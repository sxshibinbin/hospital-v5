param(
  [Parameter(Mandatory = $true)][string]$BuildProfile,
  [Parameter(Mandatory = $true)][string]$OhosProjectDir
)

$profile = Get-Content -LiteralPath $BuildProfile -Raw | ConvertFrom-Json
$config = @($profile.app.signingConfigs) | Where-Object { $_.name -eq 'release' } | Select-Object -First 1
if ($null -eq $config) { exit 0 }

$material = $config.material
function Resolve-PathValue([string]$Value) {
  if ([string]::IsNullOrWhiteSpace($Value)) { return '' }
  if ([System.IO.Path]::IsPathRooted($Value)) { return $Value }
  return [System.IO.Path]::GetFullPath((Join-Path $OhosProjectDir $Value))
}
function Emit-Set([string]$Name, [string]$Value) {
  if (-not [string]::IsNullOrWhiteSpace($Value)) {
    $escaped = $Value.Replace('"', '""')
    Write-Output "if not defined $Name set `"$Name=$escaped`""
  }
}

Emit-Set 'OHOS_KEY_ALIAS' $material.keyAlias
Emit-Set 'OHOS_KEY_PWD' $material.keyPassword
Emit-Set 'OHOS_KEYSTORE_PWD' $material.storePassword
Emit-Set 'OHOS_KEYSTORE_FILE' (Resolve-PathValue $material.storeFile)
Emit-Set 'OHOS_CERT_FILE' (Resolve-PathValue $material.certpath)
Emit-Set 'OHOS_PROFILE_FILE' (Resolve-PathValue $material.profile)
