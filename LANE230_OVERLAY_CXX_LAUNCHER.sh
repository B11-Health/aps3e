#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HOME_ROOT="/data/data/com.termux/files/home"
PREFIX_ROOT="/data/data/com.termux/files/usr"
CANON="/data/data/com.termux/files/home/projects/android/gamedeck/mobile/android/vendor/aps3e-source/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/SPUThread.cpp"
CANON_DIR="/data/data/com.termux/files/home/projects/android/gamedeck/mobile/android/vendor/aps3e-source/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell"
CAND="/data/data/com.termux/files/home/projects/android/gamedeck-ps3-prod-lanes-20260912/lane230-bink-putllc-build/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/SPUThread.cpp"
PIN_CANON="54d38ae502dfc82b9ff74c218947fec6c86b07cda8891ab008c7cc00306db121"
PIN_CAND="2979bb64cdcf34e540279b72282f08a250e1db0103f557cab9313d6c52914bc0"
TRACE="${LANE230_OVERLAY_TRACE:-}"
[[ $# -ge 1 ]] || { echo 'LANE230 launcher: compiler missing' >&2; exit 70; }
compiler="$1"; shift
args=("$@")
count=0
for i in "${!args[@]}"; do
  if [[ "${args[$i]}" == "$CANON" ]]; then
    ((count+=1)); [[ $count -eq 1 ]] || { echo 'multiple SPUThread sources' >&2; exit 71; }
    [[ "$(sha256sum "$CANON"|awk '{print $1}')" == "$PIN_CANON" ]] || { echo 'canonical SPUThread hash mismatch' >&2; exit 72; }
    [[ "$(sha256sum "$CAND"|awk '{print $1}')" == "$PIN_CAND" ]] || { echo 'candidate SPUThread hash mismatch' >&2; exit 73; }
    args[$i]="$CAND"
    args+=("-I$CANON_DIR")
    [[ -z "$TRACE" ]] || printf '%s\tSPUThread.cpp\t%s\t%s\n' "$(date -u +%FT%TZ)" "$PIN_CAND" "$compiler" >> "$TRACE"
  elif [[ "${args[$i]}" == */SPUThread.cpp ]]; then
    echo "unexpected SPUThread source: ${args[$i]}" >&2; exit 74
  fi
done
exec ccache "$compiler" "${args[@]}"
