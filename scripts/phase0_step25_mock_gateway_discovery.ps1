param(
    [string]$RuntimeDiagLogPath = "",
    [string]$CommissioningDataPath = "",
    [string]$ChipToolWslPath = "/home/thete/umatter-work/connectedhomeip/out/chip-tool/chip-tool",
    [UInt64]$NodeId = 112233,
    [int]$Discriminator = 1234,
    [string]$MockInstance = "uMatter-Mock-Gateway",
    [int]$MockLifetimeSeconds = 60,
    [string]$Instance = "",
    [string]$ArtifactsRoot = "artifacts/commissioning"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Instance)) {
    $Instance = "c25-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

if ($Discriminator -lt 0 -or $Discriminator -gt 4095) {
    throw "Discriminator must be in range 0..4095"
}
if ($MockLifetimeSeconds -lt 15 -or $MockLifetimeSeconds -gt 600) {
    throw "MockLifetimeSeconds must be in range 15..600"
}

$resolvedRoot = (Resolve-Path -Path ".").Path
$artifactsRootAbs = Join-Path $resolvedRoot $ArtifactsRoot
New-Item -ItemType Directory -Path $artifactsRootAbs -Force | Out-Null
$artifactDirAbs = Join-Path $artifactsRootAbs $Instance
New-Item -ItemType Directory -Path $artifactDirAbs -Force | Out-Null

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

$mockScriptWin = Join-Path $resolvedRoot "scripts/mock_matter_gateway.py"
if (-not (Test-Path $mockScriptWin)) {
    throw "Missing script: $mockScriptWin"
}

$mockScriptWinUnix = $mockScriptWin -replace '\\', '/'
$wslMockScript = (& wsl.exe wslpath -a "$mockScriptWinUnix" 2>$null | Out-String).Trim()
if ([string]::IsNullOrWhiteSpace($wslMockScript)) {
    throw "Failed to resolve WSL path for $mockScriptWin"
}

$wslVenv = "/tmp/umatter-mock-gateway-venv"
$wslPython = "$wslVenv/bin/python3"
$venvSetupCommand = "set -e; if [ ! -x '$wslPython' ]; then python3 -m venv '$wslVenv'; fi; '$wslPython' -m pip install -q zeroconf"
$null = (& wsl.exe -d Ubuntu bash -lc $venvSetupCommand 2>&1 | Out-String)

$mockLogPath = Join-Path $artifactDirAbs "mock_gateway.log"
$mockErrLogPath = Join-Path $artifactDirAbs "mock_gateway.err.log"
$wslMockCommand = @(
    "'$wslPython' '$wslMockScript'"
    "--instance '$MockInstance'"
    "--discriminator $Discriminator"
    "--lifetime-seconds $MockLifetimeSeconds"
) -join " "
$mockJob = Start-Job -ScriptBlock {
    param($CmdLine)
    & wsl.exe -d Ubuntu bash -lc $CmdLine 2>&1
} -ArgumentList $wslMockCommand

try {
    Start-Sleep -Seconds 3
    if ($mockJob.State -ne "Running") {
        $jobOutput = (Receive-Job -Job $mockJob -Keep | Out-String)
        Set-Content -Path $mockLogPath -Value $jobOutput -Encoding UTF8
        throw "Mock gateway process exited before gate run. See $mockLogPath"
    }

    $gateInstance = "$Instance-gate"
    $gateScriptPath = Join-Path $resolvedRoot "scripts/phase0_step12_chiptool_gate.ps1"
    $gateOutput = (& $gateScriptPath `
        -CommissioningDataPath $commissioningDataAbs `
        -RuntimeDiagLogPath $runtimeDiagLogAbs `
        -ChipToolWslPath $ChipToolWslPath `
        -NodeId $NodeId `
        -RunPairing `
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
        mock_gateway_log = $mockLogPath
        mock_gateway_wsl_script = $wslMockScript
        mock_gateway_instance = $MockInstance
        gate_instance = $gateInstance
        gate_status = $gateResult.status
        gate_status_reason = $gateResult.status_reason
        gate_discovery_precheck_status = $gateResult.discovery_precheck_status
        gate_discovery_precheck_found = $gateResult.discovery_precheck_found
        gate_discovery_gate_blocked = $gateResult.discovery_gate_blocked
        gate_network_gate_blocked = $gateResult.network_gate_blocked
        gate_runtime_gate_blocked = $gateResult.runtime_gate_blocked
    }
    $resultPath = Join-Path $artifactDirAbs "mock_gateway_discovery_result.json"
    $result | ConvertTo-Json -Depth 6 | Set-Content -Path $resultPath -Encoding UTF8

    Write-Host "Mock gateway discovery run: PASS"
    Write-Host "Instance: $Instance"
    Write-Host "Gate status: $($gateResult.status)"
    Write-Host "Discovery status: $($gateResult.discovery_precheck_status)"
    Write-Host "Artifacts: $artifactDirAbs"
}
finally {
    if ($null -ne $mockJob) {
        if ($mockJob.State -eq "Running") {
            Stop-Job -Job $mockJob -ErrorAction SilentlyContinue
        }
        $stdoutText = (Receive-Job -Job $mockJob -Keep | Out-String)
        Set-Content -Path $mockLogPath -Value $stdoutText -Encoding UTF8
        Remove-Job -Job $mockJob -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path $mockErrLogPath)) {
        Set-Content -Path $mockErrLogPath -Value "" -Encoding UTF8
    }
}
