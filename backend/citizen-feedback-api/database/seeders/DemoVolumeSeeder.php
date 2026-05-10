<?php

namespace Database\Seeders;

use App\Models\AdminResponse;
use App\Models\Category;
use App\Models\CitizenFeedback;
use App\Models\Office;
use App\Models\Report;
use App\Models\ReportEscalation;
use App\Models\ReportImage;
use App\Models\StatusHistory;
use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

class DemoVolumeSeeder extends Seeder
{
    private const ADMIN_PASSWORD = 'AdminDemo123';

    private const CITIZEN_PASSWORD = 'CitizenDemo123';

    private const DEMO_START = [2024, 1, 1];

    private const DEMO_END = [2025, 12, 20];

    private const FIRST_NAMES = [
        'Vanessa', 'Jericson', 'Jannena', 'Lito', 'Kristine', 'Arnel',
        'Michelle', 'Noel', 'Rhea', 'Dennis', 'Camille', 'Victor',
        'Joanna', 'Nestor', 'Clarissa', 'Eric', 'Melanie', 'Jun',
        'Aileen', 'Rommel', 'Leah', 'Patrick', 'Irene', 'Bryan',
        'Mylene', 'Richard', 'Hazel', 'Gerald', 'Diana', 'Ronald',
        'Marielyn', 'Christian', 'Jessa Mae', 'Allan', 'Rochelle',
        'Julius', 'Angelica', 'Mark Joseph', 'Karen', 'Joshua',
        'Marites', 'Francis', 'Elaine', 'Rodel', 'Czarina',
        'Edgar', 'Princess', 'Michael', 'Theresa', 'Renato',
    ];

    private const LAST_NAMES = [
        'Delgado', 'Cupan', 'Gayas', 'Fernandez', 'Dela Cruz', 'Soriano',
        'Lopez', 'Valdez', 'Dizon', 'De Guzman', 'Ortega', 'Salazar',
        'Robles', 'Villamor', 'Domingo', 'Bautista', 'Ramos', 'Marquez',
        'Francisco', 'Reyes', 'Gonzales', 'Medina', 'Santos', 'Aguilar',
        'Torres', 'Aquino', 'Navarro', 'Castillo', 'Mendoza', 'Flores',
        'Abad', 'Balagtas', 'Caballero', 'De la Pena', 'Enriquez',
        'Ferrer', 'Guevarra', 'Hilario', 'Ibanez', 'Javier',
        'Labadan', 'Mallari', 'Natividad', 'Ocampo', 'Paloma',
        'Quinones', 'Rivera', 'Tolentino', 'Uy', 'Mercado',
    ];

