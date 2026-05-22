<?php

namespace App\Support;

use App\Models\CitizenFeedback;
use App\Models\Report;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use RuntimeException;

class RealisticFeedbackSeedService
{
    public const DEFAULT_BATCH_SIZE = 100;

    /**
     * @var array<string, list<string>>
     */
    private const MESSAGE_TEMPLATES = [
        'Praise' => [
            'The complaint about %s was handled quickly by %s. Thank you.',
            'The update from %s about %s was clear and helpful.',
            '%s responded professionally and kept me informed about %s.',
            'The issue with %s was resolved after follow-up. %s did a good job.',
            'The process for %s was easy to understand because of %s.',
        ],
        'Suggestion' => [
            'The response for %s was helpful, but %s can send updates faster next time.',
            'I hope %s can share clearer next steps for %s in future updates.',
            'The process for %s was okay. %s could improve response timing.',
            'The update helped me understand %s. More frequent notices from %s would help.',
            '%s explained %s well, but the timeline could be clearer next time.',
        ],
        'Complaint' => [
            'I had to follow up more than once before %s gave an update on %s.',
            'The complaint about %s was received, but %s took longer than expected.',
            'The service for %s needs improvement because %s responded slowly.',
            'I hope %s can improve how it handles %s moving forward.',
            'The update for %s was useful, but %s should respond sooner next time.',
        ],
    ];

    public function __construct(
        private readonly DemoAccountService $demoAccounts,
    ) {
    }

    public function describeContext(): array
    {
        $eligibleReports = $this->eligibleReportsQuery();
        $eligibleReportCount = (clone $eligibleReports)->count();
        $citizenCount = (clone $eligibleReports)->distinct('reports.user_id')->count('reports.user_id');
        $officeCount = (clone $eligibleReports)->distinct('reports.office_id')->count('reports.office_id');

        return [
            'eligible_report_count' => $eligibleReportCount,
            'citizen_count' => $citizenCount,
            'office_count' => $officeCount,
            'feedback_count' => (int) CitizenFeedback::query()->count(),
        ];
    }

    public function seed(int $count, int $batchSize = self::DEFAULT_BATCH_SIZE): array
    {
        if ($count < 1) {
            throw new RuntimeException('The feedback count must be at least 1.');
        }

        $batchSize = max(1, min($batchSize, $count));
        $reports = $this->eligibleReportsQuery()
            ->with([
                'user:id,name,email',
                'office:id,name',
            ])
            ->orderBy('reports.created_at')
            ->orderBy('reports.id')
            ->limit($count)
            ->get([
                'reports.id',
                'reports.user_id',
                'reports.office_id',
                'reports.title',
                'reports.status',
                'reports.created_at',
                'reports.updated_at',
            ]);

        if ($reports->count() < $count) {
            throw new RuntimeException(
                sprintf(
                    'Only %d eligible real reports without linked feedback are available. Reduce --count or create more real complaints first.',
                    $reports->count(),
                ),
            );
        }

        $summary = [
            'requested_count' => $count,
            'created_count' => 0,
            'feedback_before' => (int) CitizenFeedback::query()->count(),
            'feedback_after' => 0,
            'feedback_delta' => 0,
            'office_counts' => [],
            'rating_counts' => [],
            'type_counts' => [],
            'citizen_ids_used' => [],
            'report_ids_linked' => [],
            'generated_start' => null,
            'generated_end' => null,
        ];

        $sequence = 0;

        $reports->chunk($batchSize)->values()->each(function (Collection $chunk) use (&$sequence, &$summary) {
            DB::transaction(function () use ($chunk, &$sequence, &$summary) {
                $rows = [];

                foreach ($chunk->values() as $report) {
                    if (! $report instanceof Report) {
                        continue;
                    }

                    $sequence++;
                    $blueprint = $this->buildFeedbackBlueprint($report, $sequence);

                    $rows[] = $blueprint['attributes'];
                    $summary['created_count']++;
                    $summary['citizen_ids_used'][$report->user_id] = true;
                    $summary['report_ids_linked'][$report->id] = true;
                    $this->incrementSummaryCount($summary['office_counts'], $blueprint['office_name']);
                    $this->incrementSummaryCount($summary['rating_counts'], (string) $blueprint['attributes']['rating']);
                    $this->incrementSummaryCount($summary['type_counts'], $blueprint['attributes']['type']);
                    $summary['generated_start'] = $summary['generated_start'] === null
                        || $blueprint['created_at']->lt($summary['generated_start'])
                        ? $blueprint['created_at']->copy()
                        : $summary['generated_start'];
                    $summary['generated_end'] = $summary['generated_end'] === null
                        || $blueprint['updated_at']->gt($summary['generated_end'])
                        ? $blueprint['updated_at']->copy()
                        : $summary['generated_end'];
                }

                if ($rows !== []) {
                    CitizenFeedback::query()->insert($rows);
                }
            }, 3);
        });

        ksort($summary['office_counts']);
        ksort($summary['rating_counts']);
        ksort($summary['type_counts']);

        $summary['citizen_ids_used'] = array_map('intval', array_keys($summary['citizen_ids_used']));
        sort($summary['citizen_ids_used']);
        $summary['report_ids_linked'] = array_map('intval', array_keys($summary['report_ids_linked']));
        sort($summary['report_ids_linked']);
        $summary['citizen_count_used'] = count($summary['citizen_ids_used']);
        $summary['reports_linked'] = count($summary['report_ids_linked']);
        $summary['feedback_after'] = (int) CitizenFeedback::query()->count();
        $summary['feedback_delta'] = $summary['feedback_after'] - $summary['feedback_before'];

        return $summary;
    }

