#!/data/data/com.termux/files/usr/bin/bash
set -euo pipefail

PREFIX="/data/data/com.termux/files/usr"
ROOT="$HOME/projects/android/gamedeck/mobile/android/vendor/aps3e-source"
SRC="$ROOT/app/src/main/cpp"
LANE187="$HOME/projects/android/gamedeck-ps3-prod-lanes-20260912/lane187-prod-spurs-canary-instrumentation"
REL="rpcs3/rpcs3/Emu/Cell/Modules"
CAND_A="$LANE187/app/src/main/cpp/$REL/cellSpurs.cpp"
CAND_B="$LANE187/app/src/main/cpp/$REL/cellSpursSpu.cpp"
HEAD187="cf5cb967e706fde89fd9fc76eed5f5b052e50a36"
SHA_A="c1c3731fd34823eebd88d87ab5bde00f38147e7e78d68bd93d898440161dd6f4"
SHA_B="f5ae5b6e8e19884382399f5b76980f5e6e6d253d6b0b94bdfe3dcfbf0a4d6570"
CANON_HEAD="7dc95e6baaac0712d5b3c28501778dd7934e579b"
CANON_STATUS_SHA="36b6a6d7e79282cb43e415bc4e076873c2d4b974576e5168c2844e0ff569e4bf"
NDK="$HOME/android-sdk/ndk-r29-local"
NDK_REV="29.0.14206865"
BUILD="$HOME/.cache/gd-prod-spurs-lane187-canary-build"
LAUNCHER="$(cd "$(dirname "$0")" && pwd)/LANE190_OVERLAY_CXX_LAUNCHER.sh"
TRACE="$HOME/.cache/gd-lane187-canary-overlay-trace.tsv"
LOG="$HOME/.cache/gd-lane187-canary-libe-build.log"
MANIFEST="$HOME/.cache/gd-lane187-canary-libe-manifest.txt"
RESULT="$HOME/.cache/gd-lane187-canary-libe-result.txt"
RCFILE="$HOME/.cache/gd-lane187-canary-libe.rc"
MIN_KIB=4194304

finish() {
  rc=$?
  printf '%s\n' "$rc" > "$RCFILE"
  printf 'finished_utc=%s\nrc=%s\nlog=%s\nmanifest=%s\ntrace=%s\nresult=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" "$LOG" "$MANIFEST" "$TRACE" "$RESULT" >> "$MANIFEST" 2>/dev/null || true
  exit "$rc"
}
trap finish EXIT

sha1() { sha256sum "$1" | awk '{print $1}'; }
status_sha() { git -C "$ROOT" status --porcelain=v1 -z | sha256sum | awk '{print $1}'; }
free_kib() { df -Pk /data | awk 'NR==2 {print $4}'; }

require_tool() { command -v "$1" >/dev/null 2>&1 || { echo "missing tool: $1" >&2; exit 80; }; }
for t in git sha256sum awk grep cmake ninja ccache file readelf stat date df; do require_tool "$t"; done
[[ -x "$LAUNCHER" ]] || { echo "launcher missing/not executable" >&2; exit 81; }
[[ "$(git -C "$LANE187" rev-parse HEAD)" == "$HEAD187" ]] || { echo "Lane187 HEAD mismatch" >&2; exit 82; }
[[ -z "$(git -C "$LANE187" status --porcelain)" ]] || { echo "Lane187 dirty" >&2; exit 83; }
[[ "$(sha1 "$CAND_A")" == "$SHA_A" ]] || { echo "Lane187 cellSpurs.cpp SHA mismatch" >&2; exit 84; }
[[ "$(sha1 "$CAND_B")" == "$SHA_B" ]] || { echo "Lane187 cellSpursSpu.cpp SHA mismatch" >&2; exit 85; }
[[ "$(git -C "$ROOT" rev-parse HEAD)" == "$CANON_HEAD" ]] || { echo "canonical HEAD mismatch" >&2; exit 86; }
[[ "$(status_sha)" == "$CANON_STATUS_SHA" ]] || { echo "canonical status fingerprint mismatch" >&2; exit 87; }
[[ -f "$NDK/source.properties" ]] || { echo "NDK source.properties missing" >&2; exit 88; }
actual_ndk_rev=$(awk -F'= *' '/^Pkg.Revision/ {print $2}' "$NDK/source.properties" | tr -d '\r')
[[ "$actual_ndk_rev" == "$NDK_REV" ]] || { echo "NDK revision mismatch: $actual_ndk_rev" >&2; exit 89; }
pre_free=$(free_kib)
(( pre_free >= MIN_KIB )) || { echo "free-space gate failed: $pre_free KiB < $MIN_KIB KiB" >&2; exit 90; }
[[ ! -e "$BUILD" ]] || { echo "dedicated build dir already exists; refusing ambiguous reuse: $BUILD" >&2; exit 91; }

mkdir -p "$BUILD" "$(dirname "$LOG")"
: > "$LOG"
: > "$TRACE"

