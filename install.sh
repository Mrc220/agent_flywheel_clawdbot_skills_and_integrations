#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
# Agent Flywheel Clawdbot Skills Installer
# https://github.com/Dicklesworthstone/agent_flywheel_clawdbot_skills_and_integrations
#
# Usage:
#   curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/agent_flywheel_clawdbot_skills_and_integrations/main/install.sh?v=$(date +%s)" | bash
#   curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/agent_flywheel_clawdbot_skills_and_integrations/main/install.sh?v=$(date +%s)" | bash -s -- --all
#
# Options:
#   --all           Install all skills without prompting
#   --dest DIR      Custom skills directory
#   --no-config     Skip clawdbot.json updates
#   --uninstall     Remove installed skills
#   --list          List available skills and exit
#   --help          Show this help
# ══════════════════════════════════════════════════════════════════════════════

set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

REPO_URL="https://github.com/Dicklesworthstone/agent_flywheel_clawdbot_skills_and_integrations"
REPO_RAW="https://raw.githubusercontent.com/Dicklesworthstone/agent_flywheel_clawdbot_skills_and_integrations/main"
REPO_NAME="agent_flywheel_clawdbot_skills_and_integrations"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/clawdbot-skills"
VERSION="1.0.0"

# Skills catalog with descriptions
declare -A SKILL_DESCRIPTIONS=(
    ["ntm"]="Named Tmux Manager - orchestrate AI agents in tmux"
    ["agent-mail"]="MCP Agent Mail - coordination layer with mailboxes"
    ["bv"]="Beads Viewer - TUI for task management"
    ["cass"]="Coding Agent Session Search - unified history"
    ["cm"]="CASS Memory System - procedural memory"
    ["slb"]="Simultaneous Launch Button - two-person rule"
    ["gcloud"]="Google Cloud Platform CLI"
    ["wrangler"]="Cloudflare Workers, KV, R2, D1"
    ["vercel"]="Vercel deployments and domains"
    ["supabase"]="Supabase DB, migrations, Edge Functions"
    ["github"]="GitHub CLI - repos, issues, PRs"
    ["ssh"]="SSH patterns, tunnels, keys"
    ["cursor"]="Cursor AI editor CLI"
    ["ghostty"]="Ghostty terminal emulator"
    ["wezterm"]="WezTerm terminal multiplexer"
    ["claude-chrome"]="Claude in Chrome - browser automation"
    ["giil"]="Get Image from Internet Link - cloud photos"
    ["csctf"]="Chat Shared Conversation To File - exports"
)

# Skill categories for organized display
declare -A SKILL_CATEGORIES=(
    ["ntm"]="Agentic Coding"
    ["agent-mail"]="Agentic Coding"
    ["bv"]="Agentic Coding"
    ["cass"]="Agentic Coding"
    ["cm"]="Agentic Coding"
    ["slb"]="Agentic Coding"
    ["gcloud"]="Cloud & Infrastructure"
    ["wrangler"]="Cloud & Infrastructure"
    ["vercel"]="Cloud & Infrastructure"
    ["supabase"]="Cloud & Infrastructure"
    ["github"]="Development Tools"
    ["ssh"]="Development Tools"
    ["cursor"]="Development Tools"
    ["ghostty"]="Development Tools"
    ["wezterm"]="Development Tools"
    ["claude-chrome"]="Browser Automation"
    ["giil"]="Media & Image"
    ["csctf"]="Documentation & Export"
)

# ─────────────────────────────────────────────────────────────────────────────
# Colors and Styling
# ─────────────────────────────────────────────────────────────────────────────

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    ITALIC='\033[3m'
    RESET='\033[0m'
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    MAGENTA='\033[0;35m'
    CYAN='\033[0;36m'
    WHITE='\033[0;37m'
    # Catppuccin-inspired
    MAUVE='\033[38;5;183m'
    PEACH='\033[38;5;209m'
    TEAL='\033[38;5;109m'
    LAVENDER='\033[38;5;183m'
    SURFACE='\033[38;5;238m'
else
    BOLD='' DIM='' ITALIC='' RESET=''
    RED='' GREEN='' YELLOW='' BLUE='' MAGENTA='' CYAN='' WHITE=''
    MAUVE='' PEACH='' TEAL='' LAVENDER='' SURFACE=''
fi

