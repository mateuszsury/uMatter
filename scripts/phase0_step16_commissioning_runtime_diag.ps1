param(
    [string]$ComPort = "COM11",
    [string]$DeviceName = "uMatter-C16",
    [int]$EndpointId = 9,
    [int]$Passcode = 24681357,
    [int]$Discriminator = 1234,
    [int]$Baud = 115200,
    [string]$Instance = "",
    [string]$ArtifactsRoot = "artifacts/commissioning"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Instance)) {
    $Instance = "c16-" + (Get-Date -Format "yyyyMMdd-HHmmss")
}

$resolvedRoot = (Resolve-Path -Path ".").Path
$artifactsRootAbs = Join-Path $resolvedRoot $ArtifactsRoot
New-Item -ItemType Directory -Path $artifactsRootAbs -Force | Out-Null
$artifactDirAbs = Join-Path $artifactsRootAbs $Instance
New-Item -ItemType Directory -Path $artifactDirAbs -Force | Out-Null

$allPorts = [System.IO.Ports.SerialPort]::GetPortNames()
if ($allPorts -notcontains $ComPort) {
    throw "COM port not found: $ComPort"
}
if ($EndpointId -le 0 -or $EndpointId -gt 65535) {
    throw "EndpointId out of range: $EndpointId"
}
if ($Passcode -lt 1 -or $Passcode -gt 99999998) {
    throw "Passcode out of range: $Passcode"
}
if ($Discriminator -lt 0 -or $Discriminator -gt 4095) {
    throw "Discriminator out of range: $Discriminator"
}

$env:UM_C16_COM = $ComPort
$env:UM_C16_BAUD = "$Baud"
$env:UM_C16_NAME = $DeviceName
$env:UM_C16_ENDPOINT_ID = "$EndpointId"
$env:UM_C16_PASSCODE = "$Passcode"
$env:UM_C16_DISCRIMINATOR = "$Discriminator"

$pythonSmoke = @'
import os
import sys
import time
import serial

port = os.environ["UM_C16_COM"]
baud = int(os.environ["UM_C16_BAUD"])
name = os.environ["UM_C16_NAME"]
endpoint_id = int(os.environ["UM_C16_ENDPOINT_ID"])
passcode = int(os.environ["UM_C16_PASSCODE"])
discriminator = int(os.environ["UM_C16_DISCRIMINATOR"])

def read_for(ser, seconds):
    deadline = time.time() + seconds
    out = bytearray()
    while time.time() < deadline:
        waiting = ser.in_waiting
        if waiting:
            out.extend(ser.read(waiting))
        else:
            time.sleep(0.05)
    return out.decode(errors="replace")

