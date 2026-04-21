<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;
use Symfony\Component\HttpFoundation\Response;

class PasswordResetController extends Controller
{
    private const EMOJI_REGEX = '/[\x{1F1E6}-\x{1F1FF}\x{1F300}-\x{1FAFF}\x{2600}-\x{27BF}]/u';

    public function showResetForm(Request $request, string $token): View
    {
        return view('auth.reset-password', [
            'token' => $token,
            'email' => $request->query('email', ''),
        ]);
    }

    public function showResetSuccess(): View
    {
        return view('auth.reset-password-success');
    }

    public function sendResetLink(Request $request)
    {
        $request->validate([
            'email' => ['required', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'not_regex:' . self::EMOJI_REGEX],
        ], [
            'email.not_regex' => 'Emoji characters are not allowed.',
        ]);

        $status = Password::sendResetLink(
            $request->only('email')
        );

        if ($status === Password::RESET_LINK_SENT) {
            return response()->json([
                'message' => __($status),
            ], 200);
        }

        throw ValidationException::withMessages([
            'email' => [__($status)],
        ]);
    }

    public function resetPassword(Request $request)
    {
        $status = $this->performReset($request);

        if ($status === Password::PASSWORD_RESET) {
            return response()->json([
                'message' => __($status),
            ], 200);
        }

        throw ValidationException::withMessages([
            'email' => [__($status)],
        ]);
    }

    public function resetPasswordWeb(Request $request): Response
    {
        $status = $this->performReset($request);

        if ($status === Password::PASSWORD_RESET) {
            return redirect()
                ->route('password.reset.success')
                ->with('status', 'Your password has been reset successfully. Opening the app now.');
        }

        return back()
            ->withInput($request->only('email', 'token'))
            ->withErrors([
                'email' => [__($status)],
            ]);
    }

    private function performReset(Request $request): string
    {
        $request->validate([
            'token' => 'required',
            'email' => ['required', 'email', 'regex:/^[^\s@]+@[^\s@]+\.[^\s@]+$/', 'not_regex:' . self::EMOJI_REGEX],
            'password' => 'required|min:8|confirmed',
        ], [
            'email.not_regex' => 'Emoji characters are not allowed.',
        ]);

        return Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function (User $user, string $password) {
                $user->forceFill([
                    'password' => Hash::make($password),
                    'remember_token' => Str::random(60),
                ])->save();

                event(new PasswordReset($user));
            }
        );
    }
}
