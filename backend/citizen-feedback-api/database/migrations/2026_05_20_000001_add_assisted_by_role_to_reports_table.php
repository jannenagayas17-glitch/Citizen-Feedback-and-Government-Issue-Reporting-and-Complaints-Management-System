<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            if (! Schema::hasColumn('reports', 'assisted_by_role')) {
                $table->string('assisted_by_role')
                    ->nullable()
                    ->after('assisted_by_user_id');
            }
        });
    }

    public function down(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            if (Schema::hasColumn('reports', 'assisted_by_role')) {
                $table->dropColumn('assisted_by_role');
            }
        });
    }
};
