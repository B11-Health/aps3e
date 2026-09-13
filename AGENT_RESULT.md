# Lane205 — minimal glslangValidator cache-classifier correction

## Scope and constraints

- Worktree: `/data/data/com.termux/files/home/projects/android/gamedeck-ps3-prod-lanes-20260912/lane205-glslang-validator-fix`
- Branch verified before mutation: `team/lane205-glslang-validator-fix`.
- Canonical resource policy read first; this lane performed implementation + static validation only.
- No CMake configure, compile, Ninja, Gradle, APK/NDK build, GTA run, install, push, merge, cleanup, deletion, or Codex use occurred.
- The pre-edit `LANE202_BUILD_WRAPPER.sh` was byte-identical to Lane202's wrapper: both SHA256 `a3ff931a0afec83c9403633010dbed59e35d7acc5fa1c05fd016be59a146c5ba`.

## Source evidence

RPCS3 canonical source calls Vulkan discovery at:

- `.../rpcs3/3rdparty/CMakeLists.txt:188`: `find_package(Vulkan)`.

Installed CMake 4.4 `FindVulkan.cmake` proves `glslangValidator` is host-program metadata, not a target library:

- lines 367-374 append `glslangValidator` to `Vulkan_FIND_COMPONENTS` for backward compatibility even when the caller did not request it explicitly;
- lines 500-506 call `find_program(Vulkan_GLSLANG_VALIDATOR_EXECUTABLE NAMES glslangValidator ...)`;
- lines 807-809 create imported executable target `Vulkan::glslangValidator` and set its `IMPORTED_LOCATION` from `Vulkan_GLSLANG_VALIDATOR_EXECUTABLE`.

The same module separately treats the primary Vulkan library as a library discovery variable (`find_library(Vulkan_LIBRARY ...)`, observed at line 460), so host executable metadata and Android target-library metadata have distinct roles.

Lane204's review identified the exact false-positive mechanism in Lane202: the generic cache classifier marked every `Vulkan_*` key as target dependency metadata. With `CMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER`, `find_program()` is intentionally host-rooted, so a legitimate `$PREFIX/bin/glslangValidator` cache value was incorrectly rejected as rc 158 despite not being a target link dependency.

## Minimal implementation

Only the blanket `Vulkan_` alternative was removed from the second broad prefix expression in `validate_cache()`.

Before:

```awk
key ~ /^(Backtrace_|EXECINFO_|LIBRT$|Vulkan_|ZLIB_|LIBUSB_|pkgcfg_|GAMEDECK_(ICONV|CHARSET)_LIBRARY$)/
```

After (`LANE202_BUILD_WRAPPER.sh:414-415`):

```awk
target = (key ~ /(^|_)(LIBRARY|LIBRARIES|LIBDIR|LDFLAGS|INCLUDE|INCLUDEDIR|INCLUDE_DIR|INCLUDE_DIRS)($|_)/ ||
          key ~ /^(Backtrace_|EXECINFO_|LIBRT$|ZLIB_|LIBUSB_|pkgcfg_|GAMEDECK_(ICONV|CHARSET)_LIBRARY$)/)
```

No path allowlist or special-case value exception for `glslangValidator` was added. The correction is semantic/key-role based only.

The generic role matcher remains unchanged, so Vulkan keys that are actually libraries, include directories, or linker flags remain target-classified. All other Lane202 gates are untouched because the source diff contains exactly this one classifier-line change.

## Preserved fail-closed gates

Static source inspection confirms:

- `LANE202_BUILD_WRAPPER.sh:371` still requires exact `cache_expect Vulkan_LIBRARY "$NDK_SYSROOT/usr/lib/aarch64-linux-android/24/libvulkan.so"`.
- `LANE202_BUILD_WRAPPER.sh:350` still requires `cache_expect CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER`.
- configure arguments still contain `-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER` at line 642.
- generic target roles remain `LIBRARY|LIBRARIES|LIBDIR|LDFLAGS|INCLUDE|INCLUDEDIR|INCLUDE_DIR|INCLUDE_DIRS`.
- `LIBUSB_` and `pkgcfg_` broad target-prefix gates remain present.
- `termux_target_allowlist=NONE` evidence remains present.
- the fresh-tree path rules, source/provenance identities, hashes, graph checks, native-host graph checks, artifact checks, trace checks, and rc semantics were not modified by this lane.

`grep -n 'glslangValidator' LANE202_BUILD_WRAPPER.sh` returned rc 1 with no matches, proving no exact glslangValidator path/name allowlist was introduced into the wrapper.

## Static classifier proof

A synthetic cache matrix was evaluated with the exact post-fix classifier expression from lines 414-415 and `$PREFIX=/data/data/com.termux/files/usr`.

Observed result:

```text
PASS    Vulkan_GLSLANG_VALIDATOR_EXECUTABLE
REJECT  Vulkan_LIBRARY
REJECT  Vulkan_glslang_LIBRARY
REJECT  Vulkan_INCLUDE_DIR
REJECT  Vulkan_LDFLAGS
REJECT  LIBUSB_LIBRARY
REJECT  pkgcfg_lib_USB_usb
```

This proves the required cases:

1. `Vulkan_GLSLANG_VALIDATOR_EXECUTABLE=$PREFIX/bin/glslangValidator` is host-program metadata and no longer triggers target rejection.
2. `Vulkan_LIBRARY=$PREFIX/lib/libvulkan.so` still rejects through the unchanged generic `*_LIBRARY` matcher.
3. `Vulkan_glslang_LIBRARY=$PREFIX/lib/...` still rejects through the same generic `*_LIBRARY` matcher.
4. Termux Vulkan include and LDFLAGS records still reject through generic role matching; libusb and pkg-config records still reject through their preserved target-prefix gates.
5. The exact NDK-sysroot `Vulkan_LIBRARY` cache expectation remains mandatory at line 371.

## Diff rationale

The former blanket `Vulkan_` test encoded a namespace assumption (all FindVulkan variables are target dependencies) that is false: `FindVulkan.cmake` exposes both host executable metadata and target library/include metadata under the same namespace. Removing only that blanket namespace arm while retaining the role-based matcher corrects the false positive without weakening zero-Termux-target-library policy.

## Result

Lane205 implements only the Lane204-authorized minimal cache-classifier fix. Static evidence shows the host-side glslangValidator cache record now passes while Vulkan/Termux target-library, include, linker-flag, libusb, and pkg-config contamination continues to fail closed. No build or runtime claim is made by this lane.
