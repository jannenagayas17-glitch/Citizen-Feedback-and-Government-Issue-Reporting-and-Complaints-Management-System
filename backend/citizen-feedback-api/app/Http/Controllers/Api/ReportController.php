<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminResponse;
use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\StatusHistory;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Mail;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    private const EMOJI_REGEX = '/[\x{1F1E6}-\x{1F1FF}\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]/u';
    private const OTP_TTL_MINUTES = 10;

    public function index(Request $request)
    {
        $query = Report::with(['user', 'category', 'office', 'images'])->latest();

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
        $validated = $this->validateReportPayload($request);
        $report = $this->createReportFromValidatedPayload($request->user()->id, $validated);

        return response()->json([
            'message' => 'Report created successfully',
            'report' => $report,
        ], 201);
    }

    public function requestSubmissionVerification(Request $request)
    {
        $validated = $this->validateReportPayload($request);
        $otp = (string) random_int(100000, 999999);

        Cache::put(
            $this->verificationCacheKey((int) $request->user()->id),
            [
                'otp' => $otp,
                'payload' => $validated,
                'requested_at' => now()->toIso8601String(),
            ],
            now()->addMinutes(self::OTP_TTL_MINUTES)
        );

        $user = $request->user();
        $office = Office::find($validated['office_id']);

        Mail::raw(
            implode("\n", [
                'Your Tacloban City feedback verification code is: ' . $otp,
                '',
                'This code will expire in ' . self::OTP_TTL_MINUTES . ' minutes.',
                'Selected office: ' . ($office?->name ?? 'Unknown office'),
                'Issue title: ' . $validated['title'],
                '',
                'If you did not request this submission, you can ignore this email.',
            ]),
            function ($message) use ($user) {
                $message
                    ->to($user->email, $user->name)
                    ->subject('Your Tacloban City feedback verification code');
            }
        );

        return response()->json([
            'message' => 'Verification code sent successfully.',
            'expires_in_seconds' => self::OTP_TTL_MINUTES * 60,
            'email' => $user->email,
        ]);
    }

    public function verifySubmissionAndStore(Request $request)
    {
        $validated = $request->validate([
            'otp' => ['required', 'digits:6'],
        ]);

        $cached = Cache::get($this->verificationCacheKey((int) $request->user()->id));

        if (! is_array($cached) || empty($cached['otp']) || empty($cached['payload'])) {
            return response()->json([
                'message' => 'Verification expired. Please request a new code.',
            ], 422);
        }

        if ((string) $cached['otp'] !== (string) $validated['otp']) {
            return response()->json([
                'message' => 'Invalid verification code.',
                'errors' => [
                    'otp' => ['The verification code is incorrect.'],
                ],
            ], 422);
        }

        Cache::forget($this->verificationCacheKey((int) $request->user()->id));

        $report = $this->createReportFromValidatedPayload(
            (int) $request->user()->id,
            $cached['payload']
        );

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
            'office',
            'images',
            'statusHistories.user',
            'adminResponses.user'
        ])->findOrFail($id);

        $this->authorizeReportAccess($request, $report);

        return response()->json($report);
    }

    public function adminReports(Request $request)
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $query = $this->scopedAdminReports($request)->with(['user', 'category', 'office', 'images']);

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
        $this->authorizeReportAccess($request, $report);
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
            'report' => $report->load(['user', 'category', 'office', 'images']),
        ]);
    }

    public function exportAdminReports(Request $request): StreamedResponse
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $query = $this->scopedAdminReports($request)->with(['user', 'category', 'office']);

        if ($request->filled('status')) {
            $query->where('status', $request->string('status')->toString());
        }

        $reports = $query->get();
        $officeLabel = $request->user()->role === 'super_admin'
            ? 'all-offices'
            : str($request->user()->department ?: 'office')->slug();
        $sheetTitle = $request->user()->role === 'super_admin'
            ? 'Tacloban City Government Offices Reports'
            : ($request->user()->department ?: 'Assigned Office') . ' Reports';
        $fileName = $officeLabel . '-reports-' . now()->format('Ymd-His') . '.xls';

        return response()->streamDownload(function () use ($reports, $sheetTitle) {
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
  <div class="sheet-title">
HTML;
            echo e($sheetTitle);
            echo <<<HTML
  </div>
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

    private function scopedAdminReports(Request $request)
    {
        $query = Report::query()->latest();

        if (($request->user()->role ?? null) === 'admin') {
            $department = trim((string) ($request->user()->department ?? ''));

            if ($department === '') {
                $query->whereRaw('1 = 0');
            } else {
                $query->whereHas('office', function ($officeQuery) use ($department) {
                    $officeQuery->where('name', $department);
                });
            }
        }

        return $query;
    }

    private function authorizeReportAccess(Request $request, Report $report): void
    {
        $role = $request->user()->role ?? 'citizen';

        if ($role === 'citizen' && $report->user_id !== $request->user()->id) {
            abort(403, 'Unauthorized action.');
        }

        if ($role === 'admin') {
            $department = trim((string) ($request->user()->department ?? ''));
            $officeName = trim((string) optional($report->office)->name);

            if ($department === '' || $officeName === '' || $department !== $officeName) {
                abort(403, 'Unauthorized action.');
            }
        }
    }

    private function validateReportPayload(Request $request): array
    {
        return $request->validate([
            'category_id' => 'nullable|exists:categories,id',
            'category_name' => ['nullable', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'office_id' => 'required|exists:offices,id',
            'title' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'description' => ['required', 'string', 'not_regex:' . self::EMOJI_REGEX],
            'location' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'barangay' => ['nullable', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'priority' => 'nullable|string|in:Low,Normal,High,Urgent',
        ], [
            'category_name.not_regex' => 'Emoji characters are not allowed.',
            'office_id.required' => 'Please select the office that should handle this report.',
            'title.not_regex' => 'Emoji characters are not allowed.',
            'description.not_regex' => 'Emoji characters are not allowed.',
            'location.not_regex' => 'Emoji characters are not allowed.',
            'barangay.not_regex' => 'Emoji characters are not allowed.',
            'location.required' => 'Location is required.',
        ]);
    }

    private function createReportFromValidatedPayload(int $userId, array $validated): Report
    {
        $categoryId = $validated['category_id'] ?? null;

        if ($categoryId === null) {
            $categoryName = trim((string) ($validated['category_name'] ?? ''));

            if ($categoryName === '') {
                throw ValidationException::withMessages([
                    'category' => ['The category field is required.'],
                ]);
            }

            $category = Category::firstOrCreate(
                ['name' => $categoryName],
                ['description' => $categoryName . ' reports']
            );

            $categoryId = $category->id;
        }

        $report = Report::create([
            'user_id' => $userId,
            'category_id' => $categoryId,
            'office_id' => $validated['office_id'],
            'title' => $validated['title'],
            'description' => $validated['description'],
            'location' => $validated['location'] ?? null,
            'barangay' => $validated['barangay'] ?? null,
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
            'status' => 'New',
            'priority' => $validated['priority'] ?? 'Normal',
        ]);

        return $report->load(['category', 'office']);
    }

    private function verificationCacheKey(int $userId): string
    {
        return 'report_submission_otp:' . $userId;
    }
}
