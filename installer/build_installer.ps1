# Build and Package CafeFlow Installer & Portable Bundle
param (
    [switch]$SkipFlutterBuild = $false
)

$ErrorActionPreference = "Stop"

Write-Host "======================================================" -ForegroundColor Cyan
Write-Host " CafeFlow Windows Production Installer Builder " -ForegroundColor Cyan
Write-Host "======================================================" -ForegroundColor Cyan

# 1. Project directories
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectDir = Split-Path -Parent $ScriptDir
$ReleaseDir = Join-Path $ProjectDir "build\windows\x64\runner\Release"
$InstallerOutputDir = Join-Path $ProjectDir "build\installer"
$IssScript = Join-Path $ScriptDir "cafe_flow_setup.iss"

# 2. Build Flutter release if needed
if (-not $SkipFlutterBuild) {
    Write-Host "`n[1/4] Building Flutter Windows application in Release mode..." -ForegroundColor Yellow
    Push-Location $ProjectDir
    try {
        & flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter build failed with code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
} else {
    Write-Host "`n[1/4] Skipping Flutter build (--SkipFlutterBuild specified)..." -ForegroundColor DarkGray
}

if (-not (Test-Path "$ReleaseDir\cafe_flow.exe")) {
    throw "Release executable not found at '$ReleaseDir\cafe_flow.exe'!"
}

# 3. Ensure Output Directory exists
if (-not (Test-Path $InstallerOutputDir)) {
    New-Item -ItemType Directory -Path $InstallerOutputDir -Force | Out-Null
}

# 4. Locate or Install Inno Setup
Write-Host "`n[2/4] Checking Inno Setup Compiler (ISCC.exe)..." -ForegroundColor Yellow

$IsccPath = $null
$PossiblePaths = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    (Get-Command iscc.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source)
)

foreach ($p in $PossiblePaths) {
    if ($p -and (Test-Path $p)) {
        $IsccPath = $p
        break
    }
}

if (-not $IsccPath) {
    Write-Host "Inno Setup not detected. Installing Inno Setup via winget..." -ForegroundColor Yellow
    & winget install --id JR.InnoSetup -e --silent --accept-source-agreements --accept-package-agreements
    
    foreach ($p in $PossiblePaths) {
        if ($p -and (Test-Path $p)) {
            $IsccPath = $p
            break
        }
    }
}

if (-not $IsccPath) {
    Write-Warning "Inno Setup Compiler (ISCC.exe) could not be located. Please install Inno Setup from https://jrsoftware.org/isdl.php"
} else {
    Write-Host "Found Inno Setup Compiler at: $IsccPath" -ForegroundColor Green
    
    # 5. Compile Inno Setup Script
    Write-Host "`n[3/4] Compiling Windows Installer Setup (.exe)..." -ForegroundColor Yellow
    Push-Location $ScriptDir
    try {
        & "$IsccPath" "$IssScript"
        if ($LASTEXITCODE -ne 0) {
            throw "Inno Setup compilation failed with code $LASTEXITCODE"
        }
        Write-Host "Installer compiled successfully!" -ForegroundColor Green
    } finally {
        Pop-Location
    }
}

# 6. Create Portable Zip
Write-Host "`n[4/4] Creating Portable ZIP archive..." -ForegroundColor Yellow
$ZipPath = Join-Path $InstallerOutputDir "QodexCafeFlow_Portable_v1.0.0.zip"
if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}
Compress-Archive -Path "$ReleaseDir\*" -DestinationPath $ZipPath -CompressionLevel Optimal
Write-Host "Portable archive created at: $ZipPath" -ForegroundColor Green

Write-Host "`n======================================================" -ForegroundColor Cyan
Write-Host " Build Complete! Artifacts ready in: build\installer" -ForegroundColor Cyan
Get-ChildItem -Path $InstallerOutputDir | Select-Object Name, @{Name="Size(MB)";Expression={[math]::Round($_.Length/1MB, 2)}}, LastWriteTime | Format-Table -AutoSize
Write-Host "======================================================" -ForegroundColor Cyan