    private const BARANGAY_PROFILES = [
        [
            'barangay' => 'Barangay 1 (Libertad)',
            'latitude' => 11.2431,
            'longitude' => 125.0004,
            'spots' => [
                'near Libertad Public Market',
                'beside the barangay hall',
                'along Justice Romualdez Street',
            ],
        ],
        [
            'barangay' => 'Barangay 5',
            'latitude' => 11.2462,
            'longitude' => 125.0015,
            'spots' => [
                'near the elementary school gate',
                'at the tricycle terminal',
                'beside the covered court',
            ],
        ],
        [
            'barangay' => 'Barangay 12 (GE Palanog)',
            'latitude' => 11.2458,
            'longitude' => 125.0033,
            'spots' => [
                'along the drainage canal',
                'near the sari-sari store row',
                'close to the day care center',
            ],
        ],
        [
            'barangay' => 'Barangay 24',
            'latitude' => 11.2505,
            'longitude' => 125.0074,
            'spots' => [
                'beside the chapel entrance',
                'near the public waiting shed',
                'in front of the rice mill access road',
            ],
        ],
        [
            'barangay' => 'Barangay 36 (Sabang)',
            'latitude' => 11.2511,
            'longitude' => 125.0128,
            'spots' => [
                'near the coastal access road',
                'at the fish landing area',
                'beside the sea wall section',
            ],
        ],
        [
            'barangay' => 'Barangay 49 (Youngfield)',
            'latitude' => 11.2584,
            'longitude' => 125.0155,
            'spots' => [
                'near the subdivision gate',
                'along the inner service road',
                'in front of the basketball court',
            ],
        ],
        [
            'barangay' => 'Barangay 60-A (Sagkahan)',
            'latitude' => 11.2489,
            'longitude' => 125.0191,
            'spots' => [
                'near the creek crossing',
                'beside the barangay health station',
                'at the intersection leading to the highway',
            ],
        ],
        [
            'barangay' => 'Barangay 62',
            'latitude' => 11.2493,
            'longitude' => 125.0227,
            'spots' => [
                'behind the transport terminal',
                'near the unloading bay',
                'beside the roadside drainage opening',
            ],
        ],
        [
            'barangay' => 'Barangay 68',
            'latitude' => 11.2554,
            'longitude' => 125.0278,
            'spots' => [
                'near the barangay multipurpose hall',
                'along the uphill stretch',
                'by the side street near the waiting shed',
            ],
        ],
        [
            'barangay' => 'Barangay 78 (Marasbaras)',
            'latitude' => 11.2598,
            'longitude' => 125.0316,
            'spots' => [
                'near the hospital access road',
                'at the subdivision corner',
                'beside the drainage outfall',
            ],
        ],
        [
            'barangay' => 'Barangay 83-C (San Jose)',
            'latitude' => 11.2635,
            'longitude' => 125.0382,
            'spots' => [
                'near the airport road shoulder',
                'in front of the terminal entrance',
                'beside the pedestrian crossing',
            ],
        ],
        [
            'barangay' => 'Barangay 88',
            'latitude' => 11.2661,
            'longitude' => 125.0414,
            'spots' => [
                'near the roadside canal',
                'at the inner neighborhood curve',
                'beside the loading zone',
            ],
        ],
        [
            'barangay' => 'Barangay 91 (Abucay)',
            'latitude' => 11.2704,
            'longitude' => 125.0482,
            'spots' => [
                'near the river embankment',
                'by the evacuation route',
                'at the low-lying section of the road',
            ],
        ],
        [
            'barangay' => 'Barangay 95-A (Caibaan)',
            'latitude' => 11.2736,
            'longitude' => 125.0534,
            'spots' => [
                'beside the public market service road',
                'near the jeepney stop',
                'in front of the barangay hall driveway',
            ],
        ],
        [
            'barangay' => 'Barangay 97-C',
            'latitude' => 11.2758,
            'longitude' => 125.0573,
            'spots' => [
                'at the entrance to the residential block',
                'near the drainage catch basin',
                'beside the roadside food stalls',
            ],
        ],
        [
            'barangay' => 'Barangay 102',
            'latitude' => 11.2794,
            'longitude' => 125.0621,
            'spots' => [
                'near the school fence line',
                'along the inner barangay road',
                'beside the community pump house',
            ],
        ],
        [
            'barangay' => 'Barangay 105',
            'latitude' => 11.2817,
            'longitude' => 125.0675,
            'spots' => [
                'near the newly paved road section',
                'by the culvert inlet',
                'in front of the chapel annex',
            ],
        ],
        [
            'barangay' => 'Barangay 109 (V&G Subdivision)',
            'latitude' => 11.2848,
            'longitude' => 125.0711,
            'spots' => [
                'near the subdivision rotunda',
                'along the commercial strip',
                'beside the park frontage',
            ],
        ],
        [
            'barangay' => 'Barangay 110',
            'latitude' => 11.2866,
            'longitude' => 125.0749,
            'spots' => [
                'near the village guardhouse',
                'at the back road service lane',
                'beside the drainage line behind the court',
            ],
        ],
        [
            'barangay' => 'Barangay 112',
            'latitude' => 11.2889,
            'longitude' => 125.0793,
            'spots' => [
                'near the transport dispatch area',
                'along the connector road to the highway',
                'at the roadside near the footbridge',
            ],
        ],
    ];

