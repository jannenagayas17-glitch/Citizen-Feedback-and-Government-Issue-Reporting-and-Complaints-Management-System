<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class GoogleLoginTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'services.firebase.api_key' => 'firebase-api-key-for-tests',
            'services.firebase.verify_ssl' => false,
        ]);
    }

    public function test_citizen_google_login_requires_a_registered_citizen_account(): void
    {
        $this->fakeGoogleLookup('citizen-google@example.com', [
            'displayName' => 'Citizen Google',
            'localId' => 'firebase-citizen-uid',
        ]);

        $this->postJson('/api/auth/google-login', [
            'id_token' => 'google-token',
            'role_hint' => 'citizen',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');

        $this->assertDatabaseMissing('users', [
            'email' => 'citizen-google@example.com',
        ]);
    }

    public function test_citizen_google_login_returns_an_existing_citizen_account(): void
    {
        $citizen = User::create([
            'name' => 'Citizen Google',
            'email' => 'citizen-google@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $this->fakeGoogleLookup('citizen-google@example.com', [
            'displayName' => 'Citizen Google',
            'localId' => 'firebase-citizen-uid',
        ]);

        $this->postJson('/api/auth/google-login', [
            'id_token' => 'google-token',
            'role_hint' => 'citizen',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', $citizen->id)
            ->assertJsonPath('user.role', 'citizen');

        $citizen->refresh();

        $this->assertSame('firebase-citizen-uid', $citizen->firebase_uid);
        $this->assertDatabaseCount('users', 1);
    }

    public function test_admin_google_login_returns_the_existing_admin_account(): void
    {
        $admin = User::create([
            'name' => 'Portal Admin',
            'email' => 'portal-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'admin',
            'department' => 'Roads Department',
            'is_active' => true,
        ]);

        $this->fakeGoogleLookup('portal-admin@example.com', [
            'displayName' => 'Portal Admin',
            'localId' => 'firebase-admin-uid',
        ]);

        $this->postJson('/api/auth/google-login', [
            'id_token' => 'google-token',
            'role_hint' => 'admin',
        ])
            ->assertOk()
            ->assertJsonPath('user.id', $admin->id)
            ->assertJsonPath('user.role', 'admin');

        $admin->refresh();

        $this->assertSame('firebase-admin-uid', $admin->firebase_uid);
        $this->assertDatabaseCount('users', 1);
    }

    public function test_admin_google_login_requires_an_existing_admin_account(): void
    {
        $this->fakeGoogleLookup('missing-admin@example.com', [
            'displayName' => 'Missing Admin',
            'localId' => 'firebase-missing-admin-uid',
        ]);

        $this->postJson('/api/auth/google-login', [
            'id_token' => 'google-token',
            'role_hint' => 'admin',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');

        $this->assertDatabaseMissing('users', [
            'email' => 'missing-admin@example.com',
        ]);
    }

    public function test_super_admin_google_login_is_rejected_for_the_staff_google_flow(): void
    {
        User::create([
            'name' => 'Super Admin',
            'email' => 'super-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $this->fakeGoogleLookup('super-admin@example.com', [
            'displayName' => 'Super Admin',
            'localId' => 'firebase-super-admin-uid',
        ]);

        $this->postJson('/api/auth/google-login', [
            'id_token' => 'google-token',
            'role_hint' => 'admin',
        ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors('email');
    }

    private function fakeGoogleLookup(string $email, array $overrides = []): void
    {
        Http::fake([
            'https://identitytoolkit.googleapis.com/*' => Http::response([
                'users' => [
                    array_merge([
                        'email' => $email,
                        'displayName' => 'Firebase User',
                        'localId' => 'firebase-local-id',
                        'emailVerified' => true,
                        'providerUserInfo' => [
                            ['providerId' => 'google.com'],
                        ],
                    ], $overrides),
                ],
            ], 200),
        ]);
    }
}
