<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\CitizenFeedback;
use App\Models\Report;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\StreamedResponse;

class CitizenFeedbackController extends Controller
{
    private const EMOJI_REGEX = '/[\x{1F1E6}-\x{1F1FF}\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]/u';

    public function index(Request $request)
    {
        $query = CitizenFeedback::query()
            ->with([
                'user:id,name,email',
                'office:id,name',
                'report:id,title,barangay,status,location,office_id,user_id',
                'report.office:id,name',
            ])
            ->latest();

        $user = $request->user();

        if (($user->role ?? 'citizen') === 'citizen') {
            $query->where('user_id', $user->id);
        } elseif (($user->role ?? null) === 'admin') {
            $this->ensureDepartmentHead($user);
            $this->scopeToUserDepartment($query, $user);
        } elseif (($user->role ?? null) !== 'super_admin') {
            abort(403, 'Unauthorized action.');
        }

        if ($request->filled('type')) {
            $query->where('type', $request->string('type')->toString());
        }

        if ($request->filled('barangay')) {
            $barangay = trim($request->string('barangay')->toString());
            $query->whereHas('report', function ($reportQuery) use ($barangay) {
                $reportQuery->where('barangay', $barangay);
            });
        }

        if ($request->filled('office_id')) {
            $query->where('office_id', (int) $request->integer('office_id'));
        }

        if ($request->filled('days')) {
            $days = max(1, (int) $request->integer('days'));
            $query->where('created_at', '>=', now()->subDays($days));
        }

        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        if (($request->user()->role ?? null) !== 'citizen') {
            abort(403, 'Only citizens can submit feedback.');
        }

        $validated = $request->validate([
            'office_id' => ['required', 'exists:offices,id'],
            'report_id' => ['nullable', 'exists:reports,id'],
            'type' => ['required', 'string', 'in:Suggestion,Complaint,Praise'],
            'message' => ['required', 'string', 'max:5000', 'not_regex:' . self::EMOJI_REGEX],
            'rating' => ['required', 'integer', 'between:1,5'],
        ], [
            'message.not_regex' => 'Emoji characters are not allowed.',
        ]);

        $report = null;

        if (! empty($validated['report_id'])) {
            $report = Report::query()
                ->where('id', $validated['report_id'])
                ->where('user_id', $request->user()->id)
                ->firstOrFail();

            if ((int) $report->office_id !== (int) $validated['office_id']) {
                abort(422, 'The selected department does not match this report.');
            }
        } else {
            $report = Report::query()
                ->where('user_id', $request->user()->id)
                ->where('office_id', $validated['office_id'])
                ->orderByRaw("case when status = 'Resolved' then 0 else 1 end")
                ->latest()
                ->first();
        }

        $feedback = CitizenFeedback::create([
            'user_id' => $request->user()->id,
            'office_id' => $validated['office_id'],
            'report_id' => $report?->id,
            'type' => $validated['type'],
            'message' => trim($validated['message']),
            'rating' => (int) $validated['rating'],
        ]);

        return response()->json([
            'message' => 'Feedback sent successfully.',
            'feedback' => $feedback->load([
                'user:id,name,email',
                'office:id,name',
                'report:id,title,barangay,status,location,office_id,user_id',
                'report.office:id,name',
            ]),
        ], 201);
    }

    public function export(Request $request): StreamedResponse
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $query = CitizenFeedback::query()
            ->with([
                'user:id,name,email',
                'office:id,name',
                'report:id,title,barangay,status,location,office_id,user_id',
            ])
            ->latest();

        if (($request->user()->role ?? null) === 'admin') {
            $this->ensureDepartmentHead($request->user());
            $this->scopeToUserDepartment($query, $request->user());
        }

        if ($request->filled('type')) {
            $query->where('type', $request->string('type')->toString());
        }

        if ($request->filled('barangay')) {
            $barangay = trim($request->string('barangay')->toString());
            $query->whereHas('report', function ($reportQuery) use ($barangay) {
                $reportQuery->where('barangay', $barangay);
            });
        }

        if ($request->filled('days')) {
            $days = max(1, (int) $request->integer('days'));
            $query->where('created_at', '>=', now()->subDays($days));
        }

        $items = $query->get();
        $fileName = 'citizen-feedback-' . now()->format('Ymd-His') . '.csv';

        return response()->streamDownload(function () use ($items) {
            $handle = fopen('php://output', 'w');

            fputcsv($handle, [
                'Feedback ID',
                'Report Title',
                'Reporter',
                'Barangay',
                'Status',
                'Feedback Type',
                'Rating',
                'Message',
                'Office',
                'Submitted At',
            ]);

            foreach ($items as $item) {
                fputcsv($handle, [
                    'FDB-' . str_pad((string) $item->id, 4, '0', STR_PAD_LEFT),
                    optional($item->report)->title ?? optional($item->office)->name ?? 'General Feedback',
                    optional($item->user)->name ?? 'Unknown Reporter',
                    optional($item->report)->barangay ?? '-',
                    optional($item->report)->status ?? '-',
                    $item->type,
                    $item->rating,
                    $item->message,
                    optional($item->office)->name ?? '-',
                    optional($item->created_at)?->format('Y-m-d H:i:s') ?? '-',
                ]);
            }

            fclose($handle);
        }, $fileName, [
            'Content-Type' => 'text/csv; charset=UTF-8',
            'Cache-Control' => 'no-store, no-cache',
        ]);
    }

    private function ensureDepartmentHead($user): void
    {
        if (! $user->isDepartmentHead()) {
            abort(403, 'Only the department head can view citizen feedback for this department.');
        }
    }

    private function scopeToUserDepartment($query, $user): void
    {
        $department = trim((string) ($user->department ?? ''));

        if ($department === '') {
            $query->whereRaw('1 = 0');
            return;
        }

        $query->whereHas('office', function ($officeQuery) use ($department) {
            $officeQuery->where('name', $department);
        });
    }
}
