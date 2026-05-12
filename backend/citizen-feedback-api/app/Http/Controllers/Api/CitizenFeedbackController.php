<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CitizenFeedback;
use App\Models\Report;
use App\Support\CitizenFeedbackQueryService;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\StreamedResponse;

class CitizenFeedbackController extends Controller
{
    private const EMOJI_REGEX = '/[\x{1F1E6}-\x{1F1FF}\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]/u';

    public function __construct(
        private readonly CitizenFeedbackQueryService $feedbackQueries,
    ) {
    }

    public function index(Request $request)
    {
        if (! in_array($request->user()->role, ['citizen', 'admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $filters = $this->validateFeedbackFilters($request, includePagination: true);
        $query = $this->feedbackListQuery($request);

        $this->feedbackQueries->applyFilters($query, $filters);
        $this->feedbackQueries->applyDateRangeFilter($query, $filters);

        $shouldPaginate = $request->boolean('paginate')
            || $request->filled('page')
            || $request->filled('per_page');

        if (! $shouldPaginate) {
            return response()->json($query->get());
        }

        $perPage = (int) ($filters['per_page'] ?? 20);

        return response()->json(
            $query->paginate($perPage)->appends($request->query())
        );
    }

    public function summary(Request $request)
    {
        $this->ensurePortalFeedbackAccess($request);

        $filters = $this->validateFeedbackFilters($request);
        $query = $this->feedbackBaseQuery($request);

        $this->feedbackQueries->applyFilters($query, $filters);
        $dateRange = $this->feedbackQueries->applyDateRangeFilter($query, $filters);
        $summary = $this->feedbackQueries->buildSummary($query);

        return response()->json([
            ...$summary,
            'applied_filters' => [
                'search' => $filters['search'] ?? null,
                'type' => $filters['type'] ?? null,
                'office' => $filters['office'] ?? null,
                'office_id' => $filters['office_id'] ?? null,
                'barangay' => $filters['barangay'] ?? null,
                'rating' => $filters['rating'] ?? null,
                'date_preset' => $filters['date_preset'] ?? null,
                'start_date' => $dateRange === null ? null : $dateRange['start']->toDateString(),
                'end_date' => $dateRange === null ? null : $dateRange['end']->toDateString(),
            ],
            'generated_at' => now()->toIso8601String(),
        ]);
    }

    public function charts(Request $request)
    {
        $this->ensurePortalFeedbackAccess($request);

        $filters = $this->validateFeedbackFilters($request);
        $query = $this->feedbackBaseQuery($request);

        $this->feedbackQueries->applyFilters($query, $filters);
        $dateRange = $this->feedbackQueries->applyDateRangeFilter($query, $filters)
            ?? $this->feedbackQueries->fallbackTrendRange(clone $query);

        $ratingCounts = (clone $query)
            ->select('citizen_feedback.rating')
            ->selectRaw('COUNT(*) as total')
            ->groupBy('citizen_feedback.rating')
            ->pluck('total', 'citizen_feedback.rating');

        $ratingBreakdown = collect(range(1, 5))->map(function (int $rating) use ($ratingCounts) {
            return [
                'label' => $rating === 1 ? '1 Star' : $rating.' Stars',
                'rating' => $rating,
                'count' => (int) ($ratingCounts[$rating] ?? 0),
            ];
        })->values();

        $typeCounts = (clone $query)
            ->select('citizen_feedback.type')
            ->selectRaw('COUNT(*) as total')
            ->groupBy('citizen_feedback.type')
            ->pluck('total', 'citizen_feedback.type');

        $orderedTypes = collect($this->feedbackQueries->canonicalTypes())
            ->map(function (string $type) use ($typeCounts) {
                return [
                    'label' => $type,
                    'count' => (int) ($typeCounts[$type] ?? 0),
                ];
            });

        $extraTypes = collect($typeCounts)
            ->keys()
            ->filter(fn ($type) => ! in_array($type, $this->feedbackQueries->canonicalTypes(), true))
            ->sort()
            ->map(function ($type) use ($typeCounts) {
                return [
                    'label' => (string) $type,
                    'count' => (int) ($typeCounts[$type] ?? 0),
                ];
            });

        $typeBreakdown = $orderedTypes
            ->concat($extraTypes)
            ->values();

        $officeBreakdown = (clone $query)
            ->leftJoin('offices', 'citizen_feedback.office_id', '=', 'offices.id')
            ->selectRaw("COALESCE(offices.name, 'Unassigned Office') as label, COUNT(*) as total")
            ->groupBy('label')
            ->orderByDesc('total')
            ->limit(8)
            ->get()
            ->map(function ($row) {
                return [
                    'label' => $row->label,
                    'count' => (int) $row->total,
                ];
            })
            ->values();

        $barangayBreakdown = (clone $query)
            ->leftJoin('reports', 'citizen_feedback.report_id', '=', 'reports.id')
            ->whereNotNull('reports.barangay')
            ->where('reports.barangay', '!=', '')
            ->selectRaw('reports.barangay as label, COUNT(*) as total')
            ->groupBy('reports.barangay')
            ->orderByDesc('total')
            ->limit(8)
            ->get()
            ->map(function ($row) {
                return [
                    'label' => $row->label,
                    'count' => (int) $row->total,
                ];
            })
            ->values();

        return response()->json([
            'rating_breakdown' => $ratingBreakdown->all(),
            'type_breakdown' => $typeBreakdown->all(),
            'office_breakdown' => $officeBreakdown->all(),
            'barangay_breakdown' => $barangayBreakdown->all(),
            'trend_breakdown' => $this->buildTrendBreakdown(clone $query, $dateRange),
            'applied_filters' => [
                'search' => $filters['search'] ?? null,
                'type' => $filters['type'] ?? null,
                'office' => $filters['office'] ?? null,
                'office_id' => $filters['office_id'] ?? null,
                'barangay' => $filters['barangay'] ?? null,
                'rating' => $filters['rating'] ?? null,
                'date_preset' => $filters['date_preset'] ?? null,
                'start_date' => $dateRange['start']->toDateString(),
                'end_date' => $dateRange['end']->toDateString(),
            ],
            'generated_at' => now()->toIso8601String(),
        ]);
    }

    public function store(Request $request)
    {
        if (($request->user()->role ?? null) !== 'citizen') {
            abort(403, 'Only citizens can submit feedback.');
        }

        $validated = $request->validate([
            'office_id' => ['required', 'exists:offices,id'],
            'report_id' => ['nullable', 'exists:reports,id'],
            'type' => ['required', 'string', 'in:Suggestion,Complaint,Praise'],
            'message' => ['required', 'string', 'max:5000', 'not_regex:' . self::EMOJI_REGEX],
            'rating' => ['required', 'integer', 'between:1,5'],
        ], [
            'message.not_regex' => 'Emoji characters are not allowed.',
        ]);

        $report = null;

        if (! empty($validated['report_id'])) {
            $report = Report::query()
                ->where('id', $validated['report_id'])
                ->where('user_id', $request->user()->id)
                ->firstOrFail();

            if ((int) $report->office_id !== (int) $validated['office_id']) {
                abort(422, 'The selected department does not match this report.');
            }
        } else {
            $report = Report::query()
                ->where('user_id', $request->user()->id)
                ->where('office_id', $validated['office_id'])
                ->orderByRaw("case when status = 'Resolved' then 0 else 1 end")
                ->latest()
                ->first();
        }

        $feedback = CitizenFeedback::create([
            'user_id' => $request->user()->id,
            'office_id' => $validated['office_id'],
            'report_id' => $report?->id,
            'type' => $validated['type'],
            'message' => trim($validated['message']),
            'rating' => (int) $validated['rating'],
        ]);

        return response()->json([
            'message' => 'Feedback sent successfully.',
            'feedback' => $feedback->load([
                'user:id,name,email',
                'office:id,name',
                'report:id,title,barangay,status,location,office_id,user_id',
                'report.office:id,name',
            ]),
        ], 201);
    }

    public function export(Request $request): StreamedResponse
    {
        $this->ensurePortalFeedbackAccess($request);

        $filters = $this->validateFeedbackFilters($request);
        $query = $this->feedbackListQuery($request);

        $this->feedbackQueries->applyFilters($query, $filters);
        $this->feedbackQueries->applyDateRangeFilter($query, $filters);

        $items = $query->get();
        $fileName = 'citizen-feedback-' . now()->format('Ymd-His') . '.csv';

        return response()->streamDownload(function () use ($items) {
            $handle = fopen('php://output', 'w');

            fputcsv($handle, [
                'Feedback ID',
                'Report Title',
                'Reporter',
                'Barangay',
                'Status',
                'Feedback Type',
                'Rating',
                'Message',
                'Office',
                'Submitted At',
            ]);

            foreach ($items as $item) {
                fputcsv($handle, [
                    'FDB-' . str_pad((string) $item->id, 4, '0', STR_PAD_LEFT),
                    optional($item->report)->title ?? optional($item->office)->name ?? 'General Feedback',
                    optional($item->user)->name ?? 'Unknown Reporter',
                    optional($item->report)->barangay ?? '-',
                    optional($item->report)->status ?? '-',
                    $item->type,
                    $item->rating,
                    $item->message,
                    optional($item->office)->name ?? '-',
                    optional($item->created_at)?->format('Y-m-d H:i:s') ?? '-',
                ]);
            }

            fclose($handle);
        }, $fileName, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Cache-Control' => 'no-store, no-cache',
        ]);
    }

    private function ensurePortalFeedbackAccess(Request $request): void
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }
    }

