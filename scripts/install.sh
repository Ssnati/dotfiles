#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Configuración
# ============================================

readonly repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -t 1 ]]; then
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

declare -a ERRORS=()
declare -a SKIPPED=()
declare -a SUCCESS=()

# ============================================
# Rutas
# ============================================

readonly XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
readonly XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

declare -A TARGETS=(
    [vscode]="$XDG_CONFIG_HOME/Code/User"
    [oh-my-posh]="$XDG_DATA_HOME/oh-my-posh/themes"
    [bat]="$XDG_CONFIG_HOME/bat"
    [pwsh]="$XDG_CONFIG_HOME/powershell"
    [git]="$HOME"
)

# ============================================
# Funciones auxiliares
# ============================================

log_info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }

die() { log_error "$*"; exit 1; }

add_result() {
    local type="$1" tool="$2" msg="$3"
    local entry="$tool|$msg"
    case "$type" in
        error) ERRORS+=("$entry") ;;
        skip)  SKIPPED+=("$entry") ;;
        ok)    SUCCESS+=("$entry") ;;
    esac
}

show_help() {
    local tools
    mapfile -t tools < <(get_available_tools)
    cat <<EOF

Instalador de dotfiles para Linux

Uso: $(basename "$0") [OPCIONES]

Opciones:
  -a, --all          Instala todas las herramientas
  -t, --tools LIST   Herramientas separadas por coma (vscode,git)
  -c, --config       Lee install.config.json
  -v, --verbose      Salida detallada
  -n, --dry-run      Simula sin hacer cambios
  -h, --help         Muestra esta ayuda

Herramientas disponibles:
  ${tools[*]}

Ejemplos:
  $(basename "$0")              # Modo interactivo
  $(basename "$0") --all        # Instala todo
  $(basename "$0") -t vscode,git
  $(basename "$0") --config

EOF
    exit 0
}

# ============================================
# Instaladores
# ============================================

do_link() {
    local src="$1" dst="$2" tool="$3"
    local full_src="$repo/$src"
    local full_dst="${dst//\$HOME/$HOME}"
    full_dst="${full_dst//\$repo/$repo}"
    full_dst="${full_dst//\$\{XDG_CONFIG_HOME\}/$XDG_CONFIG_HOME}"
    full_dst="${full_dst//\$\{XDG_DATA_HOME\}/$XDG_DATA_HOME}"

    [[ -e "$full_src" ]] || { add_result error "$tool" "Origen no existe: $src"; return 1; }

    if [[ -L "$full_dst" ]]; then
        local current
        current=$(readlink "$full_dst" 2>/dev/null || true)
        if [[ "$current" == "$full_src" ]]; then
            add_result skip "$tool" "Ya enlazado: $dst"; return 0
        fi
        add_result error "$tool" "Enlace diferente: $dst → $current"; return 1
    fi

    if [[ -e "$full_dst" ]]; then
        add_result error "$tool" "Archivo bloquea: $dst"; return 1
    fi

    [[ "${args[verbose]:-false}" == true ]] && log_info "Enlace: $full_dst → $full_src"

    if [[ "${args[dry-run]:-false}" == true ]]; then
        add_result ok "$tool" "[DRY-RUN] $full_dst → $src"; return 0
    fi

    mkdir -p "$(dirname "$full_dst")" || { add_result error "$tool" "Error mkdir"; return 1; }
    
    if ln -s "$full_src" "$full_dst" 2>/dev/null; then
        add_result ok "$tool" "$full_dst → $src"; return 0
    else
        add_result error "$tool" "Error ln: $dst"; return 1
    fi
}

install_vscode() {
    local dir="${TARGETS[vscode]}"
    do_link vscode/settings.json "$dir/settings.json" vscode
    do_link vscode/keybindings.json "$dir/keybindings.json" vscode
}

install_git() {
    do_link git/.gitconfig "$HOME/.gitconfig" git
}

install_pwsh() {
    local dir="${TARGETS[pwsh]}"
    mkdir -p "$dir"
    do_link pwsh/Microsoft.PowerShell_profile.ps1 "$dir/Microsoft.PowerShell_profile.ps1" pwsh
}

install_oh-my-posh() {
    local dir="${TARGETS[oh-my-posh]}"
    mkdir -p "$dir"
    do_link oh-my-posh/kali.omp.json "$dir/kali.omp.json" oh-my-posh
}

install_bat() {
    local dir="${TARGETS[bat]}"
    mkdir -p "$dir"
    do_link bat/config "$dir/config" bat
}

install_windows-terminal() {
    add_result skip windows-terminal "No soportado en Linux"
}

install_zoxide() {
    add_result skip zoxide "Sin config"
}

# ============================================
# Utilidades
# ============================================

declare -A args

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -a|--all)            args[mode]=all ;;
            -c|--config)         args[mode]=config ;;
            -t|--tools)          args[mode]=tools; args[tools]="${2:-}"; shift ;;
            -v|--verbose)        args[verbose]=true ;;
            -n|--dry-run)        args[dry-run]=true ;;
            -h|--help)           show_help ;;
            -*)                  die "Opción desconocida: $1" ;;
            *)                   die "Argumento inválido: $1" ;;
        esac
        shift
    done
    args[mode]="${args[mode]:-interactive}"
}

