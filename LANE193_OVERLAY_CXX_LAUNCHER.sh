#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

HOME_ROOT="/data/data/com.termux/files/home"
PREFIX="/data/data/com.termux/files/usr"
WORKTREE="$HOME_ROOT/projects/android/gamedeck-ps3-prod-lanes-20260912/lane193-prod-spurs-canary-build-wrapper-v2"
SELF_EXPECTED="$WORKTREE/LANE193_OVERLAY_CXX_LAUNCHER.sh"
WRAPPER_EXPECTED="$WORKTREE/LANE193_BUILD_WRAPPER.sh"
LANE187_REPO="$HOME_ROOT/projects/android/gamedeck-ps3-prod-lanes-20260912/lane187-prod-spurs-canary-instrumentation"
LANE187_MOD="$LANE187_REPO/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules"
CANON_REPO="$HOME_ROOT/projects/android/gamedeck/mobile/android/vendor/aps3e-source"
ORIG="$CANON_REPO/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules"
CCACHE="$PREFIX/bin/ccache"
GIT="$PREFIX/bin/git"
SHA256SUM="$PREFIX/bin/sha256sum"
READLINK="$PREFIX/bin/readlink"
DATE="$PREFIX/bin/date"

PIN_HEAD187="cf5cb967e706fde89fd9fc76eed5f5b052e50a36"
PIN_CELL_SHA="c1c3731fd34823eebd88d87ab5bde00f38147e7e78d68bd93d898440161dd6f4"
PIN_SPU_SHA="f5ae5b6e8e19884382399f5b76980f5e6e6d253d6b0b94bdfe3dcfbf0a4d6570"
PIN_CANON_CELL_SHA="fe9fc920ad97d993b8223a3695fc91512928b58310aa39659d7151f53944347b"
PIN_CANON_SPU_SHA="95e855384ee80ebeadd6c35300f8f093bf4d8345f4cdacca14bad6d08080fcc9"
TRACE_HEADER=$'#LANE193_OVERLAY_TRACE_V1\tutc_timestamp\ttu\tcandidate_sha256\tcompiler\tcanonical_source\tcandidate_source'
TRACE="${LANE193_TRACE_PATH:-}"
APPROVED_COMMIT="${LANE193_APPROVED_COMMIT:-}"
APPROVED_WRAPPER_SHA="${LANE193_APPROVED_WRAPPER_SHA256:-}"
APPROVED_LAUNCHER_SHA="${LANE193_APPROVED_LAUNCHER_SHA256:-}"

fail() {
    local rc="$1"
    shift
    printf 'LANE193_OVERLAY_FAIL rc=%s %s\n' "$rc" "$*" >&2
    exit "$rc"
}

sha_file() {
    local path="$1" out
    if ! out=$("$SHA256SUM" -- "$path"); then
        return 1
    fi
    printf '%s\n' "${out%% *}"
}

clean_status_or_fail() {
    local repo="$1" label="$2" status
    if ! status=$("$GIT" -C "$repo" status --porcelain=v1 -uall); then
        fail 91 "$label git status failed"
    fi
    [[ -z "$status" ]] || fail 92 "$label worktree is not clean"
}

