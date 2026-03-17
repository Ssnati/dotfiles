# ==================================================
# install.ps1 — Windows
# Ejecutar desde la raíz del repo (rama windows)
# ==================================================

param(
    [alias("h")][switch]$Help,
    [alias("a")][switch]$All,
    [switch]$Config,
    [string]$Tools
)

$repo = Split-Path -Parent $PSScriptRoot
$userHome   = $env:USERPROFILE
$vscode = "$env:APPDATA\Code\User"
$availableTools = (Get-ChildItem -Path $repo -Directory |
    Where-Object { $_.Name -notin @("scripts", ".git") }).Name

$errors   = @()
$skipped  = @()
$success  = @()

# ==================================================
# Ayuda
# ==================================================
if ($Help) {
    $availableTools = Get-ChildItem -Path $repo -Directory |
        Where-Object { $_.Name -notin @("scripts", ".git") } |
        ForEach-Object { $_.Name }

    Write-Host @"

NOMBRE
    install.ps1 - Instalador de dotfiles para Windows

SINTAXIS
    .\install.ps1 [[-Tools] <string>] [-All] [-Config] [-Help]

DESCRIPCION
    Crea symlinks para las herramientas configuradas en el repositorio
    de dotfiles. Puede ejecutarse en modo interactivo, por flags o
    leyendo un archivo de configuracion.

PARAMETROS
    -All, -a
        Instala todas las herramientas disponibles en el repositorio.

    -Tools <string>
        Lista de herramientas separadas por coma.
        Ejemplo: -Tools vscode,git

    -Config
        Lee el archivo install.config.json en la raiz del repo
        y instala las herramientas listadas en el campo "install".

    -Help, -h
        Muestra esta ayuda.

HERRAMIENTAS DISPONIBLES
    $($availableTools -join ", ")

EJEMPLOS
    .\install.ps1
        Ejecuta el instalador en modo interactivo.

    .\install.ps1 -All
        Instala todas las herramientas disponibles.

    .\install.ps1 -Tools vscode,git
        Instala unicamente VSCode y Git.

    .\install.ps1 -Config
        Lee install.config.json y ejecuta segun su contenido.

"@
    exit 0
}

# ==================================================
# Función de symlink
# ==================================================
function New-Link($src, $dst) {
    $tool = $script:currentTool

    if (-not (Test-Path $src)) {
        $script:errors += "[$tool] Archivo fuente no encontrado: $src"
        return
    }

    if (Test-Path $dst) {
        $item = Get-Item $dst -ErrorAction SilentlyContinue
        if ($item.LinkType -eq "SymbolicLink") {
        $script:skipped += "[$tool] Symlink ya existe: $dst"
        return
    } else {
        $script:errors += "[$tool] Ya existe un archivo real en: $dst — elimínalo manualmente para crear el symlink"
        return
        }
    }

    try {
        $dstDir = Split-Path $dst
        if (-not (Test-Path $dstDir)) {
            New-Item -ItemType Directory -Path $dstDir -Force | Out-Null
        }
        New-Item -ItemType SymbolicLink -Path $dst -Target $src -ErrorAction Stop | Out-Null
        $script:success += "[$tool] $dst -> $src"
    } catch {
        $script:errors += "[$tool] Error al crear symlink: $($_.Exception.Message)"
    }
}

# ==================================================
# Instaladores por herramienta
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
    zoxide = {
        # zoxide no tiene archivo de config propio
        $script:skipped += "[zoxide] Sin archivo de config — inicialización va en el perfil de PowerShell"
    }
    "windows-terminal" = {
        New-Link "$repo\windows-terminal\settings.json" "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    }
}

# ==================================================
# Resolver qué herramientas instalar
# ==================================================
$toInstall = @()

    if ($All) {
        $toInstall = $availableTools
    } elseif ($Config) {
        $configFile = "$repo\install.config.json"
        if (-not (Test-Path $configFile)) {
            Write-Host "  [error] No se encontró install.config.json en la raíz del repo" -ForegroundColor Red
            exit 1
        }
        try {
            $json = Get-Content $configFile -Raw | ConvertFrom-Json
            $toInstall = $json.install
        } catch {
            Write-Host "  [error] No se pudo leer install.config.json: $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    } elseif ($Tools) {
        $toInstall = $Tools -split ","
    } else {
        # Menú interactivo
        Write-Host ""
        Write-Host "  == Instalación de dotfiles ==" -ForegroundColor Cyan
        Write-Host ""
        foreach ($tool in $availableTools) {
            $resp = Read-Host "  ¿Instalar '$tool'? [s/n]"
            if ($resp -eq "s") { $toInstall += $tool }
        }
    }

# ==================================================
# Validar herramientas solicitadas
# ==================================================
foreach ($tool in $toInstall) {
    $tool = $tool.Trim().ToLower()
    if (-not $installers.Contains($tool)) {
        $errors += "[input] Herramienta desconocida: '$tool'"
    }
}

# ==================================================
# Ejecutar instalación
# ==================================================
Write-Host ""
Write-Host "  Instalando..." -ForegroundColor Cyan
Write-Host ""

foreach ($tool in $toInstall) {
    $tool = $tool.Trim().ToLower()
    if ($installers.Contains($tool)) {
        $script:currentTool = $tool
        & $installers[$tool]
    }
}

# ==================================================
# Resumen
# ==================================================
Write-Host ""
Write-Host "  ══════════════════════════════" -ForegroundColor DarkGray
Write-Host "  Resumen" -ForegroundColor Cyan
Write-Host "  ══════════════════════════════" -ForegroundColor DarkGray

if ($success.Count -gt 0) {
    Write-Host ""
    Write-Host "  Exitosos ($($success.Count)):" -ForegroundColor Green
    $success | ForEach-Object { Write-Host "    ✔ $_" -ForegroundColor Green }
}

if ($skipped.Count -gt 0) {
    Write-Host ""
    Write-Host "  Omitidos ($($skipped.Count)):" -ForegroundColor Yellow
    $skipped | ForEach-Object { Write-Host "    ⚠ $_" -ForegroundColor Yellow }
}

if ($errors.Count -gt 0) {
    Write-Host ""
    Write-Host "  Errores ($($errors.Count)):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "    ✘ $_" -ForegroundColor Red }
}

Write-Host ""
if ($errors.Count -eq 0) {
    Write-Host "  Todo listo. Reinicia PowerShell para aplicar los cambios." -ForegroundColor Green
} else {
    Write-Host "  Instalación completada con errores. Revisa los mensajes anteriores." -ForegroundColor Yellow
}
Write-Host ""