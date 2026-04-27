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

. "$PSScriptRoot\installers-symlinks.ps1"

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
        $toInstall = $json.tools
    } catch {
        Write-Host "  [error] No se pudo leer install.config.json: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
} elseif ($Tools) {
    $rawTools = $Tools -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    if ($rawTools.Count -eq 0) {
        Write-Host "  [error] -Tools requiere una lista de herramientas" -ForegroundColor Red
        exit 1
    }
    $toInstall = $rawTools
} else {
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
$validatedTools = @()
$invalidTools = @()

foreach ($rawTool in $toInstall) {
    $normalized = $rawTool.Trim().ToLower()
    if ($normalized -eq "") { continue }

    if ($installers.ContainsKey($normalized)) {
        $validatedTools += $normalized
    } else {
        $invalidTools += $rawTool
    }
}

if ($invalidTools.Count -gt 0) {
    Write-Host ""
    Write-Host "  [error] Herramientas desconocidas: $($invalidTools -join ", ")" -ForegroundColor Red
    Write-Host "  Usa -Help para ver herramientas disponibles" -ForegroundColor Yellow
    exit 1
}

if ($validatedTools.Count -eq 0) {
    Write-Host "  [warn] No hay herramientas para instalar" -ForegroundColor Yellow
    exit 0
}

# ==================================================
# Ejecutar instalación
# ==================================================
Write-Host ""
Write-Host "  Instalando..." -ForegroundColor Cyan
Write-Host ""

foreach ($tool in $validatedTools) {
    $script:currentTool = $tool
    & $installers[$tool]
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