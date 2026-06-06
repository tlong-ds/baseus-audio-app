#!/usr/bin/env bash
set -u

TARGET_RE='(Baseus[[:space:]]+)?Bowie[[:space:]]+H1[[:space:]]*[Ss]'
VERBOSE=0
RAW=0

usage() {
  cat <<'EOF'
Usage: ./recognize_h1s.sh [--verbose] [--raw]

Recognize Baseus Bowie H1S endpoints from macOS Bluetooth system data.
This script is bash-only and uses system_profiler; it does not scan or connect
to BLE GATT characteristics.

Options:
  --verbose  Print parsed matching endpoint blocks.
  --raw      Print the full system_profiler Bluetooth report.
  -h, --help Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --verbose)
      VERBOSE=1
      shift
      ;;
    --raw)
      RAW=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

echo "Checking macOS Bluetooth system report..."
SYSTEM_REPORT="$(system_profiler SPBluetoothDataType 2>&1)"
SYSTEM_STATUS=$?

if [[ $SYSTEM_STATUS -ne 0 ]]; then
  echo "system_profiler failed:"
  echo "$SYSTEM_REPORT"
  exit 1
fi

if [[ $RAW -eq 1 ]]; then
  echo
  echo "$SYSTEM_REPORT"
fi

MATCHES="$(
  awk -v target="$TARGET_RE" '
    BEGIN {
      IGNORECASE = 1
      count = 0
    }

    function flush() {
      if (name != "" && name ~ target) {
        count++
        role = "unknown"
        if (services ~ /<[^>]*BLE[^>]*>/ || services ~ /(^|[[:space:]])BLE($|[[:space:]])/) {
          role = "BLE sidecar"
        } else if (services ~ /A2DP/ || services ~ /HFP/ || services ~ /AVRCP/ || services ~ /ACL/) {
          role = "Classic audio/control"
        }

        print "MATCH|" count "|" role "|" name "|" address "|" rssi "|" services
      }
    }

    /^[[:space:]]{10}[^:]+:[[:space:]]*$/ {
      flush()
      name = $0
      sub(/^[[:space:]]+/, "", name)
      sub(/:[[:space:]]*$/, "", name)
      address = "unknown"
      rssi = "unknown"
      services = "unknown"
      next
    }

    /^[[:space:]]{14}Address:/ {
      address = $0
      sub(/^[[:space:]]+Address:[[:space:]]*/, "", address)
      next
    }

    /^[[:space:]]{14}RSSI:/ {
      rssi = $0
      sub(/^[[:space:]]+RSSI:[[:space:]]*/, "", rssi)
      next
    }

    /^[[:space:]]{14}Services:/ {
      services = $0
      sub(/^[[:space:]]+Services:[[:space:]]*/, "", services)
      next
    }

    END {
      flush()
    }
  ' <<<"$SYSTEM_REPORT"
)"

if [[ -z "$MATCHES" ]]; then
  echo "[no match] Bowie H1S was not found in system_profiler output."
  echo
  echo "macOS can show devices in the menu before system_profiler exposes them."
  echo "Reconnect the headset, wait a few seconds, then run this again."
  exit 1
fi

echo "[MATCH] Bowie H1S appears in macOS Bluetooth devices."
echo
echo "Parsed endpoints:"

CLASSIC_ADDRESS=""
BLE_ADDRESS=""

while IFS='|' read -r tag index role name address rssi services; do
  [[ "$tag" == "MATCH" ]] || continue

  echo "- $name"
  echo "  Role: $role"
  echo "  Address: $address"
  echo "  RSSI: $rssi"
  echo "  Services: $services"

  case "$role" in
    "Classic audio/control")
      CLASSIC_ADDRESS="$address"
      ;;
    "BLE sidecar")
      BLE_ADDRESS="$address"
      ;;
  esac
done <<<"$MATCHES"

echo
if [[ -n "$CLASSIC_ADDRESS" && -n "$BLE_ADDRESS" ]]; then
  echo "Association:"
  echo "  Classic endpoint: $CLASSIC_ADDRESS"
  echo "  BLE sidecar:      $BLE_ADDRESS"
  echo
  echo "Use the BLE sidecar for ANC/EQ reverse-engineering. The Classic endpoint"
  echo "is for audio/calls/media controls and is not enough for app-style features."
elif [[ -n "$CLASSIC_ADDRESS" ]]; then
  echo "Only the Classic endpoint was found. ANC/EQ control probably still needs"
  echo "a separate BLE sidecar, but it is not visible in this system report."
elif [[ -n "$BLE_ADDRESS" ]]; then
  echo "Only the BLE sidecar was found. This is the endpoint to inspect for GATT"
  echo "services if you use a BLE tool outside this bash-only script."
else
  echo "H1S entries were found, but their services did not identify a clear role."
fi

if [[ $VERBOSE -eq 1 ]]; then
  echo
  echo "Matching endpoint blocks:"
  awk -v target="$TARGET_RE" '
    BEGIN { IGNORECASE = 1 }
    $0 ~ "^[[:space:]]{10}" target ":[[:space:]]*$" {
      print $0
      for (i = 0; i < 6 && getline; i++) {
        if ($0 ~ /^[[:space:]]{10}[^:]+:[[:space:]]*$/) {
          break
        }
        print $0
      }
    }
  ' <<<"$SYSTEM_REPORT"
fi

exit 0
