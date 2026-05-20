<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('users', 'profile_image_path')) {
            Schema::table('users', function (Blueprint $table) {
                $table->string('profile_image_path')->nullable()->after('firebase_uid');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('users', 'profile_image_path')) {
            Schema::table('users', function (Blueprint $table) {
                $table->dropColumn('profile_image_path');
            });
        }
    }
};
