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
        'assigned_to',
        'resolved_at',
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

    public function assignedAdmin()
    {
        return $this->belongsTo(User::class, 'assigned_to');
    }

    public function adminResponses()
    {
        return $this->hasMany(AdminResponse::class);
    }
}
