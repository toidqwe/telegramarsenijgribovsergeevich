[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repository = Split-Path -Parent $PSScriptRoot
$configuration = Get-Content -LiteralPath (Join-Path $repository '.vsconfig') -Raw -Encoding UTF8 | ConvertFrom-Json
$upstream = Get-Content -LiteralPath (Join-Path $repository 'docs\fork\upstream.json') -Raw -Encoding UTF8 | ConvertFrom-Json

if ($configuration.version -ne '1.0' -or $configuration.components -notcontains 'Microsoft.VisualStudio.Component.VC.14.44.17.14.x86.x64') {
    throw 'Visual Studio configuration is missing the pinned MSVC toolset.'
}
if ($upstream.release -ne 'v7.4.1' -or $upstream.commit -notmatch '^[0-9a-f]{40}$') {
    throw 'The upstream baseline metadata is invalid.'
}

foreach ($script in (Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File)) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($script.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    if ($parseErrors.Count -gt 0) {
        throw "PowerShell syntax errors in $($script.Name): $($parseErrors.Message -join '; ')"
    }
    $bytes = [IO.File]::ReadAllBytes($script.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        throw "Unexpected UTF-8 BOM in $($script.Name)."
    }
}

Write-Output 'Repository metadata and PowerShell syntax checks passed.'
Write-Output 'This check does not compile Telegram or verify account access.'
