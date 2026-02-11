param(
    [string]$ComPort = "COM11",
    [string]$DeviceName = "uMatter-C11",
    [int]$EndpointId = 1,
    [int]$Passcode = 20202021,
    [int]$Discriminator = 3840,
    [string]$WithLevelControl = "true",
    [int]$Baud = 115200,
    [string]$Instance = "",
    [string]$ArtifactsRoot = "artifacts/commissioning"
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Instance)) {
    $Instance = "c11-" + (Get-Date -Format "yyyyMMdd-HHmmss")
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
$withLevelNorm = $WithLevelControl.ToString().Trim().ToLowerInvariant()
if (@("1", "true", "yes", "y", "on") -contains $withLevelNorm) {
    $withLevelBool = $true
} elseif (@("0", "false", "no", "n", "off") -contains $withLevelNorm) {
    $withLevelBool = $false
} else {
    throw "WithLevelControl must be one of: true/false/1/0"
}

$env:UM_C11_COM = $ComPort
$env:UM_C11_BAUD = "$Baud"
$env:UM_C11_NAME = $DeviceName
$env:UM_C11_ENDPOINT_ID = "$EndpointId"
$env:UM_C11_PASSCODE = "$Passcode"
$env:UM_C11_DISCRIMINATOR = "$Discriminator"
$env:UM_C11_WITH_LEVEL = "$(if ($withLevelBool) { "1" } else { "0" })"

$pythonSmoke = @'
import os
import sys
import time
import serial

port = os.environ["UM_C11_COM"]
baud = int(os.environ["UM_C11_BAUD"])
name = os.environ["UM_C11_NAME"]
endpoint_id = int(os.environ["UM_C11_ENDPOINT_ID"])
passcode = int(os.environ["UM_C11_PASSCODE"])
discriminator = int(os.environ["UM_C11_DISCRIMINATOR"])
with_level = os.environ.get("UM_C11_WITH_LEVEL", "1") == "1"

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

device_script = f"""
import os
import umatter
print("C11:BEGIN")
v = os.statvfs('/')
print("C11:VFS_TOTAL", v[0] * v[2])
l = umatter.Light(name={name!r}, endpoint_id={endpoint_id}, passcode={passcode}, discriminator={discriminator}, with_level_control={str(with_level)})
print("C11:COMM", l.commissioning())
print("C11:EP", l.endpoint_count())
print("C11:START0", l.is_started())
l.start()
print("C11:START1", l.is_started())
l.stop()
print("C11:START2", l.is_started())
l.close()
print("C11:END")
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
    ser.write(device_script.encode("utf-8"))
    ser.write(b"\x04")
    output = read_for(ser, 12.0)

print(output)

required = [
    "C11:BEGIN",
    "C11:VFS_TOTAL",
    f"C11:COMM ({discriminator}, {passcode})",
    "C11:EP 1",
    "C11:START0 False",
    "C11:START1 True",
    "C11:START2 False",
    "C11:END",
]
missing = [m for m in required if m not in output]
if missing:
    print("C11:MISSING_MARKERS")
    for m in missing:
        print("-", m)
    sys.exit(2)

for line in output.splitlines():
    if line.startswith("C11:VFS_TOTAL"):
        parts = line.split()
        if len(parts) == 2:
            total = int(parts[1])
            if total < 1000000:
                print("C11:VFS_TOO_SMALL", total)
                sys.exit(3)

print("HOST_C11_PASS")
'@

$smokeOutput = $pythonSmoke | python - 2>&1
$smokeExit = $LASTEXITCODE
$smokeOutputText = ($smokeOutput | Out-String)
$smokeLogPath = Join-Path $artifactDirAbs "serial_commissioning_smoke.log"
Set-Content -Path $smokeLogPath -Value $smokeOutputText -Encoding UTF8
if ($smokeExit -ne 0) {
    throw "Commissioning smoke failed with exit code $smokeExit. See $smokeLogPath"
}

$chipToolCmd = Get-Command chip-tool -ErrorAction SilentlyContinue
$chipToolFound = $null -ne $chipToolCmd
$chipToolVersion = ""
if ($chipToolFound) {
    $chipToolVersion = (& chip-tool --version 2>&1 | Out-String).Trim()
}

$commissioningData = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    instance = $Instance
    com_port = $ComPort
    baud = $Baud
    device_name = $DeviceName
    endpoint_id = $EndpointId
    passcode = $Passcode
    discriminator = $Discriminator
    short_discriminator = ($Discriminator -band 0x000F)
    with_level_control = $withLevelBool
    chip_tool_found = $chipToolFound
    chip_tool_version = $chipToolVersion
    chip_tool_note = "Firmware is still commissioning-placeholder; real chip-tool pairing is planned for next integration step."
    smoke_log = $smokeLogPath
}

$jsonPath = Join-Path $artifactDirAbs "commissioning_data.json"
$commissioningData | ConvertTo-Json -Depth 6 | Set-Content -Path $jsonPath -Encoding UTF8

Write-Host "Commissioning smoke: PASS"
Write-Host "Instance: $Instance"
Write-Host "Artifacts: $artifactDirAbs"
if ($chipToolFound) {
    Write-Host "chip-tool: detected"
} else {
    Write-Host "chip-tool: not found (expected for placeholder flow)"
}
