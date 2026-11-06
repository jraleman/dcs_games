<#
.SYNOPSIS
    Saves a screenshot of every screen in every game for review.

.DESCRIPTION
    Runs res://tools/capture_screens.gd once for each game as a standalone
    build (--game=<id>), then once for the collection (--game=all). Each run
    opens a window and walks the screens the way a player reaches them: the
    studio sting and opening, the title screen, every settings tab, the store,
    each gallery exhibit, the saves screen, the credits and, for each mode the
    game offers (solo, then local two-player), setup, briefing, the round, the
    pause overlay, results, the stats panel and the share card. The collection
    run keeps the shared title screens and the game picker.

    Every run gets a fresh, throwaway user profile with every achievement and
    unlock met and every shop able to buy its whole catalogue, so gated levels,
    characters, exhibits and items are on screen. A game's own save files stay
    fresh, so its first-run screens are kept too. Your own saves are never
    read or written.

    Output, under -OutputDir:
        <game id>\NNN_<screen>.png   one folder per run, in the order visited
        <game id>\screens.txt        each file with its scene, then the run's
                                     notes and warnings
        collection\                  the collection run
        logs\<run>.log               Godot's log for each run

    A game can add screens only it knows how to reach with an optional
    games/<folder>/tools/screen_tour.gd; see _load_hook() in
    tools/capture_screens_tour.gd.

    Keep the window visible while it runs: a minimised window may stop drawing.
    Expect two to three minutes per game. Development only, like everything
    in tools/.

.EXAMPLE
    pwsh tools\capture_screens.ps1 -Godot 'C:\Godot\Godot_v4.7.2-stable_win64.exe'

.EXAMPLE
    pwsh tools\capture_screens.ps1 -Godot 'C:\Godot\Godot_v4.7.2-stable_win64.exe' -Games chicken_pit, cube_trials -SkipCollection
#>
[CmdletBinding()]
param(
    [string] $Godot = $(if ($env:GODOT) { $env:GODOT } else { 'godot' }),
    # Game ids to capture; every game the catalog discovers when empty.
    [string[]] $Games = @(),
    [switch] $SkipCollection,
    [ValidatePattern('^\d+x\d+$')]
    [string] $Resolution = '1280x720',
    # Defaults to build\screenshots\<timestamp> under the project.
    [string] $OutputDir = '',
    # Keep one frame per screen instead of every page of its long lists.
    [switch] $NoScrollPages,
    # How long one run may take before the tour ends itself with what it kept.
    [ValidateRange(60, 86400)]
    [int] $TimeoutSeconds = 900
)

$ErrorActionPreference = 'Stop'

$projectDir = Split-Path -Parent $PSScriptRoot
$captureScript = 'res://tools/capture_screens.gd'
# The tour refuses to seed a profile without this file, so a stray launch can
# never fill a player's real save with unlocks.
$profileMarker = '.dcs_capture_profile'
# Past the tour's own timeout, a run that has not quit by itself is stuck.
$killGraceSeconds = 120
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) (
    'dcs_screen_capture_' + [guid]::NewGuid().ToString('N')
)

function Resolve-Executable {
    param([Parameter(Mandatory)] [string] $Tool)

    if ([string]::IsNullOrWhiteSpace($Tool)) {
        throw 'Tool path or command name cannot be empty.'
    }
    if (Test-Path -LiteralPath $Tool) {
        return (Resolve-Path -LiteralPath $Tool).Path
    }
    $command = Get-Command $Tool -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "Cannot run '$Tool'. Install it or pass an explicit path."
    }
    return $command.Source
}

function New-CaptureProfile {
    param([Parameter(Mandatory)] [string] $Name)

    $dir = Join-Path $workDir "profile-$Name"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $dir $profileMarker) -Force | Out-Null
    return $dir
}

# ArgumentList preserves spaces without assembling a shell command, and waiting
# on the process also handles Godot's GUI-subsystem Windows executable. Godot
# keeps user data under APPDATA on Windows and XDG_DATA_HOME elsewhere; setting
# both on the child alone leaves this session's environment untouched.
function Invoke-Godot {
    param(
        [Parameter(Mandatory)] [string[]] $Arguments,
        [Parameter(Mandatory)] [string] $ProfileDir,
        [Parameter(Mandatory)] [int] $WaitSeconds
    )

    $info = [System.Diagnostics.ProcessStartInfo]::new($godotExe)
    $info.UseShellExecute = $false
    foreach ($argument in $Arguments) {
        $info.ArgumentList.Add($argument)
    }
    $info.Environment['APPDATA'] = $ProfileDir
    $info.Environment['XDG_DATA_HOME'] = $ProfileDir
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        if (-not $process.Start()) {
            throw 'Could not start Godot.'
        }
        if (-not $process.WaitForExit($WaitSeconds * 1000)) {
            $process.Kill($true)
            $process.WaitForExit()
            return -1
        }
        return $process.ExitCode
    }
    finally {
        $process.Dispose()
    }
}

