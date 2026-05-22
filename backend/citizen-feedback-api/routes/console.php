<?php

use App\Support\DemoAccountService;
use App\Support\RealisticComplaintSeedService;
use App\Support\RealisticFeedbackSeedService;
use App\Support\UserEmailDeduplicationService;
use Illuminate\Foundation\Inspiring;
use Illuminate\Support\Facades\Artisan;

Artisan::command('inspire', function () {
    $this->comment(Inspiring::quote());
})->purpose('Display an inspiring quote');

Artisan::command('users:dedupe {--apply : Reassign related records and archive duplicate users} {--dry-run : Preview duplicate users without changing data} {--email=* : Limit the report to specific normalized email addresses}', function (UserEmailDeduplicationService $deduplicator) {
    $apply = (bool) $this->option('apply');
    $dryRun = (bool) $this->option('dry-run');

    if ($apply && $dryRun) {
        $this->error('Choose either --apply or --dry-run. Running without flags already defaults to a dry run.');

        return 1;
    }

    $mode = $apply ? 'apply' : 'dry-run';
    $emails = collect($this->option('email'))
        ->map(fn ($email) => $deduplicator->normalizeEmail($email))
        ->filter()
        ->values()
        ->all();

    $report = $apply
        ? $deduplicator->applyDuplicateEmailCleanup($emails)
        : $deduplicator->buildDuplicateEmailReport($emails);

    $report['mode'] = $mode;
    $auditLogPath = $deduplicator->writeAuditLog($report, $mode);

    $this->info('User duplicate email cleanup: '.strtoupper($mode));
    $this->line('Duplicate normalized email groups found: '.$report['group_count']);
    $this->line('Applicable groups: '.$report['applicable_group_count']);
    $this->line('Risky groups: '.$report['risky_group_count']);

    if (($report['groups'] ?? []) === []) {
        $this->line('No duplicate normalized emails were found.');
        $this->line('Audit log: storage/app/'.$auditLogPath);

        return 0;
    }

    foreach ($report['groups'] as $group) {
        $this->newLine();
        $this->line('Email: '.$group['normalized_email']);
        $this->line('Keeper user ID: '.($group['keeper_user_id'] ?? 'n/a'));
        $this->line('User IDs: '.implode(', ', $group['user_ids'] ?? []));

        if (($group['stored_email_variants'] ?? []) !== []) {
            $this->line('Stored variants: '.implode(', ', $group['stored_email_variants']));
        }

        $records = $group['group_related_records'] ?? [];
        if ($records !== []) {
            $this->line(
                'Would reassign business records and revoke auth artifacts: reports.user_id='.$records['reports.user_id']
                .', reports.assigned_to='.$records['reports.assigned_to']
                .', citizen_feedback.user_id='.$records['citizen_feedback.user_id']
                .', admin_responses.user_id='.$records['admin_responses.user_id']
                .', status_histories.updated_by='.$records['status_histories.updated_by']
                .', report_escalations.acted_by='.$records['report_escalations.acted_by']
                .', sessions='.$records['sessions.user_id']
                .', personal_access_tokens='.$records['personal_access_tokens']
            );
        }

        if (($group['risk_reasons'] ?? []) !== []) {
            $this->warn('Skipped from apply: '.implode(' ', $group['risk_reasons']));
        } else {
            $this->info(
                $apply
                    ? 'Applied safely: duplicate users were archived with soft deletes only.'
                    : 'Dry run only: no database rows were changed.'
            );
        }
    }

    if ($apply) {
        $this->newLine();
        $this->info('Applied groups: '.($report['applied_group_count'] ?? 0));
        if (($report['skipped_apply_groups'] ?? []) !== []) {
            $this->warn('Some groups were skipped during apply:');
            foreach ($report['skipped_apply_groups'] as $skippedGroup) {
                $this->line('- '.$skippedGroup['normalized_email'].': '.$skippedGroup['reason']);
            }
        }
    }

    $this->newLine();
    $this->line('Audit log: storage/app/'.$auditLogPath);
    $this->line('No complaints, reports, feedback, attachments, or status history records were deleted by this command.');

    return 0;
})->purpose('Preview or safely merge duplicate users grouped by normalized email');

