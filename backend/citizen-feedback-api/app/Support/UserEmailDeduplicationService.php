<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Database\Eloquent\Collection as EloquentCollection;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

class UserEmailDeduplicationService
{
    public function normalizeEmail($email): string
    {
        return mb_strtolower(trim((string) $email));
    }

    public function deduplicateUsersForDisplay(iterable $users): Collection
    {
        $collection = collect($users)
            ->filter(fn ($user) => $user instanceof User)
            ->values();

        if ($collection->isEmpty()) {
            return collect();
        }

        $relatedCounts = $this->loadRelatedRecordCounts(
            $collection->pluck('id')->filter()->map(fn ($id) => (int) $id)->all()
        );

        return $collection
            ->groupBy(fn (User $user) => $this->deduplicationKey($user))
            ->map(fn (Collection $group) => $this->pickPreferredUserFromGroup($group, $relatedCounts))
            ->filter()
            ->sortBy(fn (User $user) => $this->displaySortKey($user))
            ->values();
    }

    public function pickPreferredUser(iterable $users): ?User
    {
        $collection = collect($users)
            ->filter(fn ($user) => $user instanceof User)
            ->values();

        if ($collection->isEmpty()) {
            return null;
        }

        $relatedCounts = $this->loadRelatedRecordCounts(
            $collection->pluck('id')->filter()->map(fn ($id) => (int) $id)->all()
        );

        return $this->pickPreferredUserFromGroup($collection, $relatedCounts);
    }

    public function buildDuplicateEmailReport(?array $onlyEmails = null): array
    {
        $normalizedEmails = collect($onlyEmails ?? [])
            ->map(fn ($email) => $this->normalizeEmail($email))
            ->filter()
            ->values();

        $duplicateGroups = User::withTrashed()
            ->whereNotNull('email')
            ->orderBy('created_at')
            ->orderBy('id')
            ->get()
            ->groupBy(fn (User $user) => $this->normalizeEmail($user->email))
            ->filter(fn (Collection $group, string $email) => $email !== '' && $group->count() > 1);

        if ($normalizedEmails->isNotEmpty()) {
            $duplicateGroups = $duplicateGroups->filter(
                fn (Collection $group, string $email) => $normalizedEmails->contains($email)
            );
        }

        $allUsers = $duplicateGroups->flatten(1);
        $relatedCounts = $this->loadRelatedRecordCounts(
            $allUsers->pluck('id')->filter()->map(fn ($id) => (int) $id)->all()
        );

        $groups = $duplicateGroups
            ->map(function (Collection $group, string $email) use ($relatedCounts): array {
                $keeper = $this->pickPreferredUserFromGroup($group, $relatedCounts);
                $riskReasons = $this->riskReasons($group);
                $duplicates = $group
                    ->reject(fn (User $user) => $keeper !== null && $user->id === $keeper->id)
                    ->values();

                $groupReassignments = [
                    'reports.user_id' => 0,
                    'reports.assigned_to' => 0,
                    'citizen_feedback.user_id' => 0,
                    'admin_responses.user_id' => 0,
                    'status_histories.updated_by' => 0,
                    'report_escalations.acted_by' => 0,
                    'sessions.user_id' => 0,
                    'personal_access_tokens' => 0,
                ];

                $duplicateRows = $duplicates->map(function (User $duplicate) use ($relatedCounts, &$groupReassignments): array {
                    $summary = $this->userSummary($duplicate, $relatedCounts[$duplicate->id] ?? $this->emptyRelatedCounts());
                    foreach ($summary['related_records'] as $key => $value) {
                        if (array_key_exists($key, $groupReassignments)) {
                            $groupReassignments[$key] += $value;
                        }
                    }

                    return $summary;
                })->values()->all();

                return [
                    'normalized_email' => $email,
                    'stored_email_variants' => $group
                        ->map(fn (User $user) => trim((string) $user->email))
                        ->unique()
                        ->values()
                        ->all(),
                    'user_ids' => $group->pluck('id')->map(fn ($id) => (int) $id)->values()->all(),
                    'keeper_user_id' => $keeper?->id,
                    'keeper' => $keeper === null
                        ? null
                        : $this->userSummary($keeper, $relatedCounts[$keeper->id] ?? $this->emptyRelatedCounts()),
                    'duplicate_user_ids' => $duplicates
                        ->pluck('id')
                        ->map(fn ($id) => (int) $id)
                        ->values()
                        ->all(),
                    'duplicates' => $duplicateRows,
                    'group_related_records' => $groupReassignments,
                    'risk_reasons' => $riskReasons,
                    'can_apply' => $keeper !== null && $duplicates->isNotEmpty() && $riskReasons === [],
                ];
            })
            ->values()
            ->all();

        return [
            'generated_at' => now()->toIso8601String(),
            'group_count' => count($groups),
            'applicable_group_count' => collect($groups)->where('can_apply', true)->count(),
            'risky_group_count' => collect($groups)->where('can_apply', false)->count(),
            'groups' => $groups,
        ];
    }

