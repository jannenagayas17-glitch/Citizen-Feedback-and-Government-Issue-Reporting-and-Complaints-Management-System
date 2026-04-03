<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ReportEscalation extends Model
{
    use HasFactory;

    protected $fillable = [
        'report_id',
        'status',
        'notes',
        'escalated_at',
        'last_action_at',
        'acted_by',
    ];

    protected function casts(): array
    {
        return [
            'escalated_at' => 'datetime',
            'last_action_at' => 'datetime',
        ];
    }

    public function report()
    {
        return $this->belongsTo(Report::class);
    }

    public function actor()
    {
        return $this->belongsTo(User::class, 'acted_by');
    }
}
