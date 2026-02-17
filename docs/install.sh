#!/bin/sh

# Claude Code Skills Installer
# https://github.com/mhbxyz/skills

set -eu

# ── Constants ──

RESET="\033[0m"
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"

REPO_OWNER="mhbxyz"
REPO_NAME="skills"
BRANCH="main"
SKILLS_SUBDIR="src"
TARBALL_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/archive/refs/heads/${BRANCH}.tar.gz"
TREE_API_URL="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/git/trees/${BRANCH}?recursive=1"
RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}"

# ── Temp file cleanup ──

TMPFILES=""

cleanup() {
  for _f in $TMPFILES; do
    rm -rf "$_f"
  done
}

trap cleanup EXIT INT TERM

register_tmp() {
  TMPFILES="$TMPFILES $1"
}

# ── Utility functions ──

die() {
  printf "${RED}error: %s${RESET}\n" "$*" >&2
  exit 1
}

warn() {
  printf "${YELLOW}warning: %s${RESET}\n" "$*" >&2
}

info() {
  printf "${BLUE}%s${RESET}\n" "$*"
}

success() {
  printf "${GREEN}%s${RESET}\n" "$*"
}

# ── Helpers ──

download_file() {
  _url="$1" _dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$_url" -o "$_dest" || die "failed to download $_url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$_dest" "$_url" || die "failed to download $_url"
  else
    die "curl or wget is required"
  fi
}

download_to_stdout() {
  _url="$1"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$_url" || die "failed to download $_url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO- "$_url" || die "failed to download $_url"
  else
    die "curl or wget is required"
  fi
}

extract_description() {
  sed -n '/^description:/{
    s/^description: *>* *//
    /./p
    :loop
    n
    /^  /!q
    s/^  *//
    p
    b loop
  }' | tr '\n' ' ' | sed 's/  */ /g;s/^ *//;s/ *$//'
}

truncate_text() {
  _max="${1:-60}"
  read -r _text || true
  if [ "${#_text}" -gt "$_max" ]; then
    printf '%s...' "$(printf '%.'"$_max"'s' "$_text")"
  else
    printf '%s' "$_text"
  fi
}

# ── Help ──

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
  install.sh                                 # interactive mode (recommended)
  install.sh elite-coder                     # install directly by name
  install.sh -g elite-coder                  # install globally
  install.sh -l                              # list available skills
  install.sh -u elite-coder                  # uninstall
  install.sh elite-coder other-skill         # install multiple skills

  # One-liner (no clone needed):
  curl -fsSL mhbxyz.github.io/skills/install.sh | sh -s -- elite-coder
  curl -fsSL mhbxyz.github.io/skills/install.sh | sh -s -- -g elite-coder
EOF
}

# ── Detection ──

