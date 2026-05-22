<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\AdminResponse;
use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\StatusHistory;
use App\Models\User;
use App\Support\ReportQueryService;
use Illuminate\Http\UploadedFile;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Illuminate\Validation\Rules\File;
use Symfony\Component\HttpFoundation\StreamedResponse;

class ReportController extends Controller
{
    private const EMOJI_REGEX = '/[\x{1F1E6}-\x{1F1FF}\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]/u';
    private const CITIZEN_DESCRIPTION_MAX_LENGTH = 100;
    private const OTP_TTL_MINUTES = 10;
    private const MEDIA_MAX_KB = 50 * 1024;
    private const MEDIA_TYPES = ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi', 'webm', '3gp', 'm4v'];

    public function __construct(
        private readonly ReportQueryService $reportQueries,
    ) {
    }

    public function index(Request $request)
    {
        $query = $this->reportQueries
            ->scopedForUser($request->user())
            ->with($this->listRelations())
            ->orderByDesc('reports.created_at')
            ->orderByDesc('reports.id');

        if ($request->has('status')) {
            $query->where('status', $request->status);
        }

        if ($request->has('category_id')) {
            $query->where('category_id', $request->category_id);
        }

        $reports = $query->get()->unique('id')->values();

        return response()->json(
            $this->presentReportsForViewer($request, $reports)
        );
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
                        'media_type' => $this->mediaTypeForFile($mediaFile),
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
            'report' => $this->presentReportForViewer($request, $report),
        ], 201);
    }

    public function storeWalkIn(Request $request)
    {
        $this->ensureAdministrativeStaffUser($request);
        $this->normalizeWalkInRequest($request);

        $validated = $this->validateWalkInPayload($request);
        $this->ensureNoRecentWalkInDuplicate($request, $validated);

        $mediaFiles = $this->validatedMediaFiles($request);
        $storedPaths = [];

        try {
            $report = DB::transaction(function () use ($request, $validated, $mediaFiles, &$storedPaths) {
                $report = $this->createWalkInReportFromValidatedPayload(
                    $request->user(),
                    $validated
                );

                foreach ($mediaFiles as $mediaFile) {
                    $path = $mediaFile->store('report_images', 'public');
                    $storedPaths[] = $path;

                    $report->images()->create([
                        'image_path' => $path,
                        'media_type' => $this->mediaTypeForFile($mediaFile),
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
            'message' => 'Walk-in complaint submitted successfully.',
            'report' => $this->presentReportForViewer($request, $report),
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
            'report' => $this->presentReportForViewer($request, $report),
        ], 201);
    }

    public function show(Request $request, $id)
    {
        $report = Report::with($this->detailRelations())->findOrFail($id);

        $this->authorizeReportAccess($request, $report);

        return response()->json(
            $this->presentReportForViewer($request, $report)
        );
    }

    public function adminReports(Request $request)
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $datePresetRule = 'in:' . implode(',', $this->reportQueries->allowedDatePresets());

        $validated = $request->validate([
            'status' => ['nullable', 'string', 'in:New,Pending,In Progress,Resolved,Rejected'],
            'search' => ['nullable', 'string', 'max:255'],
            'category' => ['nullable', 'string', 'max:255'],
            'barangay' => ['nullable', 'string', 'max:255'],
            'office' => ['nullable', 'string', 'max:255'],
            'date_preset' => ['nullable', 'string', $datePresetRule],
            'start_date' => ['nullable', 'date', 'required_if:date_preset,custom'],
            'end_date' => ['nullable', 'date', 'required_if:date_preset,custom', 'after_or_equal:start_date'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:100'],
        ]);

        $query = $this->reportQueries
            ->scopedForUser($request->user())
            ->orderByDesc('reports.created_at')
            ->orderByDesc('reports.id')
            ->with($this->adminListRelations());

        $this->reportQueries->applyFilters($query, $validated);
        $this->reportQueries->applyDateRangeFilter($query, $validated);
        $availableFilters = $this->shouldIncludeReportAvailableFilters($request)
            ? $this->buildAdminReportAvailableFilters($request, $validated)
            : $this->emptyReportAvailableFilters();

        $shouldPaginate = $request->boolean('paginate')
            || $request->filled('page')
            || $request->filled('per_page');

        if (! $shouldPaginate) {
            return response()->json(
                $this->presentReportsForViewer($request, $query->get())
            );
        }

        $perPage = (int) ($validated['per_page'] ?? 25);
        $reports = $query->paginate($perPage)->appends($request->query());
        $reports->setCollection(
            $reports->getCollection()->map(
                fn (Report $report) => $this->presentReportForViewer($request, $report)
            )
        );

        return response()->json([
            ...$reports->toArray(),
            'available_filters' => $availableFilters,
            'applied_filters' => [
                'search' => $validated['search'] ?? null,
                'status' => $validated['status'] ?? null,
                'category' => $validated['category'] ?? null,
                'barangay' => $validated['barangay'] ?? null,
                'office' => $validated['office'] ?? null,
                'date_preset' => $validated['date_preset'] ?? null,
                'start_date' => $validated['start_date'] ?? null,
                'end_date' => $validated['end_date'] ?? null,
            ],
            'role_scope' => [
                'role' => (string) ($request->user()->role ?? 'admin'),
                'department_locked' => ($request->user()->role ?? null) === 'admin',
                'selected_department' => $this->scopeLabelForUser($request->user()),
            ],
        ]);
    }

    public function frontDeskReports(Request $request)
    {
        $this->ensureAdministrativeStaffUser($request);

        $validated = $request->validate([
            'status' => ['nullable', 'string', 'in:New,Pending,In Progress,Resolved,Rejected'],
            'search' => ['nullable', 'string', 'max:255'],
            'category' => ['nullable', 'string', 'max:255'],
            'barangay' => ['nullable', 'string', 'max:255'],
            'page' => ['nullable', 'integer', 'min:1'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $query = $this->reportQueries
            ->scopedForUser($request->user())
            ->orderByDesc('reports.created_at')
            ->orderByDesc('reports.id')
            ->with($this->adminListRelations());

        $this->reportQueries->applyFilters($query, $validated);
        $availableFilters = $this->shouldIncludeReportAvailableFilters($request)
            ? $this->buildAdminReportAvailableFilters($request, $validated)
            : $this->emptyReportAvailableFilters();

        $perPage = (int) ($validated['per_page'] ?? 15);
        $reports = $query->paginate($perPage)->appends($request->query());
        $reports->setCollection(
            $reports->getCollection()->map(
                fn (Report $report) => $this->presentReportForViewer($request, $report)
            )
        );

        return response()->json([
            ...$reports->toArray(),
            'available_filters' => $availableFilters,
            'applied_filters' => [
                'search' => $validated['search'] ?? null,
                'status' => $validated['status'] ?? null,
                'category' => $validated['category'] ?? null,
                'barangay' => $validated['barangay'] ?? null,
            ],
            'role_scope' => [
                'role' => (string) ($request->user()->role ?? User::ROLE_ADMINISTRATIVE_STAFF),
                'department_locked' => true,
                'selected_department' => $this->scopeLabelForUser($request->user()),
            ],
        ]);
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
            'report' => $this->presentReportForViewer(
                $request,
                $report->load($this->detailRelations())
            ),
        ]);
    }

    public function exportAdminReports(Request $request): StreamedResponse
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $datePresetRule = 'in:' . implode(',', $this->reportQueries->allowedDatePresets());

        $validated = $request->validate([
            'status' => ['nullable', 'string', 'in:New,Pending,In Progress,Resolved,Rejected'],
            'search' => ['nullable', 'string', 'max:255'],
            'category' => ['nullable', 'string', 'max:255'],
            'barangay' => ['nullable', 'string', 'max:255'],
            'office' => ['nullable', 'string', 'max:255'],
            'date_preset' => ['nullable', 'string', $datePresetRule],
            'start_date' => ['nullable', 'date', 'required_if:date_preset,custom'],
            'end_date' => ['nullable', 'date', 'required_if:date_preset,custom', 'after_or_equal:start_date'],
        ]);

        $query = $this->reportQueries
            ->scopedForUser($request->user())
            ->orderByDesc('reports.created_at')
            ->orderByDesc('reports.id')
            ->with([
            'user:id,name,email,mobile_number',
            'category:id,name',
            'office:id,name',
            'assignedAdmin:id,name,email',
            'assistedByUser:id,name,email,mobile_number,department,job_title',
            'adminResponses' => function ($responseQuery) {
                $responseQuery->latest();
            },
            ]);

        $canonicalPreset = $this->reportQueries->canonicalDatePreset($validated['date_preset'] ?? null);
        $this->reportQueries->applyFilters($query, $validated);
        $dateRange = $this->reportQueries->applyDateRangeFilter($query, $validated);

        $reports = $query->get();
        $analytics = $this->buildReportExportAnalytics($reports);
        $filterRows = $this->buildExportFilterRows(
            $request,
            $validated,
            $canonicalPreset,
            $dateRange
        );
        $fileName = $this->buildExportFileName($request, $validated, $canonicalPreset);

        return response()->streamDownload(function () use ($reports, $analytics, $request, $filterRows) {
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
            $write('<div class="meta">Scope: ' . e($this->scopeLabelForUser($request->user())) . '</div>');
            $write('<div class="meta">Generated: ' . e(now()->format('Y-m-d H:i:s')) . '</div>');
            $write('<div class="meta">Rows exported: ' . e((string) $reports->count()) . '</div>');

            $write('<h2>Applied Filters</h2>');
            $writeTable(
                ['Filter', 'Value'],
                $filterRows,
                null,
                'summary',
                ['260px', '420px']
            );

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
                    $report->printable_reference_number ?: 'RPT-' . str_pad((string) $report->id, 5, '0', STR_PAD_LEFT),
                    $report->source === 'walk_in' ? 'Administrative Staff Assistance' : 'Citizen Mobile App',
                    optional($report->created_at)?->format('Y-m-d H:i') ?? '-',
                    optional($report->office)->name ?? 'Unassigned office',
                    optional($report->category)->name ?? 'General',
                    $report->status ?? 'New',
                    $report->priority ?? 'Normal',
                    $report->barangay ?? '-',
                    $report->location ?? '-',
                    optional($report->assignedAdmin)->name ?? 'Unassigned',
                    $report->reporterNameForViewer($request->user()),
                    $report->reporterEmailForViewer($request->user()) ?? '-',
                    $report->reporterContactNumberForViewer($request->user()) ?? '-',
                    $report->reporterAddressForViewer($request->user()) ?? '-',
                    $report->walk_in_is_senior_citizen ? 'Yes' : 'No',
                    $report->walk_in_is_pwd ? 'Yes' : 'No',
                    optional($report->assistedByUser)->name ?? '-',
                    optional($report->expected_return_at)?->format('Y-m-d H:i') ?? '-',
                    $report->title ?? 'Untitled report',
                    $report->description ?? '-',
                    $latestResponse?->response ?? '-',
                    optional($report->resolved_at)?->format('Y-m-d H:i:s') ?? '-',
                ];
            }

            $writeTable([
                'Report ID',
                'Tracking Code',
                'Source',
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
                'Reporter Contact',
                'Reporter Address',
                'Senior Citizen',
                'PWD',
                'Assisted By',
                'Expected Return',
                'Title',
                'Description',
                'Latest Admin Remark',
                'Resolved Date',
            ], $reportRows, 'No reports available for this export.', 'records', [
                '90px',
                '130px',
                '150px',
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
                '160px',
                '220px',
                '110px',
                '90px',
                '180px',
                '150px',
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

    private function buildAdminReportAvailableFilters(Request $request, array $filters): array
    {
        return [
            'offices' => $this->availableReportOffices($request, $filters),
            'categories' => $this->availableReportCategories($request, $filters),
            'barangays' => $this->availableReportBarangays($request, $filters),
        ];
    }

    private function emptyReportAvailableFilters(): array
    {
        return [
            'offices' => [],
            'categories' => [],
            'barangays' => [],
        ];
    }

    private function shouldIncludeReportAvailableFilters(Request $request): bool
    {
        if (! $request->has('include_filters')) {
            return true;
        }

        return $request->boolean('include_filters');
    }

    private function availableReportOffices(Request $request, array $filters): array
    {
        $query = $this->reportQueries->scopedForUser($request->user());
        $this->reportQueries->applyFilters($query, $filters, ['office']);
        $this->reportQueries->applyDateRangeFilter($query, $filters);

        return (clone $query)
            ->leftJoin('offices', 'reports.office_id', '=', 'offices.id')
            ->selectRaw("COALESCE(offices.name, 'Unassigned Office') as label")
            ->groupBy('label')
            ->orderBy('label')
            ->pluck('label')
            ->map(fn ($value) => trim((string) $value))
            ->filter(fn (string $value) => $value !== '')
            ->values()
            ->all();
    }

    private function availableReportCategories(Request $request, array $filters): array
    {
        $query = $this->reportQueries->scopedForUser($request->user());
        $this->reportQueries->applyFilters($query, $filters, ['category']);
        $this->reportQueries->applyDateRangeFilter($query, $filters);

        return (clone $query)
            ->leftJoin('categories', 'reports.category_id', '=', 'categories.id')
            ->selectRaw("COALESCE(categories.name, 'General') as label")
            ->groupBy(DB::raw("COALESCE(categories.name, 'General')"))
            ->orderBy('label')
            ->pluck('label')
            ->map(fn ($value) => trim((string) $value))
            ->filter(fn (string $value) => $value !== '')
            ->values()
            ->all();
    }

    private function availableReportBarangays(Request $request, array $filters): array
    {
        $query = $this->reportQueries->scopedForUser($request->user());
        $this->reportQueries->applyFilters($query, $filters, ['barangay']);
        $this->reportQueries->applyDateRangeFilter($query, $filters);

        return (clone $query)
            ->whereNotNull('reports.barangay')
            ->where('reports.barangay', '!=', '')
            ->select('reports.barangay')
            ->distinct()
            ->orderBy('reports.barangay')
            ->pluck('reports.barangay')
            ->map(fn ($value) => trim((string) $value))
            ->filter(fn (string $value) => $value !== '')
            ->values()
            ->all();
    }

    private function buildExportFilterRows(
        Request $request,
        array $filters,
        string $canonicalPreset,
        ?array $dateRange,
    ): array {
        return [
            ['Department', trim((string) ($filters['office'] ?? '')) ?: ($request->user()->role === 'super_admin' ? 'All Departments' : $this->scopeLabelForUser($request->user()))],
            ['Barangay', trim((string) ($filters['barangay'] ?? '')) ?: 'All Barangays'],
            ['Category', trim((string) ($filters['category'] ?? '')) ?: 'All Categories'],
            ['Status', trim((string) ($filters['status'] ?? '')) ?: 'All Statuses'],
            ['Time Period', $this->datePresetLabel($canonicalPreset)],
            ['Date Range', $dateRange === null
                ? 'All available dates'
                : $dateRange['start']->toDateString() . ' to ' . $dateRange['end']->toDateString()],
        ];
    }

    private function buildExportFileName(Request $request, array $filters, string $canonicalPreset): string
    {
        $segments = array_values(array_filter([
            $this->slugSegment(
                trim((string) ($filters['office'] ?? ''))
                    ?: ($request->user()->role === 'super_admin'
                        ? 'all-departments'
                        : $this->scopeLabelForUser($request->user()))
            ),
            $this->slugSegment($canonicalPreset),
            $this->slugSegment($filters['barangay'] ?? null),
            $this->slugSegment($filters['category'] ?? null),
            $this->slugSegment($filters['status'] ?? null),
        ]));

        $segments = array_slice($segments, 0, 5);
        $segments[] = 'reports-and-analytics';
        $segments[] = now()->format('Ymd-His');

        return implode('-', $segments) . '.xls';
    }

    private function scopeLabelForUser(User $user): string
    {
        if (User::normalizeRole($user->role ?? null) === 'super_admin') {
            return 'All Departments';
        }

        $officeId = $this->reportQueries->resolveAdminOfficeId($user);
        if ($officeId !== null) {
            $officeName = Office::query()->whereKey($officeId)->value('name');
            if (is_string($officeName) && trim($officeName) !== '') {
                return trim($officeName);
            }
        }

        return trim((string) ($user->department ?? '')) ?: 'Assigned Department';
    }

    private function datePresetLabel(?string $preset): string
    {
        return match ($this->reportQueries->canonicalDatePreset($preset)) {
            'weekly' => 'Weekly',
            'monthly' => 'Monthly',
            'yearly' => 'Yearly',
            'today' => 'Today',
            'last_7_days' => 'Last 7 Days',
            'last_30_days' => 'Last 30 Days',
            'custom' => 'Custom Range',
            default => 'All Time',
        };
    }

    private function slugSegment(mixed $value): ?string
    {
        $normalized = trim((string) ($value ?? ''));
        if ($normalized === '') {
            return null;
        }

        $slug = Str::slug($normalized);

        return $slug === '' ? null : $slug;
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

    private function authorizeReportAccess(Request $request, Report $report): void
    {
        $role = User::normalizeRole($request->user()->role ?? 'citizen');

        if ($role === 'citizen' && $report->user_id !== $request->user()->id) {
            abort(403, 'Unauthorized action.');
        }

        if ($role === 'admin') {
            $adminOfficeId = $this->reportQueries->resolveAdminOfficeId($request->user());

            if ($adminOfficeId === null || (int) $report->office_id !== (int) $adminOfficeId) {
                abort(403, 'Unauthorized action.');
            }
        }

        if ($role === User::ROLE_ADMINISTRATIVE_STAFF) {
            $ownsWalkInReport = $report->isWalkInComplaint()
                && ((int) ($report->assisted_by_user_id ?? $report->user_id) === (int) $request->user()->id);

            if (! $ownsWalkInReport) {
                abort(403, 'Unauthorized action.');
            }
        }
    }

    private function ensureAdministrativeStaffUser(Request $request): void
    {
        if (User::normalizeRole($request->user()->role ?? null) !== User::ROLE_ADMINISTRATIVE_STAFF) {
            abort(403, 'Unauthorized action.');
        }
    }

    private function validateReportPayload(Request $request): array
    {
        return $request->validate([
            'category_id' => 'nullable|exists:categories,id',
            'category_name' => ['nullable', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'office_id' => 'required|exists:offices,id',
            'title' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'description' => ['required', 'string', 'max:' . self::CITIZEN_DESCRIPTION_MAX_LENGTH, 'not_regex:' . self::EMOJI_REGEX],
            'location' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'barangay' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'priority' => 'nullable|string|in:Low,Normal,High,Urgent',
            'is_anonymous' => ['nullable', 'boolean'],
        ], [
            'category_name.not_regex' => 'Emoji characters are not allowed.',
            'office_id.required' => 'Please select the office that should handle this report.',
            'title.not_regex' => 'Emoji characters are not allowed.',
            'description.not_regex' => 'Emoji characters are not allowed.',
            'description.max' => 'Description must be ' . self::CITIZEN_DESCRIPTION_MAX_LENGTH . ' characters or fewer.',
            'location.not_regex' => 'Emoji characters are not allowed.',
            'barangay.not_regex' => 'Emoji characters are not allowed.',
            'barangay.required' => 'Barangay is required.',
            'location.required' => 'Location is required.',
        ]);
    }

    private function validateWalkInPayload(Request $request): array
    {
        return $request->validate([
            'category_id' => 'nullable|exists:categories,id',
            'category_name' => ['nullable', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'office_id' => 'required|exists:offices,id',
            'title' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'description' => ['required', 'string', 'max:' . self::CITIZEN_DESCRIPTION_MAX_LENGTH, 'not_regex:' . self::EMOJI_REGEX],
            'location' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'barangay' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'latitude' => 'nullable|numeric',
            'longitude' => 'nullable|numeric',
            'priority' => 'nullable|string|in:Low,Normal,High,Urgent',
            'is_anonymous' => ['nullable', 'boolean'],
            'walk_in_full_name' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'walk_in_contact_number' => ['required', 'regex:/^09\d{9}$/'],
            'walk_in_email' => ['nullable', 'email', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'walk_in_address' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'walk_in_is_senior_citizen' => ['nullable', 'boolean'],
            'walk_in_is_pwd' => ['nullable', 'boolean'],
            'expected_return_at' => ['nullable', 'date'],
        ], [
            'category_name.not_regex' => 'Emoji characters are not allowed.',
            'office_id.required' => 'Please select the office that should handle this report.',
            'title.not_regex' => 'Emoji characters are not allowed.',
            'description.not_regex' => 'Emoji characters are not allowed.',
            'description.max' => 'Complaint description must be ' . self::CITIZEN_DESCRIPTION_MAX_LENGTH . ' characters or fewer.',
            'location.not_regex' => 'Emoji characters are not allowed.',
            'barangay.not_regex' => 'Emoji characters are not allowed.',
            'walk_in_full_name.required' => 'Complainant name is required.',
            'walk_in_contact_number.required' => 'Mobile number is required.',
            'walk_in_contact_number.regex' => 'Enter a valid Philippine mobile number using 09XXXXXXXXX.',
            'walk_in_address.required' => 'Address or barangay details are required.',
            'walk_in_address.not_regex' => 'Emoji characters are not allowed.',
        ]);
    }

    private function normalizeWalkInRequest(Request $request): void
    {
        $normalized = [];

        foreach ([
            'walk_in_full_name',
            'walk_in_email',
            'walk_in_address',
            'title',
            'description',
            'location',
            'barangay',
        ] as $field) {
            if ($request->exists($field)) {
                $normalized[$field] = trim((string) $request->input($field));
            }
        }

        if ($request->exists('walk_in_contact_number')) {
            $normalized['walk_in_contact_number'] = $this->normalizeWalkInContactNumber(
                $request->input('walk_in_contact_number')
            );
        }

        if ($normalized !== []) {
            $request->merge($normalized);
        }
    }

    private function normalizeWalkInContactNumber(mixed $value): string
    {
        $normalized = trim((string) $value);
        $digitsOnly = preg_replace('/\D+/', '', $normalized) ?? '';

        if ($digitsOnly === '') {
            return $normalized;
        }

        if (str_starts_with($digitsOnly, '63') && strlen($digitsOnly) === 12) {
            return '0' . substr($digitsOnly, 2);
        }

        if (str_starts_with($digitsOnly, '9') && strlen($digitsOnly) === 10) {
            return '0' . $digitsOnly;
        }

        return $digitsOnly;
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
                    File::types(self::MEDIA_TYPES)->max(self::MEDIA_MAX_KB),
                ],
            ],
            [
                'media.max' => 'You can upload up to 3 attachments only.',
                'media.*.types' => 'Attachments must be JPG, PNG, or video files.',
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

        $attributes = [
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
            'is_anonymous' => (bool) ($validated['is_anonymous'] ?? false),
            'source' => $validated['source'] ?? 'citizen_app',
            'assisted_by_user_id' => $validated['assisted_by_user_id'] ?? null,
            'assisted_by_role' => $validated['assisted_by_role'] ?? null,
            'walk_in_full_name' => $validated['walk_in_full_name'] ?? null,
            'walk_in_contact_number' => $validated['walk_in_contact_number'] ?? null,
            'walk_in_email' => $validated['walk_in_email'] ?? null,
            'walk_in_address' => $validated['walk_in_address'] ?? null,
            'walk_in_is_senior_citizen' => (bool) ($validated['walk_in_is_senior_citizen'] ?? false),
            'walk_in_is_pwd' => (bool) ($validated['walk_in_is_pwd'] ?? false),
            'expected_return_at' => $validated['expected_return_at'] ?? null,
            'printable_reference_number' => $validated['printable_reference_number'] ?? null,
        ];

        $report = Report::create(
            $this->reportQueries->filterPersistableReportAttributes($attributes)
        );

        return $report->load($this->detailRelations());
    }

    private function createWalkInReportFromValidatedPayload(User $assistant, array $validated): Report
    {
        $validated['source'] = 'walk_in';
        $validated['assisted_by_user_id'] = (int) $assistant->id;
        $validated['assisted_by_role'] = User::normalizeRole($assistant->role ?? User::ROLE_ADMINISTRATIVE_STAFF);
        if ($this->reportQueries->reportColumnExists('expected_return_at')) {
            $validated['expected_return_at'] = $validated['expected_return_at'] ?? $this->suggestedExpectedReturnAt();
        }
        if ($this->reportQueries->reportColumnExists('printable_reference_number')) {
            $validated['printable_reference_number'] = $validated['printable_reference_number']
                ?? $this->generatePrintableReferenceNumber();
        }

        return $this->createReportFromValidatedPayload((int) $assistant->id, $validated);
    }

    private function ensureNoRecentWalkInDuplicate(Request $request, array $validated): void
    {
        $duplicateQuery = Report::query();
        $this->reportQueries->applyWalkInFilter($duplicateQuery);

        if ($this->reportQueries->reportColumnExists('assisted_by_user_id')) {
            $duplicateQuery->where('assisted_by_user_id', $request->user()->id);
        } else {
            $duplicateQuery->where('user_id', $request->user()->id);
        }

        $duplicateQuery
            ->where('office_id', $validated['office_id'])
            ->whereRaw('LOWER(title) = ?', [mb_strtolower(trim((string) $validated['title']))])
            ->whereRaw('LOWER(description) = ?', [mb_strtolower(trim((string) $validated['description']))])
            ->where('created_at', '>=', now()->subMinutes(5));

        if ($this->reportQueries->reportColumnExists('walk_in_full_name')) {
            $duplicateQuery->whereRaw(
                'LOWER(walk_in_full_name) = ?',
                [mb_strtolower(trim((string) $validated['walk_in_full_name']))]
            );
        }

        $duplicateExists = $duplicateQuery->exists();

        if ($duplicateExists) {
            throw ValidationException::withMessages([
                'title' => ['A similar walk-in complaint was already submitted recently. Please review the latest slip before creating another one.'],
            ]);
        }
    }

    private function suggestedExpectedReturnAt(): string
    {
        return now()
            ->addDays(3)
            ->setTime(10, 0)
            ->toDateTimeString();
    }

    private function generatePrintableReferenceNumber(): string
    {
        do {
            $reference = 'WIC-' . now()->format('Ymd') . '-' . Str::upper(Str::random(6));
        } while (Report::query()->where('printable_reference_number', $reference)->exists());

        return $reference;
    }

    private function listRelations(): array
    {
        return [
            'user',
            'category',
            'office',
            'assistedByUser:id,name,email,mobile_number,department,job_title',
            'assignedAdmin:id,name,job_title',
            'latestStatusHistory.user',
            'latestAdminResponse.user',
        ];
    }

    private function adminListRelations(): array
    {
        return [
            'user:id,name,email,mobile_number',
            'category:id,name',
            'office:id,name',
            'assistedByUser:id,name,email,mobile_number,department,job_title',
            'assignedAdmin:id,name',
        ];
    }

    private function detailRelations(): array
    {
        return [
            'user',
            'category',
            'office',
            'assistedByUser:id,name,email,mobile_number,department,job_title',
            'assignedAdmin:id,name,job_title,email',
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

    private function mediaTypeForFile(UploadedFile $file): string
    {
        $mimeType = strtolower((string) $file->getMimeType());

        return str_starts_with($mimeType, 'video/') ? 'video' : 'image';
    }

    private function presentReportsForViewer(Request $request, $reports): array
    {
        return $reports
            ->map(fn (Report $report) => $this->presentReportForViewer($request, $report))
            ->values()
            ->all();
    }

    private function presentReportForViewer(Request $request, Report $report): array
    {
        $payload = $report->toArray();
        $isWalkIn = $report->isWalkInComplaint();
        $payload['is_anonymous'] = (bool) $report->is_anonymous;
        $payload['is_walk_in'] = $isWalkIn;
        $payload['source'] = $isWalkIn ? 'walk_in' : 'citizen_app';
        $payload['source_label'] = $isWalkIn ? 'Administrative Staff Assistance' : 'Citizen Mobile App';
        $payload['reporter_name'] = $report->reporterNameForViewer($request->user());
        $payload['reporter_identity_hidden'] = $report->hidesReporterIdentityFrom($request->user());
        $payload['reporter_email'] = $report->reporterEmailForViewer($request->user());
        $payload['reporter_contact_number'] = $report->reporterContactNumberForViewer($request->user());
        $payload['reporter_address'] = $report->reporterAddressForViewer($request->user());
        $payload['complainant_name'] = $report->reporterNameForViewer($request->user());
        $payload['complainant_email'] = $report->reporterEmailForViewer($request->user());
        $payload['complainant_contact_number'] = $report->reporterContactNumberForViewer($request->user());
        $payload['complainant_address'] = $report->reporterAddressForViewer($request->user());
        $payload['complainant_is_senior_citizen'] = (bool) $report->walk_in_is_senior_citizen;
        $payload['complainant_is_pwd'] = (bool) $report->walk_in_is_pwd;
        $payload['assisted_by_front_desk'] = $isWalkIn;
        $payload['assisted_by_administrative_staff'] = $isWalkIn;
        $payload['assisted_by_role'] = $report->assistedByRole();
        $payload['assisted_by_role_label'] = $report->assistedByRoleLabel();
        $payload['printable_reference_number'] = $report->printable_reference_number;
        $payload['expected_return_at'] = optional($report->expected_return_at)?->toIso8601String();
        $payload['assisted_by_user'] = $report->assistedByUser === null ? null : [
            'id' => $report->assistedByUser->id,
            'name' => $report->assistedByUser->name,
            'email' => $report->assistedByUser->email,
            'mobile_number' => $report->assistedByUser->mobile_number,
            'department' => $report->assistedByUser->department,
            'job_title' => $report->assistedByUser->job_title,
        ];
        $payload['user'] = $report->sanitizedUserPayloadForViewer($request->user());

        if ($payload['reporter_identity_hidden'] || $isWalkIn) {
            $payload['user_id'] = null;
        }

        return $payload;
    }
}
