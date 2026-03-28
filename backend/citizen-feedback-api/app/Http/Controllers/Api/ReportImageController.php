<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\ReportImage;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class ReportImageController extends Controller
{
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
            abort(404, 'Image not found.');
        }

        return response()->file(Storage::disk('public')->path($normalizedPath));
    }

    public function store(Request $request, $reportId)
    {
        $request->validate([
            'media' => 'required|file|mimes:jpeg,png,jpg,mp4,mov,avi,wmv,webm|max:51200',
        ]);

        $report = Report::findOrFail($reportId);

        $file = $request->file('media');
        $mimeType = (string) $file->getMimeType();
        $mediaType = str_starts_with($mimeType, 'video/') ? 'video' : 'image';
        $directory = $mediaType === 'video' ? 'report_videos' : 'report_images';
        $path = $file->store($directory, 'public');

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
}
