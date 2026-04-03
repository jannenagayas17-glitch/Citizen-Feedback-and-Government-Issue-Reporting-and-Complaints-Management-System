<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CitizenFeedback extends Model
{
    use HasFactory;

    protected $table = 'citizen_feedback';

    protected $fillable = [
        'user_id',
        'office_id',
        'report_id',
        'type',
        'message',
        'rating',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    public function office()
    {
        return $this->belongsTo(Office::class);
    }

    public function report()
    {
        return $this->belongsTo(Report::class);
    }
}
