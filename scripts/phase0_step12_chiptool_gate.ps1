param(
    [string]$CommissioningDataPath = "",
    [string]$CommissioningCodesDataPath = "",
    [string]$RuntimeDiagLogPath = "",
    [string]$ChipToolPath = "",
    [string]$ChipToolWslPath = "",
    [UInt64]$NodeId = 112233,
    [switch]$RunPairing,
    [string]$UseOnNetworkLong = "true",
    [string]$RequireRuntimeReadyForPairing = "true",
    [string]$RequireNetworkAdvertisingForPairing = "false",
    [string]$RequireDiscoveryFoundForPairing = "false",
    [string]$RunDiscoveryPrecheck = "true",
    [int]$DiscoveryTimeoutSeconds = 8,
    [string]$RunHostMdnsProbe = "true",
    [string]$HostMdnsProbeMode = "wsl",
    [int]$HostMdnsProbeTimeoutSeconds = 6,
    [string]$Instance = "",
    [string]$ArtifactsRoot = "artifacts/commissioning"
)

$ErrorActionPreference = "Stop"

function Convert-ToBool {
    param(
        [string]$Value,
        [string]$ParamName
    )

    $normalized = $Value.Trim().ToLowerInvariant()
    if (@("true", "1", "yes", "y", "on", "$true") -contains $normalized) {
        return $true
    }
    if (@("false", "0", "no", "n", "off", "$false") -contains $normalized) {
        return $false
    }
    throw "$ParamName must be one of: true/false/1/0/yes/no/on/off"
}

$UseOnNetworkLongBool = Convert-ToBool -Value $UseOnNetworkLong -ParamName "UseOnNetworkLong"
$RequireRuntimeReadyForPairingBool = Convert-ToBool -Value $RequireRuntimeReadyForPairing -ParamName "RequireRuntimeReadyForPairing"
$RequireNetworkAdvertisingForPairingBool = Convert-ToBool -Value $RequireNetworkAdvertisingForPairing -ParamName "RequireNetworkAdvertisingForPairing"
$RequireDiscoveryFoundForPairingBool = Convert-ToBool -Value $RequireDiscoveryFoundForPairing -ParamName "RequireDiscoveryFoundForPairing"
$RunDiscoveryPrecheckBool = Convert-ToBool -Value $RunDiscoveryPrecheck -ParamName "RunDiscoveryPrecheck"
$RunHostMdnsProbeBool = Convert-ToBool -Value $RunHostMdnsProbe -ParamName "RunHostMdnsProbe"
$HostMdnsProbeModeNormalized = $HostMdnsProbeMode.Trim().ToLowerInvariant()

if ($DiscoveryTimeoutSeconds -lt 1 -or $DiscoveryTimeoutSeconds -gt 120) {
    throw "DiscoveryTimeoutSeconds must be in range 1..120"
}
if ($HostMdnsProbeTimeoutSeconds -lt 1 -or $HostMdnsProbeTimeoutSeconds -gt 120) {
    throw "HostMdnsProbeTimeoutSeconds must be in range 1..120"
}
if (@("auto", "wsl", "windows", "both") -notcontains $HostMdnsProbeModeNormalized) {
    throw "HostMdnsProbeMode must be one of: auto, wsl, windows, both"
}
if ($RequireDiscoveryFoundForPairingBool -and -not $RunDiscoveryPrecheckBool) {
    throw "RequireDiscoveryFoundForPairing=true requires RunDiscoveryPrecheck=true"
}

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

function Resolve-WslChipToolAutoPath {
    $fromPath = (& wsl.exe -d Ubuntu bash -lc 'command -v chip-tool || true' 2>$null | Out-String).Trim()
    if (-not [string]::IsNullOrWhiteSpace($fromPath)) {
        return $fromPath
    }

    $homePath = (& wsl.exe -d Ubuntu bash -lc 'printf "%s" "$HOME"' 2>$null | Out-String).Trim()
    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($env:CHIP_TOOL_WSL_PATH)) {
        $candidates += $env:CHIP_TOOL_WSL_PATH.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($env:CHIP_TOOL_PATH)) {
        $candidates += $env:CHIP_TOOL_PATH.Trim()
    }
    if (-not [string]::IsNullOrWhiteSpace($homePath)) {
        $candidates += "$homePath/umatter-work/connectedhomeip/out/chip-tool/chip-tool"
        $candidates += "$homePath/connectedhomeip/out/chip-tool/chip-tool"
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        $null = (& wsl.exe -d Ubuntu test -x $candidate 2>$null | Out-String)
        if ($LASTEXITCODE -eq 0) {
            return $candidate
        }
    }

    return ""
}

function Resolve-WslPathFromWindowsPath {
    param(
        [string]$WindowsPath
    )

    if ([string]::IsNullOrWhiteSpace($WindowsPath)) {
        return ""
    }

    $candidate = $WindowsPath -replace "\\", "/"
    return (& wsl.exe wslpath -a "$candidate" 2>$null | Out-String).Trim()
}

