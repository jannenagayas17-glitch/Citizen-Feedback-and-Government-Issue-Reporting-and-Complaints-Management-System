<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\StatusHistory;
use Illuminate\Http\Request;

class StatusHistoryController extends Controller
{
    public function store(Request $request, $reportId)
    {
        $request->validate([
            'new_status' => 'required|string|in:Pending,In Progress,Resolved,Rejected',
            'remarks' => 'nullable|string',
        ]);

        if (!in_array($request->user()->role, ['admin', 'staff'])) {
            return response()->json([
                'message' => 'Unauthorized. Only admin or staff can update report status.'
            ], 403);
        }

        $report = Report::findOrFail($reportId);

        $history = StatusHistory::create([
            'report_id' => $report->id,
            'old_status' => $report->status,
            'new_status' => $request->new_status,
            'remarks' => $request->remarks,
            'updated_by' => $request->user()->id,
        ]);

        $report->update([
            'status' => $request->new_status,
        ]);

        return response()->json([
            'message' => 'Report status updated successfully',
            'history' => $history,
            'report' => $report,
        ]);
    }
}