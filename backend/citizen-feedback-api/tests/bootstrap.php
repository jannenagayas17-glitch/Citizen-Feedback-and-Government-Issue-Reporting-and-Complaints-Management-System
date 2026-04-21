<?php

$cachePath = __DIR__.DIRECTORY_SEPARATOR.'cache';

if (! is_dir($cachePath)) {
    mkdir($cachePath, 0777, true);
}

$staleCacheFiles = [
    'config.php',
    'events.php',
    'routes.php',
];

foreach ($staleCacheFiles as $file) {
    $path = $cachePath.DIRECTORY_SEPARATOR.$file;

    if (is_file($path)) {
        unlink($path);
    }
}

$testingEnvironment = [
    'APP_ENV' => 'testing',
    'APP_DEBUG' => 'true',
    'APP_CONFIG_CACHE' => 'tests/cache/config.php',
    'APP_EVENTS_CACHE' => 'tests/cache/events.php',
    'APP_PACKAGES_CACHE' => 'tests/cache/packages.php',
    'APP_ROUTES_CACHE' => 'tests/cache/routes.php',
    'APP_SERVICES_CACHE' => 'tests/cache/services.php',
    'BCRYPT_ROUNDS' => '4',
    'CACHE_STORE' => 'array',
    'DB_CONNECTION' => 'sqlite',
    'DB_DATABASE' => ':memory:',
    'MAIL_MAILER' => 'array',
    'QUEUE_CONNECTION' => 'sync',
    'SESSION_DRIVER' => 'array',
];

foreach ($testingEnvironment as $key => $value) {
    putenv("{$key}={$value}");
    $_ENV[$key] = $value;
    $_SERVER[$key] = $value;
}

require dirname(__DIR__).DIRECTORY_SEPARATOR.'vendor'.DIRECTORY_SEPARATOR.'autoload.php';
