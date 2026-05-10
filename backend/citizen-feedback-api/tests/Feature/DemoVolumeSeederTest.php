<?php

namespace Tests\Feature;

use App\Models\AdminResponse;
use App\Models\CitizenFeedback;
use App\Models\Report;
use App\Models\ReportImage;
use App\Models\StatusHistory;
use App\Models\User;
use Database\Seeders\DemoVolumeSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class DemoVolumeSeederTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        $this->setDemoEnv('DEMO_ADMIN_COUNT', null);
        $this->setDemoEnv('DEMO_CITIZEN_COUNT', null);
        $this->setDemoEnv('DEMO_REPORT_COUNT', null);
        $this->setDemoEnv('DEMO_FEEDBACK_COUNT', null);

        parent::tearDown();
    }

    public function test_demo_volume_seeder_creates_historical_reports_with_media_and_related_records(): void
    {
        $this->setDemoEnv('DEMO_ADMIN_COUNT', '6');
        $this->setDemoEnv('DEMO_CITIZEN_COUNT', '20');
        $this->setDemoEnv('DEMO_REPORT_COUNT', '24');
        $this->setDemoEnv('DEMO_FEEDBACK_COUNT', '8');

        $this->seed(DemoVolumeSeeder::class);

        $demoCitizens = User::query()
            ->where('email', 'like', 'demo.citizen.%')
            ->orderBy('id')
            ->get();
        $demoReports = Report::query()
            ->whereIn('user_id', $demoCitizens->pluck('id'))
            ->with('images')
            ->orderBy('id')
            ->get();

        $this->assertCount(20, $demoCitizens);
        $this->assertCount(24, $demoReports);
        $this->assertGreaterThanOrEqual(6, User::query()->where('email', 'like', 'demo.admin.%')->count());

        $years = $demoReports->map(fn (Report $report) => (int) $report->created_at->format('Y'))->unique()->sort()->values()->all();
        $this->assertSame([2024, 2025], $years);
        $this->assertGreaterThanOrEqual(
            6,
            $demoReports->map(fn (Report $report) => $report->created_at->format('Y-m'))->unique()->count()
        );

        $this->assertTrue(
            $demoReports->every(
                fn (Report $report) => in_array($report->status, ['New', 'Pending', 'In Progress', 'Resolved'], true)
            )
        );

        $this->assertGreaterThan(0, ReportImage::query()->where('media_type', 'image')->count());
        $this->assertGreaterThan(0, ReportImage::query()->where('media_type', 'video')->count());
        $this->assertGreaterThan(0, StatusHistory::query()->count());
        $this->assertGreaterThan(0, AdminResponse::query()->count());
        $this->assertGreaterThan(0, CitizenFeedback::query()->count());
    }

    private function setDemoEnv(string $key, ?string $value): void
    {
        if ($value === null) {
            putenv($key);
            unset($_ENV[$key], $_SERVER[$key]);

            return;
        }

        putenv("{$key}={$value}");
        $_ENV[$key] = $value;
        $_SERVER[$key] = $value;
    }
}
