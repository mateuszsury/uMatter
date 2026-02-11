param(
    [switch]$SkipWsl,
    [string]$WslIdfRoot,
    [string]$BuildInstance = $env:UMATTER_BUILD_INSTANCE
)

$ErrorActionPreference = "Stop"

$results = @()

function Add-Result {
    param(
        [string]$Scope,
        [string]$Check,
        [string]$Status,
        [string]$Details
    )
    $script:results += [PSCustomObject]@{
        Scope   = $Scope
        Check   = $Check
        Status  = $Status
        Details = $Details
    }
}

function Test-HostCommand {
    param(
        [string]$Name,
        [string]$Scope = "host"
    )

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        Add-Result -Scope $Scope -Check $Name -Status "FAIL" -Details "command not found"
        return $false
    }

    Add-Result -Scope $Scope -Check $Name -Status "PASS" -Details $cmd.Path
    return $true
}

function Invoke-CommandCheck {
    param(
        [string]$Scope,
        [string]$Check,
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$SuccessHint
    )

    try {
        $output = & $FilePath @ArgumentList 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            $preview = ($output | Select-Object -First 1)
            if ([string]::IsNullOrWhiteSpace($preview)) {
                $preview = $SuccessHint
            }
            Add-Result -Scope $Scope -Check $Check -Status "PASS" -Details "$preview"
            return $true
        }

        $errorPreview = ($output | Select-Object -First 1)
        if ([string]::IsNullOrWhiteSpace($errorPreview)) {
            $errorPreview = "exit code $exitCode"
        }
        Add-Result -Scope $Scope -Check $Check -Status "FAIL" -Details "$errorPreview"
        return $false
    } catch {
        Add-Result -Scope $Scope -Check $Check -Status "FAIL" -Details $_.Exception.Message
        return $false
    }
}

function Invoke-WslBashCheck {
    param(
        [string]$Check,
        [string]$BashCommand,
        [string]$SuccessHint,
        [switch]$Recommended
    )

    try {
        $output = & wsl.exe bash -lc $BashCommand 2>&1
        $exitCode = $LASTEXITCODE
        if ($exitCode -eq 0) {
            $preview = ($output | Select-Object -First 1)
            if ([string]::IsNullOrWhiteSpace($preview)) {
                $preview = $SuccessHint
            }
            Add-Result -Scope "wsl" -Check $Check -Status "PASS" -Details "$preview"
            return $true
        }

        $status = "FAIL"
        if ($Recommended) {
            $status = "WARN"
        }
        $errorPreview = ($output | Select-Object -First 1)
        if ([string]::IsNullOrWhiteSpace($errorPreview)) {
            $errorPreview = "exit code $exitCode"
        }
        Add-Result -Scope "wsl" -Check $Check -Status $status -Details "$errorPreview"
        return $false
    } catch {
        $status = "FAIL"
        if ($Recommended) {
            $status = "WARN"
        }
        Add-Result -Scope "wsl" -Check $Check -Status $status -Details $_.Exception.Message
        return $false
    }
}

function Get-WslCommandOutput {
    param(
        [string]$BashCommand
    )

    try {
        $output = & wsl.exe bash -lc $BashCommand 2>&1
        $exitCode = $LASTEXITCODE
        return [PSCustomObject]@{
            ExitCode = $exitCode
            Output   = @($output)
        }
    } catch {
        return [PSCustomObject]@{
            ExitCode = 1
            Output   = @($_.Exception.Message)
        }
    }
}

function Test-WslIdfRootUsable {
    param(
        [string]$Root
    )

    if ([string]::IsNullOrWhiteSpace($Root)) {
        return $false
    }

    $probeCmd = "source '$Root/export.sh' >/dev/null 2>&1 && idf.py --version"
    $probe = Get-WslCommandOutput -BashCommand $probeCmd
    return ($probe.ExitCode -eq 0)
}

$hasPython = Test-HostCommand -Name "python"
Test-HostCommand -Name "git" | Out-Null
$hasWsl = Test-HostCommand -Name "wsl" -Scope "host" 

if ($hasPython) {
    Invoke-CommandCheck -Scope "host" -Check "python --version" -FilePath "python" -ArgumentList @("--version") -SuccessHint "python available" | Out-Null
    Invoke-CommandCheck -Scope "host" -Check "python -m esptool version" -FilePath "python" -ArgumentList @("-m", "esptool", "version") -SuccessHint "esptool available" | Out-Null
    Invoke-CommandCheck -Scope "host" -Check "python -m mpremote --help" -FilePath "python" -ArgumentList @("-m", "mpremote", "--help") -SuccessHint "mpremote available" | Out-Null
}

