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
}
