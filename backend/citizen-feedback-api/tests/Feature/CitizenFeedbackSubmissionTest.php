<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\CitizenFeedback;
use App\Models\Office;
use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class CitizenFeedbackSubmissionTest extends TestCase
{
    use RefreshDatabase;

    public function test_feedback_without_report_id_stays_linked_to_selected_department_without_guessing_a_report(): void
    {
        $citizen = User::create([
            'name' => 'Feedback Citizen',
            'email' => 'feedback-selected-office@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $office = Office::create([
            'name' => 'City Engineer Office',
            'is_active' => true,
        ]);

        $category = Category::create(['name' => 'Road Concern']);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Resolved report',
            'description' => 'Resolved report that should not be auto-linked.',
            'location' => 'Tacloban City',
            'barangay' => 'Barangay 1',
            'status' => 'Resolved',
            'priority' => 'Normal',
        ]);

        Sanctum::actingAs($citizen);

        $response = $this->postJson('/api/feedback', [
            'office_id' => $office->id,
            'type' => 'Suggestion',
            'message' => 'Selected department feedback only',
            'rating' => 4,
        ]);

        $response->assertCreated()
            ->assertJsonPath('feedback.office_id', $office->id)
            ->assertJsonPath('feedback.report_id', null);

        $this->assertDatabaseHas('citizen_feedback', [
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'report_id' => null,
            'message' => 'Selected department feedback only',
        ]);
    }

    public function test_duplicate_feedback_submission_returns_existing_record_without_creating_duplicate_rows(): void
    {
        $citizen = User::create([
            'name' => 'Feedback Citizen',
            'email' => 'feedback-duplicate@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $office = Office::create([
            'name' => 'City Health Office',
            'is_active' => true,
        ]);

        Sanctum::actingAs($citizen);

        $payload = [
            'office_id' => $office->id,
            'type' => 'Praise',
            'message' => 'Consistent service quality',
            'rating' => 5,
        ];

        $firstResponse = $this->postJson('/api/feedback', $payload);
        $secondResponse = $this->postJson('/api/feedback', $payload);

        $firstResponse->assertCreated()
            ->assertJsonPath('message', 'Feedback sent successfully.');

        $secondResponse->assertOk()
            ->assertJsonPath('message', 'This feedback was already submitted recently.')
            ->assertJsonPath(
                'feedback.id',
                $firstResponse->json('feedback.id')
            );

        $this->assertSame(1, CitizenFeedback::query()->count());
    }
}
