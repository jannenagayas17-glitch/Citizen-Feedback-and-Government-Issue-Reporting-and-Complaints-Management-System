<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

class DemoVolumeSeeder extends Seeder
{
    private const ADMIN_PASSWORD = 'AdminDemo123';
    private const CITIZEN_PASSWORD = 'CitizenDemo123';

    public function run(): void
    {
        $adminCount = (int) env('DEMO_ADMIN_COUNT', 20);
        $citizenCount = (int) env('DEMO_CITIZEN_COUNT', 30);
        $reportCount = (int) env('DEMO_REPORT_COUNT', 300);

        $offices = Office::query()
            ->where('is_active', true)
            ->orderBy('name')
            ->get();

        if ($offices->isEmpty()) {
            $this->call(DatabaseSeeder::class);
            $offices = Office::query()
                ->where('is_active', true)
                ->orderBy('name')
                ->get();
        }

        $categories = Category::query()->orderBy('name')->get();

        if ($categories->isEmpty()) {
            $this->call(DatabaseSeeder::class);
            $categories = Category::query()->orderBy('name')->get();
        }

        $admins = $this->seedAdmins($adminCount, $offices);
        $citizens = $this->seedCitizens($citizenCount);
        $this->seedReports($reportCount, $offices, $categories, $admins, $citizens);

        $this->command?->info(
            "Demo data ready: {$adminCount} admins, {$citizenCount} citizens, {$reportCount} reports."
        );
        $this->command?->info(
            'Passwords: admins use ' . self::ADMIN_PASSWORD . ', citizens use ' . self::CITIZEN_PASSWORD . '.'
        );
    }

    private function seedAdmins(int $count, $offices)
    {
        $admins = collect();
        $officeCount = max(1, $offices->count());

        for ($index = 1; $index <= $count; $index++) {
            $office = $offices[($index - 1) % $officeCount];
            $isDepartmentHead = (($index - 1) % $officeCount) === 0;
            $email = sprintf('demo.admin.%03d@citytrack.test', $index);

            $admin = User::withTrashed()->updateOrCreate(
                ['email' => $email],
                [
                    'name' => sprintf('Demo Admin %03d', $index),
                    'mobile_number' => sprintf('0918%07d', $index),
                    'password' => self::ADMIN_PASSWORD,
                    'role' => 'admin',
                    'department' => $office->name,
                    'job_title' => $isDepartmentHead
                        ? 'Department Head'
                        : $this->jobTitleFor($index),
                    'is_active' => true,
                ]
            );

            if ($admin->trashed()) {
                $admin->restore();
            }

            $admins->push($admin);
        }

        return $admins;
    }

    private function seedCitizens(int $count)
    {
        $citizens = collect();

        for ($index = 1; $index <= $count; $index++) {
            $email = sprintf('demo.citizen.%03d@example.com', $index);

            $citizen = User::withTrashed()->updateOrCreate(
                ['email' => $email],
                [
                    'name' => sprintf('Demo Citizen %03d', $index),
                    'mobile_number' => sprintf('0927%07d', $index),
                    'password' => self::CITIZEN_PASSWORD,
                    'role' => 'citizen',
                    'department' => null,
                    'job_title' => null,
                    'is_active' => true,
                ]
            );

            if ($citizen->trashed()) {
                $citizen->restore();
            }

            $citizens->push($citizen);
        }

        return $citizens;
    }

    private function seedReports(int $count, $offices, $categories, $admins, $citizens): void
    {
        $barangays = [
            'Barangay 1 (Libertad)',
            'Barangay 12 (GE Palanog)',
            'Barangay 36 (Sabang)',
            'Barangay 49 (Youngfield)',
            'Barangay 60-A (Sagkahan)',
            'Barangay 78 (Marasbaras)',
            'Barangay 83-C (San Jose)',
            'Barangay 91 (Abucay)',
            'Barangay 95-A (Caibaan)',
            'Barangay 109 (V&G Subdivision)',
        ];
        $statuses = ['New', 'Pending', 'In Progress', 'Resolved', 'Rejected'];
        $priorities = ['Low', 'Normal', 'High', 'Urgent'];
        $officeCount = max(1, $offices->count());
        $categoryCount = max(1, $categories->count());
        $citizenCount = max(1, $citizens->count());

        for ($index = 1; $index <= $count; $index++) {
            $office = $offices[($index - 1) % $officeCount];
            $category = $categories[($index - 1) % $categoryCount];
            $citizen = $citizens[($index - 1) % $citizenCount];
            $departmentAdmins = $admins
                ->where('department', $office->name)
                ->values();
            $assignee = $departmentAdmins->isEmpty()
                ? null
                : $departmentAdmins[($index - 1) % $departmentAdmins->count()];
            $status = $statuses[($index - 1) % count($statuses)];
            $createdAt = Carbon::now()->subDays($index % 45)->subMinutes($index * 3);

            Report::query()->updateOrCreate(
                ['title' => sprintf('Demo Report %03d - %s', $index, $office->code ?? $office->id)],
                [
                    'user_id' => $citizen->id,
                    'category_id' => $category->id,
                    'office_id' => $office->id,
                    'description' => sprintf(
                        'Demo complaint %03d for %s. This record is seeded for testing dashboards, filters, and department-scoped report queues.',
                        $index,
                        $office->name
                    ),
                    'location' => $barangays[($index - 1) % count($barangays)] . ', Tacloban City',
                    'barangay' => $barangays[($index - 1) % count($barangays)],
                    'latitude' => 11.2400 + (($index % 70) / 10000),
                    'longitude' => 125.0000 + (($index % 90) / 10000),
                    'status' => $status,
                    'priority' => $priorities[($index - 1) % count($priorities)],
                    'assigned_to' => in_array($status, ['In Progress', 'Resolved'], true)
                        ? $assignee?->id
                        : null,
                    'resolved_at' => $status === 'Resolved'
                        ? $createdAt->copy()->addDays(2)
                        : null,
                    'created_at' => $createdAt,
                    'updated_at' => $status === 'Resolved'
                        ? $createdAt->copy()->addDays(2)
                        : $createdAt->copy()->addHours($index % 72),
                ]
            );
        }
    }

    private function jobTitleFor(int $index): string
    {
        return match ($index % 4) {
            0 => 'Field Engineer',
            1 => 'Administrator',
            2 => 'Maintenance Crew',
            default => 'Department Staff',
        };
    }
}
