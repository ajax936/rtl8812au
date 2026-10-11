# RTL8812AU for Pixel 10 Pro XL

Patched [aircrack-ng RTL8812AU](https://github.com/aircrack-ng/rtl8812au) driver for the **Alfa AWUS036ACH (RTL8812AU)**, targeting the Android GKI kernel below.

| Item | Target / observed result |
| --- | --- |
| Device | Google Pixel 10 Pro XL |
| Android build | CP3A.261005.005 |
| Running kernel | `6.6.127-android15-8-g91d825611104-ab16252310-4k` |
| Kernel source commit | `91d825611104e75e1a9e0e0f6b25580eddb68828` |
| Google kernel build ID | `16252310` |
| Compiler used | Ubuntu Clang 18.1.3 |
| Module | `8812au.ko` |
| Symbol-version comparison | No mismatches against matching GKI and live wireless export CRCs |
| Phone load test | `insmod` returned 0; module appeared Live in `/proc/modules` |
| USB driver registration | `usbcore: registered new interface driver rtl8812au` |
| Adapter/radio testing | Pending; no Alfa adapter was attached during the load test |

**A successful module load is the verified result.** Wi-Fi association, monitor mode, packet injection, throughput, and adapter power stability have not yet been tested. Automatic loading after reboot is not configured.

## Download

The [kernel-specific release](https://github.com/ajax936/rtl8812au/releases/tag/pixel10-6.6.127-16252310) contains the load-tested module, its SHA-256 checksum, and build details.

This module targets the exact kernel above. Other kernels or Android updates require a new ABI check and usually a rebuild.

## Build on Linux or WSL

Install Clang/LLVM 18, make, Python 3.12 or newer, curl, tar, and the host kernel-build dependencies. On Ubuntu 24.04:

```sh
sudo apt-get install clang-18 llvm-18 lld-18 make python3 curl tar build-essential libelf-dev libssl-dev flex bison bc
git clone https://github.com/ajax936/rtl8812au.git
cd rtl8812au
bash pixel10/build.sh
```

The helper downloads the exact Google kernel source and published prepared build artifacts, restores the matching configuration and symbol versions, and builds only the RTL8812A chipset. By default downloads live in `~/.cache/rtl8812au/pixel10-16252310`; set `WORKDIR`, `LLVM_BIN`, or `JOBS` to override.

The kernel was originally built with Android Clang 18.0.0. This module was built with Ubuntu Clang 18.1.3 and successfully loaded on the phone.

## Load on a rooted phone

Transfer the release module to `/data/local/tmp/8812au.ko`, then:

```sh
adb shell uname -r
adb shell su -c 'insmod /data/local/tmp/8812au.ko'
adb shell su -c 'cat /proc/modules'
adb shell su -c 'dmesg' | tail -50
```

Connect the Alfa through a USB host/OTG adapter with suitable power to test hardware operation. Loading lasts until reboot unless a separate startup mechanism is configured.

## Changes

- Bound radiotap antenna metadata and present-word writes; retained kernel FORTIFY checks.
- Validate channel-switch and vendor information-element lengths.
- Replace a trailing zero-length crypt-key payload with a flexible array.
- Return an invalid-data sentinel for invalid PHY rate/path selections.
- Correct an always-true RF comparison and several uninitialized values.
- Add an opt-in `CONFIG_RTW_GKI=y` configuration for kernels that do not export `filp_open`.
- Disable direct calibration/file I/O in that GKI configuration; use embedded firmware, built-in PHY tables, and hardware EFUSE instead.
- Retain module symbol versioning and CFI.

The bundled `pixel10/wireless-6.6.127.symvers` contains export names and CRCs extracted from the phone's cfg80211/mac80211 modules. Their imported core CRCs were checked against Google's build 16252310 artifacts with zero mismatches. It contains no phone serials, passwords, Wi-Fi names, or raw phone modules.

## Upstream and license

Based on aircrack-ng RTL8812AU v5.6.4.2, commit `734485506a30d6237c2deaad666a19f8ca5379f2`. Upstream history, source attribution, and [LICENSE](LICENSE) are retained. See [README.upstream.md](README.upstream.md) for the upstream documentation.

This repository is an independent device-specific adaptation, not an official Google, Alfa, or aircrack-ng release.