# The catalog is the one list of games; asking it means this script never
# keeps a second list that could drift.
function Get-GameIds {
    $listFile = Join-Path $workDir 'games.txt'
    $godotArgs = @(
        '--headless', '--path', $projectDir,
        '--script', $captureScript,
        '--', '--game=all', "--capture-list=$listFile"
    )
    $code = Invoke-Godot -Arguments $godotArgs -WaitSeconds 300 `
        -ProfileDir (New-CaptureProfile -Name 'discovery')
    if ($code -ne 0 -or -not (Test-Path -LiteralPath $listFile)) {
        throw "Could not list the games (Godot exit code $code)."
    }
    return @(
        Get-Content -LiteralPath $listFile |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ }
    )
}

function Invoke-Capture {
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Selector
    )

    $runDir = Join-Path $outputRoot $Name
    $log = Join-Path $logDir "$Name.log"
    $profileDir = New-CaptureProfile -Name $Name
    $godotArgs = @(
        '--path', $projectDir,
        '--resolution', $Resolution,
        '--log-file', $log,
        '--script', $captureScript,
        '--',
        "--game=$Selector",
        "--capture-out=$runDir",
        "--capture-profile=$profileDir",
        "--capture-size=$Resolution",
        "--capture-timeout=$TimeoutSeconds"
    )
    if ($NoScrollPages) {
        $godotArgs += '--no-scroll-pages'
    }

    Write-Host "Capturing $Name ..." -ForegroundColor Cyan
    $started = Get-Date
    $code = Invoke-Godot -Arguments $godotArgs -ProfileDir $profileDir `
        -WaitSeconds ($TimeoutSeconds + $killGraceSeconds)
    $minutes = [math]::Round(((Get-Date) - $started).TotalMinutes, 1)

    $screens = @(Get-ChildItem -LiteralPath $runDir -Filter '*.png' -ErrorAction SilentlyContinue).Count
    $index = Join-Path $runDir 'screens.txt'
    $warnings = 0
    if (Test-Path -LiteralPath $index) {
        $warnings = @(Select-String -LiteralPath $index -Pattern '^# warning:').Count
    }
    if ($code -eq -1) {
        Write-Warning "$Name did not quit within $($TimeoutSeconds + $killGraceSeconds) s and was stopped; see $log."
    }
    elseif ($code -ne 0) {
        Write-Warning "$Name ended with exit code $code; see $index and $log."
    }
    else {
        Write-Host "  -> $screens screens in $minutes min, $warnings warnings" -ForegroundColor Green
    }
    return [pscustomobject]@{
        Run      = $Name
        ExitCode = $code
        Screens  = $screens
        Warnings = $warnings
        Minutes  = $minutes
    }
}

$godotExe = Resolve-Executable -Tool $Godot
$outputRoot = if ($OutputDir) {
    $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputDir)
} else {
    Join-Path $projectDir ('build\screenshots\' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
}
$logDir = Join-Path $outputRoot 'logs'

New-Item -ItemType Directory -Path $workDir -Force | Out-Null
try {
    $known = Get-GameIds
    if ($known.Count -eq 0) {
        throw 'The catalog found no games.'
    }
    $selected = @(
        $Games |
            ForEach-Object { $_ -split ',' } |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ } |
            Select-Object -Unique
    )
    $unknown = @($selected | Where-Object { $_ -notin $known })
    if ($unknown.Count -gt 0) {
        throw "Unknown game id(s): $($unknown -join ', '). Known: $($known -join ', ')."
    }
    # -notin ignores case; the catalog does not, so pass its own spelling on.
    $selected = @($known | Where-Object { $_ -in $selected })
    if ($selected.Count -eq 0) {
        $selected = $known
    }

    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    # The output may sit inside the project; keep the editor from importing it.
    New-Item -ItemType File -Path (Join-Path $outputRoot '.gdignore') -Force | Out-Null

    $results = @()
    foreach ($game in $selected) {
        $results += Invoke-Capture -Name $game -Selector $game
    }
    if (-not $SkipCollection) {
        $results += Invoke-Capture -Name 'collection' -Selector 'all'
    }

    $results | Format-Table -AutoSize | Out-String | Write-Host
    Write-Host "Screenshots are in $outputRoot" -ForegroundColor Green
    if (@($results | Where-Object { $_.ExitCode -ne 0 }).Count -gt 0) {
        exit 1
    }
}
finally {
    if (Test-Path -LiteralPath $workDir) {
        Remove-Item -LiteralPath $workDir -Recurse -Force
    }
}
