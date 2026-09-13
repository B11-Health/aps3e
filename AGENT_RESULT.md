# Lane202 — systemic Android target link isolation successor

## Scope and identity
- Worktree: `/data/data/com.termux/files/home/projects/android/gamedeck-ps3-prod-lanes-20260912/lane202-coordinator-link-isolation-candidate`
- Branch: `team/coordinator-link-isolation-candidate`
- Verified start/base HEAD before final commit: `6821c8bb0a0a03f8970ac9ee2549a2c1e71e05ca`.
- Exact Lane200 input reviewed: `2badf39d65fe1156e4a22063b7789fa3f845f88f`.
- Exact Lane201 audit input reviewed: `d9242a2efe35e0f84bac2f81e7b5efcfe79e9a1c`.
- Canonical resource policy read from `/data/data/com.termux/files/home/projects/android/gamedeck-ps3-live-lanes-20260908/TEAM_RESOURCE_POLICY.md` because the production-lanes parent has no relative `../TEAM_RESOURCE_POLICY.md`.
- Task mode was script + static architecture fix + report only. No CMake configure, compile, Ninja build/test, GTA run, APK/NDK build, install, push, merge, workflow dispatch, cleanup, or deletion was executed.
- Report generated UTC: 2026-09-13T04:17:59Z.

## Why another successor was required
Lane201 proved Lane198's Android target graph escaped into the Termux prefix during CMake dependency discovery. The failed v4 root cache contained Termux values for `Backtrace_LIBRARY`, `EXECINFO_LIBRARY`, `LIBRT`, `Vulkan_LIBRARY`, GAMEDECK iconv/charset and libusb/pkg-config records. The root `build.ninja` then carried host libraries/rpaths and `-lexecinfo` into Android target links.

Lane200 correctly introduced a target-rooted `CMAKE_FIND_ROOT_PATH` with `PROGRAM=NEVER`, `LIBRARY/INCLUDE/PACKAGE=ONLY` plus environment sanitation. However, the independent Lane201 audit required broader fail-closed validation of adjacent discovery variables and a clean separation between the Android target graph and LLVM's `NATIVE` host sub-build.

The pre-existing untracked Lane202 draft was not acceptable: it explicitly allowlisted `$PREFIX/lib/libiconv.a` and `$PREFIX/lib/libcharset.a` in both cache and graph validation. Static inspection of those archives showed AArch64 relocatable members, but architecture compatibility alone does not make an uncontrolled Termux-prefix archive an approved Android target dependency. That allowlist was removed rather than hidden.

## Lane202 architecture
### 1. Systemic target discovery isolation
The future root configure keeps the NDK sysroot as the only `CMAKE_FIND_ROOT_PATH` and requires:
- `CMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER` — host programs remain discoverable.
- `CMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY`.
- `CMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY`.
- `CMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY`.

The configure environment removes ambient `CPATH`, C/C++/ObjC include paths, `LIBRARY_PATH`, `CMAKE_PREFIX_PATH`, `CMAKE_LIBRARY_PATH`, and `CMAKE_INCLUDE_PATH`. Root target pkg-config is constrained to NDK-sysroot directories with empty `PKG_CONFIG_DIR`/`PKG_CONFIG_PATH` and an NDK `PKG_CONFIG_SYSROOT_DIR`.

The later build command removes the same ambient search variables but deliberately unsets the target pkg-config overrides. This prevents target-search hints from leaking forward while allowing LLVM's later `NATIVE` host configure to use normal host program/library discovery.

### 2. Zero Termux target-dependency allowlist
`GAMEDECK_ICONV_LIBRARY` and `GAMEDECK_CHARSET_LIBRARY` are explicitly empty FILEPATH cache entries. No Termux `.a` or `.so` is permitted as an Android target dependency. If a later real link proves iconv/charset is required, that must be solved as an explicit Android-target dependency with its own provenance rather than by cross-linking a Termux-prefix archive.

`Vulkan_LIBRARY` and `ZLIB_LIBRARY` are pinned to exact API-24 AArch64 files under the NDK sysroot. Backtrace/execinfo are *not* forced empty as the primary isolation mechanism; systemic target-root discovery governs them.

### 3. Broader fail-closed cache validation
The root cache validator still proves ABI/platform/STL/toolchain/build-mode/launcher/root-mode and inherited feature gates. It now additionally:
- requires GAMEDECK iconv/charset injection to be empty;
- requires exact target-rooted Vulkan and zlib;
- treats `Backtrace_INCLUDE_DIR`, `Backtrace_LIBRARY`, `EXECINFO_LIBRARY`, and `LIBRT` as valid only when absent, empty, `*-NOTFOUND`, or NDK-sysroot-rooted;
- rejects the Termux prefix in generic target-like `*_LIBRARY`, `*_LIBRARIES`, `*_LIBDIR`, `*_LDFLAGS`, include-directory variables, known Backtrace/EXECINFO/LIBRT/Vulkan/ZLIB/LIBUSB variables, GAMEDECK injection variables, and `pkgcfg_*` records;
- handles grep/AWK outcomes explicitly: leak/match => fail, verified absence => pass, inspection error => fail.

