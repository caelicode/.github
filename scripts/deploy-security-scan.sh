#!/usr/bin/env bash
# deploy-security-scan.sh — Roll out security scanning to all CaeliCode repos
#
# Adds a thin caller workflow to each repo that invokes the reusable
# security scan from caelicode/.github. Detects the repo's primary
# language and configures CodeQL accordingly.
#
# Prerequisites:
#   - gh CLI authenticated with repo + workflow scopes
#   - jq installed
#
# Usage:
#   ./scripts/deploy-security-scan.sh              # all non-archived repos
#   ./scripts/deploy-security-scan.sh wsl           # single repo
#   ./scripts/deploy-security-scan.sh --dry-run     # preview without pushing

set -euo pipefail

ORG="caelicode"
BRANCH="add-security-scan"
DRY_RUN=false
SINGLE_REPO=""

# Parse args
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    *) SINGLE_REPO="$arg" ;;
  esac
done

# ── Language → CodeQL mapping ────────────────────────────────────
get_codeql_languages() {
  local lang="$1"
  case "$lang" in
    Python)                     echo '["python"]' ;;
    JavaScript|TypeScript)      echo '["javascript-typescript"]' ;;
    Go)                         echo '["go"]' ;;
    Java|Kotlin)                echo '["java-kotlin"]' ;;
    Ruby)                       echo '["ruby"]' ;;
    "C#")                       echo '["csharp"]' ;;
    C|C++)                      echo '["c-cpp"]' ;;
    Swift)                      echo '["swift"]' ;;
    Shell|HTML|Dockerfile|HCL)  echo '[]' ;;   # no CodeQL support
    *)                          echo '["auto"]' ;;
  esac
}

# ── Generate caller workflow YAML ────────────────────────────────
generate_caller() {
  local repo="$1"
  local languages="$2"
  local enable_codeql="true"

  if [ "$languages" = '[]' ]; then
    enable_codeql="false"
  fi

  cat <<YAML
# Security scanning — auto-deployed by CaeliCode org security policy.
# Calls the reusable workflow from caelicode/.github.
# Do not edit manually; changes will be overwritten on next deployment.

name: Security Scan

on:
  pull_request:
    branches: [main, master]
  push:
    branches: [main, master]
  schedule:
    - cron: '25 4 * * 1'  # Weekly Monday 04:25 UTC

permissions:
  actions: read
  contents: read
  security-events: write
  pull-requests: write

jobs:
  security:
    uses: caelicode/.github/.github/workflows/reusable-security-scan.yml@main
    with:
      languages: '${languages}'
      enable-codeql: ${enable_codeql}
    permissions:
      actions: read
      contents: read
      security-events: write
      pull-requests: write
YAML
}

# ── Deploy to a single repo ─────────────────────────────────────
deploy_to_repo() {
  local repo="$1"
  local lang="$2"
  local languages
  languages=$(get_codeql_languages "$lang")

  echo ""
  echo "── $repo (lang: $lang, codeql: $languages)"

  if $DRY_RUN; then
    echo "   [dry-run] Would create .github/workflows/security.yml"
    generate_caller "$repo" "$languages" | head -5
    echo "   ..."
    return
  fi

  # Create temp dir for the work
  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf $tmpdir" RETURN

  # Clone (shallow)
  if ! gh repo clone "$ORG/$repo" "$tmpdir/$repo" -- --depth 1 -q 2>/dev/null; then
    echo "   [skip] Failed to clone $repo"
    return
  fi

  cd "$tmpdir/$repo"
  git config user.name "bertrandmbanwi"
  git config user.email "bertrandmbanwi@gmail.com"

  # Check if security.yml already exists on main
  if [ -f ".github/workflows/security.yml" ]; then
    echo "   [skip] security.yml already exists"
    cd - > /dev/null
    return
  fi

  # Detect default branch
  local default_branch
  default_branch=$(git rev-parse --abbrev-ref HEAD)

  # Create workflow dir if needed
  mkdir -p .github/workflows

  # Generate and write the caller
  generate_caller "$repo" "$languages" > .github/workflows/security.yml

  # Commit directly to default branch
  git add .github/workflows/security.yml
  git commit -q -m "ci: add org-wide security scanning

Adds CodeQL SAST, Semgrep, dependency review, and Gitleaks
secret detection via the shared reusable workflow in
caelicode/.github. Runs on every PR and weekly on schedule."

  git push -q origin "$default_branch"
  echo "   [done] Pushed security.yml to $default_branch"
  cd - > /dev/null
}

# ── Main ─────────────────────────────────────────────────────────
echo "CaeliCode Security Scan Deployment"
echo "==================================="

if $DRY_RUN; then
  echo "Mode: DRY RUN (no changes will be made)"
fi

if [ -n "$SINGLE_REPO" ]; then
  # Single repo mode
  lang=$(gh api "repos/$ORG/$SINGLE_REPO" --jq '.language // "none"')
  deploy_to_repo "$SINGLE_REPO" "$lang"
else
  # All repos mode — skip .github itself and archived repos
  repos=$(gh api "orgs/$ORG/repos?per_page=100&type=all" \
    --jq '.[] | select(.archived == false) | select(.name != ".github") | "\(.name)\t\(.language // "none")"')

  while IFS=$'\t' read -r name lang; do
    deploy_to_repo "$name" "$lang"
  done <<< "$repos"
fi

echo ""
echo "==================================="
echo "Deployment complete."
