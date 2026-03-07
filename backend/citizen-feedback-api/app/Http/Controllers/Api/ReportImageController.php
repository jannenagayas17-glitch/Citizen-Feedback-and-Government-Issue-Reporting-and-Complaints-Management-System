<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Report;
use App\Models\ReportImage;
use Illuminate\Http\Request;

class ReportImageController extends Controller
{
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