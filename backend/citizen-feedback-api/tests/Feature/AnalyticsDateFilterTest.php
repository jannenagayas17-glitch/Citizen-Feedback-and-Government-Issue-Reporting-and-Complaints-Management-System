<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class AnalyticsDateFilterTest extends TestCase
{
    use RefreshDatabase;

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_today_filter_limits_analytics_to_reports_created_today(): void
    {
        Carbon::setTestNow(Carbon::create(2026, 5, 10, 10, 0, 0, 'Asia/Manila'));

        $citizen = User::create([
            'name' => 'Citizen Reporter',
            'email' => 'citizen-analytics-filter@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'super-admin-analytics-filter@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $office = Office::create([
            'name' => 'City Health Office',
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Sanitation',
        ]);

        $todayReport = new Report([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Today report',
            'description' => 'Created today',
            'location' => 'Tacloban City',
            'barangay' => 'Barangay 5',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);
        $todayReport->created_at = Carbon::now()->subHours(1);
        $todayReport->updated_at = Carbon::now()->subHours(1);
        $todayReport->save();

        $olderReport = new Report([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Older report',
            'description' => 'Created last week',
            'location' => 'Tacloban City',
            'barangay' => 'Barangay 5',
            'status' => 'Resolved',
            'priority' => 'High',
            'resolved_at' => Carbon::now()->subDays(6)->addHours(3),
        ]);
        $olderReport->created_at = Carbon::now()->subDays(6);
        $olderReport->updated_at = Carbon::now()->subDays(5);
        $olderReport->save();

        Sanctum::actingAs($superAdmin);

        $response = $this->getJson('/api/admin/analytics?date_preset=today');

        $response->assertOk()
            ->assertJsonPath('overview.total_reports', 1)
            ->assertJsonPath('overview.pending', 1)
            ->assertJsonPath('overview.resolved', 0)
            ->assertJsonPath('comparison_overview.total_reports', 0)
            ->assertJsonPath('applied_filters.date_preset', 'today')
            ->assertJsonPath('applied_filters.start_date', '2026-05-10')
            ->assertJsonPath('applied_filters.end_date', '2026-05-10');

        $this->assertSame(
            1,
            collect($response->json('timeline_breakdown'))->sum('total'),
            'Timeline totals should reflect only today\'s reports.'
        );
    }

    public function test_custom_date_range_updates_analytics_breakdowns(): void
    {
        Carbon::setTestNow(Carbon::create(2026, 5, 10, 10, 0, 0, 'Asia/Manila'));

        $citizen = User::create([
            'name' => 'Citizen Reporter',
            'email' => 'citizen-analytics-custom@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'super-admin-analytics-custom@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $office = Office::create([
            'name' => "City Engineer's Office",
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Drainage',
        ]);

        foreach ([
            ['date' => '2026-04-20 09:00:00', 'status' => 'Pending'],
            ['date' => '2026-04-25 10:00:00', 'status' => 'Resolved'],
            ['date' => '2026-05-02 11:00:00', 'status' => 'In Progress'],
            ['date' => '2026-05-09 12:00:00', 'status' => 'Resolved'],
            ['date' => '2026-04-18 12:00:00', 'status' => 'Rejected'],
        ] as $index => $item) {
            $createdAt = Carbon::parse($item['date'], 'Asia/Manila');
            $report = new Report([
                'user_id' => $citizen->id,
                'office_id' => $office->id,
                'category_id' => $category->id,
                'title' => 'Custom range report '.$index,
                'description' => 'Custom range analytics coverage',
                'location' => 'Tacloban City',
                'barangay' => 'Barangay 12',
                'status' => $item['status'],
                'priority' => 'Normal',
                'resolved_at' => $item['status'] === 'Resolved' ? $createdAt->copy()->addDays(1) : null,
            ]);
            $report->created_at = $createdAt;
            $report->updated_at = $createdAt;
            $report->save();
        }

        Sanctum::actingAs($superAdmin);

        $response = $this->getJson(
            '/api/admin/analytics?date_preset=custom&start_date=2026-04-20&end_date=2026-05-09'
        );

        $response->assertOk()
            ->assertJsonPath('overview.total_reports', 4)
            ->assertJsonPath('overview.pending', 1)
            ->assertJsonPath('overview.in_progress', 1)
            ->assertJsonPath('overview.resolved', 2)
            ->assertJsonPath('comparison_overview.total_reports', 1)
            ->assertJsonPath('applied_filters.start_date', '2026-04-20')
            ->assertJsonPath('applied_filters.end_date', '2026-05-09')
            ->assertJsonPath('barangay_breakdown.0.label', 'Barangay 12')
            ->assertJsonPath('barangay_breakdown.0.count', 4);

        $this->assertSame(
            4,
            collect($response->json('timeline_breakdown'))->sum('total'),
            'Timeline totals should match the custom-range overview count.'
        );
    }

    public function test_new_analytics_presets_update_scope_and_grouping_from_real_report_dates(): void
    {
        Carbon::setTestNow(Carbon::create(2026, 5, 15, 10, 0, 0, 'Asia/Manila'));

        $citizen = User::create([
            'name' => 'Preset Citizen',
            'email' => 'preset-citizen@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $superAdmin = User::create([
            'name' => 'Preset Super Admin',
            'email' => 'preset-super-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $office = Office::create([
            'name' => 'Business Permit Office',
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Permits',
        ]);

        foreach ([
            ['date' => '2025-12-20 09:00:00', 'status' => 'Resolved'],
            ['date' => '2026-01-08 09:00:00', 'status' => 'Pending'],
            ['date' => '2026-05-01 09:00:00', 'status' => 'Pending'],
            ['date' => '2026-05-05 09:00:00', 'status' => 'Resolved'],
            ['date' => '2026-05-12 09:00:00', 'status' => 'In Progress'],
            ['date' => '2026-05-14 09:00:00', 'status' => 'Pending'],
        ] as $index => $item) {
            $createdAt = Carbon::parse($item['date'], 'Asia/Manila');
            $report = new Report([
                'user_id' => $citizen->id,
                'office_id' => $office->id,
                'category_id' => $category->id,
                'title' => 'Preset report '.$index,
                'description' => 'Preset analytics coverage',
                'location' => 'Tacloban City',
                'barangay' => 'Barangay 8',
                'status' => $item['status'],
                'priority' => 'Normal',
                'resolved_at' => $item['status'] === 'Resolved' ? $createdAt->copy()->addDay() : null,
            ]);
            $report->created_at = $createdAt;
            $report->updated_at = $createdAt;
            $report->save();
        }

        Sanctum::actingAs($superAdmin);

        $weekly = $this->getJson('/api/admin/analytics?date_preset=weekly');
        $monthly = $this->getJson('/api/admin/analytics?date_preset=monthly');
        $yearly = $this->getJson('/api/admin/analytics?date_preset=yearly');
        $allTime = $this->getJson('/api/admin/analytics?date_preset=all_time');

        $weekly->assertOk()
            ->assertJsonPath('overview.total_reports', 2)
            ->assertJsonPath('applied_filters.date_preset', 'weekly')
            ->assertJsonPath('timeline_meta.grouping', 'day');

        $monthly->assertOk()
            ->assertJsonPath('overview.total_reports', 4)
            ->assertJsonPath('applied_filters.date_preset', 'monthly')
            ->assertJsonPath('timeline_meta.grouping', 'week');

        $yearly->assertOk()
            ->assertJsonPath('overview.total_reports', 5)
            ->assertJsonPath('applied_filters.date_preset', 'yearly')
            ->assertJsonPath('timeline_meta.grouping', 'month');

        $allTime->assertOk()
            ->assertJsonPath('overview.total_reports', 6)
            ->assertJsonPath('applied_filters.date_preset', 'all_time')
            ->assertJsonPath('timeline_meta.grouping', 'month');

        $this->assertSame(2, collect($weekly->json('timeline_breakdown'))->sum('total'));
        $this->assertSame(4, collect($monthly->json('timeline_breakdown'))->sum('total'));
        $this->assertSame(5, collect($yearly->json('timeline_breakdown'))->sum('total'));
        $this->assertSame(6, collect($allTime->json('timeline_breakdown'))->sum('total'));
    }
}