    private function validateFeedbackFilters(
        Request $request,
        bool $includePagination = false,
    ): array {
        $rules = [
            'search' => ['nullable', 'string', 'max:255'],
            'type' => ['nullable', 'string', 'max:40'],
            'office' => ['nullable', 'string', 'max:255'],
            'office_id' => ['nullable', 'integer', 'exists:offices,id'],
            'barangay' => ['nullable', 'string', 'max:255'],
            'rating' => ['nullable', 'integer', 'between:1,5'],
            'days' => ['nullable', 'integer', 'min:1', 'max:3650'],
            'date_preset' => ['nullable', 'string', 'in:today,last_7_days,last_30_days,last_90_days,this_year,custom'],
            'start_date' => ['nullable', 'date', 'required_if:date_preset,custom'],
            'end_date' => ['nullable', 'date', 'required_if:date_preset,custom', 'after_or_equal:start_date'],
        ];

        if ($includePagination) {
            $rules['paginate'] = ['nullable'];
            $rules['page'] = ['nullable', 'integer', 'min:1'];
            $rules['per_page'] = ['nullable', 'integer', 'min:1', 'max:100'];
        }

        return $request->validate($rules);
    }

    private function feedbackBaseQuery(Request $request): Builder
    {
        return $this->feedbackQueries->scopedForUser($request->user());
    }