function Convert-ProbeOutputToResult {
    param(
        [string]$Mode,
        [string]$Output,
        [int]$ExitCode,
        [string]$ResultJsonPath
    )

    $probeData = $null
    try {
        $probeData = $Output | ConvertFrom-Json
    } catch {
    }

    if ($null -eq $probeData) {
        return [PSCustomObject]@{
            mode = $Mode
            status = "invalid_output"
            status_reason = "probe output is not valid JSON"
            found = $false
            service_count = 0
            match_count = 0
            exit_code = $ExitCode
        }
    }

    $status = [string]$probeData.status
    $found = [bool]$probeData.found
    if ([string]::IsNullOrWhiteSpace($status)) {
        $status = if ($found) { "found" } else { "not_found" }
    }
    $statusReason = [string]$probeData.status_reason
    if ([string]::IsNullOrWhiteSpace($statusReason)) {
        $statusReason = "probe completed"
    }

    $probeData | ConvertTo-Json -Depth 8 | Set-Content -Path $ResultJsonPath -Encoding UTF8

    return [PSCustomObject]@{
        mode = $Mode
        status = $status
        status_reason = $statusReason
        found = $found
        service_count = [int]$probeData.service_count
        match_count = [int]$probeData.match_count
        exit_code = $ExitCode
    }
}

function Invoke-HostMdnsProbeWsl {
    param(
        [string]$ProbeScriptWin,
        [int]$DiscriminatorValue,
        [int]$TimeoutSeconds,
        [string]$LogPath,
        [string]$ResultJsonPath
    )

    $probeScriptWsl = Resolve-WslPathFromWindowsPath -WindowsPath $ProbeScriptWin
    if ([string]::IsNullOrWhiteSpace($probeScriptWsl)) {
        return [PSCustomObject]@{
            mode = "wsl"
            status = "unavailable_script_path"
            status_reason = "failed to convert probe script path to WSL"
            found = $false
            service_count = 0
            match_count = 0
            exit_code = -999
        }
    }

    $wslVenv = "/tmp/umatter-mdns-probe-venv"
    $wslPython = "$wslVenv/bin/python3"
    $setupCommand = "set -e; if [ ! -x '$wslPython' ]; then python3 -m venv '$wslVenv'; fi; '$wslPython' -m pip install -q zeroconf"
    $setupOutput = ""
    $setupExit = -999
    $prevErr = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $setupOutput = (& wsl.exe -d Ubuntu bash -lc $setupCommand 2>&1 | Out-String)
        $setupExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevErr
    }

    if ($setupExit -ne 0) {
        Set-Content -Path $LogPath -Value $setupOutput -Encoding UTF8
        return [PSCustomObject]@{
            mode = "wsl"
            status = "unavailable_dependency"
            status_reason = "failed to prepare WSL zeroconf environment"
            found = $false
            service_count = 0
            match_count = 0
            exit_code = $setupExit
        }
    }

    $probeCommand = "'$wslPython' '$probeScriptWsl' --service-type '_matterc._udp.local.' --discriminator $DiscriminatorValue --timeout-seconds $TimeoutSeconds"
    $probeOutput = ""
    $probeExit = -999
    $prevErr = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $probeOutput = (& wsl.exe -d Ubuntu bash -lc $probeCommand 2>&1 | Out-String)
        $probeExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevErr
    }
    Set-Content -Path $LogPath -Value $probeOutput -Encoding UTF8

    return Convert-ProbeOutputToResult -Mode "wsl" -Output $probeOutput -ExitCode $probeExit -ResultJsonPath $ResultJsonPath
}

function Invoke-HostMdnsProbeWindows {
    param(
        [string]$ProbeScriptWin,
        [int]$DiscriminatorValue,
        [int]$TimeoutSeconds,
        [string]$LogPath,
        [string]$ResultJsonPath
    )

    $bootstrapPython = ""
    $pyCmd = Get-Command python -ErrorAction SilentlyContinue
    if ($null -ne $pyCmd) {
        $bootstrapPython = $pyCmd.Source
    } else {
        $py3Cmd = Get-Command py -ErrorAction SilentlyContinue
        if ($null -ne $py3Cmd) {
            $bootstrapPython = $py3Cmd.Source
        }
    }
    if ([string]::IsNullOrWhiteSpace($bootstrapPython)) {
        return [PSCustomObject]@{
            mode = "windows"
            status = "unavailable_dependency"
            status_reason = "python launcher not found on Windows host"
            found = $false
            service_count = 0
            match_count = 0
            exit_code = -999
        }
    }

    $venvPath = Join-Path $env:TEMP "umatter-mdns-probe-win-venv"
    $venvPython = Join-Path $venvPath "Scripts\python.exe"
    if (-not (Test-Path $venvPython)) {
        $null = (& $bootstrapPython -m venv $venvPath 2>&1 | Out-String)
        if (-not (Test-Path $venvPython)) {
            return [PSCustomObject]@{
                mode = "windows"
                status = "unavailable_dependency"
                status_reason = "failed to create Windows venv for probe"
                found = $false
                service_count = 0
                match_count = 0
                exit_code = 1
            }
        }
    }

    $installExit = -999
    $installOutput = ""
    $prevErr = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $installOutput = (& $venvPython -m pip install -q zeroconf 2>&1 | Out-String)
        $installExit = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $prevErr
    }
    if ($installExit -ne 0) {
        Set-Content -Path $LogPath -Value $installOutput -Encoding UTF8
        return [PSCustomObject]@{
            mode = "windows"
            status = "unavailable_dependency"
            status_reason = "failed to install zeroconf in Windows venv"
            found = $false
            service_count = 0
            match_count = 0
            exit_code = $installExit
        }
    }

    $probeOutput = ""
    $probeExit = -999
    $prevNative = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
    try {
        $probeOutput = (& $venvPython $ProbeScriptWin --service-type "_matterc._udp.local." --discriminator $DiscriminatorValue --timeout-seconds $TimeoutSeconds 2>&1 | Out-String)
        $probeExit = $LASTEXITCODE
    } finally {
        $PSNativeCommandUseErrorActionPreference = $prevNative
    }
    Set-Content -Path $LogPath -Value $probeOutput -Encoding UTF8

    return Convert-ProbeOutputToResult -Mode "windows" -Output $probeOutput -ExitCode $probeExit -ResultJsonPath $ResultJsonPath
}

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
        $wslChipTool = Resolve-WslChipToolAutoPath
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

