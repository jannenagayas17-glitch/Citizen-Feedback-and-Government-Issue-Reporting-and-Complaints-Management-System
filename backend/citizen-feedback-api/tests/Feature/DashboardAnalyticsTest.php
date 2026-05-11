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
}
