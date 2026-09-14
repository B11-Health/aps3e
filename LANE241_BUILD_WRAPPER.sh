#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
umask 077

HOME_ROOT="/data/data/com.termux/files/home"
PREFIX="/data/data/com.termux/files/usr"
WT="$HOME_ROOT/projects/android/gamedeck-ps3-prod-lanes-20260912/lane241-bink-build-gate-v3"
SELF="$WT/LANE241_BUILD_WRAPPER.sh"
LAUNCHER="$WT/LANE241_CXX_AUDIT_LAUNCHER.sh"
SRC="$WT/app/src/main/cpp"
CANON="$HOME_ROOT/projects/android/gamedeck/mobile/android/vendor/aps3e-source"
CANON_SRC="$CANON/app/src/main/cpp"
GUARD="$HOME_ROOT/.local/bin/gd-team-heavy"
HEAVY_LOCK="$HOME_ROOT/.cache/gd-team-heavy.lock"
HEAVY_STATE="$HOME_ROOT/.cache/gd-team-heavy.state"
HEAVY_LABEL="lane241-bink-build-gate-v3"

LANE220="46679d67d140a59599ae43ba5f2efb5597d6e743"
LANE230="d774c1af0a45c10ba7726b73ab634f91609838a7"
LANE237_PARENT="d787644dc8c1c5076047dd6b36c8bfff659a85db"
CANON_HEAD="7dc95e6baaac0712d5b3c28501778dd7934e579b"
CANON_STATUS_SHA="3381452a0a288719e1056a5a7bce2f624bef99fde054387253a276fc43587d66"
GUARD_SHA="5f76d17fcf85469d2bdcfb2c63c632bab4583a8392263ddac3c5d940b3c35001"
LAUNCHER_DESIGN_SHA="2b406fd592008160db5716598b9a345b193520b0971fad048ac6f9979fd5d3c0"

CMAKE_BIN="$PREFIX/bin/cmake"
CMAKE_VERSION="4.4.1"
CMAKE_SHA="07c5f6bfdc48dd4f79085438ce4ab4b467313f31c9aadf5125fc3fd69ee0e682"
CMAKE_ROOT="$PREFIX/share/cmake-4.4"
CMAKE_DETERMINE_SYSTEM="$CMAKE_ROOT/Modules/CMakeDetermineSystem.cmake"
CMAKE_ANDROID_DETERMINE="$CMAKE_ROOT/Modules/Platform/Android-Determine.cmake"
CMAKE_ANDROID_DETERMINE_C="$CMAKE_ROOT/Modules/Platform/Android-Determine-C.cmake"
CMAKE_ANDROID_DETERMINE_CXX="$CMAKE_ROOT/Modules/Platform/Android-Determine-CXX.cmake"
CMAKE_DETERMINE_SYSTEM_SHA="c9a0e1cd987f813b8138039b12f5cdee70f3c7db1534c9853f3ab1c083d2276d"
CMAKE_ANDROID_DETERMINE_SHA="e8569c136777626c7252438d0ea57a8089f8fb45de5e0c04dd9583b1239775a3"
CMAKE_ANDROID_DETERMINE_C_SHA="1939341111e9b7382f8afcf222e12233235323b43620f2175bf54ef0b45997ce"
CMAKE_ANDROID_DETERMINE_CXX_SHA="dfa74e48fe90a5189982784b9d4c1c310f1c257bdb36349b61ece1ad4e5c8164"

NDK="$HOME_ROOT/android-sdk/ndk-r29-local"
NDK_REV="29.0.14206865"
NDK_SOURCE_PROPERTIES_SHA="716f3518a923198cfab037abb32dc3f1b1f7e9a9dcdcda6b66be5906215d2658"
TOOLCHAIN="$NDK/build/cmake/android.toolchain.cmake"
TOOLCHAIN_SHA="dbad92d9dcfea0d32b7c5e5f82f5072d878ded5d46a5d3f1f581ea108ca7fe89"
SYSROOT="$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
TOOLCHAIN_SYSROOT_ALIAS="$NDK/toolchains/llvm/prebuilt/sysroot"
UNWIND="$SYSROOT/usr/lib/aarch64-linux-android/24/libunwind.a"
UNWIND_SHA="c52c8462134a1610e93d873e9d992f4804027d0c73115b2ea4c21b0aed5cbe65"
ZLIB="$SYSROOT/usr/lib/aarch64-linux-android/24/libz.so"
ZLIB_SHA="1399497eaea6e1dd0e9e8e13439890e8ca9695bbd801e1085e945e207a00aaa6"
VULKAN="$SYSROOT/usr/lib/aarch64-linux-android/24/libvulkan.so"
VULKAN_SHA="f0906b4f9f4e67e1d0078a737f7fe466ce4a239b028cbfdb9256ea320670b43b"

