<?php

namespace App\Support;

use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Collection;

class DemoAccountService
{
    /**
     * @var list<string>
     */
    private const EMAIL_PATTERNS = [
        'demo.admin.%@citytrack.test',
        'demo.citizen.%',
        'demo.super_admin.%@citytrack.test',
        'demo.superadmin.%@citytrack.test',
    ];

    /**
     * @return list<string>
     */
    public function emailPatterns(): array
    {
        return self::EMAIL_PATTERNS;
    }

    public function scopeDemoUsers(Builder $query, string $column = 'email'): Builder
    {
        return $query->where(function (Builder $patternQuery) use ($column) {
            foreach (self::EMAIL_PATTERNS as $index => $pattern) {
                $method = $index === 0 ? 'where' : 'orWhere';
                $patternQuery->{$method}($column, 'like', $pattern);
            }
        });
    }

    public function scopeRealUsers(Builder $query, string $column = 'email'): Builder
    {
        return $query->where(function (Builder $patternQuery) use ($column) {
            foreach (self::EMAIL_PATTERNS as $pattern) {
                $patternQuery->where($column, 'not like', $pattern);
            }
        });
    }

    public function demoUserIdsQuery(): Builder
    {
        return $this->scopeDemoUsers(
            User::withTrashed()->select('id')
        );
    }

    public function matchesEmail(?string $email): bool
    {
        $normalizedEmail = mb_strtolower(trim((string) $email));
        if ($normalizedEmail === '') {
            return false;
        }

        foreach (self::EMAIL_PATTERNS as $pattern) {
            $expression = '/^'
                . str_replace(['%', '_'], ['.*', '.'], preg_quote(mb_strtolower($pattern), '/'))
                . '$/i';

            if (preg_match($expression, $normalizedEmail) === 1) {
                return true;
            }
        }

        return false;
    }

    public function previewDemoUsers(): Collection
    {
        return $this->scopeDemoUsers(
            User::withTrashed()
                ->orderByRaw(
                    "case when role = 'super_admin' then 0 when role = 'admin' then 1 when role = 'pending_admin' then 2 else 3 end"
                )
                ->orderBy('email')
        )->get();
    }

    public function archiveDemoUsers(): array
    {
        $users = $this->previewDemoUsers();
        $roleCounts = $this->emptyRoleCounts();
        $archivedCount = 0;
        $alreadyArchivedCount = 0;
        $deactivatedCount = 0;

        foreach ($users as $user) {
            $roleCounts[$this->roleBucket((string) $user->role)]++;
            $user->tokens()->delete();

            if ($user->is_active) {
                $user->is_active = false;
                $user->save();
                $deactivatedCount++;
            }

            if ($user->trashed()) {
                $alreadyArchivedCount++;

                continue;
            }

            $user->delete();
            $archivedCount++;
        }

        return [
            'matched_count' => $users->count(),
            'archived_count' => $archivedCount,
            'already_archived_count' => $alreadyArchivedCount,
            'deactivated_count' => $deactivatedCount,
            'role_counts' => $roleCounts,
            'emails' => $users
                ->pluck('email')
                ->map(fn ($email) => trim((string) $email))
                ->filter()
                ->values()
                ->all(),
        ];
    }

    public function summarizePreview(Collection $users): array
    {
        $roleCounts = $this->emptyRoleCounts();

        foreach ($users as $user) {
            if (! $user instanceof User) {
                continue;
            }

            $roleCounts[$this->roleBucket((string) $user->role)]++;
        }

        return [
            'matched_count' => $users->count(),
            'role_counts' => $roleCounts,
            'emails' => $users
                ->pluck('email')
                ->map(fn ($email) => trim((string) $email))
                ->filter()
                ->values()
                ->all(),
        ];
    }

    /**
     * @return array{citizen:int,admin:int,pending_admin:int,super_admin:int,other:int}
     */
    private function emptyRoleCounts(): array
    {
        return [
            'citizen' => 0,
            'admin' => 0,
            'pending_admin' => 0,
            'super_admin' => 0,
            'other' => 0,
        ];
    }

    private function roleBucket(string $role): string
    {
        return match ($role) {
            'citizen', 'admin', 'pending_admin', 'super_admin' => $role,
            default => 'other',
        };
    }
}
