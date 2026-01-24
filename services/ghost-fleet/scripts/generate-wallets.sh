#!/usr/bin/env bash
# Ghost Fleet Wallet Generator
# Generates wallets for fleet operations using cast (Foundry)
#
# Usage:
#   ./generate-wallets.sh <count> [output_dir]
#
# Example:
#   ./generate-wallets.sh 10 ./wallets
#
# Output:
#   - wallets.json: Array of wallet configs for ghost-fleet config
#   - wallets.csv: Spreadsheet-friendly format
#   - Individual .key files (encrypted with provided password)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check dependencies
check_deps() {
    if ! command -v cast &> /dev/null; then
        echo -e "${RED}Error: 'cast' not found. Install Foundry: https://getfoundry.sh${NC}"
        exit 1
    fi
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}Error: 'jq' not found. Install jq: https://stedolan.github.io/jq/${NC}"
        exit 1
    fi
}

# Print usage
usage() {
    echo "Usage: $0 <count> [output_dir] [profile]"
    echo ""
    echo "Arguments:"
    echo "  count      Number of wallets to generate (required)"
    echo "  output_dir Directory for output files (default: ./wallets)"
    echo "  profile    Default profile name for wallets (default: degen)"
    echo ""
    echo "Environment variables:"
    echo "  WALLET_PASSWORD  Password for encrypting private keys"
    echo "                   If not set, will prompt for password"
    echo ""
    echo "Example:"
    echo "  $0 10 ./wallets degen"
    echo "  WALLET_PASSWORD=secret $0 50"
    exit 1
}

# Main function
main() {
    check_deps

    # Parse arguments
    if [[ $# -lt 1 ]]; then
        usage
    fi

    local count="$1"
    local output_dir="${2:-./wallets}"
    local default_profile="${3:-degen}"

    # Validate count
    if ! [[ "$count" =~ ^[0-9]+$ ]] || [[ "$count" -lt 1 ]]; then
        echo -e "${RED}Error: count must be a positive integer${NC}"
        exit 1
    fi

    # Get password
    local password
    if [[ -n "${WALLET_PASSWORD:-}" ]]; then
        password="$WALLET_PASSWORD"
    else
        echo -e "${YELLOW}Enter password for encrypting private keys:${NC}"
        read -s password
        echo -e "${YELLOW}Confirm password:${NC}"
        read -s password_confirm
        if [[ "$password" != "$password_confirm" ]]; then
            echo -e "${RED}Error: Passwords do not match${NC}"
            exit 1
        fi
    fi

    # Create output directory
    mkdir -p "$output_dir"

    echo -e "${GREEN}Generating $count wallets...${NC}"
    echo ""

    # Initialize output files
    local json_file="$output_dir/wallets.json"
    local csv_file="$output_dir/wallets.csv"
    local toml_file="$output_dir/wallets.toml"

    echo "address,private_key,profile" > "$csv_file"
    echo "[" > "$json_file"
    echo "# Ghost Fleet Wallet Configuration" > "$toml_file"
    echo "# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")" >> "$toml_file"
    echo "" >> "$toml_file"

    local wallets_json="["
    local first=true

    for i in $(seq 1 "$count"); do
        # Generate wallet
        local wallet_output
        wallet_output=$(cast wallet new --json)
        
        local address
        address=$(echo "$wallet_output" | jq -r '.address')
        local private_key
        private_key=$(echo "$wallet_output" | jq -r '.private_key')
        
        # Generate wallet ID
        local wallet_id="wallet-$(printf "%03d" "$i")"

        # Add to CSV
        echo "$address,$private_key,$default_profile" >> "$csv_file"

        # Add to JSON
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$json_file"
        fi
        cat >> "$json_file" <<EOF
  {
    "id": "$wallet_id",
    "address": "$address",
    "profile": "$default_profile",
    "private_key": "$private_key",
    "enabled": true
  }
EOF

        # Add to TOML
        cat >> "$toml_file" <<EOF
[[wallets]]
id = "$wallet_id"
address = "$address"
profile = "$default_profile"
private_key = "$private_key"
enabled = true

EOF

        # Save encrypted keyfile (optional - for production use keystore)
        local keyfile="$output_dir/${wallet_id}.key"
        echo "$private_key" | openssl enc -aes-256-cbc -pbkdf2 -salt -pass "pass:$password" -out "$keyfile" 2>/dev/null || true

        # Progress indicator
        printf "\r  Generated %d/%d wallets" "$i" "$count"
    done

    echo "]" >> "$json_file"

    echo ""
    echo ""
    echo -e "${GREEN}Done! Generated $count wallets${NC}"
    echo ""
    echo "Output files:"
    echo "  - $json_file (JSON array for programmatic use)"
    echo "  - $csv_file (CSV for spreadsheets)"
    echo "  - $toml_file (TOML for ghost-fleet config)"
    echo ""
    echo -e "${YELLOW}SECURITY WARNING:${NC}"
    echo "  - The generated files contain UNENCRYPTED private keys"
    echo "  - Store securely and restrict file permissions"
    echo "  - Consider using encrypted keyfiles for production"
    echo ""
    
    # Set restrictive permissions
    chmod 600 "$output_dir"/*.key 2>/dev/null || true
    chmod 600 "$csv_file"
    chmod 600 "$toml_file"
    chmod 600 "$json_file"
    
    echo -e "${GREEN}File permissions set to 600 (owner read/write only)${NC}"
}

main "$@"
