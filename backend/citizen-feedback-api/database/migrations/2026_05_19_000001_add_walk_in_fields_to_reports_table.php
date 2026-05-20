<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            if (! Schema::hasColumn('reports', 'source')) {
                $table->string('source')->default('citizen_app')->after('is_anonymous');
            }

            if (! Schema::hasColumn('reports', 'assisted_by_user_id')) {
                $table->foreignId('assisted_by_user_id')
                    ->nullable()
                    ->after('source')
                    ->constrained('users')
                    ->nullOnDelete();
            }

            if (! Schema::hasColumn('reports', 'walk_in_full_name')) {
                $table->string('walk_in_full_name')->nullable()->after('assisted_by_user_id');
            }

            if (! Schema::hasColumn('reports', 'walk_in_contact_number')) {
                $table->string('walk_in_contact_number', 30)->nullable()->after('walk_in_full_name');
            }

            if (! Schema::hasColumn('reports', 'walk_in_email')) {
                $table->string('walk_in_email')->nullable()->after('walk_in_contact_number');
            }

            if (! Schema::hasColumn('reports', 'walk_in_address')) {
                $table->string('walk_in_address')->nullable()->after('walk_in_email');
            }

            if (! Schema::hasColumn('reports', 'walk_in_is_senior_citizen')) {
                $table->boolean('walk_in_is_senior_citizen')->default(false)->after('walk_in_address');
            }

            if (! Schema::hasColumn('reports', 'walk_in_is_pwd')) {
                $table->boolean('walk_in_is_pwd')->default(false)->after('walk_in_is_senior_citizen');
            }

            if (! Schema::hasColumn('reports', 'expected_return_at')) {
                $table->timestamp('expected_return_at')->nullable()->after('walk_in_is_pwd');
            }

            if (! Schema::hasColumn('reports', 'printable_reference_number')) {
                $table->string('printable_reference_number')->nullable()->after('expected_return_at');
            }
        });
    }

    public function down(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            if (Schema::hasColumn('reports', 'assisted_by_user_id')) {
                $table->dropConstrainedForeignId('assisted_by_user_id');
            }

            foreach ([
                'source',
                'walk_in_full_name',
                'walk_in_contact_number',
                'walk_in_email',
                'walk_in_address',
                'walk_in_is_senior_citizen',
                'walk_in_is_pwd',
                'expected_return_at',
                'printable_reference_number',
            ] as $column) {
                if (Schema::hasColumn('reports', $column)) {
                    $table->dropColumn($column);
                }
            }
        });
    }
};
