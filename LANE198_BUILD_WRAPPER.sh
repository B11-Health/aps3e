#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
umask 077

HOME_ROOT="/data/data/com.termux/files/home"
PREFIX="/data/data/com.termux/files/usr"
WORKTREE="$HOME_ROOT/projects/android/gamedeck-ps3-prod-lanes-20260912/lane198-prod-spurs-canary-build-wrapper-v4"
SELF_EXPECTED="$WORKTREE/LANE198_BUILD_WRAPPER.sh"
LAUNCHER="$WORKTREE/LANE198_OVERLAY_CXX_LAUNCHER.sh"
BASE190="5bcb30260fce516c23e77b5ba32a43c09dd5d606"
ROOT="$HOME_ROOT/projects/android/gamedeck/mobile/android/vendor/aps3e-source"
SRC="$ROOT/app/src/main/cpp"
CANON_MOD="$SRC/rpcs3/rpcs3/Emu/Cell/Modules"
LANE187="$HOME_ROOT/projects/android/gamedeck-ps3-prod-lanes-20260912/lane187-prod-spurs-canary-instrumentation"
REL="app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules"
CAND_A="$LANE187/$REL/cellSpurs.cpp"
CAND_B="$LANE187/$REL/cellSpursSpu.cpp"
CANON_A="$CANON_MOD/cellSpurs.cpp"
CANON_B="$CANON_MOD/cellSpursSpu.cpp"
HEAD187="cf5cb967e706fde89fd9fc76eed5f5b052e50a36"
SHA_A="c1c3731fd34823eebd88d87ab5bde00f38147e7e78d68bd93d898440161dd6f4"
SHA_B="f5ae5b6e8e19884382399f5b76980f5e6e6d253d6b0b94bdfe3dcfbf0a4d6570"
CANON_HEAD="7dc95e6baaac0712d5b3c28501778dd7934e579b"
CANON_STATUS_SHA="36b6a6d7e79282cb43e415bc4e076873c2d4b974576e5168c2844e0ff569e4bf"
CANON_SHA_A="fe9fc920ad97d993b8223a3695fc91512928b58310aa39659d7151f53944347b"
CANON_SHA_B="95e855384ee80ebeadd6c35300f8f093bf4d8345f4cdacca14bad6d08080fcc9"
NDK="$HOME_ROOT/android-sdk/ndk-r29-local"
NDK_REV="29.0.14206865"
TOOLCHAIN="$NDK/build/cmake/android.toolchain.cmake"
TOOLCHAIN_SHA="dbad92d9dcfea0d32b7c5e5f82f5072d878ded5d46a5d3f1f581ea108ca7fe89"
OLD_CONTAMINATED_BUILD="$HOME_ROOT/.cache/gd-prod-spurs-lane187-canary-build"
PRIOR_FRESH_BUILD_V2="$HOME_ROOT/.cache/gd-prod-spurs-lane187-canary-build-v2"
FRESH_BUILD_V4="$HOME_ROOT/.cache/gd-prod-spurs-lane187-canary-build-v4"
BUILD="$FRESH_BUILD_V4"
MIN_KIB=4194304
TRACE_HEADER=$'#LANE198_OVERLAY_TRACE_V1\tutc_timestamp\ttu\tcandidate_sha256\tcompiler\tcanonical_source\tcandidate_source'

GIT="$PREFIX/bin/git"
SHA256SUM="$PREFIX/bin/sha256sum"
AWK="$PREFIX/bin/awk"
GREP="$PREFIX/bin/grep"
DATE="$PREFIX/bin/date"
DF="$PREFIX/bin/df"
FIND="$PREFIX/bin/find"
STAT="$PREFIX/bin/stat"
FILE_CMD="$PREFIX/bin/file"
READELF="$PREFIX/bin/readelf"
READLINK="$PREFIX/bin/readlink"
CHMOD="$PREFIX/bin/chmod"

APPROVED_COMMIT="${LANE198_APPROVED_COMMIT:-}"
APPROVED_WRAPPER_SHA="${LANE198_APPROVED_WRAPPER_SHA256:-}"
APPROVED_LAUNCHER_SHA="${LANE198_APPROVED_LAUNCHER_SHA256:-}"

STAGE="startup"
FINAL_RESULT="FAILED_OR_INCOMPLETE"
RUN_DIR=""
FINAL_STATE=""

