param(
    [string]$ComPort = "COM14",
    [string]$IdfRootWsl = "/home/thete/esp-idf-5.5.1",
    [string]$Board = "ESP32_GENERIC_C5",
    [string]$Chip = "",
    [string]$MicropythonTag = "v1.27.0",
    [string]$BuildInstance = "",
    [string]$UserCModulesPath = "",
    [string]$PartitionCsv = "",
    [string]$ArtifactsRoot = "artifacts/esp32c5",
    [string]$SmokeExpr = "import sys,os; print(sys.implementation); print(os.uname())",
    [int]$SmokeRetries = 5,
    [int]$SmokeRetryDelaySeconds = 2,
    [switch]$SkipBuild,
    [switch]$SkipFlash,
    [switch]$SkipSmoke
)

$ErrorActionPreference = "Stop"

function Resolve-ChipFromBoard {
    param(
        [string]$BoardName,
        [string]$ChipArg
    )
    if (-not [string]::IsNullOrWhiteSpace($ChipArg)) {
        return $ChipArg.ToLowerInvariant()
    }

    $normalizedBoard = $BoardName.ToUpperInvariant()
    if ($normalizedBoard -like "*C6*") {
        return "esp32c6"
    }
    if ($normalizedBoard -like "*C5*") {
        return "esp32c5"
    }
    if ($normalizedBoard -like "*S3*") {
        return "esp32s3"
    }
    if ($normalizedBoard -like "*C3*") {
        return "esp32c3"
    }
    if ($normalizedBoard -like "*S2*") {
        return "esp32s2"
    }
    if ($normalizedBoard -like "*P4*") {
        return "esp32p4"
    }
    if ($normalizedBoard -like "*ESP32*") {
        return "esp32"
    }
    throw "Cannot resolve esptool chip from board: $BoardName. Pass -Chip explicitly."
}

$resolvedChip = Resolve-ChipFromBoard -BoardName $Board -ChipArg $Chip

if ([string]::IsNullOrWhiteSpace($BuildInstance)) {
    $BuildInstance = ($Board.ToLowerInvariant() -replace "[^a-z0-9]+", "-") + "-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$resolvedRoot = (Resolve-Path -Path ".").Path
$artifactsRootAbs = Join-Path $resolvedRoot $ArtifactsRoot
New-Item -ItemType Directory -Path $artifactsRootAbs -Force | Out-Null
$artifactDirAbs = Join-Path $artifactsRootAbs $BuildInstance
New-Item -ItemType Directory -Path $artifactDirAbs -Force | Out-Null

$allPorts = [System.IO.Ports.SerialPort]::GetPortNames()
if ($allPorts -notcontains $ComPort) {
    throw "COM port not found: $ComPort"
}
if ($SmokeRetries -lt 1 -or $SmokeRetries -gt 20) {
    throw "SmokeRetries must be in range 1..20"
}
if ($SmokeRetryDelaySeconds -lt 1 -or $SmokeRetryDelaySeconds -gt 30) {
    throw "SmokeRetryDelaySeconds must be in range 1..30"
}

if (-not $SkipBuild) {
    $scriptAbs = Join-Path $resolvedRoot "scripts/wsl_build_micropython_c5.sh"
    if (-not (Test-Path $scriptAbs)) {
        throw "WSL build script missing: $scriptAbs"
    }

    $scriptAbsForWsl = $scriptAbs -replace "\\", "/"
    $artifactDirAbsForWsl = $artifactDirAbs -replace "\\", "/"
    $scriptWsl = (& wsl.exe wslpath -a "$scriptAbsForWsl").Trim()
    $artifactDirWsl = (& wsl.exe wslpath -a "$artifactDirAbsForWsl").Trim()
    if ([string]::IsNullOrWhiteSpace($scriptWsl) -or [string]::IsNullOrWhiteSpace($artifactDirWsl)) {
        throw "Could not translate Windows paths to WSL paths."
    }

    $buildCmd = "'$scriptWsl' --idf-root '$IdfRootWsl' --board '$Board' --tag '$MicropythonTag' --instance '$BuildInstance' --artifact-dir '$artifactDirWsl'"
    if (-not [string]::IsNullOrWhiteSpace($UserCModulesPath)) {
        $userCModulesAbs = (Resolve-Path -Path $UserCModulesPath).Path
        $userCModulesAbsForWsl = $userCModulesAbs -replace "\\", "/"
        $userCModulesWsl = (& wsl.exe wslpath -a "$userCModulesAbsForWsl").Trim()
        if ([string]::IsNullOrWhiteSpace($userCModulesWsl)) {
            throw "Could not translate USER_C_MODULES path to WSL: $UserCModulesPath"
        }
        $buildCmd += " --user-c-modules '$userCModulesWsl'"
    }
    if (-not [string]::IsNullOrWhiteSpace($PartitionCsv)) {
        $partitionCsvAbs = (Resolve-Path -Path $PartitionCsv).Path
        $partitionCsvAbsForWsl = $partitionCsvAbs -replace "\\", "/"
        $partitionCsvWsl = (& wsl.exe wslpath -a "$partitionCsvAbsForWsl").Trim()
        if ([string]::IsNullOrWhiteSpace($partitionCsvWsl)) {
            throw "Could not translate partition csv path to WSL: $PartitionCsv"
        }
        $buildCmd += " --partition-csv '$partitionCsvWsl'"
    }
    & wsl.exe bash -lc $buildCmd
    if ($LASTEXITCODE -ne 0) {
        throw "WSL build failed with code $LASTEXITCODE"
    }
}

$flashArgs = Join-Path $artifactDirAbs "flash_args"
$required = @(
    $flashArgs,
    (Join-Path $artifactDirAbs "micropython.bin"),
    (Join-Path $artifactDirAbs "bootloader/bootloader.bin"),
    (Join-Path $artifactDirAbs "partition_table/partition-table.bin")
)
foreach ($file in $required) {
    if (-not (Test-Path $file)) {
        throw "Missing artifact: $file"
    }
}

if (-not $SkipFlash) {
    Push-Location $artifactDirAbs
    try {
        & python -m esptool --chip $resolvedChip -p $ComPort -b 460800 --before default_reset --after hard_reset --no-stub write_flash "@flash_args"
        if ($LASTEXITCODE -ne 0) {
            throw "Flashing failed with code $LASTEXITCODE"
        }
    } finally {
        Pop-Location
    }
}

if (-not $SkipSmoke) {
    Start-Sleep -Seconds 4
    $smokePassed = $false
    for ($attempt = 1; $attempt -le $SmokeRetries; $attempt++) {
        & python -m mpremote connect $ComPort exec $SmokeExpr
        if ($LASTEXITCODE -eq 0) {
            $smokePassed = $true
            break
        }
        if ($attempt -lt $SmokeRetries) {
            Start-Sleep -Seconds $SmokeRetryDelaySeconds
        }
    }
    if (-not $smokePassed) {
        throw "Smoke test failed after $SmokeRetries attempts"
    }
}

Write-Host "Chip: $resolvedChip"
Write-Host "Build instance: $BuildInstance"
Write-Host "Artifacts: $artifactDirAbs"
Write-Host "Done."
