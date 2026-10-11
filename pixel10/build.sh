#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=${WORKDIR:-"${XDG_CACHE_HOME:-$HOME/.cache}/rtl8812au/pixel10-16252310"}
llvm=${LLVM_BIN:-/usr/lib/llvm-18/bin}
jobs=${JOBS:-8}
release=6.6.127-android15-8-g91d825611104-ab16252310-4k
commit=91d825611104e75e1a9e0e0f6b25580eddb68828
mkdir -p "$work"
work=$(cd "$work" && pwd)
export PATH="$llvm:$PATH"
version=$(clang --version)
[[ "$version" == *"clang version 18."* ]] || { echo "Clang 18 is required" >&2; exit 1; }
download() {
  local url=$1 dest=$2
  if [[ ! -s "$dest" ]]; then
    curl --fail --location --retry 2 --connect-timeout 20 --max-time 600 "$url" -o "$dest.part"
    mv "$dest.part" "$dest"
  fi
}
download "https://android.googlesource.com/kernel/common/+archive/$commit.tar.gz" "$work/kernel-source.tar.gz"
download "https://androidbuildinternal.googleapis.com/android/internal/build/v3/builds/16252310/kernel_aarch64/attempts/latest/artifacts/kernel_aarch64_filegroup_decl.tar.gz/url?redirect=true" "$work/kernel_aarch64_filegroup_decl.tar.gz"
if [[ ! -f "$work/kernel-source/Makefile" ]]; then
  mkdir -p "$work/kernel-source"
  tar -xzf "$work/kernel-source.tar.gz" -C "$work/kernel-source"
fi
python3 - "$work" "$release" <<'PY'
from pathlib import Path
import shutil, sys, tarfile
work=Path(sys.argv[1])
stage=work/'published-artifacts'; stage.mkdir(exist_ok=True)
with tarfile.open(work/'kernel_aarch64_filegroup_decl.tar.gz') as archive:
    archive.extractall(stage,filter='data')
root=stage/'bazel-out/k8-fastbuild/bin/common'
out=work/'kernel-build';out.mkdir(exist_ok=True)
with tarfile.open(root/'kernel_aarch64_modules_prepare/modules_prepare_outdir.tar.gz') as archive:
    archive.extractall(out,filter='data')
cfg=root/'kernel_aarch64_config/out_dir'
shutil.copy2(cfg/'.config',out/'.config')
shutil.copytree(cfg/'include',out/'include',dirs_exist_ok=True)
shutil.copy2(root/'kernel_aarch64/Module.symvers',out/'Module.symvers')
kernel_release=root/'kernel_aarch64/include/config/kernel.release'
assert kernel_release.read_text().strip()==sys.argv[2], 'Published kernel release differs'
shutil.copy2(kernel_release,out/'include/config/kernel.release')
source=out/'source'
if source.is_symlink() or source.is_file():source.unlink()
assert not source.exists(),'Unexpected source directory in prepared output'
source.symlink_to(work/'kernel-source',target_is_directory=True)
(out/'Makefile').write_text(f'include {work / "kernel-source" / "Makefile"}\n')
PY
make -C "$work/kernel-source" O="$work/kernel-build" M="$repo" \
  ARCH=arm64 LLVM=1 CROSS_COMPILE= KERNELRELEASE="$release" \
  KBUILD_EXTRA_SYMBOLS="$repo/pixel10/wireless-6.6.127.symvers" \
  CONFIG_88XXAU=m CONFIG_PLATFORM_I386_PC=n CONFIG_PLATFORM_ARM64_RPI=y \
  CONFIG_MODULE_SIG_ALL=n CONFIG_RTW_GKI=y CONFIG_EFUSE_CONFIG_FILE=n \
  CONFIG_LOAD_PHY_PARA_FROM_FILE=y CONFIG_RTL8812A=y CONFIG_RTL8821A=n \
  CONFIG_RTL8814A=n -j"$jobs" modules
test -s "$repo/8812au.ko"
llvm-strings "$repo/8812au.ko" | grep "^vermagic=$release "
sha256sum "$repo/8812au.ko"
echo "Built: $repo/8812au.ko"