finalize() {
    local original_rc=$?
    trap - EXIT HUP INT TERM
    set +e
    set +u
    if [[ -n "${RUN_DIR:-}" && -d "$RUN_DIR" && ! -L "$RUN_DIR" ]]; then
        if [[ -n "${FINAL_STATE:-}" && ! -e "$FINAL_STATE" && ! -L "$FINAL_STATE" ]]; then
            ( set -o noclobber; : > "$FINAL_STATE" ) 2>/dev/null
        fi
        if [[ -n "${FINAL_STATE:-}" && -f "$FINAL_STATE" && ! -L "$FINAL_STATE" ]]; then
            {
                printf 'finished_utc=%s\n' "$("$DATE" -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"
                printf 'final_stage=%s\n' "${STAGE:-unknown}"
                printf 'original_rc=%s\n' "$original_rc"
                printf 'result=%s\n' "${FINAL_RESULT:-FAILED_OR_INCOMPLETE}"
                printf 'run_dir=%s\n' "$RUN_DIR"
            } >> "$FINAL_STATE" 2>/dev/null
        fi
        if ! "$FIND" "$RUN_DIR" -maxdepth 1 -type f -exec "$CHMOD" 0444 {} + 2>/dev/null; then
            :
        fi
        "$CHMOD" 0500 "$RUN_DIR" 2>/dev/null
    fi
    exit "$original_rc"
}
trap finalize EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

die() {
    local rc="$1"
    shift
    printf 'LANE198_BUILD_FAIL stage=%s rc=%s %s\n' "$STAGE" "$rc" "$*" >&2
    exit "$rc"
}

require_tool() {
    command -v -- "$1" >/dev/null 2>&1 || die 60 "missing required tool: $1"
}

sha_file() {
    local path="$1" out
    if ! out=$("$SHA256SUM" -- "$path"); then
        return 1
    fi
    printf '%s\n' "${out%% *}"
}

clean_status() {
    local repo="$1" out
    if ! out=$("$GIT" -C "$repo" status --porcelain=v1 -uall); then
        return 1
    fi
    [[ -z "$out" ]]
}

canonical_status_sha() {
    local out
    if ! out=$("$GIT" -C "$ROOT" status --porcelain=v1 -z | "$SHA256SUM"); then
        return 1
    fi
    printf '%s\n' "${out%% *}"
}

ndk_revision() {
    "$AWK" '
        BEGIN { count=0 }
        /^Pkg\.Revision[[:space:]]*=/ {
            count++
            value=$0
            sub(/^[^=]*=[[:space:]]*/, "", value)
            sub(/[[:space:]\r]+$/, "", value)
        }
        END {
            if (count != 1 || value == "") exit 42
            print value
        }
    ' "$NDK/source.properties"
}

free_kib() {
    "$DF" -Pk /data | "$AWK" 'NR==2 {print $4; found=1} END {if (!found) exit 43}'
}

safe_new_empty() {
    local path="$1"
    [[ ! -e "$path" && ! -L "$path" ]] || die 61 "evidence path already exists or is symlinked: $path"
    if ! ( set -o noclobber; : > "$path" ); then
        die 62 "cannot create evidence file safely: $path"
    fi
    [[ -f "$path" && ! -L "$path" ]] || die 63 "evidence path is not a regular non-symlink file: $path"
}

safe_new_text() {
    local path="$1" text="$2"
    safe_new_empty "$path"
    printf '%s' "$text" >> "$path"
}

self_contract() {
    local self_source self_real head status wrapper_sha launcher_sha approved_wrapper_blob approved_launcher_blob runtime_wrapper_blob runtime_launcher_blob

    [[ "$APPROVED_COMMIT" =~ ^[0-9a-f]{40}$ ]] || die 64 "LANE198_APPROVED_COMMIT must be exact 40-hex"
    [[ "$APPROVED_WRAPPER_SHA" =~ ^[0-9a-f]{64}$ ]] || die 65 "LANE198_APPROVED_WRAPPER_SHA256 must be exact 64-hex"
    [[ "$APPROVED_LAUNCHER_SHA" =~ ^[0-9a-f]{64}$ ]] || die 66 "LANE198_APPROVED_LAUNCHER_SHA256 must be exact 64-hex"

    self_source="${BASH_SOURCE[0]}"
    [[ ! -L "$self_source" ]] || die 67 "wrapper invocation path is symlinked"
    if ! self_real=$("$READLINK" -f -- "$self_source"); then
        die 68 "cannot resolve wrapper path"
    fi
    [[ "$self_real" == "$SELF_EXPECTED" ]] || die 69 "wrapper path mismatch: $self_real"
    [[ -f "$SELF_EXPECTED" && ! -L "$SELF_EXPECTED" && -x "$SELF_EXPECTED" ]] || die 70 "wrapper is not an executable regular non-symlink file"
    [[ -f "$LAUNCHER" && ! -L "$LAUNCHER" && -x "$LAUNCHER" ]] || die 71 "launcher is not an executable regular non-symlink file"

    if ! head=$("$GIT" -C "$WORKTREE" rev-parse HEAD); then
        die 72 "Lane198 rev-parse failed"
    fi
    [[ "$head" == "$APPROVED_COMMIT" ]] || die 73 "Lane198 HEAD does not equal approved commit: $head"
    if ! "$GIT" -C "$WORKTREE" merge-base --is-ancestor "$BASE190" "$APPROVED_COMMIT"; then
        die 74 "approved Lane198 commit is not descended from exact Lane190 base"
    fi
    if ! status=$("$GIT" -C "$WORKTREE" status --porcelain=v1 -uall); then
        die 75 "Lane198 git status failed"
    fi
    [[ -z "$status" ]] || die 76 "Lane198 worktree is not clean"

    if ! wrapper_sha=$(sha_file "$SELF_EXPECTED"); then
        die 77 "wrapper SHA256 calculation failed"
    fi
    if ! launcher_sha=$(sha_file "$LAUNCHER"); then
        die 78 "launcher SHA256 calculation failed"
    fi
    [[ "$wrapper_sha" == "$APPROVED_WRAPPER_SHA" ]] || die 79 "runtime wrapper SHA256 differs from approved identity"
    [[ "$launcher_sha" == "$APPROVED_LAUNCHER_SHA" ]] || die 80 "runtime launcher SHA256 differs from approved identity"

    if ! approved_wrapper_blob=$("$GIT" -C "$WORKTREE" rev-parse "$APPROVED_COMMIT:LANE198_BUILD_WRAPPER.sh"); then
        die 81 "approved wrapper Git blob lookup failed"
    fi
    if ! approved_launcher_blob=$("$GIT" -C "$WORKTREE" rev-parse "$APPROVED_COMMIT:LANE198_OVERLAY_CXX_LAUNCHER.sh"); then
        die 82 "approved launcher Git blob lookup failed"
    fi
    if ! runtime_wrapper_blob=$("$GIT" hash-object "$SELF_EXPECTED"); then
        die 83 "runtime wrapper Git blob calculation failed"
    fi
    if ! runtime_launcher_blob=$("$GIT" hash-object "$LAUNCHER"); then
        die 84 "runtime launcher Git blob calculation failed"
    fi
    [[ "$runtime_wrapper_blob" == "$approved_wrapper_blob" ]] || die 85 "runtime wrapper blob differs from approved commit"
    [[ "$runtime_launcher_blob" == "$approved_launcher_blob" ]] || die 86 "runtime launcher blob differs from approved commit"

    SELF_HEAD="$head"
    SELF_WRAPPER_SHA="$wrapper_sha"
    SELF_LAUNCHER_SHA="$launcher_sha"
    SELF_WRAPPER_BLOB="$runtime_wrapper_blob"
    SELF_LAUNCHER_BLOB="$runtime_launcher_blob"
}