Artisan::command('users:cleanup-demo {--apply : Archive known seeded demo accounts} {--dry-run : Preview matched demo accounts without changing data}', function (DemoAccountService $demoAccounts) {
    $apply = (bool) $this->option('apply');
    $dryRun = (bool) $this->option('dry-run');

    if ($apply && $dryRun) {
        $this->error('Choose either --apply or --dry-run. Running without flags already defaults to a dry run.');

        return 1;
    }

    $mode = $apply ? 'apply' : 'dry-run';
    $previewUsers = $demoAccounts->previewDemoUsers();
    $preview = $demoAccounts->summarizePreview($previewUsers);

    $this->info('Demo account cleanup: '.strtoupper($mode));
    $this->line('Matched demo accounts: '.$preview['matched_count']);
    $this->line(
        'Role counts: citizen='.$preview['role_counts']['citizen']
        .', admin='.$preview['role_counts']['admin']
        .', pending_admin='.$preview['role_counts']['pending_admin']
        .', super_admin='.$preview['role_counts']['super_admin']
        .', other='.$preview['role_counts']['other']
    );

    if ($preview['matched_count'] === 0) {
        $this->line('No seeded demo accounts matched the protected cleanup patterns.');
        $this->line('No real accounts, reports, feedback, complaints, attachments, or analytics rows were modified.');

        return 0;
    }

    foreach ($preview['emails'] as $email) {
        $this->line('- '.$email);
    }

    if (! $apply) {
        $this->newLine();
        $this->info('Dry run only: no database rows were changed.');
        $this->line('Protected patterns only match known seeded demo addresses.');

        return 0;
    }

    $result = $demoAccounts->archiveDemoUsers();

    $this->newLine();
    $this->info('Archived demo accounts: '.$result['archived_count']);
    $this->line('Already archived demo accounts: '.$result['already_archived_count']);
    $this->line('Deactivated demo accounts: '.$result['deactivated_count']);
    $this->line('No real accounts, reports, feedback, complaints, attachments, or analytics rows were deleted by this command.');
    $this->line('Demo-owned records remain preserved and are filtered out of portal views.');

    return 0;
})->purpose('Preview or safely archive known seeded demo accounts');

Artisan::command('complaints:seed-realistic {--count=3000 : Number of realistic complaint records to insert} {--batch=250 : Number of reports to insert per transaction batch} {--force : Skip the safety confirmation prompt}', function (RealisticComplaintSeedService $seedService) {
    $count = (int) $this->option('count');
    $batchSize = (int) $this->option('batch');
    $force = (bool) $this->option('force');

    if ($count < 1) {
        $this->error('The complaint count must be at least 1.');

        return 1;
    }

    if ($batchSize < 1) {
        $this->error('The batch size must be at least 1.');

        return 1;
    }

    try {
        $context = $seedService->describeContext();
    } catch (\Throwable $exception) {
        $this->error($exception->getMessage());

        return 1;
    }

    $this->info('Realistic complaint seeding preview');
    $this->line('Active real citizens: '.$context['citizen_count']);
    $this->line('Active offices: '.$context['office_count']);
    $this->line('Categories: '.$context['category_count']);
    $this->line('Active admins: '.$context['admin_count']);
    $this->line('Active super admins: '.$context['super_admin_count']);
    $this->line('Requested insert count: '.$count);
    $this->line('Batch size: '.$batchSize);
    $this->line('This command appends real report rows only. It does not delete, truncate, or reset existing data.');

    if (! $force && ! $this->confirm('Continue and insert realistic complaint records into the current database?', false)) {
        $this->warn('Cancelled. No database rows were changed.');

        return 1;
    }

    try {
        $summary = $seedService->seed($count, $batchSize);
    } catch (\Throwable $exception) {
        $this->error($exception->getMessage());

        return 1;
    }

    $this->newLine();
    $this->info('Realistic complaint seeding completed successfully.');
    $this->line('Reports before: '.$summary['reports_before']);
    $this->line('Reports after: '.$summary['reports_after']);
    $this->line('Report delta: '.$summary['reports_delta']);
    $this->line('Reports created: '.$summary['created_count']);
    $this->line('Status history rows created: '.$summary['status_histories_created']);
    $this->line('Admin response rows created: '.$summary['admin_responses_created']);
    $this->line('Citizens used: '.$summary['citizen_count_used']);

    if (($summary['generated_start'] ?? null) instanceof \Illuminate\Support\Carbon && ($summary['generated_end'] ?? null) instanceof \Illuminate\Support\Carbon) {
        $this->line(
            'Generated complaint date range: '
            .$summary['generated_start']->toDateString()
            .' to '
            .$summary['generated_end']->toDateString()
        );
    }

    $this->newLine();
    $this->line('Departments used:');
    foreach ($summary['office_counts'] as $officeName => $officeCount) {
        $this->line('- '.$officeName.': '.$officeCount);
    }

    $this->newLine();
    $this->line('Statuses generated:');
    foreach ($summary['status_counts'] as $status => $statusCount) {
        $this->line('- '.$status.': '.$statusCount);
    }

    $this->newLine();
    $this->line('Priorities generated:');
    foreach ($summary['priority_counts'] as $priority => $priorityCount) {
        $this->line('- '.$priority.': '.$priorityCount);
    }

    $this->newLine();
    $this->line('No existing users, reports, feedback, media, analytics, profile images, or relationships were deleted by this command.');

    return 0;
})->purpose('Safely append realistic complaint records for analytics and report testing');

