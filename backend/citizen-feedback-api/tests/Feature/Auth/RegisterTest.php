<?php

namespace Tests\Feature\Auth;

use App\Models\Office;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class RegisterTest extends TestCase
{
    use RefreshDatabase;

    public function test_citizen_can_register(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'name' => 'Juan Dela Cruz',
            'email' => 'juan@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response
            ->assertStatus(201)
            ->assertJsonStructure([
                'message',
                'user',
                'token',
            ]);

        $this->assertDatabaseHas('users', [
            'email' => 'juan@example.com',
            'role' => 'citizen',
        ]);
    }

    public function test_citizen_registration_validates_bad_full_name(): void
    {
        $response = $this->postJson('/api/auth/register', [
            'name' => 'Juan',
            'email' => 'juan@example.com',
            'password' => 'password123',
            'password_confirmation' => 'password123',
        ]);

        $response
            ->assertStatus(422)
            ->assertJsonValidationErrors('name');
    }

    public function test_admin_request_creates_pending_admin_account(): void
    {
        Office::create([
            'name' => "City Engineer's Office",
            'description' => 'Office description',
            'is_active' => true,
        ]);

        $response = $this->postJson('/api/auth/request-government-account', [
            'name' => 'Jericson Cupan',
            'email' => 'jericson@example.com',
            'mobile_number' => '09170000001',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'department' => "City Engineer's Office",
            'job_title' => 'Office Head',
        ]);

        $response
            ->assertStatus(201)
            ->assertJsonPath('user.role', 'pending_admin');

        $this->assertDatabaseHas('users', [
            'email' => 'jericson@example.com',
            'role' => 'pending_admin',
            'department' => "City Engineer's Office",
            'job_title' => 'Office Head',
        ]);
    }

    public function test_admin_request_rejects_inactive_office(): void
    {
        Office::create([
            'name' => 'Old Office',
            'description' => 'Inactive office',
            'is_active' => false,
        ]);

        $response = $this->postJson('/api/auth/request-government-account', [
            'name' => 'Jericson Cupan',
            'email' => 'jericson@example.com',
            'mobile_number' => '09170000001',
            'password' => 'password123',
            'password_confirmation' => 'password123',
            'department' => 'Old Office',
            'job_title' => 'Office Head',
        ]);

        $response
            ->assertStatus(422)
            ->assertJsonValidationErrors('department');
    }
}