    private function feedbackListQuery(Request $request): Builder
    {
        return $this->feedbackBaseQuery($request)
            ->with([
                'user:id,name,email',
                'office:id,name',
                'report:id,title,barangay,status,location,office_id,user_id',
                'report.office:id,name',
            ])
            ->orderByDesc('citizen_feedback.created_at')
            ->orderByDesc('citizen_feedback.id');
    }

    private function buildTrendBreakdown(Builder $query, array $range): array
    {
        $totalFeedback = (clone $query)->count();
        if ($totalFeedback === 0) {
            return [];
        }

        $start = $range['start']->copy()->startOfDay();
        $end = $range['end']->copy()->endOfDay();
        $spanDays = max(1, $start->diffInDays($end) + 1);

        if ($spanDays <= 31) {
            $bucketExpression = $this->dateExpression('citizen_feedback.created_at');
            $rows = (clone $query)
                ->selectRaw("{$bucketExpression} as bucket_key, COUNT(*) as total, AVG(citizen_feedback.rating) as average_rating")
                ->whereBetween('citizen_feedback.created_at', [$start, $end])
                ->groupBy('bucket_key')
                ->orderBy('bucket_key')
                ->get()
                ->keyBy('bucket_key');

            return collect(range(0, $spanDays - 1))->map(function (int $offset) use ($rows, $start, $spanDays) {
                $date = $start->copy()->addDays($offset);
                $key = $date->format('Y-m-d');
                $row = $rows->get($key);

                return [
                    'label' => $date->format($spanDays > 14 ? 'M j' : 'n/j'),
                    'date' => $key,
                    'count' => (int) ($row->total ?? 0),
                    'average_rating' => round((float) ($row->average_rating ?? 0), 2),
                ];
            })->values()->all();
        }

        $startMonth = $start->copy()->startOfMonth();
        $endMonth = $end->copy()->startOfMonth();
        $monthCount = (($endMonth->year - $startMonth->year) * 12)
            + ($endMonth->month - $startMonth->month)
            + 1;
        $bucketExpression = $this->monthExpression('citizen_feedback.created_at');

        $rows = (clone $query)
            ->selectRaw("{$bucketExpression} as bucket_key, COUNT(*) as total, AVG(citizen_feedback.rating) as average_rating")
            ->whereBetween('citizen_feedback.created_at', [$start, $end])
            ->groupBy('bucket_key')
            ->orderBy('bucket_key')
            ->get()
            ->keyBy('bucket_key');

        return collect(range(0, max(0, $monthCount - 1)))->map(function (int $offset) use ($rows, $startMonth) {
            $date = $startMonth->copy()->addMonths($offset);
            $key = $date->format('Y-m');
            $row = $rows->get($key);

            return [
                'label' => $date->format('M Y'),
                'month' => $key,
                'count' => (int) ($row->total ?? 0),
                'average_rating' => round((float) ($row->average_rating ?? 0), 2),
            ];
        })->values()->all();
    }

    private function dateExpression(string $column): string
    {
        return DB::getDriverName() === 'sqlite'
            ? "strftime('%Y-%m-%d', {$column})"
            : "DATE({$column})";
    }

    private function monthExpression(string $column): string
    {
        return DB::getDriverName() === 'sqlite'
            ? "strftime('%Y-%m', {$column})"
            : "DATE_FORMAT({$column}, '%Y-%m')";
    }
}
