<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('report_images', function (Blueprint $table) {
            if (! Schema::hasColumn('report_images', 'media_type')) {
                $table->string('media_type')->default('image')->after('image_path');
            }

            if (! Schema::hasColumn('report_images', 'original_name')) {
                $table->string('original_name')->nullable()->after('media_type');
            }
        });

        DB::table('report_images')
            ->whereNull('original_name')
            ->orWhere('original_name', '')
            ->update([
                'media_type' => 'image',
                'original_name' => DB::raw('image_path'),
            ]);
    }

    public function down(): void
    {
        Schema::table('report_images', function (Blueprint $table) {
            if (Schema::hasColumn('report_images', 'original_name')) {
                $table->dropColumn('original_name');
            }

            if (Schema::hasColumn('report_images', 'media_type')) {
                $table->dropColumn('media_type');
            }
        });
    }
};
