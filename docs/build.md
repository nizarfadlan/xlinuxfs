# Build and development

## Requirements

- macOS 15.4 or later
- Xcode 27 or later
- LLVM 19 with a working `clang` executable
- Python 3.9 or later
- A provisioning profile that authorizes the FSKit File System Module capability for signed system-mount tests

The project builds both `arm64` and `x86_64`. The pinned `vendor/lkl`
submodule contains the Darwin build profile and must be initialized before the
first build.

## Initial checkout

```sh
git submodule update --init --recursive
export CLANG=/path/to/llvm19/bin/clang
```

The compiler can also be configured without putting a machine-specific path in
the repository:

```sh
git config --local xlinuxfs.lklClang /path/to/llvm19/bin/clang
```

The local Git setting is ignored by the project and is useful when launching
Xcode from Finder. `LKL_CLANG` or `CLANG` can override it for one command.

## Build the library and app

```sh
bash scripts/build-liblkl.sh
xcodebuild -project xlinuxfs.xcodeproj -scheme xlinuxfs \
  -configuration Release ONLY_ACTIVE_ARCH=NO build
```

The Xcode prebuild phase invokes the same library script automatically. Build
outputs are written to ignored paths under `libs/`; temporary work and logs
belong under `_tmp/`.

For a signed archive, use a locally authorized signing identity and profile:

```sh
xcodebuild -project xlinuxfs.xcodeproj -scheme xlinuxfs \
  -configuration Release \
  -archivePath _tmp/xlinuxfs.xcarchive \
  -destination 'generic/platform=macOS' \
  ONLY_ACTIVE_ARCH=NO archive
```

The FSKit entitlement is restricted. A successful unsigned build does not prove
that macOS will load or mount the extension; verify the signed embedded app and
extension before system-mount testing.

### Intel (x86_64) builds

Both targets pin `ARCHS` to `arm64 x86_64`, and Release pins
`ONLY_ACTIVE_ARCH=NO`, so a Release build is universal even when the project
is opened in Xcode on a single-architecture Mac. Debug keeps the active
architecture only (project-level `ONLY_ACTIVE_ARCH=YES`), for iteration speed.

Build the x86_64-only slice explicitly:

```sh
bash scripts/build-liblkl.sh
xcodebuild -project xlinuxfs.xcodeproj -scheme xlinuxfs \
  -configuration Release \
  -derivedDataPath _tmp/DerivedData-x86_64 \
  ARCHS=x86_64 ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
bash scripts/verify-x86_64.sh \
  _tmp/DerivedData-x86_64/Build/Products/Release/xlinuxfs.app x86_64
```

`scripts/verify-x86_64.sh` checks with `lipo` that the app binary and the
embedded `lklfuse.appex` contain exactly the expected architectures, and that
`libs/liblkl.a` is universal. Pass `arm64 x86_64` instead of `x86_64` to
verify a universal build.

CI packages the built app into `xlinuxfs-x86_64.dmg` with
`scripts/package-x86_64.sh` before uploading it. GitHub always downloads
artifacts as a `.zip`, so the download unzips to the `.dmg`; mount the image
and drag the `.app` out. Uploading the raw `.app` does not work for this:
a `.app` is a directory, so the download comes back as a zip instead of a
usable app.

CI covers the same check in `.github/workflows/build-x86_64.yml`: a required
cross-compile job on the `xcode-27` runner (GitHub has no Intel runner with
Xcode 27), plus a best-effort native build on `macos-15-intel`, the last
hosted x86_64 image, available until August 2027. Both CI builds are
unsigned; signed system-mount testing on Intel stays a local step.

Intel ceiling: macOS Tahoe 26 is the last macOS for Intel Macs, so the
x86_64 slice targets macOS 15.4-26. The macOS 27-only features in the README
are Apple Silicon only.

## Validation

Run the bridge and direct FSKit capability checks against disposable fixture
images. The runners cover ext4, XFS, and Btrfs; they should not be pointed at a
mounted production volume.

```sh
python3 vendor/lkl/tools/lkl/darwin/test_profile.py
bash tests/run_bridge_platforms.sh /path/to/test-images
bash tests/run_bridge_capabilities.sh /path/to/test-images
bash tests/run_volume_capabilities.sh /path/to/test-images
```

For signed macOS 27 integration tests, see
[Platform support and verification](platform-support.md). Those tests require
an installed, signed app, an enabled extension, and disposable copies of the
fixtures.

## Dependency updates

Make LKL engine changes inside `vendor/lkl`, commit them in that submodule, and
run the bridge and capability test matrix before updating the parent gitlink.
The full ownership, fork, cache, and update workflow is documented in
[LKL dependency workflow](lkl-dependency.md).

## Development notes

- Do not commit generated `libs/` outputs or temporary `_tmp/` artifacts.
- Keep signing identities, provisioning data, local paths, and diagnostic logs
  out of public documentation and commits.
- Test read-only behavior separately from read/write behavior. A read-only
  resource must never become writable because of a requested mount mode.
- The filesystem capability document records supported metadata operations and
  intentional `ENOTSUP` boundaries.
