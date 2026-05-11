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

class AdminReportListingTest extends TestCase
{
    use RefreshDatabase;

    public function test_admin_reports_and_export_are_scoped_to_the_assigned_office(): void
    {
        $citizen = User::create([
            'name' => 'Citizen Reporter',
            'email' => 'citizen-office-scope@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $adminOffice = Office::create([
            'name' => "City Engineer's Office",
            'is_active' => true,
        ]);

        $otherOffice = Office::create([
            'name' => 'City Social Welfare Office',
            'is_active' => true,
        ]);

        $admin = User::create([
            'name' => 'Scoped Admin',
            'email' => 'scoped-admin@example.com',
            'password' => Hash::make('password123'),
            'role' => 'admin',
            'department' => mb_strtolower($adminOffice->name),
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Road Damage',
        ]);

        $visibleReport = Report::create([
            'user_id' => $citizen->id,
            'office_id' => $adminOffice->id,
            'category_id' => $category->id,
            'title' => 'Visible office report',
            'description' => 'Should be visible to the assigned office admin.',
            'location' => 'Tacloban City Hall',
            'barangay' => 'Barangay 1',
            'status' => 'Pending',
            'priority' => 'Normal',
        ]);

        Report::create([
            'user_id' => $citizen->id,
            'office_id' => $otherOffice->id,
            'category_id' => $category->id,
            'title' => 'Hidden office report',
            'description' => 'Must not appear for another office admin.',
            'location' => 'Downtown Tacloban',
            'barangay' => 'Barangay 2',
            'status' => 'Resolved',
            'priority' => 'Normal',
        ]);

        Sanctum::actingAs($admin);

        $listing = $this->getJson('/api/admin/reports');
        $export = $this->get('/api/admin/reports/export');
        $content = $export->streamedContent();

        $listing->assertOk()
            ->assertJsonCount(1)
            ->assertJsonFragment([
                'id' => $visibleReport->id,
                'office_id' => $adminOffice->id,
            ])
            ->assertJsonMissing([
                'title' => 'Hidden office report',
            ]);

        $export->assertOk();
        $this->assertStringContainsString(e($adminOffice->name), $content);
        $this->assertStringContainsString('Visible office report', $content);
        $this->assertStringNotContainsString($otherOffice->name, $content);
        $this->assertStringNotContainsString('Hidden office report', $content);
    }

    public function test_admin_reports_pagination_returns_distinct_stable_pages(): void
    {
        $citizen = User::create([
            'name' => 'Citizen Reporter',
            'email' => 'citizen-pagination@example.com',
            'password' => Hash::make('password123'),
            'role' => 'citizen',
            'is_active' => true,
        ]);

        $superAdmin = User::create([
            'name' => 'Super Admin',
            'email' => 'super-admin-pagination@example.com',
            'password' => Hash::make('password123'),
            'role' => 'super_admin',
            'is_active' => true,
        ]);

        $office = Office::create([
            'name' => "City Engineer's Office",
            'is_active' => true,
        ]);

        $category = Category::create([
            'name' => 'Road Damage',
        ]);

        foreach (range(1, 24) as $index) {
            $createdAt = Carbon::create(2026, 5, 1, 8, 0, 0, 'Asia/Manila')
                ->addMinutes($index);

            $report = new Report([
                'user_id' => $citizen->id,
                'office_id' => $office->id,
                'category_id' => $category->id,
                'title' => 'Paged report '.$index,
                'description' => 'Pagination verification report '.$index,
                'location' => 'Tacloban City',
                'barangay' => 'Barangay '.(($index % 10) + 1),
                'status' => $index % 2 === 0 ? 'Pending' : 'Resolved',
                'priority' => 'Normal',
            ]);
            $report->created_at = $createdAt;
            $report->updated_at = $createdAt;
            $report->save();
        }

        Sanctum::actingAs($superAdmin);

        $pageOne = $this->getJson('/api/admin/reports?paginate=true&per_page=10&page=1');
        $pageTwo = $this->getJson('/api/admin/reports?paginate=true&per_page=10&page=2');

        $pageOne->assertOk()
            ->assertJsonPath('current_page', 1)
            ->assertJsonPath('per_page', 10)
            ->assertJsonPath('total', 24)
            ->assertJsonCount(10, 'data');

        $pageTwo->assertOk()
            ->assertJsonPath('current_page', 2)
            ->assertJsonCount(10, 'data');

        $pageOneIds = collect($pageOne->json('data'))->pluck('id');
        $pageTwoIds = collect($pageTwo->json('data'))->pluck('id');

        $this->assertCount(10, $pageOneIds->unique(), 'Page 1 should not contain duplicate reports.');
        $this->assertCount(10, $pageTwoIds->unique(), 'Page 2 should not contain duplicate reports.');
        $this->assertTrue(
            $pageOneIds->intersect($pageTwoIds)->isEmpty(),
            'Adjacent pages should not contain overlapping reports.'
        );
        $this->assertTrue(
            $pageOneIds->contains(24) && $pageOneIds->contains(15),
            'Page 1 should contain the newest reports first.'
        );
        $this->assertTrue(
            $pageTwoIds->contains(14) && $pageTwoIds->contains(5),
            'Page 2 should continue the ordered sequence without gaps.'
        );
    }
}
