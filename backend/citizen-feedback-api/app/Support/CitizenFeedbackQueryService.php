<?php

namespace App\Support;

use App\Models\CitizenFeedback;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;

class CitizenFeedbackQueryService
{
    public function __construct(
        private readonly ReportQueryService $reportQueries,
    ) {
    }

    /**
     * @return list<string>
     */
    public function canonicalTypes(): array
    {
        return ['Suggestion', 'Complaint', 'Praise'];
    }

    public function scopedForUser($user): Builder
    {
        $query = CitizenFeedback::query();
        $this->excludeDemoSeedData($query);
        $role = $user->role ?? 'citizen';

        if ($role === 'citizen') {
            $query->where('citizen_feedback.user_id', $user->id);
        } elseif ($role === 'admin') {
            $officeId = $this->reportQueries->resolveAdminOfficeId($user);

            if ($officeId === null) {
                $query->whereRaw('1 = 0');
            } else {
                $query->where('citizen_feedback.office_id', $officeId);
            }
        } elseif ($role !== 'super_admin') {
            $query->whereRaw('1 = 0');
        }

        return $query;
    }

    private function excludeDemoSeedData(Builder $query): void
    {
        $query->whereNotIn(
            'citizen_feedback.user_id',
            $this->reportQueries->demoUserIdsQuery()
        );
    }

    public function applyFilters(Builder $query, array $filters, array $except = []): void
    {
        if (! in_array('type', $except, true) && ! empty($filters['type'])) {
            $query->whereRaw('LOWER(citizen_feedback.type) = ?', [
                mb_strtolower(trim((string) $filters['type'])),
            ]);
        }

        if (! in_array('rating', $except, true) && ! empty($filters['rating'])) {
            $query->where('citizen_feedback.rating', (int) $filters['rating']);
        }

        if (! in_array('office', $except, true) && ! empty($filters['office_id'])) {
            $query->where('citizen_feedback.office_id', (int) $filters['office_id']);
        } elseif (! in_array('office', $except, true) && ! empty($filters['office'])) {
            $office = trim((string) $filters['office']);
            $query->whereHas('office', function (Builder $officeQuery) use ($office) {
                $officeQuery->whereRaw('LOWER(name) = ?', [mb_strtolower($office)]);
            });
        }

        if (! in_array('barangay', $except, true) && ! empty($filters['barangay'])) {
            $barangay = trim((string) $filters['barangay']);
            $query->whereHas('report', function (Builder $reportQuery) use ($barangay) {
                $reportQuery->whereRaw('LOWER(barangay) = ?', [mb_strtolower($barangay)]);
            });
        }

        if (! in_array('search', $except, true) && ! empty($filters['search'])) {
            $search = trim((string) $filters['search']);
            $normalizedSearch = mb_strtolower($search);
            $numericSearch = preg_replace('/[^0-9]/', '', $search) ?? '';

            $query->where(function (Builder $searchQuery) use ($search, $normalizedSearch, $numericSearch) {
                $hasNumericCondition = false;

                if ($numericSearch !== '' && ctype_digit($numericSearch)) {
                    $searchQuery->where('citizen_feedback.id', (int) $numericSearch);
                    $hasNumericCondition = true;
                }

                $like = '%'.$search.'%';
                $baseMethod = $hasNumericCondition ? 'orWhere' : 'where';

                $searchQuery
                    ->{$baseMethod}('citizen_feedback.message', 'like', $like)
                    ->orWhere('citizen_feedback.type', 'like', $like)
                    ->orWhereHas('office', function (Builder $officeQuery) use ($normalizedSearch) {
                        $officeQuery->whereRaw('LOWER(name) like ?', ['%'.$normalizedSearch.'%']);
                    })
                    ->orWhereHas('report', function (Builder $reportQuery) use ($search, $normalizedSearch, $numericSearch) {
                        $reportQuery
                            ->where('title', 'like', '%'.$search.'%')
                            ->orWhere('barangay', 'like', '%'.$search.'%')
                            ->orWhere('location', 'like', '%'.$search.'%');

                        if ($numericSearch !== '' && ctype_digit($numericSearch)) {
                            $reportQuery->orWhere('id', (int) $numericSearch);
                        }

                        $reportQuery->orWhereHas('office', function (Builder $officeQuery) use ($normalizedSearch) {
                            $officeQuery->whereRaw('LOWER(name) like ?', ['%'.$normalizedSearch.'%']);
                        });
                    })
                    ->orWhereHas('user', function (Builder $userQuery) use ($normalizedSearch) {
                        $userQuery
                            ->whereRaw('LOWER(name) like ?', ['%'.$normalizedSearch.'%'])
                            ->orWhereRaw('LOWER(email) like ?', ['%'.$normalizedSearch.'%']);
                    });
            });
        }
    }

