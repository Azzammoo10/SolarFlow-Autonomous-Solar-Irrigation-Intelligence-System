$WshShell = New-Object -ComObject WScript.Shell
$Desktop = [System.Environment]::GetFolderPath("Desktop")
$ShortcutPath = Join-Path $Desktop "SolarFlow.lnk"
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)

# Chemin vers ton script .cmd
$TargetPath = Join-Path $PSScriptRoot "SolarFlow.cmd"

$Shortcut.TargetPath = "cmd.exe"
# /c ferme la fenêtre après, /k la laisse ouverte. On utilise /k pour voir les logs du backend.
$Shortcut.Arguments = "/k `"$TargetPath`""
$Shortcut.WorkingDirectory = $PSScriptRoot
$Shortcut.WindowStyle = 1 # Fenêtre normale
$Shortcut.IconLocation = "shell32.dll, 14" # Icône d'un monde/réseau (très SolarFlow !)
$Shortcut.Save()

Write-Host "------------------------------------------------" -ForegroundColor Green
Write-Host "  Raccourci cree avec succes sur le Bureau !" -ForegroundColor Green
Write-Host "  Cible : $TargetPath" -ForegroundColor White
Write-Host "------------------------------------------------"
