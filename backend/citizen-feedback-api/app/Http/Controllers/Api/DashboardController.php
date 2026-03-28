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
        $query = Report::query();

        return response()->json([
            'total_reports' => (clone $query)->count(),
            'new' => (clone $query)->where('status', 'New')->count(),
            'pending' => (clone $query)->where('status', 'Pending')->count(),
            'in_progress' => (clone $query)->where('status', 'In Progress')->count(),
            'resolved' => (clone $query)->where('status', 'Resolved')->count(),
        ]);
    }

    public function analytics(Request $request)
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }

        $statuses = ['New', 'Pending', 'In Progress', 'Resolved'];
        $priorities = ['Low', 'Normal', 'High', 'Urgent'];

        $baseQuery = $this->scopedReports($request);

        $statusBreakdown = collect($statuses)->map(function (string $status) use ($baseQuery) {
            return [
                'label' => $status,
                'count' => (clone $baseQuery)->where('status', $status)->count(),
            ];
        })->values();

        $priorityCounts = (clone $baseQuery)
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
            ->get()
            ->map(function (Category $category) use ($baseQuery) {
                return [
                    'label' => $category->name,
                    'count' => (clone $baseQuery)
                        ->where('category_id', $category->id)
                        ->count(),
                ];
            })
            ->sortByDesc('count')
            ->take(6)
            ->values();

        $locationBreakdown = (clone $baseQuery)
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

        $monthlyCounts = (clone $baseQuery)
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
                'total_reports' => (clone $baseQuery)->count(),
                'new' => (clone $baseQuery)->where('status', 'New')->count(),
                'pending' => (clone $baseQuery)->where('status', 'Pending')->count(),
                'in_progress' => (clone $baseQuery)->where('status', 'In Progress')->count(),
                'resolved' => (clone $baseQuery)->where('status', 'Resolved')->count(),
            ],
            'status_breakdown' => $statusBreakdown,
            'priority_breakdown' => $priorityBreakdown,
            'category_breakdown' => $categoryBreakdown,
            'location_breakdown' => $locationBreakdown,
            'monthly_trend' => $monthlyTrend,
            'generated_at' => now()->toIso8601String(),
        ]);
    }

    private function scopedReports(Request $request)
    {
        $query = Report::query();

        if (($request->user()->role ?? null) === 'admin') {
            $department = trim((string) ($request->user()->department ?? ''));

            if ($department === '') {
                $query->whereRaw('1 = 0');
            } else {
                $query->whereHas('office', function ($officeQuery) use ($department) {
                    $officeQuery->where('name', $department);
                });
            }
        }

        return $query;
    }
}
