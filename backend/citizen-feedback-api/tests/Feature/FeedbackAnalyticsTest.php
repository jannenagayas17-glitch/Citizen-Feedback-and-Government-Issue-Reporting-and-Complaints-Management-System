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
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class FeedbackAnalyticsTest extends TestCase
{
    use RefreshDatabase;

    public function test_super_admin_feedback_summary_charts_and_pagination_use_real_scoped_data(): void
    {
        [$superAdmin, $officeA, $officeB, $feedbackA, $feedbackB] = $this->seedFeedbackScenario();

        Sanctum::actingAs($superAdmin);

        $summary = $this->getJson('/api/feedback/summary');
        $charts = $this->getJson('/api/feedback/charts');
        $listing = $this->getJson('/api/feedback?paginate=true&per_page=2&page=1&search=follow-up');

        $summary->assertOk()
            ->assertJsonPath('total_feedback', 4)
            ->assertJsonPath('types.Suggestion', 2)
            ->assertJsonPath('types.Complaint', 1)
            ->assertJsonPath('types.Praise', 1);

        $charts->assertOk()
            ->assertJsonPath('rating_breakdown.0.rating', 1)
            ->assertJsonPath('rating_breakdown.4.rating', 5)
            ->assertJsonPath('type_breakdown.0.label', 'Suggestion');

        $officeRows = collect($charts->json('office_breakdown'));
        $this->assertTrue(
            $officeRows->contains(
                fn (array $row) => $row['label'] === $officeA->name && $row['count'] === 3
            ),
            'Roads Department should appear in the office feedback breakdown.'
        );

        $trendCounts = collect($charts->json('trend_breakdown'))->pluck('count');
        $this->assertTrue($trendCounts->sum() >= 4, 'Trend breakdown should include the created feedback totals.');

        $listing->assertOk()
            ->assertJsonPath('total', 1)
            ->assertJsonCount(1, 'data')
            ->assertJsonFragment(['message' => $feedbackA[0]->message])
            ->assertJsonMissing(['message' => $feedbackB[0]->message]);
    }

    public function test_department_admin_feedback_endpoints_are_scoped_without_requiring_head_title(): void
    {
        [, $officeA, $officeB, $feedbackA, $feedbackB] = $this->seedFeedbackScenario();

        $admin = User::create([
            'name' => 'Roads Admin',
            'email' => 'roads-feedback-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'admin',
            'department' => $officeA->name,
            'job_title' => 'Field Engineer',
            'is_active' => true,
        ]);

        Sanctum::actingAs($admin);

        $summary = $this->getJson('/api/feedback/summary');
        $listing = $this->getJson('/api/feedback?paginate=true&per_page=10&page=1');
        $charts = $this->getJson('/api/feedback/charts');

        $summary->assertOk()
            ->assertJsonPath('total_feedback', 3)
            ->assertJsonPath('types.Suggestion', 1)
            ->assertJsonPath('types.Complaint', 1)
            ->assertJsonPath('types.Praise', 1);

        $listing->assertOk()
            ->assertJsonPath('total', 3)
            ->assertJsonFragment(['message' => $feedbackA[0]->message])
            ->assertJsonMissing(['message' => $feedbackB[0]->message]);

        $officeRows = collect($charts->json('office_breakdown'));
        $this->assertCount(1, $officeRows);
        $this->assertSame($officeA->name, $officeRows->first()['label']);
    }

    public function test_feedback_summary_excludes_seeded_demo_feedback_records_from_portal_analytics(): void
    {
        [$superAdmin, $officeA] = $this->seedFeedbackScenario();

        $demoCitizen = User::create([
            'name' => 'Demo Citizen',
            'email' => 'demo.citizen.999@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $category = Category::firstOrCreate(['name' => 'Demo Feedback Category']);
        $report = $this->makeReport(
            $demoCitizen,
            $officeA,
            $category,
            'Demo report should be hidden',
            'Barangay 9',
            Carbon::create(2026, 5, 11, 10, 0, 0, 'Asia/Manila'),
        );

        $demoMessage = 'Demo feedback should not appear in portal totals';
        $this->makeFeedback(
            $demoCitizen,
            $officeA,
            $report,
            'Praise',
            $demoMessage,
            5,
            Carbon::create(2026, 5, 11, 11, 0, 0, 'Asia/Manila'),
        );

        Sanctum::actingAs($superAdmin);

        $summary = $this->getJson('/api/feedback/summary');
        $charts = $this->getJson('/api/feedback/charts');
        $listing = $this->getJson('/api/feedback?paginate=true&per_page=10&page=1');

        $summary->assertOk()
            ->assertJsonPath('total_feedback', 4)
            ->assertJsonPath('types.Praise', 1);

        $charts->assertOk()
            ->assertJsonPath('rating_breakdown.4.count', 1);

        $officeRows = collect($charts->json('office_breakdown'));
        $this->assertTrue(
            $officeRows->contains(
                fn (array $row) => $row['label'] === $officeA->name && $row['count'] === 3
            ),
            'Portal feedback totals should continue to reflect only real office feedback rows.'
        );

        $barangays = collect($charts->json('barangay_breakdown'));
        $this->assertFalse(
            $barangays->contains(fn (array $row) => $row['label'] === 'Barangay 9'),
            'Demo-seeded feedback locations must be excluded from portal charts.'
        );

        $listing->assertOk()
            ->assertJsonPath('total', 4)
            ->assertJsonMissing(['message' => $demoMessage]);
    }

    public function test_feedback_summary_keeps_excluding_demo_feedback_after_demo_accounts_are_archived(): void
    {
        [$superAdmin, $officeA] = $this->seedFeedbackScenario();

        $demoCitizen = User::create([
            'name' => 'Demo Citizen',
            'email' => 'demo.citizen.998@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => false,
        ]);

        $category = Category::firstOrCreate(['name' => 'Archived Demo Feedback Category']);
        $report = $this->makeReport(
            $demoCitizen,
            $officeA,
            $category,
            'Archived demo report should be hidden',
            'Barangay 10',
            Carbon::create(2026, 5, 11, 10, 0, 0, 'Asia/Manila'),
        );

        $demoMessage = 'Archived demo feedback should not appear in portal totals';
        $this->makeFeedback(
            $demoCitizen,
            $officeA,
            $report,
            'Suggestion',
            $demoMessage,
            4,
            Carbon::create(2026, 5, 11, 11, 0, 0, 'Asia/Manila'),
        );
        $demoCitizen->delete();

        Sanctum::actingAs($superAdmin);

        $summary = $this->getJson('/api/feedback/summary');
        $charts = $this->getJson('/api/feedback/charts');
        $listing = $this->getJson('/api/feedback?paginate=true&per_page=10&page=1');

        $summary->assertOk()
            ->assertJsonPath('total_feedback', 4)
            ->assertJsonPath('types.Suggestion', 2);

        $charts->assertOk();

        $officeRows = collect($charts->json('office_breakdown'));
        $this->assertTrue(
            $officeRows->contains(
                fn (array $row) => $row['label'] === $officeA->name && $row['count'] === 3
            ),
            'Archived demo-seeded feedback must stay excluded from office totals.'
        );

        $listing->assertOk()
            ->assertJsonPath('total', 4)
            ->assertJsonMissing(['message' => $demoMessage]);
    }

    public function test_feedback_export_respects_active_filters(): void
    {
        [$superAdmin, $officeA, , $feedbackA, $feedbackB] = $this->seedFeedbackScenario();

        Sanctum::actingAs($superAdmin);

        $export = $this->get(
            '/api/feedback/export?office='.urlencode($officeA->name)
            .'&type=Praise'
            .'&barangay='.urlencode('Barangay 1')
            .'&rating=5'
            .'&date_preset=custom'
            .'&start_date=2026-05-10'
            .'&end_date=2026-05-10'
        );
        $content = $export->streamedContent();

        $export->assertOk();
        $this->assertStringContainsString('Feedback ID', $content);
        $this->assertStringContainsString($feedbackA[2]->message, $content);
        $this->assertStringNotContainsString($feedbackA[0]->message, $content);
        $this->assertStringNotContainsString($feedbackA[1]->message, $content);
        $this->assertStringNotContainsString($feedbackB[0]->message, $content);
    }

    private function seedFeedbackScenario(): array
    {
        $citizen = User::create([
            'name' => 'Feedback Citizen',
            'email' => 'feedback-citizen@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $superAdmin = User::create([
            'name' => 'Feedback Super Admin',
            'email' => 'feedback-super-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $officeA = Office::create([
            'name' => 'Roads Department',
            'is_active' => true,
        ]);

        $officeB = Office::create([
            'name' => 'Water Department',
            'is_active' => true,
        ]);

        $category = Category::create(['name' => 'Infrastructure']);
        $baseDate = Carbon::create(2026, 5, 10, 8, 0, 0, 'Asia/Manila');

        $reportA = $this->makeReport($citizen, $officeA, $category, 'Roads report', 'Barangay 1', $baseDate->copy()->subDays(3));
        $reportB = $this->makeReport($citizen, $officeB, $category, 'Water report', 'Barangay 2', $baseDate->copy()->subDays(1));

        $feedbackA = [
            $this->makeFeedback($citizen, $officeA, $reportA, 'Suggestion', 'Roads follow-up suggestion', 4, $baseDate->copy()->subDays(2)),
            $this->makeFeedback($citizen, $officeA, $reportA, 'Complaint', 'Roads department complaint', 2, $baseDate->copy()->subDay()),
            $this->makeFeedback($citizen, $officeA, $reportA, 'Praise', 'Roads department praise', 5, $baseDate->copy()),
        ];

        $feedbackB = [
            $this->makeFeedback($citizen, $officeB, $reportB, 'Suggestion', 'Water department suggestion', 3, $baseDate->copy()->subHours(6)),
        ];

        return [$superAdmin, $officeA, $officeB, $feedbackA, $feedbackB];
    }

    private function makeReport(
        User $citizen,
        Office $office,
        Category $category,
        string $title,
        string $barangay,
        Carbon $createdAt,
    ): Report {
        $report = new Report([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => $title,
            'description' => $title.' description',
            'location' => $barangay.', Tacloban City',
            'barangay' => $barangay,
            'status' => 'Resolved',
            'priority' => 'Normal',
            'resolved_at' => $createdAt->copy()->addDay(),
        ]);
        $report->created_at = $createdAt;
        $report->updated_at = $createdAt;
        $report->save();

        return $report;
    }

    private function makeFeedback(
        User $citizen,
        Office $office,
        Report $report,
        string $type,
        string $message,
        int $rating,
        Carbon $createdAt,
    ): CitizenFeedback {
        $feedback = new CitizenFeedback([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'report_id' => $report->id,
            'type' => $type,
            'message' => $message,
            'rating' => $rating,
        ]);
        $feedback->created_at = $createdAt;
        $feedback->updated_at = $createdAt;
        $feedback->save();

        return $feedback;
    }
}