Artisan::command('feedback:seed-realistic {--count=300 : Number of realistic feedback records to insert} {--batch=100 : Number of feedback rows to insert per transaction batch} {--force : Skip the safety confirmation prompt}', function (RealisticFeedbackSeedService $seedService) {
    $count = (int) $this->option('count');
    $batchSize = (int) $this->option('batch');
    $force = (bool) $this->option('force');

    if ($count < 1) {
        $this->error('The feedback count must be at least 1.');

        return 1;
    }

    if ($batchSize < 1) {
        $this->error('The batch size must be at least 1.');

        return 1;
    }

    try {
        $context = $seedService->describeContext();
    } catch (\Throwable $exception) {
        $this->error($exception->getMessage());

        return 1;
    }

    $this->info('Realistic feedback seeding preview');
    $this->line('Existing feedback rows: '.$context['feedback_count']);
    $this->line('Eligible real reports without linked feedback: '.$context['eligible_report_count']);
    $this->line('Eligible citizens: '.$context['citizen_count']);
    $this->line('Eligible departments: '.$context['office_count']);
    $this->line('Requested insert count: '.$count);
    $this->line('Batch size: '.$batchSize);
    $this->line('This command appends real feedback rows only. It does not delete, truncate, or reset existing data.');

    if (! $force && ! $this->confirm('Continue and insert realistic feedback records into the current database?', false)) {
        $this->warn('Cancelled. No database rows were changed.');

        return 1;
    }

    try {
        $summary = $seedService->seed($count, $batchSize);
    } catch (\Throwable $exception) {
        $this->error($exception->getMessage());

        return 1;
    }

    $this->newLine();
    $this->info('Realistic feedback seeding completed successfully.');
    $this->line('Feedback before: '.$summary['feedback_before']);
    $this->line('Feedback after: '.$summary['feedback_after']);
    $this->line('Feedback delta: '.$summary['feedback_delta']);
    $this->line('Feedback created: '.$summary['created_count']);
    $this->line('Reports linked: '.$summary['reports_linked']);
    $this->line('Citizens used: '.$summary['citizen_count_used']);

    if (($summary['generated_start'] ?? null) instanceof \Illuminate\Support\Carbon && ($summary['generated_end'] ?? null) instanceof \Illuminate\Support\Carbon) {
        $this->line(
            'Generated feedback date range: '
            .$summary['generated_start']->toDateString()
            .' to '
            .$summary['generated_end']->toDateString()
        );
    }

    $this->newLine();
    $this->line('Departments used:');
    foreach ($summary['office_counts'] as $officeName => $officeCount) {
        $this->line('- '.$officeName.': '.$officeCount);
    }

    $this->newLine();
    $this->line('Rating distribution:');
    foreach ($summary['rating_counts'] as $rating => $ratingCount) {
        $this->line('- '.$rating.' star'.($rating === '1' ? '' : 's').': '.$ratingCount);
    }

    $this->newLine();
    $this->line('Feedback types generated:');
    foreach ($summary['type_counts'] as $type => $typeCount) {
        $this->line('- '.$type.': '.$typeCount);
    }

    $this->newLine();
    $this->line('No existing users, reports, feedback, media, analytics, profile images, or relationships were deleted by this command.');

    return 0;
})->purpose('Safely append realistic feedback records for feedback analytics and portal testing');
