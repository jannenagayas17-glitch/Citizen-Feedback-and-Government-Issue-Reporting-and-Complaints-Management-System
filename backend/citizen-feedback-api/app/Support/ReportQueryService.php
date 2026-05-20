<?php

namespace App\Support;

use App\Models\Office;
use App\Models\Report;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Schema;

class ReportQueryService
{
    private ?array $reportColumns = null;

    public function __construct(
        private readonly DemoAccountService $demoAccounts,
    ) {
    }

    /**
     * @return list<string>
     */
    public function canonicalStatuses(): array
    {
        return ['New', 'Pending', 'In Progress', 'Resolved', 'Rejected'];
    }

    /**
     * @return list<string>
     */
    public function canonicalPriorities(): array
    {
        return ['Low', 'Normal', 'High', 'Urgent'];
    }

    /**
     * @return list<string>
     */
    public function allowedDatePresets(): array
    {
        return [
            'all_time',
            'weekly',
            'monthly',
            'yearly',
            'today',
            'last_7_days',
            'last_30_days',
            'custom',
        ];
    }

    public function scopedForUser($user): Builder
    {
        $query = Report::query();
        $this->excludeDemoSeedData($query);
        $role = User::normalizeRole($user->role ?? 'citizen');

        if ($role === 'citizen') {
            $query->where('reports.user_id', $user->id);
        } elseif ($role === 'admin') {
            $officeId = $this->resolveAdminOfficeId($user);

            if ($officeId === null) {
                $query->whereRaw('1 = 0');
            } else {
                $query->where('reports.office_id', $officeId);
            }
        } elseif ($role === User::ROLE_ADMINISTRATIVE_STAFF) {
            $this->applyWalkInFilter($query);
            $this->applyAdministrativeStaffOwnershipFilter($query, $user);
        }

        return $query;
    }

    /**
     * @return list<string>
     */
    public function demoSeedEmailPatterns(): array
    {
        return $this->demoAccounts->emailPatterns();
    }

    public function demoUserIdsQuery(): Builder
    {
        return $this->demoAccounts->demoUserIdsQuery();
    }

