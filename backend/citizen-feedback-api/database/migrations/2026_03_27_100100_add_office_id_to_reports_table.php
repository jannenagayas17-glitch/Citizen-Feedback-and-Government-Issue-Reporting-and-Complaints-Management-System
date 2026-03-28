<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            if (! Schema::hasColumn('reports', 'office_id')) {
                $table->foreignId('office_id')->nullable()->after('category_id')->constrained('offices')->nullOnDelete();
            }
        });

        if (Schema::hasTable('offices') && Schema::hasTable('reports')) {
            $defaultOfficeId = DB::table('offices')
                ->where('name', "City Engineer's Office")
                ->value('id');

            if ($defaultOfficeId !== null) {
                DB::table('reports')
                    ->whereNull('office_id')
                    ->update(['office_id' => $defaultOfficeId]);
            }
        }
    }

    public function down(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            if (Schema::hasColumn('reports', 'office_id')) {
                $table->dropConstrainedForeignId('office_id');
            }
        });
    }
};