get_available_tools() {
    find "$repo" -maxdepth 1 -type d ! -name '.' ! -name 'scripts' ! -name '.git' ! -name '.dotfiles' -exec basename {} \; 2>/dev/null | sort
}

get_tools_to_install() {
    local mode="${args[mode]}"
    local all_tools
    mapfile -t all_tools < <(get_available_tools)

    case "$mode" in
        all)
            printf '%s\n' "${all_tools[@]}"
            ;;
        tools)
            local requested="${args[tools]:-}"
            [[ -z "$requested" ]] && die "-t/--tools requiere una lista de herramientas"

            local invalid_tools=()
            IFS=',' read -ra raw_tools <<< "$requested"
            for t in "${raw_tools[@]}"; do
                local normalized
                normalized=$(echo "$t" | tr '[:upper:]' '[:lower:]' | xargs)
                [[ -z "$normalized" ]] && continue

                local found=false
                for available in "${all_tools[@]}"; do
                    if [[ "$normalized" == "$(echo "$available" | tr '[:upper:]' '[:lower:]')" ]]; then
                        printf '%s\n' "$available"
                        found=true
                        break
                    fi
                done
                [[ "$found" == false ]] && invalid_tools+=("$t")
            done

            if [[ ${#invalid_tools[@]} -gt 0 ]]; then
                log_error "Herramientas desconocidas: ${invalid_tools[*]}"
                die "Usa --help para ver disponibles"
            fi
            ;;
        config)
            read_config
            ;;
        interactive)
            echo "== Instalación de dotfiles =="
            local selected=()
            for tool in "${all_tools[@]}"; do
                read -r -p "  Instalar '$tool'? [s/N]: " resp
                [[ "$resp" =~ ^[sS]$ ]] && selected+=("$tool")
            done
            printf '%s\n' "${selected[@]}"
            ;;
    esac
}

read_config() {
    local cfg="$repo/install.config.json"
    [[ -f "$cfg" ]] || { log_warn "No existe install.config.json"; return; }
    command -v jq &>/dev/null && jq -r '.tools[]?' "$cfg" 2>/dev/null
}

validate_tools() {
    local all_tools
    mapfile -t all_tools < <(get_available_tools)
    local validated=()

    while IFS= read -r tool; do
        [[ -z "$tool" ]] && continue
        local normalized
        normalized=$(echo "$tool" | tr '[:upper:]' '[:lower:]' | xargs)
        for available in "${all_tools[@]}"; do
            if [[ "$normalized" == "$(echo "$available" | tr '[:upper:]' '[:lower:]')" ]]; then
                validated+=("$available")
                break
            fi
        done
    done < <(printf '%s\n' "$@")
    printf '%s\n' "${validated[@]}"
}

run_install() {
    local tool="$1"
    case "$tool" in
        vscode)        install_vscode ;;
        git)           install_git ;;
        pwsh)          install_pwsh ;;
        oh-my-posh)    install_oh-my-posh ;;
        bat)           install_bat ;;
        windows-terminal) install_windows-terminal ;;
        zoxide)        install_zoxide ;;
        *)             add_result error "$tool" "Instalador no definido" ;;
    esac
}

print_summary() {
    echo ""
    echo "  ══════════════════════════════"
    echo -e "  ${CYAN}Resumen${NC}"
    echo "  ══════════════════════════════"

    if [[ ${#SUCCESS[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${GREEN}✔ Exitosos (${#SUCCESS[@]}):${NC}"
        for entry in "${SUCCESS[@]}"; do
            echo "    [${entry%%|*}] ${entry##*|}"
        done
    fi

    if [[ ${#SKIPPED[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${YELLOW}⚠ Omitidos (${#SKIPPED[@]}):${NC}"
        for entry in "${SKIPPED[@]}"; do
            echo "    [${entry%%|*}] ${entry##*|}"
        done
    fi

    if [[ ${#ERRORS[@]} -gt 0 ]]; then
        echo ""
        echo -e "  ${RED}✘ Errores (${#ERRORS[@]}):${NC}"
        for entry in "${ERRORS[@]}"; do
            echo "    [${entry%%|*}] ${entry##*|}"
        done
    fi

    echo ""
    if [[ ${#ERRORS[@]} -eq 0 ]]; then
        echo -e "  ${GREEN}✓ Listo. Recarga tu shell.${NC}"
    else
        echo -e "  ${YELLOW}⚠ Completado con errores.${NC}"
        exit 1
    fi
}

# ============================================
# MAIN
# ============================================

main() {
    cd "$repo" || die "No se pudo acceder al repositorio"
    parse_args "$@"
    [[ "${args[verbose]:-false}" == true ]] && log_info "Modo: ${args[mode]}"

    local tools
    mapfile -t tools < <(get_tools_to_install)
    local validated
    mapfile -t validated < <(printf '%s\n' "${tools[@]}" | validate_tools)

    if [[ ${#validated[@]} -eq 0 ]]; then
        log_warn "No hay herramientas para instalar"
        exit 0
    fi

    for tool in "${validated[@]}"; do
        run_install "$tool"
    done

    print_summary
}

main "$@"
