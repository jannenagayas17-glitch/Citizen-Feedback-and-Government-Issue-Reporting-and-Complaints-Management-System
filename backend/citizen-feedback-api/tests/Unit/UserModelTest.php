<?php

namespace Tests\Unit;

use App\Models\User;
use Tests\TestCase;

class UserModelTest extends TestCase
{
    public function test_is_active_is_cast_to_boolean(): void
    {
        $user = new User([
            'name' => 'Unit User',
            'email' => 'unit@test.com',
            'password' => 'password123',
            'is_active' => 1,
        ]);

        $this->assertIsBool($user->is_active);
        $this->assertTrue($user->is_active);
    }
}
