try {
    # ───────────────────────────────
    # 🧠 Inicialización del entorno
    # ───────────────────────────────
    (@(& oh-my-posh init pwsh --config="$env:POSH_THEMES_PATH\kali.omp.json" --print) -join "`n") | Invoke-Expression
    # Import-Module Terminal-Icons -ErrorAction Stop
    Set-PSReadLineOption -PredictionViewStyle ListView
    Invoke-Expression (& { (zoxide init powershell | Out-String) })

    # ───────────────────────────────
    # 🎨 Funciones auxiliares
    # ───────────────────────────────

    function Write-ColorLine {
        param (
            [string]$prefix,
            [string]$label,
            [string]$value,
            [string]$suffix = "",
            [ConsoleColor]$prefixColor = 'DarkCyan',
            [ConsoleColor]$labelColor = 'Gray',
            [ConsoleColor]$valueColor = 'DarkGreen'
        )

        Write-Host $prefix -ForegroundColor $prefixColor -NoNewline
        Write-Host $label -ForegroundColor $labelColor -NoNewline
        Write-Host $value -ForegroundColor $valueColor -NoNewline
        if ($suffix) { Write-Host $suffix -ForegroundColor $prefixColor } else { Write-Host "" }
    }

    function Show-WelcomeBox {
        param (
            [string]$nombre = "Sanik",
            [ConsoleColor]$colorCaja = 'DarkCyan',
            [ConsoleColor]$colorSubtitulo = 'Gray',
            [ConsoleColor]$colorContenido = 'DarkGreen'
        )

        $fecha = Get-Date -Format "dddd, dd MMMM yyyy - HH:mm:ss"
        $hostname = hostname
        $pwshVer = $PSVersionTable.PSVersion

        Write-Host ""
        Write-Host $fecha -ForegroundColor 'Red'
        Write-Host "┌─────────────────────────┐" -ForegroundColor $colorCaja
        Write-ColorLine "│  " "Hola " $nombre "		  │" $colorCaja $colorSubtitulo $colorContenido
        Write-ColorLine "│  " "Host: " $hostname "  │" $colorCaja $colorSubtitulo $colorContenido
        Write-ColorLine "│  " "PowerShell: " $pwshVer "	  │" $colorCaja $colorSubtitulo $colorContenido
        Write-Host "└─────────────────────────┘" -ForegroundColor $colorCaja
        Write-Host ""
    }

    # ───────────────────────────────
    # 🚀 Ejecución del banner
    # ───────────────────────────────
    Show-WelcomeBox -nombre "Sanik"
}
catch {
    Write-Host "⚠️ Error al cargar el perfil: $($_.Exception.Message)"
}