    private const ISSUE_PROFILES = [
        [
            'category' => 'Road Damage',
            'offices' => ["City Engineer's Office"],
            'priority_pool' => ['Normal', 'High', 'High', 'Urgent'],
            'video_friendly' => true,
            'title_templates' => [
                'Deep potholes reported %s',
                'Broken pavement needs repair %s',
                'Uneven road surface is damaging vehicles %s',
            ],
            'description_templates' => [
                'Residents reported widening potholes %s. %s %s',
                'The concrete surface %s has cracked after repeated heavy vehicles passed through. %s %s',
                'Motorists are swerving to avoid the damaged lane %s. %s %s',
            ],
        ],
        [
            'category' => 'Drainage / Sewerage',
            'offices' => ["City Engineer's Office"],
            'priority_pool' => ['Normal', 'High', 'High', 'Urgent'],
            'video_friendly' => true,
            'title_templates' => [
                'Clogged drainage needs clearing %s',
                'Sewerage overflow reported %s',
                'Canal blockage is causing stagnant water %s',
            ],
            'description_templates' => [
                'Residents observed wastewater backing up %s after rainfall. %s %s',
                'The drainage opening %s is blocked by debris and the water is no longer flowing out. %s %s',
                'Foul-smelling stagnant water has collected %s because the sewer line appears clogged. %s %s',
            ],
        ],
        [
            'category' => 'Garbage Collection',
            'offices' => ['City Health Office', "City Mayor's Office"],
            'priority_pool' => ['Low', 'Normal', 'High'],
            'video_friendly' => false,
            'title_templates' => [
                'Uncollected garbage piling up %s',
                'Missed garbage pickup reported %s',
                'Waste bags left on the roadside %s',
            ],
            'description_templates' => [
                'Residents said garbage was not collected on schedule %s and the pile is growing. %s %s',
                'Waste bags have remained %s for several days and stray animals are scattering them. %s %s',
                'There is visible trash accumulation %s and the odor is starting to affect nearby houses. %s %s',
            ],
        ],
        [
            'category' => 'Street Light Outage',
            'offices' => ["City Engineer's Office", 'TOMECO (Traffic Operation)'],
            'priority_pool' => ['Normal', 'High', 'High'],
            'video_friendly' => true,
            'title_templates' => [
                'Street light outage reported %s',
                'Dark road section needs lighting repair %s',
                'Multiple lamp posts are not working %s',
            ],
            'description_templates' => [
                'The street lights %s have been out for several nights. %s %s',
                'Residents said the road becomes very dark %s after 7 PM because the lamp posts are not turning on. %s %s',
                'At least one lamp post %s is flickering and another is already out. %s %s',
            ],
        ],
        [
            'category' => 'Permit / Business Concern',
            'offices' => ['Business Permit and Licensing Division'],
            'priority_pool' => ['Low', 'Normal', 'Normal', 'High'],
            'video_friendly' => false,
            'title_templates' => [
                'Business permit follow-up needed %s',
                'Permit release delay reported %s',
                'Licensing requirements clarification requested %s',
            ],
            'description_templates' => [
                'The business owner submitted the permit requirements but has not received an update %s. %s %s',
                'The permit release date has already passed %s and the applicant still has no clear guidance. %s %s',
                'The applicant received different permit instructions %s and is requesting clarification. %s %s',
            ],
        ],
        [
            'category' => 'Flooding',
            'offices' => [
                'City Disaster Risk Reduction and Management Office',
                "City Engineer's Office",
            ],
            'priority_pool' => ['High', 'High', 'Urgent', 'Urgent'],
            'video_friendly' => true,
            'title_templates' => [
                'Floodwater quickly rises %s',
                'Recurring flooding reported %s',
                'Low-lying area needs flood mitigation %s',
            ],
            'description_templates' => [
                'Floodwater enters nearby homes %s during moderate to heavy rain. %s %s',
                'Residents said knee-deep flooding was recorded %s during the last rainfall event. %s %s',
                'The roadway %s becomes difficult to pass whenever drainage overflows. %s %s',
            ],
        ],
        [
            'category' => 'Noise Complaint',
            'offices' => ["City Mayor's Office", 'TOMECO (Traffic Operation)'],
            'priority_pool' => ['Low', 'Normal', 'High'],
            'video_friendly' => true,
            'title_templates' => [
                'Noise complaint filed %s',
                'Late-night amplified sound reported %s',
                'Repeated loud disturbance reported %s',
            ],
            'description_templates' => [
                'Residents said loud noise continues past curfew %s and is affecting children and seniors. %s %s',
                'There have been repeated complaints about amplified sound %s during late hours. %s %s',
                'Several households reported a recurring disturbance %s that needs barangay or city coordination. %s %s',
            ],
        ],
        [
            'category' => 'Public Safety Concern',
            'offices' => [
                'City Disaster Risk Reduction and Management Office',
                "City Mayor's Office",
            ],
            'priority_pool' => ['Normal', 'High', 'Urgent'],
            'video_friendly' => true,
            'title_templates' => [
                'Public safety concern reported %s',
                'Unsafe roadside condition needs inspection %s',
                'Residents requesting immediate safety check %s',
            ],
            'description_templates' => [
                'Residents noticed a safety hazard %s that could affect commuters and nearby homes. %s %s',
                'An unsafe condition %s was reported and residents are requesting a quick inspection. %s %s',
                'Community members said the affected area %s has become risky for pedestrians, especially at night. %s %s',
            ],
        ],
        [
            'category' => 'Traffic Congestion',
            'offices' => ['TOMECO (Traffic Operation)', 'Land Transportation Office'],
            'priority_pool' => ['Low', 'Normal', 'High'],
            'video_friendly' => true,
            'title_templates' => [
                'Traffic congestion reported %s',
                'Vehicle queue causing delays %s',
                'Peak-hour traffic bottleneck needs review %s',
            ],
            'description_templates' => [
                'Residents observed heavy traffic buildup %s during rush hour. %s %s',
                'Vehicle queues have lengthened %s and are affecting nearby intersections. %s %s',
                'Commuters said traffic management is needed %s because lane movement becomes very slow. %s %s',
            ],
        ],
        [
            'category' => 'Illegal Parking',
            'offices' => ['TOMECO (Traffic Operation)'],
            'priority_pool' => ['Low', 'Normal', 'High'],
            'video_friendly' => true,
            'title_templates' => [
                'Illegal parking complaint filed %s',
                'Vehicles blocking roadway reported %s',
                'Parking obstruction needs enforcement %s',
            ],
            'description_templates' => [
                'Parked vehicles are blocking part of the roadway %s and forcing traffic into one lane. %s %s',
                'Residents said illegal parking persists %s even during busy hours. %s %s',
                'The obstruction %s is making it difficult for tricycles and emergency vehicles to pass. %s %s',
            ],
        ],
        [
            'category' => 'Water Service Concern',
            'offices' => ["City Engineer's Office", 'City Health Office'],
            'priority_pool' => ['Normal', 'High', 'High'],
            'video_friendly' => false,
            'title_templates' => [
                'Water service concern reported %s',
                'Possible pipe leak reported %s',
                'Residents requesting water line inspection %s',
            ],
            'description_templates' => [
                'Residents noticed a possible water leak %s and the pavement stays wet even without rain. %s %s',
                'The water line %s may be damaged because pressure has dropped in nearby homes. %s %s',
                'There is a persistent wet patch %s that may indicate an underground leak. %s %s',
            ],
        ],
        [
            'category' => 'Public Sanitation',
            'offices' => ['City Health Office'],
            'priority_pool' => ['Low', 'Normal', 'High'],
            'video_friendly' => false,
            'title_templates' => [
                'Sanitation issue reported %s',
                'Unsanitary roadside condition noted %s',
                'Area cleanup requested %s',
            ],
            'description_templates' => [
                'Residents are requesting sanitation action %s because the area is attracting pests. %s %s',
                'There is an unsanitary condition %s that may affect nearby houses and stalls. %s %s',
                'Standing waste material %s needs cleanup and inspection. %s %s',
            ],
        ],
        [
            'category' => 'Tax / Assessment Concern',
            'offices' => ["City Treasurer's Office", "City Assessor's Office"],
            'priority_pool' => ['Low', 'Normal', 'Normal', 'High'],
            'video_friendly' => false,
            'title_templates' => [
                'Tax or assessment record follow-up requested %s',
                'Assessment correction concern logged %s',
                'Payment posting concern needs review %s',
            ],
            'description_templates' => [
                'The resident is requesting help with a tax or assessment concern filed %s. %s %s',
                'There appears to be a mismatch in the property or payment record %s. %s %s',
                'The transaction filed %s still needs verification from the assigned office. %s %s',
            ],
        ],
    ];

