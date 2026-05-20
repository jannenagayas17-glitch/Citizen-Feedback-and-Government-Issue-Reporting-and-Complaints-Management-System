<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class UserProfileImageTest extends TestCase
{
    use RefreshDatabase;

    private const PASSWORD = 'password123';

    private const TINY_PNG_BASE64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a5i0AAAAASUVORK5CYII=';

    public function test_authenticated_user_can_upload_a_profile_photo_and_fetch_it_again(): void
    {
        Storage::fake('public');

        $user = $this->makeUser('Citizen User', 'citizen@example.com', 'citizen');
        Sanctum::actingAs($user);

        $uploadResponse = $this->post('/api/user/profile-image', [
            'profile_image' => $this->fakePngUpload('citizen-profile.png'),
        ]);

        $uploadResponse
            ->assertOk()
            ->assertJsonPath('message', 'Profile photo updated successfully.');

        $storedPath = $uploadResponse->json('user.profile_image_path');
        $profileImageUrl = $uploadResponse->json('user.profile_image_url');

        $this->assertNotNull($storedPath);
        $this->assertNotNull($profileImageUrl);
        Storage::disk('public')->assertExists($storedPath);

        $this->assertDatabaseHas('users', [
            'id' => $user->id,
            'profile_image_path' => $storedPath,
        ]);

        $this->getJson('/api/user')
            ->assertOk()
            ->assertJsonPath('profile_image_path', $storedPath)
            ->assertJsonPath('profile_image_url', $profileImageUrl);

        $this->get('/api/profile-images/'.$storedPath)
            ->assertOk()
            ->assertHeader('content-type', 'image/png');
    }

    public function test_uploading_a_new_profile_photo_replaces_the_previous_file_and_persists_after_login(): void
    {
        Storage::fake('public');

        $user = $this->makeUser('Citizen User', 'citizen@example.com', 'citizen');
        Sanctum::actingAs($user);

        $firstUpload = $this->post('/api/user/profile-image', [
            'profile_image' => $this->fakePngUpload('first-profile.png'),
        ])->assertOk();

        $firstPath = $firstUpload->json('user.profile_image_path');
        Storage::disk('public')->assertExists($firstPath);

        $secondUpload = $this->post('/api/user/profile-image', [
            'profile_image' => $this->fakePngUpload('second-profile.png'),
        ])->assertOk();

        $secondPath = $secondUpload->json('user.profile_image_path');

        $this->assertNotSame($firstPath, $secondPath);
        Storage::disk('public')->assertMissing($firstPath);
        Storage::disk('public')->assertExists($secondPath);

        $this->postJson('/api/logout')->assertOk();

        $this->postJson('/api/auth/login', [
            'email' => $user->email,
            'password' => self::PASSWORD,
        ])
            ->assertOk()
            ->assertJsonPath('user.profile_image_path', $secondPath)
            ->assertJsonPath(
                'user.profile_image_url',
                url('/api/profile-images/'.$secondPath)
            );
    }

    private function makeUser(string $name, string $email, string $role): User
    {
        return User::create([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make(self::PASSWORD),
            'role' => $role,
            'is_active' => true,
        ]);
    }

    private function fakePngUpload(string $fileName): UploadedFile
    {
        return UploadedFile::fake()->createWithContent(
            $fileName,
            base64_decode(self::TINY_PNG_BASE64, true) ?: ''
        );
    }
}
