[CmdletBinding()]
param(
    [switch]$PrepareLibraries,
    [switch]$TestApi
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'check-windows.ps1')
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if (-not $TestApi -and ([string]::IsNullOrWhiteSpace($env:TDESKTOP_API_ID) -or [string]::IsNullOrWhiteSpace($env:TDESKTOP_API_HASH))) {
    throw 'Set local TDESKTOP_API_ID and TDESKTOP_API_HASH, or explicitly use -TestApi for a non-distributable build.'
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
$visualStudio = [string](& $vswhere -latest -products '*' -version '[18.0,19.0)' -property installationPath)
$vcvars = Join-Path $visualStudio 'VC\Auxiliary\Build\vcvars64.bat'
$environment = @(& $env:ComSpec /d /c ('call "{0}" -vcvars_ver=14.44 >nul && set' -f $vcvars))
if ($LASTEXITCODE -ne 0) {
    throw 'Could not initialize the MSVC 14.44 x64 environment.'
}

$originalEnvironment = @{}
try {
    foreach ($entry in $environment) {
        $separator = $entry.IndexOf('=')
        if ($separator -gt 0) {
            $name = $entry.Substring(0, $separator)
            $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
            [Environment]::SetEnvironmentVariable($name, $entry.Substring($separator + 1), 'Process')
        }
    }

    $cmake = Join-Path $visualStudio 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
    if (-not $originalEnvironment.ContainsKey('Path')) {
        $originalEnvironment['Path'] = $env:Path
    }
    $env:Path = (Split-Path -Parent $cmake) + ';' + $env:Path

    if ($PrepareLibraries) {
        Write-Output 'Preparing upstream Debug libraries; this downloads dependencies and can take a long time.'
        $buildRoot = Split-Path -Parent $repository
        foreach ($directory in @('Libraries', 'ThirdParty')) {
            New-Item -ItemType Directory -Path (Join-Path $buildRoot $directory) -Force | Out-Null
        }
        & py -3.10 (Join-Path $repository 'Telegram\build\prepare\prepare.py') qt6 skip-release
        if ($LASTEXITCODE -ne 0) {
            throw 'Upstream library preparation failed.'
        }
    }

    $arguments = @('x64', '-D', 'DESKTOP_APP_DISABLE_AUTOUPDATE=ON', '-D', 'DESKTOP_APP_DISABLE_CRASH_REPORTS=ON', '-D', 'DESKTOP_APP_ENABLE_LTO=OFF')
    if ($TestApi) {
        Write-Warning 'TEST API build only: do not distribute this executable or test a real account without separate permission.'
        $arguments += @('-D', 'TDESKTOP_API_TEST=ON')
    } else {
        $arguments += @('-C', (Join-Path $PSScriptRoot 'api-cache.cmake'))
    }

    & py -3.10 (Join-Path $repository 'Telegram\configure.py') @arguments
    if ($LASTEXITCODE -ne 0) {
        throw 'Telegram CMake configuration failed.'
    }

    & $cmake --build (Join-Path $repository 'out') --config Debug --target Telegram
    if ($LASTEXITCODE -ne 0) {
        throw 'Telegram Debug build failed.'
    }

    Write-Output ('Build completed: ' + (Join-Path $repository 'out\Debug\Telegram.exe'))
    Write-Output 'The application has not been launched or logged into an account.'
} finally {
    foreach ($name in $originalEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], 'Process')
    }
}