function Strip-AnsiEscapeCodes {
    param(
        [string]$Text
    )
    return [regex]::Replace($Text, "`e\[[0-9;?]*[ -/]*[@-~]", "")
}

function Parse-RuntimeDiagnosticsLog {
    param(
        [string]$LogPath
    )

    if ([string]::IsNullOrWhiteSpace($LogPath) -or -not (Test-Path $LogPath)) {
        return [PSCustomObject]@{
            status = "missing"
            status_reason = "runtime diagnostics log not found"
            ready_reason = ""
            ready_reason_code = -1
            runtime = ""
            ready = $false
            network_advertising_known = $false
            network_advertising = $false
            network_advertising_reason = ""
        }
    }

    try {
        $text = Get-Content -Path $LogPath -Raw
    } catch {
        return [PSCustomObject]@{
            status = "invalid"
            status_reason = "failed to read runtime diagnostics log"
            ready_reason = ""
            ready_reason_code = -1
            runtime = ""
            ready = $false
            network_advertising_known = $false
            network_advertising = $false
            network_advertising_reason = ""
        }
    }

    $reasonMatch = [regex]::Match($text, '(?m)^C16:N_DIAG_REASON\s+([A-Za-z0-9_]+)\s*$')
    $reasonFallbackMatch = [regex]::Match($text, '(?m)^C16:N_REASON3\s+([A-Za-z0-9_]+)\s*$')
    $reasonCodeMatch = [regex]::Match($text, '(?m)^C16:N_DIAG_REASON_CODE\s+(-?\d+)\s*$')
    $runtimeMatch = [regex]::Match($text, '(?m)^C16:N_DIAG_RUNTIME\s+([A-Za-z0-9_]+)\s*$')
    $readyMatch = [regex]::Match($text, '(?m)^C16:N_DIAG_READY\s+(True|False)\s*$')
    $networkAdvertisingMatch = [regex]::Match($text, '(?m)^C16:N_DIAG_NET_ADV\s+(True|False)\s*$')
    $networkAdvertisingReasonMatch = [regex]::Match($text, '(?m)^C16:N_DIAG_NET_REASON\s+([A-Za-z0-9_]+)\s*$')

    $readyReason = ""
    if ($reasonMatch.Success) {
        $readyReason = $reasonMatch.Groups[1].Value
    } elseif ($reasonFallbackMatch.Success) {
        $readyReason = $reasonFallbackMatch.Groups[1].Value
    }

    $readyReasonCode = -1
    if ($reasonCodeMatch.Success) {
        $readyReasonCode = [int]$reasonCodeMatch.Groups[1].Value
    }

    $runtimeState = ""
    if ($runtimeMatch.Success) {
        $runtimeState = $runtimeMatch.Groups[1].Value
    }

    $readyBool = $false
    if ($readyMatch.Success) {
        $readyBool = $readyMatch.Groups[1].Value -eq "True"
    } elseif ($readyReason -eq "ready") {
        $readyBool = $true
    }

    $networkAdvertisingKnown = $false
    $networkAdvertising = $false
    if ($networkAdvertisingMatch.Success) {
        $networkAdvertisingKnown = $true
        $networkAdvertising = $networkAdvertisingMatch.Groups[1].Value -eq "True"
    }

    $networkAdvertisingReason = ""
    if ($networkAdvertisingReasonMatch.Success) {
        $networkAdvertisingReason = $networkAdvertisingReasonMatch.Groups[1].Value
    }

    if ([string]::IsNullOrWhiteSpace($readyReason) -and [string]::IsNullOrWhiteSpace($runtimeState) -and -not $readyMatch.Success) {
        return [PSCustomObject]@{
            status = "invalid"
            status_reason = "runtime diagnostics markers not found in log"
            ready_reason = ""
            ready_reason_code = -1
            runtime = ""
            ready = $false
            network_advertising_known = $networkAdvertisingKnown
            network_advertising = $networkAdvertising
            network_advertising_reason = $networkAdvertisingReason
        }
    }

    if ($readyBool -and $readyReason -eq "ready") {
        return [PSCustomObject]@{
            status = "ready"
            status_reason = "runtime diagnostics indicate commissioning readiness"
            ready_reason = $readyReason
            ready_reason_code = $readyReasonCode
            runtime = $runtimeState
            ready = $true
            network_advertising_known = $networkAdvertisingKnown
            network_advertising = $networkAdvertising
            network_advertising_reason = $networkAdvertisingReason
        }
    }

    return [PSCustomObject]@{
        status = "not_ready"
        status_reason = "runtime diagnostics indicate node is not ready for pairing"
        ready_reason = $readyReason
        ready_reason_code = $readyReasonCode
        runtime = $runtimeState
        ready = $false
        network_advertising_known = $networkAdvertisingKnown
        network_advertising = $networkAdvertising
        network_advertising_reason = $networkAdvertisingReason
    }
}

