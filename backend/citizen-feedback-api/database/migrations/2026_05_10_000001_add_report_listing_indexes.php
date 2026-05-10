<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->index('created_at', 'reports_created_at_index');
            $table->index('resolved_at', 'reports_resolved_at_index');
            $table->index('status', 'reports_status_index');
            $table->index(['office_id', 'created_at'], 'reports_office_created_at_index');
            $table->index(['office_id', 'status'], 'reports_office_status_index');
        });
    }

    public function down(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->dropIndex('reports_created_at_index');
            $table->dropIndex('reports_resolved_at_index');
            $table->dropIndex('reports_status_index');
            $table->dropIndex('reports_office_created_at_index');
            $table->dropIndex('reports_office_status_index');
        });
    }
};
