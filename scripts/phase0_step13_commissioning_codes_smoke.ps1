param(
    [string]$ComPort = "COM11",
    [string]$DeviceName = "uMatter-C13",
    [int]$EndpointId = 7,
    [int]$Passcode = 24681357,
    [int]$Discriminator = 1234,
    [int]$Baud = 115200,
    [string]$Instance = "",
    [string]$ArtifactsRoot = "artifacts/commissioning"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Instance)) {
    $Instance = "c13-" + (Get-Date -Format "yyyyMMdd-HHmmss")
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

$env:UM_C13_COM = $ComPort
$env:UM_C13_BAUD = "$Baud"
$env:UM_C13_NAME = $DeviceName
$env:UM_C13_ENDPOINT_ID = "$EndpointId"
$env:UM_C13_PASSCODE = "$Passcode"
$env:UM_C13_DISCRIMINATOR = "$Discriminator"

$pythonSmoke = @'
import os
import re
import sys
import time
import serial

port = os.environ["UM_C13_COM"]
baud = int(os.environ["UM_C13_BAUD"])
name = os.environ["UM_C13_NAME"]
endpoint_id = int(os.environ["UM_C13_ENDPOINT_ID"])
passcode = int(os.environ["UM_C13_PASSCODE"])
discriminator = int(os.environ["UM_C13_DISCRIMINATOR"])

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
print("C13:BEGIN")
n = umatter.Node(device_name={name!r})
print("C13:COMM", n.commissioning())
print("C13:MAN", n.manual_code())
print("C13:QR", n.qr_code())
n.set_commissioning(passcode={passcode}, discriminator={discriminator})
print("C13:COMM2", n.commissioning())
print("C13:MAN2", n.manual_code())
print("C13:QR2", n.qr_code())
l = umatter.Light(name="C13Light", endpoint_id={endpoint_id}, passcode={passcode}, discriminator={discriminator})
print("C13:LIGHT_MAN", l.manual_code())
print("C13:LIGHT_QR", l.qr_code())
h = c.create(0xFFF1, 0x9001, "core-c13")
print("C13:CORE_SET", c.set_commissioning(h, {discriminator}, {passcode}))
print("C13:CORE_MAN", c.get_manual_code(h))
print("C13:CORE_QR", c.get_qr_code(h))
print("C13:CORE_DEST", c.destroy(h))
print("C13:END")
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
    output = read_for(ser, 12.0)

print(output)

required = [
    "C13:BEGIN",
    "C13:COMM (3840, 20202021)",
    f"C13:COMM2 ({discriminator}, {passcode})",
    "C13:CORE_SET 0",
    "C13:CORE_DEST 0",
    "C13:END",
]
missing = [m for m in required if m not in output]
if missing:
    print("C13:MISSING_MARKERS")
    for m in missing:
        print("-", m)
    sys.exit(2)

short_discriminator = discriminator & 0x000F
expected_manual = f"{short_discriminator:03d}{passcode:08d}"

manual_line = f"C13:MAN2 {expected_manual}"
if manual_line not in output:
    print("C13:MANUAL_MISMATCH", manual_line)
    sys.exit(3)

light_manual_line = f"C13:LIGHT_MAN {expected_manual}"
if light_manual_line not in output:
    print("C13:LIGHT_MANUAL_MISMATCH", light_manual_line)
    sys.exit(4)

core_manual_line = f"C13:CORE_MAN {expected_manual}"
if core_manual_line not in output:
    print("C13:CORE_MANUAL_MISMATCH", core_manual_line)
    sys.exit(5)

qr_pattern = re.compile(r"^C13:(QR2|LIGHT_QR|CORE_QR) MT:UM[0-9A-F]{4}[0-9A-F]{4}[0-9]{4}[0-9]{8}$")
qr_lines = [line.strip() for line in output.splitlines() if line.startswith("C13:QR2 ") or line.startswith("C13:LIGHT_QR ") or line.startswith("C13:CORE_QR ")]
if len(qr_lines) != 3:
    print("C13:QR_LINES_MISSING", qr_lines)
    sys.exit(6)
for line in qr_lines:
    if not qr_pattern.match(line):
        print("C13:QR_PATTERN_FAIL", line)
        sys.exit(7)

print("HOST_C13_PASS")
'@

$smokeOutput = $pythonSmoke | python - 2>&1
$smokeExit = $LASTEXITCODE
$smokeOutputText = ($smokeOutput | Out-String)
$smokeLogPath = Join-Path $artifactDirAbs "serial_commissioning_codes_smoke.log"
Set-Content -Path $smokeLogPath -Value $smokeOutputText -Encoding UTF8
if ($smokeExit -ne 0) {
    throw "Commissioning codes smoke failed with exit code $smokeExit. See $smokeLogPath"
}

$nodeManualCode = ""
$nodeQrCode = ""
$lightQrCode = ""
$coreQrCode = ""

if ($smokeOutputText -match "(?m)^C13:MAN2\s+(\S+)") {
    $nodeManualCode = $Matches[1]
} else {
    throw "Could not extract C13:MAN2 marker from smoke log: $smokeLogPath"
}
if ($smokeOutputText -match "(?m)^C13:QR2\s+(\S+)") {
    $nodeQrCode = $Matches[1]
} else {
    throw "Could not extract C13:QR2 marker from smoke log: $smokeLogPath"
}
if ($smokeOutputText -match "(?m)^C13:LIGHT_QR\s+(\S+)") {
    $lightQrCode = $Matches[1]
} else {
    throw "Could not extract C13:LIGHT_QR marker from smoke log: $smokeLogPath"
}
if ($smokeOutputText -match "(?m)^C13:CORE_QR\s+(\S+)") {
    $coreQrCode = $Matches[1]
} else {
    throw "Could not extract C13:CORE_QR marker from smoke log: $smokeLogPath"
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
    short_discriminator = ($Discriminator -band 0x000F)
    expected_manual_code = ("{0:d3}{1:d8}" -f ($Discriminator -band 0x000F), $Passcode)
    node_manual_code = $nodeManualCode
    node_qr_code = $nodeQrCode
    light_qr_code = $lightQrCode
    core_qr_code = $coreQrCode
    smoke_log = $smokeLogPath
}

$jsonPath = Join-Path $artifactDirAbs "commissioning_codes_data.json"
$data | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Host "Commissioning code smoke: PASS"
Write-Host "Instance: $Instance"
Write-Host "Artifacts: $artifactDirAbs"
