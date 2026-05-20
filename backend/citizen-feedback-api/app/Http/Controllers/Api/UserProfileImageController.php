<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rules\File;

class UserProfileImageController extends Controller
{
    private const PROFILE_IMAGE_MAX_KB = 5 * 1024;

    private const PROFILE_IMAGE_TYPES = ['jpg', 'jpeg', 'png', 'webp'];

    public function show(string $path)
    {
        $normalizedPath = $this->normalizeStoredPath($path);

        abort_if($normalizedPath === null, 404, 'Profile image not found.');
        abort_if(! Storage::disk('public')->exists($normalizedPath), 404, 'Profile image not found.');

        return response()->file(Storage::disk('public')->path($normalizedPath));
    }

    public function update(Request $request)
    {
        $request->validate([
            'profile_image' => [
                'required',
                File::image()
                    ->types(self::PROFILE_IMAGE_TYPES)
                    ->max(self::PROFILE_IMAGE_MAX_KB),
            ],
        ], [
            'profile_image.required' => 'Please choose a profile photo to upload.',
            'profile_image.image' => 'Profile photo must be a valid image.',
            'profile_image.types' => 'Profile photo must be a JPG, PNG, or WebP image.',
            'profile_image.max' => 'Profile photo must be 5MB or smaller.',
        ]);

        $user = $request->user();
        $oldPath = $this->normalizeStoredPath($user?->profile_image_path);
        $newPath = $request->file('profile_image')->store(
            'profile_images/'.$user->id,
            'public'
        );

        $user->forceFill([
            'profile_image_path' => $newPath,
        ])->save();

        if ($oldPath !== null && $oldPath !== $newPath && Storage::disk('public')->exists($oldPath)) {
            Storage::disk('public')->delete($oldPath);
        }

        return response()->json([
            'message' => 'Profile photo updated successfully.',
            'user' => $user->fresh(),
        ]);
    }

    private function normalizeStoredPath(?string $path): ?string
    {
        $normalizedPath = trim((string) $path);
        if ($normalizedPath === '') {
            return null;
        }

        if (filter_var($normalizedPath, FILTER_VALIDATE_URL)) {
            return null;
        }

        $normalizedPath = ltrim($normalizedPath, '/');

        if (str_starts_with($normalizedPath, 'public/')) {
            $normalizedPath = substr($normalizedPath, strlen('public/'));
        }

        if (str_starts_with($normalizedPath, 'storage/')) {
            $normalizedPath = substr($normalizedPath, strlen('storage/'));
        }

        if ($normalizedPath === '' || str_contains($normalizedPath, '..')) {
            return null;
        }

        return $normalizedPath;
    }
}
