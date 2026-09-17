<#
.SYNOPSIS
    Records the "How to play" clips used by the instructions screen.

.DESCRIPTION
    Runs res://tools/tutorial_capture.tscn through Godot's Movie Maker for each
    requested game, then encodes the intermediate AVIs to the Ogg Theora files
    Godot's VideoStreamPlayer can play and extracts a still poster frame for
    each clip. Re-run this after changing gameplay visuals or the tutorial
    captions.

.EXAMPLE
    pwsh tools\record_tutorials.ps1 -Godot 'C:\Godot\Godot_v4.7.2-stable_win64.exe'

.EXAMPLE
    pwsh tools\record_tutorials.ps1 -Godot 'C:\Godot\Godot_v4.7.2-stable_win64.exe' -Games anti_chess -Variants local
#>
[CmdletBinding()]
param(
    [string] $Godot = $env:GODOT,
    [string] $FFmpeg = 'ffmpeg',
    [int]    $Fps = 30,
    [string] $CaptureResolution = '1280x720',
    [string] $OutputScale = '960:540',
    [int]    $Quality = 7,
    [ValidateSet('triangle_rush', 'desk_can_saw', 'dead_metal_jam', 'chicken_pit', 'anti_chess', 'lazer_nfc')]
    [string[]] $Games = @('triangle_rush', 'desk_can_saw', 'dead_metal_jam', 'chicken_pit', 'anti_chess', 'lazer_nfc'),
    [ValidateSet('solo', 'local')]
    [string[]] $Variants = @('solo', 'local')
)

$ErrorActionPreference = 'Stop'

# Seconds into each clip that best represent the game on the idle poster.
$PosterTimes = @{
    triangle_rush    = '6.2'
    desk_can_saw     = '10.8'
    dead_metal_jam   = '13.4'
    chicken_pit      = '9.0'
    anti_chess       = '9.8'
    anti_chess_local = '9.8'
    lazer_nfc       = '5.0'
}

# Per-game encoder quality, for clips the shared default does not suit. Chicken
# Pit's grass, bunting and moving camera give Theora
# far more to chew on, and quality 7 produced a file twice the size of any
# other walkthrough. Quality 5 lands it alongside them with no visible loss.
# An explicit -Quality still wins, so a caller can compare encodes.
$Qualities = @{
    chicken_pit = 5
    lazer_nfc = 5
}
$QualityWasRequested = $PSBoundParameters.ContainsKey('Quality')

$projectDir = Split-Path -Parent $PSScriptRoot
$gamesDir = Join-Path $projectDir 'games'
$workDir = Join-Path ([System.IO.Path]::GetTempPath()) (
    'dcs_tutorial_capture_' + [guid]::NewGuid().ToString('N')
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

# ArgumentList preserves spaces without assembling a shell command. Waiting on
# the process also handles Godot's GUI-subsystem Windows executable.
function Invoke-Tool {
    param(
        [Parameter(Mandatory)] [string] $FilePath,
        [Parameter(Mandatory)] [string[]] $Arguments,
        [Parameter(Mandatory)] [string] $What
    )

    $info = [System.Diagnostics.ProcessStartInfo]::new($FilePath)
    $info.UseShellExecute = $false
    foreach ($argument in $Arguments) {
        $info.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $info
    try {
        if (-not $process.Start()) {
            throw "Could not start $What."
        }
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) {
            throw "$What failed with exit code $($process.ExitCode)."
        }
    }
    finally {
        $process.Dispose()
    }
}

function Assert-OutputFile {
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [string] $What
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "$What did not create '$Path'."
    }
    if ((Get-Item -LiteralPath $Path).Length -le 0) {
        throw "$What created an empty file at '$Path'."
    }
}

function New-CapturePlans {
    param(
        [Parameter(Mandatory)] [string[]] $SelectedGames,
        [Parameter(Mandatory)] [string[]] $SelectedVariants
    )

    $plans = @()
    foreach ($game in $SelectedGames | Select-Object -Unique) {
        # Every clip lands in its own game folder, so the final names carry no
        # game prefix. The intermediates still do: one shared temp directory
        # holds them all, and two games' 'tutorial.ogv' would collide there.
        $targetDir = Join-Path $gamesDir "$game\assets\video"
        if ($game -eq 'anti_chess') {
            foreach ($variant in $SelectedVariants) {
                $suffix = if ($variant -eq 'local') { '_local' } else { '' }
                $plans += [pscustomobject]@{
                    Label      = "$game ($variant)"
                    Game       = $game
                    Variant    = $variant
                    AviName    = "tutorial_$game$suffix.avi"
                    TempVideo  = "tutorial_$game$suffix.ogv"
                    TempPoster = "tutorial_${game}${suffix}_poster.webp"
                    VideoName  = "tutorial$suffix.ogv"
                    PosterName = "tutorial${suffix}_poster.webp"
                    PosterKey  = "anti_chess$suffix"
                    TargetDir  = $targetDir
                    Quality    = $Quality
                }
            }
            continue
        }

        $plans += [pscustomobject]@{
            Label      = $game
            Game       = $game
            Variant    = $null
            AviName    = "tutorial_$game.avi"
            TempVideo  = "tutorial_$game.ogv"
            TempPoster = "tutorial_${game}_poster.webp"
            VideoName  = 'tutorial.ogv'
            PosterName = 'tutorial_poster.webp'
            PosterKey  = $game
            TargetDir  = $targetDir
            Quality    = if (-not $QualityWasRequested -and $Qualities.ContainsKey($game)) {
                $Qualities[$game]
            } else {
                $Quality
            }
        }
    }
    return $plans
}

