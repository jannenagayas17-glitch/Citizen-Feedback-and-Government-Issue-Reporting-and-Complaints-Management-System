<?php

namespace Tests\Feature\Auth;

use App\Models\Office;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AdminAccountManagementTest extends TestCase
{
    use RefreshDatabase;

    public function test_super_admin_can_verify_pending_admin_account(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $pendingAdmin = User::create([
            'name' => 'Pending Admin',
            'email' => 'pending@test.com',
            'password' => 'password123',
            'role' => 'pending_admin',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $response = $this->postJson("/api/admin/verify-account/{$pendingAdmin->id}");

        $response
            ->assertOk()
            ->assertJsonPath('user.role', 'admin');

        $this->assertDatabaseHas('users', [
            'id' => $pendingAdmin->id,
            'role' => 'admin',
            'is_active' => true,
        ]);
    }

    public function test_super_admin_can_reactivate_deactivated_admin_account(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $admin = User::create([
            'name' => 'Office Admin',
            'email' => 'admin@test.com',
            'password' => 'password123',
            'role' => 'admin',
            'is_active' => false,
        ]);

        Sanctum::actingAs($superAdmin);

        $response = $this->postJson("/api/admin/reactivate-account/{$admin->id}");

        $response
            ->assertOk()
            ->assertJsonPath('user.is_active', true);

        $this->assertDatabaseHas('users', [
            'id' => $admin->id,
            'is_active' => true,
        ]);
    }

    public function test_super_admin_archives_account_before_permanent_delete(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $admin = User::create([
            'name' => 'Old Admin',
            'email' => 'oldadmin@test.com',
            'password' => 'password123',
            'role' => 'admin',
            'is_active' => false,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->deleteJson("/api/admin/delete-account/{$admin->id}")
            ->assertOk()
            ->assertJsonPath('message', 'Account archived successfully');

        $this->assertSoftDeleted('users', [
            'id' => $admin->id,
        ]);

        $this->assertDatabaseHas('users', [
            'id' => $admin->id,
            'is_active' => false,
        ]);
    }

    public function test_super_admin_user_list_includes_citizen_accounts(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $citizen = User::create([
            'name' => 'Citizen User',
            'email' => 'citizen@test.com',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $response = $this->getJson('/api/admin/users');

        $response
            ->assertOk()
            ->assertJsonFragment([
                'id' => $citizen->id,
                'role' => 'citizen',
            ]);
    }

    public function test_super_admin_user_list_excludes_demo_seeded_accounts_even_when_archived(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $realCitizen = User::create([
            'name' => 'Real Citizen',
            'email' => 'real-citizen@test.com',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $demoCitizen = User::create([
            'name' => 'Demo Citizen',
            'email' => 'demo.citizen.0042@example.com',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $demoAdmin = User::create([
            'name' => 'Demo Admin',
            'email' => 'demo.admin.007@citytrack.test',
            'password' => 'password123',
            'role' => 'admin',
            'department' => 'Environment Office',
            'job_title' => 'Demo Admin',
            'is_active' => false,
        ]);
        $demoAdmin->delete();

        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/admin/users')
            ->assertOk()
            ->assertJsonFragment([
                'id' => $realCitizen->id,
                'email' => $realCitizen->email,
            ])
            ->assertJsonMissing([
                'id' => $demoCitizen->id,
                'email' => $demoCitizen->email,
            ])
            ->assertJsonMissing([
                'id' => $demoAdmin->id,
                'email' => $demoAdmin->email,
            ]);
    }

    public function test_super_admin_can_create_citizen_account_from_account_management(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'create-citizen-super@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->postJson('/api/admin/users', [
            'name' => 'New Citizen Account',
            'email' => 'new-citizen-account@test.com',
            'mobile_number' => '09171234567',
            'password' => 'citizen123',
            'password_confirmation' => 'citizen123',
            'role' => 'citizen',
        ])
            ->assertCreated()
            ->assertJsonPath('user.role', 'citizen')
            ->assertJsonPath('user.is_active', true);

        $citizen = User::query()
            ->where('email', 'new-citizen-account@test.com')
            ->firstOrFail();

        $this->assertNull($citizen->department);
        $this->assertNull($citizen->job_title);
        $this->assertTrue(Hash::check('citizen123', $citizen->password));
    }

    public function test_super_admin_can_create_administrative_staff_account_from_account_management(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'create-front-desk-super@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        Office::create([
            'name' => 'City Public Assistance Office',
            'description' => 'Public assistance services',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->postJson('/api/admin/users', [
            'name' => 'Administrative Staff Officer',
            'email' => 'administrative-staff-officer@test.com',
            'mobile_number' => '09175551234',
            'password' => 'frontdesk123',
            'password_confirmation' => 'frontdesk123',
            'role' => 'administrative_staff',
            'department' => 'City Public Assistance Office',
            'job_title' => 'Administrative Staff',
        ])
            ->assertCreated()
            ->assertJsonPath('user.role', 'administrative_staff')
            ->assertJsonPath('user.department', 'City Public Assistance Office')
            ->assertJsonPath('user.job_title', 'Administrative Staff')
            ->assertJsonPath('user.is_active', true);

        $frontDesk = User::query()
            ->where('email', 'administrative-staff-officer@test.com')
            ->firstOrFail();

        $this->assertSame('administrative_staff', $frontDesk->role);
        $this->assertSame('City Public Assistance Office', $frontDesk->department);
        $this->assertSame('Administrative Staff', $frontDesk->job_title);
        $this->assertTrue(Hash::check('frontdesk123', $frontDesk->password));
    }

    public function test_super_admin_account_creation_rejects_invalid_mobile_prefixes(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'invalid-mobile-super@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->postJson('/api/admin/users', [
            'name' => 'Ana De Leon',
            'email' => 'ana.deleon@test.com',
            'mobile_number' => '0231231233',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'citizen',
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('mobile_number')
            ->assertJsonPath(
                'errors.mobile_number.0',
                'Enter a valid Philippine mobile number. Use 09123456789 or +639123456789.'
            );
    }

    public function test_super_admin_account_creation_rejects_name_parts_longer_than_twenty_five_characters(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'long-name-super@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        Office::create([
            'name' => 'City Engineering Office',
            'description' => 'Office description',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->postJson('/api/admin/users', [
            'name' => str_repeat('A', 26).' Dela Cruz',
            'email' => 'long-name-admin@test.com',
            'mobile_number' => '09171234567',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'pending_admin',
            'department' => 'City Engineering Office',
            'job_title' => 'Office Head',
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('first_name')
            ->assertJsonPath(
                'errors.first_name.0',
                'First name must be 25 characters or fewer.'
            );
    }

    public function test_super_admin_cannot_create_duplicate_account_with_normalized_email(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'normalized-super-admin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        User::create([
            'name' => 'Existing Citizen',
            'email' => 'Citizen.Duplicate@Test.com',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->postJson('/api/admin/users', [
            'name' => 'Duplicate Citizen',
            'email' => '  citizen.duplicate@test.com ',
            'mobile_number' => '09174561234',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'citizen',
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('email')
            ->assertJsonPath('errors.email.0', 'This email is already registered.');
    }

    public function test_super_admin_cannot_create_duplicate_account_with_existing_mobile_number(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'mobile-super-admin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        User::create([
            'name' => 'Existing Admin',
            'email' => 'existing-admin@test.com',
            'mobile_number' => '09170000003',
            'password' => 'password123',
            'role' => 'admin',
            'department' => 'City Engineering Office',
            'job_title' => 'Office Head',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->postJson('/api/admin/users', [
            'name' => 'New Citizen Account',
            'email' => 'new-mobile-clash@test.com',
            'mobile_number' => '09170000003',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'role' => 'citizen',
        ])
            ->assertStatus(422)
            ->assertJsonValidationErrors('mobile_number')
            ->assertJsonPath(
                'errors.mobile_number.0',
                'This mobile number is already registered.'
            );
    }

    public function test_super_admin_user_list_includes_archived_accounts_until_permanent_delete(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $archivedCitizen = User::create([
            'name' => 'Archived Citizen',
            'email' => 'archived-citizen@test.com',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => false,
        ]);
        $archivedCitizen->delete();

        Sanctum::actingAs($superAdmin);

        $this->getJson('/api/admin/users')
            ->assertOk()
            ->assertJsonFragment([
                'id' => $archivedCitizen->id,
                'role' => 'citizen',
            ]);
    }

    public function test_super_admin_can_restore_archived_account(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $archivedAdmin = User::create([
            'name' => 'Archived Admin',
            'email' => 'archived-admin@test.com',
            'password' => 'password123',
            'role' => 'admin',
            'is_active' => false,
        ]);
        $archivedAdmin->delete();

        Sanctum::actingAs($superAdmin);

        $this->postJson("/api/admin/reactivate-account/{$archivedAdmin->id}")
            ->assertOk()
            ->assertJsonPath('user.is_active', true);

        $this->assertDatabaseHas('users', [
            'id' => $archivedAdmin->id,
            'deleted_at' => null,
            'is_active' => true,
        ]);
    }

    public function test_super_admin_can_permanently_delete_archived_account(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $archivedAdmin = User::create([
            'name' => 'Archived Admin',
            'email' => 'force-delete-admin@test.com',
            'password' => 'password123',
            'role' => 'admin',
            'is_active' => false,
        ]);
        $archivedAdmin->delete();

        Sanctum::actingAs($superAdmin);

        $this->deleteJson("/api/admin/delete-account/{$archivedAdmin->id}")
            ->assertOk()
            ->assertJsonPath('message', 'Account permanently deleted successfully');

        $this->assertDatabaseMissing('users', [
            'id' => $archivedAdmin->id,
        ]);
    }

    public function test_super_admin_account_cannot_be_deactivated_or_deleted(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $otherSuperAdmin = User::create([
            'name' => 'Protected Super Admin',
            'email' => 'protected-superadmin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->postJson("/api/admin/deactivate-account/{$otherSuperAdmin->id}")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('user');

        $this->deleteJson("/api/admin/delete-account/{$otherSuperAdmin->id}")
            ->assertUnprocessable()
            ->assertJsonValidationErrors('user');

        $this->assertDatabaseHas('users', [
            'id' => $otherSuperAdmin->id,
            'role' => 'super_admin',
            'is_active' => true,
        ]);
    }

    public function test_super_admin_user_list_collapses_duplicate_normalized_emails(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'dedupe-super-admin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        User::create([
            'name' => 'Legacy Citizen Copy',
            'email' => '  Duplicate.Citizen@Test.com ',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => false,
        ]);

        $activeCitizen = User::create([
            'name' => 'Active Citizen',
            'email' => 'duplicate.citizen@test.com',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $response = $this->getJson('/api/admin/users');

        $response->assertOk();

        $matchingUsers = collect($response->json())
            ->filter(fn (array $user) => strtolower(trim((string) ($user['email'] ?? ''))) === 'duplicate.citizen@test.com')
            ->values();

        $this->assertCount(1, $matchingUsers);
        $this->assertSame($activeCitizen->id, $matchingUsers->first()['id']);
    }

    public function test_protected_super_admin_profile_cannot_be_edited_from_portal(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin@test.com',
            'password' => 'password123',
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->putJson('/api/user/profile', [
            'name' => 'Edited Super Admin',
            'email' => 'edited-superadmin@test.com',
            'mobile_number' => '09170000003',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('user');

        $this->assertDatabaseHas('users', [
            'id' => $superAdmin->id,
            'name' => 'Super Admin',
            'email' => 'superadmin@test.com',
        ]);
    }
}
