<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\PasswordResetController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ReportImageController;
use App\Http\Controllers\Api\DashboardController;

/*
|--------------------------------------------------------------------------
| Public Routes
|--------------------------------------------------------------------------
| These routes do not require authentication
|
*/

Route::prefix('auth')->group(function () {

    // LOGIN
    Route::post('/login', [AuthController::class, 'login']);

    // REGISTER (Citizen)
    Route::post('/register', [AuthController::class, 'registerCitizen']);

    // REGISTER (Government Request)
    Route::post('/request-government-account', [AuthController::class, 'requestGovernmentAccount']);

    // GOOGLE LOGIN
    Route::post('/google-login', [AuthController::class, 'googleLogin']);

});


/*
|--------------------------------------------------------------------------
| Password Reset Routes
|--------------------------------------------------------------------------
*/

Route::post('/forgot-password', [PasswordResetController::class, 'sendResetLink']);

Route::post('/reset-password', [PasswordResetController::class, 'resetPassword']);



/*
|--------------------------------------------------------------------------
| Public Data
|--------------------------------------------------------------------------
*/

Route::get('/categories', [CategoryController::class, 'index']);
Route::get('/report-images/{path}', [ReportImageController::class, 'show'])
    ->where('path', '.*');



/*
|--------------------------------------------------------------------------
| Protected Routes
|--------------------------------------------------------------------------
| Requires authentication via Sanctum
|
*/

Route::middleware('auth:sanctum')->group(function () {

    /*
    |--------------------------------------------------------------------------
    | User
    |--------------------------------------------------------------------------
    */

    Route::get('/user', [AuthController::class, 'currentUser']);

    Route::post('/logout', [AuthController::class, 'logout']);


    /*
    |--------------------------------------------------------------------------
    | Reports / Complaints
    |--------------------------------------------------------------------------
    */

    Route::prefix('reports')->group(function () {

        Route::post('/', [ReportController::class, 'store']);        // submit complaint
        Route::get('/', [ReportController::class, 'index']);         // user complaints
        Route::get('/{id}', [ReportController::class, 'show']);      // complaint details
        Route::post('/{id}/images', [ReportImageController::class, 'store']);

    });


    /*
    |--------------------------------------------------------------------------
    | Dashboard
    |--------------------------------------------------------------------------
    */

    Route::get('/dashboard', [DashboardController::class, 'index']);


    /*
    |--------------------------------------------------------------------------
    | Admin Controls
    |--------------------------------------------------------------------------
    */

    Route::prefix('admin')->group(function () {

        Route::get('/reports', [ReportController::class, 'adminReports']);
        Route::post('/reports/{id}/status', [ReportController::class, 'updateStatus']);
        Route::get('/users', [AuthController::class, 'adminUsers']);

        Route::post('/verify-account/{id}', [AuthController::class, 'verifyAccount']);

        Route::post('/deactivate-account/{id}', [AuthController::class, 'deactivateAccount']);
        Route::post('/reactivate-account/{id}', [AuthController::class, 'reactivateAccount']);

    });

});
