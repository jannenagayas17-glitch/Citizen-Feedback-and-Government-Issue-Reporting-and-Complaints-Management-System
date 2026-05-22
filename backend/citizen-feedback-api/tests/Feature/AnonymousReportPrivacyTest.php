<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AnonymousReportPrivacyTest extends TestCase
{
    use RefreshDatabase;

    public function test_citizen_can_submit_an_anonymous_report_and_still_view_it_as_the_owner(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();

        Sanctum::actingAs($citizen);

        $createResponse = $this->postJson('/api/reports', $this->validReportPayload($office, $category, [
            'is_anonymous' => true,
        ]));

        $createResponse
            ->assertCreated()
            ->assertJsonPath('report.is_anonymous', true)
            ->assertJsonPath('report.user.name', $citizen->name)
            ->assertJsonPath('report.user.email', $citizen->email)
            ->assertJsonPath('report.user.mobile_number', $citizen->mobile_number)
            ->assertJsonPath('report.user_id', $citizen->id);

        $reportId = $createResponse->json('report.id');

        $this->assertDatabaseHas('reports', [
            'id' => $reportId,
            'is_anonymous' => true,
        ]);

        $this->getJson("/api/reports/{$reportId}")
            ->assertOk()
            ->assertJsonPath('is_anonymous', true)
            ->assertJsonPath('user.name', $citizen->name)
            ->assertJsonPath('user.email', $citizen->email)
            ->assertJsonPath('user.mobile_number', $citizen->mobile_number)
            ->assertJsonPath('user_id', $citizen->id);
    }

    public function test_citizen_report_submission_rejects_descriptions_longer_than_one_hundred_characters(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();

        Sanctum::actingAs($citizen);

        $response = $this->postJson('/api/reports', $this->validReportPayload($office, $category, [
            'description' => str_repeat('A', 101),
        ]));

        $response->assertStatus(422)
            ->assertJsonValidationErrors(['description'])
            ->assertJsonPath(
                'errors.description.0',
                'Description must be 100 characters or fewer.'
            );
    }

    public function test_admin_listing_and_detail_hide_anonymous_reporter_identity(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $admin = $this->makeUser('Scoped Admin', 'scoped-anon-admin@example.com', 'admin', [
            'department' => $office->name,
        ]);

        $report = Report::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Anonymous road report',
            'description' => 'Please hide my identity from the office.',
            'location' => 'Tacloban City Hall',
            'barangay' => 'Barangay 1',
            'status' => 'Pending',
            'priority' => 'Normal',
            'is_anonymous' => true,
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/reports')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.is_anonymous', true)
            ->assertJsonPath('0.reporter_name', 'Anonymous Citizen')
            ->assertJsonPath('0.reporter_identity_hidden', true)
            ->assertJsonPath('0.user.name', 'Anonymous Citizen')
            ->assertJsonPath('0.user.email', null)
            ->assertJsonPath('0.user.mobile_number', null)
            ->assertJsonPath('0.user.id', null)
            ->assertJsonPath('0.user_id', null);

        $this->getJson("/api/reports/{$report->id}")
            ->assertOk()
            ->assertJsonPath('is_anonymous', true)
            ->assertJsonPath('reporter_name', 'Anonymous Citizen')
            ->assertJsonPath('reporter_identity_hidden', true)
            ->assertJsonPath('user.name', 'Anonymous Citizen')
            ->assertJsonPath('user.email', null)
            ->assertJsonPath('user.mobile_number', null)
            ->assertJsonPath('user.id', null)
            ->assertJsonPath('user_id', null);
    }

    public function test_non_anonymous_reports_keep_reporter_identity_visible_to_admins(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $admin = $this->makeUser('Scoped Admin', 'visible-admin@example.com', 'admin', [
            'department' => $office->name,
        ]);

        $report = Report::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Visible identity report',
            'description' => 'My identity can remain visible.',
            'location' => 'Tacloban City Hall',
            'barangay' => 'Barangay 1',
            'status' => 'Pending',
            'priority' => 'Normal',
            'is_anonymous' => false,
        ]);

        Sanctum::actingAs($admin);

        $this->getJson("/api/reports/{$report->id}")
            ->assertOk()
            ->assertJsonPath('is_anonymous', false)
            ->assertJsonPath('reporter_name', $citizen->name)
            ->assertJsonPath('reporter_identity_hidden', false)
            ->assertJsonPath('user.name', $citizen->name)
            ->assertJsonPath('user.email', $citizen->email)
            ->assertJsonPath('user.mobile_number', $citizen->mobile_number)
            ->assertJsonPath('user_id', $citizen->id);
    }

    public function test_admin_report_export_hides_anonymous_reporter_identity(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $admin = $this->makeUser('Scoped Admin', 'export-anon-admin@example.com', 'admin', [
            'department' => $office->name,
        ]);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Anonymous export report',
            'description' => 'Hide reporter identity in exports.',
            'location' => 'Tacloban City Hall',
            'barangay' => 'Barangay 1',
            'status' => 'Pending',
            'priority' => 'Normal',
            'is_anonymous' => true,
        ]);

        Sanctum::actingAs($admin);

        $export = $this->get('/api/admin/reports/export');
        $content = $export->streamedContent();

        $export->assertOk();
        $this->assertStringContainsString('Anonymous Citizen', $content);
        $this->assertStringNotContainsString($citizen->name, $content);
        $this->assertStringNotContainsString($citizen->email, $content);
    }

    public function test_dashboard_recent_reports_hide_anonymous_reporter_identity(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $admin = $this->makeUser('Scoped Admin', 'analytics-anon-admin@example.com', 'admin', [
            'department' => $office->name,
        ]);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Anonymous dashboard report',
            'description' => 'Hide reporter identity in dashboard previews.',
            'location' => 'Tacloban City Hall',
            'barangay' => 'Barangay 1',
            'status' => 'Pending',
            'priority' => 'High',
            'is_anonymous' => true,
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/analytics')
            ->assertOk()
            ->assertJsonPath('recent_reports.0.is_anonymous', true)
            ->assertJsonPath('recent_reports.0.reporter_name', 'Anonymous Citizen')
            ->assertJsonPath('recent_reports.0.reporter_identity_hidden', true)
            ->assertJsonPath('recent_reports.0.user.name', 'Anonymous Citizen')
            ->assertJsonPath('recent_reports.0.user.email', null)
            ->assertJsonPath('recent_reports.0.user.mobile_number', null)
            ->assertJsonPath('recent_reports.0.user.id', null)
            ->assertJsonPath('recent_reports.0.user_id', null)
            ->assertJsonPath('triage_reports.0.user.name', 'Anonymous Citizen');
    }

    private function seedCitizenReportDependencies(): array
    {
        return [
            $this->makeUser('Citizen Owner', 'citizen-owner@example.com', 'citizen', [
                'mobile_number' => '09171234567',
            ]),
            Office::create(['name' => "City Engineer's Office", 'is_active' => true]),
            Category::create(['name' => 'Road Repairs']),
        ];
    }

    private function validReportPayload(Office $office, Category $category, array $overrides = []): array
    {
        return array_merge([
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Citizen anonymous complaint',
            'description' => 'Road section needs repair and inspection.',
            'location' => 'Barangay 1, Tacloban City',
            'barangay' => 'Barangay 1',
            'priority' => 'Normal',
        ], $overrides);
    }

    private function makeUser(string $name, string $email, string $role, array $overrides = []): User
    {
        return User::create(array_merge([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make('password123'),
            'role' => $role,
            'is_active' => true,
        ], $overrides));
    }
}