CC="$PREFIX/bin/cc"
CXX="$PREFIX/bin/c++"
LD_LLD="$PREFIX/bin/ld.lld"
LLVM_AR="$PREFIX/bin/llvm-ar"
LLVM_RANLIB="$PREFIX/bin/llvm-ranlib"
LLVM_STRIP="$PREFIX/bin/llvm-strip"
CC_SHA="3599a121ecc11b433d23bc43545bc0441f9a8ffcc587ea18e312d88188fcf282"
CXX_SHA="$CC_SHA"
LD_LLD_SHA="7a0e3dad3eaeaf7ec0e85337ab1047470141e95aae11e4b51eb12c749c1a561a"
LLVM_AR_SHA="a43266eaab0bbd4eabf2127f796015c46897044748bcc50976421fc116f37798"
LLVM_RANLIB_SHA="$LLVM_AR_SHA"
LLVM_STRIP_SHA="b1196f21e347a912662b0bea76ad97c60f758e68c612b58006d505182a679392"

BUILD="$HOME_ROOT/.cache/gd-lane241-bink-build-gate-v3"
RUN="$HOME_ROOT/.cache/gd-lane237-bink-putllc-run-$(date -u +%Y%m%dT%H%M%SZ)-$$"
MIN_KIB=4194304

APPROVED_COMMIT="${LANE241_APPROVED_COMMIT:-}"
APPROVED_WRAPPER_SHA="${LANE241_APPROVED_WRAPPER_SHA256:-}"
APPROVED_LAUNCHER_SHA="${LANE241_APPROVED_LAUNCHER_SHA256:-}"

STAGE=startup
fail() {
    local rc="$1"; shift
    printf 'LANE241_FAIL stage=%s rc=%s %s\n' "$STAGE" "$rc" "$*" >&2
    exit "$rc"
}
sha_file() {
    local out
    out=$(sha256sum -- "$1") || return 1
    printf '%s\n' "${out%% *}"
}

STAGE=heavy_guard
[[ -f "$GUARD" && ! -L "$GUARD" && -x "$GUARD" ]] || fail 60 'gd-team-heavy missing/unsafe'
[[ "$(sha_file "$GUARD")" == "$GUARD_SHA" ]] || fail 61 'gd-team-heavy hash changed; re-review guard contract'
[[ -f "$HEAVY_STATE" && ! -L "$HEAVY_STATE" ]] || fail 62 'must execute under active gd-team-heavy state'
read -r pid_tok label_tok started_tok extra < "$HEAVY_STATE" || fail 63 'cannot parse gd-team-heavy state'
[[ -z "${extra:-}" ]] || fail 64 'unexpected gd-team-heavy state format'
state_pid="${pid_tok#pid=}"
state_label="${label_tok#label=}"
[[ "$pid_tok" == pid=* && "$state_pid" =~ ^[0-9]+$ && "$state_pid" -gt 1 ]] || fail 65 'invalid gd-team-heavy state pid'
[[ "$label_tok" == label=* && "$state_label" == "$HEAVY_LABEL" ]] || fail 66 "gd-team-heavy label mismatch: $state_label"
[[ -r "/proc/$state_pid/stat" ]] || fail 67 'gd-team-heavy state pid is not live/readable'
state_cmd=$(tr '\0' ' ' < "/proc/$state_pid/cmdline" 2>/dev/null || true)
[[ "$state_cmd" == *"gd-team-heavy"* ]] || fail 68 'state pid is not gd-team-heavy'
fd9=$(readlink -f "/proc/$state_pid/fd/9" 2>/dev/null || true)
[[ "$fd9" == "$HEAVY_LOCK" ]] || fail 69 'gd-team-heavy state pid does not hold expected fd9 lock file'
ancestor="$$"; found_ancestor=0
for _ in $(seq 1 16); do
    [[ "$ancestor" == "$state_pid" ]] && { found_ancestor=1; break; }
    [[ -r "/proc/$ancestor/stat" ]] || break
    ancestor=$(awk '{print $4}' "/proc/$ancestor/stat" 2>/dev/null || echo 0)
    [[ "$ancestor" =~ ^[0-9]+$ && "$ancestor" -gt 1 ]] || break
