<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\StatusHistory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class RealisticComplaintSeedCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_realistic_complaint_seed_command_can_append_reports_safely(): void
    {
        $this->seedPrerequisites();

        $this->artisan('complaints:seed-realistic --count=12 --batch=4 --force')
            ->expectsOutputToContain('Realistic complaint seeding completed successfully.')
            ->expectsOutputToContain('Reports created: 12')
            ->assertExitCode(0);

        $this->assertSame(12, Report::query()->count());
        $this->assertGreaterThan(0, StatusHistory::query()->count());

        $this->assertSame(
            12,
            Report::query()
                ->where('source', 'citizen_app')
                ->whereIn('status', ['New', 'Pending', 'In Progress', 'Resolved', 'Rejected'])
                ->count()
        );

        $this->assertSame(
            12,
            Report::query()
                ->whereNotNull('office_id')
                ->whereNotNull('category_id')
                ->whereNotNull('user_id')
                ->count()
        );

        $this->assertSame(
            0,
            Report::query()
                ->whereRaw('LENGTH(description) > 100')
                ->count()
        );
    }

    public function test_realistic_complaint_seed_command_does_not_insert_rows_when_cancelled(): void
    {
        $this->seedPrerequisites();

        $this->artisan('complaints:seed-realistic --count=5')
            ->expectsConfirmation(
                'Continue and insert realistic complaint records into the current database?',
                'no'
            )
            ->expectsOutputToContain('Cancelled. No database rows were changed.')
            ->assertExitCode(1);

        $this->assertSame(0, Report::query()->count());
    }

    public function test_realistic_complaint_seed_command_stops_when_no_real_citizens_exist(): void
    {
        Office::create([
            'name' => "City Engineer's Office",
            'code' => 'CEO',
            'is_active' => true,
        ]);

        Category::create([
            'name' => 'Road Damage',
        ]);

        $this->artisan('complaints:seed-realistic --count=3 --force')
            ->expectsOutputToContain('No active real citizen accounts are available.')
            ->assertExitCode(1);

        $this->assertSame(0, Report::query()->count());
    }

    private function seedPrerequisites(): void
    {
        Office::create([
            'name' => "City Engineer's Office",
            'code' => 'CEO',
            'is_active' => true,
        ]);

        Office::create([
            'name' => 'City Health Office',
            'code' => 'CHO',
            'is_active' => true,
        ]);

        Category::create(['name' => 'Road Damage']);
        Category::create(['name' => 'Sanitation']);
        Category::create(['name' => 'Illegal Parking']);

        User::create([
            'name' => 'Real Citizen One',
            'email' => 'real.citizen.one@example.com',
            'mobile_number' => '09171234567',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        User::create([
            'name' => 'Real Citizen Two',
            'email' => 'real.citizen.two@example.com',
            'mobile_number' => '09181234567',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        User::create([
            'name' => 'Engineer Admin',
            'email' => 'engineer.admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'admin',
            'department' => "City Engineer's Office",
            'job_title' => 'Office Head',
            'is_active' => true,
        ]);

        User::create([
            'name' => 'System Super Admin',
            'email' => 'system.super.admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);
    }
}
