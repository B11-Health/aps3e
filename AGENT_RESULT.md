# Lane206 — independent static review of Lane205 glslangValidator classifier fix

## Scope and constraints

- Worktree: `/data/data/com.termux/files/home/projects/android/gamedeck-ps3-prod-lanes-20260912/lane206-glslang-validator-fix-review`
- Branch: `team/lane206-glslang-validator-fix-review`
- Starting/reviewed HEAD verified exactly: `9053cf624e2ac0a6e56ff926cb632b48ff79bb4b`.
- Reviewed parent: `b144d16ed255a302f302c3654094c5162be80899`.
- Canonical `TEAM_RESOURCE_POLICY.md` and Lane205's committed report were read before review.
- Review was static/read-only except this report. No configure, compile, Ninja, Gradle, APK/NDK build, GTA run, install, push, merge, cleanup, deletion, or mutation of v6 or any other worktree/data was performed. No Codex was used.

## Disposition

**ACCEPT — Lane205 commit `9053cf624e2ac0a6e56ff926cb632b48ff79bb4b` correctly implements the minimal fail-closed cache-classifier correction specified by Lane204.**

This is approval of the static classifier correction only. It is **not** authorization to execute the Lane205 wrapper as a heavyweight attempt. The wrapper remains hard-wired to the Lane202 worktree identity and already-consumed build-v6 path, so a separately implemented and independently reviewed fresh-tree successor (v7) is required before any build.

## 1. Exact executable-code diff

`git diff b144d16ed255a302f302c3654094c5162be80899 9053cf624e2ac0a6e56ff926cb632b48ff79bb4b -- LANE202_BUILD_WRAPPER.sh` shows exactly one executable-code change:

```diff
- key ~ /^(Backtrace_|EXECINFO_|LIBRT$|Vulkan_|ZLIB_|LIBUSB_|pkgcfg_|GAMEDECK_(ICONV|CHARSET)_LIBRARY$)/)
+ key ~ /^(Backtrace_|EXECINFO_|LIBRT$|ZLIB_|LIBUSB_|pkgcfg_|GAMEDECK_(ICONV|CHARSET)_LIBRARY$)/)
```

The blanket `Vulkan_` namespace arm is the only wrapper-code removal. No launcher code changed. The commit also updates `AGENT_RESULT.md`, as expected for Lane205 reporting.

This preserves the generic target-role matcher unchanged:

`LIBRARY|LIBRARIES|LIBDIR|LDFLAGS|INCLUDE|INCLUDEDIR|INCLUDE_DIR|INCLUDE_DIRS`.

## 2. Independent static fixtures

Using the exact post-fix classifier expression from the committed wrapper with `$PREFIX=/data/data/com.termux/files/usr`, the independent fixture matrix produced:

```text
PASS    Vulkan_GLSLANG_VALIDATOR_EXECUTABLE
REJECT  Vulkan_LIBRARY
REJECT  Vulkan_glslang_LIBRARY
REJECT  Vulkan_INCLUDE_DIR
REJECT  Vulkan_LDFLAGS
REJECT  LIBUSB_LIBRARY
REJECT  pkgcfg_lib_USB_usb
```

Therefore:

- `Vulkan_GLSLANG_VALIDATOR_EXECUTABLE=$PREFIX/bin/glslangValidator` is no longer misclassified as target dependency metadata.
- `Vulkan_LIBRARY=$PREFIX/lib/libvulkan.so` still rejects.
- `Vulkan_glslang_LIBRARY=$PREFIX/lib/...` still rejects through the generic `*_LIBRARY` role matcher.
- Vulkan include and linker-flag records under the Termux prefix still reject.
- LIBUSB and pkg-config target records under the Termux prefix still reject.

No glslangValidator path allowlist or value exception was introduced.

## 3. Required fail-closed gates remain mandatory

Source inspection of the exact Lane205 wrapper confirms:

- line 350: `cache_expect CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER`
- line 371: `cache_expect Vulkan_LIBRARY "$NDK_SYSROOT/usr/lib/aarch64-linux-android/24/libvulkan.so"`
- lines 414-415: the generic target-role matcher remains intact, with only blanket `Vulkan_` removed from the broad prefix classifier
- line 438: `pkgcfg_` and `LIBUSB_` Termux-prefix rejection remains
- line 642: configure still passes `-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER`

Thus host-program discovery remains host-rooted while the primary Vulkan target library remains pinned to the exact NDK sysroot.

## 4. Consumed v6 cache, read-only

The consumed v6 cache at `~/.cache/gd-prod-spurs-lane187-canary-build-v6/CMakeCache.txt` was inspected read-only.

Relevant entries are:

```text
Vulkan_GLSLANG_VALIDATOR_EXECUTABLE:FILEPATH=/data/data/com.termux/files/usr/bin/glslangValidator
Vulkan_LIBRARY:FILEPATH=/data/data/com.termux/files/home/android-sdk/ndk-r29-local/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/24/libvulkan.so
```

Applying the corrected Lane205 classifier to the complete consumed v6 cache returned:

```text
NO_FORBIDDEN_TERMUX_TARGET_DEPENDENCIES
```

This independently confirms the former rc=158 was the overbroad host-program classification false positive identified by Lane204, while `Vulkan_LIBRARY` remains NDK-rooted. This is static evidence only; v6 remains consumed and must not be reused or mutated.

## 5. Static integrity checks

- `bash -n LANE202_BUILD_WRAPPER.sh` — PASS
- `git diff --check b144d16ed255a302f302c3654094c5162be80899 9053cf624e2ac0a6e56ff926cb632b48ff79bb4b` — PASS
- Starting worktree was clean at exact Lane205 commit before this report was written.

## 6. Why Lane205 is not the next runnable heavy wrapper

The committed Lane205 wrapper still contains Lane202-specific runtime identity and consumed-tree wiring:

- `WORKTREE="$HOME_ROOT/projects/android/gamedeck-ps3-prod-lanes-20260912/lane202-coordinator-link-isolation-candidate"`
- `SELF_EXPECTED="$WORKTREE/LANE202_BUILD_WRAPPER.sh"`
- `LAUNCHER="$WORKTREE/LANE202_OVERLAY_CXX_LAUNCHER.sh"`
- `FRESH_BUILD_V6="$HOME_ROOT/.cache/gd-prod-spurs-lane187-canary-build-v6"`
- the wrapper refuses an existing dedicated build directory

The v6 tree already exists and is consumed evidence. Executing Lane205 directly would therefore violate its own identity/fresh-tree model and is not approved by this review.

## Exact next action

Create a separate **v7 successor implementation lane** that changes only the identity/fresh-build-tree wiring necessary to run the accepted Lane205 classifier correction from a brand-new build directory, while preserving all existing fail-closed provenance, target-isolation, graph, storage, hash, and rc gates. That successor must receive an independent static review that pins its exact commit and script hashes before any single serialized heavyweight configure/compile attempt can be considered.

No runtime, GTA visual/audio, performance, Story Mode, or playability claim is made here.
