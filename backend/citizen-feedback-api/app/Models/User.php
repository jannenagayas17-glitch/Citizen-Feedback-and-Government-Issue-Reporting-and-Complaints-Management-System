<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Database\Eloquent\SoftDeletes;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable, SoftDeletes;

    public const ROLE_ADMINISTRATIVE_STAFF = 'administrative_staff';
    public const ROLE_FRONT_DESK = 'front_desk';

    protected $fillable = [
        'name',
        'email',
        'mobile_number',
        'password',
        'role',
        'is_active',
        'department',
        'job_title',
        'firebase_uid',
        'profile_image_path',
    ];

    protected $appends = [
        'profile_image_url',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'is_active' => 'boolean',
            'deleted_at' => 'datetime',
        ];
    }

    public function reports()
    {
        return $this->hasMany(Report::class);
    }

    public function statusHistories()
    {
        return $this->hasMany(StatusHistory::class, 'updated_by');
    }

    public function adminResponses()
    {
        return $this->hasMany(AdminResponse::class);
    }

    public function feedbackEntries()
    {
        return $this->hasMany(CitizenFeedback::class);
    }

    public function escalationActions()
    {
        return $this->hasMany(ReportEscalation::class, 'acted_by');
    }

    public function isDepartmentHead(): bool
    {
        if ($this->role !== 'admin') {
            return false;
        }

        $title = strtolower(trim((string) $this->job_title));

        return str_contains($title, 'head')
            || str_contains($title, 'chief')
            || str_contains($title, 'director');
    }

    public static function normalizeRole(?string $role): string
    {
        $normalized = strtolower(trim((string) $role));

        return match ($normalized) {
            self::ROLE_FRONT_DESK => self::ROLE_ADMINISTRATIVE_STAFF,
            'staff' => 'admin',
            default => $normalized === '' ? 'citizen' : $normalized,
        };
    }

    public function normalizedRole(): string
    {
        return self::normalizeRole($this->role);
    }

    public function hasAdministrativeStaffRole(): bool
    {
        return $this->normalizedRole() === self::ROLE_ADMINISTRATIVE_STAFF;
    }

    public function getProfileImageUrlAttribute(): ?string
    {
        $path = trim((string) ($this->profile_image_path ?? ''));

        if ($path === '') {
            return null;
        }

        if (filter_var($path, FILTER_VALIDATE_URL)) {
            return $path;
        }

        $normalizedPath = ltrim($path, '/');
        if (str_starts_with($normalizedPath, 'public/')) {
            $normalizedPath = substr($normalizedPath, strlen('public/'));
        }

        if (str_starts_with($normalizedPath, 'storage/')) {
            $normalizedPath = substr($normalizedPath, strlen('storage/'));
        }

        if ($normalizedPath === '') {
            return null;
        }

        return url('/api/profile-images/'.$normalizedPath);
    }
}
