<?php

use App\Http\Controllers\Api\PasswordResetController;
use Illuminate\Support\Facades\Route;

Route::view('/', 'welcome');
Route::get('/reset-password/{token}', [PasswordResetController::class, 'showResetForm'])
    ->name('password.reset');
Route::post('/reset-password', [PasswordResetController::class, 'resetPasswordWeb'])
    ->name('password.update');
Route::get('/reset-password-success', [PasswordResetController::class, 'showResetSuccess'])
    ->name('password.reset.success');
