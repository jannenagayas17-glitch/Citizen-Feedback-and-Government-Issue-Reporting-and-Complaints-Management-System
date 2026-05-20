<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Office;
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
        $offices = [
            [
                'name' => 'Business Permit and Licensing Division',
                'code' => 'BPLD',
                'description' => 'Handles business permits, licensing concerns, and related transactions.',
            ],
            [
                'name' => 'City Agriculturist Office',
                'code' => 'CAO',
                'description' => 'Handles agriculture programs, farmer support, and related city concerns.',
            ],
            [
                'name' => "City Assessor's Office",
                'code' => 'CASSO',
                'description' => 'Handles property assessment services and assessment-related concerns.',
            ],
            [
                'name' => "City Civil Registrar's Office",
                'code' => 'CCRO',
                'description' => 'Handles civil registry records, certificates, and related citizen services.',
            ],
            [
                'name' => 'City Disaster Risk Reduction and Management Office',
                'code' => 'CDRRMO',
                'description' => 'Handles disaster preparedness, response coordination, and emergency concerns.',
            ],
            [
                'name' => "City Engineer's Office",
                'code' => 'CEO',
                'description' => 'Handles roads, drainage, public works, and engineering-related concerns.',
            ],
            [
                'name' => 'City Health Office',
                'code' => 'CHO',
                'description' => 'Handles public health concerns, sanitation, and medical service coordination.',
            ],
            [
                'name' => "City Mayor's Office",
                'code' => 'CMO',
                'description' => 'Handles executive city concerns, directives, and mayoral services.',
            ],
            [
                'name' => 'City Social Welfare and Development Office',
                'code' => 'CSWDO',
                'description' => 'Handles social welfare services, family assistance, and social protection concerns.',
            ],
            [
                'name' => 'City Tourism Operations Office',
                'code' => 'CTOO',
                'description' => 'Handles tourism promotions, visitor support, and tourism facility concerns.',
            ],
            [
                'name' => "City Treasurer's Office",
                'code' => 'CTO',
                'description' => 'Handles city treasury services, collections, and payment concerns.',
            ],
            [
                'name' => 'Land Transportation Office',
                'code' => 'LTO',
                'description' => 'Handles land transportation regulation and licensing concerns.',
            ],
            [
                'name' => 'TOMECO (Traffic Operation)',
                'code' => 'TOMECO',
                'description' => 'Handles traffic enforcement, road flow, and transport management issues.',
            ],
        ];

        foreach ($offices as $office) {
            Office::updateOrCreate(
                ['code' => $office['code']],
                [
                    'name' => $office['name'],
                    'code' => $office['code'],
                    'description' => $office['description'],
                    'is_active' => true,
                ]
            );
        }

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

    }
}
