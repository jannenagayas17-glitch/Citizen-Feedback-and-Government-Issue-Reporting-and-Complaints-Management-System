<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\User;
use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    use WithoutModelEvents;

    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        $categories = [
            [
                'name' => 'Roads',
                'description' => 'Road damage, potholes, sidewalks, and traffic-related concerns.',
            ],
            [
                'name' => 'Water',
                'description' => 'Leaks, broken pipes, water interruptions, and flooding concerns.',
            ],
            [
                'name' => 'Electric',
                'description' => 'Street lights, exposed wiring, and electrical safety issues.',
            ],
            [
                'name' => 'Drainage',
                'description' => 'Clogged canals, drainage blockages, and stormwater issues.',
            ],
            [
                'name' => 'Waste Management',
                'description' => 'Garbage buildup, illegal dumping, and sanitation concerns.',
            ],
        ];

        foreach ($categories as $category) {
            Category::updateOrCreate(
                ['name' => $category['name']],
                ['description' => $category['description']]
            );
        }

        User::updateOrCreate(
            ['email' => 'test@example.com'],
            [
                'name' => 'Test User',
                'mobile_number' => '09170000001',
                'password' => 'password123',
                'role' => 'citizen',
            ]
        );

        User::updateOrCreate(
            ['email' => 'admin@gov.ph'],
            [
                'name' => 'System Admin',
                'mobile_number' => '09170000002',
                'password' => 'admin12345',
                'role' => 'admin',
                'department' => 'City Engineering Office',
                'job_title' => 'Administrator',
            ]
        );

        User::updateOrCreate(
            ['email' => 'cityengineer@gov.ph'],
            [
                'name' => 'Super Admin',
                'mobile_number' => '09170000003',
                'password' => 'superadmin123',
                'role' => 'super_admin',
                'department' => 'City Engineering Office',
                'job_title' => 'City Engineer',
            ]
        );
    }
}
