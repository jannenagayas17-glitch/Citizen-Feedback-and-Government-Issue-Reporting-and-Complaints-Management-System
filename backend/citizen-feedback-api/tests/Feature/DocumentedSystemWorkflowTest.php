<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DocumentedSystemWorkflowTest extends TestCase
{
    use RefreshDatabase;

    public function test_tc_cit_reg_01_register_successfully_with_valid_citizen_data(): void
    {
        $response = $this->postJson('/api/auth/register', $this->validCitizenRegistrationPayload());

        $response
            ->assertCreated()
            ->assertJsonStructure(['message', 'user', 'token'])
            ->assertJsonPath('user.email', 'gjannena@example.com');

        $this->assertDatabaseHas('users', [
            'email' => 'gjannena@example.com',
            'role' => 'citizen',
        ]);
    }

    public function test_tc_cit_reg_02_registration_with_all_fields_empty_fails(): void
    {
        $this->assertCitizenRegistrationFails([
            'name' => '',
            'email' => '',
            'mobile_number' => '',
            'password' => '',
            'password_confirmation' => '',
        ], 'name');
    }

    public function test_tc_cit_reg_03_invalid_email_format_fails(): void
    {
        $this->assertCitizenRegistrationFails(['email' => 'gjannena'], 'email');
    }

    public function test_tc_cit_reg_04_password_too_short_fails(): void
    {
        $this->assertCitizenRegistrationFails([
            'password' => '123',
            'password_confirmation' => '123',
        ], 'password');
    }

    public function test_tc_cit_reg_05_email_already_exists_fails(): void
    {
        User::create([
            'name' => 'Existing User',
            'email' => 'existing@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
        ]);

        $this->assertCitizenRegistrationFails(['email' => 'existing@example.com'], 'email');
    }

    public function test_tc_cit_reg_06_password_and_confirm_password_mismatch_fails(): void
    {
        $this->assertCitizenRegistrationFails([
            'password' => 'Pass@test123',
            'password_confirmation' => 'Pass@test321',
        ], 'password');
    }

    public function test_tc_cit_reg_07_password_without_special_character_is_accepted(): void
    {
        $response = $this->postJson('/api/auth/register', array_merge(
            $this->validCitizenRegistrationPayload(),
            [
                'email' => 'plainpassword@example.com',
                'password' => 'Password123',
                'password_confirmation' => 'Password123',
            ]
        ));

        $response->assertCreated();
    }

    public function test_tc_cit_reg_08_invalid_mobile_number_format_fails(): void
    {
        $this->assertCitizenRegistrationFails(['mobile_number' => '12345'], 'mobile_number');
    }

    public function test_tc_cit_reg_09_mobile_number_accepts_only_numeric_value_backend_validation(): void
    {
        $this->assertCitizenRegistrationFails(['mobile_number' => '09ABC12345'], 'mobile_number');
    }

    public function test_tc_cit_reg_10_full_name_with_numbers_fails(): void
    {
        $this->assertCitizenRegistrationFails(['name' => 'Jannena123 Gayas'], 'name');
    }

    public function test_tc_cit_reg_11_email_with_outer_spaces_is_normalized_safely(): void
    {
        $response = $this->postJson('/api/auth/register', array_merge(
            $this->validCitizenRegistrationPayload(),
            ['email' => ' spaced@example.com ']
        ));

        $response
            ->assertCreated()
            ->assertJsonPath('user.email', 'spaced@example.com');
    }

    public function test_tc_cit_reg_12_register_with_emoji_characters_fails(): void
    {
        $this->assertCitizenRegistrationFails([
            'name' => 'Jannena ' . "\u{1F60A}" . ' Gayas',
            'password' => 'Test@123' . "\u{1F60A}",
            'password_confirmation' => 'Test@123' . "\u{1F60A}",
        ], 'name');
    }

    public function test_tc_cit_reg_14_register_with_values_exceeding_maximum_length_fails(): void
    {
        $this->assertCitizenRegistrationFails([
            'name' => str_repeat('Jannena ', 40) . 'Gayas',
            'mobile_number' => '091234567890123',
        ], 'name');
    }

    public function test_tc_log_01_login_successfully_using_valid_credentials(): void
    {
        $this->makeUser('Test Citizen', 'test123@example.com', 'citizen', [
            'password' => Hash::make('Pass@test123'),
        ]);

        $this->postJson('/api/auth/login', [
            'email' => 'test123@example.com',
            'password' => 'Pass@test123',
        ])
            ->assertOk()
            ->assertJsonStructure(['message', 'user', 'token']);
    }

    public function test_tc_log_02_login_with_empty_fields_fails(): void
    {
        $this->postJson('/api/auth/login', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['email', 'password']);
    }

    public function test_tc_log_03_login_with_invalid_email_format_fails(): void
    {
        $this->postJson('/api/auth/login', [
            'email' => 'test123',
            'password' => 'Pass@test123',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_tc_amu_04_login_with_incorrect_credentials_fails(): void
    {
        $this->makeUser('Valid User', 'valid@example.com', 'citizen', [
            'password' => Hash::make('Pass@test123'),
        ]);

        $this->postJson('/api/auth/login', [
            'email' => 'valid@example.com',
            'password' => 'WrongPass123',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_tc_amu_05_login_with_emoji_or_invalid_characters_fails(): void
    {
        $this->postJson('/api/auth/login', [
            'email' => 'test' . "\u{1F60A}" . '@example.com',
            'password' => 'Pass' . "\u{1F60A}" . '123',
        ])->assertUnprocessable();
    }

    public function test_tc_log_pending_admin_cannot_login_until_verified(): void
    {
        $this->makeUser('Pending Admin', 'pending-admin@example.com', 'pending_admin');

        $this->postJson('/api/auth/login', [
            'email' => 'pending-admin@example.com',
            'password' => 'password123',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_tc_log_deactivated_user_cannot_login(): void
    {
        $this->makeUser('Disabled User', 'disabled-user@example.com', 'citizen', [
            'is_active' => false,
        ]);

        $this->postJson('/api/auth/login', [
            'email' => 'disabled-user@example.com',
            'password' => 'password123',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_tc_fp_06_send_reset_link_with_valid_email(): void
    {
        Notification::fake();
        $this->makeUser('Reset User', 'reset@example.com', 'citizen');

        $this->postJson('/api/forgot-password', [
            'email' => 'reset@example.com',
        ])->assertOk();
    }

    public function test_tc_fp_invalid_email_format_fails(): void
    {
        $this->postJson('/api/forgot-password', [
            'email' => 'not-an-email',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_tc_ri_02_select_department_office_dropdown_returns_active_offices_only(): void
    {
        Office::create(['name' => "City Engineer's Office", 'is_active' => true]);
        Office::create(['name' => 'Inactive Office', 'is_active' => false]);

        $this->getJson('/api/offices')
            ->assertOk()
            ->assertJsonFragment(['name' => "City Engineer's Office"])
            ->assertJsonMissing(['name' => 'Inactive Office']);
    }

    public function test_tc_cd_category_filter_support_data_returns_categories(): void
    {
        Category::create(['name' => 'Road Repairs']);

        $this->getJson('/api/categories')
            ->assertOk()
            ->assertJsonFragment(['name' => 'Road Repairs']);
    }

    public function test_tc_ri_01_submit_valid_issue_successfully(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        Sanctum::actingAs($citizen);

        $this->postJson('/api/reports', $this->validReportPayload($office, $category))
            ->assertCreated()
            ->assertJsonPath('report.status', 'New')
            ->assertJsonPath('report.barangay', 'Barangay 7');
    }

    public function test_tc_ri_03_barangay_required_field_fails(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        Sanctum::actingAs($citizen);

        $this->postJson('/api/reports', array_merge(
            $this->validReportPayload($office, $category),
            ['barangay' => null]
        ))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('barangay');
    }

    public function test_tc_ri_invalid_emoji_in_report_title_fails(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        Sanctum::actingAs($citizen);

        $this->postJson('/api/reports', array_merge(
            $this->validReportPayload($office, $category),
            ['title' => 'Broken road ' . "\u{1F60A}"]
        ))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('title');
    }

    public function test_tc_ri_invalid_office_id_fails(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        Sanctum::actingAs($citizen);

        $this->postJson('/api/reports', array_merge(
            $this->validReportPayload($office, $category),
            ['office_id' => 999999]
        ))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('office_id');
    }

    public function test_tc_cd_my_reports_show_only_logged_in_citizen_reports(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $otherCitizen = $this->makeUser('Other Citizen', 'other@example.com', 'citizen');

        Report::create(array_merge($this->validReportPayload($office, $category), [
            'user_id' => $citizen->id,
            'status' => 'New',
        ]));

        Report::create([
            'user_id' => $otherCitizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Other user report',
            'description' => 'Should not be visible',
            'location' => 'Other Location',
            'barangay' => 'Barangay 9',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);

        Sanctum::actingAs($citizen);

        $this->getJson('/api/reports')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonFragment(['title' => 'Broken road']);
    }

    public function test_tc_cd_citizen_dashboard_counts_only_logged_in_citizen_reports(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $otherCitizen = $this->makeUser('Other Citizen', 'other-dashboard@example.com', 'citizen');

        Report::create(array_merge($this->validReportPayload($office, $category), [
            'user_id' => $citizen->id,
            'status' => 'New',
        ]));

        Report::create([
            'user_id' => $otherCitizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Other user dashboard report',
            'description' => 'Should not be counted in citizen dashboard',
            'location' => 'Other Location',
            'barangay' => 'Barangay 9',
            'status' => 'Resolved',
            'priority' => 'Normal',
        ]);

        Sanctum::actingAs($citizen);

        $this->getJson('/api/dashboard')
            ->assertOk()
            ->assertJsonPath('total_reports', 1)
            ->assertJsonPath('new', 1)
            ->assertJsonPath('resolved', 0);
    }

    public function test_tc_ad_01_admin_dashboard_reports_are_scoped_to_assigned_office(): void
    {
        [$officeA, , $category] = $this->seedTwoOfficesWithReports();
        $admin = $this->makeUser('Office Admin', 'office-admin@example.com', 'admin', [
            'department' => $officeA->name,
        ]);

        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/reports')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonFragment(['title' => 'Office A report'])
            ->assertJsonMissing(['title' => 'Office B report']);

        $this->getJson('/api/admin/analytics')
            ->assertOk()
            ->assertJsonPath('overview.total_reports', 1)
            ->assertJsonFragment(['label' => $category->name, 'count' => 1]);
    }

    public function test_tc_sa_02_super_admin_can_view_all_reports_and_dashboard_analytics(): void
    {
        $this->seedTwoOfficesWithReports();
        $superAdmin = $this->makeUser('Super Admin', 'superadmin@example.com', 'super_admin');

        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/admin/reports')
            ->assertOk()
            ->assertJsonCount(2);

        $this->getJson('/api/admin/analytics')
            ->assertOk()
            ->assertJsonPath('overview.total_reports', 2)
            ->assertJsonStructure([
                'overview',
                'status_breakdown',
                'category_breakdown',
                'barangay_breakdown',
                'monthly_trend',
            ]);
    }

    public function test_tc_ri_citizen_submitted_report_is_visible_to_super_admin_and_matching_department_admin(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $departmentAdmin = $this->makeUser('Matching Admin', 'matching-admin@example.com', 'admin', [
            'department' => $office->name,
        ]);
        $otherAdmin = $this->makeUser('Other Admin', 'other-admin@example.com', 'admin', [
            'department' => 'Other Department',
        ]);
        $superAdmin = $this->makeUser('Report Super Admin', 'report-super@example.com', 'super_admin');

        Sanctum::actingAs($citizen);
        $reportId = $this->postJson('/api/reports', $this->validReportPayload($office, $category))
            ->assertCreated()
            ->json('report.id');

        Sanctum::actingAs($superAdmin);
        $this->getJson('/api/admin/reports')
            ->assertOk()
            ->assertJsonFragment(['id' => $reportId, 'office_id' => $office->id]);

        Sanctum::actingAs($departmentAdmin);
        $this->getJson('/api/admin/reports')
            ->assertOk()
            ->assertJsonFragment(['id' => $reportId, 'office_id' => $office->id]);

        Sanctum::actingAs($otherAdmin);
        $this->getJson('/api/admin/reports')
            ->assertOk()
            ->assertJsonMissing(['id' => $reportId, 'office_id' => $office->id]);
    }

    public function test_tc_adm_rpt_006_admin_can_update_report_status(): void
    {
        [$office] = $this->seedTwoOfficesWithReports();
        $admin = $this->makeUser('Office Admin', 'status-admin@example.com', 'admin', [
            'department' => $office->name,
        ]);
        $report = Report::query()->where('office_id', $office->id)->firstOrFail();

        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/reports/{$report->id}/status", [
            'status' => 'In Progress',
            'remarks' => 'Admin started triage.',
        ])
            ->assertOk()
            ->assertJsonPath('report.status', 'In Progress');

        $this->assertDatabaseHas('status_histories', [
            'report_id' => $report->id,
            'new_status' => 'In Progress',
        ]);
    }

    public function test_tc_adm_rpt_008_admin_can_assign_report_to_staff(): void
    {
        [$office] = $this->seedTwoOfficesWithReports();
        $admin = $this->makeUser('Office Admin', 'assign-admin@example.com', 'admin', [
            'department' => $office->name,
        ]);
        $staff = $this->makeUser('Juan Dela Cruz', 'staff@example.com', 'admin', [
            'department' => $office->name,
            'job_title' => 'Field Engineer',
        ]);
        $report = Report::query()->where('office_id', $office->id)->firstOrFail();

        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/reports/{$report->id}/status", [
            'status' => 'In Progress',
            'assigned_to' => $staff->id,
        ])
            ->assertOk()
            ->assertJsonPath('report.assigned_to', $staff->id);
    }

    public function test_tc_adm_rpt_005_export_reports_downloads_excel_ready_file_with_analytics_and_tables(): void
    {
        [$office, , $category] = $this->seedTwoOfficesWithReports();
        $admin = $this->makeUser('Office Admin', 'export-admin@example.com', 'admin', [
            'department' => $office->name,
        ]);

        Sanctum::actingAs($admin);

        $export = $this->get('/api/admin/reports/export');
        $content = $export->streamedContent();

        $export->assertOk();
        $export->assertHeader('Content-Type', 'application/vnd.ms-excel; charset=UTF-8');
        $this->assertStringContainsString('Analytics Summary', $content);
        $this->assertStringContainsString('Reports by Department', $content);
        $this->assertStringContainsString('All Report Records', $content);
        $this->assertStringContainsString('Report ID', $content);
        $this->assertStringContainsString($category->name, $content);
    }

    public function test_tc_sa_export_reports_includes_all_departments_and_analytics(): void
    {
        [$officeA, $officeB] = $this->seedTwoOfficesWithReports();
        $superAdmin = $this->makeUser('Super Admin', 'export-super@example.com', 'super_admin');

        Sanctum::actingAs($superAdmin);

        $export = $this->get('/api/admin/reports/export');
        $content = $export->streamedContent();

        $export->assertOk();
        $this->assertStringContainsString('Analytics Summary', $content);
        $this->assertStringContainsString($officeA->name, $content);
        $this->assertStringContainsString($officeB->name, $content);
        $this->assertStringContainsString('Office A report', $content);
        $this->assertStringContainsString('Office B report', $content);
    }

    public function test_tc_dept_3_super_admin_can_add_department(): void
    {
        $superAdmin = $this->makeUser('Super Admin', 'department-super@example.com', 'super_admin');
        Sanctum::actingAs($superAdmin);

        $this->postJson('/api/admin/offices', [
            'name' => 'City Environment Office',
            'code' => 'CEO',
            'description' => 'Environment reports',
            'is_active' => true,
        ])
            ->assertCreated()
            ->assertJsonPath('office.name', 'City Environment Office');
    }

    public function test_tc_dept_4_add_department_required_fields_fail(): void
    {
        $superAdmin = $this->makeUser('Super Admin', 'department-required@example.com', 'super_admin');
        Sanctum::actingAs($superAdmin);

        $this->postJson('/api/admin/offices', ['name' => ''])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('name');
    }

    public function test_tc_dept_duplicate_department_name_fails(): void
    {
        $superAdmin = $this->makeUser('Super Admin', 'department-duplicate@example.com', 'super_admin');
        Office::create(['name' => 'City Environment Office', 'is_active' => true]);
        Sanctum::actingAs($superAdmin);

        $this->postJson('/api/admin/offices', ['name' => 'City Environment Office'])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('name');
    }

    public function test_tc_mng_1_super_admin_can_view_admin_management_list(): void
    {
        $superAdmin = $this->makeUser('Super Admin', 'accounts-super@example.com', 'super_admin');
        $this->makeUser('Manage Admin', 'manage-admin@example.com', 'admin');

        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/admin/users')
            ->assertOk()
            ->assertJsonFragment(['email' => 'manage-admin@example.com']);
    }

    public function test_tc_mng_verify_pending_admin_account(): void
    {
        $superAdmin = $this->makeUser('Super Admin', 'verify-super@example.com', 'super_admin');
        $pendingAdmin = $this->makeUser('Pending Admin', 'pending-manage@example.com', 'pending_admin');

        Sanctum::actingAs($superAdmin);

        $this->postJson("/api/admin/verify-account/{$pendingAdmin->id}")
            ->assertOk()
            ->assertJsonPath('user.role', 'admin');
    }

    public function test_tc_mng_8_deactivate_staff_admin(): void
    {
        $superAdmin = $this->makeUser('Super Admin', 'deactivate-super@example.com', 'super_admin');
        $admin = $this->makeUser('Manage Admin', 'deactivate-admin@example.com', 'admin');

        Sanctum::actingAs($superAdmin);

        $this->postJson("/api/admin/deactivate-account/{$admin->id}")
            ->assertOk()
            ->assertJsonPath('user.is_active', false);
    }

    public function test_tc_mng_8_reactivate_staff_admin(): void
    {
        $superAdmin = $this->makeUser('Super Admin', 'reactivate-super@example.com', 'super_admin');
        $admin = $this->makeUser('Manage Admin', 'reactivate-admin@example.com', 'admin', [
            'is_active' => false,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->postJson("/api/admin/reactivate-account/{$admin->id}")
            ->assertOk()
            ->assertJsonPath('user.is_active', true);
    }

    public function test_tc_mng_9_archive_staff_admin_before_permanent_delete(): void
    {
        $superAdmin = $this->makeUser('Super Admin', 'delete-super@example.com', 'super_admin');
        $admin = $this->makeUser('Manage Admin', 'delete-admin@example.com', 'admin');

        Sanctum::actingAs($superAdmin);

        $this->deleteJson("/api/admin/delete-account/{$admin->id}")
            ->assertOk()
            ->assertJsonPath('message', 'Account archived successfully');

        $this->assertSoftDeleted('users', ['id' => $admin->id]);
        $this->assertDatabaseHas('users', [
            'id' => $admin->id,
            'is_active' => false,
        ]);
    }

    public function test_tc_mng_10_prevent_self_delete(): void
    {
        $superAdmin = $this->makeUser('Super Admin', 'self-delete-super@example.com', 'super_admin');
        Sanctum::actingAs($superAdmin);

        $this->deleteJson("/api/admin/delete-account/{$superAdmin->id}")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('user');
    }

    public function test_tc_fb_12_submit_feedback_successfully(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $report = Report::create(array_merge($this->validReportPayload($office, $category), [
            'user_id' => $citizen->id,
            'status' => 'Resolved',
        ]));

        Sanctum::actingAs($citizen);

        $this->postJson('/api/feedback', [
            'office_id' => $office->id,
            'report_id' => $report->id,
            'type' => 'Suggestion',
            'message' => 'Road needs repair',
            'rating' => 4,
        ])
            ->assertCreated()
            ->assertJsonPath('feedback.rating', 4);
    }

    public function test_tc_fb_invalid_rating_fails(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $report = Report::create(array_merge($this->validReportPayload($office, $category), [
            'user_id' => $citizen->id,
            'status' => 'Resolved',
        ]));

        Sanctum::actingAs($citizen);

        $this->postJson('/api/feedback', [
            'office_id' => $office->id,
            'report_id' => $report->id,
            'type' => 'Suggestion',
            'message' => 'Invalid rating',
            'rating' => 6,
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('rating');
    }

    public function test_tc_fb_13_view_previous_feedback(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $report = Report::create(array_merge($this->validReportPayload($office, $category), [
            'user_id' => $citizen->id,
            'status' => 'Resolved',
        ]));

        $this->createFeedback($citizen, $office, $report);

        Sanctum::actingAs($citizen);

        $this->getJson('/api/feedback?type=Suggestion')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonFragment(['message' => 'Road needs repair']);
    }

    public function test_tc_fb_department_head_can_view_only_own_department_feedback(): void
    {
        [$officeA, $officeB, $citizen, $reportA, $reportB] = $this->seedTwoDepartmentFeedbackEntries();
        $head = $this->makeUser('Roads Office Head', 'roads-head@example.com', 'admin', [
            'department' => $officeA->name,
            'job_title' => 'Office Head',
        ]);

        Sanctum::actingAs($head);

        $this->getJson('/api/feedback')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonFragment(['message' => 'Roads department feedback'])
            ->assertJsonMissing(['message' => 'Water department feedback']);
    }

    public function test_tc_fb_regular_department_staff_cannot_view_department_feedback(): void
    {
        [$officeA] = $this->seedTwoDepartmentFeedbackEntries();
        $staff = $this->makeUser('Roads Staff', 'roads-staff@example.com', 'admin', [
            'department' => $officeA->name,
            'job_title' => 'Field Engineer',
        ]);

        Sanctum::actingAs($staff);

        $this->getJson('/api/feedback')->assertForbidden();
    }

    public function test_tc_fb_super_admin_can_view_feedback_from_all_departments(): void
    {
        $this->seedTwoDepartmentFeedbackEntries();
        $superAdmin = $this->makeUser('Feedback Super Admin', 'feedback-all-super@example.com', 'super_admin');

        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/feedback')
            ->assertOk()
            ->assertJsonCount(2)
            ->assertJsonFragment(['message' => 'Roads department feedback'])
            ->assertJsonFragment(['message' => 'Water department feedback']);
    }

    public function test_tc_fb_department_head_exports_only_own_department_feedback(): void
    {
        [$officeA] = $this->seedTwoDepartmentFeedbackEntries();
        $head = $this->makeUser('Roads Export Head', 'roads-export-head@example.com', 'admin', [
            'department' => $officeA->name,
            'job_title' => 'Department Head',
        ]);

        Sanctum::actingAs($head);

        $export = $this->get('/api/feedback/export');
        $content = $export->streamedContent();

        $export->assertOk();
        $this->assertStringContainsString('Roads department feedback', $content);
        $this->assertStringNotContainsString('Water department feedback', $content);
    }

    public function test_tc_fb_feedback_report_must_match_selected_department(): void
    {
        [$officeA, $officeB, $citizen, $reportA] = $this->seedTwoDepartmentFeedbackEntries();

        Sanctum::actingAs($citizen);

        $this->postJson('/api/feedback', [
            'office_id' => $officeB->id,
            'report_id' => $reportA->id,
            'type' => 'Complaint',
            'message' => 'Wrong department feedback',
            'rating' => 2,
        ])->assertUnprocessable();
    }

    public function test_tc_fdbk_export_feedback_downloads_csv_with_table_data(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $report = Report::create(array_merge($this->validReportPayload($office, $category), [
            'user_id' => $citizen->id,
            'status' => 'Resolved',
        ]));
        $this->createFeedback($citizen, $office, $report);
        $superAdmin = $this->makeUser('Super Admin', 'feedback-super@example.com', 'super_admin');

        Sanctum::actingAs($superAdmin);

        $export = $this->get('/api/feedback/export');
        $content = $export->streamedContent();

        $export->assertOk();
        $this->assertStringContainsString('Feedback ID', $content);
        $this->assertStringContainsString('Road needs repair', $content);
    }

    public function test_tc_settings_super_admin_only(): void
    {
        $admin = $this->makeUser('Settings Admin', 'settings-admin@example.com', 'admin');
        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/settings')->assertForbidden();
    }

    public function test_tc_settings_show_default_settings(): void
    {
        $superAdmin = $this->makeUser('Settings Super', 'settings-super@example.com', 'super_admin');
        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/admin/settings')
            ->assertOk()
            ->assertJsonPath('settings.escalation_settings.trigger_time_hours', 72);
    }

    public function test_tc_settings_update_valid_payload(): void
    {
        $superAdmin = $this->makeUser('Settings Super', 'settings-update@example.com', 'super_admin');
        Sanctum::actingAs($superAdmin);

        $this->putJson('/api/admin/settings', $this->validSettingsPayload([
            'notifications' => ['feedback_notifications' => false],
        ]))
            ->assertOk()
            ->assertJsonPath('settings.notifications.feedback_notifications', false);
    }

    public function test_tc_settings_invalid_payload_fails(): void
    {
        $superAdmin = $this->makeUser('Settings Super', 'settings-invalid@example.com', 'super_admin');
        Sanctum::actingAs($superAdmin);

        $this->putJson('/api/admin/settings', $this->validSettingsPayload([
            'report_settings' => ['default_due_hours' => 0],
        ]))
            ->assertUnprocessable()
            ->assertJsonValidationErrors('report_settings.default_due_hours');
    }

    public function test_tc_esc_1_view_escalations_list(): void
    {
        [$report, $superAdmin] = $this->seedEscalatedReport();
        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/admin/escalations')
            ->assertOk()
            ->assertJsonFragment(['tracking_id' => 'CTR-' . str_pad((string) $report->id, 5, '0', STR_PAD_LEFT)]);
    }

    public function test_tc_esc_2_auto_escalation_after_72_hours(): void
    {
        [, $superAdmin] = $this->seedEscalatedReport();
        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/admin/escalations')
            ->assertOk()
            ->assertJsonPath('summary.open', 1);
    }

    public function test_tc_esc_non_super_admin_cannot_view_escalations(): void
    {
        $admin = $this->makeUser('Escalation Admin', 'escalation-admin@example.com', 'admin');
        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/escalations')->assertForbidden();
    }

    public function test_tc_esc_3_acknowledge_escalation_with_notes(): void
    {
        [$report, $superAdmin] = $this->seedEscalatedReport();
        Sanctum::actingAs($superAdmin);

        $this->postJson("/api/admin/escalations/{$report->id}", [
            'status' => 'Acknowledged',
            'notes' => 'Super admin reviewed the overdue report.',
        ])
            ->assertOk()
            ->assertJsonPath('escalation.status', 'Acknowledged');
    }

    public function test_tc_esc_4_intervene_escalation(): void
    {
        [$report, $superAdmin] = $this->seedEscalatedReport();
        Sanctum::actingAs($superAdmin);

        $this->postJson("/api/admin/escalations/{$report->id}", [
            'status' => 'Intervened',
        ])
            ->assertOk()
            ->assertJsonPath('escalation.status', 'Intervened');
    }

    public function test_tc_esc_resolved_report_cannot_be_escalated(): void
    {
        [$report, $superAdmin] = $this->seedEscalatedReport();
        $report->update(['status' => 'Resolved']);
        Sanctum::actingAs($superAdmin);

        $this->postJson("/api/admin/escalations/{$report->id}", [
            'status' => 'Dismissed',
        ])->assertUnprocessable();
    }

    public function test_tc_sec_01_guest_cannot_access_current_user_endpoint(): void
    {
        $this->getJson('/api/user')->assertUnauthorized();
    }

    public function test_tc_sec_02_guest_cannot_submit_report(): void
    {
        $office = Office::create(['name' => "City Engineer's Office", 'is_active' => true]);
        $category = Category::create(['name' => 'Road Repairs']);

        $this->postJson('/api/reports', $this->validReportPayload($office, $category))
            ->assertUnauthorized();
    }

    public function test_tc_sec_03_citizen_cannot_access_admin_reports(): void
    {
        $citizen = $this->makeUser('Citizen User', 'citizen-sec@example.com', 'citizen');
        Sanctum::actingAs($citizen);

        $this->getJson('/api/admin/reports')->assertForbidden();
    }

    public function test_tc_sec_04_citizen_cannot_access_admin_users(): void
    {
        $citizen = $this->makeUser('Citizen User', 'citizen-users@example.com', 'citizen');
        Sanctum::actingAs($citizen);

        $this->getJson('/api/admin/users')->assertForbidden();
    }

    public function test_tc_pr_11_update_profile_with_valid_inputs(): void
    {
        $citizen = $this->makeUser('Old Citizen', 'old-citizen@example.com', 'citizen');
        Sanctum::actingAs($citizen);

        $this->putJson('/api/user/profile', [
            'name' => 'Jannena Gayas',
            'email' => 'jannena.updated@example.com',
            'mobile_number' => '09123456789',
        ])
            ->assertOk()
            ->assertJsonPath('user.email', 'jannena.updated@example.com');

        $this->assertDatabaseHas('users', [
            'id' => $citizen->id,
            'email' => 'jannena.updated@example.com',
        ]);
    }

    public function test_tc_pr_invalid_profile_email_format_fails(): void
    {
        $citizen = $this->makeUser('Profile Citizen', 'profile-citizen@example.com', 'citizen');
        Sanctum::actingAs($citizen);

        $this->putJson('/api/user/profile', [
            'name' => 'Jannena Gayas',
            'email' => 'invalid-email',
            'mobile_number' => '09123456789',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_tc_pr_duplicate_profile_email_fails(): void
    {
        $citizen = $this->makeUser('Profile Citizen', 'profile-owner@example.com', 'citizen');
        $this->makeUser('Other User', 'taken-email@example.com', 'citizen');
        Sanctum::actingAs($citizen);

        $this->putJson('/api/user/profile', [
            'name' => 'Jannena Gayas',
            'email' => 'taken-email@example.com',
            'mobile_number' => '09123456789',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    public function test_tc_rpt_show_report_details_for_owner(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $report = Report::create(array_merge($this->validReportPayload($office, $category), [
            'user_id' => $citizen->id,
        ]));
        Sanctum::actingAs($citizen);

        $this->getJson("/api/reports/{$report->id}")
            ->assertOk()
            ->assertJsonPath('title', 'Broken road');
    }

    public function test_tc_rpt_citizen_cannot_view_other_citizen_report_details(): void
    {
        [$owner, $office, $category] = $this->seedCitizenReportDependencies();
        $viewer = $this->makeUser('Viewer Citizen', 'viewer@example.com', 'citizen');
        $report = Report::create(array_merge($this->validReportPayload($office, $category), [
            'user_id' => $owner->id,
        ]));
        Sanctum::actingAs($viewer);

        $this->getJson("/api/reports/{$report->id}")->assertForbidden();
    }

    public function test_tc_ad_admin_cannot_update_report_from_other_department(): void
    {
        [, $officeB] = $this->seedTwoOfficesWithReports();
        $admin = $this->makeUser('Roads Admin', 'roads-only@example.com', 'admin', [
            'department' => 'Roads Department',
        ]);
        $otherReport = Report::query()->where('office_id', $officeB->id)->firstOrFail();
        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/reports/{$otherReport->id}/status", [
            'status' => 'In Progress',
        ])->assertForbidden();
    }

    public function test_tc_ad_admin_reports_status_filter_returns_matching_reports(): void
    {
        [$officeA] = $this->seedTwoOfficesWithReports();
        $admin = $this->makeUser('Roads Admin', 'roads-filter@example.com', 'admin', [
            'department' => $officeA->name,
        ]);
        Sanctum::actingAs($admin);

        $this->getJson('/api/admin/reports?status=Pending')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonFragment(['status' => 'Pending']);
    }

    public function test_tc_sa_super_admin_can_filter_reports_by_status(): void
    {
        $this->seedTwoOfficesWithReports();
        $superAdmin = $this->makeUser('Super Admin', 'status-super@example.com', 'super_admin');
        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/admin/reports?status=Resolved')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonFragment(['status' => 'Resolved']);
    }

    public function test_tc_mng_admin_cannot_reactivate_accounts(): void
    {
        $admin = $this->makeUser('Regular Admin', 'regular-reactivate@example.com', 'admin');
        $citizen = $this->makeUser('Inactive Citizen', 'inactive-citizen@example.com', 'citizen', [
            'is_active' => false,
        ]);
        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/reactivate-account/{$citizen->id}")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('user');
    }

    public function test_tc_mng_admin_cannot_deactivate_citizen_account(): void
    {
        $admin = $this->makeUser('Regular Admin', 'regular-deactivate@example.com', 'admin');
        $citizen = $this->makeUser('Target Citizen', 'target-citizen@example.com', 'citizen');
        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/deactivate-account/{$citizen->id}")
            ->assertForbidden();
    }

    public function test_tc_mng_admin_cannot_deactivate_another_admin_account(): void
    {
        $admin = $this->makeUser('Regular Admin', 'regular-admin@example.com', 'admin');
        $targetAdmin = $this->makeUser('Target Admin', 'target-admin@example.com', 'admin');
        Sanctum::actingAs($admin);

        $this->postJson("/api/admin/deactivate-account/{$targetAdmin->id}")
            ->assertForbidden();
    }

    public function test_tc_mng_super_admin_account_cannot_be_deactivated(): void
    {
        $superAdmin = $this->makeUser('Super Admin', 'super-protected@example.com', 'super_admin');
        $otherSuperAdmin = $this->makeUser('Other Super', 'other-super@example.com', 'super_admin');
        Sanctum::actingAs($superAdmin);

        $this->postJson("/api/admin/deactivate-account/{$otherSuperAdmin->id}")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('user');
    }

    public function test_tc_fb_citizen_cannot_submit_feedback_for_other_users_report(): void
    {
        [$owner, $office, $category] = $this->seedCitizenReportDependencies();
        $otherCitizen = $this->makeUser('Other Citizen', 'feedback-other@example.com', 'citizen');
        $report = Report::create(array_merge($this->validReportPayload($office, $category), [
            'user_id' => $owner->id,
            'status' => 'Resolved',
        ]));
        Sanctum::actingAs($otherCitizen);

        $this->postJson('/api/feedback', [
            'office_id' => $office->id,
            'report_id' => $report->id,
            'type' => 'Suggestion',
            'message' => 'Not my report',
            'rating' => 4,
        ])->assertNotFound();
    }

    public function test_tc_fb_super_admin_feedback_type_filter_returns_matching_feedback(): void
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $report = Report::create(array_merge($this->validReportPayload($office, $category), [
            'user_id' => $citizen->id,
            'status' => 'Resolved',
        ]));
        $this->createFeedback($citizen, $office, $report);
        $superAdmin = $this->makeUser('Super Admin', 'feedback-filter-super@example.com', 'super_admin');
        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/feedback?type=Suggestion')
            ->assertOk()
            ->assertJsonCount(1)
            ->assertJsonFragment(['type' => 'Suggestion']);
    }

    public function test_tc_esc_filter_escalations_by_barangay(): void
    {
        [$report, $superAdmin] = $this->seedEscalatedReport();
        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/admin/escalations?barangay=Barangay%207')
            ->assertOk()
            ->assertJsonFragment(['report_id' => $report->id]);
    }

    public function test_tc_esc_filter_escalations_by_priority(): void
    {
        [$report, $superAdmin] = $this->seedEscalatedReport();
        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/admin/escalations?priority=High')
            ->assertOk()
            ->assertJsonFragment(['report_id' => $report->id]);
    }

    public function test_tc_esc_invalid_status_update_fails_validation(): void
    {
        [$report, $superAdmin] = $this->seedEscalatedReport();
        Sanctum::actingAs($superAdmin);

        $this->postJson("/api/admin/escalations/{$report->id}", [
            'status' => 'Invalid Status',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('status');
    }

    private function assertCitizenRegistrationFails(array $overrides, string $field): void
    {
        $this->postJson('/api/auth/register', array_merge(
            $this->validCitizenRegistrationPayload(),
            $overrides
        ))
            ->assertUnprocessable()
            ->assertJsonValidationErrors($field);
    }

    private function validCitizenRegistrationPayload(): array
    {
        return [
            'name' => 'Jannena Gayas',
            'email' => 'gjannena@example.com',
            'mobile_number' => '09123456789',
            'password' => 'Pass@123',
            'password_confirmation' => 'Pass@123',
        ];
    }

    private function seedCitizenReportDependencies(): array
    {
        return [
            $this->makeUser('Jannena Gayas', 'citizen@example.com', 'citizen'),
            Office::create(['name' => "City Engineer's Office", 'is_active' => true]),
            Category::create(['name' => 'Road Repairs']),
        ];
    }

    private function seedTwoOfficesWithReports(): array
    {
        $citizen = $this->makeUser('Report Citizen', 'report-citizen@example.com', 'citizen');
        $officeA = Office::create(['name' => 'Roads Department', 'is_active' => true]);
        $officeB = Office::create(['name' => 'Water Department', 'is_active' => true]);
        $category = Category::create(['name' => 'Streetlighting']);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $officeA->id,
            'category_id' => $category->id,
            'title' => 'Office A report',
            'description' => 'Road issue',
            'location' => 'Main Street',
            'barangay' => 'Barangay 7',
            'status' => 'Pending',
            'priority' => 'High',
        ]);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $officeB->id,
            'category_id' => $category->id,
            'title' => 'Office B report',
            'description' => 'Water issue',
            'location' => 'Side Street',
            'barangay' => 'Barangay 5',
            'status' => 'Resolved',
            'priority' => 'Normal',
            'resolved_at' => now(),
        ]);

        return [$officeA, $officeB, $category];
    }

    private function seedEscalatedReport(): array
    {
        [$citizen, $office, $category] = $this->seedCitizenReportDependencies();
        $superAdmin = $this->makeUser('Escalation Super', 'escalation-super@example.com', 'super_admin');
        $report = Report::create(array_merge($this->validReportPayload($office, $category), [
            'user_id' => $citizen->id,
            'status' => 'Pending',
            'priority' => 'High',
        ]));
        $report->forceFill([
            'created_at' => now()->subHours(73),
            'updated_at' => now()->subHours(73),
        ])->saveQuietly();

        return [$report, $superAdmin];
    }

    private function validReportPayload(Office $office, Category $category): array
    {
        return [
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Broken road',
            'description' => 'Road damage near the plaza',
            'location' => 'Main Street',
            'barangay' => 'Barangay 7',
            'priority' => 'High',
        ];
    }

    private function createFeedback(User $citizen, Office $office, Report $report): void
    {
        $report->feedbackEntries()->create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'type' => 'Suggestion',
            'message' => 'Road needs repair',
            'rating' => 4,
        ]);
    }

    private function seedTwoDepartmentFeedbackEntries(): array
    {
        $citizen = $this->makeUser('Feedback Citizen', 'department-feedback-citizen@example.com', 'citizen');
        $officeA = Office::create(['name' => 'Roads Department', 'is_active' => true]);
        $officeB = Office::create(['name' => 'Water Department', 'is_active' => true]);
        $category = Category::create(['name' => 'Department Feedback']);

        $reportA = Report::create(array_merge($this->validReportPayload($officeA, $category), [
            'user_id' => $citizen->id,
            'title' => 'Roads feedback report',
            'status' => 'Resolved',
        ]));

        $reportB = Report::create(array_merge($this->validReportPayload($officeB, $category), [
            'user_id' => $citizen->id,
            'title' => 'Water feedback report',
            'status' => 'Resolved',
        ]));

        $reportA->feedbackEntries()->create([
            'user_id' => $citizen->id,
            'office_id' => $officeA->id,
            'type' => 'Suggestion',
            'message' => 'Roads department feedback',
            'rating' => 5,
        ]);

        $reportB->feedbackEntries()->create([
            'user_id' => $citizen->id,
            'office_id' => $officeB->id,
            'type' => 'Complaint',
            'message' => 'Water department feedback',
            'rating' => 2,
        ]);

        return [$officeA, $officeB, $citizen, $reportA, $reportB];
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