Host executable/interpreter metadata is classified separately from target dependency variables, so host programs remain legal without creating a target-library exception.

### 4. Root graph validation without false positives from host compiler resources
`build.ninja` and `CMakeFiles/rules.ninja` are scanned for Android-target dependency contamination. The validator rejects:
- absolute Termux `lib*.so` / `lib*.a` dependencies;
- `-L$PREFIX/lib` search paths;
- Termux library rpaths;
- Termux include paths;
- `libexecinfo` and `-lexecinfo`.

It intentionally does **not** reject a host compiler program merely because its `-resource-dir` is under `$PREFIX/lib/clang/...`; that is host-tool metadata, not an Android target library edge. This distinction was necessary because the known-bad v4 `rules.ninja` contains legitimate host `clang-scan-deps`/compiler resource-dir references while its target-link contamination is in the root link graph.

### 5. LLVM NATIVE host graph is separate
Lane202 adds a separate `NATIVE` classifier for `rpcs3/3rdparty/llvm/llvm_build/NATIVE/CMakeCache.txt` and `NATIVE/build.ninja` when generated. It proves the NATIVE cache uses exact host Termux `cc`/`c++` and does not reference the Android NDK toolchain file. No Android target zero-host-library scan is applied to this host graph.

The known-bad v4 NATIVE cache independently confirms this split: C compiler is `$PREFIX/bin/cc`, CXX compiler is `$PREFIX/bin/c++`, and the Android toolchain file is absent.

### 6. Fresh-tree and provenance contracts
The only future build tree is now `$HOME/.cache/gd-prod-spurs-lane187-canary-build-v6`. Lane202 refuses the original/v1 path plus v2, v3, v4, and v5 and refuses v6 reuse if v6 already exists. Static inspection verified v6 is currently absent.

All prior immutable contracts remain: exact Lane187 canary hashes, canonical source/head/status hashes, NDK revision/toolchain hash, approved commit/wrapper/launcher SHA+blob checks, strict overlay trace schema, recursive artifact uniqueness, ELF64/DYN/AArch64 artifact verification, fail-closed evidence finalization, `--parallel 1`, and the >=4194304 KiB storage gates.

The evidence namespace was corrected from stale `gd-lane198-...` to `gd-lane202-...` in both wrapper and launcher. After normalizing Lane200 -> Lane202 worktree/evidence identity, launcher differences are identity-label-only; overlay substitution semantics are unchanged.

## Static evidence against known-bad v4
Read-only probes against `/data/data/com.termux/files/home/.cache/gd-prod-spurs-lane187-canary-build-v4` found:
- `Backtrace_LIBRARY`: Termux leak.
- `EXECINFO_LIBRARY`: Termux leak.
- `LIBRT`: Termux leak.
- `Vulkan_LIBRARY`: Termux leak.
- `GAMEDECK_ICONV_LIBRARY`: Termux leak.
- `GAMEDECK_CHARSET_LIBRARY`: Termux leak.
- `LIBUSB_INCLUDEDIR`: Termux leak.
- `LIBUSB_LIBDIR`: Termux leak.
- `LIBUSB_LDFLAGS`: contains `-L$PREFIX/lib`.
- `pkgcfg_lib_LIBUSB_usb-1.0`: Termux leak.

Using the refined Lane202 root-graph classifier on the known-bad v4 evidence:
- `build.ninja`: rc=0 with 6 leak lines — correctly detected contamination.
- `CMakeFiles/rules.ninja`: rc=1 with 0 target-dependency leak lines — correctly reports verified absence while allowing host compiler resource-dir metadata.

The v4 NATIVE host proof shows exact `$PREFIX/bin/cc` and `$PREFIX/bin/c++` and no Android toolchain reference.

## Static checks
- `bash -n LANE202_BUILD_WRAPPER.sh`: PASS.
- `bash -n LANE202_OVERLAY_CXX_LAUNCHER.sh`: PASS.
- Unsafe Termux iconv/charset allowlist removed: PASS.
- No package-specific forced `Backtrace_LIBRARY:FILEPATH=` or `EXECINFO_LIBRARY:FILEPATH=` override remains: PASS.
- v6 future tree required and v1-v5 refused: PASS.
- `--parallel 1` preserved: PASS.
- NDK target root modes preserved: PASS.
- `git diff --check` on scripts: PASS.
- Future v6 path currently absent: PASS.
- Current `/data` free space at final static check: 1,782,060 KiB, which is **below** the required 4,194,304 KiB gate. Therefore no future configure/build is authorized yet.

## Limitations and disposition
No future configure was run, so Lane202 does not claim the corrected root search policy successfully configures every dependency. No compile/link was run, so it does not claim a `libe.so` artifact exists. No APK was installed and GTA was not run, so there is no runtime, visual, audio, performance, or playability claim.

A future configure/build must still be independently reviewed, must start from a clean committed Lane202 identity with exact approved script hashes, must have at least 4,194,304 KiB free, must use the fresh v6 tree, and must run as the single global heavyweight operation.

Disposition: **READY_FOR_INDEPENDENT_STATIC REVIEW; NOT YET AUTHORIZED FOR BUILD DUE TO STORAGE GATE AND REQUIRED REVIEW.**
