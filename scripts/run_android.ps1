[CmdletBinding()]
param(
    [string]$DeviceId,
    [switch]$SkipBuild,
    [switch]$CheckOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$packageName = 'com.aivoicedocs.app'

function Invoke-CheckedNative {
    param([string]$Executable, [string[]]$Arguments)
    # Windows PowerShell can represent native stderr as ErrorRecord objects.
    # Preserve the exit code and text rather than mistaking a warning for failure.
    $ErrorActionPreference = 'Continue'
    $lines = & $Executable @Arguments 2>&1
    $nativeExit = $LASTEXITCODE
    $result = ($lines | ForEach-Object { "$_" }) -join "`n"
    if ($nativeExit -ne 0) { throw "$Executable exited with code ${nativeExit}:`n$result" }
    return $result
}

Push-Location -LiteralPath $projectRoot
try {
    $sdkPath = $env:ANDROID_SDK_ROOT
    if (-not $sdkPath) { $sdkPath = $env:ANDROID_HOME }
    if (-not $sdkPath) {
        $properties = Join-Path $projectRoot 'android/local.properties'
        if (Test-Path -LiteralPath $properties) {
            $sdkLine = Get-Content -LiteralPath $properties | Where-Object { $_ -match '^sdk.dir=' } | Select-Object -First 1
            if ($sdkLine) { $sdkPath = $sdkLine.Substring(8).Replace('\\', '\').Replace('\:', ':') }
        }
    }
    if (-not $sdkPath) { $sdkPath = Join-Path $env:LOCALAPPDATA 'Android/Sdk' }
    $adbPath = Join-Path $sdkPath 'platform-tools/adb.exe'
    if (-not (Test-Path -LiteralPath $adbPath)) { throw 'Android platform-tools are missing. Configure ANDROID_SDK_ROOT or android/local.properties.' }

    if (-not $CheckOnly) {
        $deviceList = Invoke-CheckedNative $adbPath @('devices')
        $connected = @($deviceList -split "`n" | ForEach-Object {
            if ($_ -match '^(\S+)\s+device(?:\s|$)') { $Matches[1] }
        })
        if ($DeviceId) {
            if ($DeviceId -notin $connected) { throw "Device $DeviceId is not connected and authorized." }
        } elseif ($connected.Count -eq 1) { $DeviceId = $connected[0] }
        elseif ($connected.Count -eq 0) { throw 'No authorized Android device. Connect your phone, unlock it, and approve USB debugging.' }
        else { throw 'Multiple Android devices are connected. Pass -DeviceId with the intended serial.' }
    }

    if (-not $SkipBuild -and -not $CheckOnly) {
        & flutter pub get --enforce-lockfile
        if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
        & dart run build_runner build
        if ($LASTEXITCODE -ne 0) { throw 'Model generation failed.' }
        & flutter build apk --debug
        if ($LASTEXITCODE -ne 0) { throw 'Android build failed.' }
    }

    $apkPath = Join-Path $projectRoot 'build/app/outputs/flutter-apk/app-debug.apk'
    if (-not (Test-Path -LiteralPath $apkPath)) { throw 'No debug APK. Run this script without -SkipBuild first.' }
    $buildTools = Get-ChildItem -LiteralPath (Join-Path $sdkPath 'build-tools') -Directory |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending | Select-Object -First 1
    if (-not $buildTools) { throw 'Android SDK build-tools are missing.' }
    $badging = Invoke-CheckedNative (Join-Path $buildTools.FullName 'aapt.exe') @('dump', 'badging', $apkPath)
    if ($badging -notmatch "package: name='([^']+)' versionCode='(\d+)'") { throw 'APK metadata could not be read.' }
    if ($Matches[1] -ne $packageName) { throw 'The APK belongs to a different application.' }
    $apkVersion = [long]$Matches[2]
    $pubspec = Get-Content -LiteralPath (Join-Path $projectRoot 'pubspec.yaml') -Raw
    if ($pubspec -notmatch '(?m)^version:\s*[^\r\n]+\+(\d+)\s*$') { throw 'pubspec.yaml has no numeric build number.' }
    if ($apkVersion -ne [long]$Matches[1]) { throw 'The APK build number differs from pubspec.yaml. Rebuild before installing.' }

    $javaPath = $null
    if ($env:JAVA_HOME) { $javaPath = Join-Path $env:JAVA_HOME 'bin/java.exe' }
    if (-not $javaPath -or -not (Test-Path -LiteralPath $javaPath)) {
        $javaCommand = Get-Command java -ErrorAction SilentlyContinue
        if ($javaCommand) { $javaPath = $javaCommand.Source }
        else { $javaPath = Join-Path $env:ProgramFiles 'Android/Android Studio/jbr/bin/java.exe' }
    }
    if (-not (Test-Path -LiteralPath $javaPath)) { throw 'Java 17 or later is needed to verify the APK signature.' }
    $signerJar = Join-Path $buildTools.FullName 'lib/apksigner.jar'
    [void](Invoke-CheckedNative $javaPath @('-jar', $signerJar, 'verify', $apkPath))
    Write-Host "Verified Android APK: $packageName, build $apkVersion."
    if ($CheckOnly) { return }

    $installed = Invoke-CheckedNative $adbPath @('-s', $DeviceId, 'shell', 'dumpsys', 'package', $packageName)
    if ($installed -match 'versionCode=(\d+)') {
        if ([long]$Matches[1] -gt $apkVersion) { throw 'A newer version is installed. Increase the project build number and rebuild; app data will not be removed.' }
    }
    Write-Host "Updating $DeviceId in place..."
    # -r retains app data. Deliberately no uninstall or downgrade fallback.
    Write-Host (Invoke-CheckedNative $adbPath @('-s', $DeviceId, 'install', '-r', $apkPath))
    $launch = Invoke-CheckedNative $adbPath @('-s', $DeviceId, 'shell', 'am', 'start', '-W', '-n', "$packageName/.MainActivity")
    if ($launch -match 'Error:|Exception') { throw "The app could not launch: $launch" }
    Write-Host $launch
    $appProcess = Invoke-CheckedNative $adbPath @('-s', $DeviceId, 'shell', 'pidof', $packageName)
    if (-not $appProcess.Trim()) { throw 'The app process exited after launch. Check Android crash logs.' }
    Write-Host "Android app is running on $DeviceId (PID $($appProcess.Trim()))."
} finally {
    Pop-Location
}