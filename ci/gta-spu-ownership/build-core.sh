#!/usr/bin/env bash
set -euo pipefail
ROOT="${GITHUB_WORKSPACE:?}"
OUT="$ROOT/out/gta-spu-core"
WORK="${RUNNER_TEMP:?}/gta-spu-core"
JOBS=2
NDK_VER=29.0.14206865
API=24
ICONV_VER=1.19
ICONV_SHA=88dd96a8c0464eca144fc791ae60cd31cd8ee78321e67397e25fc095c4a19aa6
ICONV_URL=https://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.19.tar.gz
mkdir -p "$OUT" "$WORK"
exec > >(tee "$OUT/build.log") 2>&1
trap 'rc=$?; echo "$rc" > "$OUT/exit-code.txt"; exit $rc' EXIT

echo '== source identity =='
git rev-parse HEAD | tee "$OUT/synthetic-commit.txt"
git status --porcelain=v1 --untracked-files=no | tee "$OUT/git-status.txt"
test ! -s "$OUT/git-status.txt"
sha256sum -c ci/gta-spu-ownership/current-source.sha256 | tee "$OUT/source-manifest-check.txt"
cp ci/gta-spu-ownership/current-source.sha256 "$OUT/current-source.sha256"
git diff HEAD^ HEAD -- . ':!/.github' ':!/ci/gta-spu-ownership' > "$OUT/synthetic-source.patch" || true
sha256sum "$OUT/synthetic-source.patch" > "$OUT/synthetic-source.patch.sha256"

SOURCE=app/src/main/cpp/rpcs3/rpcs3/Emu/Cell/SPULLVMRecompiler.cpp
python3 ci/gta-spu-ownership/spu-llvm-provenance.py --source "$SOURCE" --emit-cpp "$WORK/provenance.expected.cpp"
cmp -s "$WORK/provenance.expected.cpp" app/src/main/cpp/gamedeck_spu_llvm_provenance.cpp
python3 ci/gta-spu-ownership/spu-llvm-provenance.py --source "$SOURCE" --json > "$OUT/spu-provenance-source.json"
cp app/src/main/cpp/gamedeck_spu_llvm_provenance.cpp "$OUT/gamedeck_spu_llvm_provenance.cpp"

echo '== toolchain =='
NDK="${ANDROID_HOME:?}/ndk/$NDK_VER"
test -f "$NDK/source.properties"
grep -Eq '^Pkg.Revision[[:space:]]*=[[:space:]]*29\.0\.14206865[[:space:]]*$' "$NDK/source.properties"
cat "$NDK/source.properties" | tee "$OUT/ndk-source.properties"
TOOL="$NDK/toolchains/llvm/prebuilt/linux-x86_64"
SYSROOT="$TOOL/sysroot"
TARGET=aarch64-linux-android
CC="$TOOL/bin/${TARGET}${API}-clang"
CXX="$TOOL/bin/${TARGET}${API}-clang++"
test -x "$CC"; test -x "$CXX"
"$CXX" --version | tee "$OUT/target-clang-version.txt"
cmake --version | tee "$OUT/cmake-version.txt"
ninja --version | tee "$OUT/ninja-version.txt"

 echo '== pinned libiconv =='
TARBALL="$WORK/libiconv-$ICONV_VER.tar.gz"
curl -fL --retry 3 --retry-delay 2 "$ICONV_URL" -o "$TARBALL"
printf '%s  %s\n' "$ICONV_SHA" "$TARBALL" | sha256sum -c - | tee "$OUT/libiconv-sha-check.txt"
tar -xzf "$TARBALL" -C "$WORK"
ICONV_SRC="$WORK/libiconv-$ICONV_VER"
ICONV_PREFIX="$WORK/iconv-prefix"
(
 cd "$ICONV_SRC"
 CC="$CC" CXX="$CXX" AR="$TOOL/bin/llvm-ar" RANLIB="$TOOL/bin/llvm-ranlib" STRIP="$TOOL/bin/llvm-strip" \
 CFLAGS='-O2 -fPIC' CXXFLAGS='-O2 -fPIC' ./configure --host="$TARGET" --prefix="$ICONV_PREFIX" --enable-static --disable-shared --disable-nls
 make -j2
 make install
)
test -s "$ICONV_PREFIX/include/iconv.h"
test -s "$ICONV_PREFIX/lib/libiconv.a"
test -s "$ICONV_PREFIX/lib/libcharset.a"
sha256sum "$ICONV_PREFIX/lib/libiconv.a" "$ICONV_PREFIX/lib/libcharset.a" | tee "$OUT/iconv-static-sha256.txt"

echo '== matching host LLVM 19.1.7 tblgen =='
LLVM_SRC="$ROOT/app/src/main/cpp/rpcs3/3rdparty/llvm/llvm-19.1.7/llvm"
HOST_LLVM="$WORK/llvm-host"
cmake -S "$LLVM_SRC" -B "$HOST_LLVM" -G Ninja \
 -DCMAKE_BUILD_TYPE=Release -DLLVM_TARGETS_TO_BUILD=AArch64 -DLLVM_ENABLE_PROJECTS= \
 -DLLVM_INCLUDE_TESTS=OFF -DLLVM_INCLUDE_BENCHMARKS=OFF -DLLVM_INCLUDE_EXAMPLES=OFF \
 -DLLVM_ENABLE_TERMINFO=OFF -DLLVM_ENABLE_ZLIB=OFF -DLLVM_ENABLE_ZSTD=OFF \
 -DLLVM_ENABLE_LIBXML2=OFF -DLLVM_ENABLE_BACKTRACES=OFF
