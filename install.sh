#!/bin/sh
set -e

# =============================================================================
# Claude Code Skills Installer
# https://github.com/mhbxyz/skills
# =============================================================================

REPO_OWNER="mhbxyz"
REPO_NAME="skills"
BRANCH="main"
TARBALL_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${BRANCH}.tar.gz"
TREE_API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/trees/${BRANCH}?recursive=1"

# -- Utilities ----------------------------------------------------------------

msg() {
    printf '%s\n' "$1"
}

die() {
    printf 'error: %s\n' "$1" >&2
    exit 1
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

fetch_url() {
    local url="$1"
    local dest="$2" # empty = stdout
    if has_cmd curl; then
        if [ -n "$dest" ]; then
            curl -fsSL -o "$dest" "$url" || die "failed to download $url"
        else
            curl -fsSL "$url" || die "failed to download $url"
        fi
    elif has_cmd wget; then
        if [ -n "$dest" ]; then
            wget -qO "$dest" "$url" || die "failed to download $url"
        else
            wget -qO- "$url" || die "failed to download $url"
        fi
    else
        die "curl or wget is required"
    fi
}

# -- Usage --------------------------------------------------------------------

usage() {
    cat <<'EOF'
Usage: install.sh [OPTIONS] [SKILL...]

Install Claude Code skills from github.com/mhbxyz/skills.

Options:
  -g, --global       Install to ~/.claude/skills/ (default: ./.claude/skills/)
  -l, --list         List available skills
  -u, --uninstall    Uninstall specified skill(s)
  -h, --help         Show this help

Examples:
  install.sh elite-coder                     # install locally
  install.sh -g elite-coder                  # install globally
  install.sh -l                              # list available skills
  install.sh -u elite-coder                  # uninstall
  install.sh elite-coder other-skill         # install multiple skills

  # One-liner (no clone needed):
  curl -fsSL https://raw.githubusercontent.com/mhbxyz/skills/main/install.sh | sh -s -- elite-coder
  curl -fsSL https://raw.githubusercontent.com/mhbxyz/skills/main/install.sh | sh -s -- -g elite-coder
EOF
}

# -- Detection ----------------------------------------------------------------

is_local_repo() {
    [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/.git" ] && [ -f "$SCRIPT_DIR/install.sh" ]
}

detect_skills_local() {
    local dir
    for dir in "$SCRIPT_DIR"/*/; do
        [ -f "${dir}SKILL.md" ] && basename "$dir"
    done
}

detect_skills_remote() {
    local json
    json=$(fetch_url "$TREE_API_URL") || die "failed to fetch skill list from GitHub"
    printf '%s\n' "$json" \
        | grep -o '"path":"[^"]*SKILL\.md"' \
        | sed 's/"path":"//;s/\/SKILL\.md"//' \
        | grep -v '/'
}

list_skills() {
    local skills
    if is_local_repo; then
        skills=$(detect_skills_local)
    else
        skills=$(detect_skills_remote)
    fi
    if [ -z "$skills" ]; then
        die "no skills found"
    fi
    msg "Available skills:"
    printf '%s\n' "$skills" | while read -r s; do
        msg "  $s"
    done
}

# -- Resolve target -----------------------------------------------------------

resolve_target_dir() {
    if [ "$GLOBAL" = 1 ]; then
        printf '%s' "$HOME/.claude/skills"
    else
        printf '%s' ".claude/skills"
    fi
}

# -- Validate -----------------------------------------------------------------

validate_skill() {
    local skill="$1"
    local available
    if is_local_repo; then
        available=$(detect_skills_local)
    else
        available=$(detect_skills_remote)
    fi
    if ! printf '%s\n' "$available" | grep -qx "$skill"; then
        die "skill '$skill' not found (use --list to see available skills)"
    fi
}

# -- Install ------------------------------------------------------------------

install_skill_local() {
    local skill="$1"
    local target="$2"
    local dest="$target/$skill"
    rm -rf "$dest"
    mkdir -p "$target"
    cp -r "$SCRIPT_DIR/$skill" "$dest"
    msg "installed $skill -> $dest"
}

install_skill_remote() {
    local skill="$1"
    local target="$2"
    local dest="$target/$skill"
    local tmpdir

    tmpdir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$tmpdir'" EXIT

    fetch_url "$TARBALL_URL" "$tmpdir/archive.tar.gz"

    local prefix="${REPO_NAME}-${BRANCH}"
    tar -xzf "$tmpdir/archive.tar.gz" -C "$tmpdir" "${prefix}/${skill}/" 2>/dev/null \
        || die "skill '$skill' not found in archive"

    rm -rf "$dest"
    mkdir -p "$target"
    cp -r "$tmpdir/${prefix}/${skill}" "$dest"

    rm -rf "$tmpdir"
    trap - EXIT

    msg "installed $skill -> $dest"
}

install_skill() {
    local skill="$1"
    local target
    target=$(resolve_target_dir)

    validate_skill "$skill"

    if is_local_repo; then
        install_skill_local "$skill" "$target"
    else
        install_skill_remote "$skill" "$target"
    fi
}

# -- Uninstall ----------------------------------------------------------------

uninstall_skill() {
    local skill="$1"
    local target
    target=$(resolve_target_dir)
    local dest="$target/$skill"

    if [ ! -d "$dest" ]; then
        die "skill '$skill' is not installed in $target"
    fi

    rm -rf "$dest"
    msg "uninstalled $skill from $dest"
}

# -- Main ---------------------------------------------------------------------

# Detect script directory (empty when piped via curl)
SCRIPT_DIR=""
if [ -f "$0" ] 2>/dev/null; then
    SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
fi

GLOBAL=0
ACTION="install"
SKILLS=""

while [ $# -gt 0 ]; do
    case "$1" in
        -g|--global)
            GLOBAL=1
            shift
            ;;
        -l|--list)
            ACTION="list"
            shift
            ;;
        -u|--uninstall)
            ACTION="uninstall"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            die "unknown option: $1 (see --help)"
            ;;
        *)
            SKILLS="$SKILLS $1"
            shift
            ;;
    esac
done

# Trim leading space
SKILLS="${SKILLS# }"

case "$ACTION" in
    list)
        list_skills
        ;;
    install)
        if [ -z "$SKILLS" ]; then
            die "no skill specified (use --list to see available skills)"
        fi
        for skill in $SKILLS; do
            install_skill "$skill"
        done
        ;;
    uninstall)
        if [ -z "$SKILLS" ]; then
            die "no skill specified"
        fi
        for skill in $SKILLS; do
            uninstall_skill "$skill"
        done
        ;;
esac
