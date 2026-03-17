# ==================================================
# tools.ps1 — Registro de herramientas y sus symlinks
# Agregar una herramienta nueva: añadir una entrada al hashtable
# ==================================================
$installers = [ordered]@{
    vscode = {
        New-Link "$repo\vscode\settings.json"    "$vscode\settings.json"
        New-Link "$repo\vscode\keybindings.json" "$vscode\keybindings.json"
    }
    git = {
        New-Link "$repo\git\.gitconfig" "$userHome\.gitconfig"
    }
    pwsh = {
        New-Link "$repo\pwsh\Microsoft.PowerShell_profile.ps1" $PROFILE
    }
    "oh-my-posh" = {
        New-Link "$repo\oh-my-posh\kali.omp.json" "$env:POSH_THEMES_PATH\kali.omp.json"
    }
    bat = {
        New-Link "$repo\bat\config" "$env:APPDATA\bat\config"
    }
    "windows-terminal" = {
        New-Link "$repo\windows-terminal\settings.json" "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    }
    zoxide = {
        $script:skipped += "[zoxide] Sin archivo de config — inicialización va en el perfil de PowerShell"
    }
}