<?php

namespace Tests\Feature\Auth;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DemoAccountCleanupCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_demo_account_cleanup_defaults_to_dry_run_and_does_not_modify_accounts(): void
    {
        $demoCitizen = User::create([
            'name' => 'Demo Citizen',
            'email' => 'demo.citizen.0001@example.com',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $demoAdmin = User::create([
            'name' => 'Demo Admin',
            'email' => 'demo.admin.001@citytrack.test',
            'password' => 'password123',
            'role' => 'admin',
            'department' => 'Environment Office',
            'job_title' => 'Demo Admin',
            'is_active' => true,
        ]);

        $realCitizen = User::create([
            'name' => 'Real Citizen',
            'email' => 'real.citizen@example.com',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $this->artisan('users:cleanup-demo')
            ->expectsOutputToContain('Demo account cleanup: DRY-RUN')
            ->expectsOutputToContain('Matched demo accounts: 2')
            ->expectsOutputToContain('Dry run only: no database rows were changed.')
            ->assertExitCode(0);

        $this->assertDatabaseHas('users', [
            'id' => $demoCitizen->id,
            'deleted_at' => null,
            'is_active' => true,
        ]);

        $this->assertDatabaseHas('users', [
            'id' => $demoAdmin->id,
            'deleted_at' => null,
            'is_active' => true,
        ]);

        $this->assertDatabaseHas('users', [
            'id' => $realCitizen->id,
            'deleted_at' => null,
            'is_active' => true,
        ]);
    }

    public function test_demo_account_cleanup_archives_only_known_demo_accounts_when_apply_is_used(): void
    {
        $demoCitizen = User::create([
            'name' => 'Demo Citizen',
            'email' => 'demo.citizen.0002@example.com',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $demoAdmin = User::create([
            'name' => 'Demo Admin',
            'email' => 'demo.admin.002@citytrack.test',
            'password' => 'password123',
            'role' => 'admin',
            'department' => 'Environment Office',
            'job_title' => 'Demo Admin',
            'is_active' => true,
        ]);

        $realCitizen = User::create([
            'name' => 'Real Citizen',
            'email' => 'real.person@example.com',
            'password' => 'password123',
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $this->artisan('users:cleanup-demo --apply')
            ->expectsOutputToContain('Demo account cleanup: APPLY')
            ->expectsOutputToContain('Archived demo accounts: 2')
            ->expectsOutputToContain('Deactivated demo accounts: 2')
            ->assertExitCode(0);

        $this->assertSoftDeleted('users', [
            'id' => $demoCitizen->id,
        ]);

        $this->assertSoftDeleted('users', [
            'id' => $demoAdmin->id,
        ]);

        $this->assertDatabaseHas('users', [
            'id' => $demoCitizen->id,
            'is_active' => false,
        ]);

        $this->assertDatabaseHas('users', [
            'id' => $demoAdmin->id,
            'is_active' => false,
        ]);

        $this->assertDatabaseHas('users', [
            'id' => $realCitizen->id,
            'deleted_at' => null,
            'is_active' => true,
        ]);
    }
}
