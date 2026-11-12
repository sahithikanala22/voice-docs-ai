param(
  [string]$IdentityFile = 'release/identity.json',
  [string]$FlutterSdk = 'C:\flutter'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
  $dart = Join-Path $FlutterSdk 'bin/cache/dart-sdk/bin/dart.exe'
  $flutter = Join-Path $FlutterSdk 'bin/flutter.bat'
  if (!(Test-Path -LiteralPath $dart)) { throw 'Flutter SDK was not found. Set -FlutterSdk.' }
  & $flutter pub get --enforce-lockfile
  if ($LASTEXITCODE -ne 0) { throw 'Dependency resolution failed.' }
  & $dart run scripts/prepare_play_release.dart $IdentityFile
  if ($LASTEXITCODE -ne 0) { throw 'Complete the developer identity first.' }
  $java = if ($env:JAVA_HOME) { Join-Path $env:JAVA_HOME 'bin/java.exe' }
    else { 'C:\Program Files\Android\Android Studio\jbr\bin\java.exe' }
  & $java scripts/VerifyUploadKey.java android/key.properties
  if ($LASTEXITCODE -ne 0) { throw 'The upload signing key could not be verified.' }

  & $dart run build_runner build
  if ($LASTEXITCODE -ne 0) { throw 'Code generation failed.' }
  & $dart format --output=none --set-exit-if-changed lib test scripts
  if ($LASTEXITCODE -ne 0) { throw 'Formatting needs attention.' }
  & $flutter analyze --fatal-infos
  if ($LASTEXITCODE -ne 0) { throw 'Static analysis failed.' }
  & $flutter test
  if ($LASTEXITCODE -ne 0) { throw 'Tests failed.' }
  & $flutter test scripts/render_store_artwork.dart
  if ($LASTEXITCODE -ne 0) { throw 'Store artwork generation failed.' }
  & $flutter build appbundle --release "--dart-define-from-file=$IdentityFile"
  if ($LASTEXITCODE -ne 0) { throw 'Release bundle build failed.' }
  & $dart run scripts/check_android_bundle.dart build/app/outputs/bundle/release/app-release.aab
  if ($LASTEXITCODE -ne 0) { throw 'Native compatibility checks failed.' }
  Write-Output 'Release candidate built. Complete the device test matrix and Play Console setup in release/README.md.'
} finally { Pop-Location }
