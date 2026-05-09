# Auto-detect project root (works on ANY PC, ANY path)
$projectRoot = $PSScriptRoot
$launcher    = Join-Path $projectRoot 'SolarFlow.cmd'
$desktop     = [Environment]::GetFolderPath('Desktop')
$lnk         = Join-Path $desktop 'SolarFlow.lnk'

Write-Host ''
Write-Host '  SolarFlow - Desktop Shortcut Creator' -ForegroundColor Cyan
Write-Host "  Project: $projectRoot" -ForegroundColor Gray
Write-Host ''

if (-not (Test-Path $launcher)) {
    Write-Host '  ERROR: SolarFlow.cmd not found in project folder!' -ForegroundColor Red
    Write-Host '  Make sure this script is inside the project directory.' -ForegroundColor Yellow
    pause
    exit 1
}

$shell = New-Object -ComObject WScript.Shell
$sc    = $shell.CreateShortcut($lnk)

$sc.TargetPath       = 'cmd.exe'
$sc.Arguments        = '/c "' + $launcher + '"'
$sc.WorkingDirectory = $projectRoot
$sc.WindowStyle      = 1
$sc.Description      = 'Launch SolarFlow Autonomous Irrigation Dashboard'
$sc.IconLocation     = 'C:\Windows\System32\shell32.dll, 13'
$sc.Save()

Write-Host '  Shortcut created on Desktop: SolarFlow.lnk' -ForegroundColor Green
Write-Host "  Points to: $launcher" -ForegroundColor Gray