    public function applyDuplicateEmailCleanup(?array $onlyEmails = null): array
    {
        $report = $this->buildDuplicateEmailReport($onlyEmails);
        $appliedGroups = [];
        $skippedGroups = [];

        foreach ($report['groups'] as $group) {
            if (! ($group['can_apply'] ?? false)) {
                $skippedGroups[] = [
                    'normalized_email' => $group['normalized_email'] ?? '',
                    'reason' => ($group['risk_reasons'] ?? []) !== []
                        ? implode(' ', $group['risk_reasons'])
                        : 'No duplicate records were eligible to apply.',
                ];
                continue;
            }

            try {
                $appliedGroups[] = $this->applyDuplicateGroup($group);
            } catch (\Throwable $exception) {
                $skippedGroups[] = [
                    'normalized_email' => $group['normalized_email'] ?? '',
                    'reason' => $exception->getMessage(),
                ];
            }
        }

        $report['applied_group_count'] = count($appliedGroups);
        $report['applied_groups'] = $appliedGroups;
        $report['skipped_apply_groups'] = $skippedGroups;

        return $report;
    }

    public function writeAuditLog(array $report, string $mode): string
    {
        $timestamp = now()->format('Ymd-His');
        $path = sprintf('user-dedupe-audits/%s-%s.json', $timestamp, $mode);

        Storage::disk('local')->put(
            $path,
            json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES)
        );

