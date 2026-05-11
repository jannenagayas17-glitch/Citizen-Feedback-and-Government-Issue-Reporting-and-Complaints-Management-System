<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class LoginTest extends TestCase
{
    use RefreshDatabase;

    public function test_user_can_login_with_valid_credentials(): void
    {
        $user = User::create([
            'name' => 'Padi User',
            'email' => 'padi@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
        ]);

        $response = $this->postJson('/api/auth/login', [
            'email' => 'padi@example.com',
            'password' => 'password123',
        ]);

        $response
            ->assertStatus(200)
            ->assertJsonStructure([
                'message',
                'user',
                'token',
            ]);
    }

    public function test_user_cannot_login_with_wrong_password(): void
    {
        User::create([
            'name' => 'Padi User',
            'email' => 'padi@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
        ]);

        $response = $this->postJson('/api/auth/login', [
            'email' => 'padi@example.com',
            'password' => 'wrongpassword',
        ]);

        $response->assertStatus(422);
    }

    public function test_pending_admin_cannot_login_until_verified(): void
    {
        User::create([
            'name' => 'Pending Admin',
            'email' => 'pending@example.com',
            'password' => Hash::make('password123'),
            'role' => 'pending_admin',
            'is_active' => true,
        ]);

        $response = $this->postJson('/api/auth/login', [
            'email' => 'pending@example.com',
            'password' => 'password123',
        ]);

        $response
            ->assertStatus(422)
            ->assertJsonValidationErrors('email');
    }

    public function test_deactivated_user_cannot_login(): void
    {
        User::create([
            'name' => 'Disabled Citizen',
            'email' => 'disabled@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => false,
        ]);

        $response = $this->postJson('/api/auth/login', [
            'email' => 'disabled@example.com',
            'password' => 'password123',
        ]);

        $response
            ->assertStatus(422)
            ->assertJsonValidationErrors('email');
    }

    public function test_user_can_login_when_legacy_email_in_database_has_spaces_and_mixed_case(): void
    {
        User::create([
            'name' => 'Legacy Citizen',
            'email' => '  Legacy.Citizen@Example.com ',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $this->postJson('/api/auth/login', [
            'email' => 'legacy.citizen@example.com',
            'password' => 'password123',
        ])
            ->assertOk()
            ->assertJsonPath('user.role', 'citizen');
    }
}
