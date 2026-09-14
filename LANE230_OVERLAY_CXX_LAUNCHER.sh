#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
CANON_ROOT="/data/data/com.termux/files/home/projects/android/gamedeck/mobile/android/vendor/aps3e-source/app/src/main/cpp/rpcs3/rpcs3"
CAND_ROOT="/data/data/com.termux/files/home/projects/android/gamedeck-ps3-prod-lanes-20260912/lane230-bink-putllc-build/app/src/main/cpp/rpcs3/rpcs3"
TRACE="${LANE230_OVERLAY_TRACE:-}"
PIN_HEADER="69982b9d1a12e87cbe94954b92487f6122b213cec24b40d08ea30851f5f01c8a"
fail(){ echo "LANE230_OVERLAY_FAIL rc=$1 ${*:2}" >&2; exit "$1"; }
[[ $# -ge 1 ]] || fail 70 'compiler missing'
compiler="$1"; shift
args=("$@")
[[ "$(sha256sum "$CAND_ROOT/Emu/Cell/spurs_live_canary.h" | awk '{print $1}')" == "$PIN_HEADER" ]] || fail 71 'candidate canary header hash mismatch'
count=0
for i in "${!args[@]}"; do
  src="${args[$i]}"
  case "$src" in
    "$CANON_ROOT/Emu/Cell/Modules/cellSpurs.cpp")
      c="$CAND_ROOT/Emu/Cell/Modules/cellSpurs.cpp"; ch="fe9fc920ad97d993b8223a3695fc91512928b58310aa39659d7151f53944347b"; nh="0069fcba05a009b93663006d0d9047521ec6b2fe465ee0c55aea8f70c957305d"; tu=cellSpurs.cpp ;;
    "$CANON_ROOT/Emu/Cell/Modules/cellSpursSpu.cpp")
      c="$CAND_ROOT/Emu/Cell/Modules/cellSpursSpu.cpp"; ch="95e855384ee80ebeadd6c35300f8f093bf4d8345f4cdacca14bad6d08080fcc9"; nh="f5ae5b6e8e19884382399f5b76980f5e6e6d253d6b0b94bdfe3dcfbf0a4d6570"; tu=cellSpursSpu.cpp ;;
    "$CANON_ROOT/Emu/Cell/SPULLVMRecompiler.cpp")
      c="$CAND_ROOT/Emu/Cell/SPULLVMRecompiler.cpp"; ch="03c790a79e740a45442608b1ffce4385e3a75c2b0e3cc134ee01af14c952a142"; nh="2d6b4fa079d5721bb96dab46395cc189096c58b7088877fc134cc6d2cb124009"; tu=SPULLVMRecompiler.cpp ;;
    "$CANON_ROOT/Emu/Cell/SPUThread.cpp")
      c="$CAND_ROOT/Emu/Cell/SPUThread.cpp"; ch="54d38ae502dfc82b9ff74c218947fec6c86b07cda8891ab008c7cc00306db121"; nh="2979bb64cdcf34e540279b72282f08a250e1db0103f557cab9313d6c52914bc0"; tu=SPUThread.cpp ;;
    "$CAND_ROOT/Emu/Cell/Modules/cellSpurs.cpp"|"$CAND_ROOT/Emu/Cell/Modules/cellSpursSpu.cpp"|"$CAND_ROOT/Emu/Cell/SPULLVMRecompiler.cpp"|"$CAND_ROOT/Emu/Cell/SPUThread.cpp")
      fail 72 "candidate source supplied directly: $src" ;;
    *) continue ;;
  esac
  [[ "$(sha256sum "$src" | awk '{print $1}')" == "$ch" ]] || fail 73 "canonical hash mismatch: $tu"
  [[ "$(sha256sum "$c" | awk '{print $1}')" == "$nh" ]] || fail 74 "candidate hash mismatch: $tu"
  args[$i]="$c"
  ((count+=1))
  [[ -z "$TRACE" ]] || printf '%s\t%s\t%s\t%s\t%s\n' "$(date -u +%FT%TZ)" "$tu" "$nh" "$src" "$c" >> "$TRACE"
done
if (( count > 0 )); then
  args+=("-I$CAND_ROOT")
fi
exec ccache "$compiler" "${args[@]}"
