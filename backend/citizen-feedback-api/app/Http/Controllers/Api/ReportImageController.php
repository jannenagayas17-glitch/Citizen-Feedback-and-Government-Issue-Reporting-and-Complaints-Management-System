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
            'image' => 'required|image|mimes:jpeg,png,jpg|max:2048',
        ]);

        $report = Report::findOrFail($reportId);

        $path = $request->file('image')->store('report_images', 'public');

        $reportImage = ReportImage::create([
            'report_id' => $report->id,
            'image_path' => $path,
        ]);

        return response()->json([
            'message' => 'Image uploaded successfully',
            'image' => $reportImage,
        ], 201);
    }
}