[[ "$APPROVED_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail 70 "LANE193_APPROVED_COMMIT must be an exact 40-hex commit"
[[ "$APPROVED_WRAPPER_SHA" =~ ^[0-9a-f]{64}$ ]] || fail 71 "LANE193_APPROVED_WRAPPER_SHA256 must be an exact 64-hex SHA256"
[[ "$APPROVED_LAUNCHER_SHA" =~ ^[0-9a-f]{64}$ ]] || fail 72 "LANE193_APPROVED_LAUNCHER_SHA256 must be an exact 64-hex SHA256"
[[ -n "$TRACE" ]] || fail 73 "LANE193_TRACE_PATH is required"

TRACE_PREFIX="$HOME_ROOT/.cache/gd-lane193-lane187-canary-libe-${APPROVED_WRAPPER_SHA}-"
[[ "$TRACE" == "$TRACE_PREFIX"*"/overlay-trace.tsv" ]] || fail 74 "unexpected trace path: $TRACE"
RUN_DIR="${TRACE%/overlay-trace.tsv}"
RUN_SUFFIX="${RUN_DIR#"$TRACE_PREFIX"}"
[[ "$RUN_DIR" != "$RUN_SUFFIX" && "$RUN_SUFFIX" != */* ]] || fail 75 "trace run directory violates prefix contract"
[[ "$RUN_SUFFIX" =~ ^[0-9]{8}T[0-9]{6}Z-[0-9]+$ ]] || fail 76 "trace run suffix has wrong shape: $RUN_SUFFIX"
[[ -d "$RUN_DIR" && ! -L "$RUN_DIR" ]] || fail 77 "trace run directory missing or symlinked: $RUN_DIR"
[[ -f "$TRACE" && ! -L "$TRACE" && -w "$TRACE" ]] || fail 78 "trace must be a writable regular non-symlink file: $TRACE"
if ! IFS= read -r trace_header < "$TRACE"; then
    fail 79 "cannot read trace schema header"
fi
[[ "$trace_header" == "$TRACE_HEADER" ]] || fail 80 "trace schema header mismatch"

[[ -x "$CCACHE" && -x "$GIT" && -x "$SHA256SUM" && -x "$READLINK" && -x "$DATE" ]] || fail 81 "required launcher tool missing"
[[ $# -ge 1 ]] || fail 82 "compiler argument missing"
compiler="$1"
shift
if [[ "$compiler" == */* ]]; then
    [[ -x "$compiler" ]] || fail 83 "compiler is not executable: $compiler"
else
    if ! compiler_path=$(command -v -- "$compiler"); then
        fail 83 "compiler cannot be resolved: $compiler"
    fi
    [[ -n "$compiler_path" && -x "$compiler_path" ]] || fail 83 "compiler cannot be resolved to an executable: $compiler"
fi

args=("$@")
sub_count=0
sub_index=-1
tu=""
expected_sha=""
expected_canon_sha=""
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
            expected_canon_sha="$PIN_CANON_CELL_SHA"
            candidate="$LANE187_MOD/cellSpurs.cpp"
            canonical="$ORIG/cellSpurs.cpp"
            ;;
        "$ORIG/cellSpursSpu.cpp")
            ((sub_count += 1))
            sub_index="$i"
            tu="cellSpursSpu.cpp"
            expected_sha="$PIN_SPU_SHA"
            expected_canon_sha="$PIN_CANON_SPU_SHA"
            candidate="$LANE187_MOD/cellSpursSpu.cpp"
            canonical="$ORIG/cellSpursSpu.cpp"
            ;;
        "$LANE187_MOD/cellSpurs.cpp"|"$LANE187_MOD/cellSpursSpu.cpp")
            fail 84 "candidate TU supplied directly instead of canonical source: $arg"
            ;;
        */cellSpurs.cpp|*/cellSpursSpu.cpp)
            fail 85 "unexpected protected SPURS TU source path: $arg"
            ;;
    esac
done

(( sub_count <= 1 )) || fail 86 "multiple protected SPURS source TUs in one compiler invocation"

