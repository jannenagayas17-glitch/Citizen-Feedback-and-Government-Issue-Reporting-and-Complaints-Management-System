<?php

use App\Support\DemoAccountService;
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
