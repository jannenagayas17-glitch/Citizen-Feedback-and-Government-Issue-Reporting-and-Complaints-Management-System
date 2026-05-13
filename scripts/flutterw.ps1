param(
  [Parameter(Position = 0, ValueFromRemainingArguments = $true)]
  [string[]]$FlutterArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FlutterFromLocalProperties {
  param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot
  )

  $mobileRoot = Join-Path $WorkspaceRoot 'mobile'
  if (-not (Test-Path $mobileRoot)) {
    return $null
  }

  $localPropertiesFiles = Get-ChildItem -Path $mobileRoot -Recurse -Filter local.properties -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match '\\android\\local\.properties$' }

  foreach ($file in $localPropertiesFiles) {
    $flutterSdkLine = Get-Content $file.FullName |
      Where-Object { $_ -like 'flutter.sdk=*' } |
      Select-Object -First 1

    if (-not $flutterSdkLine) {
      continue
    }

    $sdkPath = $flutterSdkLine.Substring('flutter.sdk='.Length).Trim()
    if (-not $sdkPath) {
      continue
    }

    $sdkPath = $sdkPath -replace '\\\\', '\'
    $flutterExecutable = Join-Path $sdkPath 'bin\flutter.bat'
    if (Test-Path $flutterExecutable) {
      return $flutterExecutable
    }
  }

  return $null
}

$workspaceRoot = Split-Path -Parent $PSScriptRoot
$flutterCandidates = @()

$flutterFromPath = Get-Command flutter -ErrorAction SilentlyContinue
if ($flutterFromPath) {
  $flutterCandidates += $flutterFromPath.Source
}

if ($env:FLUTTER_ROOT) {
  $flutterCandidates += Join-Path $env:FLUTTER_ROOT 'bin\flutter.bat'
}

$flutterFromLocalProperties = Get-FlutterFromLocalProperties -WorkspaceRoot $workspaceRoot
if ($flutterFromLocalProperties) {
  $flutterCandidates += $flutterFromLocalProperties
}

$siblingFlutter = Join-Path (Split-Path $workspaceRoot -Parent) 'flutter\bin\flutter.bat'
$flutterCandidates += $siblingFlutter

$flutterExecutable = $flutterCandidates |
  Where-Object { $_ -and (Test-Path $_) } |
  Select-Object -First 1

if (-not $flutterExecutable) {
  throw 'Unable to locate Flutter SDK. Add flutter/bin to PATH, set FLUTTER_ROOT, or update android/local.properties.'
}

& $flutterExecutable @FlutterArgs
exit $LASTEXITCODE