if (( sub_count == 1 )); then
    SELF_SOURCE="${BASH_SOURCE[0]}"
    [[ ! -L "$SELF_SOURCE" ]] || fail 87 "launcher invocation path is symlinked"
    if ! self_real=$("$READLINK" -f -- "$SELF_SOURCE"); then
        fail 88 "cannot resolve launcher path"
    fi
    [[ "$self_real" == "$SELF_EXPECTED" ]] || fail 89 "launcher path mismatch: $self_real"
    [[ -f "$WRAPPER_EXPECTED" && ! -L "$WRAPPER_EXPECTED" ]] || fail 90 "wrapper missing or symlinked"

    if ! lane193_head=$("$GIT" -C "$WORKTREE" rev-parse HEAD); then
        fail 93 "Lane193 rev-parse failed"
    fi
    [[ "$lane193_head" == "$APPROVED_COMMIT" ]] || fail 94 "Lane193 approved commit mismatch: $lane193_head"
    clean_status_or_fail "$WORKTREE" "Lane193"

    if ! launcher_sha=$(sha_file "$SELF_EXPECTED"); then
        fail 95 "launcher SHA256 failed"
    fi
    if ! wrapper_sha=$(sha_file "$WRAPPER_EXPECTED"); then
        fail 96 "wrapper SHA256 failed"
    fi
    [[ "$launcher_sha" == "$APPROVED_LAUNCHER_SHA" ]] || fail 97 "launcher SHA256 differs from approved identity"
    [[ "$wrapper_sha" == "$APPROVED_WRAPPER_SHA" ]] || fail 98 "wrapper SHA256 differs from approved identity"

    if ! approved_launcher_blob=$("$GIT" -C "$WORKTREE" rev-parse "$APPROVED_COMMIT:LANE193_OVERLAY_CXX_LAUNCHER.sh"); then
        fail 99 "approved launcher blob lookup failed"
    fi
    if ! approved_wrapper_blob=$("$GIT" -C "$WORKTREE" rev-parse "$APPROVED_COMMIT:LANE193_BUILD_WRAPPER.sh"); then
        fail 100 "approved wrapper blob lookup failed"
    fi
    if ! runtime_launcher_blob=$("$GIT" hash-object "$SELF_EXPECTED"); then
        fail 101 "runtime launcher blob calculation failed"
    fi
    if ! runtime_wrapper_blob=$("$GIT" hash-object "$WRAPPER_EXPECTED"); then
        fail 102 "runtime wrapper blob calculation failed"
    fi
    [[ "$runtime_launcher_blob" == "$approved_launcher_blob" ]] || fail 103 "launcher Git blob differs from approved commit"
    [[ "$runtime_wrapper_blob" == "$approved_wrapper_blob" ]] || fail 104 "wrapper Git blob differs from approved commit"

    if ! lane_head=$("$GIT" -C "$LANE187_REPO" rev-parse HEAD); then
        fail 105 "Lane187 rev-parse failed"
    fi
    [[ "$lane_head" == "$PIN_HEAD187" ]] || fail 106 "Lane187 HEAD mismatch: $lane_head"
    clean_status_or_fail "$LANE187_REPO" "Lane187"

    [[ -f "$candidate" && ! -L "$candidate" ]] || fail 107 "candidate source missing or symlinked: $candidate"
    [[ -f "$canonical" && ! -L "$canonical" ]] || fail 108 "canonical source missing or symlinked: $canonical"
    if ! candidate_sha=$(sha_file "$candidate"); then
        fail 109 "$tu candidate SHA256 failed"
    fi
    [[ "$candidate_sha" == "$expected_sha" ]] || fail 110 "$tu candidate SHA256 mismatch: $candidate_sha"
    if ! canonical_sha=$(sha_file "$canonical"); then
        fail 111 "$tu canonical SHA256 failed"
    fi
    [[ "$canonical_sha" == "$expected_canon_sha" ]] || fail 112 "$tu canonical SHA256 mismatch: $canonical_sha"

    args[$sub_index]="$candidate"
    args+=("-I$ORIG")
    if ! timestamp=$("$DATE" -u +%Y-%m-%dT%H:%M:%SZ); then
        fail 113 "UTC timestamp generation failed"
    fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$timestamp" "$tu" "$candidate_sha" "$compiler" "$canonical" "$candidate" >> "$TRACE"
fi

exec "$CCACHE" "$compiler" "${args[@]}"