    private const IMPACT_PHRASES = [
        'Motorists are starting to avoid the area and use the opposite lane.',
        'Commuters said the issue is worst during school and office rush hours.',
        'Nearby residents said the problem affects elderly residents and children the most.',
        'The issue has already been reported to barangay officials but still needs city action.',
        'The affected area is part of a commonly used route for market trips and school service vehicles.',
        'The concern becomes more visible in the evening and after rain.',
        'Residents said the issue has been recurring for several weeks.',
    ];

    private const REQUEST_PHRASES = [
        'Please schedule an on-site inspection and advise the next action.',
        'Please endorse this to the field team for verification.',
        'Please provide an update that can be shared with residents waiting for action.',
        'Please include the barangay in the coordination if immediate work is needed.',
        'Please confirm the expected timeline for the next step.',
        'Please assess whether temporary mitigation is needed while the permanent fix is pending.',
    ];

    private const PHOTO_URLS = [
        ['url' => 'https://picsum.photos/seed/citytrack-road-damage/1280/720', 'original_name' => 'road-damage-demo.jpg'],
        ['url' => 'https://picsum.photos/seed/citytrack-drainage/1280/720', 'original_name' => 'drainage-demo.jpg'],
        ['url' => 'https://picsum.photos/seed/citytrack-garbage/1280/720', 'original_name' => 'garbage-collection-demo.jpg'],
        ['url' => 'https://picsum.photos/seed/citytrack-streetlight/1280/720', 'original_name' => 'streetlight-demo.jpg'],
        ['url' => 'https://picsum.photos/seed/citytrack-flooding/1280/720', 'original_name' => 'flooding-demo.jpg'],
        ['url' => 'https://picsum.photos/seed/citytrack-traffic/1280/720', 'original_name' => 'traffic-demo.jpg'],
        ['url' => 'https://picsum.photos/seed/citytrack-sanitation/1280/720', 'original_name' => 'sanitation-demo.jpg'],
        ['url' => 'https://picsum.photos/seed/citytrack-safety/1280/720', 'original_name' => 'public-safety-demo.jpg'],
    ];

