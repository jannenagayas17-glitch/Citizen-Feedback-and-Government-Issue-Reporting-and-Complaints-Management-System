<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;

class DashboardController extends Controller
{
    public function index()
    {
        return response()->json([
            'total_reports' => Report::count(),
            'pending' => Report::where('status', 'Pending')->count(),
            'in_progress' => Report::where('status', 'In Progress')->count(),
            'resolved' => Report::where('status', 'Resolved')->count(),
            'rejected' => Report::where('status', 'Rejected')->count(),
        ]);
    }
}