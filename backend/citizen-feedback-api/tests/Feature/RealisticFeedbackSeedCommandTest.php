<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\CitizenFeedback;
use App\Models\Office;
use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class RealisticFeedbackSeedCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_feedback_seed_realistic_command_appends_real_feedback_rows_linked_to_existing_reports(): void
    {
        [$officeA, $officeB, $citizen] = $this->seedContext();
        $reports = collect([
            $this->makeReport($citizen, $officeA, 'Street light issue near barangay hall', Carbon::now()->subMonths(8)),
            $this->makeReport($citizen, $officeA, 'Drainage concern beside covered court', Carbon::now()->subMonths(7)),
            $this->makeReport($citizen, $officeB, 'Road repair follow-up at market road', Carbon::now()->subMonths(6)),
            $this->makeReport($citizen, $officeB, 'Illegal parking issue near school gate', Carbon::now()->subMonths(5)),
        ]);

        $existingFeedback = CitizenFeedback::create([
            'user_id' => $citizen->id,
            'office_id' => $officeA->id,
            'report_id' => $reports[0]->id,
            'type' => 'Suggestion',
            'message' => 'Existing feedback must remain intact.',
            'rating' => 4,
        ]);

        $beforeCount = CitizenFeedback::query()->count();

        $this->artisan('feedback:seed-realistic', [
            '--count' => 3,
            '--batch' => 2,
            '--force' => true,
        ])
            ->expectsOutputToContain('Realistic feedback seeding completed successfully.')
            ->expectsOutputToContain('Feedback created: 3')
            ->assertExitCode(0);

        $this->assertSame($beforeCount + 3, CitizenFeedback::query()->count());
        $this->assertDatabaseHas('citizen_feedback', [
            'id' => $existingFeedback->id,
            'message' => 'Existing feedback must remain intact.',
        ]);

        $seededFeedback = CitizenFeedback::query()
            ->where('id', '!=', $existingFeedback->id)
            ->orderBy('id')
            ->get();

        $this->assertCount(3, $seededFeedback);
        $this->assertSame(
            3,
            $seededFeedback->pluck('report_id')->filter()->unique()->count(),
            'Each seeded feedback row should link to a distinct real report.',
        );

        foreach ($seededFeedback as $feedback) {
            $this->assertSame($citizen->id, $feedback->user_id);
            $this->assertContains($feedback->type, ['Suggestion', 'Complaint', 'Praise']);
            $this->assertGreaterThanOrEqual(1, $feedback->rating);
            $this->assertLessThanOrEqual(5, $feedback->rating);
            $this->assertNotEmpty(trim((string) $feedback->message));
            $this->assertStringNotContainsString('test feedback', strtolower($feedback->message));
            $this->assertNotNull($feedback->report_id);
            $this->assertNotNull($feedback->office_id);
        }
    }

    public function test_feedback_seed_realistic_command_stops_when_not_enough_eligible_reports_exist(): void
    {
        [$office, , $citizen] = $this->seedContext();
        $report = $this->makeReport(
            $citizen,
            $office,
            'Resolved drainage issue near barangay road',
            Carbon::now()->subMonths(7),
        );

        CitizenFeedback::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'report_id' => $report->id,
            'type' => 'Praise',
            'message' => 'Already covered by an existing feedback entry.',
            'rating' => 5,
        ]);

        $beforeCount = CitizenFeedback::query()->count();

        $this->artisan('feedback:seed-realistic', [
            '--count' => 1,
            '--force' => true,
        ])
            ->expectsOutputToContain('Only 0 eligible real reports without linked feedback are available.')
            ->assertExitCode(1);

        $this->assertSame($beforeCount, CitizenFeedback::query()->count());
    }

    private function seedContext(): array
    {
        $citizen = User::create([
            'name' => 'Feedback Seeder Citizen',
            'email' => 'feedback-seeder-citizen@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $officeA = Office::create([
            'name' => "City Engineer's Office",
            'is_active' => true,
        ]);

        $officeB = Office::create([
            'name' => 'TOMECO (Traffic Operation)',
            'is_active' => true,
        ]);

        Category::create(['name' => 'Infrastructure']);

        return [$officeA, $officeB, $citizen];
    }

    private function makeReport(
        User $citizen,
        Office $office,
        string $title,
        Carbon $createdAt,
    ): Report {
        $category = Category::query()->firstOrFail();

        $report = new Report([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => $title,
            'description' => 'A realistic report description.',
            'location' => 'Tacloban City',
            'barangay' => 'Barangay 12',
            'status' => 'Resolved',
            'priority' => 'Normal',
            'source' => 'citizen_app',
            'resolved_at' => $createdAt->copy()->addWeek(),
        ]);
        $report->created_at = $createdAt;
        $report->updated_at = $createdAt->copy()->addWeek();
        $report->save();

        return $report;
    }
}