done
[[ "$found_ancestor" == 1 ]] || fail 70 'active gd-team-heavy pid is not an ancestor of this wrapper'
if flock -n "$HEAVY_LOCK" -c true >/dev/null 2>&1; then
    fail 71 'global heavy lock is not actually contended/held'
fi

STAGE=approved_identity
[[ "$APPROVED_COMMIT" =~ ^[0-9a-f]{40}$ ]] || fail 72 'LANE241_APPROVED_COMMIT missing/invalid'
[[ "$APPROVED_WRAPPER_SHA" =~ ^[0-9a-f]{64}$ ]] || fail 73 'LANE241_APPROVED_WRAPPER_SHA256 missing/invalid'
[[ "$APPROVED_LAUNCHER_SHA" =~ ^[0-9a-f]{64}$ ]] || fail 74 'LANE241_APPROVED_LAUNCHER_SHA256 missing/invalid'
[[ "$APPROVED_LAUNCHER_SHA" == "$LAUNCHER_DESIGN_SHA" ]] || fail 75 'approved launcher hash != reviewed Lane241 launcher design'
[[ -f "$SELF" && ! -L "$SELF" && -x "$SELF" ]] || fail 76 'wrapper path unsafe'
[[ -f "$LAUNCHER" && ! -L "$LAUNCHER" && -x "$LAUNCHER" ]] || fail 77 'launcher path unsafe'
[[ "$(readlink -f "$SELF")" == "$SELF" ]] || fail 78 'wrapper invoked from unexpected path'
wrapper_sha=$(sha_file "$SELF") || fail 79 'wrapper hash failed'
launcher_sha=$(sha_file "$LAUNCHER") || fail 80 'launcher hash failed'
[[ "$wrapper_sha" == "$APPROVED_WRAPPER_SHA" ]] || fail 81 'runtime wrapper hash != approved hash'
[[ "$launcher_sha" == "$APPROVED_LAUNCHER_SHA" ]] || fail 82 'runtime launcher hash != approved hash'
head=$(git -C "$WT" rev-parse HEAD) || fail 83 'Lane241 rev-parse failed'
[[ "$head" == "$APPROVED_COMMIT" ]] || fail 84 "Lane241 HEAD != approved commit: $head"
[[ "$(git -C "$WT" symbolic-ref --short HEAD)" == "team/lane241-bink-build-gate-v3" ]] || fail 85 'Lane241 branch mismatch'
[[ "$(git -C "$WT" show -s --format=%P HEAD)" == "$LANE237_PARENT" ]] || fail 86 'Lane241 approved HEAD must be exactly one commit atop Lane237'
git -C "$WT" merge-base --is-ancestor "$LANE220" "$head" || fail 87 'Lane220 is not ancestor of Lane241'
[[ -z "$(git -C "$WT" status --porcelain=v1 -uall)" ]] || fail 88 'Lane241 worktree must be clean'
[[ "$(git -C "$WT" hash-object "$SELF")" == "$(git -C "$WT" rev-parse "$APPROVED_COMMIT:LANE241_BUILD_WRAPPER.sh")" ]] || fail 89 'wrapper differs from approved Git blob'
[[ "$(git -C "$WT" hash-object "$LAUNCHER")" == "$(git -C "$WT" rev-parse "$APPROVED_COMMIT:LANE241_CXX_AUDIT_LAUNCHER.sh")" ]] || fail 90 'launcher differs from approved Git blob'

