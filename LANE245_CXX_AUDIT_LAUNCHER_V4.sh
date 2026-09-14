#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

HOME_ROOT="/data/data/com.termux/files/home"
PREFIX="/data/data/com.termux/files/usr"
WT="$HOME_ROOT/projects/android/gamedeck-ps3-prod-lanes-20260912/lane245-bink-build-gate-v4"
SELF="$WT/LANE245_CXX_AUDIT_LAUNCHER_V4.sh"
WRAPPER="$WT/LANE245_BUILD_WRAPPER_V4.sh"
CANON="$HOME_ROOT/projects/android/gamedeck/mobile/android/vendor/aps3e-source"
TRACE="${LANE245_CXX_TRACE:-}"
BASE241="b2d9b893aaf546b7fa65cc07a094ea11f71800d9"

GIT="$PREFIX/bin/git"
SHA256SUM="$PREFIX/bin/sha256sum"
READLINK="$PREFIX/bin/readlink"
CCACHE="$PREFIX/bin/ccache"
CCACHE_SHA="cef760b84c3143a70d15b4bc38edd52f85f8f01eec58db40eb80f14eb27a35ed"

APPROVED_COMMIT="${LANE245_APPROVED_COMMIT:-}"
APPROVED_WRAPPER_SHA="${LANE245_APPROVED_WRAPPER_SHA256:-}"
APPROVED_LAUNCHER_SHA="${LANE245_APPROVED_LAUNCHER_SHA256:-}"

fail() {
    local rc="$1"; shift
    printf 'LANE245_CXX_AUDIT_FAIL rc=%s %s\n' "$rc" "$*" >&2
    exit "$rc"
}

sha_file() {
    local out
    out=$("$SHA256SUM" -- "$1") || return 1
    printf '%s\n' "${out%% *}"
}

[[ "$APPROVED_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail 70 'LANE245_APPROVED_COMMIT missing/invalid'
[[ "$APPROVED_WRAPPER_SHA" =~ ^[0-9a-f]{64}$ ]] || fail 71 'LANE245_APPROVED_WRAPPER_SHA256 missing/invalid'
[[ "$APPROVED_LAUNCHER_SHA" =~ ^[0-9a-f]{64}$ ]] || fail 72 'LANE245_APPROVED_LAUNCHER_SHA256 missing/invalid'
[[ $# -ge 1 ]] || fail 73 'compiler argument missing'
[[ -n "$TRACE" && -f "$TRACE" && ! -L "$TRACE" ]] || fail 74 'trace file missing/unsafe'
[[ -f "$SELF" && ! -L "$SELF" && -x "$SELF" ]] || fail 75 'launcher identity unsafe'
[[ -f "$WRAPPER" && ! -L "$WRAPPER" && -x "$WRAPPER" ]] || fail 76 'wrapper identity unsafe'
[[ "$("$GIT" -C "$WT" rev-parse HEAD)" == "$APPROVED_COMMIT" ]] || fail 77 'worktree HEAD != approved commit'
[[ "$("$GIT" -C "$WT" show -s --format=%P HEAD)" == "$BASE241" ]] || fail 78 'approved commit is not the single Lane241-child v4 correction'
[[ "$(sha_file "$SELF")" == "$APPROVED_LAUNCHER_SHA" ]] || fail 79 'launcher SHA mismatch'
[[ "$(sha_file "$WRAPPER")" == "$APPROVED_WRAPPER_SHA" ]] || fail 80 'wrapper SHA mismatch'
[[ "$("$GIT" -C "$WT" hash-object "$SELF")" == "$("$GIT" -C "$WT" rev-parse "$APPROVED_COMMIT:LANE245_CXX_AUDIT_LAUNCHER_V4.sh")" ]] || fail 81 'launcher differs from approved Git blob'
[[ "$("$GIT" -C "$WT" hash-object "$WRAPPER")" == "$("$GIT" -C "$WT" rev-parse "$APPROVED_COMMIT:LANE245_BUILD_WRAPPER_V4.sh")" ]] || fail 82 'wrapper differs from approved Git blob'

compiler="$1"; shift
[[ -f "$CCACHE" && ! -L "$CCACHE" && -x "$CCACHE" ]] || fail 87 'ccache path unsafe'
[[ "$(sha_file "$CCACHE")" == "$CCACHE_SHA" ]] || fail 88 'ccache hash changed before compiler execution'
[[ "$compiler" == "$PREFIX/bin/c++" ]] || fail 85 "unexpected CXX compiler path: $compiler"
[[ "$(sha_file "$compiler")" == "3599a121ecc11b433d23bc43545bc0441f9a8ffcc587ea18e312d88188fcf282" ]] || fail 86 'CXX compiler hash changed after graph approval'
args=("$@")
count=0
for arg in "${args[@]}"; do
    [[ -e "$arg" ]] || continue
    real=$("$READLINK" -f -- "$arg" 2>/dev/null || true)
    case "$real" in
        "$WT/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules/cellSpurs.cpp")
            tu=cellSpurs.cpp; want=0069fcba05a009b93663006d0d9047521ec6b2fe465ee0c55aea8f70c957305d ;;
        "$WT/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules/cellSpursSpu.cpp")
            tu=cellSpursSpu.cpp; want=f5ae5b6e8e19884382399f5b76980f5e6e6d253d6b0b94bdfe3dcfbf0a4d6570 ;;
        "$WT/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/SPULLVMRecompiler.cpp")
            tu=SPULLVMRecompiler.cpp; want=2d6b4fa079d5721bb96dab46395cc189096c58b7088877fc134cc6d2cb124009 ;;
        "$WT/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/SPUThread.cpp")
            tu=SPUThread.cpp; want=2979bb64cdcf34e540279b72282f08a250e1db0103f557cab9313d6c52914bc0 ;;
        "$CANON/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules/cellSpurs.cpp"|\
        "$CANON/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules/cellSpursSpu.cpp"|\
        "$CANON/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/SPULLVMRecompiler.cpp"|\
        "$CANON/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/SPUThread.cpp")
            fail 83 "canonical target TU leaked into candidate build: $real" ;;
        *)
            continue ;;
    esac
    [[ "$(sha_file "$real")" == "$want" ]] || fail 84 "candidate hash mismatch: $tu"
    printf '%s\t%s\t%s\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tu" "$want" "$real" >> "$TRACE"
    ((count+=1))
done

exec "$CCACHE" "$compiler" "${args[@]}"
