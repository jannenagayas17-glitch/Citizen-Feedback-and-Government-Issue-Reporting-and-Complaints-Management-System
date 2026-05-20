<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class WalkInComplaintAssistanceTest extends TestCase
{
    use RefreshDatabase;

    private const TINY_PNG_BASE64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a5i0AAAAASUVORK5CYII=';

    public function test_administrative_staff_can_submit_a_walk_in_complaint_with_printable_metadata_and_media(): void
    {
        Storage::fake('public');

        $office = Office::create([
            'name' => 'City Social Welfare Office',
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Senior Assistance',
        ]);

        $administrativeStaff = $this->makeStaffUser(
            'Administrative Staff Officer',
            'adminstaff@example.com',
            'administrative_staff',
            $office->name,
            'Administrative Staff'
        );

        Sanctum::actingAs($administrativeStaff);

        $response = $this->post('/api/administrative-staff/reports', [
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Walk-in drainage concern',
            'description' => 'Senior citizen requested assistance for flooding near the market.',
            'location' => 'Tacloban Public Market',
            'barangay' => 'Barangay 13',
            'priority' => 'High',
            'walk_in_full_name' => 'Maria Santos',
            'walk_in_contact_number' => '09171234567',
            'walk_in_email' => 'maria.santos@example.com',
            'walk_in_address' => 'Barangay 13, Tacloban City',
            'walk_in_is_senior_citizen' => true,
            'expected_return_at' => '2026-05-23 10:00:00',
            'media' => [
                $this->fakePngUpload('walk-in-evidence.png'),
            ],
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('report.is_walk_in', true)
            ->assertJsonPath('report.source', 'walk_in')
            ->assertJsonPath('report.source_label', 'Administrative Staff Assistance')
            ->assertJsonPath('report.complainant_name', 'Maria Santos')
            ->assertJsonPath('report.complainant_contact_number', '09171234567')
            ->assertJsonPath('report.assisted_by_user.name', $administrativeStaff->name)
            ->assertJsonPath('report.assisted_by_role', 'administrative_staff')
            ->assertJsonPath('report.assisted_by_role_label', 'Administrative Staff')
            ->assertJsonPath('report.complainant_is_senior_citizen', true)
            ->assertJsonPath('report.images.0.media_type', 'image');

        $reportId = $response->json('report.id');
        $storedPath = $response->json('report.images.0.image_path');

        Storage::disk('public')->assertExists($storedPath);
        $this->assertDatabaseHas('reports', [
            'id' => $reportId,
            'source' => 'walk_in',
            'assisted_by_user_id' => $administrativeStaff->id,
            'assisted_by_role' => 'administrative_staff',
            'walk_in_full_name' => 'Maria Santos',
            'walk_in_contact_number' => '09171234567',
            'walk_in_address' => 'Barangay 13, Tacloban City',
            'walk_in_is_senior_citizen' => true,
            'walk_in_is_pwd' => false,
        ]);

        $printableReference = $response->json('report.printable_reference_number');
        $this->assertNotNull($printableReference);
        $this->assertStringStartsWith('WIC-', $printableReference);
    }

    public function test_administrative_staff_and_admin_scopes_for_walk_in_reports_remain_limited(): void
    {
        [$officeA, $officeB] = [
            Office::create(['name' => 'City Engineering Office', 'is_active' => true]),
            Office::create(['name' => 'City Health Office', 'is_active' => true]),
        ];

        $category = Category::create(['name' => 'General Assistance']);

        $frontDeskA = $this->makeStaffUser(
            'Administrative Staff A',
            'adminstaff-a@example.com',
            'administrative_staff',
            $officeA->name,
            'Administrative Staff'
        );
        $frontDeskB = $this->makeStaffUser(
            'Administrative Staff B',
            'adminstaff-b@example.com',
            'administrative_staff',
            $officeB->name,
            'Administrative Staff'
        );
        $adminA = $this->makeStaffUser(
            'Office Admin A',
            'admin-a@example.com',
            'admin',
            $officeA->name,
            'Office Head'
        );
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'super-walkin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $reportA = Report::create([
            'user_id' => $frontDeskA->id,
            'assisted_by_user_id' => $frontDeskA->id,
            'source' => 'walk_in',
            'category_id' => $category->id,
            'office_id' => $officeA->id,
            'title' => 'Walk-in report A',
            'description' => 'Concern scoped to engineering office.',
            'location' => 'City Hall',
            'barangay' => 'Barangay 1',
            'status' => 'New',
            'priority' => 'Normal',
            'walk_in_full_name' => 'Ana Reyes',
            'walk_in_contact_number' => '09170000001',
            'walk_in_address' => 'Barangay 1, Tacloban City',
            'printable_reference_number' => 'WIC-20260519-AAAAAA',
        ]);

        $reportB = Report::create([
            'user_id' => $frontDeskB->id,
            'assisted_by_user_id' => $frontDeskB->id,
            'source' => 'walk_in',
            'category_id' => $category->id,
            'office_id' => $officeB->id,
            'title' => 'Walk-in report B',
            'description' => 'Concern scoped to city health office.',
            'location' => 'District Health Center',
            'barangay' => 'Barangay 5',
            'status' => 'Pending',
            'priority' => 'High',
            'walk_in_full_name' => 'Joel Cruz',
            'walk_in_contact_number' => '09170000002',
            'walk_in_address' => 'Barangay 5, Tacloban City',
            'printable_reference_number' => 'WIC-20260519-BBBBBB',
        ]);

        Sanctum::actingAs($frontDeskA);

        $this->getJson('/api/administrative-staff/reports')
            ->assertOk()
            ->assertJsonPath('data.0.id', $reportA->id)
            ->assertJsonPath('data.0.complainant_name', 'Ana Reyes')
            ->assertJsonMissing(['id' => $reportB->id])
            ->assertJsonMissing(['complainant_name' => 'Joel Cruz']);

        Sanctum::actingAs($adminA);

        $this->getJson('/api/admin/reports')
            ->assertOk()
            ->assertJsonFragment([
                'id' => $reportA->id,
                'source' => 'walk_in',
                'complainant_name' => 'Ana Reyes',
            ])
            ->assertJsonMissing([
                'id' => $reportB->id,
                'complainant_name' => 'Joel Cruz',
            ]);

        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/admin/reports')
            ->assertOk()
            ->assertJsonFragment(['id' => $reportA->id, 'complainant_name' => 'Ana Reyes'])
            ->assertJsonFragment(['id' => $reportB->id, 'complainant_name' => 'Joel Cruz']);
    }

    public function test_administrative_staff_can_only_open_walk_in_report_details_that_they_assisted(): void
    {
        $office = Office::create([
            'name' => 'City Agriculture Office',
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Agriculture Support',
        ]);

        $frontDeskA = $this->makeStaffUser(
            'Administrative Staff A',
            'adminstaff-detail-a@example.com',
            'administrative_staff',
            $office->name,
            'Administrative Staff'
        );
        $frontDeskB = $this->makeStaffUser(
            'Administrative Staff B',
            'adminstaff-detail-b@example.com',
            'administrative_staff',
            $office->name,
            'Administrative Staff'
        );

        $ownedReport = Report::create([
            'user_id' => $frontDeskA->id,
            'assisted_by_user_id' => $frontDeskA->id,
            'source' => 'walk_in',
            'category_id' => $category->id,
            'office_id' => $office->id,
            'title' => 'Owned walk-in report',
            'description' => 'Owned report detail.',
            'location' => 'Barangay Hall',
            'barangay' => 'Barangay 12',
            'status' => 'New',
            'priority' => 'Normal',
            'walk_in_full_name' => 'Teresa Lim',
            'walk_in_contact_number' => '09170000003',
            'walk_in_address' => 'Barangay 12, Tacloban City',
            'expected_return_at' => '2026-05-24 09:00:00',
            'printable_reference_number' => 'WIC-20260519-CCCCCC',
        ]);

        $otherReport = Report::create([
            'user_id' => $frontDeskB->id,
            'assisted_by_user_id' => $frontDeskB->id,
            'source' => 'walk_in',
            'category_id' => $category->id,
            'office_id' => $office->id,
            'title' => 'Other walk-in report',
            'description' => 'Other report detail.',
            'location' => 'Agriculture Office',
            'barangay' => 'Barangay 14',
            'status' => 'Pending',
            'priority' => 'High',
            'walk_in_full_name' => 'Pedro Tan',
            'walk_in_contact_number' => '09170000004',
            'walk_in_address' => 'Barangay 14, Tacloban City',
            'printable_reference_number' => 'WIC-20260519-DDDDDD',
        ]);

        Sanctum::actingAs($frontDeskA);

        $this->getJson("/api/reports/{$ownedReport->id}")
            ->assertOk()
            ->assertJsonPath('id', $ownedReport->id)
            ->assertJsonPath('source', 'walk_in')
            ->assertJsonPath('complainant_name', 'Teresa Lim')
            ->assertJsonPath('expected_return_at', $ownedReport->expected_return_at?->toIso8601String())
            ->assertJsonPath('assisted_by_user.name', $frontDeskA->name);

        $this->getJson("/api/reports/{$otherReport->id}")
            ->assertForbidden();
    }

    public function test_administrative_staff_cannot_submit_the_same_walk_in_complaint_twice_within_five_minutes(): void
    {
        $office = Office::create([
            'name' => 'City Licensing Office',
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Walk-in Support',
        ]);

        $administrativeStaff = $this->makeStaffUser(
            'Administrative Staff Duplicate Guard',
            'adminstaff-duplicate@example.com',
            'administrative_staff',
            $office->name,
            'Administrative Staff'
        );

        Sanctum::actingAs($administrativeStaff);

        $payload = [
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Same assisted complaint',
            'description' => 'Duplicate submission check for the same walk-in complaint.',
            'location' => 'Business Permit Desk',
            'barangay' => 'Barangay 21',
            'priority' => 'Normal',
            'walk_in_full_name' => 'Ramon Flores',
            'walk_in_contact_number' => '09175553333',
            'walk_in_email' => 'ramon.flores@example.com',
            'walk_in_address' => 'Barangay 21, Tacloban City',
        ];

        $this->postJson('/api/administrative-staff/reports', $payload)
            ->assertCreated();

        $this->postJson('/api/administrative-staff/reports', $payload)
            ->assertStatus(422)
            ->assertJsonValidationErrors(['title'])
            ->assertJsonPath(
                'errors.title.0',
                'A similar walk-in complaint was already submitted recently. Please review the latest slip before creating another one.'
            );
    }

    public function test_administrative_staff_dashboard_and_listing_work_when_source_column_is_missing(): void
    {
        Storage::fake('public');

        $office = Office::create([
            'name' => 'City Disaster Risk Reduction Office',
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Emergency Support',
        ]);

        $administrativeStaff = $this->makeStaffUser(
            'Administrative Staff Legacy',
            'adminstaff-legacy@example.com',
            'administrative_staff',
            $office->name,
            'Administrative Staff'
        );

        Schema::table('reports', function (Blueprint $table) {
            $table->dropColumn('source');
        });

        Sanctum::actingAs($administrativeStaff);

        $response = $this->post('/api/administrative-staff/reports', [
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Legacy walk-in concern',
            'description' => 'Legacy schema still accepts walk-in complaints.',
            'location' => 'Emergency Operations Center',
            'barangay' => 'Barangay 21',
            'priority' => 'Urgent',
            'walk_in_full_name' => 'Pedro Martinez',
            'walk_in_contact_number' => '09179998888',
            'walk_in_email' => 'pedro.martinez@example.com',
            'walk_in_address' => 'Barangay 21, Tacloban City',
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('report.is_walk_in', true)
            ->assertJsonPath('report.source', 'walk_in')
            ->assertJsonPath('report.complainant_name', 'Pedro Martinez');

        $reportId = $response->json('report.id');

        $this->getJson('/api/dashboard')
            ->assertOk()
            ->assertJsonPath('total_reports', 1)
            ->assertJsonPath('new', 1);

        $this->getJson('/api/administrative-staff/reports')
            ->assertOk()
            ->assertJsonPath('data.0.id', $reportId)
            ->assertJsonPath('data.0.is_walk_in', true)
            ->assertJsonPath('data.0.source', 'walk_in')
            ->assertJsonPath('data.0.complainant_name', 'Pedro Martinez');
    }

    private function makeStaffUser(
        string $name,
        string $email,
        string $role,
        string $department,
        string $jobTitle,
    ): User {
        return User::create([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make('password123'),
            'role' => $role,
            'department' => $department,
            'job_title' => $jobTitle,
            'is_active' => true,
        ]);
    }

    private function fakePngUpload(string $fileName): UploadedFile
    {
        return UploadedFile::fake()->createWithContent(
            $fileName,
            base64_decode(self::TINY_PNG_BASE64, true) ?: ''
        );
    }
}
