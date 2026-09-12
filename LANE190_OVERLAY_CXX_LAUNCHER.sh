#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

HOME_ROOT="/data/data/com.termux/files/home"
TERMUX_BIN="$HOME_ROOT/../usr/bin"
LANE187_REPO="$HOME_ROOT/projects/android/gamedeck-ps3-prod-lanes-20260912/lane187-prod-spurs-canary-instrumentation"
LANE187_MOD="$LANE187_REPO/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules"
CANON_REPO="$HOME_ROOT/projects/android/gamedeck/mobile/android/vendor/aps3e-source"
ORIG="$CANON_REPO/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules"
CCACHE="/data/data/com.termux/files/usr/bin/ccache"
GIT="/data/data/com.termux/files/usr/bin/git"
SHA256SUM="/data/data/com.termux/files/usr/bin/sha256sum"
AWK="/data/data/com.termux/files/usr/bin/awk"
DATE="/data/data/com.termux/files/usr/bin/date"

PIN_HEAD="cf5cb967e706fde89fd9fc76eed5f5b052e50a36"
PIN_CELL_SHA="c1c3731fd34823eebd88d87ab5bde00f38147e7e78d68bd93d898440161dd6f4"
PIN_SPU_SHA="f5ae5b6e8e19884382399f5b76980f5e6e6d253d6b0b94bdfe3dcfbf0a4d6570"
TRACE_PREFIX="$HOME_ROOT/.cache/gd-lane190-lane187-canary-libe-"
TRACE="${LANE190_TRACE_PATH:-}"

fail() {
    local rc="$1"
    shift
    printf 'LANE190_OVERLAY_FAIL rc=%s %s\n' "$rc" "$*" >&2
    exit "$rc"
}

[[ -n "$TRACE" ]] || fail 70 "LANE190_TRACE_PATH is required"
[[ "$TRACE" == "$TRACE_PREFIX"*"/overlay-trace.tsv" ]] || fail 71 "unexpected trace path: $TRACE"
[[ -f "$TRACE" && -w "$TRACE" ]] || fail 72 "trace must already exist and be writable: $TRACE"
[[ -x "$CCACHE" && -x "$GIT" && -x "$SHA256SUM" && -x "$AWK" && -x "$DATE" ]] || fail 73 "required launcher tool missing"
[[ $# -ge 1 ]] || fail 74 "compiler argument missing"

compiler="$1"
shift
if [[ "$compiler" == */* ]]; then
    [[ -x "$compiler" ]] || fail 75 "compiler is not executable: $compiler"
else
    compiler_path="$(command -v -- "$compiler" 2>/dev/null || true)"
    [[ -n "$compiler_path" && -x "$compiler_path" ]] || fail 75 "compiler cannot be resolved: $compiler"
fi

args=("$@")
sub_count=0
sub_index=-1
tu=""
expected_sha=""
candidate=""
canonical=""

for i in "${!args[@]}"; do
    arg="${args[$i]}"
    case "$arg" in
        "$ORIG/cellSpurs.cpp")
            ((sub_count += 1))
            sub_index="$i"
            tu="cellSpurs.cpp"
            expected_sha="$PIN_CELL_SHA"
            candidate="$LANE187_MOD/cellSpurs.cpp"
            canonical="$ORIG/cellSpurs.cpp"
            ;;
        "$ORIG/cellSpursSpu.cpp")
            ((sub_count += 1))
            sub_index="$i"
            tu="cellSpursSpu.cpp"
            expected_sha="$PIN_SPU_SHA"
            candidate="$LANE187_MOD/cellSpursSpu.cpp"
            canonical="$ORIG/cellSpursSpu.cpp"
            ;;
        "$LANE187_MOD/cellSpurs.cpp"|"$LANE187_MOD/cellSpursSpu.cpp")
            fail 76 "candidate TU supplied directly instead of canonical source: $arg"
            ;;
        */cellSpurs.cpp|*/cellSpursSpu.cpp)
            fail 77 "unexpected SPURS TU source path: $arg"
            ;;
    esac
done

(( sub_count <= 1 )) || fail 78 "multiple SPURS source TUs in one compiler invocation"

if (( sub_count == 1 )); then
    [[ -d "$LANE187_REPO/.git" || -f "$LANE187_REPO/.git" ]] || fail 79 "Lane187 worktree metadata missing"
    lane_head="$($GIT -C "$LANE187_REPO" rev-parse HEAD 2>/dev/null || true)"
    [[ "$lane_head" == "$PIN_HEAD" ]] || fail 80 "Lane187 HEAD mismatch: ${lane_head:-unavailable}"
    lane_status="$($GIT -C "$LANE187_REPO" status --porcelain=v1 -uall 2>/dev/null || true)"
    [[ -z "$lane_status" ]] || fail 81 "Lane187 worktree is not clean"
    [[ -f "$candidate" && ! -L "$candidate" ]] || fail 82 "candidate source missing or symlinked: $candidate"
    [[ -f "$canonical" && ! -L "$canonical" ]] || fail 83 "canonical source missing or symlinked: $canonical"

    candidate_sha="$($SHA256SUM "$candidate" | $AWK '{print $1}')"
    [[ "$candidate_sha" == "$expected_sha" ]] || fail 84 "$tu candidate SHA256 mismatch: $candidate_sha"

    args[$sub_index]="$candidate"
    args+=("-I$ORIG")
    timestamp="$($DATE -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$timestamp" "$tu" "$candidate_sha" "$compiler" "$canonical" "$candidate" >> "$TRACE"
fi

exec "$CCACHE" "$compiler" "${args[@]}"