$godotExe = Resolve-Executable -Tool $Godot
$ffmpegExe = Resolve-Executable -Tool $FFmpeg
$variantList = @(
    $Variants |
        ForEach-Object { $_.ToLowerInvariant() } |
        Select-Object -Unique
)
if ($variantList.Count -eq 0) {
    throw 'At least one Anti-Chess tutorial variant must be selected.'
}

New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$previousAppData = $env:APPDATA
$previousXdgData = $env:XDG_DATA_HOME

try {
    $profile = Join-Path $workDir 'user-data'
    New-Item -ItemType Directory -Path $profile -Force | Out-Null
    $env:APPDATA = $profile
    $env:XDG_DATA_HOME = $profile
    $plans = New-CapturePlans -SelectedGames $Games -SelectedVariants $variantList
    if ($plans.Count -eq 0) {
        throw 'No tutorial capture plans were generated.'
    }

    foreach ($plan in $plans) {
        $avi = Join-Path $workDir $plan.AviName
        $ogv = Join-Path $workDir $plan.TempVideo
        $poster = Join-Path $workDir $plan.TempPoster
        $posterAt = if ($PosterTimes.ContainsKey($plan.PosterKey)) {
            $PosterTimes[$plan.PosterKey]
        } else {
            '6.0'
        }

        Write-Host "Recording $($plan.Label) ..." -ForegroundColor Cyan
        $godotArgs = @(
            '--path', $projectDir,
            '--resolution', $CaptureResolution,
            '--fixed-fps', $Fps,
            '--write-movie', $avi,
            'res://tools/tutorial_capture.tscn',
            '++',
            "--game=$($plan.Game)"
        )
        if ($plan.Variant) {
            $godotArgs += "--tutorial-variant=$($plan.Variant)"
        }
        Invoke-Tool -FilePath $godotExe -What "Recording $($plan.Label)" -Arguments $godotArgs
        Assert-OutputFile -Path $avi -What "Recording $($plan.Label)"

        Write-Host "Encoding $($plan.Label) ..." -ForegroundColor Cyan
        # Audio is dropped on purpose: the clip plays behind menu music and the
        # on-screen captions carry the explanation.
        Invoke-Tool -FilePath $ffmpegExe -What "Encoding $($plan.Label)" -Arguments @(
            '-y', '-hide_banner', '-loglevel', 'error',
            '-i', $avi, '-an',
            '-vf', "scale=$OutputScale`:flags=lanczos",
            '-r', $Fps,
            '-c:v', 'libtheora', '-q:v', $plan.Quality,
            $ogv
        )
        Assert-OutputFile -Path $ogv -What "Encoding $($plan.Label)"

        $sizeMb = [math]::Round((Get-Item -LiteralPath $ogv).Length / 1MB, 2)
        Write-Host "  -> $($plan.VideoName) ($sizeMb MB)" -ForegroundColor Green

        # Still frame for the idle state of the card: the clips fade in from
        # black, so frame 0 would look like a broken player.
        Invoke-Tool -FilePath $ffmpegExe -What "Poster for $($plan.Label)" -Arguments @(
            '-y', '-hide_banner', '-loglevel', 'error',
            '-ss', $posterAt, '-i', $ogv, '-frames:v', '1',
            '-vf', 'scale=640:360:flags=lanczos',
            '-c:v', 'libwebp', '-quality', '82',
            $poster
        )
        Assert-OutputFile -Path $poster -What "Poster for $($plan.Label)"
        New-Item -ItemType Directory -Path $plan.TargetDir -Force | Out-Null
        Move-Item -LiteralPath $ogv -Destination (Join-Path $plan.TargetDir $plan.VideoName) -Force
        Move-Item -LiteralPath $poster -Destination (Join-Path $plan.TargetDir $plan.PosterName) -Force
        Remove-Item -LiteralPath $avi -Force
        Write-Host "  -> $($plan.PosterName)" -ForegroundColor Green
    }

    Write-Host 'Done.' -ForegroundColor Green
}
finally {
    $env:APPDATA = $previousAppData
    $env:XDG_DATA_HOME = $previousXdgData
    if (Test-Path -LiteralPath $workDir) {
        Remove-Item -LiteralPath $workDir -Recurse -Force
    }
}