script = f"""
import umatter
import _umatter_core as c
print("C16:BEGIN")
n = umatter.Node(device_name={name!r})
print("C16:N_TRANSPORT0", n.transport())
print("C16:N_READY0", n.commissioning_ready())
print("C16:N_REASON0", n.commissioning_ready_reason())
n.set_transport("thread")
print("C16:N_TRANSPORT1", n.transport())
print("C16:N_REASON1", n.commissioning_ready_reason())
ep = n.add_endpoint(endpoint_id={endpoint_id}, device_type=umatter.DEVICE_TYPE_ON_OFF_LIGHT)
ep.add_cluster(umatter.CLUSTER_ON_OFF)
print("C16:N_READY1", n.commissioning_ready())
print("C16:N_REASON2", n.commissioning_ready_reason())
n.start()
print("C16:N_READY2", n.commissioning_ready())
print("C16:N_REASON3", n.commissioning_ready_reason())
d = n.commissioning_diagnostics()
print("C16:N_DIAG_RUNTIME", d["runtime"])
print("C16:N_DIAG_REASON", d["ready_reason"])
print("C16:N_DIAG_REASON_CODE", d["ready_reason_code"])
print("C16:N_DIAG_TRANSPORT", d["transport"])
print("C16:N_DIAG_READY", d["ready"])
print("C16:N_DIAG_STARTED", d["started"])
print("C16:N_DIAG_EP", d["endpoint_count"])
print("C16:N_DIAG_NET_ADV", d.get("network_advertising", False))
print("C16:N_DIAG_NET_REASON", d.get("network_advertising_reason", "missing"))
print("C16:N_DIAG_MANUAL", d["manual_code"])
print("C16:N_DIAG_QR", d["qr_code"])
n.stop()
print("C16:N_READY3", n.commissioning_ready())
print("C16:N_REASON4", n.commissioning_ready_reason())
n.close()
l = umatter.Light(name="C16Light", endpoint_id={endpoint_id + 1}, passcode={passcode}, discriminator={discriminator}, transport="wifi")
print("C16:L_TRANSPORT0", l.transport())
print("C16:L_READY0", l.commissioning_ready())
print("C16:L_REASON0", l.commissioning_ready_reason())
l.start()
print("C16:L_READY1", l.commissioning_ready())
print("C16:L_REASON1", l.commissioning_ready_reason())
dl = l.commissioning_diagnostics()
print("C16:L_DIAG_RUNTIME", dl["runtime"])
print("C16:L_DIAG_REASON", dl["ready_reason"])
print("C16:L_DIAG_TRANSPORT", dl["transport"])
print("C16:L_DIAG_READY", dl["ready"])
print("C16:L_DIAG_EP", dl["endpoint_count"])
print("C16:L_DIAG_NET_ADV", dl.get("network_advertising", False))
print("C16:L_DIAG_NET_REASON", dl.get("network_advertising_reason", "missing"))
l.stop()
print("C16:L_READY2", l.commissioning_ready())
print("C16:L_REASON2", l.commissioning_ready_reason())
l.close()
h = c.create(0xFFF1, 0x9002, "core-c16")
print("C16:C_TRANS0", c.get_transport(h))
print("C16:C_REASON0", c.commissioning_ready_reason(h))
print("C16:C_NET0", c.get_network_advertising(h))
print("C16:C_SET_NET0", c.set_network_advertising(h, True, c.NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT))
print("C16:C_SET_TRANS", c.set_transport(h, c.TRANSPORT_DUAL))
print("C16:C_TRANS1", c.get_transport(h))
print("C16:C_REASON1", c.commissioning_ready_reason(h))
print("C16:C_ADD_EP", c.add_endpoint(h, {endpoint_id + 10}, umatter.DEVICE_TYPE_ON_OFF_LIGHT))
print("C16:C_REASON2", c.commissioning_ready_reason(h))
print("C16:C_START", c.start(h))
print("C16:C_READY1", c.commissioning_ready(h))
print("C16:C_REASON3", c.commissioning_ready_reason(h))
print("C16:C_NET1", c.get_network_advertising(h))
print("C16:C_SET_NET1", c.set_network_advertising(h, True, c.NETWORK_ADVERTISING_REASON_SIGNAL_PRESENT))
print("C16:C_NET2", c.get_network_advertising(h))
print("C16:C_SET_NET2", c.set_network_advertising(h, False, c.NETWORK_ADVERTISING_REASON_SIGNAL_LOST))
print("C16:C_NET3", c.get_network_advertising(h))
print("C16:C_STOP", c.stop(h))
print("C16:C_READY2", c.commissioning_ready(h))
print("C16:C_REASON4", c.commissioning_ready_reason(h))
print("C16:C_NET4", c.get_network_advertising(h))
print("C16:C_DEST", c.destroy(h))
print("C16:END")
""".strip("\n") + "\n"

with serial.Serial(port, baud, timeout=0.1) as ser:
    ser.dtr = False
    ser.rts = False
    time.sleep(0.2)
    ser.write(b"\x03\x03\r\n")
    time.sleep(0.3)
    _ = read_for(ser, 0.6)
    ser.write(b"\x05")
    time.sleep(0.2)
    _ = read_for(ser, 0.4)
    ser.write(script.encode("utf-8"))
    ser.write(b"\x04")
    output = read_for(ser, 14.0)

