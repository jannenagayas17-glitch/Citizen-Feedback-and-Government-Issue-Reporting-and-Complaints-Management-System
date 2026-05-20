<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Factories\HasFactory;

class Report extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'category_id',
        'office_id',
        'title',
        'description',
        'location',
        'barangay',
        'latitude',
        'longitude',
        'status',
        'priority',
        'is_anonymous',
        'source',
        'assisted_by_user_id',
        'assisted_by_role',
        'walk_in_full_name',
        'walk_in_contact_number',
        'walk_in_email',
        'walk_in_address',
        'walk_in_is_senior_citizen',
        'walk_in_is_pwd',
        'expected_return_at',
        'printable_reference_number',
        'assigned_to',
        'resolved_at',
    ];

    protected $casts = [
        'is_anonymous' => 'bool',
        'walk_in_is_senior_citizen' => 'bool',
        'walk_in_is_pwd' => 'bool',
        'expected_return_at' => 'datetime',
        'resolved_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function category()
    {
        return $this->belongsTo(Category::class);
    }

    public function office()
    {
        return $this->belongsTo(Office::class);
    }

    public function images()
    {
        return $this->hasMany(ReportImage::class);
    }

    public function statusHistories()
    {
        return $this->hasMany(StatusHistory::class);
    }

    public function latestStatusHistory()
    {
        return $this->hasOne(StatusHistory::class)->latestOfMany();
    }

    public function assignedAdmin()
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }

    public function assistedByUser()
    {
        return $this->belongsTo(User::class, 'assisted_by_user_id');
    }

    public function adminResponses()
    {
        return $this->hasMany(AdminResponse::class);
    }

    public function latestAdminResponse()
    {
        return $this->hasOne(AdminResponse::class)->latestOfMany();
    }

    public function feedbackEntries()
    {
        return $this->hasMany(CitizenFeedback::class);
    }

    public function escalation()
    {
        return $this->hasOne(ReportEscalation::class);
    }

    public function hidesReporterIdentityFrom($viewer): bool
    {
        $viewerRole = User::normalizeRole($viewer->role ?? 'citizen');

        return $this->is_anonymous
            && in_array($viewerRole, ['admin', 'super_admin'], true);
    }

    public function isWalkInComplaint(): bool
    {
        if (trim((string) $this->source) === 'walk_in') {
            return true;
        }

        if (($this->assisted_by_user_id ?? null) !== null) {
            return true;
        }

        foreach ([
            $this->walk_in_full_name ?? null,
            $this->walk_in_contact_number ?? null,
            $this->walk_in_address ?? null,
        ] as $value) {
            if (trim((string) $value) !== '') {
                return true;
            }
        }

        return false;
    }

    public function reporterNameForViewer($viewer): string
    {
        if ($this->isWalkInComplaint()) {
            $name = trim((string) $this->walk_in_full_name);

            return $name === '' ? 'Walk-in complainant' : $name;
        }

        if ($this->hidesReporterIdentityFrom($viewer)) {
            return 'Anonymous Citizen';
        }

        $name = trim((string) optional($this->user)->name);

        return $name === '' ? 'Unknown citizen' : $name;
    }

    public function reporterEmailForViewer($viewer): ?string
    {
        if ($this->isWalkInComplaint()) {
            $email = trim((string) $this->walk_in_email);

            return $email === '' ? null : $email;
        }

        if ($this->hidesReporterIdentityFrom($viewer)) {
            return null;
        }

        $email = trim((string) optional($this->user)->email);

        return $email === '' ? null : $email;
    }

    public function reporterContactNumberForViewer($viewer): ?string
    {
        if ($this->isWalkInComplaint()) {
            $contactNumber = trim((string) $this->walk_in_contact_number);

            return $contactNumber === '' ? null : $contactNumber;
        }

        if ($this->hidesReporterIdentityFrom($viewer)) {
            return null;
        }

        $mobileNumber = trim((string) optional($this->user)->mobile_number);

        return $mobileNumber === '' ? null : $mobileNumber;
    }

    public function reporterAddressForViewer($viewer): ?string
    {
        if ($this->isWalkInComplaint()) {
            $address = trim((string) $this->walk_in_address);

            return $address === '' ? null : $address;
        }

        $location = trim((string) $this->location);
        $barangay = trim((string) $this->barangay);

        if ($barangay !== '' && $location !== '') {
            return $barangay.', '.$location;
        }

        return $barangay !== '' ? $barangay : ($location === '' ? null : $location);
    }

    public function sanitizedUserPayloadForViewer($viewer): ?array
    {
        if ($this->isWalkInComplaint()) {
            return [
                'id' => null,
                'name' => $this->reporterNameForViewer($viewer),
                'email' => $this->reporterEmailForViewer($viewer),
                'mobile_number' => $this->reporterContactNumberForViewer($viewer),
                'address' => $this->reporterAddressForViewer($viewer),
                'is_anonymous' => false,
                'is_walk_in' => true,
                'is_senior_citizen' => (bool) $this->walk_in_is_senior_citizen,
                'is_pwd' => (bool) $this->walk_in_is_pwd,
            ];
        }

        if ($this->hidesReporterIdentityFrom($viewer)) {
            return [
                'id' => null,
                'name' => 'Anonymous Citizen',
                'email' => null,
                'mobile_number' => null,
                'is_anonymous' => true,
                'is_walk_in' => false,
            ];
        }

        if ($this->user === null) {
            return null;
        }

        $payload = $this->user->toArray();
        $payload['is_anonymous'] = (bool) $this->is_anonymous;
        $payload['is_walk_in'] = false;

        return $payload;
    }

    public function assistedByRole(): ?string
    {
        $storedRole = trim((string) $this->assisted_by_role);
        if ($storedRole !== '') {
            return User::normalizeRole($storedRole);
        }

        if ($this->assistedByUser !== null) {
            return $this->assistedByUser->normalizedRole();
        }

        return null;
    }

    public function assistedByRoleLabel(): ?string
    {
        return match ($this->assistedByRole()) {
            User::ROLE_ADMINISTRATIVE_STAFF => 'Administrative Staff',
            'admin' => 'Administrator',
            'super_admin' => 'Super Admin',
            default => null,
        };
    }
}
