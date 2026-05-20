<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\ReportImage;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rules\File;

class ReportImageController extends Controller
{
    private const MEDIA_MAX_KB = 50 * 1024;
    private const MEDIA_TYPES = ['jpg', 'jpeg', 'png', 'mp4', 'mov', 'avi', 'webm', '3gp', 'm4v'];

    public function show(string $path)
    {
        $normalizedPath = ltrim($path, '/');

        if (str_starts_with($normalizedPath, 'public/')) {
            $normalizedPath = substr($normalizedPath, strlen('public/'));
        }

        if (str_starts_with($normalizedPath, 'storage/')) {
            $normalizedPath = substr($normalizedPath, strlen('storage/'));
        }

        if (! Storage::disk('public')->exists($normalizedPath)) {
            abort(404, 'Attachment not found.');
        }

        return response()->file(Storage::disk('public')->path($normalizedPath));
    }

    public function store(Request $request, $reportId)
    {
        $report = Report::findOrFail($reportId);
        $this->authorizeReportAccess($request, $report);

        $request->validate([
            'media' => [
                'required',
                File::types(self::MEDIA_TYPES)
                    ->max(self::MEDIA_MAX_KB),
            ],
        ], [
            'media.required' => 'Please attach a photo or video before submitting.',
            'media.types' => 'Attachments must be JPG, PNG, or video files.',
            'media.max' => 'Attachments must be 50MB or smaller.',
        ]);

        $file = $request->file('media');
        $mediaType = $this->mediaTypeForFile($file);
        $path = $file->store('report_images', 'public');

        $reportImage = ReportImage::create([
            'report_id' => $report->id,
            'image_path' => $path,
            'media_type' => $mediaType,
            'original_name' => $file->getClientOriginalName(),
        ]);

        return response()->json([
            'message' => ucfirst($mediaType) . ' uploaded successfully',
            'image' => $reportImage,
        ], 201);
    }

    private function authorizeReportAccess(Request $request, Report $report): void
    {
        $user = $request->user();
        $role = User::normalizeRole($user?->role ?? 'citizen');

        if ($role === 'super_admin') {
            return;
        }

        if ($role === 'citizen') {
            abort_if($report->user_id !== $user?->id, 403, 'Unauthorized action.');

            return;
        }

        if ($role === 'admin') {
            $department = trim((string) ($user?->department ?? ''));
            $officeName = trim((string) optional($report->office)->name);

            abort_if(
                $department === ''
                    || $officeName === ''
                    || mb_strtolower($department) !== mb_strtolower($officeName),
                403,
                'Unauthorized action.'
            );

            return;
        }

        if ($role === User::ROLE_ADMINISTRATIVE_STAFF) {
            abort_if(
                ! $report->isWalkInComplaint()
                    || ((int) ($report->assisted_by_user_id ?? $report->user_id) !== (int) ($user?->id ?? 0)),
                403,
                'Unauthorized action.'
            );

            return;
        }

        abort(403, 'Unauthorized action.');
    }

    private function mediaTypeForFile(\Illuminate\Http\UploadedFile $file): string
    {
        $mimeType = strtolower((string) $file->getMimeType());

        return str_starts_with($mimeType, 'video/') ? 'video' : 'image';
    }
}
