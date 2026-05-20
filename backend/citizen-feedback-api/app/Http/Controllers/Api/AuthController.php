<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Office;
use App\Models\User;
use App\Support\DemoAccountService;
use App\Support\UserEmailDeduplicationService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    private const EMOJI_REGEX = '/[\x{1F1E6}-\x{1F1FF}\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]/u';

    private const NAME_PART_REGEX = "/^(?=.{1,25}$)\p{L}+(?:[ '-]\p{L}+)*$/u";

    private const FULL_NAME_REGEX = "/^(?=.{3,255}$)\p{L}+(?:[ '-]\p{L}+)*(?:\s+\p{L}+(?:[ '-]\p{L}+)*)+$/u";

    private const PH_MOBILE_REGEX = '/^09\d{9}$/';

    private const GOVERNMENT_ACCOUNT_JOB_TITLES = [
        'Office Head',
        'Office Supervisor',
        'Office Coordinator',
        'Administrative Staff',
    ];

    public function registerCitizen(Request $request)
    {
        return $this->register($request);
    }

    public function register(Request $request)
    {
        $this->normalizeCredentialRequest($request);

        $validated = $request->validate([
            'first_name' => ['nullable', 'string', 'max:25', 'not_regex:'.self::EMOJI_REGEX],
            'last_name' => ['nullable', 'string', 'max:25', 'not_regex:'.self::EMOJI_REGEX],
            'name' => ['required_without_all:first_name,last_name', 'nullable', 'string', 'max:255', 'regex:'.self::FULL_NAME_REGEX, 'not_regex:'.self::EMOJI_REGEX],
            'email' => ['required', 'string', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'max:255', 'unique:users,email', 'not_regex:'.self::EMOJI_REGEX],
            'mobile_number' => ['nullable', 'regex:'.self::PH_MOBILE_REGEX],
            'password' => ['required', 'string', 'min:8', 'confirmed', 'not_regex:'.self::EMOJI_REGEX],
        ], $this->validationMessages());

        [, , $fullName] = $this->resolveCitizenRegistrationName($validated);

        $this->ensureUniqueCredentials(
            $validated['email'],
            $validated['mobile_number'] ?? null
        );

        $user = User::create([
            'name' => $fullName,
            'email' => $validated['email'],
            'mobile_number' => $validated['mobile_number'] ?? null,
            'password' => Hash::make($validated['password']),
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
        $this->normalizeCredentialRequest($request);

        $validated = $request->validate([
            'first_name' => ['nullable', 'string', 'max:25', 'not_regex:'.self::EMOJI_REGEX],
            'last_name' => ['nullable', 'string', 'max:25', 'not_regex:'.self::EMOJI_REGEX],
            'name' => ['required_without_all:first_name,last_name', 'nullable', 'string', 'max:255', 'regex:'.self::FULL_NAME_REGEX, 'not_regex:'.self::EMOJI_REGEX],
            'email' => ['required', 'string', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'max:255', 'unique:users,email', 'not_regex:'.self::EMOJI_REGEX],
            'mobile_number' => ['required', 'regex:'.self::PH_MOBILE_REGEX],
            'password' => ['required', 'string', 'min:8', 'confirmed', 'not_regex:'.self::EMOJI_REGEX],
            'department' => ['required', 'string', 'max:255', 'not_regex:'.self::EMOJI_REGEX, 'exists:offices,name'],
            'job_title' => ['required', 'string', 'max:255', 'not_regex:'.self::EMOJI_REGEX, Rule::in(self::GOVERNMENT_ACCOUNT_JOB_TITLES)],
        ], $this->validationMessages());

        [, , $fullName] = $this->resolveCitizenRegistrationName($validated);

        $this->ensureUniqueCredentials(
            $validated['email'],
            $validated['mobile_number'] ?? null
        );

        $office = Office::query()
            ->where('name', trim((string) $validated['department']))
            ->where('is_active', true)
            ->first();

        if (! $office) {
            throw ValidationException::withMessages([
                'department' => ['Please select an active government office.'],
            ]);
        }

        $user = User::create([
            'name' => $fullName,
            'email' => $validated['email'],
            'mobile_number' => $validated['mobile_number'],
            'password' => Hash::make($validated['password']),
            'role' => 'pending_admin',
            'department' => $office->name,
            'job_title' => trim((string) $validated['job_title']),
        ]);

        return response()->json([
            'message' => 'Admin access request submitted successfully. Please wait for super admin approval.',
            'user' => $user,
        ], 201);
    }

    public function login(Request $request)
    {
        $this->normalizeCredentialRequest($request);

        $request->validate([
            'email' => ['required', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'not_regex:'.self::EMOJI_REGEX],
            'password' => ['required', 'not_regex:'.self::EMOJI_REGEX],
        ], $this->validationMessages());

        $user = $this->findUserByNormalizedEmail((string) $request->email);

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
        $validated = $request->validate([
            'id_token' => 'required|string',
            'role_hint' => 'nullable|string|in:citizen,admin',
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
                    'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key='.$firebaseApiKey,
                    ['idToken' => $validated['id_token']]
                );
        } catch (\Throwable $e) {
            $message = app()->isLocal()
                ? 'Google token verification failed on the server: '.$e->getMessage()
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
        $email = $this->normalizeEmail($firebaseUser['email'] ?? null);

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

        $roleHint = $validated['role_hint'] ?? 'citizen';
        $user = $roleHint === 'admin'
            ? $this->resolveStaffGoogleUser($email)
            : $this->resolveCitizenGoogleUser($email);

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

    private function resolveCitizenGoogleUser(string $email): User
    {
        $user = $this->findUserByNormalizedEmail($email);

        if (! $user) {
            throw ValidationException::withMessages([
                'email' => ['No registered citizen account was found for this Google email. Please sign up first.'],
            ]);
        }

        if ($user->role !== 'citizen') {
            throw ValidationException::withMessages([
                'email' => ['This Google account is not registered as a citizen account.'],
            ]);
        }

        return $user;
    }

    private function resolveStaffGoogleUser(string $email): User
    {
        $user = $this->findUserByNormalizedEmail($email);

        if (! $user) {
            throw ValidationException::withMessages([
                'email' => ['No approved admin account was found for this Google email. Please ask the super admin to create or verify your account first.'],
            ]);
        }

        if ($user->role === 'pending_admin') {
            throw ValidationException::withMessages([
                'email' => ['Your admin access request is still pending approval.'],
            ]);
        }

        if ($user->role === 'super_admin') {
            throw ValidationException::withMessages([
                'email' => ['Super admin accounts must sign in with email and password.'],
            ]);
        }

        if ($user->role !== 'admin') {
            throw ValidationException::withMessages([
                'email' => ['This Google account is not authorized for staff login.'],
            ]);
        }

        return $user;
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

        $this->normalizeCredentialRequest($request);

        $validated = $request->validate([
            'first_name' => ['nullable', 'string', 'max:25', 'not_regex:'.self::EMOJI_REGEX],
            'last_name' => ['nullable', 'string', 'max:25', 'not_regex:'.self::EMOJI_REGEX],
            'name' => ['required_without_all:first_name,last_name', 'nullable', 'string', 'max:255', 'regex:'.self::FULL_NAME_REGEX, 'not_regex:'.self::EMOJI_REGEX],
            'email' => ['required', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'max:255', 'unique:users,email,'.$user->id, 'not_regex:'.self::EMOJI_REGEX],
            'mobile_number' => ['nullable', 'regex:'.self::PH_MOBILE_REGEX],
        ], $this->validationMessages());

        [, , $fullName] = $this->resolveCitizenRegistrationName($validated);

        $this->ensureUniqueCredentials(
            $validated['email'],
            $validated['mobile_number'] ?? null,
            $user->id
        );

        $user->update([
            'name' => $fullName,
            'email' => $validated['email'],
            'mobile_number' => $validated['mobile_number'] ?? null,
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
            'current_password' => ['required', 'string', 'not_regex:'.self::EMOJI_REGEX],
            'new_password' => ['required', 'string', 'min:8', 'confirmed', 'different:current_password', 'not_regex:'.self::EMOJI_REGEX],
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

        $query = app(DemoAccountService::class)->scopeRealUsers(
            User::withTrashed()
                ->whereIn('role', ['super_admin', 'admin', 'administrative_staff', 'front_desk', 'pending_admin', 'citizen'])
        );

        $deduplicatedUsers = app(UserEmailDeduplicationService::class)
            ->deduplicateUsersForDisplay(
                $query
                    ->orderByRaw("case when role = 'super_admin' then 0 when role = 'admin' then 1 when role = 'administrative_staff' then 2 when role = 'front_desk' then 3 when role = 'pending_admin' then 4 else 5 end")
                    ->orderBy('name')
                    ->get()
            );

        return response()->json(
            $deduplicatedUsers->values()
        );
    }

    public function storeManagedAccount(Request $request)
    {
        $this->ensureSuperAdmin($request);

        $this->normalizeCredentialRequest($request);

        $validated = $request->validate([
            'first_name' => ['nullable', 'string', 'max:25', 'not_regex:'.self::EMOJI_REGEX],
            'last_name' => ['nullable', 'string', 'max:25', 'not_regex:'.self::EMOJI_REGEX],
            'name' => ['required_without_all:first_name,last_name', 'nullable', 'string', 'max:255', 'regex:'.self::FULL_NAME_REGEX, 'not_regex:'.self::EMOJI_REGEX],
            'email' => ['required', 'string', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'max:255', 'unique:users,email', 'not_regex:'.self::EMOJI_REGEX],
            'mobile_number' => ['nullable', 'regex:'.self::PH_MOBILE_REGEX],
            'password' => ['required', 'string', 'min:8', 'confirmed', 'not_regex:'.self::EMOJI_REGEX],
            'role' => ['required', 'in:pending_admin,admin,administrative_staff,front_desk,citizen'],
            'department' => ['nullable', 'required_if:role,pending_admin,admin,administrative_staff,front_desk', 'string', 'max:255', 'not_regex:'.self::EMOJI_REGEX, 'exists:offices,name'],
            'job_title' => ['nullable', 'required_if:role,pending_admin,admin,administrative_staff,front_desk', 'string', 'max:255', 'not_regex:'.self::EMOJI_REGEX],
        ], $this->validationMessages());

        [, , $fullName] = $this->resolveCitizenRegistrationName($validated);

        $this->ensureUniqueCredentials(
            $validated['email'],
            $validated['mobile_number'] ?? null
        );

        $role = $this->normalizeManagedRole($validated['role']);
        $department = null;
        $jobTitle = null;

        if ($this->isManagedStaffRole($role)) {
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
            'name' => $fullName,
            'email' => trim((string) $validated['email']),
            'mobile_number' => $validated['mobile_number'] ?? null,
            'password' => Hash::make($validated['password']),
            'role' => $role,
            'department' => $department,
            'job_title' => $jobTitle,
            'is_active' => true,
        ]);

        return response()->json([
            'message' => match ($role) {
                'citizen' => 'Citizen account created successfully.',
                'administrative_staff' => 'Administrative staff account created successfully.',
                'admin' => 'Administrator account created successfully.',
                default => 'Pending admin account created successfully.',
            },
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

        $this->normalizeCredentialRequest($request);

        $validated = $request->validate([
            'first_name' => ['nullable', 'string', 'max:25', 'not_regex:'.self::EMOJI_REGEX],
            'last_name' => ['nullable', 'string', 'max:25', 'not_regex:'.self::EMOJI_REGEX],
            'name' => ['required_without_all:first_name,last_name', 'nullable', 'string', 'max:255', 'regex:'.self::FULL_NAME_REGEX, 'not_regex:'.self::EMOJI_REGEX],
            'email' => ['required', 'string', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'max:255', 'unique:users,email,'.$user->id, 'not_regex:'.self::EMOJI_REGEX],
            'mobile_number' => ['nullable', 'regex:'.self::PH_MOBILE_REGEX],
            'role' => ['required', 'in:pending_admin,admin,administrative_staff,front_desk,citizen'],
            'department' => ['nullable', 'required_if:role,pending_admin,admin,administrative_staff,front_desk', 'string', 'max:255', 'not_regex:'.self::EMOJI_REGEX, 'exists:offices,name'],
            'job_title' => ['nullable', 'required_if:role,pending_admin,admin,administrative_staff,front_desk', 'string', 'max:255', 'not_regex:'.self::EMOJI_REGEX],
            'password' => ['nullable', 'string', 'min:8', 'confirmed', 'not_regex:'.self::EMOJI_REGEX],
        ], $this->validationMessages());

        [, , $fullName] = $this->resolveCitizenRegistrationName($validated);

        $this->ensureUniqueCredentials(
            $validated['email'],
            $validated['mobile_number'] ?? null,
            $user->id
        );

        $role = $this->normalizeManagedRole($validated['role']);
        $department = null;
        $jobTitle = null;

        if ($this->isManagedStaffRole($role)) {
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
            'name' => $fullName,
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

    private function normalizeManagedRole(string $role): string
    {
        return User::normalizeRole($role);
    }

    private function isManagedStaffRole(string $role): bool
    {
        return in_array($this->normalizeManagedRole($role), [
            'pending_admin',
            'admin',
            User::ROLE_ADMINISTRATIVE_STAFF,
        ], true);
    }

    private function normalizeCredentialRequest(Request $request): void
    {
        $normalized = [];

        if ($request->exists('name')) {
            $normalized['name'] = $this->normalizePersonName($request->input('name'));
        }

        if ($request->exists('first_name')) {
            $normalized['first_name'] = $this->normalizePersonName(
                $request->input('first_name')
            );
        }

        if ($request->exists('last_name')) {
            $normalized['last_name'] = $this->normalizePersonName(
                $request->input('last_name')
            );
        }

        if ($request->exists('email')) {
            $normalized['email'] = $this->normalizeEmail($request->input('email'));
        }

        if ($request->exists('mobile_number')) {
            $normalized['mobile_number'] = $this->normalizeMobileNumber(
                $request->input('mobile_number')
            );
        }

        if ($request->exists('department')) {
            $normalized['department'] = trim((string) $request->input('department'));
        }

        if ($request->exists('job_title')) {
            $normalized['job_title'] = trim((string) $request->input('job_title'));
        }

        if ($normalized !== []) {
            $request->merge($normalized);
        }
    }

    private function normalizeEmail($value): string
    {
        return mb_strtolower(trim((string) $value));
    }

    private function normalizePersonName($value): string
    {
        $normalized = preg_replace('/\s+/u', ' ', trim((string) $value));
        $normalized = $normalized ?? '';

        if ($normalized === '') {
            return '';
        }

        $lowerCased = mb_convert_case($normalized, MB_CASE_LOWER, 'UTF-8');

        return preg_replace_callback(
            "/(^|[ '-])(\p{L})/u",
            fn (array $matches) => $matches[1].mb_strtoupper($matches[2], 'UTF-8'),
            $lowerCased
        ) ?? '';
    }

    private function normalizeMobileNumber($value): ?string
    {
        $normalized = trim((string) $value);

        if ($normalized === '') {
            return null;
        }

        $digitsOnly = preg_replace('/\D+/', '', $normalized);
        $digitsOnly = $digitsOnly ?? '';

        if ($digitsOnly === '') {
            return $normalized;
        }

        if (str_starts_with($digitsOnly, '63') && strlen($digitsOnly) === 12) {
            return '0'.substr($digitsOnly, 2);
        }

        if (str_starts_with($digitsOnly, '9') && strlen($digitsOnly) === 10) {
            return '0'.$digitsOnly;
        }

        return $digitsOnly;
    }

    private function resolveCitizenRegistrationName(array $validated): array
    {
        $firstName = $validated['first_name'] ?? null;
        $lastName = $validated['last_name'] ?? null;

        if ($firstName !== null || $lastName !== null) {
            if ($firstName === null || $firstName === '') {
                throw ValidationException::withMessages([
                    'first_name' => ['First name is required.'],
                ]);
            }

            if ($lastName === null || $lastName === '') {
                throw ValidationException::withMessages([
                    'last_name' => ['Last name is required.'],
                ]);
            }

            $this->ensureValidNamePart($firstName, 'first_name', 'First name');
            $this->ensureValidNamePart($lastName, 'last_name', 'Last name');

            return [$firstName, $lastName, trim($firstName.' '.$lastName)];
        }

        $fullName = trim((string) ($validated['name'] ?? ''));
        if ($fullName === '') {
            throw ValidationException::withMessages([
                'name' => ['Full name is required.'],
            ]);
        }

        [$legacyFirstName, $legacyLastName] = $this->splitLegacyFullName($fullName);

        $this->ensureValidNamePart($legacyFirstName, 'first_name', 'First name');
        $this->ensureValidNamePart($legacyLastName, 'last_name', 'Last name');

        return [$legacyFirstName, $legacyLastName, $fullName];
    }

    private function splitLegacyFullName(string $fullName): array
    {
        $segments = preg_split('/\s+/u', $fullName, -1, PREG_SPLIT_NO_EMPTY) ?: [];

        if (count($segments) < 2) {
            throw ValidationException::withMessages([
                'name' => ['Enter your full name with first and last name.'],
            ]);
        }

        $firstName = array_shift($segments);
        $lastName = implode(' ', $segments);

        return [
            $this->normalizePersonName((string) $firstName),
            $this->normalizePersonName($lastName),
        ];
    }

    private function ensureValidNamePart(string $value, string $field, string $label): void
    {
        $normalized = $this->normalizePersonName($value);

        if ($normalized === '') {
            throw ValidationException::withMessages([
                $field => [$label.' is required.'],
            ]);
        }

        if (preg_match(self::EMOJI_REGEX, $normalized) === 1) {
            throw ValidationException::withMessages([
                $field => ['Emoji characters are not allowed.'],
            ]);
        }

        if (mb_strlen($normalized) > 25) {
            throw ValidationException::withMessages([
                $field => [$label.' must be 25 characters or fewer.'],
            ]);
        }

        if (preg_match(self::NAME_PART_REGEX, $normalized) !== 1) {
            throw ValidationException::withMessages([
                $field => [$label.' can only contain letters, spaces, hyphens, and apostrophes.'],
            ]);
        }
    }

    private function ensureUniqueCredentials(
        string $email,
        ?string $mobileNumber,
        ?int $ignoreUserId = null
    ): void {
        $emailQuery = User::withTrashed()
            ->whereRaw('LOWER(TRIM(email)) = ?', [$this->normalizeEmail($email)]);

        if ($ignoreUserId !== null) {
            $emailQuery->where('id', '!=', $ignoreUserId);
        }

        if ($emailQuery->exists()) {
            throw ValidationException::withMessages([
                'email' => ['This email is already registered.'],
            ]);
        }

        if ($mobileNumber === null || $mobileNumber === '') {
            return;
        }

        $mobileVariants = $this->mobileNumberVariants($mobileNumber);
        $mobileQuery = User::withTrashed()->whereIn('mobile_number', $mobileVariants);

        if ($ignoreUserId !== null) {
            $mobileQuery->where('id', '!=', $ignoreUserId);
        }

        if ($mobileQuery->exists()) {
            throw ValidationException::withMessages([
                'mobile_number' => ['This mobile number is already registered.'],
            ]);
        }
    }

    private function findUserByNormalizedEmail(string $email): ?User
    {
        $normalizedEmail = $this->normalizeEmail($email);
        if ($normalizedEmail === '') {
            return null;
        }

        return User::query()
            ->whereRaw('LOWER(TRIM(email)) = ?', [$normalizedEmail])
            ->get()
            ->pipe(fn ($users) => app(UserEmailDeduplicationService::class)->pickPreferredUser($users));
    }

    private function validationMessages(): array
    {
        return [
            'first_name.max' => 'First name must be 25 characters or fewer.',
            'last_name.max' => 'Last name must be 25 characters or fewer.',
            'first_name.not_regex' => 'Emoji characters are not allowed.',
            'last_name.not_regex' => 'Emoji characters are not allowed.',
            'mobile_number.regex' => 'Enter a valid Philippine mobile number. Use 09123456789 or +639123456789.',
            'mobile_number.unique' => 'This mobile number is already registered.',
            'email.unique' => 'This email is already registered.',
            'name.required_without_all' => 'Full name is required.',
            'name.regex' => 'Enter a valid full name using letters, spaces, hyphens, and apostrophes.',
            'name.not_regex' => 'Emoji characters are not allowed.',
            'email.not_regex' => 'Emoji characters are not allowed.',
            'password.not_regex' => 'Emoji characters are not allowed.',
            'password.confirmed' => 'Password confirmation does not match.',
            'new_password.not_regex' => 'Emoji characters are not allowed.',
            'new_password.confirmed' => 'Password confirmation does not match.',
            'new_password.different' => 'New password must be different from the current password.',
            'department.required' => 'Please select a government office.',
            'department.required_if' => 'Please select a government office.',
            'department.not_regex' => 'Emoji characters are not allowed.',
            'department.exists' => 'Please select a valid government office.',
            'job_title.required' => 'Please select an admin type.',
            'job_title.required_if' => 'Please select an admin type.',
            'job_title.not_regex' => 'Emoji characters are not allowed.',
            'job_title.in' => 'Please select a valid admin type.',
        ];
    }

    private function mobileNumberVariants(string $mobileNumber): array
    {
        $normalized = $this->normalizeMobileNumber($mobileNumber);

        if ($normalized === null || $normalized === '') {
            return [];
        }

        $subscriberDigits = substr($normalized, 1);

        return array_values(array_unique([
            $normalized,
            '+63'.$subscriberDigits,
            '63'.$subscriberDigits,
            $subscriberDigits,
        ]));
    }
}
