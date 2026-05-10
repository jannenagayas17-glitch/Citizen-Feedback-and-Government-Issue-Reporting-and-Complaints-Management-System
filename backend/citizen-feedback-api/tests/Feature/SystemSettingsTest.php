<?php

namespace Tests\Feature;

use App\Models\SystemSetting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class SystemSettingsTest extends TestCase
{
    use RefreshDatabase;

    public function test_super_admin_can_persist_alert_preferences_and_read_them_back(): void
    {
        Sanctum::actingAs($this->makeSuperAdmin());

        $payload = $this->validSettingsPayload([
            'notifications' => [
                'enable_alerts' => true,
                'escalation_notifications' => false,
                'feedback_notifications' => true,
            ],
        ]);

        $this->putJson('/api/admin/settings', $payload)
            ->assertOk()
            ->assertJsonPath('settings.notifications.enable_alerts', true)
            ->assertJsonPath('settings.notifications.escalation_notifications', false)
            ->assertJsonPath('settings.notifications.feedback_notifications', true);

        $this->getJson('/api/admin/settings')
            ->assertOk()
            ->assertJsonPath('settings.notifications.enable_alerts', true)
            ->assertJsonPath('settings.notifications.escalation_notifications', false)
            ->assertJsonPath('settings.notifications.feedback_notifications', true);

        $setting = SystemSetting::query()->where('key', 'super_admin_portal')->firstOrFail();

        $this->assertSame(true, data_get($setting->value, 'notifications.enable_alerts'));
        $this->assertSame(false, data_get($setting->value, 'notifications.escalation_notifications'));
        $this->assertSame(true, data_get($setting->value, 'notifications.feedback_notifications'));
    }

    public function test_super_admin_can_update_settings_through_the_post_route_alias(): void
    {
        Sanctum::actingAs($this->makeSuperAdmin('alias-super@example.com'));

        $payload = $this->validSettingsPayload([
            'notifications' => [
                'enable_alerts' => false,
                'escalation_notifications' => false,
                'feedback_notifications' => false,
            ],
        ]);

        $this->postJson('/api/admin/settings', $payload)
            ->assertOk()
            ->assertJsonPath('settings.notifications.enable_alerts', false)
            ->assertJsonPath('settings.notifications.escalation_notifications', false)
            ->assertJsonPath('settings.notifications.feedback_notifications', false);
    }

    private function makeSuperAdmin(string $email = 'settings-super@example.com'): User
    {
        return User::create([
            'name' => 'Settings Super Admin',
            'email' => $email,
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);
    }

    private function validSettingsPayload(array $overrides = []): array
    {
        return array_replace_recursive([
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
        ], $overrides);
    }
}
