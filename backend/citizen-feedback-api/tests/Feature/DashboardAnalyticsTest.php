<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class DashboardAnalyticsTest extends TestCase
{
    use RefreshDatabase;

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
                    'title' => $barangay . ' issue #' . ($index + 1),
                    'description' => 'Road concern in ' . $barangay,
                    'location' => $barangay . ', Tacloban City',
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
}
