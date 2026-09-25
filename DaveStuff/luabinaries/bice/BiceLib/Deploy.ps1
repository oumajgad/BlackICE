<#
.SYNOPSIS
    Builds BiceLib and copies the DLL into the mod's script folder.

.DESCRIPTION
    Two steps and no more: MSBuild, then one copy into the repository's `script` folder.
    It deliberately does **not** touch the game's own directory - moving it there is a
    separate decision, and a script that did it silently would overwrite whatever is in a
    running install.

    The build writes to `ReleaseDebug` whatever the configuration is called; that is the
    solution's own naming and not a mistake. Build through the solution rather than the
    vcxproj: the project on its own puts the DLL somewhere else.

.PARAMETER Configuration
    Debug by default. Release works, and writes to the same place.

.PARAMETER SkipBuild
    Copy whatever was built last, without building again.

.EXAMPLE
    .\Deploy.ps1
    .\Deploy.ps1 -Configuration Release
    .\Deploy.ps1 -SkipBuild
#>
[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string] $Configuration = 'Debug',
    [switch] $SkipBuild
)

$ErrorActionPreference = 'Stop'

$solution = Join-Path $PSScriptRoot 'BiceLib.sln'
$dll = Join-Path $PSScriptRoot 'ReleaseDebug\BiceLib.dll'

# BiceLib sits four deep in the repository, so this is the repository root whatever
# anybody has cloned it as.
$repository = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')).Path
$scripts = Join-Path $repository 'script'

if (-not (Test-Path $solution)) {
    throw "No BiceLib.sln beside this script - expected $solution"
}
if (-not (Test-Path $scripts)) {
    throw "No script folder at $scripts - is this the BlackICE repository?"
}

function Find-MSBuild {
    # vswhere is installed with any Visual Studio since 2017 and is the supported way to
    # find the build tools; the fixed paths below are only for when it is not there.
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path $vswhere) {
        $found = & $vswhere -latest -requires Microsoft.Component.MSBuild `
            -find 'MSBuild\**\Bin\MSBuild.exe' | Select-Object -First 1
        if ($found) { return $found }
    }
    $guesses = @(
        'C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe',
        'C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe'
    )
    foreach ($guess in $guesses) {
        if (Test-Path $guess) { return $guess }
    }
    return $null
}

# Remembered so the build can be reported as having produced something or not. Comparing
# against the clock instead said "nothing to do" on every second run, which is the normal
# and healthy outcome of an incremental build rather than anything worth warning about.
$before = $null
if (Test-Path $dll) {
    $before = (Get-Item $dll).LastWriteTime
}

if (-not $SkipBuild) {
    $msbuild = Find-MSBuild
    if (-not $msbuild) {
        throw 'Could not find MSBuild. Open a Developer Command Prompt, or install the C++ build tools.'
    }

    Write-Host "Building $Configuration with $msbuild"
    # win32 rather than x86: the solution spells it that way and the other name does not
    # match any configuration it has.
    & $msbuild $solution -p:Configuration=$Configuration -p:Platform=win32 -v:minimal -nologo
    if ($LASTEXITCODE -ne 0) {
        throw "The build failed (MSBuild exit code $LASTEXITCODE). Nothing was copied."
    }
}

if (-not (Test-Path $dll)) {
    throw "The build reported success but there is no DLL at $dll"
}

$built = (Get-Item $dll).LastWriteTime
$rebuilt = ($null -eq $before) -or ($built -ne $before)

try {
    Copy-Item $dll (Join-Path $scripts 'BiceLib.dll') -Force
}
catch {
    throw ("Could not copy the DLL into $scripts - if the game is running it holds the " +
           "file open, so close it and run this again. ($($_.Exception.Message))")
}

Write-Host ''
Write-Host "Deployed BiceLib.dll to $scripts" -ForegroundColor Green
if ($rebuilt) {
    Write-Host "  built $built, $([math]::Round((Get-Item $dll).Length / 1KB)) KB"
}
else {
    Write-Host "  unchanged - nothing to rebuild; copied the DLL from $built"
}
Write-Host '  the game folder is untouched - copy it across yourself when you are ready.'