if ($SkipWsl) {
    Add-Result -Scope "wsl" -Check "WSL checks" -Status "SKIP" -Details "skipped by -SkipWsl"
} elseif (-not $hasWsl) {
    Add-Result -Scope "wsl" -Check "WSL checks" -Status "FAIL" -Details "wsl command missing"
} else {
    $wslRootsRaw = Get-WslCommandOutput -BashCommand "ls -d ~/esp-idf ~/esp-idf-* 2>/dev/null | xargs -I{} sh -c '[ -f {}/export.sh ] && echo {}' | sort -u"
    $wslDetectedRoots = @($wslRootsRaw.Output | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $selectedIdfRoot = $null

    if (-not [string]::IsNullOrWhiteSpace($WslIdfRoot)) {
        $selectedIdfRoot = $WslIdfRoot
        if (Test-WslIdfRootUsable -Root $selectedIdfRoot) {
            Add-Result -Scope "wsl" -Check "idf root selection" -Status "PASS" -Details "explicit: $selectedIdfRoot"
        } else {
            Add-Result -Scope "wsl" -Check "idf root selection" -Status "FAIL" -Details "explicit root is not usable: $selectedIdfRoot"
        }
    } elseif (-not [string]::IsNullOrWhiteSpace($env:UMATTER_WSL_IDF_ROOT)) {
        $selectedIdfRoot = $env:UMATTER_WSL_IDF_ROOT
        if (Test-WslIdfRootUsable -Root $selectedIdfRoot) {
            Add-Result -Scope "wsl" -Check "idf root selection" -Status "PASS" -Details "UMATTER_WSL_IDF_ROOT: $selectedIdfRoot"
        } else {
            Add-Result -Scope "wsl" -Check "idf root selection" -Status "FAIL" -Details "UMATTER_WSL_IDF_ROOT is not usable: $selectedIdfRoot"
        }
    } else {
        $usableRoots = @()
        foreach ($root in $wslDetectedRoots) {
            if (Test-WslIdfRootUsable -Root $root) {
                $usableRoots += $root
            }
        }

        if ($usableRoots.Count -eq 1) {
            $selectedIdfRoot = $usableRoots[0]
            Add-Result -Scope "wsl" -Check "idf root selection" -Status "PASS" -Details "auto usable: $selectedIdfRoot"
        } elseif ($usableRoots.Count -gt 1) {
            $selectedIdfRoot = $usableRoots[0]
            $allUsableRoots = ($usableRoots -join ", ")
            Add-Result -Scope "wsl" -Check "idf root selection" -Status "WARN" -Details "multiple usable roots detected ($allUsableRoots); using $selectedIdfRoot; set -WslIdfRoot for deterministic instance"
        } elseif ($wslDetectedRoots.Count -gt 0) {
            $allRoots = ($wslDetectedRoots -join ", ")
            Add-Result -Scope "wsl" -Check "idf root selection" -Status "FAIL" -Details "roots detected but not usable: $allRoots"
        } else {
            Add-Result -Scope "wsl" -Check "idf root selection" -Status "FAIL" -Details "no ESP-IDF roots detected"
        }
    }

    Invoke-WslBashCheck -Check "wsl uname -a" -BashCommand "uname -a" -SuccessHint "linux kernel detected" | Out-Null
    Invoke-WslBashCheck -Check "cmake --version" -BashCommand "command -v cmake >/dev/null && cmake --version | head -n 1" -SuccessHint "cmake available" | Out-Null
    Invoke-WslBashCheck -Check "ninja --version" -BashCommand "command -v ninja >/dev/null && ninja --version" -SuccessHint "ninja available" | Out-Null
    Invoke-WslBashCheck -Check "make --version" -BashCommand "command -v make >/dev/null && make --version | head -n 1" -SuccessHint "make available" | Out-Null
    Invoke-WslBashCheck -Check "ccache --version (recommended)" -BashCommand "command -v ccache >/dev/null && ccache --version | head -n 1" -SuccessHint "ccache available" -Recommended | Out-Null

    if (-not [string]::IsNullOrWhiteSpace($selectedIdfRoot)) {
        $idfVersionCmd = "source '$selectedIdfRoot/export.sh' >/dev/null 2>&1 && idf.py --version"
        $idfPathCmd = "source '$selectedIdfRoot/export.sh' >/dev/null 2>&1 && env | grep '^IDF_PATH='"
        $idfBuildDirFlagCmd = "source '$selectedIdfRoot/export.sh' >/dev/null 2>&1 && idf.py --help | grep -q -- '--build-dir'"

        Invoke-WslBashCheck -Check "idf.py --version" -BashCommand $idfVersionCmd -SuccessHint "idf.py available from selected root" | Out-Null
        Invoke-WslBashCheck -Check "IDF_PATH after export" -BashCommand $idfPathCmd -SuccessHint "IDF_PATH set by export.sh" | Out-Null
        Invoke-WslBashCheck -Check "idf.py supports --build-dir" -BashCommand $idfBuildDirFlagCmd -SuccessHint "build dir isolation available" | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($BuildInstance)) {
        Add-Result -Scope "policy" -Check "UMATTER_BUILD_INSTANCE" -Status "WARN" -Details "not set; set per process to avoid build-dir collisions across concurrent instances"
    } else {
        Add-Result -Scope "policy" -Check "UMATTER_BUILD_INSTANCE" -Status "PASS" -Details $BuildInstance
    }
}

$results | Format-Table -AutoSize

$failCount = @($results | Where-Object { $_.Status -eq "FAIL" }).Count
$warnCount = @($results | Where-Object { $_.Status -eq "WARN" }).Count
$skipCount = @($results | Where-Object { $_.Status -eq "SKIP" }).Count
$passCount = @($results | Where-Object { $_.Status -eq "PASS" }).Count

Write-Host ""
Write-Host "Summary: PASS=$passCount WARN=$warnCount SKIP=$skipCount FAIL=$failCount"

if ($failCount -gt 0) {
    exit 1
}

exit 0