# ─────────────────────────────────────────────────────────────────────────────
# Utility Functions
# ─────────────────────────────────────────────────────────────────────────────

print_banner() {
    echo ""
    echo -e "${MAUVE}╔══════════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${MAUVE}║${RESET}  ${BOLD}${PEACH}Agent Flywheel Clawdbot Skills${RESET}                                  ${MAUVE}║${RESET}"
    echo -e "${MAUVE}║${RESET}  ${DIM}Professional agentic coding workflow tools${RESET}                      ${MAUVE}║${RESET}"
    echo -e "${MAUVE}╚══════════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
}

log_info() {
    echo -e "${BLUE}ℹ${RESET}  $1"
}

log_success() {
    echo -e "${GREEN}✓${RESET}  $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${RESET}  $1"
}

log_error() {
    echo -e "${RED}✗${RESET}  $1" >&2
}

log_step() {
    echo -e "${CYAN}→${RESET}  $1"
}

has_command() {
    command -v "$1" &>/dev/null
}

# ─────────────────────────────────────────────────────────────────────────────
# Dependency Detection
# ─────────────────────────────────────────────────────────────────────────────

HAS_GUM=false
HAS_GIT=false
HAS_CURL=false

detect_dependencies() {
    has_command gum && HAS_GUM=true
    has_command git && HAS_GIT=true
    has_command curl && HAS_CURL=true
}

# ─────────────────────────────────────────────────────────────────────────────
# Skills Directory Detection
# ─────────────────────────────────────────────────────────────────────────────

detect_skills_dir() {
    local custom_dest="${1:-}"

    if [[ -n "$custom_dest" ]]; then
        echo "$custom_dest"
        return
    fi

    # Check common locations
    if [[ -d "$HOME/clawd/skills" ]]; then
        echo "$HOME/clawd/skills"
    elif [[ -d "$HOME/.clawdbot/skills" ]]; then
        echo "$HOME/.clawdbot/skills"
    else
        # Default to ~/.clawdbot/skills
        echo "$HOME/.clawdbot/skills"
    fi
}

