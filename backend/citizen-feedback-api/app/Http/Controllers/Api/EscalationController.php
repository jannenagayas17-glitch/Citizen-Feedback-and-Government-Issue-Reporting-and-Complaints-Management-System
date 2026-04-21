<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\ReportEscalation;
use App\Models\SystemSetting;
use Illuminate\Http\Request;

class EscalationController extends Controller
{
    private const SETTINGS_KEY = 'super_admin_portal';

    public function index(Request $request)
    {
        $this->ensureSuperAdmin($request);

        $settings = $this->resolvedSettings();
        $triggerHours = (int) data_get($settings, 'escalation_settings.trigger_time_hours', 72);
        $threshold = now()->subHours($triggerHours);

        $query = Report::query()
            ->with([
                'user',
                'category',
                'office',
                'assignedAdmin',
                'escalation.actor',
            ])
            ->where('status', '!=', 'Resolved')
            ->where('created_at', '<=', $threshold)
            ->latest();

        if ($request->filled('barangay')) {
            $query->where('barangay', $request->string('barangay')->toString());
        }

        if ($request->filled('priority')) {
            $query->where('priority', $request->string('priority')->toString());
        }

        $reports = $query->get();

        $items = $reports->map(function (Report $report) {
            $escalation = $report->escalation;
            $status = $escalation?->status ?? 'Open';

            return [
                'report_id' => $report->id,
                'tracking_id' => 'CTR-' . str_pad((string) $report->id, 5, '0', STR_PAD_LEFT),
                'title' => $report->title,
                'status' => $report->status,
                'priority' => $report->priority ?? 'Normal',
                'barangay' => $report->barangay,
                'location' => $report->location,
                'office' => optional($report->office)->name ?? 'Unassigned Office',
                'reporter' => optional($report->user)->name ?? 'Citizen Reporter',
                'assigned_to' => optional($report->assignedAdmin)->name,
                'age_hours' => (int) now()->diffInHours($report->created_at),
                'created_at' => optional($report->created_at)?->toIso8601String(),
                'updated_at' => optional($report->updated_at)?->toIso8601String(),
                'escalation' => [
                    'status' => $status,
                    'notes' => $escalation?->notes,
                    'escalated_at' => optional($escalation?->escalated_at)?->toIso8601String(),
                    'last_action_at' => optional($escalation?->last_action_at)?->toIso8601String(),
                    'actor' => $escalation?->actor ? [
                        'id' => $escalation->actor->id,
                        'name' => $escalation->actor->name,
                    ] : null,
                ],
            ];
        })->values();

        if ($request->filled('escalation_status')) {
            $statusFilter = $request->string('escalation_status')->toString();
            $items = $items
                ->filter(fn (array $item) => ($item['escalation']['status'] ?? 'Open') === $statusFilter)
                ->values();
        }

        return response()->json([
            'settings' => [
                'trigger_time_hours' => $triggerHours,
                'priority' => data_get($settings, 'escalation_settings.priority', 'High Priority'),
                'notification_channel' => data_get($settings, 'escalation_settings.notification_channel', 'Email & In-App'),
            ],
            'summary' => [
                'total' => $items->count(),
                'open' => $this->countEscalationsByStatus($items, 'Open'),
                'acknowledged' => $this->countEscalationsByStatus($items, 'Acknowledged'),
                'intervened' => $this->countEscalationsByStatus($items, 'Intervened'),
                'dismissed' => $this->countEscalationsByStatus($items, 'Dismissed'),
            ],
            'items' => $items->all(),
        ]);
    }

    public function update(Request $request, Report $report)
    {
        $this->ensureSuperAdmin($request);

        if ($report->status === 'Resolved') {
            return response()->json([
                'message' => 'Resolved reports cannot be escalated.',
            ], 422);
        }

        $validated = $request->validate([
            'status' => ['required', 'string', 'in:Open,Acknowledged,Intervened,Dismissed'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ]);

        $escalation = ReportEscalation::query()->updateOrCreate(
            ['report_id' => $report->id],
            [
                'status' => $validated['status'],
                'notes' => $validated['notes'] ?? null,
                'acted_by' => $request->user()->id,
                'escalated_at' => now(),
                'last_action_at' => now(),
            ]
        );

        return response()->json([
            'message' => 'Escalation updated successfully.',
            'escalation' => $escalation->load('actor'),
        ]);
    }

    private function ensureSuperAdmin(Request $request): void
    {
        if (($request->user()->role ?? null) !== 'super_admin') {
            abort(403, 'Unauthorized action.');
        }
    }

    private function resolvedSettings(): array
    {
        $defaults = [
            'escalation_settings' => [
                'trigger_time_hours' => 72,
                'notification_channel' => 'Email & In-App',
                'priority' => 'High Priority',
            ],
        ];

        $setting = SystemSetting::query()->where('key', self::SETTINGS_KEY)->first();

        return array_replace_recursive($defaults, $setting?->value ?? []);
    }

    private function countEscalationsByStatus($items, string $status): int
    {
        return $items
            ->filter(fn (array $item) => data_get($item, 'escalation.status') === $status)
            ->count();
    }
}
