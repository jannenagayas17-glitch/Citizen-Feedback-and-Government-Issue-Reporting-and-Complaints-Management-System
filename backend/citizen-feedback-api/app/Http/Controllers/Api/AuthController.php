<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Office;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    private const EMOJI_REGEX = '/[\x{1F1E6}-\x{1F1FF}\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]/u';
    private const FULL_NAME_REGEX = "/^(?=.{3,255}$)(?=.*\s)\p{L}[\p{L}'\.-]*(?:\s+\p{L}[\p{L}'\.-]*)+$/u";

    public function registerCitizen(Request $request)
    {
        return $this->register($request);
    }

    public function register(Request $request)
    {
        $request->validate([
            'name' => ['required', 'string', 'max:255', 'regex:' . self::FULL_NAME_REGEX, 'not_regex:' . self::EMOJI_REGEX],
            'email' => ['required', 'string', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'max:255', 'unique:users,email', 'not_regex:' . self::EMOJI_REGEX],
            'mobile_number' => ['nullable', 'regex:/^\d{11}$/'],
            'password' => ['required', 'string', 'min:8', 'confirmed', 'not_regex:' . self::EMOJI_REGEX],
        ], $this->validationMessages());

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'mobile_number' => $request->mobile_number,
            'password' => Hash::make($request->password),
        ]);

        $token = $user->createToken('mobile-token')->plainTextToken;

        return response()->json([
            'message' => 'User registered successfully',
            'user' => $user,
            'token' => $token,
        ], 201);
    }

    public function requestGovernmentAccount(Request $request)
    {
        $request->validate([
            'name' => ['required', 'string', 'max:255', 'regex:' . self::FULL_NAME_REGEX, 'not_regex:' . self::EMOJI_REGEX],
            'email' => ['required', 'string', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'max:255', 'unique:users,email', 'not_regex:' . self::EMOJI_REGEX],
            'mobile_number' => ['required', 'regex:/^\d{11}$/'],
            'password' => ['required', 'string', 'min:8', 'confirmed', 'not_regex:' . self::EMOJI_REGEX],
            'department' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX, 'exists:offices,name'],
            'job_title' => ['required', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
        ], $this->validationMessages());

        $office = Office::query()
            ->where('name', trim((string) $request->department))
            ->where('is_active', true)
            ->first();

        if (! $office) {
            throw ValidationException::withMessages([
                'department' => ['Please select an active government office.'],
            ]);
        }

        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'mobile_number' => $request->mobile_number,
            'password' => Hash::make($request->password),
            'role' => 'pending_admin',
            'department' => $office->name,
            'job_title' => $request->job_title,
        ]);

        return response()->json([
            'message' => 'Admin access request submitted successfully. Please wait for super admin approval.',
            'user' => $user,
        ], 201);
    }

    public function login(Request $request)
    {
        $request->validate([
            'email' => ['required', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'not_regex:' . self::EMOJI_REGEX],
            'password' => ['required', 'not_regex:' . self::EMOJI_REGEX],
        ], $this->validationMessages());

        $user = User::where('email', $request->email)->first();

        if (! $user || ! Hash::check($request->password, $user->password)) {
            throw ValidationException::withMessages([
                'email' => ['The provided credentials are incorrect.'],
            ]);
        }

        if ($user->role === 'pending_admin') {
            throw ValidationException::withMessages([
                'email' => ['Your admin access request is still pending approval.'],
            ]);
        }

        if (! $user->is_active) {
            throw ValidationException::withMessages([
                'email' => ['This account has been deactivated. Please contact the administrator.'],
            ]);
        }

        $token = $user->createToken('mobile-token')->plainTextToken;

        return response()->json([
            'message' => 'Login successful',
            'user' => $user,
            'token' => $token,
        ]);
    }

    public function googleLogin(Request $request)
    {
        $request->validate([
            'id_token' => 'required|string',
        ]);

        $firebaseApiKey = config('services.firebase.api_key');
        $shouldVerifySsl = (bool) config('services.firebase.verify_ssl', true);

        if (! $firebaseApiKey) {
            throw ValidationException::withMessages([
                'firebase' => ['Firebase API key is not configured on the server.'],
            ]);
        }

        try {
            $lookupResponse = Http::withOptions([
                'verify' => $shouldVerifySsl,
            ])
                ->timeout(15)
                ->retry(2, 400)
                ->post(
                'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' . $firebaseApiKey,
                ['idToken' => $request->id_token]
            );
        } catch (\Throwable $e) {
            $message = app()->isLocal()
                ? 'Google token verification failed on the server: ' . $e->getMessage()
                : 'Google token verification is temporarily unavailable.';

            throw ValidationException::withMessages([
                'google' => [$message],
            ]);
        }

        if (! $lookupResponse->successful()) {
            throw ValidationException::withMessages([
                'google' => ['Unable to verify the Google sign-in token.'],
            ]);
        }

        $firebaseUser = $lookupResponse->json('users.0');
        $email = $firebaseUser['email'] ?? null;

        if (! $firebaseUser || ! $email) {
            throw ValidationException::withMessages([
                'google' => ['Invalid Firebase account response.'],
            ]);
        }

        if (! ($firebaseUser['emailVerified'] ?? false)) {
            throw ValidationException::withMessages([
                'email' => ['Google email must be verified.'],
            ]);
        }

        $providerInfo = collect($firebaseUser['providerUserInfo'] ?? []);
        $isGoogleProvider = $providerInfo->contains(function ($provider) {
            return ($provider['providerId'] ?? null) === 'google.com';
        });

        if (! $isGoogleProvider) {
            throw ValidationException::withMessages([
                'google' => ['This sign-in token is not linked to Google.'],
            ]);
        }

        $user = User::firstOrCreate(
            ['email' => $email],
            [
                'name' => $firebaseUser['displayName'] ?? Str::before($email, '@'),
                'password' => Hash::make(Str::random(32)),
                'role' => 'citizen',
                'firebase_uid' => $firebaseUser['localId'] ?? null,
            ]
        );

        if (! $user->is_active) {
            throw ValidationException::withMessages([
                'email' => ['This account has been deactivated. Please contact the administrator.'],
            ]);
        }

        if (empty($user->name) && ! empty($firebaseUser['displayName'])) {
            $user->name = $firebaseUser['displayName'];
        }

        if (empty($user->firebase_uid) && ! empty($firebaseUser['localId'])) {
            $user->firebase_uid = $firebaseUser['localId'];
        }

        if ($user->isDirty()) {
            $user->save();
        }

        $token = $user->createToken('mobile-token')->plainTextToken;

        return response()->json([
            'message' => 'Google login successful',
            'user' => $user,
            'token' => $token,
        ]);
    }

    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json([
            'message' => 'Logged out successfully',
        ]);
    }

    public function currentUser(Request $request)
    {
        return response()->json($request->user());
    }

    public function updateProfile(Request $request)
    {
        $user = $request->user();

        if (($user->role ?? null) === 'super_admin') {
            throw ValidationException::withMessages([
                'user' => ['The protected super admin account cannot be edited from the portal.'],
            ]);
        }

        $request->validate([
            'name' => ['required', 'string', 'max:255', 'regex:' . self::FULL_NAME_REGEX, 'not_regex:' . self::EMOJI_REGEX],
            'email' => ['required', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'max:255', 'unique:users,email,' . $user->id, 'not_regex:' . self::EMOJI_REGEX],
            'mobile_number' => ['nullable', 'regex:/^\d{11}$/'],
        ], $this->validationMessages());

        $user->update([
            'name' => $request->name,
            'email' => $request->email,
            'mobile_number' => $request->mobile_number,
        ]);

        return response()->json([
            'message' => 'Profile updated successfully',
            'user' => $user,
        ]);
    }

    public function changePassword(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'current_password' => ['required', 'string', 'not_regex:' . self::EMOJI_REGEX],
            'new_password' => ['required', 'string', 'min:8', 'confirmed', 'different:current_password', 'not_regex:' . self::EMOJI_REGEX],
        ], $this->validationMessages());

        if (! Hash::check($validated['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['The current password is incorrect.'],
            ]);
        }

        $user->forceFill([
            'password' => Hash::make($validated['new_password']),
        ])->save();

        $currentToken = $request->user()->currentAccessToken();
        if ($currentToken !== null) {
            $user->tokens()->whereKeyNot($currentToken->id)->delete();
        }

        return response()->json([
            'message' => 'Password changed successfully',
        ]);
    }

    public function adminUsers(Request $request)
    {
        $this->ensureSuperAdmin($request);

        $query = User::withTrashed()
            ->whereIn('role', ['super_admin', 'admin', 'pending_admin', 'citizen']);

        return response()->json(
            $query
                ->orderByRaw("case when role = 'super_admin' then 0 when role = 'admin' then 1 when role = 'pending_admin' then 2 else 3 end")
                ->orderBy('name')
                ->get()
        );
    }

    public function storeManagedAccount(Request $request)
    {
        $this->ensureSuperAdmin($request);

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255', 'regex:' . self::FULL_NAME_REGEX, 'not_regex:' . self::EMOJI_REGEX],
            'email' => ['required', 'string', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'max:255', 'unique:users,email', 'not_regex:' . self::EMOJI_REGEX],
            'mobile_number' => ['nullable', 'regex:/^\d{11}$/'],
            'password' => ['required', 'string', 'min:8', 'confirmed', 'not_regex:' . self::EMOJI_REGEX],
            'role' => ['required', 'in:pending_admin,admin,citizen'],
            'department' => ['nullable', 'required_if:role,pending_admin,admin', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX, 'exists:offices,name'],
            'job_title' => ['nullable', 'required_if:role,pending_admin,admin', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
        ], $this->validationMessages());

        $role = $validated['role'];
        $department = null;
        $jobTitle = null;

        if (in_array($role, ['pending_admin', 'admin'], true)) {
            $office = Office::query()
                ->where('name', trim((string) $validated['department']))
                ->where('is_active', true)
                ->first();

            if (! $office) {
                throw ValidationException::withMessages([
                    'department' => ['Please select an active government office.'],
                ]);
            }

            $department = $office->name;
            $jobTitle = trim((string) $validated['job_title']);
        }

        $user = User::create([
            'name' => trim((string) $validated['name']),
            'email' => trim((string) $validated['email']),
            'mobile_number' => $validated['mobile_number'] ?? null,
            'password' => Hash::make($validated['password']),
            'role' => $role,
            'department' => $department,
            'job_title' => $jobTitle,
            'is_active' => true,
        ]);

        return response()->json([
            'message' => $role === 'citizen'
                ? 'Citizen account created successfully.'
                : 'Pending admin account created successfully.',
            'user' => $user,
        ], 201);
    }

    public function updateManagedAccount(Request $request, $id)
    {
        $this->ensureSuperAdmin($request);

        $actor = $request->user();
        $user = User::withTrashed()->findOrFail($id);

        if ($user->id === $actor->id) {
            throw ValidationException::withMessages([
                'user' => ['You cannot edit your own account from Account Management.'],
            ]);
        }

        if ($user->role === 'super_admin') {
            throw ValidationException::withMessages([
                'user' => ['Super admin accounts cannot be edited here.'],
            ]);
        }

        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255', 'regex:' . self::FULL_NAME_REGEX, 'not_regex:' . self::EMOJI_REGEX],
            'email' => ['required', 'string', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'max:255', 'unique:users,email,' . $user->id, 'not_regex:' . self::EMOJI_REGEX],
            'mobile_number' => ['nullable', 'regex:/^\d{11}$/'],
            'role' => ['required', 'in:pending_admin,admin,citizen'],
            'department' => ['nullable', 'required_if:role,pending_admin,admin', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX, 'exists:offices,name'],
            'job_title' => ['nullable', 'required_if:role,pending_admin,admin', 'string', 'max:255', 'not_regex:' . self::EMOJI_REGEX],
            'password' => ['nullable', 'string', 'min:8', 'confirmed', 'not_regex:' . self::EMOJI_REGEX],
        ], $this->validationMessages());

        $role = $validated['role'];
        $department = null;
        $jobTitle = null;

        if (in_array($role, ['pending_admin', 'admin'], true)) {
            $office = Office::query()
                ->where('name', trim((string) $validated['department']))
                ->where('is_active', true)
                ->first();

            if (! $office) {
                throw ValidationException::withMessages([
                    'department' => ['Please select an active government office.'],
                ]);
            }

            $department = $office->name;
            $jobTitle = trim((string) $validated['job_title']);
        }

        $user->fill([
            'name' => trim((string) $validated['name']),
            'email' => trim((string) $validated['email']),
            'mobile_number' => $validated['mobile_number'] ?? null,
            'role' => $role,
            'department' => $department,
            'job_title' => $jobTitle,
        ]);

        if (! empty($validated['password'])) {
            $user->password = Hash::make($validated['password']);
            $user->tokens()->delete();
        }

        $user->save();

        return response()->json([
            'message' => 'Account updated successfully.',
            'user' => $user,
        ]);
    }

    public function verifyAccount(Request $request, $id)
    {
        $this->ensureElevatedRole($request);

        if (($request->user()->role ?? null) !== 'super_admin') {
            throw ValidationException::withMessages([
                'user' => ['Only super admins can verify pending admin accounts.'],
            ]);
        }

        $user = User::withTrashed()->findOrFail($id);
        if ($user->role !== 'pending_admin') {
            throw ValidationException::withMessages([
                'user' => ['Only pending admin accounts can be verified.'],
            ]);
        }
        $user->role = 'admin';
        if ($user->trashed()) {
            $user->restore();
        }

        $user->is_active = true;
        $user->save();

        return response()->json([
            'message' => 'Account verified successfully',
            'user' => $user,
        ]);
    }

    public function deactivateAccount(Request $request, $id)
    {
        $this->ensureSuperAdmin($request);

        $actor = $request->user();
        $user = User::withTrashed()->findOrFail($id);

        if ($user->role === 'super_admin') {
            throw ValidationException::withMessages([
                'user' => ['Super admin accounts cannot be deactivated.'],
            ]);
        }

        if ($user->id === $actor->id) {
            throw ValidationException::withMessages([
                'user' => ['You cannot deactivate your own account.'],
            ]);
        }

        $user->tokens()->delete();
        $user->is_active = false;
        $user->save();

        return response()->json([
            'message' => 'Account deactivated successfully',
            'user' => $user,
        ]);
    }

    public function reactivateAccount(Request $request, $id)
    {
        $this->ensureElevatedRole($request);

        $actor = $request->user();
        $user = User::withTrashed()->findOrFail($id);

        if ($user->role === 'super_admin') {
            throw ValidationException::withMessages([
                'user' => ['Super admin accounts are always active.'],
            ]);
        }

        if ($actor->role !== 'super_admin') {
            throw ValidationException::withMessages([
                'user' => ['Only super admins can reactivate accounts.'],
            ]);
        }

        if ($user->trashed()) {
            $user->restore();
        }

        $user->is_active = true;
        $user->save();

        return response()->json([
            'message' => 'Account reactivated successfully',
            'user' => $user,
        ]);
    }

    public function deleteAccount(Request $request, $id)
    {
        $this->ensureElevatedRole($request);

        $actor = $request->user();
        $user = User::withTrashed()->findOrFail($id);

        if (($actor->role ?? null) !== 'super_admin') {
            throw ValidationException::withMessages([
                'user' => ['Only super admins can delete accounts.'],
            ]);
        }

        if ($user->id === $actor->id) {
            throw ValidationException::withMessages([
                'user' => ['You cannot delete your own account.'],
            ]);
        }

        if ($user->role === 'super_admin') {
            throw ValidationException::withMessages([
                'user' => ['Super admin accounts cannot be deleted.'],
            ]);
        }

        $user->tokens()->delete();

        if ($user->trashed()) {
            $user->forceDelete();

            return response()->json([
                'message' => 'Account permanently deleted successfully',
            ]);
        }

        $user->is_active = false;
        $user->save();
        $user->delete();

        return response()->json([
            'message' => 'Account archived successfully',
        ]);
    }

    private function ensureElevatedRole(Request $request): void
    {
        if (! in_array($request->user()->role, ['admin', 'super_admin'], true)) {
            abort(403, 'Unauthorized action.');
        }
    }

    private function ensureSuperAdmin(Request $request): void
    {
        if (($request->user()->role ?? null) !== 'super_admin') {
            abort(403, 'Only super admins can manage accounts.');
        }
    }

    private function validationMessages(): array
    {
        return [
            'mobile_number.regex' => 'Mobile number must be exactly 11 digits.',
            'name.regex' => 'Enter your full name with first and last name.',
            'name.not_regex' => 'Emoji characters are not allowed.',
            'email.not_regex' => 'Emoji characters are not allowed.',
            'password.not_regex' => 'Emoji characters are not allowed.',
            'password.confirmed' => 'Password confirmation does not match.',
            'new_password.not_regex' => 'Emoji characters are not allowed.',
            'new_password.confirmed' => 'Password confirmation does not match.',
            'new_password.different' => 'New password must be different from the current password.',
            'department.not_regex' => 'Emoji characters are not allowed.',
            'department.exists' => 'Please select a valid government office.',
            'job_title.not_regex' => 'Emoji characters are not allowed.',
        ];
    }
}
