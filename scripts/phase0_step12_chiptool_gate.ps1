param(
    [string]$CommissioningDataPath = "",
    [string]$CommissioningCodesDataPath = "",
    [string]$ChipToolPath = "",
    [string]$ChipToolWslPath = "",
    [UInt64]$NodeId = 112233,
    [switch]$RunPairing,
    [switch]$UseOnNetworkLong = $true,
    [string]$Instance = "",
    [string]$ArtifactsRoot = "artifacts/commissioning"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Instance)) {
    $Instance = "c12-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$resolvedRoot = (Resolve-Path -Path ".").Path
$artifactsRootAbs = Join-Path $resolvedRoot $ArtifactsRoot
New-Item -ItemType Directory -Path $artifactsRootAbs -Force | Out-Null
$artifactDirAbs = Join-Path $artifactsRootAbs $Instance
New-Item -ItemType Directory -Path $artifactDirAbs -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($CommissioningDataPath)) {
    $latestData = Get-ChildItem -Path $artifactsRootAbs -Recurse -File -Filter "commissioning_data.json" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latestData) {
        throw "No commissioning_data.json found under $artifactsRootAbs"
    }
    $CommissioningDataPath = $latestData.FullName
}

$commissioningDataAbs = (Resolve-Path -Path $CommissioningDataPath).Path
$commissioningData = Get-Content -Path $commissioningDataAbs -Raw | ConvertFrom-Json

$passcode = [int]$commissioningData.passcode
$discriminator = [int]$commissioningData.discriminator
$expectedManualCode = "{0:d3}{1:d8}" -f ($discriminator -band 0x000F), $passcode

if ($passcode -lt 1 -or $passcode -gt 99999998) {
    throw "Invalid passcode in commissioning_data.json: $passcode"
}
if ($discriminator -lt 0 -or $discriminator -gt 4095) {
    throw "Invalid discriminator in commissioning_data.json: $discriminator"
}

$codesDataAbs = ""
$codesData = $null
$codesStatus = "missing"
$codesStatusReason = "commissioning codes data not found"
$nodeManualCode = $expectedManualCode
$nodeQrCode = ""
$manualCodeSource = "computed"

if (-not [string]::IsNullOrWhiteSpace($CommissioningCodesDataPath)) {
    $codesDataAbs = (Resolve-Path -Path $CommissioningCodesDataPath).Path
} else {
    $candidates = Get-ChildItem -Path $artifactsRootAbs -Recurse -File -Filter "commissioning_codes_data.json" |
        Sort-Object LastWriteTime -Descending
    foreach ($candidate in $candidates) {
        try {
            $candidateData = Get-Content -Path $candidate.FullName -Raw | ConvertFrom-Json
            if ([int]$candidateData.passcode -eq $passcode -and [int]$candidateData.discriminator -eq $discriminator) {
                $codesDataAbs = $candidate.FullName
                break
            }
        } catch {
        }
    }
}

if (-not [string]::IsNullOrWhiteSpace($codesDataAbs)) {
    try {
        $codesData = Get-Content -Path $codesDataAbs -Raw | ConvertFrom-Json
        $codesStatus = "matched"
        $codesStatusReason = "commissioning codes loaded"

        if ([int]$codesData.passcode -ne $passcode -or [int]$codesData.discriminator -ne $discriminator) {
            $codesStatus = "mismatch"
            $codesStatusReason = "commissioning codes passcode/discriminator differ from commissioning_data.json"
        }

        if (-not [string]::IsNullOrWhiteSpace($codesData.node_manual_code)) {
            $nodeManualCode = [string]$codesData.node_manual_code
            $manualCodeSource = "codes_data"
        } elseif (-not [string]::IsNullOrWhiteSpace($codesData.expected_manual_code)) {
            $nodeManualCode = [string]$codesData.expected_manual_code
            $manualCodeSource = "codes_data_expected"
        }

        if (-not [string]::IsNullOrWhiteSpace($codesData.node_qr_code)) {
            $nodeQrCode = [string]$codesData.node_qr_code
        }
    } catch {
        $codesStatus = "invalid"
        $codesStatusReason = "failed to parse commissioning codes data JSON"
        $codesData = $null
    }
}