    private const VIDEO_URLS = [
        ['url' => 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4', 'original_name' => 'site-inspection-demo.mp4'],
        ['url' => 'https://www.w3schools.com/html/mov_bbb.mp4', 'original_name' => 'resident-video-demo.mp4'],
    ];

    private const STATUS_REMARKS = [
        'Pending' => [
            'The report has been logged and is waiting for field verification.',
            'The complaint has been endorsed to the assigned department for initial review.',
            'The office acknowledged the concern and is validating the submitted details.',
        ],
        'In Progress' => [
            'Field personnel visited the location and started the initial intervention.',
            'The issue has been assigned to staff and site coordination is ongoing.',
            'Materials or crew scheduling is underway while the department completes validation.',
        ],
        'Resolved' => [
            'The assigned office reported that corrective work has been completed on site.',
            'The concern was addressed and the barangay was informed of the completed action.',
            'Final verification was completed and the issue was marked resolved after follow-up.',
        ],
    ];

    private const FEEDBACK_MESSAGES = [
        'Praise' => [
            'The department responded professionally and kept the citizen informed.',
            'The update was clear and the follow-through was appreciated by the residents.',
            'Thank you for resolving the concern and coordinating with the barangay.',
        ],
        'Suggestion' => [
            'Please add clearer progress updates so residents know when field work will happen.',
            'The process would improve if estimated completion windows were included in updates.',
            'A short message after assignment would help citizens follow the complaint more easily.',
        ],
        'Complaint' => [
            'The concern was acknowledged, but the response time still felt longer than expected.',
            'The report needed more detailed updates while residents were waiting for action.',
            'The issue improved, but citizens are still requesting closer monitoring afterward.',
        ],
    ];

    /** @var array<string, Category> */
    private array $categoryCache = [];

    public function run(): void
    {
        fake()->seed(20240509);
        mt_srand(20240509);

        $adminCount = (int) env('DEMO_ADMIN_COUNT', 39);
        $citizenCount = (int) env('DEMO_CITIZEN_COUNT', 420);
        $reportCount = (int) env('DEMO_REPORT_COUNT', 3200);
        $feedbackCount = (int) env('DEMO_FEEDBACK_COUNT', 900);

        $this->call(DatabaseSeeder::class);
        $this->cleanupPreviousDemoDataset();

        $offices = Office::query()
            ->where('is_active', true)
            ->orderBy('name')
            ->get();

        $this->primeCategories();

        $admins = $this->seedAdmins($adminCount, $offices);
        $citizens = $this->seedCitizens($citizenCount);
        $reportSummary = $this->seedReports($reportCount, $offices, $admins, $citizens, $feedbackCount);

        $this->command?->info(
            sprintf(
                'Demo dataset ready: %d admins, %d citizens, %d reports, %d attachments, %d status histories, %d admin responses, %d feedback entries, %d escalations.',
                $admins->count(),
                $citizens->count(),
                $reportSummary['reports_count'],
                $reportSummary['attachments_count'],
                $reportSummary['status_history_count'],
                $reportSummary['admin_response_count'],
                $reportSummary['feedback_count'],
                $reportSummary['escalation_count'],
            )
        );
        $this->command?->info(
            'Passwords: admins use '.self::ADMIN_PASSWORD.', citizens use '.self::CITIZEN_PASSWORD.'.'
        );
    }

    private function cleanupPreviousDemoDataset(): void
    {
        $demoUsers = User::withTrashed()
            ->where('email', 'like', 'demo.admin.%')
            ->orWhere('email', 'like', 'demo.citizen.%')
            ->get();

        if ($demoUsers->isEmpty()) {
            return;
        }

        $demoUsers->each(function (User $user): void {
            $user->forceDelete();
        });
    }

    private function primeCategories(): void
    {
        foreach (self::ISSUE_PROFILES as $profile) {
            $category = Category::query()->firstOrCreate(
                ['name' => $profile['category']],
                ['description' => $profile['category'].' demonstration reports']
            );

            $this->categoryCache[$profile['category']] = $category;
        }
    }

    private function seedAdmins(int $count, Collection $offices): Collection
    {
        $admins = collect();
        $officeCount = max(1, $offices->count());

        for ($index = 1; $index <= $count; $index++) {
            $office = $offices[($index - 1) % $officeCount];
            $email = sprintf('demo.admin.%03d@citytrack.test', $index);
            $admin = User::query()->updateOrCreate(
                ['email' => $email],
                [
                    'name' => $this->fullName($index + 100),
                    'mobile_number' => sprintf('0918%07d', $index),
                    'password' => self::ADMIN_PASSWORD,
                    'role' => 'admin',
                    'department' => $office->name,
                    'job_title' => (($index - 1) % $officeCount) === 0
                        ? 'Department Head'
                        : $this->adminJobTitle($index),
                    'is_active' => true,
                ]
            );

            $admins->push($admin);
        }

        return $admins;
    }

    private function seedCitizens(int $count): Collection
    {
        $citizens = collect();

        for ($index = 1; $index <= $count; $index++) {
            $email = sprintf('demo.citizen.%04d@example.com', $index);
            $citizen = User::query()->updateOrCreate(
                ['email' => $email],
                [
                    'name' => $this->fullName($index),
                    'mobile_number' => sprintf('0927%07d', $index),
                    'password' => self::CITIZEN_PASSWORD,
                    'role' => 'citizen',
                    'department' => null,
                    'job_title' => null,
                    'is_active' => true,
                ]
            );

            $citizens->push($citizen);
        }

        return $citizens;
    }

    private function seedReports(
        int $count,
        Collection $offices,
        Collection $admins,
        Collection $citizens,
        int $feedbackLimit
    ): array {
        $officeByName = $offices->keyBy('name');
        $allAdmins = $admins->values();
        $adminsByDepartment = $admins->groupBy('department')->map(
            fn (Collection $departmentAdmins) => $departmentAdmins->values()
        );

        $imageRows = [];
        $statusHistoryRows = [];
        $adminResponseRows = [];
        $feedbackRows = [];
        $escalationRows = [];

        for ($index = 1; $index <= $count; $index++) {
            $profile = $this->issueProfileForIndex($index);
            $officeName = $this->pickFrom($profile['offices'], $index + 3);
            $office = $officeByName->get($officeName) ?? $offices->first();
            $category = $this->categoryCache[$profile['category']];
            $citizen = $citizens[($index * 11) % max(1, $citizens->count())];
            $departmentAdmins = $adminsByDepartment->get($office->name, collect());

            if ($departmentAdmins->isEmpty()) {
                $departmentAdmins = $allAdmins;
            }

            $reviewer = $departmentAdmins->first(
                fn (User $admin) => $admin->isDepartmentHead()
            ) ?? $departmentAdmins->first();
            $assignee = $departmentAdmins->isEmpty()
                ? null
                : $departmentAdmins[($index * 5) % $departmentAdmins->count()];
            $barangayProfile = $this->barangayProfileForIndex($index);
            $spot = $this->pickFrom($barangayProfile['spots'], $index + 5);
            $status = $this->statusForIndex($index);
            $priority = $this->pickFrom($profile['priority_pool'], $index + 7);
            $createdAt = $this->historicalCreatedAt($index);
            $transitions = $this->buildTransitions(
                $status,
                $createdAt,
                $reviewer,
                $assignee,
                $index
            );
            $latestTransition = empty($transitions)
                ? null
                : $transitions[count($transitions) - 1];
            $resolvedAt = $status === 'Resolved'
                ? Carbon::parse($latestTransition['happened_at'])
                : null;
            $updatedAt = $resolvedAt
                ?? ($latestTransition
                    ? Carbon::parse($latestTransition['happened_at'])
                    : $createdAt->copy()->addHours(2 + ($index % 10)));

            $report = new Report([
                'user_id' => $citizen->id,
                'category_id' => $category->id,
                'office_id' => $office->id,
                'title' => $this->buildReportTitle($profile, $spot, $index),
                'description' => $this->buildReportDescription(
                    $profile,
                    $spot,
                    $office->name,
                    $index
                ),
                'location' => $spot.', '.$barangayProfile['barangay'].', Tacloban City',
                'barangay' => $barangayProfile['barangay'],
                'latitude' => $barangayProfile['latitude'] + (($index % 9) * 0.00021),
                'longitude' => $barangayProfile['longitude'] + (($index % 7) * 0.00019),
                'status' => $status,
                'priority' => $priority,
                'assigned_to' => in_array($status, ['Pending', 'In Progress', 'Resolved'], true)
                    ? $assignee?->id
                    : null,
                'resolved_at' => $resolvedAt,
            ]);
            $report->created_at = $createdAt;
            $report->updated_at = $updatedAt;
            $report->save();

            foreach ($this->attachmentRowsForReport($report->id, $profile, $index) as $attachmentRow) {
                $imageRows[] = $attachmentRow;
            }

            foreach ($transitions as $transition) {
                $statusHistoryRows[] = [
                    'report_id' => $report->id,
                    'old_status' => $transition['old_status'],
                    'new_status' => $transition['new_status'],
                    'remarks' => $transition['remarks'],
                    'updated_by' => $transition['updated_by'],
                    'created_at' => $transition['happened_at'],
                    'updated_at' => $transition['happened_at'],
                ];
            }

            if ($latestTransition !== null) {
                $adminResponseRows[] = [
                    'report_id' => $report->id,
                    'user_id' => $latestTransition['updated_by'],
                    'response' => $latestTransition['remarks'],
                    'created_at' => $latestTransition['happened_at'],
                    'updated_at' => $latestTransition['happened_at'],
                ];
            }

            if (
                $status === 'Resolved'
                && count($feedbackRows) < $feedbackLimit
                && ($index % 2 === 0)
            ) {
                $feedbackType = $this->feedbackTypeForIndex($index);
                $feedbackAt = $resolvedAt?->copy()->addHours(3 + ($index % 9))
                    ?? $updatedAt->copy()->addHours(4);
                $feedbackRows[] = [
                    'user_id' => $citizen->id,
                    'office_id' => $office->id,
                    'report_id' => $report->id,
                    'type' => $feedbackType,
                    'message' => $this->feedbackMessage($feedbackType, $report->title, $office->name, $index),
                    'rating' => $this->feedbackRating($feedbackType, $index),
                    'created_at' => $feedbackAt,
                    'updated_at' => $feedbackAt,
                ];
            }

            if (
                $status !== 'Resolved'
                && in_array($priority, ['High', 'Urgent'], true)
                && $reviewer !== null
                && ($index % 14 === 0)
            ) {
                $escalatedAt = $updatedAt->copy()->addHours(96 + ($index % 24));
                $escalationStatus = $status === 'In Progress'
                    ? (($index % 3 === 0) ? 'Intervened' : 'Acknowledged')
                    : 'Open';

                $escalationRows[] = [
                    'report_id' => $report->id,
                    'status' => $escalationStatus,
                    'notes' => 'Escalated for demonstration because the concern remained unresolved beyond the expected response window.',
                    'escalated_at' => $escalatedAt,
                    'last_action_at' => $escalatedAt,
                    'acted_by' => $reviewer->id,
                    'created_at' => $escalatedAt,
                    'updated_at' => $escalatedAt,
                ];
            }
        }

        $this->insertInChunks(ReportImage::query(), $imageRows);
        $this->insertInChunks(StatusHistory::query(), $statusHistoryRows);
        $this->insertInChunks(AdminResponse::query(), $adminResponseRows);
        $this->insertInChunks(CitizenFeedback::query(), $feedbackRows);
        $this->insertInChunks(ReportEscalation::query(), $escalationRows);

        return [
            'reports_count' => $count,
            'attachments_count' => count($imageRows),
            'status_history_count' => count($statusHistoryRows),
            'admin_response_count' => count($adminResponseRows),
            'feedback_count' => count($feedbackRows),
            'escalation_count' => count($escalationRows),
        ];
    }

    private function insertInChunks($query, array $rows): void
    {
        if ($rows === []) {
            return;
        }

        foreach (array_chunk($rows, 500) as $chunk) {
            $query->insert($chunk);
        }
    }

    private function buildTransitions(
        string $status,
        Carbon $createdAt,
        ?User $reviewer,
        ?User $assignee,
        int $index
    ): array {
        if ($status === 'New' || $reviewer === null) {
            return [];
        }

        $transitions = [];
        $pendingAt = $this->clampToDemoEnd($createdAt->copy()->addHours(4 + ($index % 18)));
        $transitions[] = [
            'old_status' => 'New',
            'new_status' => 'Pending',
            'remarks' => $this->statusRemark('Pending', $index),
            'updated_by' => $reviewer->id,
            'happened_at' => $pendingAt,
        ];

        if ($status === 'Pending') {
            return $transitions;
        }

        $progressActor = $assignee ?? $reviewer;
        $inProgressAt = $this->clampToDemoEnd($pendingAt->copy()->addHours(18 + (($index * 3) % 72)));
        $transitions[] = [
            'old_status' => 'Pending',
            'new_status' => 'In Progress',
            'remarks' => $this->statusRemark('In Progress', $index),
            'updated_by' => $progressActor->id,
            'happened_at' => $inProgressAt,
        ];

        if ($status === 'In Progress') {
            return $transitions;
        }

        $resolvedAt = $this->clampToDemoEnd($inProgressAt->copy()->addHours(24 + (($index * 5) % 168)));
        $transitions[] = [
            'old_status' => 'In Progress',
            'new_status' => 'Resolved',
            'remarks' => $this->statusRemark('Resolved', $index),
            'updated_by' => $progressActor->id,
            'happened_at' => $resolvedAt,
        ];

        return $transitions;
    }

    private function attachmentRowsForReport(int $reportId, array $profile, int $index): array
    {
        $pattern = $index % 10;
        $attachments = [];
        $timestamp = $this->historicalCreatedAt($index)->copy()->addMinutes(15);

        if (in_array($pattern, [0, 1, 2], true)) {
            $attachments[] = $this->imageAttachmentRow($reportId, $index, $timestamp);
        } elseif ($pattern === 3) {
            $attachments[] = $this->imageAttachmentRow($reportId, $index, $timestamp);
            $attachments[] = $this->imageAttachmentRow($reportId, $index + 1, $timestamp->copy()->addMinutes(1));
        } elseif ($pattern === 4 && ($profile['video_friendly'] ?? false)) {
            $attachments[] = $this->imageAttachmentRow($reportId, $index, $timestamp);
            $attachments[] = $this->videoAttachmentRow($reportId, $index, $timestamp->copy()->addMinutes(2));
        } elseif ($pattern === 5 && ($profile['video_friendly'] ?? false)) {
            $attachments[] = $this->videoAttachmentRow($reportId, $index, $timestamp);
        }

        return $attachments;
    }

    private function imageAttachmentRow(int $reportId, int $index, Carbon $timestamp): array
    {
        $asset = $this->pickFrom(self::PHOTO_URLS, $index);

        return [
            'report_id' => $reportId,
            'image_path' => $asset['url'],
            'media_type' => 'image',
            'original_name' => $asset['original_name'],
            'created_at' => $timestamp,
            'updated_at' => $timestamp,
        ];
    }

    private function videoAttachmentRow(int $reportId, int $index, Carbon $timestamp): array
    {
        $asset = $this->pickFrom(self::VIDEO_URLS, $index);

        return [
            'report_id' => $reportId,
            'image_path' => $asset['url'],
            'media_type' => 'video',
            'original_name' => $asset['original_name'],
            'created_at' => $timestamp,
            'updated_at' => $timestamp,
        ];
    }

    private function buildReportTitle(array $profile, string $spot, int $index): string
    {
        $template = $this->pickFrom($profile['title_templates'], $index);

        return sprintf($template, $spot);
    }

    private function buildReportDescription(
        array $profile,
        string $spot,
        string $officeName,
        int $index
    ): string {
        $template = $this->pickFrom($profile['description_templates'], $index + 1);
        $impact = $this->pickFrom(self::IMPACT_PHRASES, $index + 2);
        $request = $this->pickFrom(self::REQUEST_PHRASES, $index + 4);

        return sprintf($template, $spot, $impact, $request)
            .' Assigned office: '.$officeName.'.';
    }

    private function fullName(int $index): string
    {
        $firstName = $this->pickFrom(self::FIRST_NAMES, $index);
        $lastName = $this->pickFrom(self::LAST_NAMES, $index * 3);

        return $firstName.' '.$lastName;
    }

    private function adminJobTitle(int $index): string
    {
        return match ($index % 4) {
            0 => 'Field Coordinator',
            1 => 'Operations Officer',
            2 => 'Inspection Staff',
            default => 'Department Staff',
        };
    }

    private function issueProfileForIndex(int $index): array
    {
        return self::ISSUE_PROFILES[(($index * 7) + 3) % count(self::ISSUE_PROFILES)];
    }

    private function barangayProfileForIndex(int $index): array
    {
        return self::BARANGAY_PROFILES[(($index * 13) + 5) % count(self::BARANGAY_PROFILES)];
    }

    private function statusForIndex(int $index): string
    {
        $bucket = ($index - 1) % 25;

        return match (true) {
            $bucket < 5 => 'New',
            $bucket < 11 => 'Pending',
            $bucket < 19 => 'In Progress',
            default => 'Resolved',
        };
    }

    private function statusRemark(string $status, int $index): string
    {
        return $this->pickFrom(self::STATUS_REMARKS[$status] ?? self::STATUS_REMARKS['Pending'], $index);
    }

    private function feedbackTypeForIndex(int $index): string
    {
        return $this->pickFrom(['Praise', 'Suggestion', 'Complaint'], $index + 2);
    }

    private function feedbackRating(string $type, int $index): int
    {
        return match ($type) {
            'Praise' => 5,
            'Suggestion' => 4,
            default => 2 + ($index % 2),
        };
    }

    private function feedbackMessage(string $type, string $reportTitle, string $officeName, int $index): string
    {
        $base = $this->pickFrom(self::FEEDBACK_MESSAGES[$type] ?? self::FEEDBACK_MESSAGES['Suggestion'], $index);

        return $base.' Related report: "'.$reportTitle.'" handled by '.$officeName.'.';
    }

    private function historicalCreatedAt(int $index): Carbon
    {
        $start = Carbon::create(
            self::DEMO_START[0],
            self::DEMO_START[1],
            self::DEMO_START[2],
            7,
            0,
            0,
            'Asia/Manila'
        );
        $end = Carbon::create(
            self::DEMO_END[0],
            self::DEMO_END[1],
            self::DEMO_END[2],
            18,
            0,
            0,
            'Asia/Manila'
        );
        $totalDays = $start->diffInDays($end) + 1;
        $dayOffset = (($index * 37) + intdiv($index, 5)) % $totalDays;
        $hour = 6 + (($index * 7) % 12);
        $minute = ($index * 13) % 60;

        return $start->copy()->addDays($dayOffset)->setTime($hour, $minute);
    }

    private function clampToDemoEnd(Carbon $timestamp): Carbon
    {
        $end = Carbon::create(
            self::DEMO_END[0],
            self::DEMO_END[1],
            self::DEMO_END[2],
            23,
            45,
            0,
            'Asia/Manila'
        );

        return $timestamp->greaterThan($end) ? $end->copy() : $timestamp;
    }

    /**
     * @template T
     *
     * @param  array<int, T>  $items
     * @return T
     */
    private function pickFrom(array $items, int $index)
    {
        return $items[$index % count($items)];
    }
}
