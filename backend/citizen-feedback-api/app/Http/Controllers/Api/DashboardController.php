<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Category;
use App\Models\Report;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class DashboardController extends Controller
{
    public function index()
    {
        return response()->json([
            'total_reports' => Report::count(),
            'new' => Report::where('status', 'New')->count(),
            'pending' => Report::where('status', 'Pending')->count(),
            'in_progress' => Report::where('status', 'In Progress')->count(),
            'resolved' => Report::where('status', 'Resolved')->count(),
        ]);
    }

    public function analytics(Request $request)
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $statuses = ['New', 'Pending', 'In Progress', 'Resolved'];
        $priorities = ['Low', 'Normal', 'High', 'Urgent'];

        $statusBreakdown = collect($statuses)->map(function (string $status) {
            return [
                'label' => $status,
                'count' => Report::where('status', $status)->count(),
            ];
        })->values();

        $priorityCounts = Report::query()
            ->select('priority', DB::raw('COUNT(*) as total'))
            ->groupBy('priority')
            ->pluck('total', 'priority');

        $priorityBreakdown = collect($priorities)->map(function (string $priority) use ($priorityCounts) {
            return [
                'label' => $priority,
                'count' => (int) ($priorityCounts[$priority] ?? 0),
            ];
        })->values();

        $categoryBreakdown = Category::query()
            ->withCount('reports')
            ->orderByDesc('reports_count')
            ->limit(6)
            ->get()
            ->map(function (Category $category) {
                return [
                    'label' => $category->name,
                    'count' => $category->reports_count,
                ];
            })
            ->values();

        $locationBreakdown = Report::query()
            ->select('location', DB::raw('COUNT(*) as total'))
            ->whereNotNull('location')
            ->where('location', '!=', '')
            ->groupBy('location')
            ->orderByDesc('total')
            ->limit(6)
            ->get()
            ->map(function ($row) {
                return [
                    'label' => $row->location,
                    'count' => (int) $row->total,
                ];
            })
            ->values();

        $monthlyCounts = Report::query()
            ->selectRaw('DATE_FORMAT(created_at, "%Y-%m") as month_key, COUNT(*) as total')
            ->where('created_at', '>=', now()->subMonths(5)->startOfMonth())
            ->groupBy('month_key')
            ->orderBy('month_key')
            ->get()
            ->pluck('total', 'month_key');

        $monthlyTrend = collect(range(0, 5))->map(function (int $offset) use ($monthlyCounts) {
            $date = Carbon::now()->subMonths(5 - $offset);
            $key = $date->format('Y-m');

            return [
                'label' => $date->format('M Y'),
                'count' => (int) ($monthlyCounts[$key] ?? 0),
            ];
        })->values();

        return response()->json([
            'overview' => [
                'total_reports' => Report::count(),
                'new' => Report::where('status', 'New')->count(),
                'pending' => Report::where('status', 'Pending')->count(),
                'in_progress' => Report::where('status', 'In Progress')->count(),
                'resolved' => Report::where('status', 'Resolved')->count(),
            ],
            'status_breakdown' => $statusBreakdown,
            'priority_breakdown' => $priorityBreakdown,
            'category_breakdown' => $categoryBreakdown,
            'location_breakdown' => $locationBreakdown,
            'monthly_trend' => $monthlyTrend,
            'generated_at' => now()->toIso8601String(),
        ]);
    }
}
