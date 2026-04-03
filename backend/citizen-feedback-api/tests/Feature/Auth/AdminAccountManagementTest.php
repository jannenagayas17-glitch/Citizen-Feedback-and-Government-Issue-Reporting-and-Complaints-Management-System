<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
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

    public function test_super_admin_can_delete_unused_admin_account(): void
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

        $response = $this->deleteJson("/api/admin/delete-account/{$admin->id}");

        $response->assertOk();

        $this->assertDatabaseMissing('users', [
            'id' => $admin->id,
        ]);
    }
}