print(output)

required = [
    "C16:BEGIN",
    "C16:N_TRANSPORT0 none",
    "C16:N_READY0 False",
    "C16:N_REASON0 transport_not_configured",
    "C16:N_TRANSPORT1 thread",
    "C16:N_REASON1 no_endpoints",
    "C16:N_READY1 False",
    "C16:N_REASON2 node_not_started",
    "C16:N_READY2 True",
    "C16:N_REASON3 ready",
    "C16:N_DIAG_RUNTIME commissioning_ready",
    "C16:N_DIAG_REASON ready",
    "C16:N_DIAG_REASON_CODE 0",
    "C16:N_DIAG_TRANSPORT thread",
    "C16:N_DIAG_READY True",
    "C16:N_DIAG_STARTED True",
    "C16:N_DIAG_NET_ADV False",
    "C16:N_DIAG_NET_REASON",
    "C16:N_READY3 False",
    "C16:N_REASON4 node_not_started",
    "C16:L_TRANSPORT0 wifi",
    "C16:L_READY0 False",
    "C16:L_REASON0 node_not_started",
    "C16:L_READY1 True",
    "C16:L_REASON1 ready",
    "C16:L_DIAG_RUNTIME commissioning_ready",
    "C16:L_DIAG_REASON ready",
    "C16:L_DIAG_TRANSPORT wifi",
    "C16:L_DIAG_READY True",
    "C16:L_DIAG_NET_ADV False",
    "C16:L_DIAG_NET_REASON",
    "C16:L_READY2 False",
    "C16:L_REASON2 node_not_started",
    "C16:C_TRANS0 0",
    "C16:C_REASON0 1",
    "C16:C_NET0 (False, 1)",
    "C16:C_SET_NET0 -3",
    "C16:C_SET_TRANS 0",
    "C16:C_TRANS1 3",
    "C16:C_REASON1 2",
    "C16:C_ADD_EP 0",
    "C16:C_REASON2 3",
    "C16:C_START 0",
    "C16:C_READY1 1",
    "C16:C_REASON3 0",
    "C16:C_NET1 (False, 2)",
    "C16:C_SET_NET1 0",
    "C16:C_NET2 (True, 3)",
    "C16:C_SET_NET2 0",
    "C16:C_NET3 (False, 4)",
    "C16:C_STOP 0",
    "C16:C_READY2 0",
    "C16:C_REASON4 3",
    "C16:C_NET4 (False, 1)",
    "C16:C_DEST 0",
    "C16:END",
]
missing = [m for m in required if m not in output]
if missing:
    print("C16:MISSING_MARKERS")
    for m in missing:
        print("-", m)
    sys.exit(2)

print("HOST_C16_PASS")
'@

$smokeOutput = $pythonSmoke | python - 2>&1
$smokeExit = $LASTEXITCODE
$smokeOutputText = ($smokeOutput | Out-String)
$smokeLogPath = Join-Path $artifactDirAbs "serial_commissioning_runtime_diag.log"
Set-Content -Path $smokeLogPath -Value $smokeOutputText -Encoding UTF8
if ($smokeExit -ne 0) {
    throw "Commissioning runtime diagnostics smoke failed with exit code $smokeExit. See $smokeLogPath"
}

$data = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    instance = $Instance
    com_port = $ComPort
    baud = $Baud
    device_name = $DeviceName
    endpoint_id = $EndpointId
    passcode = $Passcode
    discriminator = $Discriminator
    smoke_log = $smokeLogPath
}

$jsonPath = Join-Path $artifactDirAbs "commissioning_runtime_diag_data.json"
$data | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Host "Commissioning runtime diagnostics smoke: PASS"
Write-Host "Instance: $Instance"
Write-Host "Artifacts: $artifactDirAbs"