$preflightLogPath = Join-Path $artifactDirAbs "chiptool_preflight.log"
$discoveryLogPath = Join-Path $artifactDirAbs "chiptool_discovery.log"
$hostMdnsProbeLogPath = Join-Path $artifactDirAbs "host_mdns_probe.log"
$hostMdnsProbeJsonPath = Join-Path $artifactDirAbs "host_mdns_probe_result.json"
$hostMdnsProbeWslLogPath = Join-Path $artifactDirAbs "host_mdns_probe_wsl.log"
$hostMdnsProbeWslJsonPath = Join-Path $artifactDirAbs "host_mdns_probe_wsl_result.json"
$hostMdnsProbeWindowsLogPath = Join-Path $artifactDirAbs "host_mdns_probe_windows.log"
$hostMdnsProbeWindowsJsonPath = Join-Path $artifactDirAbs "host_mdns_probe_windows_result.json"
$pairingLogPath = Join-Path $artifactDirAbs "chiptool_pairing.log"
$matrixMdPath = Join-Path $artifactDirAbs "chiptool_matrix_row.md"
$resultJsonPath = Join-Path $artifactDirAbs "chiptool_gate_result.json"

$runtimeDiagLogSource = "none"
if ([string]::IsNullOrWhiteSpace($RuntimeDiagLogPath)) {
    $latestRuntimeLog = Get-ChildItem -Path $artifactsRootAbs -Recurse -File -Filter "serial_commissioning_runtime_diag.log" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -ne $latestRuntimeLog) {
        $RuntimeDiagLogPath = $latestRuntimeLog.FullName
        $runtimeDiagLogSource = "auto_latest"
    }
} else {
    $runtimeDiagLogSource = "explicit"
}

$runtimeDiagLogAbs = ""
if (-not [string]::IsNullOrWhiteSpace($RuntimeDiagLogPath) -and (Test-Path $RuntimeDiagLogPath)) {
    $runtimeDiagLogAbs = (Resolve-Path -Path $RuntimeDiagLogPath).Path
}

$runtimeDiag = Parse-RuntimeDiagnosticsLog -LogPath $runtimeDiagLogAbs
$runtimeDiagStatus = [string]$runtimeDiag.status
$runtimeDiagStatusReason = [string]$runtimeDiag.status_reason
$runtimeReadyReason = [string]$runtimeDiag.ready_reason
$runtimeReadyReasonCode = [int]$runtimeDiag.ready_reason_code
$runtimeState = [string]$runtimeDiag.runtime
$runtimeReady = [bool]$runtimeDiag.ready
$networkAdvertisingKnown = [bool]$runtimeDiag.network_advertising_known
$networkAdvertising = [bool]$runtimeDiag.network_advertising
$networkAdvertisingReason = [string]$runtimeDiag.network_advertising_reason
$discoveryPrecheckEnabled = $false
$discoveryPrecheckStatus = "skipped"
$discoveryPrecheckStatusReason = "not requested"
$discoveryPrecheckFound = $false
$discoveryPrecheckExit = -999
$discoveryPrecheckMode = "none"
$discoveryPrecheckLog = ""
$discoveryPrecheckMethod = "none"
$discoveryPrecheckFallbackUsed = $false
$hostMdnsProbeEnabled = $false
$hostMdnsProbeStatus = "skipped"
$hostMdnsProbeStatusReason = "not requested"
$hostMdnsProbeFound = $false
$hostMdnsProbeServiceCount = 0
$hostMdnsProbeMatchCount = 0
$hostMdnsProbeMode = "none"
$hostMdnsProbeModeRequested = $HostMdnsProbeModeNormalized
$hostMdnsProbeExit = -999
$hostMdnsProbeWslStatus = "skipped"
$hostMdnsProbeWslStatusReason = "not requested"
$hostMdnsProbeWslFound = $false
$hostMdnsProbeWslServiceCount = 0
$hostMdnsProbeWslMatchCount = 0
$hostMdnsProbeWslExit = -999
$hostMdnsProbeWindowsStatus = "skipped"
$hostMdnsProbeWindowsStatusReason = "not requested"
$hostMdnsProbeWindowsFound = $false
$hostMdnsProbeWindowsServiceCount = 0
$hostMdnsProbeWindowsMatchCount = 0
$hostMdnsProbeWindowsExit = -999

$preflightOutput = ""
$pairingOutput = ""
$preflightExit = -999
$pairingExit = -999
$status = "blocked_tool_missing"
$statusReason = "chip-tool binary not found in PATH"
$pairingMode = "onnetwork-long"
if (-not $UseOnNetworkLongBool) {
    $pairingMode = "onnetwork"
}
$pairingCommand = "chip-tool pairing $pairingMode $NodeId $passcode $discriminator"