$chipToolResolved = ""
$chipToolMode = "missing"

if (-not [string]::IsNullOrWhiteSpace($ChipToolWslPath)) {
    $chipToolResolved = $ChipToolWslPath.Trim()
    $chipToolMode = "wsl"
} elseif (-not [string]::IsNullOrWhiteSpace($ChipToolPath)) {
    $resolvedCandidate = (Resolve-Path -Path $ChipToolPath).Path
    if ($resolvedCandidate -like "\\wsl.localhost\*") {
        $wslPath = (& wsl.exe wslpath -a "$resolvedCandidate" 2>$null | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($wslPath)) {
            $chipToolResolved = $wslPath
            $chipToolMode = "wsl"
        }
    } else {
        $chipToolResolved = $resolvedCandidate
        $chipToolMode = "windows"
    }
} else {
    $cmd = Get-Command chip-tool -ErrorAction SilentlyContinue
    if ($null -ne $cmd) {
        $chipToolResolved = $cmd.Source
        $chipToolMode = "windows"
    } else {
        $wslChipTool = (& wsl.exe bash -lc "command -v chip-tool || true" 2>$null | Out-String).Trim()
        if (-not [string]::IsNullOrWhiteSpace($wslChipTool)) {
            $chipToolResolved = $wslChipTool
            $chipToolMode = "wsl"
        }
    }
}

function Invoke-ChipToolCommand {
    param(
        [string]$Mode,
        [string]$BinaryPath,
        [string[]]$ToolArgs
    )

    if ($Mode -eq "windows") {
        $prevNative = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
        try {
            $output = (& $BinaryPath @ToolArgs 2>&1 | Out-String)
        } finally {
            $PSNativeCommandUseErrorActionPreference = $prevNative
        }
        return [PSCustomObject]@{
            Output = $output
            ExitCode = $LASTEXITCODE
        }
    }

    if ($Mode -eq "wsl") {
        $cmdLine = $BinaryPath
        if ($ToolArgs.Count -gt 0) {
            $cmdLine += " " + ($ToolArgs -join " ")
        }
        $prevErr = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $output = (& wsl.exe -d Ubuntu bash -lc $cmdLine 2>&1 | Out-String)
        } finally {
            $ErrorActionPreference = $prevErr
        }
        return [PSCustomObject]@{
            Output = $output
            ExitCode = $LASTEXITCODE
        }
    }

    throw "Unsupported chip-tool mode: $Mode"
}

$preflightLogPath = Join-Path $artifactDirAbs "chiptool_preflight.log"
$pairingLogPath = Join-Path $artifactDirAbs "chiptool_pairing.log"
$matrixMdPath = Join-Path $artifactDirAbs "chiptool_matrix_row.md"
$resultJsonPath = Join-Path $artifactDirAbs "chiptool_gate_result.json"

$preflightOutput = ""
$pairingOutput = ""
$preflightExit = -999
$pairingExit = -999
$status = "blocked_tool_missing"
$statusReason = "chip-tool binary not found in PATH"
$pairingMode = "onnetwork-long"
if (-not $UseOnNetworkLong) {
    $pairingMode = "onnetwork"
}
$pairingCommand = "chip-tool pairing $pairingMode $NodeId $passcode $discriminator"

$pairingArgs = @("pairing", $pairingMode, "$NodeId", "$passcode", "$discriminator")

