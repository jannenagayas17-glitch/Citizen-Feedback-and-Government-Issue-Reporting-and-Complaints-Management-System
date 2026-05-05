<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ChangePasswordTest extends TestCase
{
    use RefreshDatabase;

    public function test_super_admin_can_change_password_with_the_correct_current_password(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin-password@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->putJson('/api/user/password', [
            'current_password' => 'password123',
            'new_password' => 'newpassword123',
            'new_password_confirmation' => 'newpassword123',
        ])
            ->assertOk()
            ->assertJsonPath('message', 'Password changed successfully');

        $superAdmin->refresh();

        $this->assertTrue(Hash::check('newpassword123', $superAdmin->password));
        $this->assertFalse(Hash::check('password123', $superAdmin->password));
    }

    public function test_password_change_fails_when_the_current_password_is_incorrect(): void
    {
        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin-password-fail@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        Sanctum::actingAs($superAdmin);

        $this->putJson('/api/user/password', [
            'current_password' => 'wrong-password',
            'new_password' => 'newpassword123',
            'new_password_confirmation' => 'newpassword123',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('current_password');

        $superAdmin->refresh();

        $this->assertTrue(Hash::check('password123', $superAdmin->password));
    }
}
