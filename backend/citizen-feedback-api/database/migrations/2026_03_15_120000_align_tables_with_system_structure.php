<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            if (! Schema::hasColumn('users', 'mobile_number')) {
                $table->string('mobile_number', 30)->nullable()->after('email');
            }

            if (! Schema::hasColumn('users', 'department')) {
                $table->string('department')->nullable()->after('role');
            }

            if (! Schema::hasColumn('users', 'job_title')) {
                $table->string('job_title')->nullable()->after('department');
            }

            if (! Schema::hasColumn('users', 'firebase_uid')) {
                $table->string('firebase_uid')->nullable()->unique()->after('job_title');
            }
        });

        Schema::table('reports', function (Blueprint $table) {
            if (! Schema::hasColumn('reports', 'barangay')) {
                $table->string('barangay')->nullable()->after('location');
            }

            if (! Schema::hasColumn('reports', 'latitude')) {
                $table->decimal('latitude', 10, 7)->nullable()->after('barangay');
            }

            if (! Schema::hasColumn('reports', 'longitude')) {
                $table->decimal('longitude', 10, 7)->nullable()->after('latitude');
            }

            if (! Schema::hasColumn('reports', 'priority')) {
                $table->string('priority')->default('Normal')->after('status');
            }

            if (! Schema::hasColumn('reports', 'assigned_to')) {
                $table->foreignId('assigned_to')->nullable()->after('priority')
                    ->constrained('users')->nullOnDelete();
            }

            if (! Schema::hasColumn('reports', 'resolved_at')) {
                $table->timestamp('resolved_at')->nullable()->after('assigned_to');
            }
        });

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE reports MODIFY status VARCHAR(255) NOT NULL DEFAULT 'New'");
        }
    }

    public function down(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            if (Schema::hasColumn('reports', 'assigned_to')) {
                $table->dropConstrainedForeignId('assigned_to');
            }

            $columns = ['barangay', 'latitude', 'longitude', 'priority', 'resolved_at'];
            foreach ($columns as $column) {
                if (Schema::hasColumn('reports', $column)) {
                    $table->dropColumn($column);
                }
            }
        });

        Schema::table('users', function (Blueprint $table) {
            if (Schema::hasColumn('users', 'firebase_uid')) {
                $table->dropUnique(['firebase_uid']);
                $table->dropColumn('firebase_uid');
            }

            $columns = ['mobile_number', 'department', 'job_title'];
            foreach ($columns as $column) {
                if (Schema::hasColumn('users', $column)) {
                    $table->dropColumn($column);
                }
            }
        });

        if (in_array(DB::getDriverName(), ['mysql', 'mariadb'], true)) {
            DB::statement("ALTER TABLE reports MODIFY status VARCHAR(255) NOT NULL DEFAULT 'Pending'");
        }
    }
};
