[CmdletBinding()]
param([string]$CMake = 'cmake')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$originalId = $env:TDESKTOP_API_ID
$originalHash = $env:TDESKTOP_API_HASH
$cacheScript = Join-Path $PSScriptRoot 'api-cache.cmake'

function Test-CacheCase {
    param([string]$Description, [string]$ApiId, [string]$ApiHash, [bool]$ShouldSucceed)

    $env:TDESKTOP_API_ID = $ApiId
    $env:TDESKTOP_API_HASH = $ApiHash
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = @(& $CMake -P $cacheScript 2>&1)
        $succeeded = $LASTEXITCODE -eq 0
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($succeeded -ne $ShouldSucceed) {
        throw "Unexpected result: $Description"
    }
    if (-not [string]::IsNullOrEmpty($ApiHash) -and ($output -join "`n").Contains($ApiHash)) {
        throw 'API hash appeared in CMake output.'
    }
    Write-Output "[OK] $Description"
}

try {
    Test-CacheCase 'Missing credentials are rejected.' '' '' $false
    Test-CacheCase 'A valid credential shape is accepted without echoing it.' '1' ('0' * 32) $true
    Test-CacheCase 'An invalid API ID is rejected.' 'not-an-id' ('0' * 32) $false
    Test-CacheCase 'An invalid hash is rejected without echoing it.' '1' 'invalid-private-placeholder' $false
    Test-CacheCase 'A short hexadecimal hash is rejected.' '1' 'abcd' $false
} finally {
    $env:TDESKTOP_API_ID = $originalId
    $env:TDESKTOP_API_HASH = $originalHash
}

Write-Output 'API cache input and redaction tests passed; no API connection was attempted.'
exit 0
