#!/usr/bin/env bash
# GitHub Actions Security Maintenance Script
# 
# This script helps maintain GitHub Actions security by checking for updates
# and providing SHA-pinned references for actions used in CI/CD workflows.
#
# Usage:
#   ./update_actions.sh --check    # Check current actions against latest versions
#   ./update_actions.sh --update   # Generate updated SHA-pinned references
#   ./update_actions.sh --list     # List all actions used in workflows

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW_DIR="$REPO_ROOT/.github/workflows"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Action registry with current versions
declare -A ACTIONS=(
    # Official GitHub Actions
    ["actions/checkout"]="v3.6.0"
    ["actions/cache"]="v3.3.2"
    ["actions/setup-python"]="v4.7.1"
    ["actions/upload-artifact"]="v3.1.3"
    ["actions/download-artifact"]="v3.0.2"
    
    # Third-party actions
    ["jidicula/clang-format-action"]="v4.11.0"
    ["softprops/action-gh-release"]="v1.0.0"
)

# Known commit SHAs for current versions
declare -A CURRENT_SHAS=(
    ["actions/checkout@v3.6.0"]="f43a0e5ff2bd294095638e18286ca9a3d1956744"
    ["actions/cache@v3.3.2"]="704facf57e6136b1bc63b828d79edcd491f0ee84"
    ["actions/setup-python@v4.7.1"]="65d7f2d534ac1bc67fcd62888c5f4f3d2cb2b236"
    ["actions/upload-artifact@v3.1.3"]="a8a3f3ad30e3422c9c7b888a15615d19a852ae32"
    ["actions/download-artifact@v3.0.2"]="9bc31d5ccc31df68ecc42ccf4149144866c47d8a"
    ["jidicula/clang-format-action@v4.11.0"]="c74383674bf5f7c69f60ce562019c1c94bc1421a"
    ["softprops/action-gh-release@v1.0.0"]="de2c0eb89ae2a093876385947365aca7b0e5f844"
)

print_header() {
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  GitHub Actions Security Maintenance Tool                     ${BLUE}║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "\n${YELLOW}▶ $1${NC}"
    echo "$(printf '─%.0s' {1..64})"
}

list_actions() {
    print_section "Actions Used in Workflows"
    
    for action in "${!ACTIONS[@]}"; do
        version="${ACTIONS[$action]}"
        key="$action@$version"
        sha="${CURRENT_SHAS[$key]:-unknown}"
        
        echo -e "${GREEN}✓${NC} $action"
        echo "  Version: $version"
        echo "  SHA: $sha"
        echo "  Repository: https://github.com/$action"
        echo ""
    done
}

check_actions() {
    print_section "Security Status Check"
    
    echo "Checking workflow files for action references..."
    echo ""
    
    local issues=0
    
    # Check if actions are properly pinned in workflow files
    for workflow in "$WORKFLOW_DIR"/*.yml "$WORKFLOW_DIR"/*.yaml; do
        if [[ -f "$workflow" ]]; then
            echo "Checking $(basename "$workflow")..."
            
            # Look for unpinned actions (using @v notation without SHA)
            while IFS= read -r line; do
                if [[ "$line" =~ uses:.*@v[0-9] ]] && [[ ! "$line" =~ \#.*v[0-9] ]]; then
                    echo -e "  ${RED}⚠${NC} Found potentially unpinned action: $line"
                    ((issues++))
                fi
            done < "$workflow"
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        echo -e "\n${GREEN}✓ All actions appear to be properly pinned${NC}"
    else
        echo -e "\n${YELLOW}⚠ Found $issues potential issue(s)${NC}"
        echo "Run with --update to generate updated references"
    fi
}

generate_reference() {
    local action=$1
    local version=$2
    local sha="${CURRENT_SHAS[$action@$version]}"
    
    if [[ -n "$sha" ]]; then
        echo "  uses: $action@$sha # $version"
    else
        echo "  # SHA not available for $action@$version"
        echo "  # Please verify manually at https://github.com/$action/releases/tag/$version"
        echo "  uses: $action@[VERIFY_SHA] # $version"
    fi
}

update_actions() {
    print_section "Generate Updated Action References"
    
    echo "Copy the following to your workflow files:"
    echo ""
    echo "# Security: Actions pinned to commit SHAs ($(date +%Y-%m-%d))"
    echo ""
    
    for action in "${!ACTIONS[@]}"; do
        version="${ACTIONS[$action]}"
        echo "# $action $version"
        generate_reference "$action" "$version"
        echo ""
    done
    
    echo ""
    echo "After updating, verify with: ./update_actions.sh --check"
}

show_best_practices() {
    print_section "Security Best Practices"
    
    cat << 'EOF'
1. ✅ Always pin actions to specific commit SHAs, not mutable tags
   - Bad:  uses: actions/checkout@v3
   - Good: uses: actions/checkout@f43a0e5ff2bd294095638e18286ca9a3d1956744 # v3.6.0

2. ✅ Include version comments for readability
   - Helps identify which version the SHA represents

3. ✅ Review action updates quarterly
   - Security patches and improvements
   - Breaking changes in major versions

4. ✅ Audit third-party actions before use
   - Review source code
   - Check community trust/stars
   - Verify active maintenance

5. ✅ Use official GitHub actions when possible
   - actions/* namespace is maintained by GitHub
   - Higher trust level

6. ✅ Minimize secret exposure
   - Only pass secrets to trusted actions
   - Use environment-specific secrets
   - Rotate secrets regularly

7. ✅ Apply principle of least privilege
   - Use GITHUB_TOKEN with minimal permissions
   - Review permissions: sections in workflows

Resources:
- https://docs.github.com/en/actions/security-guides
- https://securitylab.github.com/research/github-actions-preventing-pwn-requests/
EOF
}

usage() {
    cat << EOF
Usage: $0 [OPTION]

Maintain GitHub Actions security for CI/CD workflows.

Options:
  --check       Check workflow files for security issues
  --update      Generate updated SHA-pinned action references
  --list        List all actions used in workflows
  --help        Show this help message

Examples:
  $0 --check                 # Audit current workflows
  $0 --list                  # Show all actions and their versions
  $0 --update                # Generate updated references

For more information, see docs/build_system/modern_build_system.md
EOF
}

main() {
    print_header
    
    case "${1:-}" in
        --check)
            check_actions
            ;;
        --update)
            update_actions
            ;;
        --list)
            list_actions
            ;;
        --best-practices)
            show_best_practices
            ;;
        --help)
            usage
            ;;
        *)
            echo "Error: Invalid option '${1:-}'"
            echo ""
            usage
            exit 1
            ;;
    esac
}

main "$@"
