<?php

namespace App\Support;

use App\Models\AdminResponse;
use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\StatusHistory;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class RealisticComplaintSeedService
{
    public const DESCRIPTION_LIMIT = 100;
    public const DEFAULT_BATCH_SIZE = 250;

    /**
     * @var list<array{barangay:string,latitude:float,longitude:float,landmarks:list<string>}>
     */
    private const BARANGAY_PROFILES = [
        [
            'barangay' => 'Barangay 1 (Libertad)',
            'latitude' => 11.2431,
            'longitude' => 125.0004,
            'landmarks' => [
                'near Libertad Public Market',
                'beside the barangay hall',
                'along Justice Romualdez Street',
            ],
        ],
        [
            'barangay' => 'Barangay 5',
            'latitude' => 11.2462,
            'longitude' => 125.0015,
            'landmarks' => [
                'at the tricycle terminal',
                'near the elementary school gate',
                'beside the covered court',
            ],
        ],
        [
            'barangay' => 'Barangay 12 (GE Palanog)',
            'latitude' => 11.2458,
            'longitude' => 125.0033,
            'landmarks' => [
                'along the drainage canal',
                'near the sari-sari store row',
                'close to the day care center',
            ],
        ],
        [
            'barangay' => 'Barangay 24',
            'latitude' => 11.2505,
            'longitude' => 125.0074,
            'landmarks' => [
                'beside the chapel entrance',
                'near the public waiting shed',
                'in front of the rice mill access road',
            ],
        ],
        [
            'barangay' => 'Barangay 36 (Sabang)',
            'latitude' => 11.2511,
            'longitude' => 125.0128,
            'landmarks' => [
                'near the coastal access road',
                'at the fish landing area',
                'beside the sea wall section',
            ],
        ],
        [
            'barangay' => 'Barangay 49 (Youngfield)',
            'latitude' => 11.2584,
            'longitude' => 125.0155,
            'landmarks' => [
                'near the subdivision gate',
                'along the inner service road',
                'in front of the basketball court',
            ],
        ],
        [
            'barangay' => 'Barangay 60-A (Sagkahan)',
            'latitude' => 11.2489,
            'longitude' => 125.0191,
            'landmarks' => [
                'near the creek crossing',
                'beside the barangay health station',
                'at the intersection leading to the highway',
            ],
        ],
        [
            'barangay' => 'Barangay 62',
            'latitude' => 11.2493,
            'longitude' => 125.0227,
            'landmarks' => [
                'behind the transport terminal',
                'near the unloading bay',
                'beside the roadside drainage opening',
            ],
        ],
        [
            'barangay' => 'Barangay 68',
            'latitude' => 11.2554,
            'longitude' => 125.0278,
            'landmarks' => [
                'near the barangay multipurpose hall',
                'along the uphill stretch',
                'by the side street near the waiting shed',
            ],
        ],
        [
            'barangay' => 'Barangay 78 (Marasbaras)',
            'latitude' => 11.2598,
            'longitude' => 125.0316,
            'landmarks' => [
                'near the hospital access road',
                'at the subdivision corner',
                'beside the drainage outfall',
            ],
        ],
        [
            'barangay' => 'Barangay 83-C (San Jose)',
            'latitude' => 11.2635,
            'longitude' => 125.0382,
            'landmarks' => [
                'near the airport road shoulder',
                'in front of the terminal entrance',
                'beside the pedestrian crossing',
            ],
        ],
        [
            'barangay' => 'Barangay 91 (Abucay)',
            'latitude' => 11.2704,
            'longitude' => 125.0482,
            'landmarks' => [
                'near the river embankment',
                'by the evacuation route',
                'at the low-lying section of the road',
            ],
        ],
        [
            'barangay' => 'Barangay 95-A (Caibaan)',
            'latitude' => 11.2736,
            'longitude' => 125.0534,
            'landmarks' => [
                'beside the public market service road',
                'near the jeepney stop',
                'in front of the barangay hall driveway',
            ],
        ],
        [
            'barangay' => 'Barangay 102',
            'latitude' => 11.2794,
            'longitude' => 125.0621,
            'landmarks' => [
                'near the school fence line',
                'along the inner barangay road',
                'beside the community pump house',
            ],
        ],
        [
            'barangay' => 'Barangay 109 (V&G Subdivision)',
            'latitude' => 11.2848,
            'longitude' => 125.0711,
            'landmarks' => [
                'near the subdivision rotunda',
                'along the commercial strip',
                'beside the park frontage',
            ],
        ],
    ];

    /**
     * @var list<array{
     *   office:string,
     *   category_candidates:list<string>,
     *   subjects:list<string>,
     *   title_templates:list<string>,
     *   description_templates:list<string>,
     *   priority_pool:list<string>,
     *   weight:int
     * }>
     */
    private const SCENARIOS = [
        [
            'office' => 'Business Permit and Licensing Division',
            'category_candidates' => ['Business Permit Renewal', 'Permit Release Delay', 'Permit / Business Concern', 'Business Registration'],
            'subjects' => ['permit release', 'business permit assessment', 'renewal queue', 'inspection schedule'],
            'title_templates' => [
                '%s delay near %s',
                'Follow-up needed for %s at %s',
                '%s concern reported from %s',
            ],
            'description_templates' => [
                'Citizen follow-up on %s remains pending near %s.',
                'Business owner asked for faster handling of %s at %s.',
                '%s needs verification because documents are stuck near %s.',
            ],
            'priority_pool' => ['Low', 'Normal', 'Normal', 'High'],
            'weight' => 6,
        ],
        [
            'office' => 'City Agriculturist Office',
            'category_candidates' => ['Livestock Concern', 'Livestock Health', 'Agriculture Assistance', 'Farmer Support'],
            'subjects' => ['stray livestock', 'animal health response', 'farm support request', 'crop damage follow-up'],
            'title_templates' => [
                '%s reported around %s',
                'Residents flagged %s near %s',
                '%s needs field inspection at %s',
            ],
            'description_templates' => [
                '%s is affecting nearby homes around %s.',
                'Residents requested assistance because %s continues near %s.',
                '%s may worsen if no field team checks %s soon.',
            ],
            'priority_pool' => ['Low', 'Normal', 'High'],
            'weight' => 5,
        ],
        [
            'office' => "City Assessor's Office",
            'category_candidates' => ['Property Assessment', 'Assessment Correction', 'Property Valuation', 'Tax Declaration'],
            'subjects' => ['property assessment discrepancy', 'tax declaration correction', 'valuation concern', 'ownership record mismatch'],
            'title_templates' => [
                '%s raised near %s',
                'Clarification requested for %s from %s',
                '%s follow-up logged at %s',
            ],
            'description_templates' => [
                'Citizen reported %s and needs office review near %s.',
                '%s remains unresolved for the resident assisted near %s.',
                'Records review was requested because of %s at %s.',
            ],
            'priority_pool' => ['Low', 'Normal', 'Normal', 'High'],
            'weight' => 4,
        ],
        [
            'office' => "City Civil Registrar's Office",
            'category_candidates' => ['Birth Certificate', 'Marriage Certificate', 'Death Certificate', 'Delayed Registration', 'Civil Registry Correction'],
            'subjects' => ['certificate correction', 'delayed registration follow-up', 'record mismatch', 'release delay'],
            'title_templates' => [
                '%s concern from %s',
                'Resident requested update on %s near %s',
                '%s verification needed at %s',
            ],
            'description_templates' => [
                '%s is still pending and needs checking near %s.',
                'Citizen asked for clearer guidance because of %s at %s.',
                '%s may delay release unless reviewed promptly near %s.',
            ],
            'priority_pool' => ['Low', 'Normal', 'Normal', 'High'],
            'weight' => 4,
        ],
        [
            'office' => 'City Disaster Risk Reduction and Management Office',
            'category_candidates' => ['Flooding', 'Hazard Report', 'Emergency Response', 'Disaster Preparedness'],
            'subjects' => ['flood-prone section', 'hazard warning request', 'blocked evacuation route', 'emergency response follow-up'],
            'title_templates' => [
                '%s reported near %s',
                'Barangay logged %s at %s',
                'Immediate review requested for %s near %s',
            ],
            'description_templates' => [
                '%s was observed again near %s after recent rain.',
                'Residents asked for inspection because %s remains at %s.',
                '%s could affect safety if left unresolved around %s.',
            ],
            'priority_pool' => ['Normal', 'High', 'High', 'Urgent'],
            'weight' => 7,
        ],
        [
            'office' => "City Engineer's Office",
            'category_candidates' => ['Road Damage', 'Road Repairs', 'Drainage/Sewerage', 'Drainage / Sewerage', 'Street Light Outage', 'Streetlighting', 'Road Obstruction', 'Road Safety', 'Public Works'],
            'subjects' => ['pothole damage', 'clogged drainage', 'street light outage', 'road obstruction'],
            'title_templates' => [
                '%s near %s',
                'Residents reported %s around %s',
                '%s needs action at %s',
            ],
            'description_templates' => [
                '%s keeps disrupting traffic and residents near %s.',
                'Motorists reported %s and want engineering action at %s.',
                '%s may worsen if repairs are delayed around %s.',
            ],
            'priority_pool' => ['Normal', 'High', 'High', 'Urgent'],
            'weight' => 14,
        ],
        [
            'office' => 'City Health Office',
            'category_candidates' => ['Waste Management', 'Garbage Collection', 'Public Sanitation', 'Sanitation', 'Public Health', 'Disease Prevention', 'Health Center Concern'],
            'subjects' => ['garbage backlog', 'sanitation issue', 'foul odor concern', 'mosquito breeding area'],
            'title_templates' => [
                '%s raised near %s',
                'Residents flagged %s at %s',
                '%s complaint logged around %s',
            ],
            'description_templates' => [
                '%s is affecting nearby households around %s.',
                'Health-related concern about %s was reported at %s.',
                '%s may pose sanitation risks if not cleared near %s.',
            ],
            'priority_pool' => ['Normal', 'Normal', 'High', 'Urgent'],
            'weight' => 12,
        ],
        [
            'office' => "City Mayor's Office",
            'category_candidates' => ['Noise Complaint', 'General City Concern', 'Public Safety Concern', 'Administrative Complaint', 'Executive Assistance'],
            'subjects' => ['late-night noise complaint', 'public disturbance', 'community safety concern', 'follow-up on barangay action'],
            'title_templates' => [
                '%s from %s',
                'Residents requested help on %s near %s',
                '%s endorsement needed at %s',
            ],
            'description_templates' => [
                '%s continues and residents near %s requested escalation.',
                'Citizen asked the city for help because of %s at %s.',
                '%s needs coordination and review around %s.',
            ],
            'priority_pool' => ['Low', 'Normal', 'High'],
            'weight' => 5,
        ],
        [
            'office' => 'City Social Welfare and Development Office',
            'category_candidates' => ['Social Assistance', 'Senior Citizen Assistance', 'PWD Assistance', 'Family Welfare', 'Child Welfare', 'Financial Assistance (AICS)'],
            'subjects' => ['AICS follow-up', 'senior assistance concern', 'PWD support request', 'family welfare referral'],
            'title_templates' => [
                '%s pending near %s',
                'Resident asked update on %s from %s',
                '%s intake concern reported at %s',
            ],
            'description_templates' => [
                '%s needs review because the resident has waited since last visit near %s.',
                'Citizen asked for guidance on %s while at %s.',
                '%s remains open and follow-up was requested near %s.',
            ],
            'priority_pool' => ['Low', 'Normal', 'Normal', 'High'],
            'weight' => 5,
        ],
        [
            'office' => 'City Tourism Operations Office',
            'category_candidates' => ['Tourism Facility', 'Tourism Event', 'Visitor Assistance', 'Heritage Site Concern'],
            'subjects' => ['tourism facility cleanliness', 'visitor assistance concern', 'event traffic concern', 'heritage site maintenance issue'],
            'title_templates' => [
                '%s reported at %s',
                'Visitor raised %s near %s',
                '%s follow-up requested from %s',
            ],
            'description_templates' => [
                '%s may affect visitors if not checked soon near %s.',
                'Tourism-related concern about %s was raised around %s.',
                '%s needs coordination before visitor traffic increases at %s.',
            ],
            'priority_pool' => ['Low', 'Normal', 'High'],
            'weight' => 3,
        ],
        [
            'office' => "City Treasurer's Office",
            'category_candidates' => ['Receipt Concern', 'Payment Concern', 'Business Tax', 'Real Property Tax', 'Collection Issue'],
            'subjects' => ['official receipt issue', 'payment posting delay', 'tax payment follow-up', 'collection concern'],
            'title_templates' => [
                '%s reported near %s',
                'Resident needs update on %s at %s',
                '%s concern filed from %s',
            ],
            'description_templates' => [
                '%s still needs verification according to the resident at %s.',
                'Citizen returned because of %s and asked help near %s.',
                '%s may affect payment records unless resolved at %s.',
            ],
            'priority_pool' => ['Low', 'Normal', 'Normal', 'High'],
            'weight' => 4,
        ],
        [
            'office' => 'Land Transportation Office',
            'category_candidates' => ['Vehicle Registration', 'Driver Licensing', 'Licensing Concern', 'Transport Regulation'],
            'subjects' => ['vehicle registration delay', 'driver licensing concern', 'plate release follow-up', 'transport compliance concern'],
            'title_templates' => [
                '%s concern from %s',
                'Motorist requested help on %s near %s',
                '%s review needed at %s',
            ],
            'description_templates' => [
                '%s remains pending and the motorist returned near %s.',
                'Citizen asked for assistance because of %s at %s.',
                '%s may delay travel compliance if left unresolved near %s.',
            ],
            'priority_pool' => ['Low', 'Normal', 'High'],
            'weight' => 3,
        ],
        [
            'office' => 'TOMECO (Traffic Operation)',
            'category_candidates' => ['Illegal Parking', 'Traffic Congestion', 'Traffic Enforcement', 'Traffic Violation Concern', 'Traffic Signal'],
            'subjects' => ['illegal parking', 'traffic congestion', 'damaged traffic signal', 'enforcer response concern'],
            'title_templates' => [
                '%s near %s',
                'Motorists reported %s at %s',
                '%s complaint logged from %s',
            ],
            'description_templates' => [
                '%s keeps blocking movement and residents want action at %s.',
                'Commuters reported %s and asked traffic officers to check %s.',
                '%s continues during peak hours near %s.',
            ],
            'priority_pool' => ['Normal', 'High', 'High', 'Urgent'],
            'weight' => 11,
        ],
    ];

    public function __construct(
        private readonly DemoAccountService $demoAccounts,
    ) {
    }

    public function describeContext(): array
    {
        $citizens = $this->realCitizenPool();
        $offices = Office::query()->where('is_active', true)->get(['id', 'name']);
        $categories = Category::query()->get(['id', 'name']);
        $admins = $this->adminPool();

        return [
            'citizen_count' => $citizens->count(),
            'office_count' => $offices->count(),
            'category_count' => $categories->count(),
            'admin_count' => $admins->where('role', 'admin')->count(),
            'super_admin_count' => $admins->where('role', 'super_admin')->count(),
            'office_names' => $offices->pluck('name')->values()->all(),
        ];
    }

    public function seed(int $count, int $batchSize = self::DEFAULT_BATCH_SIZE): array
    {
        if ($count < 1) {
            throw new RuntimeException('The complaint count must be at least 1.');
        }

        $batchSize = max(1, min($batchSize, $count));
        $context = $this->buildContext();
        $this->ensurePrerequisites($context);

        $summary = [
            'requested_count' => $count,
            'created_count' => 0,
            'status_histories_created' => 0,
            'admin_responses_created' => 0,
            'reports_before' => (int) Report::query()->count(),
            'reports_after' => 0,
            'citizen_ids_used' => [],
            'office_counts' => [],
            'status_counts' => [],
            'priority_counts' => [],
            'generated_start' => null,
            'generated_end' => null,
        ];

        for ($offset = 0; $offset < $count; $offset += $batchSize) {
            $chunkSize = min($batchSize, $count - $offset);
            DB::transaction(function () use ($offset, $chunkSize, $context, &$summary) {
                $statusHistoryRows = [];
                $adminResponseRows = [];

                for ($index = 0; $index < $chunkSize; $index++) {
                    $sequence = $offset + $index + 1;
                    $blueprint = $this->buildComplaintBlueprint($sequence, $context);

                    $report = new Report($blueprint['attributes']);
                    $report->created_at = $blueprint['created_at'];
                    $report->updated_at = $blueprint['updated_at'];
                    $report->save();

                    $summary['created_count']++;
                    $summary['citizen_ids_used'][$blueprint['attributes']['user_id']] = true;
                    $this->incrementSummaryCount($summary['office_counts'], $blueprint['office_name']);
                    $this->incrementSummaryCount($summary['status_counts'], $blueprint['attributes']['status']);
                    $this->incrementSummaryCount($summary['priority_counts'], $blueprint['attributes']['priority']);
                    $summary['generated_start'] = $summary['generated_start'] === null
                        || $blueprint['created_at']->lt($summary['generated_start'])
                        ? $blueprint['created_at']->copy()
                        : $summary['generated_start'];
                    $summary['generated_end'] = $summary['generated_end'] === null
                        || $blueprint['updated_at']->gt($summary['generated_end'])
                        ? $blueprint['updated_at']->copy()
                        : $summary['generated_end'];

                    foreach ($blueprint['status_histories'] as $historyRow) {
                        $statusHistoryRows[] = [
                            'report_id' => $report->id,
                            ...$historyRow,
                        ];
                    }

                    if ($blueprint['admin_response'] !== null) {
                        $adminResponseRows[] = [
                            'report_id' => $report->id,
                            ...$blueprint['admin_response'],
                        ];
                    }
                }

                if ($statusHistoryRows !== []) {
                    StatusHistory::query()->insert($statusHistoryRows);
                    $summary['status_histories_created'] += count($statusHistoryRows);
                }

                if ($adminResponseRows !== []) {
                    AdminResponse::query()->insert($adminResponseRows);
                    $summary['admin_responses_created'] += count($adminResponseRows);
                }
            }, 3);
        }

        ksort($summary['office_counts']);
        ksort($summary['status_counts']);
        ksort($summary['priority_counts']);

        $summary['citizen_ids_used'] = array_map('intval', array_keys($summary['citizen_ids_used']));
        sort($summary['citizen_ids_used']);
        $summary['citizen_count_used'] = count($summary['citizen_ids_used']);
        $summary['reports_after'] = (int) Report::query()->count();
        $summary['reports_delta'] = $summary['reports_after'] - $summary['reports_before'];

        return $summary;
    }

    private function buildContext(): array
    {
        $citizens = $this->realCitizenPool()->values();
        $offices = Office::query()->where('is_active', true)->orderBy('name')->get(['id', 'name']);
        $categories = Category::query()->orderBy('name')->get(['id', 'name']);
        $admins = $this->adminPool()->values();
        $officeByName = $offices->keyBy(fn (Office $office) => mb_strtolower(trim((string) $office->name)));
        $categoryByName = $categories->keyBy(fn (Category $category) => mb_strtolower(trim((string) $category->name)));
        $adminsByDepartment = $admins
            ->filter(fn (User $user) => trim((string) $user->department) !== '')
            ->groupBy(fn (User $user) => mb_strtolower(trim((string) $user->department)))
            ->map(fn (Collection $items) => $items->values());

        return [
            'citizens' => $citizens,
            'offices' => $offices,
            'office_by_name' => $officeByName,
            'categories' => $categories,
            'category_by_name' => $categoryByName,
            'admins' => $admins,
            'admins_by_department' => $adminsByDepartment,
            'profiles' => $this->availableProfiles($officeByName),
        ];
    }

    private function ensurePrerequisites(array $context): void
    {
        if (($context['citizens'] instanceof Collection ? $context['citizens']->count() : 0) < 1) {
            throw new RuntimeException('No active real citizen accounts are available. Create at least one citizen before seeding complaints.');
        }

        if (($context['offices'] instanceof Collection ? $context['offices']->count() : 0) < 1) {
            throw new RuntimeException('No active offices are available. Seed or create offices before seeding complaints.');
        }

        if (($context['categories'] instanceof Collection ? $context['categories']->count() : 0) < 1) {
            throw new RuntimeException('No categories are available. Seed or create categories before seeding complaints.');
        }
    }

    private function buildComplaintBlueprint(int $sequence, array $context): array
    {
        /** @var Collection<int, array<string, mixed>> $profiles */
        $profiles = $context['profiles'];
        /** @var Collection<int, User> $citizens */
        $citizens = $context['citizens'];
        /** @var Collection<int, Office> $offices */
        $offices = $context['offices'];
        /** @var Collection<int, Category> $categories */
        $categories = $context['categories'];
        /** @var Collection<string, Office> $officeByName */
        $officeByName = $context['office_by_name'];
        /** @var Collection<string, Category> $categoryByName */
        $categoryByName = $context['category_by_name'];
        /** @var Collection<int, User> $admins */
        $admins = $context['admins'];
        /** @var Collection<string, Collection<int, User>> $adminsByDepartment */
        $adminsByDepartment = $context['admins_by_department'];

        $profile = $profiles[($sequence * 7) % max(1, $profiles->count())];
        $officeKey = mb_strtolower(trim((string) $profile['office']));
        $office = $officeByName->get($officeKey) ?? $offices->first();
        $category = $this->resolveCategoryForProfile($profile, $categoryByName, $categories, $sequence);
        $citizen = $citizens[($sequence * 11) % max(1, $citizens->count())];
        $barangayProfile = self::BARANGAY_PROFILES[($sequence * 13) % count(self::BARANGAY_PROFILES)];
        $landmark = $this->pickFrom($barangayProfile['landmarks'], $sequence + 3);
        $subject = $this->pickFrom($profile['subjects'], $sequence + 5);
        $createdAt = $this->createdAtForSequence($sequence);
        $status = $this->statusForDate($createdAt, $sequence);
        $priority = $this->priorityForProfile($profile, $status, $sequence);
        $isAnonymous = $sequence % 9 === 0;

        $departmentAdmins = $adminsByDepartment->get(mb_strtolower(trim((string) ($office?->name ?? ''))), collect());
        $reviewers = $departmentAdmins->isNotEmpty() ? $departmentAdmins : $admins;
        $reviewer = $reviewers->first(fn (User $user) => $user->isDepartmentHead()) ?? $reviewers->first();
        $assignee = $departmentAdmins->isEmpty()
            ? null
            : $departmentAdmins[($sequence * 3) % $departmentAdmins->count()];

        $titleTemplate = $this->pickFrom($profile['title_templates'], $sequence + 1);
        $descriptionTemplate = $this->pickFrom($profile['description_templates'], $sequence + 2);
        $title = $this->clipText(sprintf($titleTemplate, $this->headline($subject), $landmark), 255);
        $description = $this->clipText(sprintf($descriptionTemplate, $subject, $landmark), self::DESCRIPTION_LIMIT);
        $location = $this->clipText($landmark.', '.$barangayProfile['barangay'].', Tacloban City', 255);
        $assignedTo = in_array($status, ['Pending', 'In Progress', 'Resolved'], true) ? $assignee?->id : null;
        $timeline = $this->buildStatusTimeline($status, $createdAt, $reviewer, $assignee, $sequence);

        return [
            'office_name' => $office?->name ?? 'Unknown office',
            'created_at' => $createdAt,
            'updated_at' => $timeline['updated_at'],
            'attributes' => [
                'user_id' => $citizen->id,
                'category_id' => $category?->id,
                'office_id' => $office?->id,
                'title' => $title,
                'description' => $description,
                'location' => $location,
                'barangay' => $barangayProfile['barangay'],
                'latitude' => round($barangayProfile['latitude'] + (($sequence % 9) * 0.00018), 7),
                'longitude' => round($barangayProfile['longitude'] + (($sequence % 7) * 0.00016), 7),
                'status' => $status,
                'priority' => $priority,
                'is_anonymous' => $isAnonymous,
                'source' => 'citizen_app',
                'assigned_to' => $assignedTo,
                'resolved_at' => $timeline['resolved_at'],
            ],
            'status_histories' => $timeline['status_histories'],
            'admin_response' => $timeline['admin_response'],
        ];
    }

    private function buildStatusTimeline(
        string $status,
        Carbon $createdAt,
        ?User $reviewer,
        ?User $assignee,
        int $sequence
    ): array {
        if ($status === 'New' || $reviewer === null) {
            return [
                'resolved_at' => null,
                'updated_at' => $createdAt->copy()->addHours(1 + ($sequence % 6)),
                'status_histories' => [],
                'admin_response' => null,
            ];
        }

        $transitions = [];
        $pendingAt = $createdAt->copy()->addHours(6 + ($sequence % 18));
        $transitions[] = $this->statusTransitionRow(
            'New',
            'Pending',
            'Report acknowledged and queued for field validation.',
            $reviewer->id,
            $pendingAt
        );

        if ($status === 'Pending') {
            return $this->timelinePayloadFromTransitions($transitions, null);
        }

        $progressActor = $assignee ?? $reviewer;
        $inProgressAt = $pendingAt->copy()->addHours(10 + (($sequence * 3) % 48));
        $transitions[] = $this->statusTransitionRow(
            'Pending',
            'In Progress',
            'Assigned team scheduled a site inspection and coordination.',
            $progressActor->id,
            $inProgressAt
        );

        if ($status === 'In Progress') {
            return $this->timelinePayloadFromTransitions($transitions, null);
        }

        if ($status === 'Rejected') {
            $rejectAt = $inProgressAt->copy()->addHours(8 + (($sequence * 5) % 36));
            $transitions[] = $this->statusTransitionRow(
                'In Progress',
                'Rejected',
                'Report was closed after verification found incomplete, duplicate, or outside office scope.',
                $reviewer->id,
                $rejectAt
            );

            return $this->timelinePayloadFromTransitions($transitions, null);
        }

        $resolvedAt = $inProgressAt->copy()->addHours(18 + (($sequence * 7) % 96));
        $transitions[] = $this->statusTransitionRow(
            'In Progress',
            'Resolved',
            'Field team completed corrective action and marked the concern resolved.',
            $progressActor->id,
            $resolvedAt
        );

        return $this->timelinePayloadFromTransitions($transitions, $resolvedAt);
    }

    private function timelinePayloadFromTransitions(array $transitions, ?Carbon $resolvedAt): array
    {
        $latest = $transitions[count($transitions) - 1];
        $latestAt = Carbon::parse((string) $latest['created_at']);

        return [
            'resolved_at' => $resolvedAt,
            'updated_at' => $latestAt,
            'status_histories' => $transitions,
            'admin_response' => [
                'user_id' => $latest['updated_by'],
                'response' => $latest['remarks'],
                'created_at' => $latest['created_at'],
                'updated_at' => $latest['updated_at'],
            ],
        ];
    }

    private function statusTransitionRow(
        string $oldStatus,
        string $newStatus,
        string $remarks,
        int $updatedBy,
        Carbon $happenedAt
    ): array {
        return [
            'old_status' => $oldStatus,
            'new_status' => $newStatus,
            'remarks' => $remarks,
            'updated_by' => $updatedBy,
            'created_at' => $happenedAt->toDateTimeString(),
            'updated_at' => $happenedAt->toDateTimeString(),
        ];
    }

    private function createdAtForSequence(int $sequence): Carbon
    {
        $daysAgo = ($sequence * 17) % 330;
        $hour = 7 + (($sequence * 5) % 12);
        $minute = ($sequence * 11) % 60;

        return now()
            ->subDays($daysAgo)
            ->setTime($hour, $minute, 0)
            ->startOfMinute();
    }

    private function statusForDate(Carbon $createdAt, int $sequence): string
    {
        $daysOpen = (int) $createdAt->diffInDays(now());

        if ($daysOpen <= 7) {
            return $this->pickFrom(['New', 'Pending', 'In Progress'], $sequence);
        }

        if ($daysOpen <= 30) {
            return $this->pickFrom(['Pending', 'In Progress', 'Resolved', 'Resolved'], $sequence);
        }

        if ($daysOpen <= 90) {
            return $this->pickFrom(['Pending', 'In Progress', 'Resolved', 'Resolved', 'Rejected'], $sequence);
        }

        return $this->pickFrom(['Resolved', 'Resolved', 'Resolved', 'In Progress', 'Pending', 'Rejected'], $sequence);
    }

    private function priorityForProfile(array $profile, string $status, int $sequence): string
    {
        $priority = $this->pickFrom($profile['priority_pool'], $sequence + 9);

        if ($status === 'Rejected' && $priority === 'Urgent') {
            return 'High';
        }

        if ($status === 'New' && $priority === 'Low' && $sequence % 5 === 0) {
            return 'Normal';
        }

        return $priority;
    }

    /**
     * @param Collection<string, Office> $officeByName
     * @return Collection<int, array<string, mixed>>
     */
    private function availableProfiles(Collection $officeByName): Collection
    {
        $available = collect(self::SCENARIOS)
            ->filter(fn (array $profile) => $officeByName->has(mb_strtolower(trim((string) $profile['office']))))
            ->values();

        if ($available->isEmpty()) {
            $available = collect(self::SCENARIOS);
        }

        return $available->flatMap(function (array $profile) {
            return array_fill(0, max(1, (int) ($profile['weight'] ?? 1)), $profile);
        })->values();
    }

    /**
     * @param Collection<string, Category> $categoryByName
     * @param Collection<int, Category> $categories
     */
    private function resolveCategoryForProfile(
        array $profile,
        Collection $categoryByName,
        Collection $categories,
        int $sequence
    ): ?Category {
        $matches = collect($profile['category_candidates'])
            ->map(fn (string $name) => $categoryByName->get(mb_strtolower(trim($name))))
            ->filter()
            ->values();

        if ($matches->isNotEmpty()) {
            return $matches[$sequence % $matches->count()];
        }

        return $categories->isEmpty()
            ? null
            : $categories[$sequence % $categories->count()];
    }

    /**
     * @return Collection<int, User>
     */
    private function realCitizenPool(): Collection
    {
        return $this->demoAccounts
            ->scopeRealUsers(
                User::query()
                    ->where('role', 'citizen')
                    ->where('is_active', true)
                    ->whereNull('deleted_at')
                    ->orderBy('id')
            )
            ->get(['id', 'name', 'email', 'mobile_number', 'role', 'is_active', 'deleted_at']);
    }

    /**
     * @return Collection<int, User>
     */
    private function adminPool(): Collection
    {
        return $this->demoAccounts
            ->scopeRealUsers(
                User::query()
                    ->whereIn('role', ['admin', 'super_admin'])
                    ->where('is_active', true)
                    ->whereNull('deleted_at')
                    ->orderBy('role')
                    ->orderBy('id')
            )
            ->get(['id', 'name', 'role', 'department', 'job_title', 'is_active', 'deleted_at']);
    }

    private function pickFrom(array $values, int $seed): mixed
    {
        if ($values === []) {
            return null;
        }

        return $values[$seed % count($values)];
    }

    private function headline(string $value): string
    {
        $value = $this->squish($value);
        $parts = array_filter(explode(' ', $value), fn (string $part) => $part !== '');

        return implode(' ', array_map(function (string $part) {
            $segments = explode('-', $part);
            $segments = array_map(
                fn (string $segment) => $segment === '' ? $segment : ucfirst(mb_strtolower($segment)),
                $segments
            );

            return implode('-', $segments);
        }, $parts));
    }

    private function clipText(string $value, int $limit): string
    {
        $value = $this->squish($value);
        if (mb_strlen($value) <= $limit) {
            return $value;
        }

        $truncated = rtrim(mb_substr($value, 0, max(1, $limit - 1)));

        return rtrim($truncated, " ,.;:-").'.';
    }

    private function squish(string $value): string
    {
        $trimmed = trim($value);
        $normalized = preg_replace('/\s+/', ' ', $trimmed);

        return $normalized === null ? $trimmed : $normalized;
    }

    private function incrementSummaryCount(array &$counts, string $key): void
    {
        $counts[$key] = (int) ($counts[$key] ?? 0) + 1;
    }
}
