#!/usr/bin/env bash
#
# Ad / telemetry regression guard.
#
# Fails if compiled C/C++/header or build sources reintroduce the advertising, telemetry, or
# remote-UI surface that was removed in the ad-free hardening. This is a defense against a future
# change (or a bad merge from upstream) silently bringing the Aitum API, InstallGUID transmission,
# server-controlled "partnerBlocks", donation/promotion links, or the Stream Suite update prompt back.
#
# Pure comment lines (leading //, *, or #) are ignored so that explanatory comments documenting the
# removal do not trip the guard. Any NON-comment line containing a forbidden pattern is a failure.
#
# Run from the repository root: bash .github/scripts/check-no-ads.sh

set -euo pipefail

# Files that are compiled into the plugin or drive its build.
files=()
while IFS= read -r f; do
  files+=("$f")
done < <(git ls-files \
  '*.c' '*.cpp' '*.h' '*.hpp' '*.cc' '*.cxx' \
  'CMakeLists.txt' '*.cmake')

# Forbidden patterns (extended regex). These target the removed ad/telemetry/remote-UI mechanisms.
patterns=(
  'api\.aitum\.tv'                 # automatic Aitum API / telemetry endpoint
  'InstallGUID'                    # OBS stable install identifier transmission
  'partnerBlocks?'                 # server-controlled promotional blocks
  'partner_block'                  # persisted partner-block timestamp
  'aitum\.tv/contribute'           # donation link
  'download/stream-suite'          # Stream Suite promotional update URL
  'update_info_create'             # file-updater entry point (Aitum-only)
  'file-updater\.h'                # removed updater header include
  'ApiInfo'                        # server-driven UI renderer
)

# Strip pure comment lines, then search for any forbidden pattern in real code.
found=0
for pattern in "${patterns[@]}"; do
  for f in "${files[@]}"; do
    # Skip this guard script's own file list is not relevant (it's a shell script, not scanned).
    if grep -nE "$pattern" "$f" 2>/dev/null \
        | grep -vE '^[0-9]+:[[:space:]]*(//|\*|#)' > /tmp/adhit.$$; then
      if [ -s /tmp/adhit.$$ ]; then
        echo "AD/TELEMETRY REGRESSION: pattern '$pattern' found in $f:"
        sed 's/^/    /' /tmp/adhit.$$
        found=1
      fi
    fi
  done
done
rm -f /tmp/adhit.$$

if [ "$found" -ne 0 ]; then
  echo ""
  echo "ERROR: forbidden advertising/telemetry/remote-UI code was detected in compiled sources."
  echo "The ad-free hardening must not be reverted. See SECURITY-HARDENING.md."
  exit 1
fi

echo "OK: no advertising/telemetry/remote-UI code found in compiled sources."
