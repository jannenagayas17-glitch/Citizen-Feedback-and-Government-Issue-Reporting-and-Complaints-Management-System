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

class DashboardAnalyticsTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_analytics_only_counts_reports_from_the_assigned_office(): void
    {
        $citizen = User::create([
            'name' => 'Citizen Reporter',
            'email' => 'citizen-analytics-scope@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $adminOffice = Office::create([
            'name' => 'Roads Department',
            'is_active' => true,
        ]);

        $otherOffice = Office::create([
            'name' => 'Water Department',
            'is_active' => true,
        ]);

        $admin = User::create([
            'name' => 'Roads Admin',
            'email' => 'roads-admin-analytics@example.com',
            'password' => Hash::make('password123'),
            'role' => 'admin',
            'department' => mb_strtolower($adminOffice->name),
            'is_active' => true,
        ]);

        $roadCategory = Category::create(['name' => 'Road Damage']);
        $waterCategory = Category::create(['name' => 'Water Leak']);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $adminOffice->id,
            'category_id' => $roadCategory->id,
            'title' => 'Road issue 1',
            'description' => 'Road concern for assigned office.',
            'location' => 'Roads location',
            'barangay' => 'Barangay 1',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $adminOffice->id,
            'category_id' => $roadCategory->id,
            'title' => 'Road issue 2',
            'description' => 'Resolved concern for assigned office.',
            'location' => 'Roads location 2',
            'barangay' => 'Barangay 3',
            'status' => 'Resolved',
            'priority' => 'High',
        ]);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $otherOffice->id,
            'category_id' => $waterCategory->id,
            'title' => 'Water issue',
            'description' => 'Concern for another office.',
            'location' => 'Water location',
            'barangay' => 'Barangay 9',
            'status' => 'In Progress',
            'priority' => 'Urgent',
        ]);

        Sanctum::actingAs($admin);

        $response = $this->getJson('/api/admin/analytics');

        $response->assertOk()
            ->assertJsonPath('overview.total_reports', 2)
            ->assertJsonPath('overview.pending', 1)
            ->assertJsonPath('overview.resolved', 1)
            ->assertJsonPath('overview.in_progress', 0)
            ->assertJsonPath('category_breakdown.0.label', 'Road Damage')
            ->assertJsonPath('category_breakdown.0.count', 2);

        $barangays = collect($response->json('barangay_breakdown'));
        $this->assertTrue(
            $barangays->contains(fn (array $row) => $row['label'] === 'Barangay 1'),
            'Assigned office barangays should appear in analytics.'
        );
        $this->assertFalse(
            $barangays->contains(fn (array $row) => $row['label'] === 'Barangay 9'),
            'Other office barangays must not appear in admin analytics.'
        );
    }

    public function test_super_admin_analytics_returns_top_five_barangays_sorted_by_report_count(): void
    {
        $citizen = User::create([
            'name' => 'Citizen Reporter',
            'email' => 'citizen-analytics@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'superadmin-analytics@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $office = Office::create([
            'name' => "City Engineer's Office",
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Road Repairs',
        ]);

        $barangayCounts = [
            'Barangay 7' => 6,
            'Barangay 5' => 5,
            'Barangay 9' => 4,
            'Barangay 2' => 3,
            'Barangay 1' => 2,
            'Barangay 3' => 1,
        ];

        foreach ($barangayCounts as $barangay => $count) {
            for ($index = 0; $index < $count; $index++) {
                Report::create([
                    'user_id' => $citizen->id,
                    'office_id' => $office->id,
                    'category_id' => $category->id,
                    'title' => $barangay.' issue #'.($index + 1),
                    'description' => 'Road concern in '.$barangay,
                    'location' => $barangay.', Tacloban City',
                    'barangay' => $barangay,
                    'status' => 'Pending',
                    'priority' => 'Normal',
                ]);
            }
        }

        Sanctum::actingAs($superAdmin);

        $response = $this->getJson('/api/admin/analytics');

        $response
            ->assertOk()
            ->assertJsonCount(5, 'barangay_breakdown')
            ->assertJsonPath('barangay_breakdown.0.label', 'Barangay 7')
            ->assertJsonPath('barangay_breakdown.0.count', 6)
            ->assertJsonPath('barangay_breakdown.1.label', 'Barangay 5')
            ->assertJsonPath('barangay_breakdown.1.count', 5)
            ->assertJsonPath('barangay_breakdown.4.label', 'Barangay 1')
            ->assertJsonPath('barangay_breakdown.4.count', 2);

        $barangays = collect($response->json('barangay_breakdown'));

        $this->assertFalse(
            $barangays->contains(fn (array $row) => $row['label'] === 'Barangay 3'),
            'Barangay 3 should not be included in the top five list.'
        );
    }

    public function test_super_admin_analytics_combined_filters_return_only_matching_reports(): void
    {
        $citizen = User::create([
            'name' => 'Filter Citizen',
            'email' => 'filter-citizen@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $superAdmin = User::create([
            'name' => 'Filter Super Admin',
            'email' => 'filter-super-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $engineering = Office::create([
            'name' => "City Engineer's Office",
            'is_active' => true,
        ]);

        $health = Office::create([
            'name' => 'City Health Office',
            'is_active' => true,
        ]);

        $drainage = Category::create(['name' => 'Drainage']);
        $sanitation = Category::create(['name' => 'Sanitation']);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $engineering->id,
            'category_id' => $drainage->id,
            'title' => 'Matching analytics filter report',
            'description' => 'This report should match all analytics filters.',
            'location' => 'Barangay 7, Tacloban City',
            'barangay' => 'Barangay 7',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $engineering->id,
            'category_id' => $drainage->id,
            'title' => 'Wrong status report',
            'description' => 'Should be excluded by status filter.',
            'location' => 'Barangay 7, Tacloban City',
            'barangay' => 'Barangay 7',
            'status' => 'Resolved',
            'priority' => 'Normal',
        ]);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $engineering->id,
            'category_id' => $sanitation->id,
            'title' => 'Wrong category report',
            'description' => 'Should be excluded by category filter.',
            'location' => 'Barangay 7, Tacloban City',
            'barangay' => 'Barangay 7',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $health->id,
            'category_id' => $drainage->id,
            'title' => 'Wrong office report',
            'description' => 'Should be excluded by office filter.',
            'location' => 'Barangay 7, Tacloban City',
            'barangay' => 'Barangay 7',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $engineering->id,
            'category_id' => $drainage->id,
            'title' => 'Wrong barangay report',
            'description' => 'Should be excluded by barangay filter.',
            'location' => 'Barangay 5, Tacloban City',
            'barangay' => 'Barangay 5',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);

        Sanctum::actingAs($superAdmin);

        $response = $this->getJson(
            '/api/admin/analytics?office='.urlencode($engineering->name)
            .'&barangay='.urlencode('Barangay 7')
            .'&category='.urlencode($drainage->name)
            .'&status='.urlencode('Pending')
            .'&date_preset=all_time'
        );

        $response->assertOk()
            ->assertJsonPath('overview.total_reports', 1)
            ->assertJsonPath('overview.pending', 1)
            ->assertJsonPath('overview.resolved', 0)
            ->assertJsonPath('applied_filters.office', $engineering->name)
            ->assertJsonPath('applied_filters.barangay', 'Barangay 7')
            ->assertJsonPath('applied_filters.category', $drainage->name)
            ->assertJsonPath('applied_filters.status', 'Pending')
            ->assertJsonPath('category_breakdown.0.label', $drainage->name)
            ->assertJsonPath('category_breakdown.0.count', 1)
            ->assertJsonPath('barangay_breakdown.0.label', 'Barangay 7')
            ->assertJsonPath('barangay_breakdown.0.count', 1);
    }

    public function test_super_admin_analytics_monthly_trend_uses_the_latest_report_month_in_the_dataset(): void
    {
        $citizen = User::create([
            'name' => 'Historical Citizen',
            'email' => 'historical-citizen@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $superAdmin = User::create([
            'name' => 'Historical Super Admin',
            'email' => 'historical-super-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $office = Office::create([
            'name' => "City Engineer's Office",
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Flooding',
        ]);

        $latestMonth = Carbon::create(2025, 12, 1, 9, 0, 0, 'Asia/Manila');

        foreach (range(0, 5) as $offset) {
            $createdAt = $latestMonth->copy()->subMonths(5 - $offset)->addDays(3);
            $report = new Report([
                'user_id' => $citizen->id,
                'office_id' => $office->id,
                'category_id' => $category->id,
                'title' => 'Historical issue '.$offset,
                'description' => 'Historical analytics coverage for month '.$offset,
                'location' => 'Barangay 1, Tacloban City',
                'barangay' => 'Barangay 1',
                'status' => $offset >= 3 ? 'Resolved' : 'In Progress',
                'priority' => 'High',
                'resolved_at' => $offset >= 3 ? $createdAt->copy()->addDays(4) : null,
            ]);
            $report->created_at = $createdAt;
            $report->updated_at = $createdAt->copy()->addDays(2);
            $report->save();
        }

        Sanctum::actingAs($superAdmin);

        $response = $this->getJson('/api/admin/analytics');

        $response
            ->assertOk()
            ->assertJsonCount(6, 'monthly_trend')
            ->assertJsonPath('monthly_trend.0.label', 'Jul')
            ->assertJsonPath('monthly_trend.5.label', 'Dec')
            ->assertJsonPath('monthly_trend.5.new_reports', 1)
            ->assertJsonPath('monthly_trend.3.resolved_reports', 1);
    }

    public function test_super_admin_dashboard_analytics_and_report_listing_match_without_filters(): void
    {
        $citizen = User::create([
            'name' => 'Consistency Citizen',
            'email' => 'consistency-citizen@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $superAdmin = User::create([
            'name' => 'Consistency Super Admin',
            'email' => 'consistency-super-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $roadOffice = Office::create([
            'name' => 'Roads and Drainage Office',
            'is_active' => true,
        ]);

        $healthOffice = Office::create([
            'name' => 'City Health Office',
            'is_active' => true,
        ]);

        $roadCategory = Category::create(['name' => 'Road Repair']);
        $healthCategory = Category::create(['name' => 'Sanitation']);

        foreach ([
            [$roadOffice->id, $roadCategory->id, 'Pending', 'Barangay 1'],
            [$roadOffice->id, $roadCategory->id, 'Resolved', 'Barangay 2'],
            [$healthOffice->id, $healthCategory->id, 'In Progress', 'Barangay 3'],
            [$healthOffice->id, $healthCategory->id, 'Rejected', 'Barangay 4'],
        ] as $index => [$officeId, $categoryId, $status, $barangay]) {
            Report::create([
                'user_id' => $citizen->id,
                'office_id' => $officeId,
                'category_id' => $categoryId,
                'title' => 'Consistency report '.$index,
                'description' => 'Consistency coverage '.$index,
                'location' => 'Tacloban City',
                'barangay' => $barangay,
                'status' => $status,
                'priority' => 'Normal',
            ]);
        }

        Sanctum::actingAs($superAdmin);

        $dashboard = $this->getJson('/api/dashboard');
        $analytics = $this->getJson('/api/admin/analytics');
        $reports = $this->getJson('/api/admin/reports?paginate=true&per_page=25');

        $dashboard->assertOk()
            ->assertJsonPath('total_reports', 4)
            ->assertJsonPath('queue_count', 2)
            ->assertJsonPath('rejected', 1);

        $analytics->assertOk()
            ->assertJsonPath('overview.total_reports', 4)
            ->assertJsonPath('overview.queue_count', 2)
            ->assertJsonPath('overview.rejected', 1);

        $reports->assertOk()
            ->assertJsonPath('total', 4);
    }

    public function test_department_admin_dashboard_analytics_and_report_listing_match_within_office_scope(): void
    {
        $citizen = User::create([
            'name' => 'Scoped Citizen',
            'email' => 'scoped-citizen@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $adminOffice = Office::create([
            'name' => 'Traffic Management Office',
            'is_active' => true,
        ]);

        $otherOffice = Office::create([
            'name' => 'Water Services Office',
            'is_active' => true,
        ]);

        $admin = User::create([
            'name' => 'Traffic Admin',
            'email' => 'traffic-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'admin',
            'department' => mb_strtolower($adminOffice->name),
            'is_active' => true,
        ]);

        $category = Category::create(['name' => 'Operations']);

        foreach ([
            [$adminOffice->id, 'Pending', 'Barangay 1'],
            [$adminOffice->id, 'Resolved', 'Barangay 2'],
            [$otherOffice->id, 'In Progress', 'Barangay 9'],
        ] as $index => [$officeId, $status, $barangay]) {
            Report::create([
                'user_id' => $citizen->id,
                'office_id' => $officeId,
                'category_id' => $category->id,
                'title' => 'Scoped report '.$index,
                'description' => 'Scoped analytics report '.$index,
                'location' => 'Tacloban City',
                'barangay' => $barangay,
                'status' => $status,
                'priority' => 'Normal',
            ]);
        }

        Sanctum::actingAs($admin);

        $dashboard = $this->getJson('/api/dashboard');
        $analytics = $this->getJson('/api/admin/analytics');
        $reports = $this->getJson('/api/admin/reports?paginate=true&per_page=25');

        $dashboard->assertOk()
            ->assertJsonPath('total_reports', 2)
            ->assertJsonPath('queue_count', 1)
            ->assertJsonPath('resolved', 1);

        $analytics->assertOk()
            ->assertJsonPath('overview.total_reports', 2)
            ->assertJsonPath('overview.queue_count', 1)
            ->assertJsonPath('overview.resolved', 1);

        $reports->assertOk()
            ->assertJsonPath('total', 2)
            ->assertJsonMissing(['barangay' => 'Barangay 9']);
    }

    public function test_super_admin_department_trend_series_are_unique_per_office(): void
    {
        Carbon::setTestNow(Carbon::create(2026, 5, 15, 10, 0, 0, 'Asia/Manila'));

        $citizen = User::create([
            'name' => 'Trend Citizen',
            'email' => 'trend-citizen@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $superAdmin = User::create([
            'name' => 'Trend Super Admin',
            'email' => 'trend-super-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $engineerOffice = Office::create([
            'name' => "City Engineer's Office",
            'is_active' => true,
        ]);

        $permitOffice = Office::create([
            'name' => 'Business Permit Office',
            'is_active' => true,
        ]);

        $category = Category::create(['name' => 'Operations']);

        foreach ([
            [$engineerOffice->id, '2026-05-12 08:00:00', 'Pending'],
            [$engineerOffice->id, '2026-05-12 10:00:00', 'Resolved'],
            [$engineerOffice->id, '2026-05-13 11:00:00', 'In Progress'],
            [$permitOffice->id, '2026-05-14 08:00:00', 'Pending'],
            [$permitOffice->id, '2026-05-14 09:00:00', 'Pending'],
            [$permitOffice->id, '2026-05-15 09:00:00', 'Resolved'],
        ] as $index => [$officeId, $date, $status]) {
            $createdAt = Carbon::parse($date, 'Asia/Manila');
            $report = new Report([
                'user_id' => $citizen->id,
                'office_id' => $officeId,
                'category_id' => $category->id,
                'title' => 'Department trend report '.$index,
                'description' => 'Department trend analytics coverage',
                'location' => 'Tacloban City',
                'barangay' => 'Barangay 10',
                'status' => $status,
                'priority' => 'Normal',
                'resolved_at' => $status === 'Resolved' ? $createdAt->copy()->addDay() : null,
            ]);
            $report->created_at = $createdAt;
            $report->updated_at = $createdAt;
            $report->save();
        }

        Sanctum::actingAs($superAdmin);

        $response = $this->getJson('/api/admin/analytics?date_preset=weekly');

        $response->assertOk()
            ->assertJsonPath('overview.total_reports', 6)
            ->assertJsonPath('applied_filters.date_preset', 'weekly')
            ->assertJsonPath('timeline_meta.grouping', 'day');

        $series = collect($response->json('department_trend.series'))->keyBy('label');

        $this->assertTrue($series->has("City Engineer's Office"));
        $this->assertTrue($series->has('Business Permit Office'));
        $this->assertSame(
            3,
            array_sum($series["City Engineer's Office"]['counts']),
            'City Engineer analytics should reflect only its own weekly reports.'
        );
        $this->assertSame(
            3,
            array_sum($series['Business Permit Office']['counts']),
            'Business Permit analytics should reflect only its own weekly reports.'
        );
        $this->assertNotSame(
            $series["City Engineer's Office"]['counts'],
            $series['Business Permit Office']['counts'],
            'Department trend series must differ between offices.'
        );
    }

    public function test_super_admin_dashboard_analytics_and_report_listing_exclude_demo_seeded_reports(): void
    {
        $citizen = User::create([
            'name' => 'Real Citizen',
            'email' => 'real-dashboard-citizen@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $demoCitizen = User::create([
            'name' => 'Demo Citizen',
            'email' => 'demo.citizen.777@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $superAdmin = User::create([
            'name' => 'Dashboard Super Admin',
            'email' => 'dashboard-super-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $office = Office::create([
            'name' => 'Environment Office',
            'is_active' => true,
        ]);

        $category = Category::create(['name' => 'Sanitation']);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Real report',
            'description' => 'Real report that should remain visible.',
            'location' => 'Tacloban City',
            'barangay' => 'Barangay 1',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);

        Report::create([
            'user_id' => $demoCitizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Demo seeded report',
            'description' => 'Demo seeded report that must stay hidden from portal analytics.',
            'location' => 'Tacloban City',
            'barangay' => 'Barangay 9',
            'status' => 'Resolved',
            'priority' => 'Normal',
        ]);

        Sanctum::actingAs($superAdmin);

        $dashboard = $this->getJson('/api/dashboard');
        $analytics = $this->getJson('/api/admin/analytics');
        $reports = $this->getJson('/api/admin/reports?paginate=true&per_page=25');

        $dashboard->assertOk()
            ->assertJsonPath('total_reports', 1)
            ->assertJsonPath('pending', 1)
            ->assertJsonPath('resolved', 0);

        $analytics->assertOk()
            ->assertJsonPath('overview.total_reports', 1)
            ->assertJsonPath('overview.pending', 1)
            ->assertJsonPath('overview.resolved', 0);

        $reports->assertOk()
            ->assertJsonPath('total', 1)
            ->assertJsonMissing(['title' => 'Demo seeded report'])
            ->assertJsonMissing(['barangay' => 'Barangay 9']);
    }

    public function test_super_admin_dashboard_analytics_keep_excluding_demo_reports_after_demo_accounts_are_archived(): void
    {
        $citizen = User::create([
            'name' => 'Real Citizen',
            'email' => 'real-archived-dashboard@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $demoCitizen = User::create([
            'name' => 'Demo Citizen',
            'email' => 'demo.citizen.778@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => false,
        ]);

        $superAdmin = User::create([
            'name' => 'Dashboard Super Admin',
            'email' => 'dashboard-archived-super-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $office = Office::create([
            'name' => 'Environment Office',
            'is_active' => true,
        ]);

        $category = Category::create(['name' => 'Sanitation']);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Real report',
            'description' => 'Real report that should remain visible.',
            'location' => 'Tacloban City',
            'barangay' => 'Barangay 1',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);

        Report::create([
            'user_id' => $demoCitizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Archived demo seeded report',
            'description' => 'Archived demo seeded report that must stay hidden from portal analytics.',
            'location' => 'Tacloban City',
            'barangay' => 'Barangay 9',
            'status' => 'Resolved',
            'priority' => 'Normal',
        ]);

        $demoCitizen->delete();

        Sanctum::actingAs($superAdmin);

        $dashboard = $this->getJson('/api/dashboard');
        $analytics = $this->getJson('/api/admin/analytics');
        $reports = $this->getJson('/api/admin/reports?paginate=true&per_page=25');

        $dashboard->assertOk()
            ->assertJsonPath('total_reports', 1)
            ->assertJsonPath('pending', 1)
            ->assertJsonPath('resolved', 0);

        $analytics->assertOk()
            ->assertJsonPath('overview.total_reports', 1)
            ->assertJsonPath('overview.pending', 1)
            ->assertJsonPath('overview.resolved', 0);

        $reports->assertOk()
            ->assertJsonPath('total', 1)
            ->assertJsonMissing(['title' => 'Archived demo seeded report'])
            ->assertJsonMissing(['barangay' => 'Barangay 9']);
    }
}
