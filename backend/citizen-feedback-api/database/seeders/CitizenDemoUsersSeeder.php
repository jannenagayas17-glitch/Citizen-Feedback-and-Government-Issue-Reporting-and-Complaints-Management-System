<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;

class CitizenDemoUsersSeeder extends Seeder
{
    private const PASSWORD = 'CitizenDemo123';

    private const NAMES = [
        'Vanessa Delgado',
        'Jericson Cupan',
        'Jannena Gayas',
        'Lito Fernandez',
        'Kristine Dela Cruz',
        'Arnel Soriano',
        'Michelle Lopez',
        'Noel Valdez',
        'Rhea Dizon',
        'Dennis De Guzman',
        'Camille Ortega',
        'Victor Salazar',
        'Joanna Robles',
        'Nestor Villamor',
        'Clarissa Domingo',
        'Eric Bautista',
        'Melanie Ramos',
        'Jun Marquez',
        'Aileen Francisco',
        'Rommel Reyes',
        'Leah Gonzales',
        'Patrick Medina',
        'Irene Santos',
        'Bryan Aguilar',
        'Mylene Torres',
        'Richard Aquino',
        'Hazel Navarro',
        'Gerald Castillo',
        'Diana Mendoza',
        'Ronald Flores',
        'Marielyn Abad',
        'Christian Balagtas',
        'Jessa Mae Caballero',
        'Allan Dela Pena',
        'Rochelle Enriquez',
        'Julius Ferrer',
        'Angelica Guevarra',
        'Mark Joseph Hilario',
        'Karen Ibanez',
        'Joshua Javier',
        'Marites Labadan',
        'Francis Mallari',
        'Elaine Natividad',
        'Rodel Ocampo',
        'Czarina Paloma',
        'Edgar Quinones',
        'Princess Rivera',
        'Michael Soriano',
        'Theresa Tolentino',
        'Renato Uy',
    ];

    public function run(): void
    {
        $targetCount = (int) env('DEMO_CITIZEN_COUNT', 50);
        $targetCount = max(50, $targetCount);

        for ($index = 1; $index <= $targetCount; $index++) {
            $user = User::withTrashed()->updateOrCreate(
                ['email' => sprintf('demo.citizen.%03d@example.com', $index)],
                [
                    'name' => self::NAMES[($index - 1) % count(self::NAMES)],
                    'mobile_number' => sprintf('0927%07d', $index),
                    'password' => self::PASSWORD,
                    'role' => 'citizen',
                    'department' => null,
                    'job_title' => null,
                    'is_active' => true,
                ]
            );

            if ($user->trashed()) {
                $user->restore();
            }
        }

        $this->command?->info("Citizen demo users ready: {$targetCount} citizen accounts.");
        $this->command?->info('Password for demo citizens: ' . self::PASSWORD);
    }
}