    public function applyFilters(Builder $query, array $filters, array $except = []): void
    {
        if (! in_array('status', $except, true) && ! empty($filters['status'])) {
            $query->where('reports.status', trim((string) $filters['status']));
        }

        if (! in_array('office', $except, true) && ! empty($filters['office'])) {
            $office = trim((string) $filters['office']);
            $query->whereHas('office', function (Builder $officeQuery) use ($office) {
                $officeQuery->whereRaw('LOWER(name) = ?', [mb_strtolower($office)]);
            });
        }

        if (! in_array('barangay', $except, true) && ! empty($filters['barangay'])) {
            $barangay = trim((string) $filters['barangay']);
            $query->whereRaw('LOWER(reports.barangay) = ?', [mb_strtolower($barangay)]);
        }

        if (! in_array('category', $except, true) && ! empty($filters['category'])) {
            $category = trim((string) $filters['category']);
            $query->whereHas('category', function (Builder $categoryQuery) use ($category) {
                $categoryQuery->whereRaw('LOWER(name) = ?', [mb_strtolower($category)]);
            });
        }

        if (! in_array('search', $except, true) && ! empty($filters['search'])) {
            $search = trim((string) $filters['search']);
            $normalizedSearch = mb_strtolower($search);
            $trackingId = preg_replace('/[^0-9]/', '', $search) ?? '';

            $query->where(function (Builder $searchQuery) use ($search, $normalizedSearch, $trackingId) {
                $hasCondition = false;

                if ($trackingId !== '' && ctype_digit($trackingId)) {
                    $searchQuery->where('reports.id', (int) $trackingId);
                    $hasCondition = true;
                }

                $like = '%' . $search . '%';
                $titleMethod = $hasCondition ? 'orWhere' : 'where';

                $searchQuery
                    ->{$titleMethod}('reports.title', 'like', $like)
                    ->orWhere('reports.location', 'like', $like)
                    ->orWhere('reports.barangay', 'like', $like)
                    ->orWhere('reports.status', 'like', $like)
                    ->orWhere('reports.printable_reference_number', 'like', $like)
                    ->orWhere('reports.walk_in_full_name', 'like', $like)
                    ->orWhere('reports.walk_in_contact_number', 'like', $like)
                    ->orWhereHas('category', function (Builder $categoryQuery) use ($normalizedSearch) {
                        $categoryQuery->whereRaw('LOWER(name) like ?', ['%' . $normalizedSearch . '%']);
                    })
                    ->orWhereHas('office', function (Builder $officeQuery) use ($normalizedSearch) {
                        $officeQuery->whereRaw('LOWER(name) like ?', ['%' . $normalizedSearch . '%']);
                    })
                    ->orWhereHas('user', function (Builder $userQuery) use ($normalizedSearch) {
                        $userQuery->whereRaw('LOWER(name) like ?', ['%' . $normalizedSearch . '%']);
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

        $query->whereBetween('reports.created_at', [$range['start'], $range['end']]);

        return $range;
    }

    public function canonicalDatePreset(?string $preset): string
    {
        $normalized = trim((string) $preset);

        return match ($normalized) {
            '', 'all_time' => 'all_time',
            'today' => 'today',
            'weekly' => 'weekly',
            'last_7_days' => 'last_7_days',
            'monthly' => 'monthly',
            'last_30_days' => 'last_30_days',
            'yearly' => 'yearly',
            'custom' => 'custom',
            default => 'all_time',
        };
    }

    public function resolveDateRange(array $filters): ?array
    {
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
            'weekly' => [
                'preset' => $preset,
                'start' => $today->copy()->startOfWeek(Carbon::MONDAY),
                'end' => $today->copy()->endOfDay(),
            ],
            'last_7_days' => [
                'preset' => $preset,
                'start' => $today->copy()->subDays(6),
                'end' => $today->copy()->endOfDay(),
            ],
            'monthly' => [
                'preset' => $preset,
                'start' => $today->copy()->startOfMonth(),
                'end' => $today->copy()->endOfDay(),
            ],
            'last_30_days' => [
                'preset' => $preset,
                'start' => $today->copy()->subDays(29),
                'end' => $today->copy()->endOfDay(),
            ],
            'yearly' => [
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

    public function fallbackTimelineRange(Builder $query): array
    {
        $earliestCreatedAt = (clone $query)->min('created_at');
        $latestCreatedAt = (clone $query)->max('created_at');

        $start = $earliestCreatedAt === null
            ? now()->startOfDay()
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

    public function buildOverviewCounts(Builder $query): array
    {
        $statusCounts = (clone $query)
            ->select('status')
            ->selectRaw('COUNT(*) as total')
            ->groupBy('status')
            ->pluck('total', 'status');

        $new = (int) ($statusCounts['New'] ?? 0);
        $pending = (int) ($statusCounts['Pending'] ?? 0);
        $inProgress = (int) ($statusCounts['In Progress'] ?? 0);
        $resolved = (int) ($statusCounts['Resolved'] ?? 0);
        $rejected = (int) ($statusCounts['Rejected'] ?? 0);

        return [
            'total_reports' => (clone $query)->count(),
            'new' => $new,
            'pending' => $pending,
            'in_progress' => $inProgress,
            'resolved' => $resolved,
            'rejected' => $rejected,
            'queue_count' => $new + $pending + $inProgress,
        ];
    }

    public function reportColumnExists(string $column): bool
    {
        if ($this->reportColumns === null) {
            $this->reportColumns = Schema::hasTable('reports')
                ? array_fill_keys(Schema::getColumnListing('reports'), true)
                : [];
        }

        return isset($this->reportColumns[$column]);
    }

    public function filterPersistableReportAttributes(array $attributes): array
    {
        return array_filter(
            $attributes,
            fn (string $column): bool => $this->reportColumnExists($column),
            ARRAY_FILTER_USE_KEY
        );
    }

    public function applyWalkInFilter(Builder $query): void
    {
        if ($this->reportColumnExists('source')) {
            $query->where('reports.source', 'walk_in');

            return;
        }

        $query->where(function (Builder $walkInQuery) {
            $hasMarker = false;

            if ($this->reportColumnExists('assisted_by_user_id')) {
                $walkInQuery->whereNotNull('reports.assisted_by_user_id');
                $hasMarker = true;
            }

            foreach (['walk_in_full_name', 'walk_in_contact_number', 'walk_in_address'] as $column) {
                if (! $this->reportColumnExists($column)) {
                    continue;
                }

                $callback = function (Builder $markerQuery) use ($column) {
                    $markerQuery
                        ->whereNotNull('reports.'.$column)
                        ->where('reports.'.$column, '!=', '');
                };

                if ($hasMarker) {
                    $walkInQuery->orWhere($callback);
                } else {
                    $walkInQuery->where($callback);
                    $hasMarker = true;
                }
            }

            if (! $hasMarker) {
                $walkInQuery->whereRaw('1 = 0');
            }
        });
    }

    public function resolveAdminOfficeId($user): ?int
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

    private function excludeDemoSeedData(Builder $query): void
    {
        $query->whereNotIn('reports.user_id', $this->demoUserIdsQuery());
    }

    private function applyAdministrativeStaffOwnershipFilter(Builder $query, User $user): void
    {
        $query->where(function (Builder $frontDeskQuery) use ($user) {
            if ($this->reportColumnExists('assisted_by_user_id')) {
                $frontDeskQuery
                    ->where('reports.assisted_by_user_id', $user->id)
                    ->orWhere('reports.user_id', $user->id);

                return;
            }

            $frontDeskQuery->where('reports.user_id', $user->id);
        });
    }
}
