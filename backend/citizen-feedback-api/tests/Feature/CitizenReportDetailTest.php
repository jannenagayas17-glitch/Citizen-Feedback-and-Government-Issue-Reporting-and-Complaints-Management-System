<?php

namespace Tests\Feature;

use App\Models\AdminResponse;
use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\StatusHistory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CitizenReportDetailTest extends TestCase
{
    use RefreshDatabase;

    public function test_citizen_reports_list_is_scoped_to_owner_and_returns_each_report_once(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $otherCitizen = $this->makeUser('Other Citizen', 'other-citizen@example.com', 'citizen');
        $assignedStaff = $this->makeUser('Assigned Staff', 'assigned@example.com', 'admin', [
            'department' => $office->name,
            'job_title' => 'Field Officer',
        ]);

        $ownedReport = Report::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Owned report',
            'description' => 'Citizen owned report',
            'location' => 'Main Street',
            'barangay' => 'Barangay 7',
            'status' => 'In Progress',
            'priority' => 'High',
            'assigned_to' => $assignedStaff->id,
        ]);

        StatusHistory::create([
            'report_id' => $ownedReport->id,
            'old_status' => 'New',
            'new_status' => 'In Progress',
            'remarks' => 'Staff started field validation.',
            'updated_by' => $assignedStaff->id,
        ]);

        AdminResponse::create([
            'report_id' => $ownedReport->id,
            'user_id' => $assignedStaff->id,
            'response' => 'We are validating the issue on site.',
        ]);

        Report::create([
            'user_id' => $otherCitizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Other citizen report',
            'description' => 'Should not be visible',
            'location' => 'Other Street',
            'barangay' => 'Barangay 9',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);

        Sanctum::actingAs($citizen);

        $response = $this->getJson('/api/reports');

        $response
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonPath('0.id', $ownedReport->id)
            ->assertJsonPath('0.assigned_admin.id', $assignedStaff->id)
            ->assertJsonPath('0.latest_status_history.report_id', $ownedReport->id)
            ->assertJsonPath('0.latest_admin_response.report_id', $ownedReport->id)
            ->assertJsonMissing(['title' => 'Other citizen report']);
    }

    public function test_citizen_report_detail_returns_only_the_selected_report_history_and_responses(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $assignedStaff = $this->makeUser('History Staff', 'history-staff@example.com', 'admin', [
            'department' => $office->name,
            'job_title' => 'Department Engineer',
        ]);

        $selectedReport = Report::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Selected report',
            'description' => 'Show exact details',
            'location' => 'Selected Location',
            'barangay' => 'Barangay 7',
            'status' => 'Resolved',
            'priority' => 'High',
            'assigned_to' => $assignedStaff->id,
            'resolved_at' => now(),
        ]);

        $otherReport = Report::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Other report',
            'description' => 'Should not leak into selected detail',
            'location' => 'Other Location',
            'barangay' => 'Barangay 8',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);

        $selectedHistory = StatusHistory::create([
            'report_id' => $selectedReport->id,
            'old_status' => 'In Progress',
            'new_status' => 'Resolved',
            'remarks' => 'Repair completed successfully.',
            'updated_by' => $assignedStaff->id,
        ]);

        $selectedResponse = AdminResponse::create([
            'report_id' => $selectedReport->id,
            'user_id' => $assignedStaff->id,
            'response' => 'The office completed the repair.',
        ]);

        StatusHistory::create([
            'report_id' => $otherReport->id,
            'old_status' => 'New',
            'new_status' => 'Pending',
            'remarks' => 'Different report history.',
            'updated_by' => $assignedStaff->id,
        ]);

        AdminResponse::create([
            'report_id' => $otherReport->id,
            'user_id' => $assignedStaff->id,
            'response' => 'Different report response.',
        ]);

        Sanctum::actingAs($citizen);

        $response = $this->getJson("/api/reports/{$selectedReport->id}");

        $response
            ->assertOk()
            ->assertJsonPath('id', $selectedReport->id)
            ->assertJsonPath('assigned_admin.id', $assignedStaff->id)
            ->assertJsonPath('status_histories.0.id', $selectedHistory->id)
            ->assertJsonPath('status_histories.0.report_id', $selectedReport->id)
            ->assertJsonPath('admin_responses.0.id', $selectedResponse->id)
            ->assertJsonPath('admin_responses.0.report_id', $selectedReport->id)
            ->assertJsonCount(1, 'status_histories')
            ->assertJsonCount(1, 'admin_responses')
            ->assertJsonMissing(['title' => 'Other report'])
            ->assertJsonMissing(['response' => 'Different report response.']);
    }

    private function seedCitizenReportDependencies(): array
    {
        return [
            $this->makeUser('Citizen Owner', 'citizen-owner@example.com', 'citizen'),
            Office::create(['name' => "City Engineer's Office", 'is_active' => true]),
            Category::create(['name' => 'Road Repairs']),
        ];
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
