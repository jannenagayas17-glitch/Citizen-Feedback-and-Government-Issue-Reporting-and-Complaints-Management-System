<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Office;
use App\Models\Report;
use App\Models\SystemSetting;
use App\Models\User;
use App\Support\ReportQueryService;
use App\Support\UserEmailDeduplicationService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function __construct(
        private readonly ReportQueryService $reportQueries,
        private readonly UserEmailDeduplicationService $userEmailDeduplication,
    ) {
    }

    public function index(Request $request)
    {
        $query = $this->reportQueries->scopedForUser($request->user());
        $overview = $this->reportQueries->buildOverviewCounts($query);

        return response()->json([
            'total_reports' => $overview['total_reports'],
            'new' => $overview['new'],
            'pending' => $overview['pending'],
            'in_progress' => $overview['in_progress'],
            'resolved' => $overview['resolved'],
            'rejected' => $overview['rejected'],
            'queue_count' => $overview['queue_count'],
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
            'status' => ['nullable', 'string', 'in:New,Pending,In Progress,Resolved,Rejected'],
            'date_preset' => ['nullable', 'string', 'in:today,last_7_days,last_30_days,custom'],
            'start_date' => ['nullable', 'date', 'required_if:date_preset,custom'],
            'end_date' => ['nullable', 'date', 'required_if:date_preset,custom', 'after_or_equal:start_date'],
        ]);

        $statuses = $this->reportQueries->canonicalStatuses();
        $priorities = $this->reportQueries->canonicalPriorities();

        $baseQuery = $this->reportQueries->scopedForUser($request->user());
        $this->reportQueries->applyFilters($baseQuery, $filters);

        $dateRange = $this->reportQueries->applyDateRangeFilter($baseQuery, $filters);

        $timelineRange = $dateRange ?? $this->reportQueries->fallbackTimelineRange(clone $baseQuery);
        $overview = $this->reportQueries->buildOverviewCounts($baseQuery);
        $comparisonOverview = [
            'total_reports' => 0,
            'new' => 0,
            'pending' => 0,
            'in_progress' => 0,
            'resolved' => 0,
            'rejected' => 0,
            'queue_count' => 0,
        ];

        if ($dateRange !== null) {
            $previousQuery = $this->reportQueries->scopedForUser($request->user());
            $this->reportQueries->applyFilters($previousQuery, $filters);
            $previousRange = $this->previousDateRange($dateRange);
            $previousQuery->whereBetween('reports.created_at', [
                $previousRange['start'],
                $previousRange['end'],
            ]);
            $comparisonOverview = $this->reportQueries->buildOverviewCounts($previousQuery);
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

        $officeBreakdown = (clone $baseQuery)
            ->leftJoin('offices', 'reports.office_id', '=', 'offices.id')
            ->selectRaw("
                COALESCE(offices.name, 'Unassigned Office') as label,
                COUNT(*) as total,
                SUM(CASE WHEN reports.status = 'New' THEN 1 ELSE 0 END) as new_total,
                SUM(CASE WHEN reports.status = 'Pending' THEN 1 ELSE 0 END) as pending_total,
                SUM(CASE WHEN reports.status = 'In Progress' THEN 1 ELSE 0 END) as in_progress_total,
                SUM(CASE WHEN reports.status = 'Resolved' THEN 1 ELSE 0 END) as resolved_total,
                SUM(CASE WHEN reports.status = 'Rejected' THEN 1 ELSE 0 END) as rejected_total
            ")
            ->groupBy('label')
            ->orderByDesc('total')
            ->limit(6)
            ->get()
            ->map(function ($row) {
                $total = (int) $row->total;
                $resolved = (int) $row->resolved_total;

                return [
                    'label' => $row->label,
                    'count' => $total,
                    'pending' => (int) $row->pending_total,
                    'in_progress' => (int) $row->in_progress_total,
                    'resolved' => $resolved,
                    'rejected' => (int) $row->rejected_total,
                    'new' => (int) $row->new_total,
                    'resolution_rate' => $total === 0 ? 0 : (int) round(($resolved / $total) * 100),
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
            ->leftJoin('users as assigned_admins', 'reports.assigned_to', '=', 'assigned_admins.id')
            ->whereNotNull('assigned_to')
            ->selectRaw("
                reports.assigned_to as id,
                COALESCE(assigned_admins.name, 'Assigned Staff') as name,
                COUNT(*) as reports_count,
                SUM(CASE WHEN reports.status = 'Resolved' THEN 1 ELSE 0 END) as resolved_count,
                SUM(CASE WHEN reports.status = 'In Progress' THEN 1 ELSE 0 END) as in_progress_count
            ")
            ->groupBy('reports.assigned_to', 'assigned_admins.name')
            ->orderByDesc('reports_count')
            ->limit(5)
            ->get()
            ->map(function ($row) {
                return [
                    'id' => (int) $row->id,
                    'name' => $row->name,
                    'reports_count' => (int) $row->reports_count,
                    'resolved_count' => (int) $row->resolved_count,
                    'in_progress_count' => (int) $row->in_progress_count,
                ];
            })
            ->values();

        $triggerHours = $this->triggerTimeHours();
        $recentReports = $this->buildReportPreviews(clone $baseQuery, 12);
        $triageReports = $this->buildReportPreviews(
            (clone $baseQuery)
                ->whereIn('reports.status', ['New', 'Pending', 'In Progress'])
                ->orderByDesc('reports.updated_at')
                ->orderByDesc('reports.id'),
            6,
            applyDefaultOrder: false,
        );
        $staleReportsCount = (clone $baseQuery)
            ->whereIn('reports.status', ['New', 'Pending', 'In Progress'])
            ->where('reports.created_at', '<=', now()->subHours($triggerHours))
            ->count();
        $escalationPreview = $this->buildEscalationPreview(clone $baseQuery, $triggerHours);
        $monthlyVolume = $this->buildMonthlyVolume(clone $baseQuery);
        $averageOpenHours = $this->averageOpenHours(clone $baseQuery);
        $activeOfficesCount = $this->activeOfficesCountForUser($request->user());
        $adminPreview = $this->buildAdminPreview($request->user());

        return response()->json([
            'overview' => $overview,
            'comparison_overview' => $comparisonOverview,
            'status_breakdown' => $statusBreakdown,
            'priority_breakdown' => $priorityBreakdown,
            'category_breakdown' => $categoryBreakdown,
            'barangay_breakdown' => $barangayBreakdown,
            'top_barangays' => $barangayBreakdown,
            'location_breakdown' => $locationBreakdown,
            'office_breakdown' => $officeBreakdown,
            'staff_performance' => $staffPerformance,
            'monthly_trend' => $monthlyTrend,
            'monthly_volume' => $monthlyVolume,
            'timeline_breakdown' => $timelineBreakdown,
            'recent_reports' => $recentReports,
            'triage_reports' => $triageReports,
            'queue_count' => $overview['queue_count'],
            'stale_reports_count' => $staleReportsCount,
            'average_open_hours' => $averageOpenHours,
            'trigger_time_hours' => $triggerHours,
            'active_offices_count' => $activeOfficesCount,
            'admin_preview' => $adminPreview,
            'escalations_preview' => $escalationPreview,
            'applied_filters' => [
                'office' => $filters['office'] ?? null,
                'barangay' => $filters['barangay'] ?? null,
                'category' => $filters['category'] ?? null,
                'status' => $filters['status'] ?? null,
                'date_preset' => $filters['date_preset'] ?? null,
                'start_date' => $timelineRange['start']->toDateString(),
                'end_date' => $timelineRange['end']->toDateString(),
            ],
            'generated_at' => now()->toIso8601String(),
        ]);
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

    private function buildTimelineBreakdown(Builder $query, array $range): array
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

    private function buildReportPreviews(
        Builder $query,
        int $limit,
        bool $applyDefaultOrder = true,
    ): array
    {
        $reportQuery = $query
            ->select([
                'reports.id',
                'reports.user_id',
                'reports.category_id',
                'reports.office_id',
                'reports.title',
                'reports.location',
                'reports.barangay',
                'reports.status',
                'reports.priority',
                'reports.assigned_to',
                'reports.created_at',
                'reports.updated_at',
            ])
            ->with([
                'user:id,name,email',
                'category:id,name',
                'office:id,name',
                'assignedAdmin:id,name,email',
            ]);

        if ($applyDefaultOrder) {
            $reportQuery
                ->orderByDesc('reports.created_at')
                ->orderByDesc('reports.id');
        }

        $reports = $reportQuery
            ->limit($limit)
            ->get();

        return $reports->map(function (Report $report) {
            return [
                'id' => $report->id,
                'title' => $report->title,
                'location' => $report->location,
                'barangay' => $report->barangay,
                'status' => $report->status,
                'priority' => $report->priority,
                'assigned_to' => $report->assigned_to,
                'created_at' => optional($report->created_at)?->toIso8601String(),
                'updated_at' => optional($report->updated_at)?->toIso8601String(),
                'user' => $report->user === null ? null : [
                    'id' => $report->user->id,
                    'name' => $report->user->name,
                    'email' => $report->user->email,
                ],
                'category' => $report->category === null ? null : [
                    'id' => $report->category->id,
                    'name' => $report->category->name,
                ],
                'office' => $report->office === null ? null : [
                    'id' => $report->office->id,
                    'name' => $report->office->name,
                ],
                'assigned_admin' => $report->assignedAdmin === null ? null : [
                    'id' => $report->assignedAdmin->id,
                    'name' => $report->assignedAdmin->name,
                    'email' => $report->assignedAdmin->email,
                ],
            ];
        })->values()->all();
    }

    private function buildEscalationPreview(Builder $query, int $triggerHours): array
    {
        return $this->buildReportPreviews(
            $query
                ->whereIn('reports.status', ['New', 'Pending', 'In Progress'])
                ->where('reports.created_at', '<=', now()->subHours($triggerHours))
                ->orderBy('reports.created_at')
                ->orderBy('reports.id'),
            4,
            applyDefaultOrder: false,
        );
    }

    private function buildMonthlyVolume(Builder $query): array
    {
        $monthExpression = $this->monthExpression('created_at');
        $endMonth = $this->trendEndMonth($query);
        $startMonth = $endMonth->copy()->subMonths(11)->startOfMonth();

        $counts = (clone $query)
            ->selectRaw("{$monthExpression} as month_key, COUNT(*) as total")
            ->where('created_at', '>=', $startMonth)
            ->where('created_at', '<', $endMonth->copy()->addMonth()->startOfMonth())
            ->groupBy('month_key')
            ->orderBy('month_key')
            ->get()
            ->pluck('total', 'month_key');

        return collect(range(0, 11))->map(function (int $offset) use ($startMonth, $counts) {
            $date = $startMonth->copy()->addMonths($offset);
            $key = $date->format('Y-m');

            return [
                'label' => $date->format('M'),
                'month' => (int) $date->format('n'),
                'year' => (int) $date->format('Y'),
                'count' => (int) ($counts[$key] ?? 0),
            ];
        })->values()->all();
    }

    private function averageOpenHours(Builder $query): int
    {
        $openQuery = (clone $query)->whereIn('reports.status', ['New', 'Pending', 'In Progress']);

        if (DB::getDriverName() === 'sqlite') {
            $average = $openQuery
                ->selectRaw("AVG((julianday('now') - julianday(created_at)) * 24) as average_hours")
                ->value('average_hours');
        } else {
            $average = $openQuery
                ->selectRaw('AVG(TIMESTAMPDIFF(HOUR, created_at, NOW())) as average_hours')
                ->value('average_hours');
        }

        return (int) round((float) ($average ?? 0));
    }

    private function triggerTimeHours(): int
    {
        $settings = SystemSetting::query()
            ->where('key', 'super_admin_portal')
            ->value('value');

        return (int) data_get($settings, 'escalation_settings.trigger_time_hours', 72);
    }

    private function monthExpression(string $column): string
    {
        return DB::getDriverName() === 'sqlite'
            ? "strftime('%Y-%m', {$column})"
            : "DATE_FORMAT({$column}, '%Y-%m')";
    }

    private function activeOfficesCountForUser($user): int
    {
        if (($user->role ?? null) === 'admin') {
            return $this->reportQueries->resolveAdminOfficeId($user) === null ? 0 : 1;
        }

        return Office::query()
            ->where('is_active', true)
            ->count();
    }

    private function buildAdminPreview($user): array
    {
        if (($user->role ?? null) !== 'super_admin') {
            return [];
        }

        $users = User::withTrashed()
            ->whereIn('role', ['super_admin', 'admin'])
            ->orderByRaw("case when role = 'super_admin' then 0 else 1 end")
            ->orderBy('name')
            ->get();

        return $this->userEmailDeduplication
            ->deduplicateUsersForDisplay($users)
            ->take(4)
            ->map(function ($user) {
                $department = trim((string) ($user->department ?? ''));

                return [
                    'name' => (string) ($user->name ?? 'Admin User'),
                    'department' => $department === '' ? 'No department' : $department,
                    'active' => $user->is_active == true,
                    'role' => (string) ($user->role ?? 'admin'),
                ];
            })
            ->values()
            ->all();
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
