<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminResponse;
use App\Models\Category;
use App\Models\Report;
use App\Models\StatusHistory;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    private const EMOJI_REGEX = '/[\x{1F1E6}-\x{1F1FF}\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]/u';

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
        $validated = $request->validate([
            'category_id' => 'nullable|exists:categories,id',
            'category_name' => ['nullable', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'title' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'description' => ['required', 'string', 'not_regex:' . self::EMOJI_REGEX],
            'location' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'barangay' => ['nullable', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'priority' => 'nullable|string|in:Low,Normal,High,Urgent',
        ], [
            'category_name.not_regex' => 'Emoji characters are not allowed.',
            'title.not_regex' => 'Emoji characters are not allowed.',
            'description.not_regex' => 'Emoji characters are not allowed.',
            'location.not_regex' => 'Emoji characters are not allowed.',
            'barangay.not_regex' => 'Emoji characters are not allowed.',
            'location.required' => 'Location is required.',
        ]);

        $categoryId = $validated['category_id'] ?? null;

        if ($categoryId === null) {
            $categoryName = trim((string) ($validated['category_name'] ?? ''));

            if ($categoryName === '') {
                return response()->json([
                    'message' => 'A category is required.',
                    'errors' => [
                        'category' => ['The category field is required.'],
                    ],
                ], 422);
            }

            $category = Category::firstOrCreate(
                ['name' => $categoryName],
                ['description' => $categoryName . ' reports']
            );

            $categoryId = $category->id;
        }

        $report = Report::create([
            'user_id' => $request->user()->id,
            'category_id' => $categoryId,
            'title' => $validated['title'],
            'description' => $validated['description'],
            'location' => $validated['location'] ?? null,
            'barangay' => $validated['barangay'] ?? null,
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
            'status' => 'New',
            'priority' => $validated['priority'] ?? 'Normal',
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

    public function exportAdminReports(Request $request): StreamedResponse
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $query = Report::with(['user', 'category'])->latest();

        if ($request->filled('status')) {
            $query->where('status', $request->string('status')->toString());
        }

        $reports = $query->get();
        $fileName = 'engineering-reports-' . now()->format('Ymd-His') . '.xls';

        return response()->streamDownload(function () use ($reports) {
            echo <<<HTML
<html>
<head>
  <meta charset="UTF-8">
  <style>
    body {
      font-family: Arial, sans-serif;
      font-size: 12px;
      color: #1f2937;
    }
    .sheet-title {
      font-size: 18px;
      font-weight: bold;
      color: #0f172a;
      margin-bottom: 6px;
    }
    .sheet-subtitle {
      color: #475569;
      margin-bottom: 14px;
    }
    table {
      border-collapse: collapse;
      width: 100%;
    }
    th, td {
      border: 1px solid #cbd5e1;
      padding: 8px 10px;
      vertical-align: top;
      text-align: left;
    }
    th {
      background: #1d4ed8;
      color: #ffffff;
      font-weight: bold;
      white-space: nowrap;
    }
    tr:nth-child(even) td {
      background: #f8fafc;
    }
    .status-pending { color: #b45309; font-weight: bold; }
    .status-in-progress { color: #7c3aed; font-weight: bold; }
    .status-resolved { color: #15803d; font-weight: bold; }
    .status-new { color: #2563eb; font-weight: bold; }
    .muted { color: #64748b; }
  </style>
</head>
<body>
  <div class="sheet-title">Tacloban City Engineering Office Reports</div>
  <div class="sheet-subtitle">Generated at: 
HTML;
            echo e(now()->format('F j, Y g:i A'));
            echo <<<HTML
  </div>
  <table>
    <thead>
      <tr>
        <th>Report ID</th>
        <th>Title</th>
        <th>Category</th>
        <th>Status</th>
        <th>Priority</th>
        <th>Location</th>
        <th>Barangay</th>
        <th>Reported By</th>
        <th>Reporter Email</th>
        <th>Created Date</th>
        <th>Resolved Date</th>
      </tr>
    </thead>
    <tbody>
HTML;

            foreach ($reports as $report) {
                $status = (string) $report->status;
                $statusClass = match (strtolower($status)) {
                    'pending' => 'status-pending',
                    'in progress' => 'status-in-progress',
                    'resolved' => 'status-resolved',
                    'new' => 'status-new',
                    default => '',
                };

                echo '<tr>';
                echo '<td>' . e((string) $report->id) . '</td>';
                echo '<td>' . e((string) ($report->title ?? 'Untitled report')) . '</td>';
                echo '<td>' . e((string) (optional($report->category)->name ?? 'General')) . '</td>';
                echo '<td class="' . e($statusClass) . '">' . e(ucwords($status)) . '</td>';
                echo '<td>' . e((string) ($report->priority ?? 'Normal')) . '</td>';
                echo '<td>' . e((string) ($report->location ?? '-')) . '</td>';
                echo '<td>' . e((string) ($report->barangay ?? '-')) . '</td>';
                echo '<td>' . e((string) (optional($report->user)->name ?? '-')) . '</td>';
                echo '<td>' . e((string) (optional($report->user)->email ?? '-')) . '</td>';
                echo '<td>' . e((string) (optional($report->created_at)?->format('M d, Y h:i A') ?? '-')) . '</td>';
                echo '<td>' . e((string) (optional($report->resolved_at)?->format('M d, Y h:i A') ?? '-')) . '</td>';
                echo '</tr>';
            }

            echo <<<HTML
    </tbody>
  </table>
</body>
</html>
HTML;
        }, $fileName, [
            'Content-Type' => 'application/vnd.ms-excel; charset=UTF-8',
            'Cache-Control' => 'no-store, no-cache',
        ]);
    }
}
