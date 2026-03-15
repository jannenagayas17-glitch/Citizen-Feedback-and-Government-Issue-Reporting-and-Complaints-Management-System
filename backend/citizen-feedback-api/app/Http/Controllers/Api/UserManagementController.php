<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Http\Request;

class UserManagementController extends Controller
{
    public function index(Request $request)
    {
        if (!in_array($request->user()->role, ['admin', 'super_admin'])) {
            return response()->json([
                'message' => 'Unauthorized'
            ], 403);
        }

        return response()->json(User::all());
    }

    public function updateRole(Request $request, $id)
    {
        if (!in_array($request->user()->role, ['admin', 'super_admin'])) {
            return response()->json([
                'message' => 'Unauthorized'
            ], 403);
        }

        $request->validate([
            'role' => 'required|string|in:citizen,admin,super_admin',
        ]);

        $user = User::findOrFail($id);

        $user->update([
            'role' => $request->role,
        ]);

        return response()->json([
            'message' => 'User role updated successfully',
            'user' => $user,
        ]);
    }
}
