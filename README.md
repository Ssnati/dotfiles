# dotfiles

Configuraciones personales de herramientas de desarrollo, versionadas con Git.

---

## Estructura
```
.dotfiles/
├── git/
│   └── .gitconfig
├── oh-my-posh/
│   └── kali.omp.json
├── pwsh/
│   └── Microsoft.PowerShell_profile.ps1
├── scripts/
│   ├── install.ps1       # Windows installer
│   └── install.sh        # Linux installer
├── vscode/
│   ├── keybindings.json
│   ├── settings.json
│   └── vscode-santi-default.code-profile
├── install.config.example.json
└── README.md
```

> **Nota:** Este repositorio usa una sola rama (`main`) para todas las plataformas. Los scripts de instalación detectan el sistema operativo y aplican solo las configuraciones pertinentes.

---

## Plataformas soportadas

| Plataforma      | Herramientas                                           |
|-----------------|--------------------------------------------------------|
| Windows 10/11   | vscode, pwsh, git, oh-my-posh, windows-terminal       |
| Linux (Ubuntu/Debian) | vscode, git, oh-my-posh, bat, zoxide            |

El instalador detecta el sistema operativo y aplica las configuraciones correspondientes automáticamente.

---

## Instalación

### Clonar el repositorio
```bash
git clone https://github.com/ssnati/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

### Windows
```powershell
.\scripts\install.ps1
```

El script requiere permisos para crear symlinks. Activa Developer Mode en:

- **Configuración → Sistema → Para desarrolladores → Developer Mode**
- O ejecuta el siguiente comando en PowerShell (como administrador):

```powershell
reg add "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock" /t REG_DWORD /d 1 /v "AllowDevelopmentWithoutDevLicense" /f
```

### Linux
```bash
chmod +x scripts/install.sh
./scripts/install.sh
```

### Modos del instalador

#### Windows
| Comando                              | Comportamiento                        |
|--------------------------------------|---------------------------------------|
| `.\scripts\install.ps1`              | Menú interactivo                      |
| `.\scripts\install.ps1 -All`         | Instala todas las herramientas        |
| `.\scripts\install.ps1 -Tools vscode,git` | Instala herramientas específicas  |
| `.\scripts\install.ps1 -Config`      | Lee `install.config.json`             |
| `.\scripts\install.ps1 -h`           | Muestra ayuda                         |

#### Linux
| Comando                          | Comportamiento                        |
|----------------------------------|---------------------------------------|
| `./scripts/install.sh`           | Menú interactivo                      |
| `./scripts/install.sh -a`        | Instala todas las herramientas        |
| `./scripts/install.sh -t vscode,git` | Instala herramientas específicas  |
| `./scripts/install.sh -c`        | Lee `install.config.json`             |
| `./scripts/install.sh -h`        | Muestra ayuda                         |

### Instalación selectiva con config

Crea `install.config.json` en la raíz del repo:
```json
{
  "install": ["vscode", "git"]
}
```

Luego ejecuta el instalador con `-Config` (Windows) o `-c` (Linux).

---

## Rutas originales

Rutas donde cada herramienta espera encontrar sus archivos de configuración.
El script de instalación crea symlinks desde estas rutas hacia el repo.

### Windows

| Herramienta  | Archivo                                  | Ruta original                                                                 |
|--------------|------------------------------------------|-------------------------------------------------------------------------------|
| VSCode       | `settings.json`                          | `%APPDATA%\Code\User\settings.json`                                           |
| VSCode       | `keybindings.json`                       | `%APPDATA%\Code\User\keybindings.json`                                        |
| PowerShell   | `Microsoft.PowerShell_profile.ps1`       | `%USERPROFILE%\Documents\PowerShell\Microsoft.PowerShell_profile.ps1`         |
| Git          | `.gitconfig`                             | `%USERPROFILE%\.gitconfig`                                                    |
| oh-my-posh   | `kali.omp.json`                          | `%LOCALAPPDATA%\Programs\oh-my-posh\bin\oh-my-posh.exe`                       |
| oh-my-posh   | ejecutable                               | `%LOCALAPPDATA%\Programs\oh-my-posh\themes\kali.omp.json`                     |
| windows-terminal   | `settings.json`                          | `%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json`                     |

### Linux

| Herramienta  | Archivo       | Ruta original                              |
|--------------|---------------|--------------------------------------------|
| VSCode       | `settings.json`     | `~/.config/Code/User/settings.json`  |
| VSCode       | `keybindings.json`  | `~/.config/Code/User/keybindings.json`|
| Git          | `.gitconfig`        | `~/.gitconfig`                        |
| bat          | `config`            | `~/.config/bat/config`                |

---

## Agregar una herramienta

### 1. Crear la carpeta en el repo
```powershell
mkdir nombre-herramienta
```

El nombre de la carpeta es el identificador que usará el instalador.

### 2. Copiar el archivo de configuración
```powershell
Copy-Item "ruta\original\config.archivo" ".\nombre-herramienta\config.archivo"
```

### 3. Crear el symlink manualmente (primera vez)
```powershell
Remove-Item "ruta\original\config.archivo"
New-Item -ItemType SymbolicLink -Path "ruta\original\config.archivo" -Target "$PWD\nombre-herramienta\config.archivo"
```

### 4. Registrar el instalador en `install.ps1`

Agrega una entrada al hashtable `$installers`:
```powershell
"nombre-herramienta" = {
    New-Link "$repo\nombre-herramienta\config.archivo" "ruta\destino\config.archivo"
}
```

### 5. Documentar la ruta original en este README

Agrega una fila a la tabla de **Rutas originales** con el archivo y su ruta esperada.  
Puedes consultar la sección [Rutas originales](#rutas-originales) en este README para ver ejemplos.

### 6. Commitear
```powershell
git add .
git commit -m "feat: agregar nombre-herramienta a dotfiles"
```

---

## Flujo de trabajo diario

Los archivos en el repo son los que editas directamente — no los de las rutas
originales, ya que esos son symlinks. Cualquier cambio se refleja de inmediato
en la herramienta correspondiente.

Para guardar un cambio:
```powershell
git add .
git commit -m "descripción del cambio"
git push
```