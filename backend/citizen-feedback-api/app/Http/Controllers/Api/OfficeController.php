<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Office;
use Illuminate\Http\Request;

class OfficeController extends Controller
{
    private const EMOJI_REGEX = '/[\x{1F1E6}-\x{1F1FF}\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]/u';

    public function index(Request $request)
    {
        $query = Office::query()->orderBy('name');

        if (! $request->boolean('include_inactive')) {
            $query->where('is_active', true);
        }

        return response()->json($query->get());
    }

    public function store(Request $request)
    {
        $this->ensureElevatedRole($request);

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255', 'unique:offices,name', 'not_regex:' . self::EMOJI_REGEX],
            'code' => ['nullable', 'string', 'max:50', 'unique:offices,code', 'not_regex:' . self::EMOJI_REGEX],
            'description' => ['nullable', 'string', 'max:1000', 'not_regex:' . self::EMOJI_REGEX],
            'is_active' => ['nullable', 'boolean'],
        ], [
            'name.not_regex' => 'Emoji characters are not allowed.',
            'code.not_regex' => 'Emoji characters are not allowed.',
            'description.not_regex' => 'Emoji characters are not allowed.',
        ]);

        $office = Office::create([
            'name' => trim($validated['name']),
            'code' => isset($validated['code']) ? trim((string) $validated['code']) : null,
            'description' => isset($validated['description']) ? trim((string) $validated['description']) : null,
            'is_active' => $validated['is_active'] ?? true,
        ]);

        return response()->json([
            'message' => 'Office added successfully',
            'office' => $office,
        ], 201);
    }

    private function ensureElevatedRole(Request $request): void
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }
    }
}
