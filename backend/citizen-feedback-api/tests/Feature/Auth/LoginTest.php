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
}