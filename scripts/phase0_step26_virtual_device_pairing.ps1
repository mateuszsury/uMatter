param(
    [string]$RuntimeDiagLogPath = "",
    [string]$CommissioningDataPath = "",
    [string]$ChipToolWslPath = "/home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool",
    [string]$VirtualDeviceAppWslPath = "/home/thete/umatter-work/connectedhomeip/out/all-clusters/chip-all-clusters-app",
    [UInt64]$NodeId = 556677,
    [int]$Discriminator = -1,
    [int]$Passcode = -1,
    [int]$StartupWaitSeconds = 8,
    [string]$Instance = "",
    [string]$ArtifactsRoot = "artifacts/commissioning"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Instance)) {
    $Instance = "c26-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

if ($StartupWaitSeconds -lt 3 -or $StartupWaitSeconds -gt 60) {
    throw "StartupWaitSeconds must be in range 3..60"
}
if ($NodeId -le 0) {
    throw "NodeId must be > 0"
}

$resolvedRoot = (Resolve-Path -Path ".").Path
$artifactsRootAbs = Join-Path $resolvedRoot $ArtifactsRoot
New-Item -ItemType Directory -Path $artifactsRootAbs -Force | Out-Null
$artifactDirAbs = Join-Path $artifactsRootAbs $Instance
New-Item -ItemType Directory -Path $artifactDirAbs -Force | Out-Null

$chipToolExists = (& wsl.exe -d Ubuntu bash -lc "test -x '$ChipToolWslPath' && echo 1 || echo 0" 2>$null | Out-String).Trim()
if ($chipToolExists -ne "1") {
    throw "chip-tool binary not found or not executable: $ChipToolWslPath"
}
$virtualAppExists = (& wsl.exe -d Ubuntu bash -lc "test -x '$VirtualDeviceAppWslPath' && echo 1 || echo 0" 2>$null | Out-String).Trim()
if ($virtualAppExists -ne "1") {
    throw "virtual device binary not found or not executable: $VirtualDeviceAppWslPath"
}

if ([string]::IsNullOrWhiteSpace($RuntimeDiagLogPath)) {
    $latestRuntimeLog = Get-ChildItem -Path $artifactsRootAbs -Recurse -File -Filter "serial_commissioning_runtime_diag.log" |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if ($null -eq $latestRuntimeLog) {
        throw "No runtime diagnostics log found under $artifactsRootAbs"
    }
    $RuntimeDiagLogPath = $latestRuntimeLog.FullName
}
$runtimeDiagLogAbs = (Resolve-Path -Path $RuntimeDiagLogPath).Path

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

$effectiveDiscriminator = $Discriminator
$effectivePasscode = $Passcode
if ($effectiveDiscriminator -lt 0) {
    $effectiveDiscriminator = [int]$commissioningData.discriminator
}
if ($effectivePasscode -lt 0) {
    $effectivePasscode = [int]$commissioningData.passcode
}
if ($effectiveDiscriminator -lt 0 -or $effectiveDiscriminator -gt 4095) {
    throw "Discriminator must be in range 0..4095"
}
if ($effectivePasscode -lt 1 -or $effectivePasscode -gt 99999998) {
    throw "Passcode must be in range 1..99999998"
}

$deviceLogPath = Join-Path $artifactDirAbs "virtual_device.log"
$wslDeviceLogPath = "/tmp/umatter-vdev-$Instance.log"
$wslDeviceKvsPath = "/tmp/umatter-vdev-$Instance.kvs"
$deviceCommand = @(
    "set -e"
    "rm -f '$wslDeviceKvsPath'"
    "'$VirtualDeviceAppWslPath' --discriminator $effectiveDiscriminator --passcode $effectivePasscode --KVS '$wslDeviceKvsPath' --secured-device-port 5540 > '$wslDeviceLogPath' 2>&1"
) -join "; "

$deviceJob = Start-Job -ScriptBlock {
    param($CmdLine)
    & wsl.exe -d Ubuntu bash -lc $CmdLine 2>&1
} -ArgumentList $deviceCommand

try {
    Start-Sleep -Seconds $StartupWaitSeconds
    if ($deviceJob.State -ne "Running") {
        $jobOutput = (Receive-Job -Job $deviceJob -Keep | Out-String)
        Set-Content -Path $deviceLogPath -Value $jobOutput -Encoding UTF8
        throw "Virtual device process exited before gate run. See $deviceLogPath"
    }

    $gateInstance = "$Instance-gate"
    $gateScriptPath = Join-Path $resolvedRoot "scripts/phase0_step12_chiptool_gate.ps1"
    $gateOutput = (& $gateScriptPath `
        -CommissioningDataPath $commissioningDataAbs `
        -RuntimeDiagLogPath $runtimeDiagLogAbs `
        -ChipToolWslPath $ChipToolWslPath `
        -NodeId $NodeId `
        -RunPairing `
        -RequireRuntimeReadyForPairing true `
        -RequireNetworkAdvertisingForPairing true `
        -RequireDiscoveryFoundForPairing true `
        -RunDiscoveryPrecheck true `
        -DiscoveryTimeoutSeconds 8 `
        -Instance $gateInstance `
        -ArtifactsRoot $ArtifactsRoot 2>&1 | Out-String)
    Set-Content -Path (Join-Path $artifactDirAbs "step12_invocation.log") -Value $gateOutput -Encoding UTF8

    $gateResultPath = Join-Path $artifactsRootAbs "$gateInstance\chiptool_gate_result.json"
    if (-not (Test-Path $gateResultPath)) {
        throw "Missing gate result: $gateResultPath"
    }
    $gateResult = Get-Content -Path $gateResultPath -Raw | ConvertFrom-Json

    $result = [ordered]@{
        timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        instance = $Instance
        artifacts_dir = $artifactDirAbs
        runtime_diag_log_path = $runtimeDiagLogAbs
        commissioning_data_path = $commissioningDataAbs
        virtual_device_app = $VirtualDeviceAppWslPath
        virtual_device_log = $deviceLogPath
        virtual_device_kvs = $wslDeviceKvsPath
        node_id = $NodeId
        discriminator = $effectiveDiscriminator
        passcode = $effectivePasscode
        gate_instance = $gateInstance
        gate_status = $gateResult.status
        gate_status_reason = $gateResult.status_reason
        gate_discovery_precheck_status = $gateResult.discovery_precheck_status
        gate_discovery_precheck_method = $gateResult.discovery_precheck_method
        gate_discovery_gate_blocked = $gateResult.discovery_gate_blocked
        gate_network_gate_blocked = $gateResult.network_gate_blocked
        gate_runtime_gate_blocked = $gateResult.runtime_gate_blocked
        gate_pairing_exit = $gateResult.pairing_exit
    }
    $resultPath = Join-Path $artifactDirAbs "virtual_device_pairing_result.json"
    $result | ConvertTo-Json -Depth 6 | Set-Content -Path $resultPath -Encoding UTF8

    Write-Host "Virtual device pairing run: PASS"
    Write-Host "Instance: $Instance"
    Write-Host "Gate status: $($gateResult.status)"
    Write-Host "Discovery status: $($gateResult.discovery_precheck_status)"
    Write-Host "Artifacts: $artifactDirAbs"
}
finally {
    if ($null -ne $deviceJob) {
        if ($deviceJob.State -eq "Running") {
            Stop-Job -Job $deviceJob -ErrorAction SilentlyContinue
        }
        $jobOutput = (Receive-Job -Job $deviceJob -Keep | Out-String)
        if (-not [string]::IsNullOrWhiteSpace($jobOutput)) {
            Add-Content -Path $deviceLogPath -Value $jobOutput
        }
        Remove-Job -Job $deviceJob -Force -ErrorAction SilentlyContinue
    }

    $deviceLogText = (& wsl.exe -d Ubuntu bash -lc "cat '$wslDeviceLogPath' 2>/dev/null || true" 2>$null | Out-String)
    if (-not [string]::IsNullOrWhiteSpace($deviceLogText)) {
        Set-Content -Path $deviceLogPath -Value $deviceLogText -Encoding UTF8
    }
    $null = (& wsl.exe -d Ubuntu bash -lc "rm -f '$wslDeviceLogPath' '$wslDeviceKvsPath'" 2>$null | Out-String)
}
