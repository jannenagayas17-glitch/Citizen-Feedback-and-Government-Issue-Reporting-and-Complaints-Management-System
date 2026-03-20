<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Password Reset Complete</title>
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
            text-align: center;
        }

        h1 {
            margin: 0 0 10px;
            font-size: 28px;
        }

        p {
            margin: 0 0 18px;
            line-height: 1.5;
            color: rgba(255, 255, 255, 0.76);
        }

        a.button {
            display: inline-block;
            margin-top: 8px;
            padding: 14px 18px;
            border-radius: 12px;
            background: #2563eb;
            color: #fff;
            font-size: 15px;
            font-weight: 700;
            text-decoration: none;
        }
    </style>
</head>
<body>
    <div class="card">
        <h1>Password Updated</h1>
        <p>{{ session('status', 'Your password has been reset successfully.') }}</p>
        <p>We are sending you back to the mobile app login now.</p>
        <a class="button" href="cityengineeringoffice://login">Open App</a>
    </div>

    <script>
        window.setTimeout(function () {
            window.location.href = 'cityengineeringoffice://login';
        }, 900);
    </script>
</body>
</html>
