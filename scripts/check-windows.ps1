[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$failures = [Collections.Generic.List[string]]::new()
$repository = Split-Path -Parent $PSScriptRoot

function Test-Requirement {
    param([bool]$Condition, [string]$Description)

    if ($Condition) {
        Write-Output "[OK] $Description"
    } else {
        Write-Output "[MISSING] $Description"
        $failures.Add($Description)
    }
}

if ($env:OS -ne 'Windows_NT') {
    Write-Error 'This check requires native Windows.'
    exit 1
}

Test-Requirement ($repository -notmatch '\s') 'Build checkout path has no spaces; use C:\TBuild\tdesktop.'
$git = Get-Command git -ErrorAction SilentlyContinue
Test-Requirement ($null -ne $git) 'Git is available.'

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$visualStudio = ''
if (Test-Path -LiteralPath $vswhere) {
    $visualStudio = [string](& $vswhere -latest -products '*' -version '[18.0,19.0)' -property installationPath)
}
Test-Requirement (-not [string]::IsNullOrWhiteSpace($visualStudio)) 'Visual Studio 2026 is installed.'

$toolsetReady = $false
$cmakeReady = $false
if (-not [string]::IsNullOrWhiteSpace($visualStudio)) {
    $toolsets = Join-Path $visualStudio 'VC\Tools\MSVC'
    if (Test-Path -LiteralPath $toolsets) {
        $toolsetReady = @(Get-ChildItem -LiteralPath $toolsets -Directory | Where-Object {
            $_.Name -like '14.44.*' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'bin\Hostx64\x64\cl.exe'))
        }).Count -gt 0
    }
    $cmakeReady = Test-Path -LiteralPath (Join-Path $visualStudio 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe')
}
Test-Requirement $toolsetReady 'MSVC 14.44 x64 is installed; import .vsconfig if missing.'
Test-Requirement $cmakeReady 'Visual Studio CMake tools are installed.'

$sdk = Join-Path ${env:ProgramFiles(x86)} 'Windows Kits\10\Include\10.0.26100.0\um\Windows.h'
Test-Requirement (Test-Path -LiteralPath $sdk) 'Windows SDK 10.0.26100.0 is installed.'

$launcher = Get-Command py -ErrorAction SilentlyContinue
$pythonReady = $false
if ($null -ne $launcher) {
    $pythonReady = (@(& $launcher.Source --list-paths) -join "`n") -match '(?m)^\s+-(?:V:)?3\.10(?:-\d+)?\s'
}
Test-Requirement $pythonReady 'Python 3.10 is available through the py launcher.'

if ($null -ne $git) {
    $submodules = @(& $git.Source -C $repository submodule status --recursive)
    $submoduleExit = $LASTEXITCODE
    $unpinned = @($submodules | Where-Object { $_ -match '^[-+U]' })
    $quickjs = 'Telegram/ThirdParty/widget-sandbox/packages/ios/Sources/CQuickJS/quickjs'
    $moduleConfiguration = Join-Path $repository "$quickjs/.gitmodules"
    if (Test-Path -LiteralPath $moduleConfiguration) {
        $update = & $git.Source config -f $moduleConfiguration --get submodule.test262.update
        $modulePath = & $git.Source config -f $moduleConfiguration --get submodule.test262.path
        if ($update -eq 'none' -and $modulePath -eq 'test262') {
            $skippedPattern = '^-[0-9a-f]{40}\s+' + [regex]::Escape("$quickjs/test262") + '$'
            $unpinned = @($unpinned | Where-Object { $_ -notmatch $skippedPattern })
        }
    }
    Test-Requirement ($submoduleExit -eq 0 -and $submodules.Count -gt 0 -and $unpinned.Count -eq 0) 'Required submodules are initialized at pinned revisions; upstream update=none exclusions are respected.'
}

if ($failures.Count -gt 0) {
    Write-Output "Build is not ready: $($failures.Count) requirement(s) missing. See docs/fork/README.md."
    exit 1
}

Write-Output 'Environment checks passed. Libraries still need preparation before the first build.'