git -C "$WT" diff --quiet "$LANE237_PARENT" "$head" -- app/src/main/cpp || fail 91 'Lane241 altered Lane237 candidate source tree'
expected_diff=$'M\tapp/src/main/cpp/rpcs3/rpcs3/Emu/CMakeLists.txt\nM\tapp/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules/cellSpurs.cpp\nM\tapp/src/main/cpp/rpcs3/rpcs3/Emu/Cell/Modules/cellSpursSpu.cpp\nM\tapp/src/main/cpp/rpcs3/rpcs3/Emu/Cell/SPULLVMRecompiler.cpp\nM\tapp/src/main/cpp/rpcs3/rpcs3/Emu/Cell/SPUThread.cpp\nA\tapp/src/main/cpp/rpcs3/rpcs3/Emu/Cell/spurs_live_canary.h'
actual_diff=$(git -C "$WT" diff --name-status "$CANON_HEAD" "$head" -- app/src/main/cpp)
[[ "$actual_diff" == "$expected_diff" ]] || fail 92 'candidate native-source divergence is not the exact reviewed six-file Lane220 lineage'

STAGE=source_hashes
check_hash() { [[ "$(sha_file "$1")" == "$2" ]] || fail "$3" "hash mismatch: $1"; }
check_hash "$SRC/rpcs3/rpcs3/Emu/CMakeLists.txt" 22927b0d3f0332b8fa26ea18dd2c1d3eab8a25a2848195acd13ef261b858c97d 93
check_hash "$SRC/rpcs3/rpcs3/Emu/Cell/Modules/cellSpurs.cpp" 0069fcba05a009b93663006d0d9047521ec6b2fe465ee0c55aea8f70c957305d 94
check_hash "$SRC/rpcs3/rpcs3/Emu/Cell/Modules/cellSpursSpu.cpp" f5ae5b6e8e19884382399f5b76980f5e6e6d253d6b0b94bdfe3dcfbf0a4d6570 95
check_hash "$SRC/rpcs3/rpcs3/Emu/Cell/SPULLVMRecompiler.cpp" 2d6b4fa079d5721bb96dab46395cc189096c58b7088877fc134cc6d2cb124009 96
check_hash "$SRC/rpcs3/rpcs3/Emu/Cell/SPUThread.cpp" 2979bb64cdcf34e540279b72282f08a250e1db0103f557cab9313d6c52914bc0 97
check_hash "$SRC/rpcs3/rpcs3/Emu/Cell/spurs_live_canary.h" 69982b9d1a12e87cbe94954b92487f6122b213cec24b40d08ea30851f5f01c8a 98
[[ "$(grep -Fc 'target_compile_definitions(rpcs3_emu PUBLIC ANDROID)' "$SRC/rpcs3/rpcs3/Emu/CMakeLists.txt")" -eq 1 ]] || fail 99 'Lane220 ANDROID runtime macro lineage missing/duplicated'

STAGE=canonical_identity
[[ "$(git -C "$CANON" rev-parse HEAD)" == "$CANON_HEAD" ]] || fail 100 'canonical HEAD changed'
[[ "$(git -C "$CANON" status --porcelain=v1 -uall | sha256sum | awk '{print $1}')" == "$CANON_STATUS_SHA" ]] || fail 101 'canonical worktree status changed'

