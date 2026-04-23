<?php

namespace Database\Seeders;

use App\Models\Category;
use App\Models\CitizenFeedback;
use App\Models\Office;
use App\Models\Report;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;

class DemoVolumeSeeder extends Seeder
{
    private const ADMIN_PASSWORD = 'AdminDemo123';
    private const CITIZEN_PASSWORD = 'CitizenDemo123';
    private const REPORT_DETAILS = [
        'Business Permit Application' => [
            'title' => 'Follow up on delayed business permit application',
            'description' => 'I submitted the business permit requirements last week, but I have not received a clear update on the next step. Please help check the application status.',
        ],
        'Business Permit Renewal' => [
            'title' => 'Business permit renewal queue is taking too long',
            'description' => 'The renewal process has been pending for several days even after the documents were completed. I need assistance so the business can continue operating properly.',
        ],
        'Licensing Concern' => [
            'title' => 'Need clarification on licensing requirements',
            'description' => 'The requirements given at the counter were different from the checklist online. Please confirm the correct documents needed for this license.',
        ],
        'Business Inspection' => [
            'title' => 'Request for business inspection schedule update',
            'description' => 'Our business inspection has not yet been scheduled. Please provide an update because this is needed for our permit processing.',
        ],
        'Permit Release Delay' => [
            'title' => 'Permit release date has passed with no notice',
            'description' => 'The expected release date for the permit already passed, but no notice was sent. Please help verify when it can be released.',
        ],
        'Agriculture Assistance' => [
            'title' => 'Request for agriculture assistance follow up',
            'description' => 'Farmers in our area are requesting support for seeds and basic supplies. Please advise when assistance can be provided.',
        ],
        'Farmer Support' => [
            'title' => 'Farmer support request for damaged crops',
            'description' => 'Several crops were damaged after heavy rain. We are requesting an assessment and guidance from the agriculture office.',
        ],
        'Crop Damage' => [
            'title' => 'Crop damage needs field validation',
            'description' => 'The recent weather caused visible crop damage in our sitio. Please send personnel to validate the affected area.',
        ],
        'Livestock Concern' => [
            'title' => 'Livestock health concern reported by residents',
            'description' => 'Some livestock in the area appear sick and residents are worried it may spread. Please coordinate a checkup or advisory.',
        ],
        'Urban Gardening' => [
            'title' => 'Urban gardening supplies requested',
            'description' => 'Our neighborhood group would like to request seedlings and technical advice for a small urban gardening project.',
        ],
        'Property Assessment' => [
            'title' => 'Property assessment record needs review',
            'description' => 'The property assessment details appear outdated compared with the current property condition. Please review the record.',
        ],
        'Tax Declaration' => [
            'title' => 'Tax declaration correction request',
            'description' => 'There is a spelling error in the tax declaration record. Please help correct the document before we use it for processing.',
        ],
        'Real Property Record' => [
            'title' => 'Real property record copy request delayed',
            'description' => 'I requested a copy of a real property record, but it has not been released. Please check the status of the request.',
        ],
        'Assessment Correction' => [
            'title' => 'Assessment correction needs verification',
            'description' => 'The assessed classification seems incorrect. Please verify the record and advise what documents are needed.',
        ],
        'Property Valuation' => [
            'title' => 'Property valuation inquiry for residential lot',
            'description' => 'I need assistance understanding the latest valuation for a residential lot in our barangay.',
        ],
        'Birth Certificate' => [
            'title' => 'Birth certificate request has incorrect details',
            'description' => 'The released birth certificate has a detail that does not match the supporting record. Please help verify the correction process.',
        ],
        'Marriage Certificate' => [
            'title' => 'Marriage certificate copy follow up',
            'description' => 'I requested a copy of a marriage certificate and would like to follow up because it is needed for a pending transaction.',
        ],
        'Death Certificate' => [
            'title' => 'Death certificate registration follow up',
            'description' => 'The family needs help confirming whether the death certificate registration has been completed.',
        ],
        'Civil Registry Correction' => [
            'title' => 'Civil registry correction guidance needed',
            'description' => 'There is an incorrect spelling in a civil registry document. Please advise the proper correction steps and requirements.',
        ],
        'Delayed Registration' => [
            'title' => 'Delayed registration requirements clarification',
            'description' => 'We need clarification on the requirements for delayed registration because the family documents are incomplete.',
        ],
        'Emergency Response' => [
            'title' => 'Emergency response request for unsafe area',
            'description' => 'Residents noticed an unsafe area after recent rainfall. Please inspect and advise if emergency action is needed.',
        ],
        'Flooding' => [
            'title' => 'Floodwater enters homes during heavy rain',
            'description' => 'Floodwater reaches several homes whenever it rains hard. Please assess the area and coordinate mitigation support.',
        ],
        'Disaster Preparedness' => [
            'title' => 'Request for disaster preparedness orientation',
            'description' => 'Our barangay group would like to request an orientation on evacuation planning and emergency preparedness.',
        ],
        'Hazard Report' => [
            'title' => 'Reported hazard near residential area',
            'description' => 'There is a visible hazard near the roadside that may affect pedestrians and nearby households. Please inspect it.',
        ],
        'Rescue Assistance' => [
            'title' => 'Rescue assistance concern after heavy rain',
            'description' => 'Residents are requesting clearer rescue coordination because some areas become difficult to access during heavy rain.',
        ],
        'Road Damage' => [
            'title' => 'Potholes causing unsafe travel',
            'description' => 'Several potholes along the road are causing vehicles to slow down suddenly and may lead to accidents. Please schedule repairs.',
        ],
        'Drainage' => [
            'title' => 'Clogged drainage causing stagnant water',
            'description' => 'The drainage canal is clogged and stagnant water has started to collect near nearby houses. Please clear the canal.',
        ],
        'Street Light' => [
            'title' => 'Street light not working at night',
            'description' => 'A street light in the area has not been working for several nights, making the road unsafe for pedestrians.',
        ],
        'Sidewalk' => [
            'title' => 'Damaged sidewalk needs repair',
            'description' => 'The sidewalk has broken sections that make walking difficult, especially for seniors and children.',
        ],
        'Public Works' => [
            'title' => 'Public facility repair request',
            'description' => 'A public facility in the area needs minor repair and maintenance. Please inspect and schedule the needed work.',
        ],
        'Public Health' => [
            'title' => 'Public health concern in neighborhood',
            'description' => 'Residents are concerned about a possible health risk in the area. Please inspect and provide guidance.',
        ],
        'Sanitation' => [
            'title' => 'Sanitation issue near residential block',
            'description' => 'There is a sanitation concern near several houses that may attract pests. Please coordinate inspection and cleanup.',
        ],
        'Medical Assistance' => [
            'title' => 'Medical assistance inquiry for resident',
            'description' => 'A resident needs guidance on how to request medical assistance from the city health office.',
        ],
        'Health Center Concern' => [
            'title' => 'Health center service schedule concern',
            'description' => 'Residents need clearer information about the health center service schedule and available consultation hours.',
        ],
        'Disease Prevention' => [
            'title' => 'Request for disease prevention advisory',
            'description' => 'Our area needs a disease prevention advisory because residents have reported similar symptoms recently.',
        ],
        'Executive Assistance' => [
            'title' => 'Request for executive assistance follow up',
            'description' => 'I submitted a request for city assistance and would like to know which office will handle the next step.',
        ],
        'Public Service Request' => [
            'title' => 'Public service request needs assignment',
            'description' => 'This public service concern has not yet been assigned to a specific office. Please help route it properly.',
        ],
        'City Program Concern' => [
            'title' => 'City program participation concern',
            'description' => 'Residents are asking for clarification about participation requirements for a city program.',
        ],
        'Administrative Complaint' => [
            'title' => 'Administrative complaint for follow up',
            'description' => 'I would like to report a concern about how a public transaction was handled and request proper follow up.',
        ],
        'General City Concern' => [
            'title' => 'General city concern for routing',
            'description' => 'This concern affects residents in the area and needs help from the appropriate city office.',
        ],
        'Social Assistance' => [
            'title' => 'Social assistance application follow up',
            'description' => 'A resident submitted documents for social assistance and needs an update on the application status.',
        ],
        'Family Welfare' => [
            'title' => 'Family welfare support request',
            'description' => 'A family in the area needs guidance on available welfare programs and requirements.',
        ],
        'Senior Citizen Assistance' => [
            'title' => 'Senior citizen assistance concern',
            'description' => 'A senior citizen needs help with assistance processing and document verification.',
        ],
        'PWD Assistance' => [
            'title' => 'PWD assistance requirements inquiry',
            'description' => 'We need clarification about the requirements for PWD assistance and available city support.',
        ],
        'Child Welfare' => [
            'title' => 'Child welfare concern for assessment',
            'description' => 'A child welfare concern was reported by neighbors and may need assessment from the proper office.',
        ],
        'Tourism Facility' => [
            'title' => 'Tourism facility maintenance concern',
            'description' => 'A tourism facility needs maintenance because visitors have reported damaged fixtures in the area.',
        ],
        'Visitor Assistance' => [
            'title' => 'Visitor assistance information request',
            'description' => 'Visitors need clearer directions and assistance information for a city destination.',
        ],
        'Tourism Event' => [
            'title' => 'Tourism event coordination request',
            'description' => 'Our group needs coordination guidance for a tourism-related event in the city.',
        ],
        'Heritage Site Concern' => [
            'title' => 'Heritage site area needs inspection',
            'description' => 'A heritage site area has visible maintenance concerns that may affect visitors.',
        ],
        'Promotion Request' => [
            'title' => 'Request for tourism promotion support',
            'description' => 'A local group would like to ask about possible support for promoting a community tourism activity.',
        ],
        'Payment Concern' => [
            'title' => 'Payment posting concern',
            'description' => 'A payment was made but does not appear to be posted yet. Please verify the transaction record.',
        ],
        'Receipt Concern' => [
            'title' => 'Receipt details need verification',
            'description' => 'The receipt details appear incomplete. Please help verify the correct payment information.',
        ],
        'Business Tax' => [
            'title' => 'Business tax computation inquiry',
            'description' => 'I need clarification about the business tax computation before completing payment.',
        ],
        'Real Property Tax' => [
            'title' => 'Real property tax payment concern',
            'description' => 'There is a concern about real property tax payment status. Please check the record.',
        ],
        'Collection Issue' => [
            'title' => 'Collection record needs review',
            'description' => 'The collection record may not match the payment made. Please review and advise.',
        ],
        'Driver Licensing' => [
            'title' => 'Driver licensing schedule concern',
            'description' => 'Applicants need clearer information about driver licensing schedules and requirements.',
        ],
        'Vehicle Registration' => [
            'title' => 'Vehicle registration follow up',
            'description' => 'The vehicle registration process has been delayed and needs status verification.',
        ],
        'Road Safety' => [
            'title' => 'Road safety concern near crossing',
            'description' => 'Pedestrians are having difficulty crossing safely in this area. Please assess road safety measures.',
        ],
        'Transport Regulation' => [
            'title' => 'Transport regulation concern reported',
            'description' => 'Residents reported a transport regulation concern that needs checking by the proper office.',
        ],
        'Traffic Violation Concern' => [
            'title' => 'Traffic violation concern needs action',
            'description' => 'Repeated traffic violations are happening in the area and residents are requesting enforcement.',
        ],
        'Traffic Congestion' => [
            'title' => 'Traffic congestion during peak hours',
            'description' => 'Traffic becomes heavy during morning and afternoon peak hours. Please review possible traffic management measures.',
        ],
        'Illegal Parking' => [
            'title' => 'Illegal parking blocking the road',
            'description' => 'Vehicles are often parked illegally and block the flow of traffic. Please conduct enforcement.',
        ],
        'Traffic Signal' => [
            'title' => 'Traffic signal timing concern',
            'description' => 'The traffic signal timing causes long queues and unsafe crossing behavior. Please inspect the signal timing.',
        ],
        'Traffic Enforcement' => [
            'title' => 'Traffic enforcement request near school',
            'description' => 'Traffic enforcement is needed near the school during dismissal time to keep students safe.',
        ],
        'Road Obstruction' => [
            'title' => 'Road obstruction affecting vehicles',
            'description' => 'An obstruction is affecting vehicle flow and may cause accidents. Please clear or coordinate removal.',
        ],
    ];
    private const FEEDBACK_MESSAGES = [
        'Suggestion' => [
            'Please add clearer status updates so citizens know when the next action will happen.',
            'It would help if the department sends a short message after assigning the report to staff.',
            'The process is useful, but citizens would benefit from more specific estimated completion dates.',
        ],
        'Complaint' => [
            'The response took longer than expected and I had to follow up several times.',
            'The report was received, but the update was not detailed enough for residents waiting for action.',
            'The issue still needs closer checking because the problem returned after the first action.',
        ],
        'Praise' => [
            'The staff handled the concern professionally and gave a clear update.',
            'Thank you for responding to the report and coordinating with the barangay.',
            'The department was helpful and the report status was updated properly.',
        ],
    ];
    private const ADMIN_NAMES = [
        'Juan Dela Cruz',
        'Maria Santos',
        'Carlos Reyes',
        'Ana Mae Garcia',
        'Jose Villanueva',
        'Lourdes Del Rosario',
        'Miguel Cruz',
        'Patricia Mendoza',
        'Ramon De Leon',
        'Angela Navarro',
        'Roberto Tan',
        'Marites Flores',
        'Gabriel Aquino',
        'Elena Bautista',
        'Francis Lim',
        'Catherine Yu',
        'Paolo Gonzales',
        'Rosa Dela Pena',
        'Mark Anthony Ramos',
        'Janine Mercado',
        'Daniel Castillo',
        'Sofia Alcantara',
        'Edwin Salvador',
        'Grace Manalo',
        'Anthony Velasco',
    ];
    private const CITIZEN_NAMES = [
        'Vanessa Delgado',
        'Jericson Cupan',
        'Jannena Gayas',
        'Lito Fernandez',
        'Kristine Dela Cruz',
        'Arnel Soriano',
        'Michelle Lopez',
        'Noel Valdez',
        'Rhea Dizon',
        'Dennis De Guzman',
        'Camille Ortega',
        'Victor Salazar',
        'Joanna Robles',
        'Nestor Villamor',
        'Clarissa Domingo',
        'Eric Bautista',
        'Melanie Ramos',
        'Jun Marquez',
        'Aileen Francisco',
        'Rommel Reyes',
        'Leah Gonzales',
        'Patrick Medina',
        'Irene Santos',
        'Bryan Aguilar',
        'Mylene Torres',
        'Richard Aquino',
        'Hazel Navarro',
        'Gerald Castillo',
        'Diana Mendoza',
        'Ronald Flores',
        'Marielyn Abad',
        'Christian Balagtas',
        'Jessa Mae Caballero',
        'Allan Dela Pena',
        'Rochelle Enriquez',
        'Julius Ferrer',
        'Angelica Guevarra',
        'Mark Joseph Hilario',
        'Karen Ibanez',
        'Joshua Javier',
        'Marites Labadan',
        'Francis Mallari',
        'Elaine Natividad',
        'Rodel Ocampo',
        'Czarina Paloma',
        'Edgar Quinones',
        'Princess Rivera',
        'Michael Soriano',
        'Theresa Tolentino',
        'Renato Uy',
    ];
    private const OFFICE_ISSUE_TYPES = [
        'Business Permit and Licensing Division' => [
            'Business Permit Application',
            'Business Permit Renewal',
            'Licensing Concern',
            'Business Inspection',
            'Permit Release Delay',
        ],
        'City Agriculturist Office' => [
            'Agriculture Assistance',
            'Farmer Support',
            'Crop Damage',
            'Livestock Concern',
            'Urban Gardening',
        ],
        "City Assessor's Office" => [
            'Property Assessment',
            'Tax Declaration',
            'Real Property Record',
            'Assessment Correction',
            'Property Valuation',
        ],
        "City Civil Registrar's Office" => [
            'Birth Certificate',
            'Marriage Certificate',
            'Death Certificate',
            'Civil Registry Correction',
            'Delayed Registration',
        ],
        'City Disaster Risk Reduction and Management Office' => [
            'Emergency Response',
            'Flooding',
            'Disaster Preparedness',
            'Hazard Report',
            'Rescue Assistance',
        ],
        "City Engineer's Office" => [
            'Road Damage',
            'Drainage',
            'Street Light',
            'Sidewalk',
            'Public Works',
        ],
        'City Health Office' => [
            'Public Health',
            'Sanitation',
            'Medical Assistance',
            'Health Center Concern',
            'Disease Prevention',
        ],
        "City Mayor's Office" => [
            'Executive Assistance',
            'Public Service Request',
            'City Program Concern',
            'Administrative Complaint',
            'General City Concern',
        ],
        'City Social Welfare and Development Office' => [
            'Social Assistance',
            'Family Welfare',
            'Senior Citizen Assistance',
            'PWD Assistance',
            'Child Welfare',
        ],
        'City Tourism Operations Office' => [
            'Tourism Facility',
            'Visitor Assistance',
            'Tourism Event',
            'Heritage Site Concern',
            'Promotion Request',
        ],
        "City Treasurer's Office" => [
            'Payment Concern',
            'Receipt Concern',
            'Business Tax',
            'Real Property Tax',
            'Collection Issue',
        ],
        'Land Transportation Office' => [
            'Driver Licensing',
            'Vehicle Registration',
            'Road Safety',
            'Transport Regulation',
            'Traffic Violation Concern',
        ],
        'TOMECO (Traffic Operation)' => [
            'Traffic Congestion',
            'Illegal Parking',
            'Traffic Signal',
            'Traffic Enforcement',
            'Road Obstruction',
        ],
    ];

