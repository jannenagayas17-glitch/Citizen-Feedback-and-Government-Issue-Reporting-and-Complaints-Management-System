<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\PasswordResetController;
use App\Http\Controllers\Api\OfficeController;
use App\Http\Controllers\Api\CategoryController;
use App\Http\Controllers\Api\ReportController;
use App\Http\Controllers\Api\ReportImageController;
use App\Http\Controllers\Api\DashboardController;
use App\Http\Controllers\Api\CitizenFeedbackController;
use App\Http\Controllers\Api\SystemSettingController;
use App\Http\Controllers\Api\EscalationController;

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
Route::get('/offices', [OfficeController::class, 'index']);
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
    Route::put('/user/profile', [AuthController::class, 'updateProfile']);
    Route::match(['put', 'post'], '/user/password', [AuthController::class, 'changePassword'])
        ->name('api/user/password');

    Route::post('/logout', [AuthController::class, 'logout']);


    /*
    |--------------------------------------------------------------------------
    | Reports / Complaints
    |--------------------------------------------------------------------------
    */

    Route::prefix('reports')->group(function () {

        Route::post('/', [ReportController::class, 'store']);        // submit complaint
        Route::post('/request-verification', [ReportController::class, 'requestSubmissionVerification']);
        Route::post('/verify-and-store', [ReportController::class, 'verifySubmissionAndStore']);
        Route::get('/', [ReportController::class, 'index']);         // user complaints
        Route::get('/{id}', [ReportController::class, 'show']);      // complaint details
        Route::post('/{id}/images', [ReportImageController::class, 'store']);

    });

    Route::prefix('feedback')->group(function () {
        Route::get('/', [CitizenFeedbackController::class, 'index']);
        Route::post('/', [CitizenFeedbackController::class, 'store']);
        Route::get('/export', [CitizenFeedbackController::class, 'export']);
    });


    /*
    |--------------------------------------------------------------------------
    | Dashboard
    |--------------------------------------------------------------------------
    */

    Route::get('/dashboard', [DashboardController::class, 'index']);
    Route::get('/admin/analytics', [DashboardController::class, 'analytics']);


    /*
    |--------------------------------------------------------------------------
    | Admin Controls
    |--------------------------------------------------------------------------
    */

    Route::prefix('admin')->group(function () {

        Route::get('/reports', [ReportController::class, 'adminReports']);
        Route::get('/reports/export', [ReportController::class, 'exportAdminReports']);
        Route::post('/reports/{id}/status', [ReportController::class, 'updateStatus']);
        Route::get('/users', [AuthController::class, 'adminUsers']);
        Route::post('/users', [AuthController::class, 'storeManagedAccount']);
        Route::put('/users/{id}', [AuthController::class, 'updateManagedAccount']);
        Route::get('/offices', [OfficeController::class, 'index']);
        Route::post('/offices', [OfficeController::class, 'store']);

        Route::post('/verify-account/{id}', [AuthController::class, 'verifyAccount']);

        Route::post('/deactivate-account/{id}', [AuthController::class, 'deactivateAccount']);
        Route::post('/reactivate-account/{id}', [AuthController::class, 'reactivateAccount']);
        Route::delete('/delete-account/{id}', [AuthController::class, 'deleteAccount']);
        Route::get('/settings', [SystemSettingController::class, 'show']);
        Route::put('/settings', [SystemSettingController::class, 'update']);
        Route::get('/escalations', [EscalationController::class, 'index']);
        Route::post('/escalations/{report}', [EscalationController::class, 'update']);

    });

});
