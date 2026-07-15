param(
    [ValidateSet("win-x64", "win-arm64")]
    [string]$Runtime = "win-x64",
    [string]$CertificateThumbprint = ""
)

$ErrorActionPreference = "Stop"
$ProjectDir = $PSScriptRoot
$DistDir = Join-Path $ProjectDir "dist"
$PublishDir = Join-Path $DistDir $Runtime
$ZipPath = Join-Path $DistDir "fukura-$Runtime.zip"

if (Test-Path $PublishDir) { Remove-Item $PublishDir -Recurse -Force }
dotnet publish (Join-Path $ProjectDir "FukuraWindows.csproj") `
    -c Release `
    -r $Runtime `
    --self-contained true `
    -p:PublishSingleFile=true `
    -p:EnableCompressionInSingleFile=true `
    -o $PublishDir

$ExePath = Join-Path $PublishDir "fukura.exe"
if ($CertificateThumbprint) {
    $SignTool = Get-Command signtool.exe -ErrorAction Stop
    & $SignTool.Source sign /sha1 $CertificateThumbprint /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 $ExePath
}

if (Test-Path $ZipPath) { Remove-Item $ZipPath -Force }
Compress-Archive -Path (Join-Path $PublishDir "*") -DestinationPath $ZipPath
Write-Host "Created: $ZipPath"