$pairingArgs = @("pairing", $pairingMode, "$NodeId", "$passcode", "$discriminator")
$runtimeGateBlocked = $false
if ($RunPairing -and $RequireRuntimeReadyForPairingBool -and $runtimeDiagStatus -ne "ready") {
    $runtimeGateBlocked = $true
    $status = "blocked_runtime_not_ready"
    $statusReason = "runtime diagnostics gate: $runtimeDiagStatusReason"
    if (-not [string]::IsNullOrWhiteSpace($runtimeReadyReason)) {
        $statusReason += " (ready_reason=$runtimeReadyReason)"
    }
    Set-Content -Path $preflightLogPath -Value $statusReason -Encoding UTF8
    Set-Content -Path $pairingLogPath -Value "pairing skipped: runtime not ready" -Encoding UTF8
}
$networkGateBlocked = $false
if ($RunPairing -and $RequireNetworkAdvertisingForPairingBool -and $RunDiscoveryPrecheckBool) {
    $discoveryPrecheckEnabled = $true

    if ($RunHostMdnsProbeBool) {
        $hostMdnsProbeEnabled = $true
        $probeScriptWin = Join-Path $resolvedRoot "scripts/host_mdns_commissionable_probe.py"
        if (-not (Test-Path $probeScriptWin)) {
            $hostMdnsProbeStatus = "unavailable_script"
            $hostMdnsProbeStatusReason = "missing probe script: $probeScriptWin"
            $hostMdnsProbeMode = "none"
        } else {
            $runWslProbe = $false
            $runWindowsProbe = $false
            switch ($HostMdnsProbeModeNormalized) {
                "wsl" {
                    $runWslProbe = $true
                }
                "windows" {
                    $runWindowsProbe = $true
                }
                "both" {
                    $runWslProbe = $true
                    $runWindowsProbe = $true
                }
                "auto" {
                    $runWslProbe = $true
                    $runWindowsProbe = $true
                }
            }

            $probeResults = @()
            if ($runWslProbe) {
                $wslResult = Invoke-HostMdnsProbeWsl -ProbeScriptWin $probeScriptWin -DiscriminatorValue $discriminator -TimeoutSeconds $HostMdnsProbeTimeoutSeconds -LogPath $hostMdnsProbeWslLogPath -ResultJsonPath $hostMdnsProbeWslJsonPath
                $hostMdnsProbeWslStatus = [string]$wslResult.status
                $hostMdnsProbeWslStatusReason = [string]$wslResult.status_reason
                $hostMdnsProbeWslFound = [bool]$wslResult.found
                $hostMdnsProbeWslServiceCount = [int]$wslResult.service_count
                $hostMdnsProbeWslMatchCount = [int]$wslResult.match_count
                $hostMdnsProbeWslExit = [int]$wslResult.exit_code
                $probeResults += $wslResult
            }
            if ($runWindowsProbe) {
                $winResult = Invoke-HostMdnsProbeWindows -ProbeScriptWin $probeScriptWin -DiscriminatorValue $discriminator -TimeoutSeconds $HostMdnsProbeTimeoutSeconds -LogPath $hostMdnsProbeWindowsLogPath -ResultJsonPath $hostMdnsProbeWindowsJsonPath
                $hostMdnsProbeWindowsStatus = [string]$winResult.status
                $hostMdnsProbeWindowsStatusReason = [string]$winResult.status_reason
                $hostMdnsProbeWindowsFound = [bool]$winResult.found
                $hostMdnsProbeWindowsServiceCount = [int]$winResult.service_count
                $hostMdnsProbeWindowsMatchCount = [int]$winResult.match_count
                $hostMdnsProbeWindowsExit = [int]$winResult.exit_code
                $probeResults += $winResult
            }

            $hostMdnsProbeMode = if ($runWslProbe -and $runWindowsProbe) { "wsl+windows" } elseif ($runWslProbe) { "wsl" } elseif ($runWindowsProbe) { "windows" } else { "none" }
            $foundResults = @($probeResults | Where-Object { $_.found })
            $notFoundResults = @($probeResults | Where-Object { $_.status -eq "not_found" })
            $unavailableResults = @($probeResults | Where-Object { $_.status -like "unavailable_*" })

            if ($foundResults.Count -gt 0) {
                $firstFound = $foundResults[0]
                $hostMdnsProbeStatus = "found"
                $hostMdnsProbeStatusReason = "host probe found commissionable entry (mode=$($firstFound.mode))"
                $hostMdnsProbeFound = $true
            } elseif ($notFoundResults.Count -gt 0) {
                if ($unavailableResults.Count -gt 0) {
                    $hostMdnsProbeStatus = "not_found_partial"
                    $hostMdnsProbeStatusReason = "no matching entry found in available probe mode(s); another mode unavailable"
                } else {
                    $hostMdnsProbeStatus = "not_found"
                    $hostMdnsProbeStatusReason = "no commissionable entries discovered on host probe"
                }
                $hostMdnsProbeFound = $false
            } elseif ($probeResults.Count -gt 0) {
                $primary = $probeResults[0]
                $hostMdnsProbeStatus = [string]$primary.status
                $hostMdnsProbeStatusReason = [string]$primary.status_reason
                $hostMdnsProbeFound = [bool]$primary.found
            }

            if ($probeResults.Count -gt 0) {
                $hostMdnsProbeServiceCount = [int](($probeResults | Measure-Object -Property service_count -Maximum).Maximum)
                $hostMdnsProbeMatchCount = [int](($probeResults | Measure-Object -Property match_count -Maximum).Maximum)
                $hostMdnsProbeExit = [int]$probeResults[0].exit_code
            }

            $hostSummary = [ordered]@{
                mode_requested = $HostMdnsProbeModeNormalized
                mode_effective = $hostMdnsProbeMode
                status = $hostMdnsProbeStatus
                status_reason = $hostMdnsProbeStatusReason
                found = $hostMdnsProbeFound
                service_count = $hostMdnsProbeServiceCount
                match_count = $hostMdnsProbeMatchCount
                wsl = [ordered]@{
                    status = $hostMdnsProbeWslStatus
                    status_reason = $hostMdnsProbeWslStatusReason
                    found = $hostMdnsProbeWslFound
                    service_count = $hostMdnsProbeWslServiceCount
                    match_count = $hostMdnsProbeWslMatchCount
                    exit_code = $hostMdnsProbeWslExit
                    log = $hostMdnsProbeWslLogPath
                    result_json = $hostMdnsProbeWslJsonPath
                }
                windows = [ordered]@{
                    status = $hostMdnsProbeWindowsStatus
                    status_reason = $hostMdnsProbeWindowsStatusReason
                    found = $hostMdnsProbeWindowsFound
                    service_count = $hostMdnsProbeWindowsServiceCount
                    match_count = $hostMdnsProbeWindowsMatchCount
                    exit_code = $hostMdnsProbeWindowsExit
                    log = $hostMdnsProbeWindowsLogPath
                    result_json = $hostMdnsProbeWindowsJsonPath
                }
            }
            $hostSummary | ConvertTo-Json -Depth 8 | Set-Content -Path $hostMdnsProbeJsonPath -Encoding UTF8
            $hostSummaryLines = @(
                "mode_requested=$HostMdnsProbeModeNormalized"
                "mode_effective=$hostMdnsProbeMode"
                "status=$hostMdnsProbeStatus"
                "status_reason=$hostMdnsProbeStatusReason"
                "wsl_status=$hostMdnsProbeWslStatus"
                "windows_status=$hostMdnsProbeWindowsStatus"
            )
            Set-Content -Path $hostMdnsProbeLogPath -Value ($hostSummaryLines -join [Environment]::NewLine) -Encoding UTF8

            if (-not $networkAdvertisingKnown) {
                $networkAdvertisingKnown = $true
                $networkAdvertising = $hostMdnsProbeFound
                $networkAdvertisingReason = if ($hostMdnsProbeFound) { "host_mdns_probe" } else { "host_mdns_probe_no_match" }
            }
        }
    }

    if ([string]::IsNullOrWhiteSpace($chipToolResolved)) {
        $discoveryPrecheckStatus = "unavailable_tool"
        $discoveryPrecheckStatusReason = "chip-tool binary not found"
    } elseif ($chipToolMode -ne "wsl") {
        $discoveryPrecheckStatus = "unsupported_mode"
        $discoveryPrecheckStatusReason = "discovery precheck currently supports wsl chip-tool mode only"
    } else {
        $discoveryPrecheckMode = $chipToolMode
        $discoveryPrecheckMethod = "long_discriminator"
        $discoverCommand = "set -o pipefail; timeout ${DiscoveryTimeoutSeconds}s '$chipToolResolved' discover find-commissionable-by-long-discriminator $discriminator --discover-once true 2>&1 | cat"
        $prevErr = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $discoverOutput = (& wsl.exe -d Ubuntu bash -lc $discoverCommand 2>&1 | Out-String)
        } finally {
            $ErrorActionPreference = $prevErr
        }
        $primaryExit = $LASTEXITCODE
        $primaryClean = Strip-AnsiEscapeCodes -Text $discoverOutput
        $foundByLongDiscriminator = $primaryClean -match "(?im)Long\s+Discriminator\s*:\s*$discriminator(\D|$)"
        $foundByInstanceName = $primaryClean -match '(?im)Instance\s+Name\s*:'
        $foundByVendor = $primaryClean -match '(?im)Vendor\s+ID\s*:'
        $primaryFound = $foundByLongDiscriminator -or $foundByInstanceName -or $foundByVendor
        $combinedDiscoveryLog = "=== discover find-commissionable-by-long-discriminator ===`r`n$discoverOutput"
        $fallbackExit = -999
        $fallbackFound = $false

        if (-not $primaryFound) {
            $discoveryPrecheckFallbackUsed = $true
            $fallbackCommand = "set -o pipefail; timeout ${DiscoveryTimeoutSeconds}s '$chipToolResolved' discover commissionables --discover-once true 2>&1 | cat"
            $prevErr = $ErrorActionPreference
            $ErrorActionPreference = "Continue"
            try {
                $fallbackOutput = (& wsl.exe -d Ubuntu bash -lc $fallbackCommand 2>&1 | Out-String)
            } finally {
                $ErrorActionPreference = $prevErr
            }
            $fallbackExit = $LASTEXITCODE
            $fallbackClean = Strip-AnsiEscapeCodes -Text $fallbackOutput
            $fallbackFound = $fallbackClean -match "(?im)Long\s+Discriminator\s*:\s*$discriminator(\D|$)"
            $combinedDiscoveryLog += "`r`n=== discover commissionables (fallback) ===`r`n$fallbackOutput"
            if ($fallbackFound) {
                $discoveryPrecheckMethod = "commissionables_fallback"
            }
        }

        $discoveryPrecheckFound = $primaryFound -or $fallbackFound
        if ($discoveryPrecheckFallbackUsed -and $fallbackExit -ne -999) {
            $discoveryPrecheckExit = $fallbackExit
        } else {
            $discoveryPrecheckExit = $primaryExit
        }
        $discoveryPrecheckLog = $combinedDiscoveryLog
        Set-Content -Path $discoveryLogPath -Value $discoveryPrecheckLog -Encoding UTF8

        if ($discoveryPrecheckFound) {
            $discoveryPrecheckStatus = "found"
            $discoveryPrecheckStatusReason = "commissionable discovery returned at least one matching entry"
            $networkAdvertisingKnown = $true
            $networkAdvertising = $true
            $networkAdvertisingReason = if ($discoveryPrecheckMethod -eq "commissionables_fallback") { "chip_tool_discovery_fallback" } else { "chip_tool_discovery" }
        } else {
            $discoveryPrecheckStatus = "not_found"
            if ($discoveryPrecheckFallbackUsed) {
                $discoveryPrecheckStatusReason = "commissionable discovery did not return a matching entry (primary + fallback)"
            } else {
                $discoveryPrecheckStatusReason = "commissionable discovery did not return a matching entry"
            }
            if (-not $networkAdvertisingKnown) {
                $networkAdvertisingKnown = $true
                $networkAdvertising = $false
                $networkAdvertisingReason = "chip_tool_discovery_no_match"
            } elseif ([string]::IsNullOrWhiteSpace($networkAdvertisingReason)) {
                $networkAdvertisingReason = "chip_tool_discovery_no_match"
            }
        }
    }
}
if ($RunPairing -and -not $runtimeGateBlocked -and $RequireNetworkAdvertisingForPairingBool -and (-not $networkAdvertisingKnown -or -not $networkAdvertising)) {
    $networkGateBlocked = $true
    $status = "blocked_network_not_advertising"
    $statusReason = "network diagnostics gate: mDNS advertisement not confirmed"
    if ($networkAdvertisingKnown) {
        $statusReason += " (network_advertising=False)"
    } else {
        $statusReason += " (network_advertising=unknown)"
    }
    if (-not [string]::IsNullOrWhiteSpace($networkAdvertisingReason)) {
        $statusReason += " (reason=$networkAdvertisingReason)"
    }
    Set-Content -Path $preflightLogPath -Value $statusReason -Encoding UTF8
    Set-Content -Path $pairingLogPath -Value "pairing skipped: network advertising not ready" -Encoding UTF8
}
$discoveryGateBlocked = $false
if ($RunPairing -and -not $runtimeGateBlocked -and $RequireDiscoveryFoundForPairingBool -and -not $discoveryPrecheckFound) {
    $discoveryGateBlocked = $true
    $status = "blocked_discovery_not_found"
    $statusReason = "discovery gate: commissionable entry not found before pairing"
    if (-not [string]::IsNullOrWhiteSpace($discoveryPrecheckStatus)) {
        $statusReason += " (discovery_status=$discoveryPrecheckStatus)"
    }
    Set-Content -Path $preflightLogPath -Value $statusReason -Encoding UTF8
    Set-Content -Path $pairingLogPath -Value "pairing skipped: discovery precheck did not find commissionable entry" -Encoding UTF8
}