    private function eligibleReportsQuery(): Builder
    {
        return Report::query()
            ->whereIn('reports.user_id', $this->realCitizenIdsQuery())
            ->whereNotNull('reports.office_id')
            ->where('reports.created_at', '>=', now()->subMonths(12)->startOfDay())
            ->where('reports.created_at', '<=', now()->subDays(2)->endOfDay())
            ->whereDoesntHave('feedbackEntries')
            ->whereHas('office')
            ->whereHas('user');
    }

    private function realCitizenIdsQuery(): Builder
    {
        return $this->demoAccounts
            ->scopeRealUsers(
                User::query()
                    ->select('id')
                    ->where('role', 'citizen')
                    ->where('is_active', true)
                    ->whereNull('deleted_at'),
            );
    }

    private function buildFeedbackBlueprint(Report $report, int $sequence): array
    {
        $rating = $this->ratingForReport($report, $sequence);
        $type = $this->typeForRatingAndStatus($rating, (string) $report->status, $sequence);
        $feedbackAt = $this->feedbackTimestampFor($report, $sequence);
        $updatedAt = $feedbackAt->copy()->addMinutes($sequence % 11);
        $officeName = trim((string) optional($report->office)->name);
        $resolvedOfficeName = $officeName === '' ? 'the assigned department' : $officeName;
        $subject = $this->reportSubject($report);
        $message = $this->clipText(
            sprintf(
                $this->pickFrom(self::MESSAGE_TEMPLATES[$type], $sequence + $rating),
                $subject,
                $resolvedOfficeName,
            ),
            5000,
        );

        return [
            'office_name' => $resolvedOfficeName,
            'created_at' => $feedbackAt,
            'updated_at' => $updatedAt,
            'attributes' => [
                'user_id' => $report->user_id,
                'office_id' => $report->office_id,
                'report_id' => $report->id,
                'type' => $type,
                'message' => $message,
                'rating' => $rating,
                'created_at' => $feedbackAt->toDateTimeString(),
                'updated_at' => $updatedAt->toDateTimeString(),
            ],
        ];
    }

    private function ratingForReport(Report $report, int $sequence): int
    {
        return match (trim((string) $report->status)) {
            'Resolved' => $this->pickFrom([5, 4, 4, 5, 3], $sequence),
            'In Progress' => $this->pickFrom([4, 3, 3, 2], $sequence),
            'Rejected' => $this->pickFrom([2, 1, 2, 3], $sequence),
            default => $this->pickFrom([3, 2, 4, 3], $sequence),
        };
    }

    private function typeForRatingAndStatus(int $rating, string $status, int $sequence): string
    {
        if (trim($status) === 'Rejected' || $rating <= 2) {
            return $this->pickFrom(['Complaint', 'Complaint', 'Suggestion'], $sequence + $rating);
        }

        if ($rating >= 5) {
            return $this->pickFrom(['Praise', 'Praise', 'Suggestion'], $sequence + $rating);
        }

        if ($rating === 4 && trim($status) === 'Resolved') {
            return $this->pickFrom(['Praise', 'Suggestion'], $sequence + $rating);
        }

        return $this->pickFrom(['Suggestion', 'Complaint', 'Suggestion'], $sequence + $rating);
    }

    private function feedbackTimestampFor(Report $report, int $sequence): Carbon
    {
        $windowStart = now()->subMonths(11)->startOfDay();
        $reportCreatedAt = $report->created_at instanceof Carbon
            ? $report->created_at->copy()
            : Carbon::parse((string) $report->created_at);
        $start = $reportCreatedAt->copy()->startOfDay();
        if ($start->lt($windowStart)) {
            $start = $windowStart->copy();
        }

        $baseEnd = $report->updated_at instanceof Carbon
            ? $report->updated_at->copy()
            : Carbon::parse((string) ($report->updated_at ?? $report->created_at));
        $end = $baseEnd->copy()->endOfDay();
        $latestAllowed = now()->subDays(($sequence % 10) + 1)->endOfDay();
        if ($end->gt($latestAllowed)) {
            $end = $latestAllowed->copy();
        }
        if ($end->lt($start)) {
            $end = $start->copy()->addHours(4);
        }

        $daySpan = max(0, $start->diffInDays($end));
        $offsetDays = $daySpan === 0 ? 0 : (($sequence * 13) % ($daySpan + 1));
        $timestamp = $start->copy()->addDays($offsetDays);
        $timestamp->setTime(8 + (($sequence * 3) % 10), ($sequence * 17) % 60, 0);

        if ($timestamp->gt($end)) {
            return $end->copy()->startOfMinute();
        }

        return $timestamp->startOfMinute();
    }

    private function reportSubject(Report $report): string
    {
        $title = $this->squish((string) $report->title);
        if ($title === '') {
            return 'the reported concern';
        }

        return $this->clipText(mb_strtolower($title), 72);
    }

    /**
     * @param list<int>|list<string> $values
     */
    private function pickFrom(array $values, int $seed): mixed
    {
        if ($values === []) {
            return null;
        }

        return $values[$seed % count($values)];
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