snapshot_state() {
    local label="$1" path="$2" enforce_free="$3"
    local lane_head lane_status sha_a sha_b canon_head canon_status canon_sha_a canon_sha_b actual_ndk_rev toolchain_sha free

    [[ -d "$LANE187" ]] || die 87 "Lane187 worktree missing"
    if ! lane_head=$("$GIT" -C "$LANE187" rev-parse HEAD); then
        die 88 "$label Lane187 rev-parse failed"
    fi
    [[ "$lane_head" == "$HEAD187" ]] || die 89 "$label Lane187 HEAD mismatch: $lane_head"
    if ! lane_status=$("$GIT" -C "$LANE187" status --porcelain=v1 -uall); then
        die 90 "$label Lane187 git status failed"
    fi
    [[ -z "$lane_status" ]] || die 91 "$label Lane187 worktree is not clean"

    [[ -f "$CAND_A" && ! -L "$CAND_A" ]] || die 92 "$label Lane187 cellSpurs.cpp missing or symlinked"
    [[ -f "$CAND_B" && ! -L "$CAND_B" ]] || die 93 "$label Lane187 cellSpursSpu.cpp missing or symlinked"
    if ! sha_a=$(sha_file "$CAND_A"); then die 94 "$label Lane187 cellSpurs.cpp SHA256 failed"; fi
    if ! sha_b=$(sha_file "$CAND_B"); then die 95 "$label Lane187 cellSpursSpu.cpp SHA256 failed"; fi
    [[ "$sha_a" == "$SHA_A" ]] || die 96 "$label Lane187 cellSpurs.cpp SHA256 mismatch"
    [[ "$sha_b" == "$SHA_B" ]] || die 97 "$label Lane187 cellSpursSpu.cpp SHA256 mismatch"

    if ! canon_head=$("$GIT" -C "$ROOT" rev-parse HEAD); then
        die 98 "$label canonical rev-parse failed"
    fi
    [[ "$canon_head" == "$CANON_HEAD" ]] || die 99 "$label canonical HEAD mismatch: $canon_head"
    if ! canon_status=$(canonical_status_sha); then
        die 100 "$label canonical status fingerprint command failed"
    fi
    [[ "$canon_status" == "$CANON_STATUS_SHA" ]] || die 101 "$label canonical status fingerprint mismatch: $canon_status"
    [[ -f "$CANON_A" && ! -L "$CANON_A" ]] || die 102 "$label canonical cellSpurs.cpp missing or symlinked"
    [[ -f "$CANON_B" && ! -L "$CANON_B" ]] || die 103 "$label canonical cellSpursSpu.cpp missing or symlinked"
    if ! canon_sha_a=$(sha_file "$CANON_A"); then die 104 "$label canonical cellSpurs.cpp SHA256 failed"; fi
    if ! canon_sha_b=$(sha_file "$CANON_B"); then die 105 "$label canonical cellSpursSpu.cpp SHA256 failed"; fi
    [[ "$canon_sha_a" == "$CANON_SHA_A" ]] || die 106 "$label canonical cellSpurs.cpp SHA256 mismatch"
    [[ "$canon_sha_b" == "$CANON_SHA_B" ]] || die 107 "$label canonical cellSpursSpu.cpp SHA256 mismatch"

    [[ -f "$NDK/source.properties" && ! -L "$NDK/source.properties" ]] || die 108 "$label NDK source.properties missing or symlinked"
    [[ -f "$TOOLCHAIN" && ! -L "$TOOLCHAIN" ]] || die 109 "$label NDK toolchain missing or symlinked"
    if ! actual_ndk_rev=$(ndk_revision); then
        die 110 "$label NDK revision parse failed"
    fi
    [[ "$actual_ndk_rev" == "$NDK_REV" ]] || die 111 "$label NDK revision mismatch: $actual_ndk_rev"
    if ! toolchain_sha=$(sha_file "$TOOLCHAIN"); then
        die 112 "$label toolchain SHA256 failed"
    fi
    [[ "$toolchain_sha" == "$TOOLCHAIN_SHA" ]] || die 113 "$label toolchain SHA256 mismatch"

    if ! free=$(free_kib); then
        die 114 "$label free-space query failed"
    fi
    [[ "$free" =~ ^[0-9]+$ ]] || die 115 "$label free-space value is not numeric: $free"
    if [[ "$enforce_free" == "yes" ]]; then
        (( free >= MIN_KIB )) || die 116 "$label free-space gate failed: $free KiB < $MIN_KIB KiB"
    fi

    safe_new_empty "$path"
    {
        printf 'snapshot=%s\n' "$label"
        printf 'utc=%s\n' "$("$DATE" -u +%Y-%m-%dT%H:%M:%SZ)"
        printf 'lane187_head=%s\n' "$lane_head"
        printf 'lane187_status=clean\n'
        printf 'lane187_cellSpurs_sha256=%s\n' "$sha_a"
        printf 'lane187_cellSpursSpu_sha256=%s\n' "$sha_b"
        printf 'canonical_head=%s\n' "$canon_head"
        printf 'canonical_status_sha256=%s\n' "$canon_status"
        printf 'canonical_cellSpurs_sha256=%s\n' "$canon_sha_a"
        printf 'canonical_cellSpursSpu_sha256=%s\n' "$canon_sha_b"
        printf 'ndk_revision=%s\n' "$actual_ndk_rev"
        printf 'toolchain=%s\n' "$TOOLCHAIN"
        printf 'toolchain_sha256=%s\n' "$toolchain_sha"
        printf 'free_kib_data=%s\n' "$free"
        printf 'free_gate_kib=%s\n' "$MIN_KIB"
        printf 'free_gate_enforced=%s\n' "$enforce_free"
    } >> "$path"
}

