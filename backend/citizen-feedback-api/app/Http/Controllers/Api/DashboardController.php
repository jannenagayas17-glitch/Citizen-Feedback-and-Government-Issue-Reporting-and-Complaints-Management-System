<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\SystemSetting;
use App\Models\User;
use App\Support\DemoAccountService;
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
        private readonly DemoAccountService $demoAccounts,
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

        $datePresetRule = 'in:' . implode(',', $this->reportQueries->allowedDatePresets());

        $filters = $request->validate([
            'office' => ['nullable', 'string', 'max:255'],
            'barangay' => ['nullable', 'string', 'max:255'],
            'category' => ['nullable', 'string', 'max:255'],
            'status' => ['nullable', 'string', 'in:New,Pending,In Progress,Resolved,Rejected'],
            'date_preset' => ['nullable', 'string', $datePresetRule],
            'start_date' => ['nullable', 'date', 'required_if:date_preset,custom'],
            'end_date' => ['nullable', 'date', 'required_if:date_preset,custom', 'after_or_equal:start_date'],
        ]);

        $statuses = $this->reportQueries->canonicalStatuses();
        $priorities = $this->reportQueries->canonicalPriorities();
        $canonicalPreset = $this->reportQueries->canonicalDatePreset($filters['date_preset'] ?? null);

        $baseQuery = $this->reportQueries->scopedForUser($request->user());
        $this->reportQueries->applyFilters($baseQuery, $filters);

        $dateRange = $this->reportQueries->applyDateRangeFilter($baseQuery, $filters);

        $timelineRange = $dateRange ?? $this->reportQueries->fallbackTimelineRange(clone $baseQuery);
        $timelineMode = $this->resolveTimelineMode($canonicalPreset, $timelineRange);
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

        $monthlyTrend = $this->buildMonthlyTrend(clone $baseQuery);
        $timelineBreakdown = $this->buildTimelineBreakdown(clone $baseQuery, $timelineRange, $timelineMode);
        $departmentTrend = $this->buildDepartmentTrend(
            clone $baseQuery,
            $timelineRange,
            $timelineMode,
            $officeBreakdown->take(4)->all(),
        );

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
        $recentReports = $this->buildReportPreviews(clone $baseQuery, 12, $request->user());
        $triageReports = $this->buildReportPreviews(
            (clone $baseQuery)
                ->whereIn('reports.status', ['New', 'Pending', 'In Progress'])
                ->orderByDesc('reports.updated_at')
                ->orderByDesc('reports.id'),
            6,
            $request->user(),
            applyDefaultOrder: false,
        );
        $staleReportsCount = (clone $baseQuery)
            ->whereIn('reports.status', ['New', 'Pending', 'In Progress'])
            ->where('reports.created_at', '<=', now()->subHours($triggerHours))
            ->count();
        $escalationPreview = $this->buildEscalationPreview(clone $baseQuery, $triggerHours, $request->user());
        $monthlyVolume = $this->buildMonthlyVolume(clone $baseQuery);
        $averageOpenHours = $this->averageOpenHours(clone $baseQuery);
        $activeOfficesCount = (clone $baseQuery)
            ->whereNotNull('reports.office_id')
            ->distinct()
            ->count('reports.office_id');
        $adminPreview = $this->buildAdminPreview($request->user());
        $availableFilters = $this->buildAvailableFilters($request->user(), $filters);

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
            'department_trend' => $departmentTrend,
            'staff_performance' => $staffPerformance,
            'monthly_trend' => $monthlyTrend,
            'monthly_volume' => $monthlyVolume,
            'timeline_breakdown' => $timelineBreakdown,
            'timeline_meta' => [
                'preset' => $canonicalPreset,
                'grouping' => $timelineMode['grouping'],
                'grouping_label' => $timelineMode['grouping_label'],
                'range_label' => $this->formatTimelineRangeLabel($timelineRange, $timelineMode['grouping']),
            ],
            'recent_reports' => $recentReports,
            'triage_reports' => $triageReports,
            'queue_count' => $overview['queue_count'],
            'stale_reports_count' => $staleReportsCount,
            'average_open_hours' => $averageOpenHours,
            'trigger_time_hours' => $triggerHours,
            'active_offices_count' => $activeOfficesCount,
            'admin_preview' => $adminPreview,
            'escalations_preview' => $escalationPreview,
            'role_scope' => [
                'role' => (string) ($request->user()->role ?? 'admin'),
                'department_locked' => ($request->user()->role ?? null) === 'admin',
                'selected_department' => $this->selectedDepartmentLabel($request->user(), $filters['office'] ?? null),
            ],
            'available_filters' => $availableFilters,
            'applied_filters' => [
                'office' => $filters['office'] ?? null,
                'barangay' => $filters['barangay'] ?? null,
                'category' => $filters['category'] ?? null,
                'status' => $filters['status'] ?? null,
                'date_preset' => $canonicalPreset,
                'start_date' => $timelineRange['start']->toDateString(),
                'end_date' => $timelineRange['end']->toDateString(),
            ],
            'generated_at' => now()->toIso8601String(),
        ]);
    }

    private function buildAvailableFilters(User $user, array $filters): array
    {
        return [
            'barangays' => $this->availableBarangays($user, $filters),
            'categories' => $this->availableCategories($user, $filters),
        ];
    }

    private function availableBarangays(User $user, array $filters): array
    {
        $query = $this->reportQueries->scopedForUser($user);
        $this->reportQueries->applyFilters($query, $filters, ['barangay']);
        $this->reportQueries->applyDateRangeFilter($query, $filters);

        return (clone $query)
            ->whereNotNull('reports.barangay')
            ->where('reports.barangay', '!=', '')
            ->select('reports.barangay')
            ->distinct()
            ->orderBy('reports.barangay')
            ->pluck('reports.barangay')
            ->map(fn ($value) => trim((string) $value))
            ->filter(fn (string $value) => $value !== '')
            ->values()
            ->all();
    }

    private function availableCategories(User $user, array $filters): array
    {
        $query = $this->reportQueries->scopedForUser($user);
        $this->reportQueries->applyFilters($query, $filters, ['category']);
        $this->reportQueries->applyDateRangeFilter($query, $filters);

        return (clone $query)
            ->leftJoin('categories', 'reports.category_id', '=', 'categories.id')
            ->selectRaw("COALESCE(categories.name, 'General') as label")
            ->groupBy(DB::raw("COALESCE(categories.name, 'General')"))
            ->orderBy('label')
            ->pluck('label')
            ->map(fn ($value) => trim((string) $value))
            ->filter(fn (string $value) => $value !== '')
            ->values()
            ->all();
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

    private function resolveTimelineMode(string $canonicalPreset, array $range): array
    {
        $spanDays = max(
            1,
            $range['start']->copy()->startOfDay()->diffInDays($range['end']->copy()->startOfDay()) + 1
        );
        $spanMonths = max(
            1,
            $range['start']->copy()->startOfMonth()->diffInMonths($range['end']->copy()->startOfMonth()) + 1
        );

        return match ($canonicalPreset) {
            'today',
            'weekly' => [
                'grouping' => 'day',
                'grouping_label' => 'Daily',
            ],
            'last_7_days' => [
                'grouping' => 'day',
                'grouping_label' => 'Daily',
            ],
            'monthly',
            'last_30_days',
            'custom' => [
                'grouping' => $spanDays <= 14 ? 'day' : 'week',
                'grouping_label' => $spanDays <= 14 ? 'Daily' : 'Weekly',
            ],
            'yearly' => [
                'grouping' => 'month',
                'grouping_label' => 'Monthly',
            ],
            default => [
                'grouping' => $spanMonths <= 18 ? 'month' : 'year',
                'grouping_label' => $spanMonths <= 18 ? 'Monthly' : 'Yearly',
            ],
        };
    }

    private function buildTimelineBreakdown(Builder $query, array $range, array $mode): array
    {
        $definitions = $this->buildBucketDefinitions($range, $mode['grouping']);
        if ($definitions === []) {
            return [];
        }

        return match ($mode['grouping']) {
            'day' => $this->mapDirectRowsToBuckets(
                $definitions,
                $this->fetchTimelineRows($query, $range, $this->dateExpression('reports.created_at')),
            ),
            'week' => $this->mapWeeklyRowsToBuckets(
                $definitions,
                $this->fetchTimelineRows($query, $range, $this->dateExpression('reports.created_at')),
            ),
            'month' => $this->mapDirectRowsToBuckets(
                $definitions,
                $this->fetchTimelineRows($query, $range, $this->monthExpression('reports.created_at')),
            ),
            default => $this->mapDirectRowsToBuckets(
                $definitions,
                $this->fetchTimelineRows($query, $range, $this->yearExpression('reports.created_at')),
            ),
        };
    }

    private function buildDepartmentTrend(
        Builder $query,
        array $range,
        array $mode,
        array $departments,
    ): array {
        $definitions = $this->buildBucketDefinitions($range, $mode['grouping']);
        $seriesMeta = collect($departments)
            ->map(function (array $department) {
                $label = trim((string) ($department['label'] ?? ''));
                if ($label === '') {
                    return null;
                }

                return [
                    'label' => $label,
                    'total' => (int) ($department['count'] ?? 0),
                    'resolved' => (int) ($department['resolved'] ?? 0),
                    'resolution_rate' => (int) ($department['resolution_rate'] ?? 0),
                ];
            })
            ->filter()
            ->values();

        if ($definitions === [] || $seriesMeta->isEmpty()) {
            return [
                'grouping' => $mode['grouping'],
                'grouping_label' => $mode['grouping_label'],
                'labels' => array_column($definitions, 'label'),
                'series' => [],
            ];
        }

        $departmentLabels = $seriesMeta->pluck('label')->all();

        $rows = match ($mode['grouping']) {
            'day', 'week' => $this->fetchDepartmentRows(
                $query,
                $range,
                $this->dateExpression('reports.created_at'),
                $departmentLabels,
            ),
            'month' => $this->fetchDepartmentRows(
                $query,
                $range,
                $this->monthExpression('reports.created_at'),
                $departmentLabels,
            ),
            default => $this->fetchDepartmentRows(
                $query,
                $range,
                $this->yearExpression('reports.created_at'),
                $departmentLabels,
            ),
        };

        $series = $seriesMeta->map(function (array $department) use ($definitions, $rows, $mode) {
            return [
                'label' => $department['label'],
                'counts' => collect($definitions)
                    ->map(function (array $definition) use ($rows, $department, $mode) {
                        return $this->departmentCountForBucket(
                            $rows,
                            $department['label'],
                            $definition,
                            $mode['grouping'],
                        );
                    })
                    ->all(),
                'total' => $department['total'],
                'resolved' => $department['resolved'],
                'resolution_rate' => $department['resolution_rate'],
            ];
        })->values()->all();

        return [
            'grouping' => $mode['grouping'],
            'grouping_label' => $mode['grouping_label'],
            'labels' => array_column($definitions, 'label'),
            'series' => $series,
        ];
    }

    private function buildMonthlyTrend(Builder $query): array
    {
        $monthExpression = $this->monthExpression('created_at');
        $resolvedMonthExpression = $this->monthExpression('COALESCE(resolved_at, created_at)');
        $trendEndMonth = $this->trendEndMonth($query);
        $trendStartMonth = $trendEndMonth->copy()->subMonths(5)->startOfMonth();

        $monthlyCounts = (clone $query)
            ->selectRaw("{$monthExpression} as month_key, COUNT(*) as total")
            ->where('created_at', '>=', $trendStartMonth)
            ->where('created_at', '<', $trendEndMonth->copy()->addMonth()->startOfMonth())
            ->groupBy('month_key')
            ->orderBy('month_key')
            ->get()
            ->pluck('total', 'month_key');

        $monthlyResolvedCounts = (clone $query)
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

        return collect(range(0, 5))->map(function (int $offset) use ($monthlyCounts, $monthlyResolvedCounts, $trendStartMonth) {
            $date = $trendStartMonth->copy()->addMonths($offset);
            $key = $date->format('Y-m');

            return [
                'label' => $date->format('M'),
                'new_reports' => (int) ($monthlyCounts[$key] ?? 0),
                'resolved_reports' => (int) ($monthlyResolvedCounts[$key] ?? 0),
            ];
        })->values()->all();
    }

    private function buildBucketDefinitions(array $range, string $grouping): array
    {
        $start = $range['start']->copy()->startOfDay();
        $end = $range['end']->copy()->endOfDay();

        if ($start->gt($end)) {
            return [];
        }

        return match ($grouping) {
            'day' => $this->buildDailyBucketDefinitions($start, $end),
            'week' => $this->buildWeeklyBucketDefinitions($start, $end),
            'month' => $this->buildMonthlyBucketDefinitions($start, $end),
            default => $this->buildYearlyBucketDefinitions($start, $end),
        };
    }

    private function buildDailyBucketDefinitions(Carbon $start, Carbon $end): array
    {
        $definitions = [];
        $cursor = $start->copy();
        $useYear = $start->year !== $end->year;

        while ($cursor->lte($end)) {
            $definitions[] = [
                'key' => $cursor->format('Y-m-d'),
                'label' => $cursor->format($useYear ? 'M j, Y' : 'M j'),
                'start' => $cursor->copy()->startOfDay(),
                'end' => $cursor->copy()->endOfDay(),
            ];

            $cursor->addDay();
        }

        return $definitions;
    }

    private function buildWeeklyBucketDefinitions(Carbon $start, Carbon $end): array
    {
        $definitions = [];
        $cursor = $start->copy();

        while ($cursor->lte($end)) {
            $bucketStart = $cursor->copy()->startOfDay();
            $bucketEnd = $bucketStart->copy()->addDays(6)->endOfDay();
            if ($bucketEnd->gt($end)) {
                $bucketEnd = $end->copy();
            }

            $definitions[] = [
                'key' => $bucketStart->format('Y-m-d'),
                'label' => $this->formatWeekLabel($bucketStart, $bucketEnd),
                'start' => $bucketStart,
                'end' => $bucketEnd,
            ];

            $cursor = $bucketEnd->copy()->addDay()->startOfDay();
        }

        return $definitions;
    }

    private function buildMonthlyBucketDefinitions(Carbon $start, Carbon $end): array
    {
        $definitions = [];
        $cursor = $start->copy()->startOfMonth();
        $lastMonth = $end->copy()->startOfMonth();
        $useYear = $cursor->year !== $lastMonth->year;

        while ($cursor->lte($lastMonth)) {
            $bucketStart = $cursor->copy()->startOfMonth();
            $bucketEnd = $cursor->copy()->endOfMonth();

            if ($bucketStart->lt($start)) {
                $bucketStart = $start->copy();
            }

            if ($bucketEnd->gt($end)) {
                $bucketEnd = $end->copy();
            }

            $definitions[] = [
                'key' => $cursor->format('Y-m'),
                'label' => $cursor->format($useYear ? 'M Y' : 'M'),
                'start' => $bucketStart,
                'end' => $bucketEnd,
            ];

            $cursor->addMonth();
        }

        return $definitions;
    }

    private function buildYearlyBucketDefinitions(Carbon $start, Carbon $end): array
    {
        $definitions = [];
        $cursor = $start->copy()->startOfYear();
        $lastYear = $end->copy()->startOfYear();

        while ($cursor->lte($lastYear)) {
            $bucketStart = $cursor->copy()->startOfYear();
            $bucketEnd = $cursor->copy()->endOfYear();

            if ($bucketStart->lt($start)) {
                $bucketStart = $start->copy();
            }

            if ($bucketEnd->gt($end)) {
                $bucketEnd = $end->copy();
            }

            $definitions[] = [
                'key' => $cursor->format('Y'),
                'label' => $cursor->format('Y'),
                'start' => $bucketStart,
                'end' => $bucketEnd,
            ];

            $cursor->addYear();
        }

        return $definitions;
    }

    private function fetchTimelineRows(Builder $query, array $range, string $bucketExpression): array
    {
        return (clone $query)
            ->selectRaw("
                {$bucketExpression} as bucket_key,
                COUNT(*) as total,
                SUM(CASE WHEN reports.status IN ('New', 'Pending') THEN 1 ELSE 0 END) as pending,
                SUM(CASE WHEN reports.status = 'In Progress' THEN 1 ELSE 0 END) as progress,
                SUM(CASE WHEN reports.status = 'Resolved' THEN 1 ELSE 0 END) as resolved,
                SUM(CASE WHEN reports.status = 'Rejected' THEN 1 ELSE 0 END) as rejected
            ")
            ->whereBetween('reports.created_at', [
                $range['start']->copy()->startOfDay(),
                $range['end']->copy()->endOfDay(),
            ])
            ->groupBy('bucket_key')
            ->orderBy('bucket_key')
            ->get()
            ->map(function ($row) {
                return [
                    'bucket_key' => (string) $row->bucket_key,
                    'total' => (int) $row->total,
                    'pending' => (int) $row->pending,
                    'progress' => (int) $row->progress,
                    'resolved' => (int) $row->resolved,
                    'rejected' => (int) $row->rejected,
                ];
            })
            ->values()
            ->all();
    }

    private function fetchDepartmentRows(
        Builder $query,
        array $range,
        string $bucketExpression,
        array $departments,
    ): array {
        if ($departments === []) {
            return [];
        }

        return (clone $query)
            ->leftJoin('offices', 'reports.office_id', '=', 'offices.id')
            ->selectRaw("
                {$bucketExpression} as bucket_key,
                COALESCE(offices.name, 'Unassigned Office') as department_label,
                COUNT(*) as total
            ")
            ->whereBetween('reports.created_at', [
                $range['start']->copy()->startOfDay(),
                $range['end']->copy()->endOfDay(),
            ])
            ->where(function ($departmentQuery) use ($departments) {
                foreach ($departments as $index => $department) {
                    if ($department === 'Unassigned Office') {
                        if ($index === 0) {
                            $departmentQuery->whereNull('reports.office_id');
                        } else {
                            $departmentQuery->orWhereNull('reports.office_id');
                        }

                        continue;
                    }

                    if ($index === 0) {
                        $departmentQuery->where('offices.name', $department);
                    } else {
                        $departmentQuery->orWhere('offices.name', $department);
                    }
                }
            })
            ->groupBy('bucket_key', 'department_label')
            ->orderBy('bucket_key')
            ->orderBy('department_label')
            ->get()
            ->map(function ($row) {
                return [
                    'bucket_key' => (string) $row->bucket_key,
                    'department_label' => (string) $row->department_label,
                    'total' => (int) $row->total,
                ];
            })
            ->values()
            ->all();
    }

    private function mapDirectRowsToBuckets(array $definitions, array $rows): array
    {
        $indexed = [];
        foreach ($rows as $row) {
            $indexed[$row['bucket_key']] = $row;
        }

        return array_map(function (array $definition) use ($indexed) {
            $row = $indexed[$definition['key']] ?? null;

            return [
                'label' => $definition['label'],
                'total' => (int) ($row['total'] ?? 0),
                'pending' => (int) ($row['pending'] ?? 0),
                'progress' => (int) ($row['progress'] ?? 0),
                'resolved' => (int) ($row['resolved'] ?? 0),
                'rejected' => (int) ($row['rejected'] ?? 0),
            ];
        }, $definitions);
    }

    private function mapWeeklyRowsToBuckets(array $definitions, array $rows): array
    {
        return array_map(function (array $definition) use ($rows) {
            $bucket = [
                'label' => $definition['label'],
                'total' => 0,
                'pending' => 0,
                'progress' => 0,
                'resolved' => 0,
                'rejected' => 0,
            ];

            foreach ($rows as $row) {
                $date = Carbon::parse($row['bucket_key'])->startOfDay();
                if ($date->lt($definition['start']) || $date->gt($definition['end'])) {
                    continue;
                }

                $bucket['total'] += (int) $row['total'];
                $bucket['pending'] += (int) $row['pending'];
                $bucket['progress'] += (int) $row['progress'];
                $bucket['resolved'] += (int) $row['resolved'];
                $bucket['rejected'] += (int) $row['rejected'];
            }

            return $bucket;
        }, $definitions);
    }

    private function departmentCountForBucket(
        array $rows,
        string $departmentLabel,
        array $definition,
        string $grouping,
    ): int {
        if ($grouping === 'week') {
            $total = 0;

            foreach ($rows as $row) {
                if ($row['department_label'] !== $departmentLabel) {
                    continue;
                }

                $date = Carbon::parse($row['bucket_key'])->startOfDay();
                if ($date->lt($definition['start']) || $date->gt($definition['end'])) {
                    continue;
                }

                $total += (int) $row['total'];
            }

            return $total;
        }

        foreach ($rows as $row) {
            if ($row['department_label'] === $departmentLabel && $row['bucket_key'] === $definition['key']) {
                return (int) $row['total'];
            }
        }

        return 0;
    }

    private function formatWeekLabel(Carbon $start, Carbon $end): string
    {
        if ($start->isSameDay($end)) {
            return $start->format('M j');
        }

        if ($start->year !== $end->year) {
            return $start->format('M j, Y') . ' - ' . $end->format('M j, Y');
        }

        if ($start->month !== $end->month) {
            return $start->format('M j') . ' - ' . $end->format('M j');
        }

        return $start->format('M j') . '-' . $end->format('j');
    }

    private function formatTimelineRangeLabel(array $range, string $grouping): string
    {
        $start = $range['start']->copy();
        $end = $range['end']->copy();

        return match ($grouping) {
            'year' => $start->format('Y') === $end->format('Y')
                ? $start->format('Y')
                : $start->format('Y') . ' - ' . $end->format('Y'),
            'month' => $start->format('M Y') === $end->format('M Y')
                ? $start->format('M Y')
                : $start->format('M Y') . ' - ' . $end->format('M Y'),
            default => $start->isSameDay($end)
                ? $start->format('M j, Y')
                : $start->format('M j') . ' - ' . $end->format('M j, Y'),
        };
    }

    private function selectedDepartmentLabel($user, ?string $officeFilter): string
    {
        if (($user->role ?? null) === 'super_admin') {
            $office = trim((string) ($officeFilter ?? ''));

            return $office === '' ? 'All Departments' : $office;
        }

        $department = trim((string) ($user->department ?? ''));

        return $department === '' ? 'Assigned Department' : $department;
    }

    private function buildReportPreviews(
        Builder $query,
        int $limit,
        $viewer,
        bool $applyDefaultOrder = true,
    ): array
    {
        $reportQuery = $query
            ->select('reports.*')
            ->with([
                'user:id,name,email,mobile_number',
                'category:id,name',
                'office:id,name',
                'assistedByUser:id,name,email,mobile_number,department,job_title',
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

        return $reports->map(function (Report $report) use ($viewer) {
            $identityHidden = $report->hidesReporterIdentityFrom($viewer);
            $isWalkIn = $report->isWalkInComplaint();

            return [
                'id' => $report->id,
                'title' => $report->title,
                'location' => $report->location,
                'barangay' => $report->barangay,
                'status' => $report->status,
                'priority' => $report->priority,
                'is_anonymous' => (bool) $report->is_anonymous,
                'is_walk_in' => $isWalkIn,
                'source' => $isWalkIn ? 'walk_in' : 'citizen_app',
                'source_label' => $isWalkIn ? 'Administrative Staff Assistance' : 'Citizen Mobile App',
                'reporter_name' => $report->reporterNameForViewer($viewer),
                'reporter_identity_hidden' => $identityHidden,
                'user_id' => ($identityHidden || $isWalkIn) ? null : $report->user_id,
                'assigned_to' => $report->assigned_to,
                'printable_reference_number' => $report->printable_reference_number,
                'expected_return_at' => optional($report->expected_return_at)?->toIso8601String(),
                'complainant_name' => $report->reporterNameForViewer($viewer),
                'complainant_contact_number' => $report->reporterContactNumberForViewer($viewer),
                'complainant_email' => $report->reporterEmailForViewer($viewer),
                'complainant_address' => $report->reporterAddressForViewer($viewer),
                'complainant_is_senior_citizen' => (bool) $report->walk_in_is_senior_citizen,
                'complainant_is_pwd' => (bool) $report->walk_in_is_pwd,
                'created_at' => optional($report->created_at)?->toIso8601String(),
                'updated_at' => optional($report->updated_at)?->toIso8601String(),
                'user' => $report->sanitizedUserPayloadForViewer($viewer),
                'category' => $report->category === null ? null : [
                    'id' => $report->category->id,
                    'name' => $report->category->name,
                ],
                'office' => $report->office === null ? null : [
                    'id' => $report->office->id,
                    'name' => $report->office->name,
                ],
                'assisted_by_user' => $report->assistedByUser === null ? null : [
                    'id' => $report->assistedByUser->id,
                    'name' => $report->assistedByUser->name,
                    'email' => $report->assistedByUser->email,
                    'mobile_number' => $report->assistedByUser->mobile_number,
                    'department' => $report->assistedByUser->department,
                    'job_title' => $report->assistedByUser->job_title,
                ],
                'assigned_admin' => $report->assignedAdmin === null ? null : [
                    'id' => $report->assignedAdmin->id,
                    'name' => $report->assignedAdmin->name,
                    'email' => $report->assignedAdmin->email,
                ],
            ];
        })->values()->all();
    }

    private function buildEscalationPreview(Builder $query, int $triggerHours, $viewer): array
    {
        return $this->buildReportPreviews(
            $query
                ->whereIn('reports.status', ['New', 'Pending', 'In Progress'])
                ->where('reports.created_at', '<=', now()->subHours($triggerHours))
                ->orderBy('reports.created_at')
                ->orderBy('reports.id'),
            4,
            $viewer,
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

    private function dateExpression(string $column): string
    {
        return DB::getDriverName() === 'sqlite'
            ? "strftime('%Y-%m-%d', {$column})"
            : "DATE_FORMAT({$column}, '%Y-%m-%d')";
    }

    private function yearExpression(string $column): string
    {
        return DB::getDriverName() === 'sqlite'
            ? "strftime('%Y', {$column})"
            : "DATE_FORMAT({$column}, '%Y')";
    }

    private function buildAdminPreview($user): array
    {
        if (($user->role ?? null) !== 'super_admin') {
            return [];
        }

        $users = User::withTrashed()
            ->whereIn('role', ['super_admin', 'admin'])
            ->orderByRaw("case when role = 'super_admin' then 0 else 1 end")
            ->orderBy('name');

        $users = $this->demoAccounts
            ->scopeRealUsers($users)
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