    public function applyDateRangeFilter(Builder $query, array $filters): ?array
    {
        $range = $this->resolveDateRange($filters);

        if ($range === null) {
            return null;
        }

        $query->whereBetween('citizen_feedback.created_at', [$range['start'], $range['end']]);

        return $range;
    }

    public function resolveDateRange(array $filters): ?array
    {
        $days = isset($filters['days']) ? (int) $filters['days'] : null;
        if (($days ?? 0) > 0 && empty($filters['date_preset'])) {
            $today = now()->startOfDay();

            return [
                'preset' => 'rolling_days',
                'start' => $today->copy()->subDays(max(0, $days - 1)),
                'end' => $today->copy()->endOfDay(),
            ];
        }

        $preset = trim((string) ($filters['date_preset'] ?? ''));
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
            'last_90_days' => [
                'preset' => $preset,
                'start' => $today->copy()->subDays(89),
                'end' => $today->copy()->endOfDay(),
            ],
            'this_year' => [
                'preset' => $preset,
                'start' => $today->copy()->startOfYear(),
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

    public function fallbackTrendRange(Builder $query): array
    {
        $earliestCreatedAt = (clone $query)->min('citizen_feedback.created_at');
        $latestCreatedAt = (clone $query)->max('citizen_feedback.created_at');

        $start = $earliestCreatedAt === null
            ? now()->subDays(29)->startOfDay()
            : Carbon::parse($earliestCreatedAt)->startOfDay();
        $end = $latestCreatedAt === null
            ? now()->endOfDay()
            : Carbon::parse($latestCreatedAt)->endOfDay();

        if ($start->gt($end)) {
            [$start, $end] = [$end->copy()->startOfDay(), $start->copy()->endOfDay()];
        }

        return [
            'preset' => 'all_time',
            'start' => $start,
            'end' => $end,
        ];
    }

    public function buildSummary(Builder $query): array
    {
        $aggregate = (clone $query)
            ->selectRaw('COUNT(*) as total_feedback')
            ->selectRaw('COALESCE(AVG(citizen_feedback.rating), 0) as average_rating')
            ->first();

        $totalFeedback = (int) ($aggregate?->total_feedback ?? 0);
        $averageRating = round((float) ($aggregate?->average_rating ?? 0), 2);
        $recentFeedbackCount = (clone $query)
            ->where('citizen_feedback.created_at', '>=', now()->subDays(6)->startOfDay())
            ->count();

        $typeCounts = (clone $query)
            ->select('citizen_feedback.type')
            ->selectRaw('COUNT(*) as total')
            ->groupBy('citizen_feedback.type')
            ->pluck('total', 'citizen_feedback.type');

        $orderedTypes = collect($this->canonicalTypes())
            ->map(function (string $type) use ($typeCounts) {
                return [
                    'label' => $type,
                    'count' => (int) ($typeCounts[$type] ?? 0),
                ];
            });

        $extraTypes = collect($typeCounts)
            ->keys()
            ->filter(fn ($type) => ! in_array($type, $this->canonicalTypes(), true))
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

        return [
            'total_feedback' => $totalFeedback,
            'average_rating' => $averageRating,
            'recent_feedback_count' => (int) $recentFeedbackCount,
            'type_breakdown' => $typeBreakdown->all(),
            'types' => $typeBreakdown
                ->mapWithKeys(fn (array $row) => [$row['label'] => $row['count']])
                ->all(),
        ];
    }
}