cache_expect() {
    local key="$1" expected="$2" record lhs actual
    if ! record=$("$AWK" -v key="$key" '
        BEGIN { count=0; malformed=0 }
        /^[#]/ || /^\/\// || /^$/ { next }
        {
            eq=index($0, "=")
            if (eq == 0) next
            lhs=substr($0, 1, eq-1)
            value=substr($0, eq+1)
            n=split(lhs, parts, ":")
            if (parts[1] == key) {
                count++
                if (n > 2 || (n == 2 && parts[2] == "")) malformed=1
                if (count == 1) { saved_lhs=lhs; saved_value=value }
            }
        }
        END {
            if (count != 1 || malformed) exit 44
            printf "%s\t%s\n", saved_lhs, saved_value
        }
    ' "$CACHE_FILE"); then
        die 117 "CMakeCache key missing, duplicate, or malformed: $key"
    fi
    lhs="${record%%$'\t'*}"
    actual="${record#*$'\t'}"
    [[ "$actual" == "$expected" ]] || die 118 "CMakeCache mismatch for $key: expected '$expected' got '$actual'"
    printf '%s\t%s\t%s\n' "$key" "$lhs" "$actual" >> "$CACHE_EVIDENCE"
}

validate_cache() {
    [[ -f "$CACHE_FILE" && ! -L "$CACHE_FILE" ]] || die 119 "generated CMakeCache.txt missing or symlinked"
    safe_new_empty "$CACHE_EVIDENCE"
    printf 'validator=LANE198_CMAKE_CACHE_V1\nkey\tcache_lhs\tvalue\n' >> "$CACHE_EVIDENCE"
    cache_expect ANDROID_ABI arm64-v8a
    cache_expect ANDROID_PLATFORM android-24
    cache_expect ANDROID_PLATFORM_LEVEL 24
    cache_expect ANDROID_STL c++_shared
    cache_expect ANDROID_USE_LEGACY_TOOLCHAIN_FILE OFF
    cache_expect CMAKE_BUILD_TYPE Release
    cache_expect CMAKE_GENERATOR Ninja
    cache_expect CMAKE_TOOLCHAIN_FILE "$TOOLCHAIN"
    cache_expect CMAKE_CXX_COMPILER_LAUNCHER "$LAUNCHER"
    cache_expect CMAKE_C_COMPILER_LAUNCHER ccache
    cache_expect CMAKE_DISABLE_SOURCE_CHANGES ON
    cache_expect CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY
    cache_expect CMAKE_HAVE_LIBC_PTHREAD 1
    cache_expect HAVE_LIBPTHREAD 0
    cache_expect HAVE_LIBRT 0
    cache_expect HAVE_PTHREAD_MUTEX_LOCK 1
    cache_expect HAVE_PTHREAD_RWLOCK_INIT 1
    cache_expect PTHREAD_IN_LIBC 1
    cache_expect CURL_BROTLI OFF
    cache_expect CURL_ZSTD OFF
    cache_expect USE_NGHTTP2 OFF
    cache_expect LLVM_ENABLE_ZSTD OFF
    cache_expect LLVM_ENABLE_BACKTRACES OFF
    cache_expect LLVM_ENABLE_LIBEDIT OFF
    cache_expect LLVM_ENABLE_LIBXML2 OFF
    cache_expect GAMEDECK_ICONV_LIBRARY "$PREFIX/lib/libiconv.a"
    cache_expect GAMEDECK_CHARSET_LIBRARY "$PREFIX/lib/libcharset.a"
    cache_expect ZLIB_LIBRARY "$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/24/libz.so"
}

validate_graph() {
    local match
    [[ -f "$NINJA_FILE" && ! -L "$NINJA_FILE" ]] || die 120 "generated build.ninja missing or symlinked"
    if ! match=$("$AWK" '
        /^build emu:/ {
            all++
            if ($0 == "build emu: phony libe.so") { exact++; exact_line=NR ":" $0 }
        }
        END {
            if (all != 1 || exact != 1) exit 45
            print exact_line
        }
    ' "$NINJA_FILE"); then
        die 121 "build.ninja does not unambiguously prove exact 'build emu: phony libe.so'"
    fi
    local rules_file="$BUILD/CMakeFiles/rules.ninja"
    [[ -f "$rules_file" && ! -L "$rules_file" ]] || die 150 "generated CMakeFiles/rules.ninja missing or symlinked"
    local grep_rc pattern
    for pattern in "-isystem $PREFIX/include" "-I$PREFIX/include"; do
        if "$GREP" -Fq -- "$pattern" "$NINJA_FILE"; then
            die 151 "generated build.ninja leaks Termux host include root: $PREFIX/include"
        else
            grep_rc=$?
            [[ "$grep_rc" -eq 1 ]] || die 153 "grep inspection error for generated build.ninja rc=$grep_rc pattern=$pattern"
        fi
    done
    for pattern in "-isystem $PREFIX/include" "-I$PREFIX/include"; do
        if "$GREP" -Fq -- "$pattern" "$rules_file"; then
            die 152 "generated rules.ninja leaks Termux host include root: $PREFIX/include"
        else
            grep_rc=$?
            [[ "$grep_rc" -eq 1 ]] || die 154 "grep inspection error for generated rules.ninja rc=$grep_rc pattern=$pattern"
        fi
    done
    safe_new_empty "$GRAPH_EVIDENCE"
    printf 'validator=LANE198_NINJA_GRAPH_V2\n%s\nhost_include_root=%s\nhost_include_leak=0\n' "$match" "$PREFIX/include" >> "$GRAPH_EVIDENCE"
}

validate_trace() {
    local summary
    [[ -f "$TRACE" && ! -L "$TRACE" ]] || die 122 "overlay trace missing or symlinked"
    if ! summary=$("$AWK" -F '\t' \
        -v header="$TRACE_HEADER" \
        -v sha_a="$SHA_A" -v sha_b="$SHA_B" \
        -v canon_a="$CANON_A" -v canon_b="$CANON_B" \
        -v cand_a="$CAND_A" -v cand_b="$CAND_B" '
        NR == 1 {
            if ($0 != header) exit 50
            next
        }
        {
            if (NF != 6) exit 51
            ts=$1; tu=$2; sha=$3; compiler=$4; canon=$5; cand=$6
            if (ts !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z$/) exit 52
            if (compiler == "") exit 53
            if (tu == "cellSpurs.cpp") {
                if (sha != sha_a || canon != canon_a || cand != cand_a) exit 54
                count_a++
            } else if (tu == "cellSpursSpu.cpp") {
                if (sha != sha_b || canon != canon_b || cand != cand_b) exit 55
                count_b++
            } else {
                exit 56
            }
            rows++
        }
        END {
            if (NR < 1 || count_a < 1 || count_b < 1) exit 57
            printf "schema=LANE198_OVERLAY_TRACE_V1\nrows=%d\ncellSpurs.cpp_rows=%d\ncellSpursSpu.cpp_rows=%d\n", rows, count_a, count_b
        }
    ' "$TRACE"); then
        die 123 "strict overlay trace validation failed"
    fi
    safe_new_text "$TRACE_SUMMARY" "$summary"$'\n'
}

STAGE="build_path_contract_preflight"
(( $# == 0 )) || die 147 "wrapper accepts no arguments or build-dir overrides; only pinned v4 build path is permitted"
[[ "$BUILD" == "$FRESH_BUILD_V4" ]] || die 148 "future build path is not exact pinned v4 path: $BUILD"
[[ "$BUILD" != "$OLD_CONTAMINATED_BUILD" ]] || die 149 "refusing contaminated retired build path: $OLD_CONTAMINATED_BUILD"
[[ "$BUILD" != "$PRIOR_FRESH_BUILD_V2" ]] || die 150 "refusing prior v2 build path: $PRIOR_FRESH_BUILD_V2"

STAGE="tool_preflight"
for tool in git sha256sum awk grep cmake ninja ccache file readelf stat date df find chmod readlink; do
    require_tool "$tool"
done

STAGE="self_provenance_preflight"
self_contract

STAGE="evidence_directory_create"
if ! run_utc=$("$DATE" -u +%Y%m%dT%H%M%SZ); then
    die 124 "cannot generate unique run UTC"
fi
RUN_PREFIX="$HOME_ROOT/.cache/gd-lane198-lane187-canary-libe-${APPROVED_WRAPPER_SHA}-"
RUN_DIR="${RUN_PREFIX}${run_utc}-$$"
[[ ! -e "$RUN_DIR" && ! -L "$RUN_DIR" ]] || die 125 "unique evidence directory already exists or is symlinked: $RUN_DIR"
if ! mkdir -m 700 -- "$RUN_DIR"; then
    die 126 "cannot create unique evidence directory: $RUN_DIR"
fi
[[ -d "$RUN_DIR" && ! -L "$RUN_DIR" ]] || die 127 "evidence directory is not a regular directory"

TRACE="$RUN_DIR/overlay-trace.tsv"
PRE_MANIFEST="$RUN_DIR/preflight-manifest.txt"
RUNTIME_IDS="$RUN_DIR/runtime-identities.txt"
COMMANDS="$RUN_DIR/commands.txt"
PREFLIGHT_SNAPSHOT="$RUN_DIR/preflight-snapshot.txt"
CONFIGURE_LOG="$RUN_DIR/configure.log"
CONFIGURE_RC="$RUN_DIR/configure.rc"
POST_CONFIG_SNAPSHOT="$RUN_DIR/post-configure-snapshot.txt"
CACHE_FILE="$BUILD/CMakeCache.txt"
CACHE_EVIDENCE="$RUN_DIR/cmake-cache-validation.txt"
NINJA_FILE="$BUILD/build.ninja"
GRAPH_EVIDENCE="$RUN_DIR/build-ninja-graph.txt"
PREBUILD_SNAPSHOT="$RUN_DIR/pre-build-snapshot.txt"
BUILD_LOG="$RUN_DIR/build.log"
BUILD_RC="$RUN_DIR/build.rc"
ARTIFACT_FIND_RAW="$RUN_DIR/artifact-find.list0"
ARTIFACT_FIND_RC="$RUN_DIR/artifact-find.rc"
ARTIFACT_UNIQUENESS="$RUN_DIR/artifact-uniqueness.txt"
FILE_EVIDENCE="$RUN_DIR/artifact-file.txt"
READELF_EVIDENCE="$RUN_DIR/artifact-readelf-h.txt"
ARTIFACT_EVIDENCE="$RUN_DIR/artifact-identity.txt"
TRACE_SUMMARY="$RUN_DIR/overlay-trace-summary.txt"
POSTFLIGHT_SNAPSHOT="$RUN_DIR/postflight-snapshot.txt"
RESULT_FILE="$RUN_DIR/result.txt"
FINAL_STATE="$RUN_DIR/final-state.txt"

safe_new_text "$TRACE" "$TRACE_HEADER"$'\n'
export LANE198_TRACE_PATH="$TRACE"
export LANE198_APPROVED_COMMIT="$APPROVED_COMMIT"
export LANE198_APPROVED_WRAPPER_SHA256="$APPROVED_WRAPPER_SHA"
export LANE198_APPROVED_LAUNCHER_SHA256="$APPROVED_LAUNCHER_SHA"

STAGE="preflight_manifest"
safe_new_empty "$RUNTIME_IDS"
{
    printf 'approved_commit=%s\n' "$APPROVED_COMMIT"
    printf 'runtime_head=%s\n' "$SELF_HEAD"
    printf 'worktree=%s\n' "$WORKTREE"
    printf 'wrapper=%s\nwrapper_sha256=%s\nwrapper_blob=%s\n' "$SELF_EXPECTED" "$SELF_WRAPPER_SHA" "$SELF_WRAPPER_BLOB"
    printf 'launcher=%s\nlauncher_sha256=%s\nlauncher_blob=%s\n' "$LAUNCHER" "$SELF_LAUNCHER_SHA" "$SELF_LAUNCHER_BLOB"
} >> "$RUNTIME_IDS"

CONFIGURE=(cmake -S "$SRC" -B "$BUILD" -G Ninja
    -DCMAKE_BUILD_TYPE=Release
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN"
    -DANDROID_ABI=arm64-v8a
    -DANDROID_PLATFORM=android-24
    -DANDROID_PLATFORM_LEVEL=24
    -DANDROID_STL=c++_shared
    -DANDROID_USE_LEGACY_TOOLCHAIN_FILE=OFF
    -DCMAKE_CXX_COMPILER_LAUNCHER="$LAUNCHER"
    -DCMAKE_C_COMPILER_LAUNCHER=ccache
    -DCMAKE_DISABLE_SOURCE_CHANGES=ON
    -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY
    -DCMAKE_HAVE_LIBC_PTHREAD=1
    -DHAVE_LIBPTHREAD=0
    -DHAVE_LIBRT=0
    -DHAVE_PTHREAD_MUTEX_LOCK=1
    -DHAVE_PTHREAD_RWLOCK_INIT=1
    -DPTHREAD_IN_LIBC=1
    -DCURL_BROTLI=OFF
    -DCURL_ZSTD=OFF
    -DUSE_NGHTTP2=OFF
    -DLLVM_ENABLE_ZSTD=OFF
    -DLLVM_ENABLE_BACKTRACES=OFF
    -DLLVM_ENABLE_LIBEDIT=OFF
    -DLLVM_ENABLE_LIBXML2=OFF
    -DGAMEDECK_ICONV_LIBRARY="$PREFIX/lib/libiconv.a"
    -DGAMEDECK_CHARSET_LIBRARY="$PREFIX/lib/libcharset.a"
    -DZLIB_LIBRARY="$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/24/libz.so")
BUILD_CMD=(cmake --build "$BUILD" --target emu --parallel 1)

safe_new_empty "$COMMANDS"
{
    printf 'configure_command='; printf '%q ' "${CONFIGURE[@]}"; printf '\n'
    printf 'build_command='; printf '%q ' "${BUILD_CMD[@]}"; printf '\n'
} >> "$COMMANDS"

safe_new_empty "$PRE_MANIFEST"
{
    printf 'schema=LANE198_CANARY_LIBE_BUILD_V1\n'
    printf 'created_utc=%s\n' "$("$DATE" -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'run_dir=%s\ntrace=%s\nbuild_dir=%s\n' "$RUN_DIR" "$TRACE" "$BUILD"
    printf 'lane187_head=%s\ncellSpurs_sha256=%s\ncellSpursSpu_sha256=%s\n' "$HEAD187" "$SHA_A" "$SHA_B"
    printf 'canonical_head=%s\ncanonical_status_sha256=%s\n' "$CANON_HEAD" "$CANON_STATUS_SHA"
    printf 'canonical_cellSpurs_sha256=%s\ncanonical_cellSpursSpu_sha256=%s\n' "$CANON_SHA_A" "$CANON_SHA_B"
    printf 'ndk=%s\nndk_revision=%s\ntoolchain=%s\ntoolchain_sha256=%s\n' "$NDK" "$NDK_REV" "$TOOLCHAIN" "$TOOLCHAIN_SHA"
    printf 'abi=arm64-v8a\nandroid_platform=android-24\nplatform_level=24\nstl=c++_shared\nbuild_type=Release\ngenerator=Ninja\n'
    printf 'target=emu\nexpected_artifact=%s/libe.so\nparallel=1\n' "$BUILD"
    printf 'free_gate_kib=%s\n' "$MIN_KIB"
    printf 'claim=compile_link_only_no_runtime_correctness_or_playability_claim\n'
} >> "$PRE_MANIFEST"

STAGE="source_preflight"
snapshot_state preflight "$PREFLIGHT_SNAPSHOT" yes

STAGE="dedicated_build_dir_create"
[[ ! -e "$BUILD" && ! -L "$BUILD" ]] || die 128 "dedicated build dir already exists or is symlinked; refusing reuse: $BUILD"
if ! mkdir -m 700 -- "$BUILD"; then
    die 129 "cannot create dedicated build dir: $BUILD"
fi
[[ -d "$BUILD" && ! -L "$BUILD" ]] || die 130 "dedicated build path is not a regular directory"
if ! build_real=$("$READLINK" -f -- "$BUILD"); then
    die 131 "cannot resolve dedicated build dir"
fi
[[ "$build_real" == "$BUILD" ]] || die 132 "dedicated build dir canonical path mismatch: $build_real"

STAGE="configure"
safe_new_empty "$CONFIGURE_LOG"
set +e
"${CONFIGURE[@]}" >> "$CONFIGURE_LOG" 2>&1
configure_rc=$?
set -e
safe_new_text "$CONFIGURE_RC" "$configure_rc"$'\n'
if (( configure_rc != 0 )); then
    die "$configure_rc" "configure failed"
fi

STAGE="post_configure_identity_and_storage_gate"
snapshot_state post_configure "$POST_CONFIG_SNAPSHOT" yes

STAGE="cmake_cache_validation"
validate_cache

STAGE="ninja_graph_validation"
validate_graph

STAGE="pre_build_identity_and_storage_gate"
snapshot_state pre_build "$PREBUILD_SNAPSHOT" yes

STAGE="self_provenance_pre_build"
self_contract

STAGE="build_emu"
safe_new_empty "$BUILD_LOG"
set +e
"${BUILD_CMD[@]}" >> "$BUILD_LOG" 2>&1
build_rc=$?
set -e
safe_new_text "$BUILD_RC" "$build_rc"$'\n'
if (( build_rc != 0 )); then
    die "$build_rc" "build failed"
fi

STAGE="artifact_uniqueness"
OUT="$BUILD/libe.so"
safe_new_empty "$ARTIFACT_FIND_RAW"
set +e
"$FIND" "$BUILD" -name 'libe.so' -print0 >> "$ARTIFACT_FIND_RAW"
find_rc=$?
set -e
safe_new_text "$ARTIFACT_FIND_RC" "$find_rc"$'\n'
(( find_rc == 0 )) || die 133 "recursive artifact find failed rc=$find_rc"
libes=()
mapfile -d '' -t libes < "$ARTIFACT_FIND_RAW"
(( ${#libes[@]} == 1 )) || die 134 "expected exactly one libe.so anywhere under build tree; found ${#libes[@]}"
[[ "${libes[0]}" == "$OUT" ]] || die 135 "unique libe.so path is not exact root artifact: ${libes[0]}"
[[ -f "$OUT" && ! -L "$OUT" && -s "$OUT" ]] || die 136 "root libe.so is not a nonzero regular non-symlink file"
if ! out_real=$("$READLINK" -f -- "$OUT"); then
    die 137 "cannot resolve libe.so canonical path"
fi
[[ "$out_real" == "$OUT" ]] || die 138 "libe.so canonical path mismatch: $out_real"
safe_new_empty "$ARTIFACT_UNIQUENESS"
printf 'find_rc=%s\ncount=%s\nartifact=%s\ncanonical_path=%s\n' "$find_rc" "${#libes[@]}" "$OUT" "$out_real" >> "$ARTIFACT_UNIQUENESS"

STAGE="elf_validation"
safe_new_empty "$FILE_EVIDENCE"
if ! "$FILE_CMD" "$OUT" >> "$FILE_EVIDENCE"; then
    die 139 "file(1) evidence command failed"
fi
safe_new_empty "$READELF_EVIDENCE"
if ! "$READELF" -h "$OUT" >> "$READELF_EVIDENCE"; then
    die 140 "readelf -h failed"
fi
"$GREP" -Eq '^[[:space:]]*Class:[[:space:]]+ELF64([[:space:]]|$)' "$READELF_EVIDENCE" || die 141 "readelf Class is not ELF64"
"$GREP" -Eq '^[[:space:]]*Type:[[:space:]]+DYN([[:space:]]|$|[[:space:]]*\()' "$READELF_EVIDENCE" || die 142 "readelf Type is not DYN"
"$GREP" -Eq '^[[:space:]]*Machine:[[:space:]]+AArch64([[:space:]]|$)' "$READELF_EVIDENCE" || die 143 "readelf Machine is not AArch64"
if ! artifact_sha=$(sha_file "$OUT"); then
    die 144 "artifact SHA256 failed"
fi
if ! artifact_bytes=$("$STAT" -c %s -- "$OUT"); then
    die 145 "artifact byte-size query failed"
fi
[[ "$artifact_bytes" =~ ^[0-9]+$ && "$artifact_bytes" -gt 0 ]] || die 146 "artifact byte size is invalid: $artifact_bytes"
safe_new_empty "$ARTIFACT_EVIDENCE"
printf 'artifact=%s\nsha256=%s\nbytes=%s\n' "$OUT" "$artifact_sha" "$artifact_bytes" >> "$ARTIFACT_EVIDENCE"

STAGE="strict_trace_validation"
validate_trace

STAGE="postflight_source_repo_ndk"
snapshot_state postflight "$POSTFLIGHT_SNAPSHOT" no

STAGE="postflight_self_provenance"
self_contract

STAGE="success_result"
safe_new_empty "$RESULT_FILE"
{
    printf 'rc=0\n'
    printf 'artifact=%s\nartifact_sha256=%s\nartifact_bytes=%s\n' "$OUT" "$artifact_sha" "$artifact_bytes"
    printf 'trace=%s\ntrace_summary=%s\n' "$TRACE" "$TRACE_SUMMARY"
    printf 'configure_rc=%s\nbuild_rc=%s\n' "$configure_rc" "$build_rc"
    printf 'claim=compile_link_only_no_runtime_correctness_or_playability_claim\n'
} >> "$RESULT_FILE"

FINAL_RESULT="PASS_COMPILE_LINK_ONLY"
STAGE="complete"
exit 0
