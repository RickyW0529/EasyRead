#!/bin/bash
set -euo pipefail

# Build a locally signed Release app with the same identity on every rebuild.
# Configure the ignored signing file first with scripts/setup-team.sh.
cd "$(dirname "$0")/.."
local_config="EasyRead-debug.local.xcconfig"
if [[ ! -f "$local_config" ]]; then
    echo "Run bash scripts/setup-team.sh first to select your Apple Development identity." >&2
    exit 1
fi

signing_identity=$(sed -nE 's/^CODE_SIGN_IDENTITY[[:space:]]*=[[:space:]]*(.*)/\1/p' "$local_config")
signing_team=$(sed -nE 's/^DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*(.*)/\1/p' "$local_config")
if [[ -z "$signing_identity" || "$signing_identity" == "-" || -z "$signing_team" ]]; then
    echo "A development certificate is required for stable Accessibility authorization; run bash scripts/setup-team.sh." >&2
    exit 1
fi

signing_config=$(mktemp "${TMPDIR:-/tmp}/easyread-local-signing.XXXXXX")
trap 'rm -f "$signing_config"' EXIT
cat > "$signing_config" <<EOF
CODE_SIGN_IDENTITY = $signing_identity
CODE_SIGN_IDENTITY[sdk=macosx*] = $signing_identity
DEVELOPMENT_TEAM = $signing_team
DEVELOPMENT_TEAM[sdk=macosx*] = $signing_team
CODE_SIGN_STYLE = Manual
PROVISIONING_PROFILE_SPECIFIER =
EOF

checkout_id=$(git rev-parse --show-toplevel | sed -e "s|^$HOME/||" -e 's|^\.||' -e 's|/|_|g')
agent_dd="$HOME/Library/Developer/Xcode/DerivedData/Easydict-Agent/$checkout_id"
xcodebuild build \
    -workspace EasyRead.xcworkspace \
    -scheme EasyRead \
    -configuration Release \
    -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$agent_dd" \
    -xcconfig "$signing_config" \
    -disableAutomaticPackageResolution \
    ONLY_ACTIVE_ARCH=YES \
    EASYREAD_RELEASE_PACKAGING=YES

app_path="$agent_dd/Build/Products/Release/EasyRead.app"
codesign --verify --deep --strict "$app_path"
printf '\nBuilt and verified: %s\n' "$app_path"
echo 'Quit the installed EasyRead before replacing it at the same installation path.'
