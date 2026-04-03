<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\SystemSetting;
use Illuminate\Http\Request;

class SystemSettingController extends Controller
{
    private const SETTINGS_KEY = 'super_admin_portal';

    public function show(Request $request)
    {
        $this->ensureSuperAdmin($request);

        $setting = SystemSetting::query()->firstOrCreate(
            ['key' => self::SETTINGS_KEY],
            ['value' => $this->defaultSettings()]
        );

        return response()->json([
            'settings' => array_replace_recursive(
                $this->defaultSettings(),
                $setting->value ?? []
            ),
        ]);
    }

    public function update(Request $request)
    {
        $this->ensureSuperAdmin($request);

        $validated = $request->validate([
            'notifications.enable_alerts' => ['required', 'boolean'],
            'notifications.escalation_notifications' => ['required', 'boolean'],
            'notifications.feedback_notifications' => ['required', 'boolean'],
            'report_settings.default_due_hours' => ['required', 'integer', 'min:1', 'max:336'],
            'report_settings.default_due_unit' => ['required', 'string', 'in:Hours,Days'],
            'escalation_settings.trigger_time_hours' => ['required', 'integer', 'min:1', 'max:720'],
            'escalation_settings.notification_channel' => ['required', 'string', 'in:Email,Email & In-App,In-App Only'],
            'escalation_settings.priority' => ['required', 'string', 'in:Low Priority,Normal Priority,High Priority,Critical Priority'],
        ]);

        $setting = SystemSetting::query()->updateOrCreate(
            ['key' => self::SETTINGS_KEY],
            ['value' => $validated]
        );

        return response()->json([
            'message' => 'Settings updated successfully.',
            'settings' => array_replace_recursive(
                $this->defaultSettings(),
                $setting->value ?? []
            ),
        ]);
    }

    private function ensureSuperAdmin(Request $request): void
    {
        if (($request->user()->role ?? null) !== 'super_admin') {
            abort(403, 'Unauthorized action.');
        }
    }

    private function defaultSettings(): array
    {
        return [
            'notifications' => [
                'enable_alerts' => true,
                'escalation_notifications' => true,
                'feedback_notifications' => true,
            ],
            'report_settings' => [
                'default_due_hours' => 48,
                'default_due_unit' => 'Hours',
            ],
            'escalation_settings' => [
                'trigger_time_hours' => 72,
                'notification_channel' => 'Email & In-App',
                'priority' => 'High Priority',
            ],
        ];
    }
}
