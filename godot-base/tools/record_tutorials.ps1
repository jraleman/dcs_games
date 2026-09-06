<#
.SYNOPSIS
    Records the "How to play" clips used by the instructions screen.

.DESCRIPTION
    Runs res://tools/tutorial_capture.tscn through Godot's Movie Maker for each
    game, then encodes the intermediate AVIs to the Ogg Theora files Godot's
    VideoStreamPlayer can play and extracts a still poster frame for each clip.
    Re-run this after changing gameplay visuals or the tutorial captions.

.EXAMPLE
    pwsh tools/record_tutorials.ps1 -Godot 'C:\Godot\Godot_v4.7.2-stable_win64.exe'
#>
[CmdletBinding()]
param(
    [string] $Godot = $env:GODOT,
    [string] $FFmpeg = 'ffmpeg',
    [int]    $Fps = 30,
    [string] $CaptureResolution = '1280x720',
    [string] $OutputScale = '960:540',
    [int]    $Quality = 7,
    [string[]] $Games = @('triangle_rush', 'desk_can_saw', 'dead_metal_jam')
)

$ErrorActionPreference = 'Stop'

# Seconds into each clip that best represent the game on the idle poster.
$PosterTimes = @{
    triangle_rush  = '6.2'
    desk_can_saw   = '10.8'
    dead_metal_jam = '13.4'
}

$projectDir = Split-Path -Parent $PSScriptRoot
$videoDir = Join-Path $projectDir 'assets/video'
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) "dcs_tutorial_capture"

if (-not $Godot) {
    throw "Godot executable not found. Pass -Godot <path> or set the GODOT environment variable."
}
foreach ($tool in @($Godot, $FFmpeg)) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Cannot run '$tool'. Install it or pass an explicit path."
    }
}

New-Item -ItemType Directory -Path $videoDir, $workDir -Force | Out-Null

# Godot's Windows binary is a GUI-subsystem executable, so `&` would not wait
# for it. Start-Process -Wait gives a reliable exit code on every platform.
function Invoke-Tool {
    param([string] $FilePath, [string[]] $Arguments, [string] $What)

    $process = Start-Process -FilePath $FilePath -ArgumentList $Arguments `
        -NoNewWindow -Wait -PassThru
    if ($process.ExitCode -ne 0) {
        throw "$What failed with exit code $($process.ExitCode)."
    }
}

foreach ($game in $Games) {
    $avi = Join-Path $workDir "$game.avi"
    $ogv = Join-Path $videoDir "tutorial_$game.ogv"

    Write-Host "Recording $game ..." -ForegroundColor Cyan
    Invoke-Tool -FilePath $Godot -What "Recording $game" -Arguments @(
        '--path', $projectDir,
        '--resolution', $CaptureResolution,
        '--fixed-fps', $Fps,
        '--write-movie', $avi,
        'res://tools/tutorial_capture.tscn',
        '++', "--game=$game"
    )

    Write-Host "Encoding $game ..." -ForegroundColor Cyan
    # Audio is dropped on purpose: the clip plays behind menu music and the
    # on-screen captions carry the explanation.
    Invoke-Tool -FilePath $FFmpeg -What "Encoding $game" -Arguments @(
        '-y', '-hide_banner', '-loglevel', 'error',
        '-i', $avi, '-an',
        '-vf', "scale=$OutputScale`:flags=lanczos",
        '-r', $Fps,
        '-c:v', 'libtheora', '-q:v', $Quality,
        $ogv
    )

    $sizeMb = [math]::Round((Get-Item $ogv).Length / 1MB, 2)
    Write-Host "  -> $ogv ($sizeMb MB)" -ForegroundColor Green

    # Still frame for the idle state of the card: the clips fade in from black,
    # so frame 0 would look like a broken player.
    $poster = Join-Path $videoDir "tutorial_${game}_poster.webp"
    $posterAt = if ($PosterTimes.ContainsKey($game)) { $PosterTimes[$game] } else { '6.0' }
    Invoke-Tool -FilePath $FFmpeg -What "Poster for $game" -Arguments @(
        '-y', '-hide_banner', '-loglevel', 'error',
        '-ss', $posterAt, '-i', $ogv, '-frames:v', '1',
        '-vf', 'scale=640:360:flags=lanczos',
        '-c:v', 'libwebp', '-quality', '82',
        $poster
    )
    Write-Host "  -> $poster" -ForegroundColor Green
}

Remove-Item $workDir -Recurse -Force
Write-Host "Done. Run 'godot --headless --path . --import' so Godot picks up the new assets." -ForegroundColor Green
