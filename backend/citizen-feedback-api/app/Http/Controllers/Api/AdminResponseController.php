<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminResponse;
use App\Models\Report;
use Illuminate\Http\Request;

class AdminResponseController extends Controller
{
    public function store(Request $request, $reportId)
    {
        $request->validate([
            'response' => 'required|string',
        ]);

        if (!in_array($request->user()->role, ['admin', 'staff'])) {
            return response()->json([
                'message' => 'Unauthorized. Only admin or staff can respond to reports.'
            ], 403);
        }

        $report = Report::findOrFail($reportId);

        $adminResponse = AdminResponse::create([
            'report_id' => $report->id,
            'user_id' => $request->user()->id,
            'response' => $request->response,
        ]);

        return response()->json([
            'message' => 'Admin response added successfully',
            'admin_response' => $adminResponse,
        ], 201);
    }
}