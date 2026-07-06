#!/bin/bash

set -euo pipefail

workflow_file=".github/workflows/CORE-ALL.yml"

grep -Fq 'WRT_FRP_MODE:' "$workflow_file"
grep -Fq 'WRT_USB_MODE:' "$workflow_file"
grep -Fq 'WRT_FRP_MODE: ${{inputs.WRT_FRP_MODE || '"'"'none'"'"' }}' "$workflow_file"
grep -Fq 'WRT_USB_MODE: ${{inputs.WRT_USB_MODE || '"'"'default'"'"' }}' "$workflow_file"
grep -Fq 'manual_overlays="${WRT_OVERLAYS:-}"' "$workflow_file"
grep -Fq "frp_overlays=''" "$workflow_file"
grep -Fq "usb_overlays=''" "$workflow_file"
grep -Fq "combined_overlays=''" "$workflow_file"
grep -Fq 'combined_overlays="$frp_overlays"' "$workflow_file"
grep -Fq 'combined_overlays="${combined_overlays},${usb_overlays}"' "$workflow_file"
grep -Fq 'combined_overlays="${combined_overlays},${manual_overlays}"' "$workflow_file"
grep -Fq 'WRT_OVERLAYS=$(merge_overlay_csv_lists "$GITHUB_WORKSPACE/$WRT_DIR_CONFIGS" "$auto_overlays" "$combined_overlays")' "$workflow_file"
grep -Fq 'echo "WRT_OVERLAYS=$WRT_OVERLAYS" >> $GITHUB_ENV' "$workflow_file"

echo "test_core_all_structured_overlays: ok"
