#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail
HOME_ROOT="/data/data/com.termux/files/home"
PREFIX_ROOT="/data/data/com.termux/files/usr"
WT="/data/data/com.termux/files/home/projects/android/gamedeck-ps3-prod-lanes-20260912/lane230-bink-putllc-build"
CANON="/data/data/com.termux/files/home/projects/android/gamedeck/mobile/android/vendor/aps3e-source"
SRC="$CANON/app/src/main/cpp"
CAND="$WT/app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/SPUThread.cpp"
CANON_SPU="$SRC/rpcs3/rpcs3/Emu/Cell/SPUThread.cpp"
LAUNCHER="$WT/LANE230_OVERLAY_CXX_LAUNCHER.sh"
NDK="$HOME_ROOT/android-sdk/ndk-r29-arm64-local"
TOOLCHAIN="$NDK/build/cmake/android.toolchain.cmake"
SYSROOT="$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
BUILD="$HOME_ROOT/.cache/gd-lane230-putllc-build"
RUN="$HOME_ROOT/.cache/gd-lane230-putllc-run-$(date -u +%Y%m%dT%H%M%SZ)-$$"
MIN_KIB=4194304
PIN_BASE="46679d67d140a59599ae43ba5f2efb5597d6e743"
PIN_CANON_HEAD="7dc95e6baaac0712d5b3c28501778dd7934e579b"
PIN_CANON_STATUS="3381452a0a288719e1056a5a7bce2f624bef99fde054387253a276fc43587d66"
PIN_CANON_SPU="54d38ae502dfc82b9ff74c218947fec6c86b07cda8891ab008c7cc00306db121"
PIN_CAND_SPU="2979bb64cdcf34e540279b72282f08a250e1db0103f557cab9313d6c52914bc0"
PIN_TOOLCHAIN="88f31142c4a28b0a9f09235998af3f857c23b91c227eb57b32fb15aa574184b3"
fail(){ echo "LANE230_FAIL stage=${STAGE:-preflight} rc=$1 ${*:2}" >&2; exit "$1"; }
STAGE=preflight
[[ ! -e "$BUILD" ]] || fail 101 "fresh build dir required: $BUILD"
[[ -f "$TOOLCHAIN" && ! -L "$TOOLCHAIN" ]] || fail 102 'toolchain missing/symlinked'
[[ "$(sha256sum "$TOOLCHAIN"|awk '{print $1}')" == "$PIN_TOOLCHAIN" ]] || fail 103 'official r29 toolchain hash mismatch'
[[ -f "$NDK/source.properties" ]] || fail 104 'source.properties missing'
grep -Fq 'Pkg.Revision = 29.0.14206865' "$NDK/source.properties" || fail 105 'NDK revision mismatch'
[[ -f "$SYSROOT/usr/lib/aarch64-linux-android/24/libz.so" ]] || fail 106 'Android API24 libz missing'
[[ -f "$SYSROOT/usr/lib/aarch64-linux-android/24/libvulkan.so" ]] || fail 107 'Android API24 libvulkan missing'
[[ "$(git -C "$CANON" rev-parse HEAD)" == "$PIN_CANON_HEAD" ]] || fail 108 'canonical HEAD changed'
[[ "$(git -C "$CANON" status --porcelain=v1 -uall | sha256sum | awk '{print $1}')" == "$PIN_CANON_STATUS" ]] || fail 109 'canonical status fingerprint changed'
[[ "$(sha256sum "$CANON_SPU"|awk '{print $1}')" == "$PIN_CANON_SPU" ]] || fail 110 'canonical SPUThread changed'
[[ "$(sha256sum "$CAND"|awk '{print $1}')" == "$PIN_CAND_SPU" ]] || fail 111 'candidate SPUThread changed'
[[ -z "$(git -C "$WT" status --porcelain=v1 -uall)" ]] || fail 112 'lane230 worktree dirty'
FREE=$(df -Pk /data | awk 'END{print $4}')
(( FREE >= MIN_KIB )) || fail 113 "free-space gate: $FREE < $MIN_KIB KiB"
for t in cmake ninja ccache cc c++ readelf file sha256sum; do command -v "$t" >/dev/null || fail 114 "missing tool $t"; done
mkdir -m 700 "$RUN" "$BUILD"
TRACE="$RUN/overlay.tsv"; : > "$TRACE"; export LANE230_OVERLAY_TRACE="$TRACE"
printf 'free_kib=%s\ncanon_head=%s\ncanon_status_sha=%s\ncandidate_spu_sha=%s\ntoolchain_sha=%s\n' "$FREE" "$PIN_CANON_HEAD" "$PIN_CANON_STATUS" "$PIN_CAND_SPU" "$PIN_TOOLCHAIN" > "$RUN/preflight.txt"
STAGE=configure
env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u OBJC_INCLUDE_PATH -u LIBRARY_PATH -u CMAKE_PREFIX_PATH -u CMAKE_LIBRARY_PATH -u CMAKE_INCLUDE_PATH  PKG_CONFIG_DIR= PKG_CONFIG_PATH= PKG_CONFIG_LIBDIR="$SYSROOT/usr/lib/aarch64-linux-android/pkgconfig:$SYSROOT/usr/lib/pkgconfig:$SYSROOT/usr/share/pkgconfig" PKG_CONFIG_SYSROOT_DIR="$SYSROOT"  cmake -S "$SRC" -B "$BUILD" -G Ninja  -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN"  -DCMAKE_C_COMPILER="/data/data/com.termux/files/usr/bin/cc" -DCMAKE_CXX_COMPILER="/data/data/com.termux/files/usr/bin/c++"  -DCMAKE_FIND_ROOT_PATH="$SYSROOT" -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-24 -DANDROID_PLATFORM_LEVEL=24 -DANDROID_STL=c++_shared -DANDROID_USE_LEGACY_TOOLCHAIN_FILE=OFF  -DCMAKE_CXX_COMPILER_LAUNCHER="$LAUNCHER" -DCMAKE_C_COMPILER_LAUNCHER=ccache  -DCMAKE_DISABLE_SOURCE_CHANGES=ON -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY -DCMAKE_HAVE_LIBC_PTHREAD=1  -DHAVE_LIBPTHREAD=0 -DHAVE_LIBRT=0 -DHAVE_PTHREAD_MUTEX_LOCK=1 -DHAVE_PTHREAD_RWLOCK_INIT=1 -DPTHREAD_IN_LIBC=1  -DCURL_BROTLI=OFF -DCURL_ZSTD=OFF -DUSE_NGHTTP2=OFF -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_BACKTRACES=OFF -DLLVM_ENABLE_LIBEDIT=OFF -DLLVM_ENABLE_LIBXML2=OFF  -DGAMEDECK_ICONV_LIBRARY:FILEPATH= -DGAMEDECK_CHARSET_LIBRARY:FILEPATH=  -DVulkan_LIBRARY:FILEPATH="$SYSROOT/usr/lib/aarch64-linux-android/24/libvulkan.so" -DZLIB_LIBRARY:FILEPATH="$SYSROOT/usr/lib/aarch64-linux-android/24/libz.so"  >"$RUN/configure.log" 2>&1 || fail 120 'configure failed'
STAGE=graph_gate
CACHE="$BUILD/CMakeCache.txt"; RULES="$BUILD/CMakeFiles/rules.ninja"; NINJA="$BUILD/build.ninja"
[[ -f "$CACHE" && -f "$RULES" && -f "$NINJA" ]] || fail 121 'generated graph incomplete'
grep -Fq "CMAKE_C_COMPILER:FILEPATH=/data/data/com.termux/files/usr/bin/cc" "$CACHE" || fail 122 'wrong C compiler'
grep -Fq "CMAKE_CXX_COMPILER:FILEPATH=/data/data/com.termux/files/usr/bin/c++" "$CACHE" || fail 123 'wrong CXX compiler'
if grep -E "\/data\/data\/com.termux\/files\/usr/(include|lib/)|-L ?\/data\/data\/com.termux\/files\/usr/lib|lib(execinfo|z\.so\.1|vulkan\.so\.1|xml2|nghttp2|zstd)" "$NINJA" "$RULES" >"$RUN/forbidden-graph.txt"; then fail 124 'Termux target dependency leaked into Android graph'; fi
STAGE=build
env -u CPATH -u C_INCLUDE_PATH -u CPLUS_INCLUDE_PATH -u OBJC_INCLUDE_PATH -u LIBRARY_PATH -u CMAKE_PREFIX_PATH -u CMAKE_LIBRARY_PATH -u CMAKE_INCLUDE_PATH  cmake --build "$BUILD" --target emu --parallel 1 >"$RUN/build.log" 2>&1 || fail 130 'build failed'
STAGE=artifact
ART="$BUILD/libe.so"; [[ -f "$ART" ]] || fail 131 'libe.so missing'
[[ "$(grep -c 'SPUThread.cpp' "$TRACE")" -eq 1 ]] || fail 132 'overlay substitution count != 1'
file "$ART" >"$RUN/file.txt"; readelf -h "$ART" >"$RUN/elf-header.txt"; readelf -d "$ART" >"$RUN/dynamic.txt"
grep -q 'AArch64' "$RUN/file.txt" || fail 133 'artifact not AArch64'
! grep -Eq 'RPATH|RUNPATH|libz\.so\.1|libvulkan\.so\.1|libexecinfo|libxml2|libnghttp2|libzstd' "$RUN/dynamic.txt" || fail 134 'forbidden runtime dependency'
SHA=$(sha256sum "$ART"|awk '{print $1}'); BYTES=$(stat -c %s "$ART")
printf 'RESULT=PASS_BUILD_ONLY\nartifact=%s\nsha256=%s\nbytes=%s\nrun=%s\n' "$ART" "$SHA" "$BYTES" "$RUN" | tee "$RUN/result.txt"
