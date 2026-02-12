param(
    [string]$ComPort = "COM11",
    [string]$DeviceName = "uMatter-C19",
    [int]$EndpointId = 9,
    [int]$Passcode = 24681357,
    [int]$Discriminator = 1234,
    [int]$Baud = 115200,
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
    [string]$RunDiscoveryPrecheck = "true",
    [int]$DiscoveryTimeoutSeconds = 8,
    [switch]$SkipRuntimeDiag,
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
$RunDiscoveryPrecheckBool = Convert-ToBool -Value $RunDiscoveryPrecheck -ParamName "RunDiscoveryPrecheck"

if ($DiscoveryTimeoutSeconds -lt 1 -or $DiscoveryTimeoutSeconds -gt 120) {
    throw "DiscoveryTimeoutSeconds must be in range 1..120"
}

if ([string]::IsNullOrWhiteSpace($Instance)) {
    $Instance = "c19-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$resolvedRoot = (Resolve-Path -Path ".").Path
$artifactsRootAbs = Join-Path $resolvedRoot $ArtifactsRoot
New-Item -ItemType Directory -Path $artifactsRootAbs -Force | Out-Null
$artifactDirAbs = Join-Path $artifactsRootAbs $Instance
New-Item -ItemType Directory -Path $artifactDirAbs -Force | Out-Null

$runtimeDiagInstance = ""
$runtimeDiagLogAbs = ""
$runtimeDiagStatus = "not_run"
$runtimeDiagStatusReason = "runtime diagnostics step skipped"
$diagInvokeLogPath = Join-Path $artifactDirAbs "step16_invocation.log"

if (-not $SkipRuntimeDiag) {
    $runtimeDiagInstance = "$Instance-diag"
    $runtimeDiagStatus = "running"
    $runtimeDiagStatusReason = "executing step16 runtime diagnostics"
    $diagScriptPath = Join-Path $resolvedRoot "scripts/phase0_step16_commissioning_runtime_diag.ps1"
    $diagParams = @{
        ComPort = $ComPort
        DeviceName = $DeviceName
        EndpointId = $EndpointId
        Passcode = $Passcode
        Discriminator = $Discriminator
        Baud = $Baud
        Instance = $runtimeDiagInstance
        ArtifactsRoot = $ArtifactsRoot
    }
    $diagOutput = (& $diagScriptPath @diagParams 2>&1 | Out-String)
    Set-Content -Path $diagInvokeLogPath -Value $diagOutput -Encoding UTF8

    $runtimeDiagLogCandidate = Join-Path $artifactsRootAbs "$runtimeDiagInstance\serial_commissioning_runtime_diag.log"
    if (-not (Test-Path $runtimeDiagLogCandidate)) {
        throw "Missing runtime diagnostics log: $runtimeDiagLogCandidate"
    }
    $runtimeDiagLogAbs = (Resolve-Path -Path $runtimeDiagLogCandidate).Path
    $runtimeDiagStatus = "pass"
    $runtimeDiagStatusReason = "step16 runtime diagnostics completed"
}

if ([string]::IsNullOrWhiteSpace($runtimeDiagLogAbs) -and -not [string]::IsNullOrWhiteSpace($RuntimeDiagLogPath)) {
    if (-not (Test-Path $RuntimeDiagLogPath)) {
        throw "RuntimeDiagLogPath does not exist: $RuntimeDiagLogPath"
    }
    $runtimeDiagLogAbs = (Resolve-Path -Path $RuntimeDiagLogPath).Path
    $runtimeDiagStatus = "external"
    $runtimeDiagStatusReason = "using external runtime diagnostics log"
}

$gateInstance = "$Instance-gate"
$gateInvokeLogPath = Join-Path $artifactDirAbs "step12_invocation.log"
$gateScriptPath = Join-Path $resolvedRoot "scripts/phase0_step12_chiptool_gate.ps1"
$gateParams = @{
    Instance = $gateInstance
    ArtifactsRoot = $ArtifactsRoot
    NodeId = $NodeId
    RequireRuntimeReadyForPairing = $RequireRuntimeReadyForPairingBool
    RequireNetworkAdvertisingForPairing = $RequireNetworkAdvertisingForPairingBool
    RunDiscoveryPrecheck = $RunDiscoveryPrecheckBool
    DiscoveryTimeoutSeconds = $DiscoveryTimeoutSeconds
}
if (-not [string]::IsNullOrWhiteSpace($CommissioningDataPath)) {
    $gateParams.CommissioningDataPath = $CommissioningDataPath
}
if (-not [string]::IsNullOrWhiteSpace($CommissioningCodesDataPath)) {
    $gateParams.CommissioningCodesDataPath = $CommissioningCodesDataPath
}
if (-not [string]::IsNullOrWhiteSpace($runtimeDiagLogAbs)) {
    $gateParams.RuntimeDiagLogPath = $runtimeDiagLogAbs
}
if (-not [string]::IsNullOrWhiteSpace($ChipToolPath)) {
    $gateParams.ChipToolPath = $ChipToolPath
}
if (-not [string]::IsNullOrWhiteSpace($ChipToolWslPath)) {
    $gateParams.ChipToolWslPath = $ChipToolWslPath
}
if ($RunPairing) {
    $gateParams.RunPairing = $true
}
if (-not $UseOnNetworkLongBool) {
    $gateParams.UseOnNetworkLong = $false
}

$gateOutput = (& $gateScriptPath @gateParams 2>&1 | Out-String)
Set-Content -Path $gateInvokeLogPath -Value $gateOutput -Encoding UTF8

$gateResultPath = Join-Path $artifactsRootAbs "$gateInstance\chiptool_gate_result.json"
if (-not (Test-Path $gateResultPath)) {
    throw "Missing gate result JSON: $gateResultPath"
}

$gateResultAbs = (Resolve-Path -Path $gateResultPath).Path
$gateResult = Get-Content -Path $gateResultAbs -Raw | ConvertFrom-Json

$result = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    instance = $Instance
    artifacts_dir = $artifactDirAbs
    runtime_diag_instance = $runtimeDiagInstance
    runtime_diag_status = $runtimeDiagStatus
    runtime_diag_status_reason = $runtimeDiagStatusReason
    runtime_diag_log_path = $runtimeDiagLogAbs
    gate_instance = $gateInstance
    gate_result_path = $gateResultAbs
    gate_status = $gateResult.status
    gate_status_reason = $gateResult.status_reason
    gate_runtime_diag_status = $gateResult.runtime_diag_status
    gate_runtime_ready_reason = $gateResult.runtime_ready_reason
    gate_runtime_state = $gateResult.runtime_state
    gate_runtime_gate_blocked = $gateResult.runtime_gate_blocked
    gate_network_advertising_known = $gateResult.network_advertising_known
    gate_network_advertising = $gateResult.network_advertising
    gate_network_advertising_reason = $gateResult.network_advertising_reason
    gate_network_gate_blocked = $gateResult.network_gate_blocked
    gate_discovery_precheck_enabled = $gateResult.discovery_precheck_enabled
    gate_discovery_precheck_status = $gateResult.discovery_precheck_status
    gate_discovery_precheck_status_reason = $gateResult.discovery_precheck_status_reason
    gate_discovery_precheck_found = $gateResult.discovery_precheck_found
    gate_discovery_precheck_exit = $gateResult.discovery_precheck_exit
    gate_discovery_precheck_log = $gateResult.discovery_precheck_log
    run_pairing = [bool]$RunPairing
    node_id = $NodeId
}

$resultPath = Join-Path $artifactDirAbs "commissioning_gate_e2e_result.json"
$result | ConvertTo-Json -Depth 6 | Set-Content -Path $resultPath -Encoding UTF8

Write-Host "Commissioning gate e2e: PASS"
Write-Host "Instance: $Instance"
Write-Host "Gate status: $($gateResult.status)"
Write-Host "Artifacts: $artifactDirAbs"