CONFIGURE=(cmake -S "$SRC" -B "$BUILD" -G Ninja
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_TOOLCHAIN_FILE="$NDK/build/cmake/android.toolchain.cmake"
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
  -DHAVE_LIBPTHREAD=0 -DHAVE_LIBRT=0 -DHAVE_PTHREAD_MUTEX_LOCK=1 -DHAVE_PTHREAD_RWLOCK_INIT=1 -DPTHREAD_IN_LIBC=1
  -DCURL_BROTLI=OFF -DCURL_ZSTD=OFF -DUSE_NGHTTP2=OFF
  -DGAMEDECK_ICONV_LIBRARY="$PREFIX/lib/libiconv.a"
  -DGAMEDECK_CHARSET_LIBRARY="$PREFIX/lib/libcharset.a"
  -DZLIB_LIBRARY="$NDK/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/24/libz.so")
BUILD_CMD=(cmake --build "$BUILD" --target emu --parallel 1)

{
  printf 'preflight_utc=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf 'preflight_local=%s\n' "$(date +%Y-%m-%dT%H:%M:%S%z)"
  printf 'wrapper_sha256=%s\n' "$(sha1 "$0")"
  printf 'launcher_sha256=%s\n' "$(sha1 "$LAUNCHER")"
  printf 'lane187_head=%s\ncellSpurs_sha256=%s\ncellSpursSpu_sha256=%s\n' "$HEAD187" "$SHA_A" "$SHA_B"
  printf 'canonical_head=%s\ncanonical_status_sha256=%s\n' "$CANON_HEAD" "$CANON_STATUS_SHA"
  printf 'ndk_revision=%s\nabi=arm64-v8a\napi=24\nbuild_type=Release\nstl=c++_shared\n' "$actual_ndk_rev"
  printf 'free_kib_pre=%s\n' "$pre_free"
  printf 'configure_command='; printf '%q ' "${CONFIGURE[@]}"; printf '\n'
  printf 'build_command='; printf '%q ' "${BUILD_CMD[@]}"; printf '\n'
} > "$MANIFEST"

"${CONFIGURE[@]}" >> "$LOG" 2>&1
"${BUILD_CMD[@]}" >> "$LOG" 2>&1

OUT="$BUILD/libe.so"
[[ -s "$OUT" ]] || { echo "missing/nonzero libe.so" >&2; exit 92; }
[[ "$(find "$BUILD" -maxdepth 1 -type f -name 'libe.so' | wc -l | tr -d ' ')" == "1" ]] || { echo "unexpected libe.so count" >&2; exit 93; }
file "$OUT" | grep -q 'ELF 64-bit.*ARM aarch64.*shared object' || { echo "file(1) architecture/type check failed" >&2; exit 94; }
readelf -h "$OUT" | grep -q 'Machine:.*AArch64' || { echo "readelf machine check failed" >&2; exit 95; }
readelf -h "$OUT" | grep -q 'Type:.*DYN' || { echo "readelf DYN check failed" >&2; exit 96; }

# Exactly the two allowed substitution identities may appear; each must appear at least once.
awk -F '\t' 'NF>=4 {print $2"\t"$3}' "$TRACE" | sort -u > "$TRACE.allowed"
expected=$(printf 'cellSpurs.cpp\t%s\ncellSpursSpu.cpp\t%s\n' "$SHA_A" "$SHA_B" | sort)
actual=$(cat "$TRACE.allowed")
[[ "$actual" == "$expected" ]] || { echo "overlay trace missing/unexpected TU identity" >&2; exit 97; }
[[ "$(grep -c $'\tcellSpurs.cpp\t' "$TRACE")" -ge 1 ]] || exit 98
[[ "$(grep -c $'\tcellSpursSpu.cpp\t' "$TRACE")" -ge 1 ]] || exit 99

[[ "$(git -C "$LANE187" rev-parse HEAD)" == "$HEAD187" && -z "$(git -C "$LANE187" status --porcelain)" ]] || { echo "Lane187 postflight drift" >&2; exit 100; }
[[ "$(sha1 "$CAND_A")" == "$SHA_A" && "$(sha1 "$CAND_B")" == "$SHA_B" ]] || { echo "Lane187 postflight source drift" >&2; exit 101; }
[[ "$(git -C "$ROOT" rev-parse HEAD)" == "$CANON_HEAD" && "$(status_sha)" == "$CANON_STATUS_SHA" ]] || { echo "canonical postflight drift" >&2; exit 102; }
post_free=$(free_kib)

{
  printf 'rc=0\nartifact=%s\nartifact_sha256=%s\nartifact_bytes=%s\n' "$OUT" "$(sha1 "$OUT")" "$(stat -c %s "$OUT")"
  printf 'file=%s\n' "$(file "$OUT")"
  printf 'free_kib_post=%s\n' "$post_free"
  printf 'claim=compile_link_only_no_runtime_correctness_or_playability_claim\n'
} > "$RESULT"

trap - EXIT
printf '0\n' > "$RCFILE"
printf 'finished_utc=%s\nrc=0\nresult=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$RESULT" >> "$MANIFEST"
exit 0