    public function run(): void
    {
        $adminCount = (int) env('DEMO_ADMIN_COUNT', 20);
        $citizenCount = (int) env('DEMO_CITIZEN_COUNT', 50);
        $reportCount = (int) env('DEMO_REPORT_COUNT', 300);
        $feedbackCount = (int) env('DEMO_FEEDBACK_COUNT', 300);

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
        $reports = $this->seedReports($reportCount, $offices, $categories, $admins, $citizens);
        $this->seedFeedback($feedbackCount, $reports);

        $this->command?->info(
            "Demo data ready: {$adminCount} admins, {$citizenCount} citizens, {$reportCount} reports, {$feedbackCount} feedback entries."
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
                    'name' => $this->personName(self::ADMIN_NAMES, $index),
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
                    'name' => $this->personName(self::CITIZEN_NAMES, $index),
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

    private function seedReports(int $count, $offices, $categories, $admins, $citizens)
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
        $citizenCount = max(1, $citizens->count());
        $reports = collect();

        for ($index = 1; $index <= $count; $index++) {
            $office = $offices[($index - 1) % $officeCount];
            $category = $this->categoryForOffice($office->name, $index, $categories);
            $citizen = $citizens[($index - 1) % $citizenCount];
            $departmentAdmins = $admins
                ->where('department', $office->name)
                ->values();
            $assignee = $departmentAdmins->isEmpty()
                ? null
                : $departmentAdmins[($index - 1) % $departmentAdmins->count()];
            $status = $statuses[($index - 1) % count($statuses)];
            $createdAt = Carbon::now()->subDays($index % 45)->subMinutes($index * 3);
            $legacyTitle = sprintf('Demo Report %03d - %s', $index, $office->code ?? $office->id);
            $reportTitle = $this->reportTitle($category->name, $barangays[($index - 1) % count($barangays)], $index);
            $reportDescription = $this->reportDescription($category->name, $office->name, $index);

            $report = Report::query()
                ->where('title', $legacyTitle)
                ->orWhere('title', $reportTitle)
                ->first();

            if (! $report) {
                $report = new Report();
            }

            $report->fill([
                'user_id' => $citizen->id,
                'category_id' => $category->id,
                'office_id' => $office->id,
                'title' => $reportTitle,
                'description' => $reportDescription,
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
            ]);
            $report->created_at = $createdAt;
            $report->updated_at = $status === 'Resolved'
                ? $createdAt->copy()->addDays(2)
                : $createdAt->copy()->addHours($index % 72);
            $report->save();
            $reports->push($report);
        }

        return $reports;
    }

    private function seedFeedback(int $count, $reports): void
    {
        if ($reports->isEmpty()) {
            return;
        }

        $types = ['Praise', 'Suggestion', 'Complaint'];
        $reportCount = max(1, $reports->count());

        for ($index = 1; $index <= $count; $index++) {
            $report = $reports[($index - 1) % $reportCount]->fresh(['user', 'office', 'category']);

            if (! $report || ! $report->user_id || ! $report->office_id) {
                continue;
            }

            $type = $types[($index - 1) % count($types)];
            $rating = match ($type) {
                'Praise' => 5,
                'Suggestion' => 4,
                default => 2 + ($index % 2),
            };
            $createdAt = Carbon::parse($report->updated_at ?? $report->created_at)
                ->addHours(($index % 48) + 1);

            $feedback = CitizenFeedback::query()->firstOrNew([
                'user_id' => $report->user_id,
                'report_id' => $report->id,
                'type' => $type,
            ]);
            $feedback->fill([
                'office_id' => $report->office_id,
                'message' => $this->feedbackMessage($type, $report, $index),
                'rating' => $rating,
            ]);
            $feedback->created_at = $createdAt;
            $feedback->updated_at = $createdAt;
            $feedback->save();
        }
    }

    private function reportTitle(string $categoryName, string $barangay, int $index): string
    {
        $details = self::REPORT_DETAILS[$categoryName] ?? null;
        $baseTitle = $details['title'] ?? $categoryName . ' concern for city action';

        return $baseTitle . ' - ' . $barangay . ' #' . str_pad((string) $index, 3, '0', STR_PAD_LEFT);
    }

    private function reportDescription(string $categoryName, string $officeName, int $index): string
    {
        $details = self::REPORT_DETAILS[$categoryName] ?? null;
        $description = $details['description'] ?? 'A resident submitted this concern and is requesting proper action from the assigned city office.';

        return $description . ' This report is assigned to ' . $officeName . ' for validation and follow up. Reference no. ' . str_pad((string) $index, 3, '0', STR_PAD_LEFT) . '.';
    }

    private function feedbackMessage(string $type, Report $report, int $index): string
    {
        $messages = self::FEEDBACK_MESSAGES[$type] ?? self::FEEDBACK_MESSAGES['Suggestion'];
        $message = $messages[($index - 1) % count($messages)];
        $officeName = $report->office?->name ?? 'the assigned department';
        $reportTitle = $report->title ?: 'the submitted report';

        return $message . ' Related report: "' . $reportTitle . '" handled by ' . $officeName . '.';
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

    private function categoryForOffice(string $officeName, int $index, $fallbackCategories): Category
    {
        $issueTypes = self::OFFICE_ISSUE_TYPES[$officeName] ?? [];

        if ($issueTypes === []) {
            $categoryCount = max(1, $fallbackCategories->count());

            return $fallbackCategories[($index - 1) % $categoryCount];
        }

        $name = $issueTypes[($index - 1) % count($issueTypes)];

        return Category::query()->firstOrCreate(
            ['name' => $name],
            ['description' => $name . ' reports for ' . $officeName]
        );
    }

    private function personName(array $names, int $index): string
    {
        if ($names === []) {
            return 'Juan Dela Cruz';
        }

        return $names[($index - 1) % count($names)];
    }
}