        return $path;
    }

    private function applyDuplicateGroup(array $group): array
    {
        $keeperId = (int) ($group['keeper_user_id'] ?? 0);
        $duplicateIds = collect($group['duplicate_user_ids'] ?? [])
            ->map(fn ($id) => (int) $id)
            ->filter()
            ->values()
            ->all();

        if ($keeperId <= 0 || $duplicateIds === []) {
            throw new \RuntimeException('This duplicate group does not have a valid keeper and duplicate list.');
        }

        $actions = [];

        DB::transaction(function () use ($keeperId, $duplicateIds, &$actions): void {
            /** @var User $keeper */
            $keeper = User::withTrashed()->findOrFail($keeperId);

            foreach ($duplicateIds as $duplicateId) {
                if ($duplicateId === $keeperId) {
                    continue;
                }

                /** @var User $duplicate */
                $duplicate = User::withTrashed()->findOrFail($duplicateId);

                $this->mergeMissingKeeperFields($keeper, $duplicate);

                $businessReassignments = $this->reassignBusinessRecords(
                    fromUserId: $duplicateId,
                    toUserId: $keeperId,
                );
                $authCleanup = $this->clearDuplicateAuthArtifacts($duplicateId);

                $duplicate->is_active = false;
                $duplicate->save();

                if (! $duplicate->trashed()) {
                    $duplicate->delete();
                }

                $actions[] = [
                    'duplicate_user_id' => $duplicateId,
                    'reassigned_records' => $businessReassignments,
                    'auth_cleanup' => $authCleanup,
                    'archived' => true,
                ];
            }

            if ($keeper->trashed()) {
                $keeper->restore();
            }

            if (! $keeper->is_active) {
                $keeper->is_active = true;
            }

            $keeper->save();
        });

        return [
            'normalized_email' => $group['normalized_email'] ?? '',
            'keeper_user_id' => $keeperId,
            'duplicate_user_ids' => $duplicateIds,
            'actions' => $actions,
        ];
    }

    private function deduplicationKey(User $user): string
    {
        $normalizedEmail = $this->normalizeEmail($user->email);

        if ($normalizedEmail !== '') {
            return 'email:'.$normalizedEmail;
        }

        return 'id:'.$user->id;
    }

    private function pickPreferredUserFromGroup(Collection $group, array $relatedCounts): ?User
    {
        /** @var User|null $preferred */
        $preferred = null;

        foreach ($group as $candidate) {
            if (! $candidate instanceof User) {
                continue;
            }

            if ($preferred === null || $this->isPreferredCandidate($candidate, $preferred, $relatedCounts)) {
                $preferred = $candidate;
            }
        }

        return $preferred;
    }

    private function isPreferredCandidate(User $candidate, User $current, array $relatedCounts): bool
    {
        $candidateVerified = $this->isVerifiedAndActive($candidate);
        $currentVerified = $this->isVerifiedAndActive($current);
        if ($candidateVerified !== $currentVerified) {
            return $candidateVerified;
        }

        $candidateActive = $this->isActiveAndNotArchived($candidate);
        $currentActive = $this->isActiveAndNotArchived($current);
        if ($candidateActive !== $currentActive) {
            return $candidateActive;
        }

        $candidateRelated = $relatedCounts[$candidate->id]['business_total'] ?? 0;
        $currentRelated = $relatedCounts[$current->id]['business_total'] ?? 0;
        if ($candidateRelated !== $currentRelated) {
            return $candidateRelated > $currentRelated;
        }

        $candidateCompleteness = $this->completenessScore($candidate);
        $currentCompleteness = $this->completenessScore($current);
        if ($candidateCompleteness !== $currentCompleteness) {
            return $candidateCompleteness > $currentCompleteness;
        }

        $candidateCreatedAt = $candidate->created_at?->getTimestamp() ?? PHP_INT_MAX;
        $currentCreatedAt = $current->created_at?->getTimestamp() ?? PHP_INT_MAX;
        if ($candidateCreatedAt !== $currentCreatedAt) {
            return $candidateCreatedAt < $currentCreatedAt;
        }

        return $candidate->id < $current->id;
    }

    private function completenessScore(User $user): int
    {
        $fields = [
            trim((string) $user->name),
            $this->normalizeEmail($user->email),
            trim((string) ($user->mobile_number ?? '')),
            trim((string) ($user->department ?? '')),
            trim((string) ($user->job_title ?? '')),
            trim((string) ($user->firebase_uid ?? '')),
        ];

        return collect($fields)->filter(fn ($value) => $value !== '')->count();
    }

    private function isVerifiedAndActive(User $user): bool
    {
        return ! $user->trashed()
            && $user->is_active === true
            && $user->email_verified_at !== null;
    }

    private function isActiveAndNotArchived(User $user): bool
    {
        return ! $user->trashed() && $user->is_active === true;
    }

    private function displaySortKey(User $user): string
    {
        return implode('|', [
            str_pad((string) $this->rolePriority($user), 2, '0', STR_PAD_LEFT),
            mb_strtolower(trim((string) $user->name)),
            $this->normalizeEmail($user->email),
            str_pad((string) $user->id, 10, '0', STR_PAD_LEFT),
        ]);
    }

    private function rolePriority(User $user): int
    {
        return match ($user->role) {
            'super_admin' => 0,
            'admin' => 1,
            'pending_admin' => 2,
            'citizen' => 3,
            default => 9,
        };
    }

    private function riskReasons(Collection $group): array
    {
        $reasons = [];
        $roles = $group
            ->map(fn (User $user) => (string) $user->role)
            ->filter()
            ->unique()
            ->values();

        if ($roles->contains('super_admin')) {
            $reasons[] = 'Contains a super admin account and requires manual review.';
        }

        $containsCitizen = $roles->contains('citizen');
        $containsStaff = $roles->contains(fn ($role) => in_array($role, ['admin', 'pending_admin'], true));
        if ($containsCitizen && $containsStaff) {
            $reasons[] = 'Contains both citizen and staff roles with the same email.';
        }

        $staffDepartments = $group
            ->filter(fn (User $user) => in_array($user->role, ['admin', 'pending_admin'], true))
            ->map(fn (User $user) => trim((string) ($user->department ?? '')))
            ->filter()
            ->unique()
            ->values();
        if ($staffDepartments->count() > 1) {
            $reasons[] = 'Staff accounts belong to different departments.';
        }

        return $reasons;
    }

    private function userSummary(User $user, array $relatedRecords): array
    {
        return [
            'id' => $user->id,
            'name' => $user->name,
            'email' => trim((string) $user->email),
            'normalized_email' => $this->normalizeEmail($user->email),
            'mobile_number' => $user->mobile_number,
            'role' => $user->role,
            'department' => $user->department,
            'job_title' => $user->job_title,
            'is_active' => (bool) $user->is_active,
            'is_archived' => $user->trashed(),
            'email_verified_at' => $user->email_verified_at?->toIso8601String(),
            'created_at' => $user->created_at?->toIso8601String(),
            'related_records' => $relatedRecords,
        ];
    }

    private function emptyRelatedCounts(): array
    {
        return [
            'reports.user_id' => 0,
            'reports.assigned_to' => 0,
            'citizen_feedback.user_id' => 0,
            'admin_responses.user_id' => 0,
            'status_histories.updated_by' => 0,
            'report_escalations.acted_by' => 0,
            'sessions.user_id' => 0,
            'personal_access_tokens' => 0,
            'business_total' => 0,
        ];
    }

    private function loadRelatedRecordCounts(array $userIds): array
    {
        $userIds = collect($userIds)
            ->map(fn ($id) => (int) $id)
            ->filter(fn ($id) => $id > 0)
            ->values()
            ->all();

        if ($userIds === []) {
            return [];
        }

        $counts = [];
        foreach ($userIds as $userId) {
            $counts[$userId] = $this->emptyRelatedCounts();
        }

        $this->applyCountsToMap($counts, 'reports.user_id', $this->countByColumn('reports', 'user_id', $userIds));
        $this->applyCountsToMap($counts, 'reports.assigned_to', $this->countByColumn('reports', 'assigned_to', $userIds));
        $this->applyCountsToMap($counts, 'citizen_feedback.user_id', $this->countByColumn('citizen_feedback', 'user_id', $userIds));
        $this->applyCountsToMap($counts, 'admin_responses.user_id', $this->countByColumn('admin_responses', 'user_id', $userIds));
        $this->applyCountsToMap($counts, 'status_histories.updated_by', $this->countByColumn('status_histories', 'updated_by', $userIds));
        $this->applyCountsToMap($counts, 'report_escalations.acted_by', $this->countByColumn('report_escalations', 'acted_by', $userIds));
        $this->applyCountsToMap($counts, 'sessions.user_id', $this->countByColumn('sessions', 'user_id', $userIds));
        $this->applyCountsToMap(
            $counts,
            'personal_access_tokens',
            $this->countByColumn(
                table: 'personal_access_tokens',
                column: 'tokenable_id',
                userIds: $userIds,
                extraWhere: fn ($query) => $query->where('tokenable_type', User::class),
            ),
        );

        foreach ($counts as $userId => $related) {
            $counts[$userId]['business_total'] = $related['reports.user_id']
                + $related['reports.assigned_to']
                + $related['citizen_feedback.user_id']
                + $related['admin_responses.user_id']
                + $related['status_histories.updated_by']
                + $related['report_escalations.acted_by'];
        }

        return $counts;
    }

    private function applyCountsToMap(array &$counts, string $key, array $values): void
    {
        foreach ($values as $userId => $count) {
            if (! array_key_exists($userId, $counts)) {
                $counts[$userId] = $this->emptyRelatedCounts();
            }

            $counts[$userId][$key] = (int) $count;
        }
    }

    private function countByColumn(
        string $table,
        string $column,
        array $userIds,
        ?callable $extraWhere = null,
    ): array {
        $query = DB::table($table)
            ->selectRaw($column.' as user_id, COUNT(*) as aggregate_count')
            ->whereIn($column, $userIds)
            ->groupBy($column);

        if ($extraWhere !== null) {
            $extraWhere($query);
        }

        return $query
            ->pluck('aggregate_count', 'user_id')
            ->map(fn ($count) => (int) $count)
            ->all();
    }

    private function reassignBusinessRecords(int $fromUserId, int $toUserId): array
    {
        return [
            'reports.user_id' => DB::table('reports')
                ->where('user_id', $fromUserId)
                ->update(['user_id' => $toUserId]),
            'reports.assigned_to' => DB::table('reports')
                ->where('assigned_to', $fromUserId)
                ->update(['assigned_to' => $toUserId]),
            'citizen_feedback.user_id' => DB::table('citizen_feedback')
                ->where('user_id', $fromUserId)
                ->update(['user_id' => $toUserId]),
            'admin_responses.user_id' => DB::table('admin_responses')
                ->where('user_id', $fromUserId)
                ->update(['user_id' => $toUserId]),
            'status_histories.updated_by' => DB::table('status_histories')
                ->where('updated_by', $fromUserId)
                ->update(['updated_by' => $toUserId]),
            'report_escalations.acted_by' => DB::table('report_escalations')
                ->where('acted_by', $fromUserId)
                ->update(['acted_by' => $toUserId]),
            'sessions.user_id' => DB::table('sessions')
                ->where('user_id', $fromUserId)
                ->delete(),
        ];
    }

    private function clearDuplicateAuthArtifacts(int $userId): array
    {
        return [
            'personal_access_tokens' => DB::table('personal_access_tokens')
                ->where('tokenable_type', User::class)
                ->where('tokenable_id', $userId)
                ->delete(),
        ];
    }

    private function mergeMissingKeeperFields(User $keeper, User $duplicate): void
    {
        $updated = false;

        if ($keeper->trashed() && ! $duplicate->trashed()) {
            $keeper->restore();
            $updated = true;
        }

        if (! $keeper->is_active && $duplicate->is_active) {
            $keeper->is_active = true;
            $updated = true;
        }

        if ($keeper->email_verified_at === null && $duplicate->email_verified_at !== null) {
            $keeper->email_verified_at = $duplicate->email_verified_at;
            $updated = true;
        }

        foreach (['mobile_number', 'department', 'job_title', 'firebase_uid'] as $field) {
            $keeperValue = trim((string) ($keeper->{$field} ?? ''));
            $duplicateValue = trim((string) ($duplicate->{$field} ?? ''));
            if ($keeperValue === '' && $duplicateValue !== '') {
                $keeper->{$field} = $duplicate->{$field};
                $updated = true;
            }
        }

        $keeperName = trim((string) $keeper->name);
        $duplicateName = trim((string) $duplicate->name);
        if ($keeperName === '' && $duplicateName !== '') {
            $keeper->name = $duplicate->name;
            $updated = true;
        }

        if ($keeper->role === 'pending_admin' && $duplicate->role === 'admin') {
            $keeper->role = 'admin';
            $updated = true;
        }

        if ($updated) {
            $keeper->save();
        }
    }
}