cmake --build "$HOST_LLVM" --target llvm-tblgen --parallel 2
TBLGEN="$HOST_LLVM/bin/llvm-tblgen"
test -x "$TBLGEN"
"$TBLGEN" --version | tee "$OUT/llvm-tblgen-version.txt"

echo '== configure Android ARM64 core =='
BUILD="$WORK/build"
cmake -S "$ROOT/app/src/main/cpp" -B "$BUILD" -G Ninja \
 -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake" \
 -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-$API -DANDROID_PLATFORM_LEVEL=$API -DANDROID_STL=c++_shared \
 -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-I$ICONV_PREFIX/include" -DCMAKE_CXX_FLAGS="-I$ICONV_PREFIX/include" \
 -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY -DCMAKE_SKIP_RPATH=ON -DUSE_NATIVE_INSTRUCTIONS=OFF \
 -DWITH_LLVM=ON -DBUILD_LLVM=ON -DSTATIC_LINK_LLVM=ON -DLLVM_TARGETS_TO_BUILD=AArch64 \
 -DUSE_PRECOMPILED_HEADERS=OFF -DUSE_FAUDIO=OFF -DUSE_SYSTEM_CURL=OFF -DUSE_SYSTEM_FFMPEG=OFF \
 -DUSE_SYSTEM_LIBPNG=OFF -DUSE_SYSTEM_ZLIB=ON -DUSE_SYSTEM_ZSTD=OFF -DLLVM_TABLEGEN="$TBLGEN" \
 -DLLVM_ENABLE_ZSTD=OFF -DLLVM_ENABLE_BACKTRACES=OFF -DCURL_BROTLI=OFF -DUSE_NGHTTP2=OFF -DCURL_ZSTD=OFF \
 -DCMAKE_HAVE_LIBC_PTHREAD=1 -DHAVE_LIBPTHREAD=0 -DPTHREAD_IN_LIBC=1 -DHAVE_PTHREAD_RWLOCK_INIT=1 \
 -DHAVE_PTHREAD_MUTEX_LOCK=1 -DHAVE_LIBRT=0 -DZLIB_INCLUDE_DIR="$SYSROOT/usr/include" \
 -DZLIB_LIBRARY="$SYSROOT/usr/lib/aarch64-linux-android/$API/libz.so" -DVulkan_INCLUDE_DIR="$SYSROOT/usr/include" \
 -DVulkan_LIBRARY="$SYSROOT/usr/lib/aarch64-linux-android/$API/libvulkan.so" \
 -DGAMEDECK_ICONV_LIBRARY="$ICONV_PREFIX/lib/libiconv.a" -DGAMEDECK_CHARSET_LIBRARY="$ICONV_PREFIX/lib/libcharset.a" \
 | tee "$OUT/configure.log"

echo '== build libe.so single-job =='
cmake --build "$BUILD" --target libe.so --parallel 2 | tee "$OUT/compile-link.log"
mapfile -t cores < <(find "$BUILD" -type f -name libe.so -print)
test "${#cores[@]}" -eq 1
CORE="${cores[0]}"
cp "$CORE" "$OUT/libe.so"
file "$OUT/libe.so" | tee "$OUT/libe-file.txt"
readelf -h "$OUT/libe.so" > "$OUT/libe-elf-header.txt"
readelf -d "$OUT/libe.so" > "$OUT/libe-elf-dynamic.txt"
readelf -n "$OUT/libe.so" > "$OUT/libe-notes.txt"
grep -Fq 'Machine:                           AArch64' "$OUT/libe-elf-header.txt"
grep -Eq 'Type:.*DYN' "$OUT/libe-elf-header.txt"
! grep -Eq '\(RPATH\)|\(RUNPATH\)' "$OUT/libe-elf-dynamic.txt"
sed -n 's/.*Shared library: \[\(.*\)\]/\1/p' "$OUT/libe-elf-dynamic.txt" | sort -u | tee "$OUT/DT-NEEDED.txt"
allowed='libOpenSLES.so libandroid.so libc++_shared.so libc.so libdl.so liblog.so libm.so libvulkan.so libz.so libhook_impl.so'
while read -r dep; do case " $allowed " in *" $dep "*) ;; *) echo "UNEXPECTED_DT_NEEDED=$dep"; exit 70;; esac; done < "$OUT/DT-NEEDED.txt"
python3 ci/gta-spu-ownership/spu-llvm-provenance.py --source "$SOURCE" --verify-binary "$OUT/libe.so" --json | tee "$OUT/spu-provenance-binary.json"
strings "$OUT/libe.so" | grep -F 'GAMEDECK_SPU_LLVM_PROVENANCE_V1|' | head -1 > "$OUT/embedded-provenance-marker.txt"
test -s "$OUT/embedded-provenance-marker.txt"
sha256sum "$OUT/libe.so" | tee "$OUT/libe.sha256"
sed -n 's/.*Build ID: //p' "$OUT/libe-notes.txt" | head -1 | tee "$OUT/libe.build-id"
test -s "$OUT/libe.build-id"
cp "$ROOT/ci/gta-spu-ownership/build-core.sh" "$OUT/build-core.sh"
cp "$ROOT/ci/gta-spu-ownership/spu-llvm-provenance.py" "$OUT/spu-llvm-provenance.py"
find "$OUT" -maxdepth 1 -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > "$OUT/SHA256SUMS"
echo 0 > "$OUT/exit-code.txt"
trap - EXIT
