<?php

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Office;
use App\Models\Report;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

class ReportImageUploadTest extends TestCase
{
    use RefreshDatabase;

    private const TINY_PNG_BASE64 =
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a5i0AAAAASUVORK5CYII=';

    public function test_citizen_can_upload_an_attachment_to_their_own_report(): void
    {
        Storage::fake('public');

        [$citizen, $report] = $this->seedCitizenReport();
        Sanctum::actingAs($citizen);

        $response = $this->postJson("/api/reports/{$report->id}/images", [
            'media' => $this->fakePngUpload(),
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('image.report_id', $report->id)
            ->assertJsonPath('image.media_type', 'image')
            ->assertJsonPath('image.original_name', 'evidence.png');

        $storedPath = $response->json('image.image_path');

        Storage::disk('public')->assertExists($storedPath);
        $this->assertDatabaseHas('report_images', [
            'report_id' => $report->id,
            'image_path' => $storedPath,
            'media_type' => 'image',
            'original_name' => 'evidence.png',
        ]);
    }

    public function test_citizen_cannot_upload_an_attachment_to_another_users_report(): void
    {
        Storage::fake('public');

        [, $report] = $this->seedCitizenReport();
        $otherCitizen = $this->makeUser(
            'Other Citizen',
            'other-citizen@example.com',
            'citizen'
        );
        Sanctum::actingAs($otherCitizen);

        $this->postJson("/api/reports/{$report->id}/images", [
            'media' => $this->fakePngUpload(),
        ])->assertForbidden();
    }

    public function test_citizen_can_upload_a_video_attachment_to_their_own_report(): void
    {
        Storage::fake('public');

        [$citizen, $report] = $this->seedCitizenReport();
        Sanctum::actingAs($citizen);

        $response = $this->postJson("/api/reports/{$report->id}/images", [
            'media' => UploadedFile::fake()->create('evidence.mp4', 256, 'video/mp4'),
        ]);

        $response
            ->assertCreated()
            ->assertJsonPath('image.report_id', $report->id)
            ->assertJsonPath('image.media_type', 'video')
            ->assertJsonPath('image.original_name', 'evidence.mp4');

        $storedPath = $response->json('image.image_path');

        Storage::disk('public')->assertExists($storedPath);
        $this->assertDatabaseHas('report_images', [
            'report_id' => $report->id,
            'image_path' => $storedPath,
            'media_type' => 'video',
            'original_name' => 'evidence.mp4',
        ]);
    }

    public function test_report_detail_includes_uploaded_photo_metadata(): void
    {
        Storage::fake('public');

        [$citizen, $report] = $this->seedCitizenReport();
        Sanctum::actingAs($citizen);

        $uploadResponse = $this->postJson("/api/reports/{$report->id}/images", [
            'media' => $this->fakePngUpload(),
        ])->assertCreated();

        $storedPath = $uploadResponse->json('image.image_path');

        $this->getJson("/api/reports/{$report->id}")
            ->assertOk()
            ->assertJsonPath('images.0.image_path', $storedPath)
            ->assertJsonPath('images.0.media_type', 'image')
            ->assertJsonPath('images.0.original_name', 'evidence.png');
    }

    public function test_uploaded_photo_can_be_streamed_from_report_images_endpoint(): void
    {
        Storage::fake('public');

        [$citizen, $report] = $this->seedCitizenReport();
        Sanctum::actingAs($citizen);

        $uploadResponse = $this->postJson("/api/reports/{$report->id}/images", [
            'media' => $this->fakePngUpload(),
        ])->assertCreated();

        $storedPath = $uploadResponse->json('image.image_path');

        $this->get("/api/report-images/{$storedPath}")
            ->assertOk()
            ->assertHeader('content-type', 'image/png');
    }

    public function test_citizen_can_create_a_report_with_mixed_media_in_a_single_request(): void
    {
        Storage::fake('public');

        $citizen = $this->makeUser('Inline Upload Citizen', 'inline-upload@example.com', 'citizen');
        $office = Office::create(['name' => "City Engineer's Office", 'is_active' => true]);
        $category = Category::create(['name' => 'Drainage']);

        Sanctum::actingAs($citizen);

        $response = $this->post('/api/reports', array_merge(
            $this->validReportPayload($office, $category),
            [
                'media' => [
                    $this->fakePngUpload('inline-evidence-1.png'),
                    UploadedFile::fake()->create('inline-evidence-2.mp4', 256, 'video/mp4'),
                ],
            ]
        ));

        $response
            ->assertCreated()
            ->assertJsonCount(2, 'report.images')
            ->assertJsonPath('report.images.0.media_type', 'image')
            ->assertJsonPath('report.images.1.media_type', 'video');

        $imagePaths = $response->json('report.images.*.image_path');

        foreach ($imagePaths as $imagePath) {
            Storage::disk('public')->assertExists($imagePath);
        }

        $this->assertDatabaseCount('report_images', 2);
    }

    private function seedCitizenReport(): array
    {
        $citizen = $this->makeUser('Report Owner', 'report-owner@example.com', 'citizen');
        $office = Office::create(['name' => "City Engineer's Office", 'is_active' => true]);
        $category = Category::create(['name' => 'Drainage']);
        $report = Report::create([
            'user_id' => $citizen->id,
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Drainage issue',
            'description' => 'Standing water near the road.',
            'location' => 'Barangay 7, Tacloban City',
            'barangay' => 'Barangay 7',
            'status' => 'New',
            'priority' => 'Normal',
        ]);

        return [$citizen, $report];
    }

    private function makeUser(string $name, string $email, string $role): User
    {
        return User::create([
            'name' => $name,
            'email' => $email,
            'password' => Hash::make('password123'),
            'role' => $role,
            'is_active' => true,
        ]);
    }

    private function validReportPayload(Office $office, Category $category): array
    {
        return [
            'office_id' => $office->id,
            'category_id' => $category->id,
            'title' => 'Drainage issue',
            'description' => 'Standing water near the road.',
            'location' => 'Barangay 7, Tacloban City',
            'barangay' => 'Barangay 7',
            'priority' => 'Normal',
        ];
    }

    private function fakePngUpload(string $fileName = 'evidence.png'): UploadedFile
    {
        return UploadedFile::fake()->createWithContent(
            $fileName,
            base64_decode(self::TINY_PNG_BASE64, true) ?: ''
        );
    }
}
