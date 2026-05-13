param(
  [Parameter(Mandatory = $true)]
  [string]$AppDir,

  [Parameter(Mandatory = $true)]
  [ValidateSet('edge', 'chrome')]
  [string]$DeviceId,

  [Parameter(Mandatory = $true)]
  [int]$WebPort,

  [string]$ApiHost = '127.0.0.1',

  [int]$ApiPort = 8000
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$appPath = Join-Path $workspaceRoot $AppDir
$flutterWrapper = Join-Path $PSScriptRoot 'flutterw.ps1'

if (-not (Test-Path $appPath)) {
  throw "App directory not found: $appPath"
}

Push-Location $appPath
try {
  & $flutterWrapper -FlutterArgs @(
    'run',
    '-d',
    $DeviceId,
    '--web-hostname',
    '127.0.0.1',
    '--web-port',
    "$WebPort",
    '--dart-define',
    "API_HOST=$ApiHost",
    '--dart-define',
    "API_PORT=$ApiPort"
  )

  exit $LASTEXITCODE
} finally {
  Pop-Location
}
