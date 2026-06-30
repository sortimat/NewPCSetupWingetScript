<#
.SYNOPSIS
Installs a list of applications using winget.

.DESCRIPTION
Loops through an array of winget package IDs and installs each one.
Logs success/failure per app instead of stopping the whole run on
the first failure, and prints a summary at the end.

.NOTES
- Use winget package IDs (e.g. "Microsoft.PowerToys"), not display
  names — IDs are unambiguous, names can match multiple packages
  or fail to match at all. Run "winget search <name>" to find the
  right ID if you're not sure.
- Some packages (drivers, anything touching system paths) may
  require an elevated (Run as Administrator) PowerShell session.
  Most user-scope app installs do not.
- --accept-package-agreements and --accept-source-agreements are
  included so the script doesn't hang waiting for an interactive
  prompt. Read what you're agreeing to before relying on this.
- Apps that typically require an interactive sign-in or license
  flow (e.g. Microsoft.Office) are intentionally kept out of the
  bulk list below — winget can kick off the install, but it will
  often need you to finish it by hand, so it's separated out so
  one stuck install doesn't make the whole run look "stuck."
#>

# Edit this list with the winget IDs of the apps you want installed
$apps = @(
    "Google.Chrome"
    "Mozilla.Firefox"
    "Bitwarden.Bitwarden"
    "Valve.Steam"
    "Discord.Discord"
    "Logitech.GHUB"
    "Logitech.OptionsPlus"
    "Google.GoogleDrive"
    "Proton.ProtonDrive"
    "Proton.ProtonAuthenticator"
    "Spotify.Spotify"
    "calibre.calibre"
    "Rem0o.FanControl"
    "Obsidian.Obsidian"
    "RazerInc.RazerInstaller.Synapse3"
    "REALix.HWiNFO"
    "Bambulab.Bambustudio"
    "Cyanfish.NAPS2"
    "RealVNC.VNCViewer"
    "8BitDo.UltimateSoftwareV2"
)

# Apps that commonly need an interactive license/sign-in step and may
# hang or "fail" under --silent even though nothing is actually wrong.
# Run these separately, by hand, after the bulk list finishes.
$interactiveApps = @(
    "Microsoft.Office"
)

# Confirm winget is actually available before doing anything else
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Error "winget was not found on this system. Install 'App Installer' from the Microsoft Store, then re-run this script."
    exit 1
}

# Warn (don't block) if not elevated — a few of the apps above (drivers,
# Logitech/Razer device software) may need this to fully install.
$isElevated = ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains "S-1-5-32-544")
if (-not $isElevated) {
    Write-Host "Note: this session is not running as Administrator. Most installs below will still work, but driver/device-software packages (Logitech, Razer, HWiNFO) may need an elevated session to finish cleanly." -ForegroundColor Yellow
}

$results = @()

foreach ($app in $apps) {
    Write-Host "`nInstalling $app ..." -ForegroundColor Cyan
    try {
        $output = winget install --id $app --exact --silent `
            --accept-package-agreements --accept-source-agreements 2>&1
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Write-Host " -> Success" -ForegroundColor Green
            $results += [PSCustomObject]@{ App = $app; Status = "Success"; ExitCode = $exitCode }
        }
        else {
            Write-Host " -> Failed (exit code $exitCode)" -ForegroundColor Yellow
            $results += [PSCustomObject]@{ App = $app; Status = "Failed"; ExitCode = $exitCode }
        }
    }
    catch {
        Write-Host " -> Error: $_" -ForegroundColor Red
        $results += [PSCustomObject]@{ App = $app; Status = "Error"; ExitCode = $_.Exception.Message }
    }
}

Write-Host "`n===== Install Summary =====" -ForegroundColor Magenta
$results | Format-Table -AutoSize

$failed = $results | Where-Object { $_.Status -ne "Success" }
if ($failed) {
    Write-Host "`n$($failed.Count) app(s) did not install successfully. Scroll up or check the table above for exit codes." -ForegroundColor Yellow
}
else {
    Write-Host "`nAll apps installed successfully." -ForegroundColor Green
}

if ($interactiveApps.Count -gt 0) {
    Write-Host "`n===== Apps requiring interactive setup (not auto-installed) =====" -ForegroundColor Magenta
    foreach ($app in $interactiveApps) {
        Write-Host " - $app  (run: winget install --id $app --exact)" -ForegroundColor Cyan
    }
}
