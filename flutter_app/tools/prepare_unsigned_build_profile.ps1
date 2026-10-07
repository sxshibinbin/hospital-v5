param(
  [Parameter(Mandatory = $true)]
  [string]$BuildProfile
)

$ErrorActionPreference = 'Stop'
$profile = Get-Content -LiteralPath $BuildProfile -Raw | ConvertFrom-Json
foreach ($product in @($profile.app.products)) {
  $property = $product.PSObject.Properties['signingConfig']
  if ($null -ne $property) {
    $product.PSObject.Properties.Remove('signingConfig')
  }
}

$json = $profile | ConvertTo-Json -Depth 64
$encoding = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($BuildProfile, $json, $encoding)
