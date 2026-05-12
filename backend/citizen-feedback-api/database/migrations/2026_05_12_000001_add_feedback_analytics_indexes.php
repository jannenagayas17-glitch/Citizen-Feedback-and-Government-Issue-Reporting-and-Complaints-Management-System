<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('citizen_feedback', function (Blueprint $table) {
            $table->index('created_at', 'citizen_feedback_created_at_index');
            $table->index('type', 'citizen_feedback_type_index');
            $table->index('rating', 'citizen_feedback_rating_index');
            $table->index(['office_id', 'created_at'], 'citizen_feedback_office_created_at_index');
        });

        Schema::table('reports', function (Blueprint $table) {
            $table->index('barangay', 'reports_barangay_index');
        });
    }

    public function down(): void
    {
        Schema::table('citizen_feedback', function (Blueprint $table) {
            $table->dropIndex('citizen_feedback_created_at_index');
            $table->dropIndex('citizen_feedback_type_index');
            $table->dropIndex('citizen_feedback_rating_index');
            $table->dropIndex('citizen_feedback_office_created_at_index');
        });

        Schema::table('reports', function (Blueprint $table) {
            $table->dropIndex('reports_barangay_index');
        });
    }
};
