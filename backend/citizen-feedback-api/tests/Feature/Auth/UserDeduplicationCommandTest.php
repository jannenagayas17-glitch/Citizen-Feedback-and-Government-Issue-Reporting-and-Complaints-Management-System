<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class UserDeduplicationCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_users_dedupe_command_defaults_to_dry_run_and_does_not_modify_users(): void
    {
        $original = User::create([
            'name' => 'Original Citizen',
            'email' => 'duplicate.audit@example.com',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $legacyCopy = User::create([
            'name' => 'Legacy Copy',
            'email' => '  Duplicate.Audit@Example.com ',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => false,
        ]);

        $this->artisan('users:dedupe')
            ->expectsOutputToContain('User duplicate email cleanup: DRY-RUN')
            ->expectsOutputToContain('Duplicate normalized email groups found: 1')
            ->expectsOutputToContain('Email: duplicate.audit@example.com')
            ->expectsOutputToContain('Dry run only: no database rows were changed.')
            ->assertExitCode(0);

        $this->assertDatabaseHas('users', [
            'id' => $original->id,
            'deleted_at' => null,
        ]);

        $this->assertDatabaseHas('users', [
            'id' => $legacyCopy->id,
            'deleted_at' => null,
        ]);
    }
}
