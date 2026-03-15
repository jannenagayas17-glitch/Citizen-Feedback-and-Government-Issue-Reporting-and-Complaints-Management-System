<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminResponse;
use App\Models\Report;
use App\Models\StatusHistory;
use Illuminate\Http\Request;

class ReportController extends Controller
{
    public function index(Request $request)
    {
        $query = Report::with(['user', 'category', 'images']);

        if (($request->user()->role ?? 'citizen') === 'citizen') {
            $query->where('user_id', $request->user()->id);
        }

        if ($request->has('status')) {
        $query->where('status', $request->status);
        }

        if ($request->has('category_id')) {
        $query->where('category_id', $request->category_id);
        }

        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        $request->validate([
            'category_id' => 'required|exists:categories,id',
            'title' => 'required|string|max:255',
            'description' => 'required|string',
            'location' => 'nullable|string|max:255',
            'barangay' => 'nullable|string|max:255',
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'priority' => 'nullable|string|in:Low,Normal,High,Urgent',
        ]);

        $report = Report::create([
            'user_id' => $request->user()->id,
            'category_id' => $request->category_id,
            'title' => $request->title,
            'description' => $request->description,
            'location' => $request->location,
            'barangay' => $request->barangay,
            'latitude' => $request->latitude,
            'longitude' => $request->longitude,
            'status' => 'New',
            'priority' => $request->priority ?? 'Normal',
        ]);

        return response()->json([
            'message' => 'Report created successfully',
            'report' => $report,
        ], 201);
    }

    public function show(Request $request, $id)
    {
        $report = Report::with([
            'user',
            'category',
            'images',
            'statusHistories.user',
            'adminResponses.user'
        ])->findOrFail($id);

        if (($request->user()->role ?? 'citizen') === 'citizen' &&
            $report->user_id !== $request->user()->id) {
            abort(403, 'Unauthorized action.');
        }

        return response()->json($report);
    }

    public function adminReports(Request $request)
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $query = Report::with(['user', 'category', 'images'])->latest();

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        return response()->json($query->get());
    }

    public function updateStatus(Request $request, $id)
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $validated = $request->validate([
            'status' => 'required|string|in:New,Pending,In Progress,Resolved',
            'remarks' => 'nullable|string|max:2000',
        ]);

        $report = Report::findOrFail($id);
        $oldStatus = $report->status;
        $report->status = $validated['status'];
        $report->resolved_at = $validated['status'] === 'Resolved' ? now() : null;
        $report->save();

        StatusHistory::create([
            'report_id' => $report->id,
            'old_status' => $oldStatus,
            'new_status' => $validated['status'],
            'remarks' => $validated['remarks'] ?? null,
            'updated_by' => $request->user()->id,
        ]);

        if (! empty($validated['remarks'])) {
            AdminResponse::create([
                'report_id' => $report->id,
                'user_id' => $request->user()->id,
                'response' => $validated['remarks'],
            ]);
        }

        return response()->json([
            'message' => 'Report status updated successfully',
            'report' => $report->load(['user', 'category', 'images']),
        ]);
    }
}