if (-not $runtimeGateBlocked -and -not $networkGateBlocked -and -not $discoveryGateBlocked -and -not [string]::IsNullOrWhiteSpace($chipToolResolved)) {
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
} elseif (-not $runtimeGateBlocked -and -not $networkGateBlocked -and -not $discoveryGateBlocked) {
    Set-Content -Path $preflightLogPath -Value "chip-tool not found" -Encoding UTF8
}

$detailsParts = @($statusReason, "manual=$nodeManualCode", "codes=$codesStatus", "runtime=$runtimeDiagStatus")
if (-not [string]::IsNullOrWhiteSpace($runtimeReadyReason)) {
    $detailsParts += "ready_reason=$runtimeReadyReason"
}
if ($networkAdvertisingKnown) {
    $detailsParts += "net_adv=$networkAdvertising"
} else {
    $detailsParts += "net_adv=unknown"
}
if (-not [string]::IsNullOrWhiteSpace($networkAdvertisingReason)) {
    $detailsParts += "net_reason=$networkAdvertisingReason"
}
if ($discoveryPrecheckEnabled) {
    $detailsParts += "discover=$discoveryPrecheckStatus"
    $detailsParts += "discover_method=$discoveryPrecheckMethod"
}
if ($hostMdnsProbeEnabled) {
    $detailsParts += "host_mdns=$hostMdnsProbeStatus"
    $detailsParts += "host_mdns_mode=$hostMdnsProbeMode"
    $detailsParts += "host_mdns_match=$hostMdnsProbeMatchCount"
    $detailsParts += "host_mdns_total=$hostMdnsProbeServiceCount"
}
if ($RequireDiscoveryFoundForPairingBool) {
    $detailsParts += "discover_required=true"
}
if (-not [string]::IsNullOrWhiteSpace($nodeQrCode)) {
    $detailsParts += "qr=$nodeQrCode"
}
$detailsJoined = ($detailsParts -join "; ").Replace('|', '/')

