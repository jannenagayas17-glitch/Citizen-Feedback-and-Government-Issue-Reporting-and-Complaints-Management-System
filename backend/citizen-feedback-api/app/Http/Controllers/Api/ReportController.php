<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminResponse;
use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\StatusHistory;
use Illuminate\Http\UploadedFile;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;
use Illuminate\Validation\Rules\File;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    private const EMOJI_REGEX = '/[\x{1F1E6}-\x{1F1FF}\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]/u';
    private const OTP_TTL_MINUTES = 10;

    public function index(Request $request)
    {
        $query = Report::with($this->listRelations())->latest();

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
        $mediaFiles = $this->validatedMediaFiles($request);
        $storedPaths = [];

        try {
            $report = DB::transaction(function () use ($request, $validated, $mediaFiles, &$storedPaths) {
                $report = $this->createReportFromValidatedPayload($request->user()->id, $validated);

                foreach ($mediaFiles as $mediaFile) {
                    $path = $mediaFile->store('report_images', 'public');
                    $storedPaths[] = $path;

                    $report->images()->create([
                        'image_path' => $path,
                        'media_type' => 'image',
                        'original_name' => $mediaFile->getClientOriginalName(),
                    ]);
                }

                return $report->fresh()->load($this->detailRelations());
            });
        } catch (\Throwable $exception) {
            foreach ($storedPaths as $storedPath) {
                Storage::disk('public')->delete($storedPath);
            }

            throw $exception;
        }

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
        $report = Report::with($this->detailRelations())->findOrFail($id);

        $this->authorizeReportAccess($request, $report);

        return response()->json($report);
    }

    public function adminReports(Request $request)
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $query = $this->scopedAdminReports($request)->with($this->listRelations());

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
            'status' => 'required|string|in:New,Pending,In Progress,Resolved,Rejected',
            'assigned_to' => 'nullable|exists:users,id',
            'remarks' => 'nullable|string|max:2000',
        ]);

        $report = Report::findOrFail($id);
        $this->authorizeReportAccess($request, $report);
        $oldStatus = $report->status;
        $report->status = $validated['status'];
        $report->assigned_to = $validated['assigned_to'] ?? $report->assigned_to;
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
            'report' => $report->load($this->detailRelations()),
        ]);
    }

    public function exportAdminReports(Request $request): StreamedResponse
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $query = $this->scopedAdminReports($request)->with([
            'user:id,name,email',
            'category:id,name',
            'office:id,name',
            'assignedAdmin:id,name,email',
            'adminResponses' => function ($responseQuery) {
                $responseQuery->latest();
            },
        ]);

        if ($request->filled('status')) {
            $query->where('status', $request->string('status')->toString());
        }

        $reports = $query->get();
        $analytics = $this->buildReportExportAnalytics($reports);
        $officeLabel = $request->user()->role === 'super_admin'
            ? 'all-offices'
            : str($request->user()->department ?: 'office')->slug();
        $fileName = $officeLabel . '-reports-and-analytics-' . now()->format('Ymd-His') . '.xls';

        return response()->streamDownload(function () use ($reports, $analytics, $request) {
            $handle = fopen('php://output', 'w');

            $write = static function (string $value) use ($handle): void {
                fwrite($handle, $value);
            };

            $cell = static function ($value, string $class = ''): string {
                $classAttribute = $class === '' ? '' : ' class="' . e($class) . '"';

                return '<td' . $classAttribute . '>' . e((string) ($value ?? '-')) . '</td>';
            };

            $headerCell = static function (string $value): string {
                return '<th>' . e($value) . '</th>';
            };

            $writeTable = static function (array $headers, iterable $rows, ?string $emptyMessage = null, string $class = 'data-table', array $widths = []) use ($write, $cell, $headerCell): void {
                $write('<table class="' . e($class) . '">');
                if ($widths !== []) {
                    $write('<colgroup>');
                    foreach ($widths as $width) {
                        $write('<col style="width:' . e((string) $width) . ';">');
                    }
                    $write('</colgroup>');
                }
                $write('<thead><tr>');
                foreach ($headers as $header) {
                    $write($headerCell($header));
                }
                $write('</tr></thead><tbody>');

                $hasRows = false;
                foreach ($rows as $row) {
                    $hasRows = true;
                    $write('<tr>');
                    foreach ($row as $value) {
                        $write($cell($value));
                    }
                    $write('</tr>');
                }

                if (! $hasRows && $emptyMessage !== null) {
                    $write('<tr><td colspan="' . count($headers) . '">' . e($emptyMessage) . '</td></tr>');
                }

                $write('</tbody></table>');
            };

            $write('<!doctype html><html><head><meta charset="UTF-8">');
            $write('<style>
                body { font-family: Arial, sans-serif; color: #111827; background: #FFFFFF; }
                h1 { font-size: 24px; margin: 0 0 6px; color: #0F172A; font-weight: 800; }
                h2 { font-size: 17px; margin: 26px 0 8px; color: #1D4ED8; font-weight: 800; }
                .meta { color: #4B5563; margin-bottom: 4px; font-size: 12px; }
                .note { color: #64748B; margin: 8px 0 14px; font-size: 12px; }
                table { border-collapse: collapse; margin-bottom: 18px; table-layout: fixed; }
                th { background: #1D4ED8; color: #FFFFFF; font-weight: 700; white-space: nowrap; }
                th, td { border: 1px solid #CBD5E1; padding: 7px 8px; vertical-align: top; mso-number-format: "\\@"; }
                td { color: #111827; background: #FFFFFF; }
                tbody tr:nth-child(even) td { background: #F8FAFC; }
                .summary { width: 720px; }
                .summary th { background: #0F172A; }
                .summary td { font-weight: 700; font-size: 13px; }
                .summary .label { color: #475569; font-weight: 700; }
                .breakdown { width: 620px; }
                .records { width: 1880px; }
                .records th { background: #0F172A; }
                .wrap { white-space: normal; }
                .center { text-align: center; }
                .right { text-align: right; }
            </style>');
            $write('</head><body>');
            $write('<h1>CityTrack PH Reports and Analytics Export</h1>');
            $write('<div class="meta">Scope: ' . e($request->user()->role === 'super_admin' ? 'All Departments' : ($request->user()->department ?: 'Assigned Department')) . '</div>');
            $write('<div class="meta">Generated: ' . e(now()->format('Y-m-d H:i:s')) . '</div>');
            $write('<div class="meta">Rows exported: ' . e((string) $reports->count()) . '</div>');

            $write('<h2>Analytics Summary</h2>');
            $summaryRows = [];
            foreach ($analytics['summary'] as $label => $value) {
                $summaryRows[] = [$label, $value];
            }
            $writeTable(
                ['Metric', 'Value'],
                $summaryRows,
                null,
                'summary',
                ['360px', '160px']
            );

            $write('<h2>Reports by Department</h2>');
            $writeTable(['Department', 'Total Reports'], $analytics['departments'], 'No department data available.', 'breakdown', ['420px', '140px']);

            $write('<h2>Reports by Category</h2>');
            $writeTable(['Category', 'Total Reports'], $analytics['categories'], 'No category data available.', 'breakdown', ['420px', '140px']);

            $write('<h2>Reports by Barangay</h2>');
            $writeTable(['Barangay', 'Total Reports'], $analytics['barangays'], 'No barangay data available.', 'breakdown', ['420px', '140px']);

            $write('<h2>Reports by Status</h2>');
            $writeTable(['Status', 'Total Reports'], $analytics['statuses'], 'No status data available.', 'breakdown', ['260px', '140px']);

            $write('<h2>All Report Records</h2>');
            $write('<div class="note">Detailed records include the routing department, issue type, citizen location, assignment, latest admin remark, and key dates.</div>');
            $reportRows = [];
            foreach ($reports as $report) {
                $latestResponse = $report->adminResponses->first();

                $reportRows[] = [
                    $report->id,
                    'RPT-' . str_pad((string) $report->id, 5, '0', STR_PAD_LEFT),
                    optional($report->created_at)?->format('Y-m-d H:i') ?? '-',
                    optional($report->office)->name ?? 'Unassigned office',
                    optional($report->category)->name ?? 'General',
                    $report->status ?? 'New',
                    $report->priority ?? 'Normal',
                    $report->barangay ?? '-',
                    $report->location ?? '-',
                    optional($report->assignedAdmin)->name ?? 'Unassigned',
                    optional($report->user)->name ?? '-',
                    optional($report->user)->email ?? '-',
                    $report->title ?? 'Untitled report',
                    $report->description ?? '-',
                    $latestResponse?->response ?? '-',
                    optional($report->resolved_at)?->format('Y-m-d H:i:s') ?? '-',
                ];
            }

            $writeTable([
                'Report ID',
                'Tracking Code',
                'Submitted',
                'Department',
                'Category',
                'Status',
                'Priority',
                'Barangay',
                'Location',
                'Assigned Staff',
                'Reporter Name',
                'Reporter Email',
                'Title',
                'Description',
                'Latest Admin Remark',
                'Resolved Date',
            ], $reportRows, 'No reports available for this export.', 'records', [
                '90px',
                '130px',
                '145px',
                '260px',
                '220px',
                '110px',
                '100px',
                '210px',
                '260px',
                '180px',
                '180px',
                '240px',
                '330px',
                '460px',
                '360px',
                '150px',
            ]);

            $write('</body></html>');

            fclose($handle);
        }, $fileName, [
            'Content-Type' => 'application/vnd.ms-excel; charset=UTF-8',
            'Cache-Control' => 'no-store, no-cache',
        ]);
    }

    private function buildReportExportAnalytics($reports): array
    {
        $total = $reports->count();
        $pending = $reports->where('status', 'Pending')->count();
        $inProgress = $reports->where('status', 'In Progress')->count();
        $resolved = $reports->where('status', 'Resolved')->count();
        $rejected = $reports->where('status', 'Rejected')->count();
        $new = $reports->where('status', 'New')->count();
        $resolutionRate = $total === 0 ? 0 : round(($resolved / $total) * 100);

        return [
            'summary' => [
                'Total Reports' => $total,
                'New Reports' => $new,
                'Pending Reports' => $pending,
                'In Progress Reports' => $inProgress,
                'Resolved Reports' => $resolved,
                'Rejected Reports' => $rejected,
                'Resolution Rate' => $resolutionRate . '%',
            ],
            'departments' => $this->groupReportCounts($reports, fn ($report) => optional($report->office)->name ?: 'Unassigned department'),
            'categories' => $this->groupReportCounts($reports, fn ($report) => optional($report->category)->name ?: 'General'),
            'barangays' => $this->groupReportCounts($reports, fn ($report) => $report->barangay ?: 'Unspecified barangay'),
            'statuses' => $this->groupReportCounts($reports, fn ($report) => $report->status ?: 'New'),
        ];
    }

    private function groupReportCounts($reports, callable $labelResolver): array
    {
        return $reports
            ->groupBy(fn ($report) => $labelResolver($report))
            ->map(fn ($group, $label) => [$label, $group->count()])
            ->sortByDesc(fn ($row) => $row[1])
            ->values()
            ->all();
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
            'barangay' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
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
            'barangay.required' => 'Barangay is required.',
            'location.required' => 'Location is required.',
        ]);
    }

    /**
     * @return array<int, UploadedFile>
     */
    private function validatedMediaFiles(Request $request): array
    {
        $rawFiles = $request->allFiles()['media'] ?? $request->allFiles()['media[]'] ?? [];

        if ($rawFiles instanceof UploadedFile) {
            $mediaFiles = [$rawFiles];
        } elseif (is_array($rawFiles)) {
            $mediaFiles = array_values(
                array_filter(
                    $rawFiles,
                    static fn ($file): bool => $file instanceof UploadedFile
                )
            );
        } else {
            $mediaFiles = [];
        }

        Validator::make(
            ['media' => $mediaFiles],
            [
                'media' => ['nullable', 'array', 'max:3'],
                'media.*' => [
                    File::types(['jpg', 'jpeg', 'png'])->max(50 * 1024),
                ],
            ],
            [
                'media.max' => 'You can upload up to 3 attachments only.',
                'media.*.types' => 'Attachments must be JPG or PNG photos only.',
                'media.*.max' => 'Attachments must be 50MB or smaller.',
            ]
        )->validate();

        return $mediaFiles;
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

        return $report->load($this->detailRelations());
    }

    private function listRelations(): array
    {
        return [
            'user',
            'category',
            'office',
            'images',
            'latestStatusHistory.user',
            'latestAdminResponse.user',
        ];
    }

    private function detailRelations(): array
    {
        return [
            'user',
            'category',
            'office',
            'images',
            'statusHistories' => function ($query) {
                $query->with('user')->latest();
            },
            'adminResponses' => function ($query) {
                $query->with('user')->latest();
            },
            'latestStatusHistory.user',
            'latestAdminResponse.user',
        ];
    }

    private function verificationCacheKey(int $userId): string
    {
        return 'report_submission_otp:' . $userId;
    }
}
