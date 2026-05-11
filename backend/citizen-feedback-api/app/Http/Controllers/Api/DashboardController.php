<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Office;
use App\Models\Report;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function index(Request $request)
    {
        $query = $this->scopedReports($request);

        return response()->json([
            'total_reports' => (clone $query)->count(),
            'new' => (clone $query)->where('status', 'New')->count(),
            'pending' => (clone $query)->where('status', 'Pending')->count(),
            'in_progress' => (clone $query)->where('status', 'In Progress')->count(),
            'resolved' => (clone $query)->where('status', 'Resolved')->count(),
        ]);
    }

    public function analytics(Request $request)
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $filters = $request->validate([
            'office' => ['nullable', 'string', 'max:255'],
            'barangay' => ['nullable', 'string', 'max:255'],
            'category' => ['nullable', 'string', 'max:255'],
            'date_preset' => ['nullable', 'string', 'in:today,last_7_days,last_30_days,custom'],
            'start_date' => ['nullable', 'date', 'required_if:date_preset,custom'],
            'end_date' => ['nullable', 'date', 'required_if:date_preset,custom', 'after_or_equal:start_date'],
        ]);

        $statuses = ['New', 'Pending', 'In Progress', 'Resolved', 'Rejected'];
        $priorities = ['Low', 'Normal', 'High', 'Urgent'];

        $baseQuery = $this->scopedReports($request);
        $this->applyAnalyticsFilters($baseQuery, $filters);

        $dateRange = $this->resolveDateRange($filters);
        $this->applyDateRange($baseQuery, $dateRange);

        $timelineRange = $dateRange ?? $this->fallbackTimelineRange(clone $baseQuery);
        $overview = $this->buildOverviewCounts($baseQuery);
        $comparisonOverview = [
            'total_reports' => 0,
            'new' => 0,
            'pending' => 0,
            'in_progress' => 0,
            'resolved' => 0,
            'rejected' => 0,
        ];

        if ($dateRange !== null) {
            $previousQuery = $this->scopedReports($request);
            $this->applyAnalyticsFilters($previousQuery, $filters);
            $this->applyDateRange($previousQuery, $this->previousDateRange($dateRange));
            $comparisonOverview = $this->buildOverviewCounts($previousQuery);
        }

        $statusCounts = (clone $baseQuery)
            ->select('status', DB::raw('COUNT(*) as total'))
            ->groupBy('status')
            ->pluck('total', 'status');

        $statusBreakdown = collect($statuses)->map(function (string $status) use ($statusCounts) {
            return [
                'label' => $status,
                'count' => (int) ($statusCounts[$status] ?? 0),
            ];
        })->values();

        $priorityCounts = (clone $baseQuery)
            ->select('priority', DB::raw('COUNT(*) as total'))
            ->groupBy('priority')
            ->pluck('total', 'priority');

        $priorityBreakdown = collect($priorities)->map(function (string $priority) use ($priorityCounts) {
            return [
                'label' => $priority,
                'count' => (int) ($priorityCounts[$priority] ?? 0),
            ];
        })->values();

        $categoryBreakdown = (clone $baseQuery)
            ->leftJoin('categories', 'reports.category_id', '=', 'categories.id')
            ->selectRaw("COALESCE(categories.name, 'General') as label, COUNT(*) as total")
            ->groupBy(DB::raw("COALESCE(categories.name, 'General')"))
            ->orderByDesc('total')
            ->limit(6)
            ->get()
            ->map(function ($row) {
                return [
                    'label' => $row->label,
                    'count' => (int) $row->total,
                ];
            })
            ->values();

        $barangayBreakdown = (clone $baseQuery)
            ->select('barangay', DB::raw('COUNT(*) as total'))
            ->whereNotNull('barangay')
            ->where('barangay', '!=', '')
            ->groupBy('barangay')
            ->orderByDesc('total')
            ->limit(5)
            ->get()
            ->map(function ($row) {
                return [
                    'label' => $row->barangay,
                    'count' => (int) $row->total,
                ];
            })
            ->values();

        $locationBreakdown = (clone $baseQuery)
            ->select('location', DB::raw('COUNT(*) as total'))
            ->whereNotNull('location')
            ->where('location', '!=', '')
            ->groupBy('location')
            ->orderByDesc('total')
            ->limit(6)
            ->get()
            ->map(function ($row) {
                return [
                    'label' => $row->location,
                    'count' => (int) $row->total,
                ];
            })
            ->values();

        $monthExpression = $this->monthExpression('created_at');
        $resolvedMonthExpression = $this->monthExpression('COALESCE(resolved_at, created_at)');
        $trendEndMonth = $this->trendEndMonth($baseQuery);
        $trendStartMonth = $trendEndMonth->copy()->subMonths(5)->startOfMonth();

        $monthlyCounts = (clone $baseQuery)
            ->selectRaw("{$monthExpression} as month_key, COUNT(*) as total")
            ->where('created_at', '>=', $trendStartMonth)
            ->where('created_at', '<', $trendEndMonth->copy()->addMonth()->startOfMonth())
            ->groupBy('month_key')
            ->orderBy('month_key')
            ->get()
            ->pluck('total', 'month_key');

        $monthlyResolvedCounts = (clone $baseQuery)
            ->selectRaw("{$resolvedMonthExpression} as month_key, COUNT(*) as total")
            ->where('status', 'Resolved')
            ->where(function ($query) use ($trendStartMonth, $trendEndMonth) {
                $query->where('resolved_at', '>=', $trendStartMonth)
                    ->where('resolved_at', '<', $trendEndMonth->copy()->addMonth()->startOfMonth())
                    ->orWhere(function ($fallbackQuery) use ($trendStartMonth, $trendEndMonth) {
                        $fallbackQuery->whereNull('resolved_at')
                            ->where('created_at', '>=', $trendStartMonth)
                            ->where('created_at', '<', $trendEndMonth->copy()->addMonth()->startOfMonth());
                    });
            })
            ->groupBy('month_key')
            ->orderBy('month_key')
            ->get()
            ->pluck('total', 'month_key');

        $monthlyTrend = collect(range(0, 5))->map(function (int $offset) use ($monthlyCounts, $monthlyResolvedCounts, $trendStartMonth) {
            $date = $trendStartMonth->copy()->addMonths($offset);
            $key = $date->format('Y-m');

            return [
                'label' => $date->format('M'),
                'new_reports' => (int) ($monthlyCounts[$key] ?? 0),
                'resolved_reports' => (int) ($monthlyResolvedCounts[$key] ?? 0),
            ];
        })->values();

        $timelineBreakdown = $this->buildTimelineBreakdown(clone $baseQuery, $timelineRange);

        $staffPerformance = (clone $baseQuery)
            ->with('assignedAdmin:id,name')
            ->whereNotNull('assigned_to')
            ->get()
            ->groupBy('assigned_to')
            ->map(function ($reports, $userId) {
                $firstReport = $reports->first();
                $assignedAdmin = $firstReport?->assignedAdmin;

                return [
                    'id' => (int) $userId,
                    'name' => $assignedAdmin?->name ?? 'Assigned Staff',
                    'reports_count' => $reports->count(),
                    'resolved_count' => $reports->where('status', 'Resolved')->count(),
                    'in_progress_count' => $reports->where('status', 'In Progress')->count(),
                ];
            })
            ->sortByDesc('reports_count')
            ->take(5)
            ->values();

        return response()->json([
            'overview' => $overview,
            'comparison_overview' => $comparisonOverview,
            'status_breakdown' => $statusBreakdown,
            'priority_breakdown' => $priorityBreakdown,
            'category_breakdown' => $categoryBreakdown,
            'barangay_breakdown' => $barangayBreakdown,
            'top_barangays' => $barangayBreakdown,
            'location_breakdown' => $locationBreakdown,
            'staff_performance' => $staffPerformance,
            'monthly_trend' => $monthlyTrend,
            'timeline_breakdown' => $timelineBreakdown,
            'applied_filters' => [
                'office' => $filters['office'] ?? null,
                'barangay' => $filters['barangay'] ?? null,
                'category' => $filters['category'] ?? null,
                'date_preset' => $filters['date_preset'] ?? null,
                'start_date' => $timelineRange['start']->toDateString(),
                'end_date' => $timelineRange['end']->toDateString(),
            ],
            'generated_at' => now()->toIso8601String(),
        ]);
    }

    private function scopedReports(Request $request)
    {
        $query = Report::query();
        $role = $request->user()->role ?? 'citizen';

        if ($role === 'citizen') {
            $query->where('user_id', $request->user()->id);
        } elseif ($role === 'admin') {
            $officeId = $this->resolveAdminOfficeId($request->user());

            if ($officeId === null) {
                $query->whereRaw('1 = 0');
            } else {
                $query->where('reports.office_id', $officeId);
            }
        }

        return $query;
    }

    private function resolveAdminOfficeId($user): ?int
    {
        if (($user->role ?? null) !== 'admin') {
            return null;
        }

        $directOfficeId = data_get($user, 'office_id') ?? data_get($user, 'office.id');
        if ($directOfficeId !== null && is_numeric($directOfficeId)) {
            return (int) $directOfficeId;
        }

        $department = trim((string) ($user->department ?? ''));
        if ($department === '') {
            return null;
        }

        $resolvedOfficeId = Office::query()
            ->whereRaw('LOWER(name) = ?', [mb_strtolower($department)])
            ->value('id');

        return $resolvedOfficeId === null ? null : (int) $resolvedOfficeId;
    }

    private function applyAnalyticsFilters($query, array $filters): void
    {
        if (! empty($filters['office'])) {
            $office = trim((string) $filters['office']);
            $query->whereHas('office', function ($officeQuery) use ($office) {
                $officeQuery->whereRaw('LOWER(name) = ?', [mb_strtolower($office)]);
            });
        }

        if (! empty($filters['barangay'])) {
            $barangay = trim((string) $filters['barangay']);
            $query->whereRaw('LOWER(reports.barangay) = ?', [mb_strtolower($barangay)]);
        }

        if (! empty($filters['category'])) {
            $category = trim((string) $filters['category']);
            $query->whereHas('category', function ($categoryQuery) use ($category) {
                $categoryQuery->whereRaw('LOWER(name) = ?', [mb_strtolower($category)]);
            });
        }
    }

    private function resolveDateRange(array $filters): ?array
    {
        $preset = (string) ($filters['date_preset'] ?? '');
        if ($preset === '') {
            return null;
        }

        $today = now()->startOfDay();

        return match ($preset) {
            'today' => [
                'preset' => $preset,
                'start' => $today->copy(),
                'end' => $today->copy()->endOfDay(),
            ],
            'last_7_days' => [
                'preset' => $preset,
                'start' => $today->copy()->subDays(6),
                'end' => $today->copy()->endOfDay(),
            ],
            'last_30_days' => [
                'preset' => $preset,
                'start' => $today->copy()->subDays(29),
                'end' => $today->copy()->endOfDay(),
            ],
            'custom' => [
                'preset' => $preset,
                'start' => Carbon::parse((string) $filters['start_date'])->startOfDay(),
                'end' => Carbon::parse((string) $filters['end_date'])->endOfDay(),
            ],
            default => null,
        };
    }

    private function applyDateRange($query, ?array $range): void
    {
        if ($range === null) {
            return;
        }

        $query->whereBetween('reports.created_at', [$range['start'], $range['end']]);
    }

    private function fallbackTimelineRange($query): array
    {
        $latestCreatedAt = (clone $query)->max('created_at');
        $end = $latestCreatedAt === null
            ? now()->endOfDay()
            : Carbon::parse($latestCreatedAt)->endOfDay();

        return [
            'preset' => 'last_30_days',
            'start' => $end->copy()->subDays(29)->startOfDay(),
            'end' => $end,
        ];
    }

    private function previousDateRange(array $range): array
    {
        $days = $range['start']->copy()->startOfDay()->diffInDays($range['end']->copy()->startOfDay()) + 1;
        $previousEnd = $range['start']->copy()->subDay()->endOfDay();
        $previousStart = $previousEnd->copy()->subDays($days - 1)->startOfDay();

        return [
            'preset' => 'comparison',
            'start' => $previousStart,
            'end' => $previousEnd,
        ];
    }

    private function buildOverviewCounts($query): array
    {
        $statusCounts = (clone $query)
            ->select('status', DB::raw('COUNT(*) as total'))
            ->groupBy('status')
            ->pluck('total', 'status');

        return [
            'total_reports' => (clone $query)->count(),
            'new' => (int) ($statusCounts['New'] ?? 0),
            'pending' => (int) ($statusCounts['Pending'] ?? 0),
            'in_progress' => (int) ($statusCounts['In Progress'] ?? 0),
            'resolved' => (int) ($statusCounts['Resolved'] ?? 0),
            'rejected' => (int) ($statusCounts['Rejected'] ?? 0),
        ];
    }

    private function buildTimelineBreakdown($query, array $range): array
    {
        $start = $range['start']->copy()->startOfDay();
        $end = $range['end']->copy()->endOfDay();
        $segments = 7;
        $spanDays = max(1, $start->diffInDays($end) + 1);
        $bucketSize = max(1, (int) ceil($spanDays / $segments));
        $reports = (clone $query)->get(['status', 'created_at']);
        $buckets = [];

        for ($index = 0; $index < $segments; $index++) {
            $bucketStart = $start->copy()->addDays($bucketSize * $index);
            if ($bucketStart->gt($end)) {
                break;
            }

            $bucketEnd = $bucketStart->copy()->addDays($bucketSize - 1)->endOfDay();
            if ($bucketEnd->gt($end)) {
                $bucketEnd = $end->copy();
            }

            $items = $reports->filter(function (Report $report) use ($bucketStart, $bucketEnd) {
                $createdAt = $report->created_at;
                if ($createdAt === null) {
                    return false;
                }

                $createdDate = $createdAt->toDateString();
                return $createdDate >= $bucketStart->toDateString()
                    && $createdDate <= $bucketEnd->toDateString();
            });

            $buckets[] = [
                'label' => $bucketStart->format('n/j'),
                'total' => $items->count(),
                'pending' => $items->whereIn('status', ['New', 'Pending'])->count(),
                'progress' => $items->where('status', 'In Progress')->count(),
                'resolved' => $items->where('status', 'Resolved')->count(),
                'rejected' => $items->where('status', 'Rejected')->count(),
            ];
        }

        return $buckets;
    }

    private function monthExpression(string $column): string
    {
        return DB::getDriverName() === 'sqlite'
            ? "strftime('%Y-%m', {$column})"
            : "DATE_FORMAT({$column}, '%Y-%m')";
    }

    private function trendEndMonth($baseQuery): Carbon
    {
        $latestCreatedAt = (clone $baseQuery)->max('created_at');

        if ($latestCreatedAt === null) {
            return now()->startOfMonth();
        }

        return Carbon::parse($latestCreatedAt)->startOfMonth();
    }
}