detect_config_file() {
    # Check for config symlink or file
    if [[ -f "$HOME/.clawdbot/clawdbot.json" ]]; then
        echo "$HOME/.clawdbot/clawdbot.json"
    elif [[ -f "$HOME/clawd/config/clawdbot.json" ]]; then
        echo "$HOME/clawd/config/clawdbot.json"
    else
        echo ""
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Download Skills Repository
# ─────────────────────────────────────────────────────────────────────────────

download_skills() {
    local target_dir="$CACHE_DIR/repo"

    mkdir -p "$CACHE_DIR"

    if [[ -d "$target_dir/.git" ]]; then
        log_step "Updating skills repository..."
        cd "$target_dir"
        git pull --quiet 2>/dev/null || {
            log_warn "Git pull failed, re-cloning..."
            cd ..
            rm -rf "$target_dir"
            git clone --quiet --depth 1 "$REPO_URL" "$target_dir"
        }
    elif $HAS_GIT; then
        log_step "Cloning skills repository..."
        rm -rf "$target_dir"
        git clone --quiet --depth 1 "$REPO_URL" "$target_dir"
    else
        log_step "Downloading skills (no git, using curl)..."
        rm -rf "$target_dir"
        mkdir -p "$target_dir"

        # Download and extract tarball
        local tarball="$CACHE_DIR/skills.tar.gz"
        curl -fsSL "${REPO_URL}/archive/refs/heads/main.tar.gz" -o "$tarball"
        tar -xzf "$tarball" -C "$target_dir" --strip-components=1
        rm -f "$tarball"
    fi

    echo "$target_dir"
}

# ─────────────────────────────────────────────────────────────────────────────
# Get Available Skills
# ─────────────────────────────────────────────────────────────────────────────

get_available_skills() {
    local repo_dir="$1"
    local skills_dir="$repo_dir/skills"

    if [[ ! -d "$skills_dir" ]]; then
        log_error "Skills directory not found: $skills_dir"
        exit 1
    fi

    for skill_dir in "$skills_dir"/*/; do
        if [[ -f "$skill_dir/SKILL.md" ]]; then
            basename "$skill_dir"
        fi
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Interactive Skill Selection (with gum)
# ─────────────────────────────────────────────────────────────────────────────

select_skills_gum() {
    local -a skills=("$@")

    # Print instructions to stderr so they're visible but not captured
    echo -e "${BOLD}Select skills to install:${RESET}" >&2
    echo -e "${DIM}(Space to select, Enter to confirm)${RESET}" >&2
    echo "" >&2

    # Use gum choose with multi-select - output goes to stdout for capture
    printf '%s\n' "${skills[@]}" | gum choose --no-limit --height=20 \
        --header="Select skills (space to toggle, enter to confirm)" \
        --cursor.foreground="212" \
        --selected.foreground="212" \
        --item.foreground="255" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
# Interactive Skill Selection (fallback bash menu)
# ─────────────────────────────────────────────────────────────────────────────

select_skills_bash() {
    local -a skills=("$@")
    local -a selected=()
    local -A is_selected=()

    # Group skills by category
    local -a categories=("Agentic Coding" "Cloud & Infrastructure" "Browser Automation" "Media & Image" "Documentation & Export" "Development Tools")

    # Print menu to stderr so it's visible but not captured
    echo "" >&2
    echo -e "${BOLD}Available Skills:${RESET}" >&2
    echo -e "${DIM}────────────────────────────────────────────────────────────────────${RESET}" >&2

    local idx=1
    local -A skill_index=()

    for category in "${categories[@]}"; do
        local has_skills=false
        for skill in "${skills[@]}"; do
            if [[ "${SKILL_CATEGORIES[$skill]:-Other}" == "$category" ]]; then
                has_skills=true
                break
            fi
        done

        if $has_skills; then
            echo "" >&2
            echo -e "${PEACH}${BOLD}$category${RESET}" >&2

            for skill in "${skills[@]}"; do
                if [[ "${SKILL_CATEGORIES[$skill]:-Other}" == "$category" ]]; then
                    local desc="${SKILL_DESCRIPTIONS[$skill]:-No description}"
                    printf "  ${CYAN}%2d${RESET}) ${BOLD}%-15s${RESET} ${DIM}%s${RESET}\n" "$idx" "$skill" "$desc" >&2
                    skill_index[$idx]="$skill"
                    idx=$((idx + 1))
                fi
            done
        fi
    done

    echo "" >&2
    echo -e "${DIM}────────────────────────────────────────────────────────────────────${RESET}" >&2
    echo "" >&2
    echo -e "${BOLD}Enter skill numbers to install (space or comma separated):${RESET}" >&2
    echo -e "${DIM}Examples: 1 2 3   or   1,2,3   or   1-5   or   all${RESET}" >&2
    echo "" >&2

    # Read from /dev/tty to ensure we get user input even when stdout is redirected
    read -rp "Selection: " selection </dev/tty

    # Parse selection
    if [[ "$selection" == "all" ]] || [[ "$selection" == "a" ]]; then
        printf '%s\n' "${skills[@]}"
        return
    fi

    # Replace commas with spaces, handle ranges
    selection="${selection//,/ }"

    local -a parsed=()
    for token in $selection; do
        if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
            # Range: 1-5
            local start="${BASH_REMATCH[1]}"
            local end="${BASH_REMATCH[2]}"
            for ((i=start; i<=end; i++)); do
                parsed+=("$i")
            done
        elif [[ "$token" =~ ^[0-9]+$ ]]; then
            parsed+=("$token")
        fi
    done

    for num in "${parsed[@]}"; do
        if [[ -n "${skill_index[$num]:-}" ]]; then
            echo "${skill_index[$num]}"
        fi
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Install Skills
# ─────────────────────────────────────────────────────────────────────────────

install_skills() {
    local repo_dir="$1"
    local skills_dst="$2"
    shift 2
    local -a skills_to_install=("$@")

    local skills_src="$repo_dir/skills"
    local installed=0
    local skipped=0

    mkdir -p "$skills_dst"

    echo ""
    log_step "Installing ${#skills_to_install[@]} skill(s) to $skills_dst"
    echo ""

    for skill in "${skills_to_install[@]}"; do
        local src="$skills_src/$skill"
        local dst="$skills_dst/$skill"

        if [[ ! -d "$src" ]]; then
            log_warn "Skill not found: $skill"
            continue
        fi

        if [[ -L "$dst" ]]; then
            echo -e "  ${DIM}[skip]${RESET} $skill ${DIM}(already linked)${RESET}"
            skipped=$((skipped + 1))
        elif [[ -d "$dst" ]]; then
            echo -e "  ${DIM}[skip]${RESET} $skill ${DIM}(directory exists)${RESET}"
            skipped=$((skipped + 1))
        else
            # Copy instead of symlink for curl-pipe installs
            cp -r "$src" "$dst"
            echo -e "  ${GREEN}[install]${RESET} ${BOLD}$skill${RESET}"
            installed=$((installed + 1))
        fi
    done

    echo ""
    if [[ $installed -gt 0 ]]; then
        log_success "Installed $installed skill(s)"
    fi
    if [[ $skipped -gt 0 ]]; then
        log_info "Skipped $skipped skill(s) (already installed)"
    fi

    # Return count via global variable to avoid stdout capture issues
    INSTALLED_COUNT=$installed
}

# ─────────────────────────────────────────────────────────────────────────────
# Generate Config Snippet
# ─────────────────────────────────────────────────────────────────────────────

generate_config_snippet() {
    local -a skills=("$@")

    echo ""
    echo -e "${BOLD}Add to your clawdbot.json skills.entries:${RESET}"
    echo ""
    echo -e "${DIM}\"skills\": {${RESET}"
    echo -e "${DIM}  \"entries\": {${RESET}"

    for skill in "${skills[@]}"; do
        echo -e "    ${CYAN}\"$skill\"${RESET}: { \"enabled\": true },"
    done

    echo -e "${DIM}  }${RESET}"
    echo -e "${DIM}}${RESET}"
}

# ─────────────────────────────────────────────────────────────────────────────
# Uninstall Skills
# ─────────────────────────────────────────────────────────────────────────────

uninstall_skills() {
    local skills_dst="$1"

    if [[ ! -d "$skills_dst" ]]; then
        log_error "Skills directory not found: $skills_dst"
        exit 1
    fi

    local removed=0

    for skill in "${!SKILL_DESCRIPTIONS[@]}"; do
        local target="$skills_dst/$skill"
        if [[ -d "$target" ]] || [[ -L "$target" ]]; then
            rm -rf "$target"
            echo -e "  ${RED}[remove]${RESET} $skill"
            removed=$((removed + 1))
        fi
    done

    if [[ $removed -gt 0 ]]; then
        log_success "Removed $removed skill(s)"
    else
        log_info "No Agent Flywheel skills found to remove"
    fi

    # Clean cache
    rm -rf "$CACHE_DIR"
    log_info "Cleaned cache directory"
}

# ─────────────────────────────────────────────────────────────────────────────
# List Skills
# ─────────────────────────────────────────────────────────────────────────────

list_skills() {
    print_banner

    local -a categories=("Agentic Coding" "Cloud & Infrastructure" "Browser Automation" "Media & Image" "Documentation & Export" "Development Tools")

    for category in "${categories[@]}"; do
        local has_skills=false
        for skill in "${!SKILL_CATEGORIES[@]}"; do
            if [[ "${SKILL_CATEGORIES[$skill]}" == "$category" ]]; then
                has_skills=true
                break
            fi
        done

        if $has_skills; then
            echo -e "${PEACH}${BOLD}$category${RESET}"
            echo -e "${DIM}$(printf '─%.0s' {1..60})${RESET}"

            for skill in "${!SKILL_CATEGORIES[@]}"; do
                if [[ "${SKILL_CATEGORIES[$skill]}" == "$category" ]]; then
                    local desc="${SKILL_DESCRIPTIONS[$skill]:-No description}"
                    printf "  ${CYAN}%-15s${RESET} %s\n" "$skill" "$desc"
                fi
            done
            echo ""
        fi
    done
}

# ─────────────────────────────────────────────────────────────────────────────
# Show Help
# ─────────────────────────────────────────────────────────────────────────────

show_help() {
    cat << 'EOF'
Agent Flywheel Clawdbot Skills Installer

USAGE:
    curl -fsSL "https://raw.githubusercontent.com/Dicklesworthstone/agent_flywheel_clawdbot_skills_and_integrations/main/install.sh?v=$(date +%s)" | bash
    curl -fsSL "...install.sh?v=$(date +%s)" | bash -s -- --all
    curl -fsSL "...install.sh?v=$(date +%s)" | bash -s -- --list

OPTIONS:
    --all           Install all skills without prompting
    --dest DIR      Custom skills installation directory
    --no-config     Skip showing clawdbot.json config snippet
    --uninstall     Remove all Agent Flywheel skills
    --list          List available skills and exit
    --help          Show this help message

EXAMPLES:
    # Interactive mode (pick skills from menu)
    curl -fsSL "...install.sh?v=$(date +%s)" | bash

    # Install all skills
    curl -fsSL "...install.sh?v=$(date +%s)" | bash -s -- --all

    # Install to custom directory
    curl -fsSL "...install.sh?v=$(date +%s)" | bash -s -- --dest ~/my-skills

    # List available skills
    curl -fsSL "...install.sh?v=$(date +%s)" | bash -s -- --list

SKILLS INCLUDED:
    Agentic Coding:     ntm, agent-mail, bv, cass, cm, slb
    Cloud:              gcloud, wrangler, vercel, supabase
    Browser:            claude-chrome
    Media:              giil
    Export:             csctf
    Dev Tools:          github, ssh, cursor, ghostty, wezterm

MORE INFO:
    https://github.com/Dicklesworthstone/agent_flywheel_clawdbot_skills_and_integrations

EOF
}

# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────

main() {
    local install_all=false
    local custom_dest=""
    local show_config=true
    local do_uninstall=false
    local do_list=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --all|-a)
                install_all=true
                shift
                ;;
            --dest|-d)
                custom_dest="$2"
                shift 2
                ;;
            --no-config)
                show_config=false
                shift
                ;;
            --uninstall)
                do_uninstall=true
                shift
                ;;
            --list|-l)
                do_list=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Detect dependencies
    detect_dependencies

    # Handle --list
    if $do_list; then
        list_skills
        exit 0
    fi

    # Detect skills directory
    local skills_dst
    skills_dst=$(detect_skills_dir "$custom_dest")

    # Handle --uninstall
    if $do_uninstall; then
        print_banner
        log_step "Uninstalling Agent Flywheel skills from $skills_dst"
        uninstall_skills "$skills_dst"
        exit 0
    fi

    # Show banner
    print_banner

    # Check for curl or git
    if ! $HAS_CURL && ! $HAS_GIT; then
        log_error "Either curl or git is required"
        exit 1
    fi

    # Download/update skills repository
    local repo_dir
    repo_dir=$(download_skills)
    log_success "Skills repository ready"

    # Get available skills
    local -a available_skills
    mapfile -t available_skills < <(get_available_skills "$repo_dir")

    if [[ ${#available_skills[@]} -eq 0 ]]; then
        log_error "No skills found in repository"
        exit 1
    fi

    log_info "Found ${#available_skills[@]} available skills"

    # Select skills to install
    local -a selected_skills

    if $install_all; then
        selected_skills=("${available_skills[@]}")
        log_info "Installing all skills (--all flag)"
    elif $HAS_GUM && [[ -t 0 ]]; then
        # Interactive selection with gum
        mapfile -t selected_skills < <(select_skills_gum "${available_skills[@]}")
    elif [[ -t 0 ]]; then
        # Interactive selection with bash
        mapfile -t selected_skills < <(select_skills_bash "${available_skills[@]}")
    else
        # Non-interactive, no --all flag
        log_error "Non-interactive mode requires --all flag"
        echo "Use: curl ... | bash -s -- --all"
        exit 1
    fi

    # Check if any skills selected
    if [[ ${#selected_skills[@]} -eq 0 ]]; then
        log_warn "No skills selected"
        exit 0
    fi

    # Install selected skills
    INSTALLED_COUNT=0
    install_skills "$repo_dir" "$skills_dst" "${selected_skills[@]}"

    # Show config snippet
    if $show_config && [[ $INSTALLED_COUNT -gt 0 ]]; then
        generate_config_snippet "${selected_skills[@]}"
    fi

    # Final message
    echo ""
    echo -e "${DIM}────────────────────────────────────────────────────────────────────${RESET}"
    echo ""
    log_success "Installation complete!"
    echo ""
    echo -e "  ${DIM}Skills installed to:${RESET} ${BOLD}$skills_dst${RESET}"
    echo ""
    echo -e "  ${DIM}Next steps:${RESET}"
    echo -e "    1. Add skills to your ${CYAN}clawdbot.json${RESET} (see config above)"
    echo -e "    2. Restart your Clawdbot gateway"
    echo ""
    echo -e "  ${DIM}More info:${RESET} ${BLUE}$REPO_URL${RESET}"
    echo ""
}

# Run main
main "$@"