is_local_repo() {
  [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/.git" ] && [ -f "$SCRIPT_DIR/install.sh" ]
}

detect_skills_local() {
  for _dir in "$SCRIPT_DIR/$SKILLS_SUBDIR"/*/; do
    if [ -f "${_dir}SKILL.md" ]; then
      basename "$_dir"
    fi
  done
}

detect_skills_remote() {
  _json=$(download_to_stdout "$TREE_API_URL")
  printf '%s\n' "$_json" \
    | grep -o "\"path\": *\"${SKILLS_SUBDIR}/[^\"/]*/SKILL\.md\"" \
    | sed "s/\"path\": *\"${SKILLS_SUBDIR}\///;s/\/SKILL\.md\"//"
}

get_skill_description() {
  _skill="$1"
  if is_local_repo; then
    extract_description < "$SCRIPT_DIR/$SKILLS_SUBDIR/$_skill/SKILL.md"
  else
    _raw=$(download_to_stdout "$RAW_URL/$SKILLS_SUBDIR/$_skill/SKILL.md" 2>/dev/null) || true
    printf '%s\n' "$_raw" | extract_description
  fi
}

list_skills() {
  if is_local_repo; then
    _skills=$(detect_skills_local)
  else
    _skills=$(detect_skills_remote)
  fi
  [ -z "$_skills" ] && die "no skills found"
  info "Available skills:"
  for _s in $_skills; do
    _desc=$(get_skill_description "$_s" | truncate_text 60)
    if [ -n "$_desc" ]; then
      printf '  %-16s %s\n' "$_s" "$_desc"
    else
      printf '  %s\n' "$_s"
    fi
  done
}

# ── Resolve and validate ──

resolve_target_dir() {
  if [ "$GLOBAL" = 1 ]; then
    printf '%s' "$HOME/.claude/skills"
  else
    printf '%s' ".claude/skills"
  fi
}

validate_skill() {
  _vskill="$1"
  if is_local_repo; then
    _vavailable=$(detect_skills_local)
  else
    _vavailable=$(detect_skills_remote)
  fi
  if ! printf '%s\n' "$_vavailable" | grep -qx "$_vskill"; then
    die "skill '$_vskill' not found (use --list to see available skills)"
  fi
}

# ── Install ──

install_skill_local() {
  _skill="$1"
  _target="$2"
  _dest="$_target/$_skill"
  rm -rf "$_dest"
  mkdir -p "$_target"
  cp -r "$SCRIPT_DIR/$SKILLS_SUBDIR/$_skill" "$_dest"
  success "installed $_skill -> $_dest"
}

install_skill_remote() {
  _skill="$1"
  _target="$2"
  _tmpdir=$(mktemp -d)
  register_tmp "$_tmpdir"

  download_file "$TARBALL_URL" "$_tmpdir/archive.tar.gz"

  _prefix="${REPO_NAME}-${BRANCH}"
  tar -xzf "$_tmpdir/archive.tar.gz" -C "$_tmpdir" "${_prefix}/${SKILLS_SUBDIR}/${_skill}/" 2>/dev/null \
    || die "skill '$_skill' not found in archive"

  _dest="$_target/$_skill"
  rm -rf "$_dest"
  mkdir -p "$_target"
  cp -r "$_tmpdir/${_prefix}/${SKILLS_SUBDIR}/${_skill}" "$_dest"

  success "installed $_skill -> $_dest"
}

install_skill() {
  _skill="$1"
  _target=$(resolve_target_dir)

  validate_skill "$_skill"

  if is_local_repo; then
    install_skill_local "$_skill" "$_target"
  else
    install_skill_remote "$_skill" "$_target"
  fi
}

# ── Uninstall ──

uninstall_skill() {
  _skill="$1"
  _target=$(resolve_target_dir)
  _dest="$_target/$_skill"

  if [ ! -d "$_dest" ]; then
    die "skill '$_skill' is not installed in $_target"
  fi

  rm -rf "$_dest"
  success "uninstalled $_skill from $_dest"
}

# ── Menu ──

random_phrase() {
  _phrases="YELLOW|There is no secret. Move along.
CYAN|Mitochondria is the powerhouse of the cell.
GREEN|A monad is just a monoid in the category of endofunctors.
MAGENTA|There are only two hard things: cache invalidation, naming things, and off-by-one errors.
BLUE|It works on my machine.
RED|Have you tried turning it off and on again?
YELLOW|The cake is a lie.
CYAN|127.0.0.1 is where the heart is.
GREEN|To mass-assign or not to mass-assign, that is the CVE.
MAGENTA|In case of fire: git commit, git push, leave building."
  _count=10
  _pick=$(( $(od -An -tu4 -N4 /dev/urandom) % _count + 1 ))
  _line=$(printf '%s\n' "$_phrases" | sed -n "${_pick}p")
  _color_name="${_line%%|*}"
  _text="${_line#*|}"
  eval "_color=\$$_color_name"
  printf "  ${_color}%s${RESET}" "$_text"
}

show_menu() {
  if [ ! -t 0 ] && [ ! -e /dev/tty ]; then
    die "no skill specified (use --list to see available skills)"
  fi

  if is_local_repo; then
    _skills=$(detect_skills_local)
  else
    _skills=$(detect_skills_remote)
  fi
  [ -z "$_skills" ] && die "no skills found"

  info "Available skills:" >/dev/tty
  printf "\n" >/dev/tty

  _i=0
  _skill_list=""
  for _s in $_skills; do
    _i=$((_i + 1))
    _skill_list="$_skill_list $_s"
    _desc=$(get_skill_description "$_s" | truncate_text 50)
    if [ -n "$_desc" ]; then
      printf '  %d) %-16s %s\n' "$_i" "$_s" "$_desc" >/dev/tty
    else
      printf '  %d) %s\n' "$_i" "$_s" >/dev/tty
    fi
  done
  _skill_list="${_skill_list# }"
  _count="$_i"

  printf "\n" >/dev/tty
  printf "  a) All skills\n" >/dev/tty
  printf "  q) Quit\n" >/dev/tty
  printf "\n$(random_phrase)\n" >/dev/tty
  printf "\nSelect skills to install (e.g. 1 3 or a or q): " >/dev/tty
  read -r _choice </dev/tty

  if [ "$_choice" = "q" ] || [ "$_choice" = "Q" ]; then
    return 1
  fi

  if [ "$_choice" = "a" ] || [ "$_choice" = "A" ]; then
    printf '%s' "$_skill_list"
    return
  fi

  _selected=""
  for _num in $_choice; do
    case "$_num" in
      *[!0-9]*) die "invalid selection: $_num" ;;
    esac
    if [ "$_num" -lt 1 ] || [ "$_num" -gt "$_count" ]; then
      die "selection out of range: $_num (1-$_count)"
    fi
    _i=0
    for _s in $_skill_list; do
      _i=$((_i + 1))
      if [ "$_i" -eq "$_num" ]; then
        _selected="$_selected $_s"
        break
      fi
    done
  done
  printf '%s' "$_selected" | sed 's/^ //'
}

# ── Commands ──

cmd_install() {
  if [ -z "$SKILLS" ]; then
    _names=$(show_menu) || exit 0
    [ -z "$_names" ] && die "no selection made"
    for _skill in $_names; do
      install_skill "$_skill"
    done
  else
    for _skill in $SKILLS; do
      install_skill "$_skill"
    done
  fi
}

cmd_list() {
  list_skills
}

cmd_uninstall() {
  if [ -z "$SKILLS" ]; then
    die "no skill specified"
  fi
  for _skill in $SKILLS; do
    uninstall_skill "$_skill"
  done
}

# ── Main dispatch ──

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

SKILLS="${SKILLS# }"

case "$ACTION" in
  list)      cmd_list ;;
  install)   cmd_install ;;
  uninstall) cmd_uninstall ;;
esac
