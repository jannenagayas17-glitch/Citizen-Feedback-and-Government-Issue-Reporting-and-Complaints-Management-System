<?php

namespace Tests;

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Support\Facades\DB;
use RuntimeException;

abstract class TestCase extends BaseTestCase
{
    public function createApplication()
    {
        $app = parent::createApplication();

        $this->forceSafeTestingDatabase();
        $this->assertTestingDatabaseIsSafe($app);

        return $app;
    }

    private function forceSafeTestingDatabase(): void
    {
        config([
            'database.default' => 'sqlite',
            'database.connections.sqlite.database' => ':memory:',
            'database.connections.sqlite.foreign_key_constraints' => true,
        ]);

        DB::purge('mysql');
        DB::purge('sqlite');
    }

    private function assertTestingDatabaseIsSafe(Application $app): void
    {
        if (! $app->environment('testing')) {
            throw new RuntimeException(
                'Refusing to run tests because APP_ENV is not testing.'
            );
        }

        $connection = config('database.default');
        $database = config("database.connections.{$connection}.database");
        $isSqliteMemory = $connection === 'sqlite' && $database === ':memory:';

        if ($isSqliteMemory) {
            return;
        }

        throw new RuntimeException(sprintf(
            'Refusing to run tests on [%s] database [%s]. Tests must use sqlite :memory: so the real database is never touched.',
            $connection,
            (string) $database
        ));
    }
}