if (-not [string]::IsNullOrWhiteSpace($chipToolResolved)) {
    $preflightResult = Invoke-ChipToolCommand -Mode $chipToolMode -BinaryPath $chipToolResolved -ToolArgs @("pairing")
    $preflightOutput = $preflightResult.Output
    $preflightExit = $preflightResult.ExitCode
    Set-Content -Path $preflightLogPath -Value $preflightOutput -Encoding UTF8

    $preflightLooksValid = $preflightOutput -match "Commands for commissioning devices\." -or $preflightOutput -match "Usage:"
    if ($preflightLooksValid) {
        if ($RunPairing) {
            $pairingResult = Invoke-ChipToolCommand -Mode $chipToolMode -BinaryPath $chipToolResolved -ToolArgs $pairingArgs
            $pairingOutput = $pairingResult.Output
            $pairingExit = $pairingResult.ExitCode
            Set-Content -Path $pairingLogPath -Value $pairingOutput -Encoding UTF8
            if ($pairingExit -eq 0) {
                $status = "pass"
                $statusReason = "pairing command completed successfully"
            } else {
                $status = "fail_pairing"
                $statusReason = "pairing command returned non-zero"
                $pairingOutputLower = $pairingOutput.ToLowerInvariant()
                if ($pairingOutputLower -match "timeout waiting for mdns resolution") {
                    $statusReason = "pairing timeout waiting for mDNS resolution"
                } elseif ($pairingOutputLower -match "chip error 0x00000032: timeout") {
                    $statusReason = "pairing timeout in chip-tool command flow"
                } elseif ($pairingOutputLower -match "pase") {
                    $statusReason = "pairing failed during PASE/session establishment"
                } elseif ($pairingOutputLower -match "unknown command") {
                    $statusReason = "pairing command syntax rejected by chip-tool"
                }
            }
        } else {
            $status = "preflight_ready"
            $statusReason = "chip-tool available, command-set preflight passed"
        }
    } else {
        $status = "fail_preflight"
        $statusReason = "chip-tool preflight output did not match expected command-set usage"
    }
} else {
    Set-Content -Path $preflightLogPath -Value "chip-tool not found" -Encoding UTF8
}

$detailsParts = @($statusReason, "manual=$nodeManualCode", "codes=$codesStatus")
if (-not [string]::IsNullOrWhiteSpace($nodeQrCode)) {
    $detailsParts += "qr=$nodeQrCode"
}
$detailsJoined = ($detailsParts -join "; ").Replace('|', '/')

$matrixRow = @(
    "| board | transport | controller | test | status | details |"
    "|---|---|---|---|---|---|"
    ("| ESP32-C6 | commissioning-placeholder | chip-tool | pairing {0} | {1} | {2} |" -f $pairingMode, $status, $detailsJoined)
) -join [Environment]::NewLine
Set-Content -Path $matrixMdPath -Value $matrixRow -Encoding UTF8

$result = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    instance = $Instance
    commissioning_data_path = $commissioningDataAbs
    source_instance = $commissioningData.instance
    source_com_port = $commissioningData.com_port
    passcode = $passcode
    discriminator = $discriminator
    expected_manual_code = $expectedManualCode
    manual_code = $nodeManualCode
    manual_code_source = $manualCodeSource
    node_qr_code = $nodeQrCode
    commissioning_codes_data_path = $codesDataAbs
    commissioning_codes_status = $codesStatus
    commissioning_codes_status_reason = $codesStatusReason
    node_id = $NodeId
    command = $pairingCommand
    pairing_mode = $pairingMode
    chip_tool_path = $chipToolResolved
    chip_tool_mode = $chipToolMode
    run_pairing = [bool]$RunPairing
    preflight_exit = $preflightExit
    pairing_exit = $pairingExit
    status = $status
    status_reason = $statusReason
    preflight_log = $preflightLogPath
    pairing_log = $pairingLogPath
    matrix_row_md = $matrixMdPath
}
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $resultJsonPath -Encoding UTF8

Write-Host "chip-tool gate status: $status"
Write-Host "Reason: $statusReason"
Write-Host "Artifacts: $artifactDirAbs"
