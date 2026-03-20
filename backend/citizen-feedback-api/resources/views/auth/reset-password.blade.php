<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Reset Password</title>
    <style>
        body {
            margin: 0;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            padding: 24px;
            font-family: Arial, sans-serif;
            background: linear-gradient(180deg, #0c1727 0%, #1e293b 58%, #463327 100%);
            color: #fff;
        }

        .card {
            width: 100%;
            max-width: 420px;
            padding: 28px;
            border-radius: 24px;
            border: 1px solid rgba(255, 255, 255, 0.16);
            background: rgba(18, 27, 49, 0.92);
            box-shadow: 0 18px 40px rgba(0, 0, 0, 0.32);
        }

        h1 {
            margin: 0 0 10px;
            font-size: 28px;
            text-align: center;
        }

        p {
            margin: 0 0 22px;
            line-height: 1.5;
            text-align: center;
            color: rgba(255, 255, 255, 0.76);
        }

        label {
            display: block;
            margin: 14px 0 8px;
            font-size: 14px;
            font-weight: 700;
        }

        input {
            width: 100%;
            padding: 14px 16px;
            border-radius: 12px;
            border: 1px solid rgba(255, 255, 255, 0.18);
            background: rgba(255, 255, 255, 0.09);
            color: #fff;
            font-size: 15px;
            box-sizing: border-box;
        }

        input::placeholder {
            color: rgba(255, 255, 255, 0.4);
        }

        .password-wrap {
            position: relative;
        }

        .password-wrap input {
            padding-right: 52px;
        }

        .toggle-password {
            position: absolute;
            top: 50%;
            right: 14px;
            transform: translateY(-50%);
            border: 0;
            background: transparent;
            color: rgba(255, 255, 255, 0.7);
            font-size: 13px;
            font-weight: 700;
            cursor: pointer;
            width: auto;
            margin: 0;
            padding: 0;
        }

        button {
            width: 100%;
            margin-top: 20px;
            padding: 14px 16px;
            border: 0;
            border-radius: 12px;
            background: #2563eb;
            color: #fff;
            font-size: 15px;
            font-weight: 700;
            cursor: pointer;
        }

        .status {
            margin-bottom: 16px;
            padding: 12px 14px;
            border-radius: 12px;
            background: rgba(34, 197, 94, 0.18);
            color: #d1fae5;
        }

        .error-list {
            margin: 8px 0 0;
            padding-left: 18px;
            color: #fecaca;
            font-size: 13px;
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>Reset Password</h1>
        <p>Enter your new password below, then go back to the mobile app and sign in with the updated password.</p>

        @if (session('status'))
            <div class="status">{{ session('status') }}</div>
        @endif

        <form method="POST" action="{{ route('password.update') }}">
            @csrf
            <input type="hidden" name="token" value="{{ old('token', $token) }}">

            <label for="email">Email Address</label>
            <input
                id="email"
                type="email"
                name="email"
                value="{{ old('email', $email) }}"
                required
                autocomplete="email"
            >
            @error('email')
                <ul class="error-list"><li>{{ $message }}</li></ul>
            @enderror

            <label for="password">New Password</label>
            <div class="password-wrap">
                <input
                    id="password"
                    type="password"
                    name="password"
                    required
                    autocomplete="new-password"
                >
                <button type="button" class="toggle-password" data-target="password">Show</button>
            </div>
            @error('password')
                <ul class="error-list"><li>{{ $message }}</li></ul>
            @enderror

            <label for="password_confirmation">Confirm Password</label>
            <div class="password-wrap">
                <input
                    id="password_confirmation"
                    type="password"
                    name="password_confirmation"
                    required
                    autocomplete="new-password"
                >
                <button type="button" class="toggle-password" data-target="password_confirmation">Show</button>
            </div>

            <button type="submit">Reset Password</button>
        </form>
    </div>

    <script>
        document.querySelectorAll('.toggle-password').forEach(function (button) {
            button.addEventListener('click', function () {
                const input = document.getElementById(button.dataset.target);
                const isHidden = input.type === 'password';
                input.type = isHidden ? 'text' : 'password';
                button.textContent = isHidden ? 'Hide' : 'Show';
            });
        });
    </script>
</body>
</html>