STAGE=cmake_identity
[[ -f "$CMAKE_BIN" && ! -L "$CMAKE_BIN" && -x "$CMAKE_BIN" ]] || fail 102 'pinned CMake executable missing/unsafe'
check_hash "$CMAKE_BIN" "$CMAKE_SHA" 103
[[ "$($CMAKE_BIN --version | sed -n '1s/^cmake version //p')" == "$CMAKE_VERSION" ]] || fail 104 'CMake version mismatch'
check_hash "$CMAKE_DETERMINE_SYSTEM" "$CMAKE_DETERMINE_SYSTEM_SHA" 105
check_hash "$CMAKE_ANDROID_DETERMINE" "$CMAKE_ANDROID_DETERMINE_SHA" 106
check_hash "$CMAKE_ANDROID_DETERMINE_C" "$CMAKE_ANDROID_DETERMINE_C_SHA" 107
check_hash "$CMAKE_ANDROID_DETERMINE_CXX" "$CMAKE_ANDROID_DETERMINE_CXX_SHA" 108
[[ "$(uname -o)" == "Android" ]] || fail 109 'host OS identity is no longer Android'
[[ "$(uname -m)" == "aarch64" ]] || fail 110 'host processor identity is no longer aarch64'
grep -Fq 'elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Android")' "$CMAKE_DETERMINE_SYSTEM" || fail 111 'CMake Android host-detection branch missing'
grep -Fq 'if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Android")' "$CMAKE_ANDROID_DETERMINE" || fail 112 'Android host early-return condition missing'
awk 'BEGIN{ok=0} /if\(CMAKE_HOST_SYSTEM_NAME STREQUAL "Android"\)/{seen=1;next} seen && /return\(\)/{ok=1;exit} END{exit ok?0:1}' "$CMAKE_ANDROID_DETERMINE" || fail 113 'Android host early-return ordering changed'
awk 'NR==1 && $0=="if(CMAKE_C_COMPILER)"{a=1} NR==2 && $0=="  return()"{b=1} END{exit (a&&b)?0:1}' "$CMAKE_ANDROID_DETERMINE_C" || fail 114 'explicit C compiler early-return changed'
awk 'NR==1 && $0=="if(CMAKE_CXX_COMPILER)"{a=1} NR==2 && $0=="  return()"{b=1} END{exit (a&&b)?0:1}' "$CMAKE_ANDROID_DETERMINE_CXX" || fail 115 'explicit CXX compiler early-return changed'