$transportState = "commissioning-placeholder"
if (-not [string]::IsNullOrWhiteSpace($runtimeState)) {
    $transportState = $runtimeState
}

$matrixRow = @(
    "| board | transport | controller | test | status | details |"
    "|---|---|---|---|---|---|"
    ("| ESP32-C6 | {0} | chip-tool | pairing {1} | {2} | {3} |" -f $transportState, $pairingMode, $status, $detailsJoined)
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
    runtime_diag_log_path = $runtimeDiagLogAbs
    runtime_diag_log_source = $runtimeDiagLogSource
    runtime_diag_status = $runtimeDiagStatus
    runtime_diag_status_reason = $runtimeDiagStatusReason
    runtime_state = $runtimeState
    runtime_ready = $runtimeReady
    runtime_ready_reason = $runtimeReadyReason
    runtime_ready_reason_code = $runtimeReadyReasonCode
    require_runtime_ready_for_pairing = $RequireRuntimeReadyForPairingBool
    require_network_advertising_for_pairing = $RequireNetworkAdvertisingForPairingBool
    require_discovery_found_for_pairing = $RequireDiscoveryFoundForPairingBool
    run_discovery_precheck = $RunDiscoveryPrecheckBool
    discovery_timeout_seconds = $DiscoveryTimeoutSeconds
    discovery_precheck_enabled = $discoveryPrecheckEnabled
    discovery_precheck_status = $discoveryPrecheckStatus
    discovery_precheck_status_reason = $discoveryPrecheckStatusReason
    discovery_precheck_found = $discoveryPrecheckFound
    discovery_precheck_exit = $discoveryPrecheckExit
    discovery_precheck_mode = $discoveryPrecheckMode
    discovery_precheck_method = $discoveryPrecheckMethod
    discovery_precheck_fallback_used = $discoveryPrecheckFallbackUsed
    discovery_precheck_log = $discoveryLogPath
    discovery_precheck_discriminator = $discriminator
    run_host_mdns_probe = $RunHostMdnsProbeBool
    host_mdns_probe_mode_requested = $HostMdnsProbeModeNormalized
    host_mdns_probe_timeout_seconds = $HostMdnsProbeTimeoutSeconds
    host_mdns_probe_enabled = $hostMdnsProbeEnabled
    host_mdns_probe_status = $hostMdnsProbeStatus
    host_mdns_probe_status_reason = $hostMdnsProbeStatusReason
    host_mdns_probe_found = $hostMdnsProbeFound
    host_mdns_probe_mode = $hostMdnsProbeMode
    host_mdns_probe_exit = $hostMdnsProbeExit
    host_mdns_probe_service_count = $hostMdnsProbeServiceCount
    host_mdns_probe_match_count = $hostMdnsProbeMatchCount
    host_mdns_probe_log = $hostMdnsProbeLogPath
    host_mdns_probe_result_json = $hostMdnsProbeJsonPath
    host_mdns_probe_wsl_status = $hostMdnsProbeWslStatus
    host_mdns_probe_wsl_status_reason = $hostMdnsProbeWslStatusReason
    host_mdns_probe_wsl_found = $hostMdnsProbeWslFound
    host_mdns_probe_wsl_service_count = $hostMdnsProbeWslServiceCount
    host_mdns_probe_wsl_match_count = $hostMdnsProbeWslMatchCount
    host_mdns_probe_wsl_exit = $hostMdnsProbeWslExit
    host_mdns_probe_wsl_log = $hostMdnsProbeWslLogPath
    host_mdns_probe_wsl_result_json = $hostMdnsProbeWslJsonPath
    host_mdns_probe_windows_status = $hostMdnsProbeWindowsStatus
    host_mdns_probe_windows_status_reason = $hostMdnsProbeWindowsStatusReason
    host_mdns_probe_windows_found = $hostMdnsProbeWindowsFound
    host_mdns_probe_windows_service_count = $hostMdnsProbeWindowsServiceCount
    host_mdns_probe_windows_match_count = $hostMdnsProbeWindowsMatchCount
    host_mdns_probe_windows_exit = $hostMdnsProbeWindowsExit
    host_mdns_probe_windows_log = $hostMdnsProbeWindowsLogPath
    host_mdns_probe_windows_result_json = $hostMdnsProbeWindowsJsonPath
    runtime_gate_blocked = $runtimeGateBlocked
    network_advertising_known = $networkAdvertisingKnown
    network_advertising = $networkAdvertising
    network_advertising_reason = $networkAdvertisingReason
    network_gate_blocked = $networkGateBlocked
    discovery_gate_blocked = $discoveryGateBlocked
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