STAGE=ndk_identity
[[ -d "$NDK" && ! -L "$NDK" ]] || fail 102 'full ndk-r29-local missing/unsafe'
[[ -f "$NDK/source.properties" && ! -L "$NDK/source.properties" ]] || fail 103 'NDK source.properties missing/unsafe'
check_hash "$NDK/source.properties" "$NDK_SOURCE_PROPERTIES_SHA" 104
grep -Fxq "Pkg.Revision = $NDK_REV" "$NDK/source.properties" || fail 105 'NDK revision mismatch'
[[ -f "$TOOLCHAIN" && ! -L "$TOOLCHAIN" ]] || fail 106 'stock NDK toolchain missing/unsafe'
check_hash "$TOOLCHAIN" "$TOOLCHAIN_SHA" 107
[[ -L "$TOOLCHAIN_SYSROOT_ALIAS" && "$(readlink "$TOOLCHAIN_SYSROOT_ALIAS")" == 'linux-x86_64/sysroot' ]] || fail 108 'NDK prebuilt/sysroot compatibility link changed'
[[ "$(readlink -f "$TOOLCHAIN_SYSROOT_ALIAS")" == "$SYSROOT" ]] || fail 109 'NDK sysroot alias does not resolve to pinned full sysroot'
for spec in \
    "clang|$CC" \
    "clang++|$CXX" \
    "ld.lld|$LD_LLD" \
    "llvm-ar|$LLVM_AR" \
    "llvm-ranlib|$LLVM_RANLIB" \
    "llvm-strip|$LLVM_STRIP"; do
    name=${spec%%|*}; target=${spec#*|}
    link="$NDK/toolchains/llvm/prebuilt/bin/$name"
    [[ -L "$link" && "$(readlink "$link")" == "$target" ]] || fail 110 "NDK compatibility link changed: $name"
done
check_hash "$CC" "$CC_SHA" 111
check_hash "$CXX" "$CXX_SHA" 112
check_hash "$LD_LLD" "$LD_LLD_SHA" 113
check_hash "$LLVM_AR" "$LLVM_AR_SHA" 114
check_hash "$LLVM_RANLIB" "$LLVM_RANLIB_SHA" 115
check_hash "$LLVM_STRIP" "$LLVM_STRIP_SHA" 116
[[ -L "$UNWIND" && "$(readlink "$UNWIND")" == "$PREFIX/lib/libunwind.a" ]] || fail 117 'API24 libunwind correction changed'
check_hash "$UNWIND" "$UNWIND_SHA" 118
check_hash "$ZLIB" "$ZLIB_SHA" 119
check_hash "$VULKAN" "$VULKAN_SHA" 120

STAGE=resource_gate
[[ ! -e "$BUILD" && ! -L "$BUILD" ]] || fail 121 "fresh build dir required: $BUILD"
FREE=$(df -Pk /data | awk 'END{print $4}')
(( FREE >= MIN_KIB )) || fail 122 "free-space gate: $FREE < $MIN_KIB KiB"
for t in ninja ccache git sha256sum readelf file strings flock readlink awk grep sed uname; do command -v "$t" >/dev/null 2>&1 || fail 123 "missing tool $t"; done

STAGE=prepare
mkdir -m 700 "$RUN" "$BUILD"
TRACE="$RUN/cxx-audit.tsv"
: > "$TRACE"
chmod 600 "$TRACE"
export LANE241_CXX_TRACE="$TRACE"
export LANE241_APPROVED_COMMIT="$APPROVED_COMMIT"
export LANE241_APPROVED_WRAPPER_SHA256="$APPROVED_WRAPPER_SHA"
export LANE241_APPROVED_LAUNCHER_SHA256="$APPROVED_LAUNCHER_SHA"
printf 'approved_commit=%s\nwrapper_sha256=%s\nlauncher_sha256=%s\ncanon_head=%s\ncmake=%s\ncmake_version=%s\ncmake_sha256=%s\nhost_os=%s\nhost_arch=%s\nndk=%s\ntoolchain_sha256=%s\nsysroot=%s\nfree_kib=%s\n' \
    "$APPROVED_COMMIT" "$wrapper_sha" "$launcher_sha" "$CANON_HEAD" "$CMAKE_BIN" "$CMAKE_VERSION" "$CMAKE_SHA" "$(uname -o)" "$(uname -m)" "$NDK" "$TOOLCHAIN_SHA" "$SYSROOT" "$FREE" > "$RUN/preflight.txt"

STAGE=configure
env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u OBJC_INCLUDE_PATH -u LIBRARY_PATH -u CMAKE_PREFIX_PATH -u CMAKE_LIBRARY_PATH -u CMAKE_INCLUDE_PATH \
    PKG_CONFIG_DIR= PKG_CONFIG_PATH= \
    PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/aarch64-linux-android/pkgconfig:$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig" \
    PKG_CONFIG_SYSROOT_DIR="$SYSROOT" \
    "$CMAKE_BIN" -S "$SRC" -B "$BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN" \
    -DANDROID_NDK="$NDK" \
    -DCMAKE_SYSROOT="$SYSROOT" \
    -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX" \
    -DCMAKE_FIND_ROOT_PATH="$SYSROOT" \
    -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
    -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
    -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
    -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DANDROID_PLATFORM_LEVEL=24 \
    -DANDROID_STL=c++_shared -DANDROID_USE_LEGACY_TOOLCHAIN_FILE=OFF \
    -DCMAKE_CXX_COMPILER_LAUNCHER="$LAUNCHER" -DCMAKE_C_COMPILER_LAUNCHER=ccache \
    -DCMAKE_DISABLE_SOURCE_CHANGES=ON -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
    -DCMAKE_HAVE_LIBC_PTHREAD=1 -DHAVE_LIBPTHREAD=0 -DHAVE_LIBRT=0 \
    -DHAVE_PTHREAD_MUTEX_LOCK=1 -DHAVE_PTHREAD_RWLOCK_INIT=1 -DPTHREAD_IN_LIBC=1 \
    -DCURL_BROTLI=OFF -DCURL_ZSTD=OFF -DUSE_NGHTTP2=OFF \
    -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_BACKTRACES=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_LIBXML2=OFF \
    -DGAMEDECK_ICONV_LIBRARY:FILEPATH= -DGAMEDECK_CHARSET_LIBRARY:FILEPATH= \
    -DVulkan_LIBRARY:FILEPATH="$VULKAN" -DZLIB_LIBRARY:FILEPATH="$ZLIB" \
    >"$RUN/configure.log" 2>&1 || fail 130 'configure failed'

STAGE=graph_gate
CACHE="$BUILD/CMakeCache.txt"; RULES="$BUILD/CMakeFiles/rules.ninja"; NINJA="$BUILD/build.ninja"
[[ -f "$CACHE" && -f "$RULES" && -f "$NINJA" ]] || fail 131 'generated graph incomplete'
grep -Fq "CMAKE_HOME_DIRECTORY:INTERNAL=$SRC" "$CACHE" || fail 132 'configure did not consume Lane241 isolated source tree'
grep -Fq "CMAKE_TOOLCHAIN_FILE:FILEPATH=$TOOLCHAIN" "$CACHE" || fail 133 'wrong toolchain file in cache'
grep -Eq "CMAKE_C_COMPILER:(FILEPATH|STRING)=$CC" "$CACHE" || fail 134 'wrong C compiler'
grep -Eq "CMAKE_CXX_COMPILER:(FILEPATH|STRING)=$CXX" "$CACHE" || fail 135 'wrong CXX compiler'
grep -Fq "$SRC/rpcs3/rpcs3/Emu/CMakeLists.txt" "$NINJA" || fail 136 'candidate Emu/CMakeLists.txt absent from regeneration graph'
grep -Fq -- '-DANDROID' "$NINJA" || fail 137 'Lane220 ANDROID compile definition absent from generated graph'
if ! grep -Fq -- "--sysroot=$NDK/toolchains/llvm/prebuilt//sysroot" "$RULES" && ! grep -Fq -- "--sysroot=$SYSROOT" "$RULES"; then
    fail 138 'generated compiler rules do not use pinned full-NDK sysroot'
fi
if grep -E "ndk-r29-arm64-local|\.ndk-r29-local-repair-20260914|/data/data/com\.termux/files/usr/(include|lib/)|-L ?/data/data/com\.termux/files/usr/lib|lib(execinfo|z\.so\.1|vulkan\.so\.1|xml2|nghttp2|zstd)" "$NINJA" "$RULES" > "$RUN/forbidden-graph.txt"; then
    fail 139 'stale NDK/partial-repair/Termux target dependency leaked into Android graph'
fi

STAGE=build
env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u OBJC_INCLUDE_PATH -u LIBRARY_PATH -u CMAKE_PREFIX_PATH -u CMAKE_LIBRARY_PATH -u CMAKE_INCLUDE_PATH \
    "$CMAKE_BIN" --build "$BUILD" --target emu --parallel 1 >"$RUN/build.log" 2>&1 || fail 140 'build failed'

STAGE=artifact
ART="$BUILD/libe.so"
[[ -f "$ART" && ! -L "$ART" ]] || fail 141 'libe.so missing/unsafe'
for tu in cellSpurs.cpp cellSpursSpu.cpp SPULLVMRecompiler.cpp SPUThread.cpp; do
    [[ "$(awk -F'\t' -v t="$tu" '$2==t{n++} END{print n+0}' "$TRACE")" -eq 1 ]] || fail 142 "CXX audit count != 1 for $tu"
done
[[ "$(wc -l < "$TRACE")" -eq 4 ]] || fail 143 'unexpected CXX audit entries'
file "$ART" > "$RUN/file.txt"
readelf -d "$ART" > "$RUN/dynamic.txt"
grep -q 'AArch64' "$RUN/file.txt" || fail 144 'artifact is not AArch64'
! grep -Eq 'RPATH|RUNPATH|libz\.so\.1|libvulkan\.so\.1|libexecinfo|libxml2|libnghttp2|libzstd' "$RUN/dynamic.txt" || fail 145 'forbidden runtime dependency/RPATH'
[[ "$(strings -a "$ART" | grep -c 'BINK_PUTLLC_CANARY' || true)" -eq 1 ]] || fail 146 'BINK_PUTLLC_CANARY string count != 1'
SHA=$(sha_file "$ART"); BYTES=$(stat -c %s "$ART")
printf 'RESULT=PASS_BUILD_ONLY\nartifact=%s\nsha256=%s\nbytes=%s\nrun=%s\n' "$ART" "$SHA" "$BYTES" "$RUN" | tee "$RUN/result.txt"
