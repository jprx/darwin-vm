# darwin-vm

Run iOS/ macOS in Qemu. Supports emulating iPhone 17, 16, 15, 14, 13, and 12
(A19-A14) and M5-M1 Macs (tested with MacBook Air and Mac Mini). You can debug
the kernel, edit the root filesystem, and run a root shell + custom programs.

Features:
- Runs a lightweight debuggable iOS/ macOS (Darwin) system with custom filesystem.
- Boots you directly into a root shell in just a few seconds.
- Compile and run your own programs as root in the VM, no jailbreak or kernel patches required.
- Runs anywhere qemu runs (ARM host not required).
- Supports emulating A19-A14 (iOS) and M5-M1 (macOS) CPUs.
- Supports SPTM based kernels and CPUs with MIE.
- Can debug / patch the kernel, SPTM, TXM, dyld, launchd, and userspace programs.
- Automated setup to get going in just a few minutes.

```
$ ./run.sh
Darwin Kernel Version 27.0.0: Tue Aug 11 22:05:33 PDT 2026; root:xnu-13432.1.9~3/RELEASE_ARM64_T8142
pmap_startup() init/release time: 893478 microsec
vm_page_bootstrap: 463555 free pages, 25917 wired pages
VM bootstrap: 73 maps, 256 entries and 64 nodes available
ptr-packing max: compressor:0x<ptr> page:0x<ptr> vmn:0xfffffeffffffff00 vme:0x<ptr>
zone_map_range: min:0x<ptr> max:0x0, vm-size:0x5cc000000 ro-size:0x29e000000, vm_min:0x<ptr> ro_min:0x<ptr>
vm: "vm_compressor_mode" is 4
VM bootstrap done: 71 maps, 224 entries and 59 nodes left
standard timeslicing quantum is 10000 us
standard background quantum is 2500 us
Long logs support configured: size: 16384
Firehose configured: 16 chunks, 8 io pages
Log queues configured: slot count: 90, per-slot size: 32768, total size: 2949120
OSLog stream configured: stream: 8192 bytes, cache: 2112 bytes
[trap_telemetry] trap_telemetry_init
mig_table_max_displ = 91 mach_kobj_count = 390
debug_log_init: Error!! gPanicBase is still not initialized
libTXM_KernelVersion: 12
libTXM_Image4Version: 1
TXM [Log]: setup logging: 32768 bytes (256 | 128)
TXM [Log]: system supports DIT feature
TXM [Log]: setup device tree range
TXM [Log]: unable to find esdm-fuses property in /chosen
TXM [Log]: resolved system platform identity: 0
TXM [Log]: Code Signing Monitor Image4 Module Version 7.0.0: Mon Aug 10 00:10:03 PDT 2026; root:AppleImage4_txm-374~7048/libima
...
Darwin Ignition Sequence Version 1.0.0: Tue Aug 11 21:44:28 PDT 2026; root:libignition-64~19270/libignition_core/RELEASE_ARM64E
libignition: 1: arguments           :
libignition: 1:   ignition level    : 0x5
libignition: 1:   force dylib root  : 0x0
libignition: 1:   halt after stage  : n/a
...
com.apple.xpc.launchd|1970-01-01 00:00:29.466851 <Notice>: Darwin Bootstrapper Version 7.0.0: Mon Aug 10 01:06:09 PDT 2026; root:libxpc_executables-3298.1.1~29/launchd/RELEASE_ARM64E
com.apple.xpc.launchd|1970-01-01 00:00:29.484709 <Notice>: boot-args = rd=md0 serial=3 -v -noprogress wdt=-1 wlan-olyhal-abort
com.apple.xpc.launchd|1970-01-01 00:00:29.486795 <Notice>: Restore environment starting.
com.apple.xpc.launchd|1970-01-01 00:00:29.487770 <Notice>: System Integrity Protection is engaged.
com.apple.xpc.launchd|1970-01-01 00:00:29.904447 (system/com.jprx.bash) <Notice>: internal event: WILL_SPAWN, code = 0
com.apple.xpc.launchd|1970-01-01 00:00:29.905070 (system/com.jprx.bash) <Notice>: service state: spawn scheduled
com.apple.xpc.launchd|1970-01-01 00:00:29.905166 (system/com.jprx.bash) <Notice>: service state: spawning
com.apple.xpc.launchd|1970-01-01 00:00:29.922055 (system/com.jprx.bash) <Notice>: launching: speculative
bash-3.2# uname -v
Darwin Kernel Version 27.0.0: Tue Aug 11 22:05:33 PDT 2026; root:xnu-13432.1.9~3/RELEASE_ARM64_T8142
bash-3.2# whoami
root
bash-3.2# ls
.fseventsd      mnt1            mnt3            mnt8            usr
System          mnt10           mnt4            mnt9            var
bin             mnt11           mnt5            private
dev             mnt12           mnt6            sbin
etc             mnt2            mnt7            tmp
```

(some kernel messages were removed from the above log to make it easier to read)

# What this is not

This is not a full iPhone/ Mac emulator. Don't expect the screen, wifi,
bluetooth, graphics, GUI apps, or full springboard to work. This just boots iOS
/ macOS to a barebones root shell so you can run custom command line programs,
debug the kernel, and mess around with low-level Darwin internals.

If you've ever compiled Linux + busybox and booted in qemu (with `-kernel` and
`-initrd`) for kernel development, this is like that but for Darwin systems.

# Tested Configurations

`darwin-vm` has been tested with the following systems:

| Device          | `devname`    | CPU name | iOS 27.0 beta 8 | iOS 26.6 |
|-----------------|--------------|----------|-----------------|----------|
| iPhone 17 (A19) | `iPhone18,3` | `t8150`  | ✅              | ✅       |
| iPhone 16 (A18) | `iPhone17,3` | `t8140`  | ✅              | ✅       |
| iPhone 15 (A16) | `iPhone15,4` | `t8120`  | ✅              | ✅       |
| iPhone 14 (A15) | `iPhone14,7` | `t8110`  | ✅              | ✅       |
| iPhone 13 (A15) | `iPhone14,5` | `t8110`  | ✅              | ✅       |
| iPhone 12 (A14) | `iPhone13,2` | `t8101`  | ✅              | ✅       |

| Device         | `devname`    | CPU name | macOS 27.0 beta 8 | macOS 26.6 |
|----------------|--------------|----------|-------------------|------------|
| M5 Macbook Air | `Mac17,4`    | `t8142`  | ✅                | ✅         |
| M4 Mac Mini    | `Mac16,10`   | `t8132`  | ✅                | ✅         |
| M3 Macbook Air | `Mac15,13`   | `t8122`  | ✅                | ✅         |
| M2 Mac Mini    | `Mac14,3`    | `t8112`  | ✅                | ✅         |
| M1 Mac Mini    | `Macmini9,1` | `t8103`  | ✅                | ✅         |

✅ = boots to root shell and can run commands

Notes:
- If you don't need MIE, use something without it, as emulating MIE can be slow.

# Setup

You'll need a few things:
1. Access to a Mac with `python`, `jq`, `wget`, and `ipsw`.
2. A machine to build and run `qemu` on - this can be different to the first machine.
3. (optional) The URL of the IPSW (iOS or macOS) you want to use. You don't need to download the IPSW, you just need the URL. If you don't care which version you boot, we provide a default one.

> [!NOTE]
> The [`ipsw`](https://blacktop.github.io/ipsw/) tool can help find the URLs for `IPSW` files.

## Quickstart

How to get this running as fast as possible. See below sections for
explanations of what these commands do/ how to customize things.

Install dependencies:

```
brew install jq wget ipsw
```

Clone this repo:

```
git clone https://github.com/jprx/darwin-vm.git
cd darwin-vm
```

Download iOS files. Must run this on a Mac (see step 1 below to customize which
iOS/ macOS version we install):

```
./get_files.sh
./fix_perms.sh firmware/ramdisk.dmg
```

Build qemu:

```
git submodule update --init
cd qemu-sptm
mkdir build
cd build
../configure --target-list=aarch64-softmmu
make -j
cd ../..
```

Launch the VM:

```
./run.sh
```

Your VM should boot to a root shell! Use `ctrl+A` followed by `x` in the
terminal to quit Qemu.

## 1. Preparing Files

`get_files.sh` will download and patch the files we need from the remote IPSW URL.

> [!IMPORTANT]
> This step requires a Mac.

Run `get_files.sh` with no arguments to load a known working version of iOS. If
you do have a specific IPSW you want to use:

```
DEVNAME="your_device_name" URL="your_ipsw_url" ./get_files.sh
```

Example:

```
$ DEVNAME="iPhone17,3" URL="https://updates.cdn-apple.com/2026SpringSeed/ad5a4f9d-f005-466b-bbcf-3b466040074b/iPhone17,3_27.0_24A5424a_Restore.ipsw" ./get_files.sh
iPhone17,3
board name: d47ap
kernel ext: iphone17
chip name:  t8140
os sdk:     iphoneos

   • Extracting files matching pattern "kernelcache.release.iphone17"
   • Extracting Payload        path=firmware/bootkc
   • Extracting files matching pattern "sptm.t8140.release"
   • Extracting Payload        path=firmware/sptm
   • Extracting files matching pattern "txm.iphoneos.release"
   • Extracting Payload        path=firmware/txm
   • Extracting files matching pattern "DeviceTree.d47ap"
   • Extracting Payload        path=firmware/dtree
   • Extracting DMG
   • Extracting Payload        path=firmware/ramdisk.dmg
Patching firmware/ramdisk.dmg
/dev/disk7
/dev/disk8              EF57347C-0000-11AA-AA11-0030654
/dev/disk8s1            41504653-0000-11AA-AA11-0030654 /private/var/folders/bn/mbs4rq1j2wnc3mkz3lv70hr80000gn/T/tmp.4UAV9eVIrO
mounted firmware/ramdisk.dmg on /var/folders/bn/mbs4rq1j2wnc3mkz3lv70hr80000gn/T/tmp.4UAV9eVIrO
--2026-08-27 16:55:40--  https://raw.githubusercontent.com/jprx/ios-cli-tools/refs/heads/main/prebuilt.tar.gz
Resolving raw.githubusercontent.com (raw.githubusercontent.com)...
Connecting to raw.githubusercontent.com (raw.githubusercontent.com)... connected.
HTTP request sent, awaiting response... 200 OK
Length: 4513811 (4.3M) [application/octet-stream]
Saving to: ‘sysroot.tar.gz’

sysroot.tar.gz      100%[===================>]   4.30M  26.1MB/s    in 0.2s

2026-08-27 16:55:40 (26.1 MB/s) - ‘sysroot.tar.gz’ saved [4513811/4513811]

signing binaries...
building trustcache...
done!
"disk7" ejected.
```

## 2. Fixing Permissions

> [!IMPORTANT]
> This step requires a Mac.

`firmware/ramdisk.dmg` holds the filesystem our VM is going to use.
`get_files.sh` modified it to make the virtual machine immediately boot a root
shell; however, the files on the disk currently aren't owned by `root`, which
we need for the VM to boot.

Fix permissions with:

```
./fix_perms.sh firmware/ramdisk.dmg
```

Example:

```
$ ./fix_perms.sh firmware/ramdisk.dmg
/dev/disk5
/dev/disk7              EF57347C-0000-11AA-AA11-0030654
/dev/disk7s1            41504653-0000-11AA-AA11-0030654 /private/var/folders/bn/mbs4rq1j2wnc3mkz3lv70hr80000gn/T/tmp.iGnHuTRtjs
mounted firmware/ramdisk.dmg on /var/folders/bn/mbs4rq1j2wnc3mkz3lv70hr80000gn/T/tmp.iGnHuTRtjs
This will run: sudo chown -R root:wheel /var/folders/bn/mbs4rq1j2wnc3mkz3lv70hr80000gn/T/tmp.iGnHuTRtjs/bin /var/folders/bn/mbs4rq1j2wnc3mkz3lv70hr80000gn/T/tmp.iGnHuTRtjs/System /var/folders/bn/mbs4rq1j2wnc3mkz3lv70hr80000gn/T/tmp.iGnHuTRtjs/libexec
Are you sure? (y/n) y
y
done!
"disk5" ejected.
```

You will now have a `firmware` directory with everything we need to run the VM in it.

## 3. Build `qemu-sptm`

[`qemu-sptm`](https://github.com/jprx/qemu-sptm) is a fork of Qemu that adds
support for running Apple Silicon machines with SPTM/ TXM. It's provided in
this repo as a submodule. To boot our VM, we need to compile the `qemu-sptm`
submodule.

First, make sure you have the [Qemu build dependencies
installed](https://www.qemu.org/docs/master/devel/build-environment.html).
Then, build `qemu-sptm`:

```
git submodule update --init
cd qemu-sptm
mkdir build
cd build
../configure --target-list=aarch64-softmmu
make -j
cd ../..
```

Qemu will be located at `qemu-sptm/build/qemu-system-aarch64`.

## 4. Run the VM

The `run.sh` script boots qemu using the files in the `firmware` directory. It
takes no arguments:

```
./run.sh
```

Use `ctrl+A` followed by `x` in the terminal to quit Qemu.

## 5. Add custom programs to the VM

> [!IMPORTANT]
> This step requires a Mac with Xcode.

Let's say you want to run the following (in `hello.c`):

```c
#include <stdio.h>
int main() {
  printf("hello, xnu!\n");
}
```

1. Build it with `xcrun`, where `${YOUR_SDK}` is `iphoneos` (iOS VM) or `macosx` (macOS VM):

```
xcrun -sdk ${YOUR_SDK} clang hello.c -o hello
```

2. Sign it:

```
codesign -s - hello
```

3. Copy it into the ramdisk (by mounting `firmware/ramdisk.dmg`):

```
mkdir mnt
hdiutil attach -owners on -mountpoint mnt firmware/ramdisk.dmg
sudo cp hello mnt/bin/hello
hdiutil detach mnt
rmdir mnt
```

4. Get the `CDHash` of the binary:

```
codesign -d -vvv hello
```

look for the field that says `CDHash=...`, that 40-character hash is your `CDHash`.

5. Open `firmware/all_hashes` and add the `CDHash` as a new line at the top of
   the file. Then, run the following:

```
./build_tc.py firmware/all_hashes firmware/ramdisk.tc
```

Reboot the VM and run your program:

```
bash-3.2# hello
hello, xnu!
```

## 6. Running a custom / `development` kernel

> [!IMPORTANT]
> This step requires a Mac.

Apple ships `development` flavors of the kernel via Kernel Debug Kits for
macOS. You can also try to [compile XNU
yourself](https://github.com/blacktop/darwin-xnu-build). Using `development`
kernels is nice because they have extra features and symbols. We can boot these
with `darwin-vm` too.

To boot a `development` kernel, we need to create a new kernelcache combining
the kernel we want to use plus all the kexts for the system we're targeting.

### 1. Select a Mac and macOS version. You need to know:

- The device name of the Mac you want to use (eg. `Mac16,10` is an M4 Mac Mini).
- The exact macOS version number to target (eg. `25G70`).
- The URL of a macOS IPSW for that version.

### 2. Download and install the KDK for that version

Apple sometimes forgets to publish KDKs, so check that there is a KDK in Apple
Developer Downloads before continuing (you'll need to sign in to view these):

https://developer.apple.com/download/all/?q=Kernel%20Debug%20Kit

Make sure the exact version number matches (eg. `25G70`), not just the
customer-facing release (eg. `26.6`), as there can be multiple KDKs released
per macOS release.

Download the KDK matching your exact macOS version and install it.

### 3. Setup an initial VM

Use `get_files.sh` to fetch a macOS IPSW matching the version we want to debug
for the specific Mac you want to boot.

For example, if you wanted to run macOS build 25G70 on an M4 Mac Mini, use:

```
DEVNAME="Mac16,10" URL="https://updates.cdn-apple.com/2026SummerFCS/fullrestores/140-56823/1C29995E-8C11-4384-B9C0-B00145B84F51/UniversalMac_26.6_25G70_Restore.ipsw" ./get_files.sh
```

Make note of the following output; we'll need the `kernel ext` and `chip name`
fields later:

```
Mac16,10
board name: j773gap
kernel ext: mac16g
chip name:  t8132
os sdk:     macosx
```

(and don't forget to run `./fix_perms.sh firmware/ramdisk.dmg` after `get_files.sh`).

Boot and run the VM and make sure it works before continuing.

### 4. Build your new KC

The KDK we installed will be at `/Library/Developer/KDKs/${KDK}`. We need two
files:

1. `${KDK}/System/Library/KernelCollections/kernelcache.release.${KERNEL_EXT}.manifest.plist`
2. `${KDK}/System/Library/Kernels/kernel.development.${CHIP_NAME}`

Where `${KERNEL_EXT}` and `${CHIP_NAME}` come from the output of `get_files.sh`
above. `kernel.development.${CHIP_NAME}` is the actual kernel we want to run.
`kernelcache.release.${KERNEL_EXT}.manifest.plist` is a list of the kexts we
need to link your kernel to for the machine to boot. You also need to know the
version number of macOS to use (eg. `25G70`).

Use the following to create a new kernel collection:

```
kmutil create \
  -n boot \
  -s none \
  -a arm64e \
  -z -v \
  -B kc -V development \
  -r "${KDK}/System/Library/Extensions" \
  --build "${VERSION_NUMBER}" \
  -k kernel.development.${CHIP_NAME} \
  -x $(plutil -convert json kernelcache.release.${KERNEL_EXT}.manifest.plist -o - | jq -r '.requiredIdentifiers | .[]' | awk '{print " -b "$1; }')
```

For example:

```
kmutil create \
  -n boot \
  -s none \
  -a arm64e \
  -z -v \
  -B kc -V development \
  -r "/Library/Developer/KDKs/KDK_26.6_25G70.kdk/System/Library/Extensions" \
  --build "25G70" \
  -k kernel.development.t8132 \
  -x $(plutil -convert json kernelcache.release.mac16g.manifest.plist -o - | jq -r '.requiredIdentifiers | .[]' | awk '{print " -b "$1; }')
```

Your new custom kc will be available at `kc.development`.

### 5. Inspect your KC

Run `kmutil inspect -B ${your_kc}` to see what got linked:

```
$ kmutil inspect -B kc.development
...
Extension Information:
com.apple.driver.AppleFileSystemDriver  3.0.1   /Library/Developer/KDKs/KDK_26.6_25G70.kdk/System/Library/Extensions/AppleFileSystemDriver.kext
com.apple.plugin.IOAVBControlPlugin     1440.7  /Library/Developer/KDKs/KDK_26.6_25G70.kdk/System/Library/Extensions/IOAVBFamily.kext/Contents/PlugIns/IOAVBControlPlugin.kext
com.apple.driver.AppleCS42L84Audio      940.17  /Library/Developer/KDKs/KDK_26.6_25G70.kdk/System/Library/Extensions/AppleEmbeddedAudio.kext/Contents/PlugIns/AppleCS42L84Audio.kext
...
```

You should see only kernel extensions from the KDK you selected, and these
should match the contents of the manifest file.

### 6. Boot your new KC

`firmware/bootkc` is the kernelcache that `run.sh` will use when booting the
VM. Move the current `firmware/bootkc` file somewhere else, then copy the
`kc.development` file we built above to `firmware/bootkc`.

Use `run.sh` to boot the VM. You should immediately see a new Darwin kernel
version string printed:

```
$ ./run.sh
Darwin Kernel Version 25.6.0: Sat Jul 11 16:10:10 PDT 2026; root:xnu_development-12377.161.13~4/DEVELOPMENT_ARM64_T8132
pmap_startup() init/release time: 392049 microsec
vm_page_bootstrap: 498765 free pages, 25523 wired pages
VM bootstrap: 73 maps, 256 entries and 64 nodes available
Enable all vm_debug options with boot-arg vm_debug=1
Maximum number of VM swap files: 100
...
```

Note the `DEVELOPMENT_ARM64_T8132` version string, as opposed to
`RELEASE_ARM64_T8132` from before.

## 7. Modifying / inspecting the filesystem

`firmware/ramdisk.dmg` contains the filesystem used for running the VM. It's
based on the recovery image from the IPSW file for this OS.

In section 5 (above), I showed how to compile and add new programs to the VM.
You can modify the entire filesystem this way. Mount the ramdisk with:

```
mkdir mnt
hdiutil attach -owners on -mountpoint mnt firmware/ramdisk.dmg
```

The `mnt` folder now contains the contents of the ramdisk. You can modify it
however you want. For example, add new launchd daemons by tossing them into
`System/Library/LaunchDaemons`. Install new programs by copying them into `bin`
(and make sure to add their CDHash to the trustcache, see section 5 above).
Make sure the files are owned by `root:wheel` as otherwise XNU/ launchd will
reject them.

When you're done, unmount the disk image:

```
hdiutil detach mnt
rmdir mnt
```

## 8. Debugging the kernel

Add `-s` to `args` in `run.sh` to expose a GDB debug server from qemu. You can
use this to debug the running kernel or user programs. Add `-S` to make qemu
wait for a debugger to attach before running any instructions; use this to
start on the first instruction of SPTM.

You can use `lldb` with `gdb-remote localhost:1234` to attach to the GDB
server, or compile/ acquire an `aarch64` GDB and use that. (the [Fractal
toolchain](https://github.com/jprx/fractal/blob/main/toolchain/mk_toolchain.sh)
shows how to compile GDB from source, this is what I use).

You can debug iOS or macOS kernels. If you're running a `development` kernel /
have a KDK, you can use `lldb` to debug with symbols:

```
$ lldb firmware/bootkc
(lldb) gdb-remote localhost:1234
...
Load Address: 0xfffffe002700c000
Kernel slid 0x20000000 in memory.
...
Process 1 stopped
* thread #1, stop reason = signal SIGTRAP
    frame #0: 0xfffffe002b9272e4 bootkc`kern_timeout_start + 132
bootkc`kern_timeout_start:
->  0xfffffe002b9272e4 <+132>: ldr    x9, [x8, #0x248]
    0xfffffe002b9272e8 <+136>: ldr    x9, [x9, #0x58]
    0xfffffe002b9272ec <+140>: cmp    x9, x10
    0xfffffe002b9272f0 <+144>: b.ne   0xfffffe002b9272dc ; <+124>
Target 0: (bootkc) stopped.
(lldb) bt
* thread #1, stop reason = signal SIGTRAP
  * frame #0: 0xfffffe002b9272e4 bootkc`kern_timeout_start + 132
    frame #1: 0xfffffe002bb1ac2c bootkc`ml_set_interrupts_enabled_with_debug + 200
    frame #2: 0xfffffe002b8e1104 bootkc`processor_idle + 324
    frame #3: 0xfffffe002b8e1470 bootkc`idle_thread + 124
    frame #4: 0xfffffe002b820fac bootkc`Call_continuation + 204
```

You can set breakpoints just like you'd expect:

```
(lldb) b sleh_synchronous
Breakpoint 1: where = bootkc`sleh_synchronous, address = 0xfffffe002bb149c8
(lldb) c
Process 1 resuming
Process 1 stopped
* thread #1, stop reason = breakpoint 1.1
    frame #0: 0xfffffe002bb149c8 bootkc`sleh_synchronous
bootkc`sleh_synchronous:
->  0xfffffe002bb149c8 <+0>:  pacibsp
    0xfffffe002bb149cc <+4>:  sub    sp, sp, #0xf0
    0xfffffe002bb149d0 <+8>:  stp    x28, x27, [sp, #0x90]
    0xfffffe002bb149d4 <+12>: stp    x26, x25, [sp, #0xa0]
Target 0: (bootkc) stopped.
```

And inspect memory too. For example, here's how to dump the device tree:

```
(lldb) x/10gx DTRootNode
0xfffffe0006fbc000: 0x0000001900000017 0x6f74616c75676572
0xfffffe0006fbc010: 0x6c65646f6d2d7972 0x007265626d756e2d
0xfffffe0006fbc020: 0x0000000000000000 0x6373797300000011
0xfffffe0006fbc030: 0x2f23644d522f6766 0x0000000030327830
0xfffffe0006fbc040: 0x7373657264646123 0x0000736c6c65632d
```

Or read the boot args:

```
(lldb) p/x *(boot_args*)BootArgs
(boot_args) {
  Revision = 0x0002
  Version = 0x0002
  virtBase = 0xfffffe0000000000
  physBase = 0x0000010000000000
  memSize = 0x0000000200000000
  topOfKernelData = 0x0000010016130000
  Video = {
    v_baseAddr = 0x0000000000000000
    v_display = 0x0000000000000000
    v_rowBytes = 0x0000000000000000
    v_width = 0x0000000000000000
    v_height = 0x0000000000000000
    v_depth = 0x0000000000000000
  }
  machineType = 0x00000000
  deviceTreeP = 0x0000000000000000
  deviceTreeLength = 0x00000000
  CommandLine = "rd=md0 serial=3 -v -noprogress wdt=-1 wlan-olyhal-abort"
  bootFlags = 0x0000000000000000
  memSizeActual = 0x0000000000000000
}
```

(I cleaned up the `CommandLine` string in the above log to make it easier to read)

For iOS, you won't have symbols, but you can still use lldb/ gdb.

### Rebasing the boot KC

By default, the bootkc will be slid forward `0x20000000` bytes in virtual
memory. SPTM makes it annoying to load the bootkc exactly where we want it (see
`qemu-sptm/hw/arm/xnuboot_sptm.c` for why). TLDR is that sliding forward by
`0x20000000` bytes works out to be a very natural way to load a kernelcache
under SPTM, so that's the default.

To convert from mach-o addresses to VM addresses, add `0x20000000`. To convert
from a VM address to a mach-o address, subtract `0x20000000`.

For example, the bootkc mach-o reports that `sleh_synchronous` is at
`0xfffffe000bb149c8`, so to find it in the VM, add `0x20000000` to get
`0xfffffe002bb149c8`. Sure enough, if you attach with `lldb`, that's where
`lldb` says `sleh_synchronous` is loaded in memory (see above).

> [!IMPORTANT]
> For best results, always use the fully linked bootkc kernelcache for
> rebasing, never the raw kernel itself, as symbols get moved around during the
> `kmutil create` process.

If you want, I provided the compile-time option `LINEUP_BOOTKC_NICELY` in
`xnuboot_sptm.c` that will try to place the bootkc at its exact virtual memory
address by underflowing the virtual address base. This has the effect of
putting SPTM and TXM at really strange virtual addresses, and is known to cause
instability, but was helpful for me in debugging early XNU boot. Uncomment that
line and recompile qemu if you want to try it.

# FAQ

The system boots, but I don't have a shell, and I see this error in the log:

`Failed to bootstrap path: path = /System/Library/LaunchDaemons/com.jprx.sh.plist, error = 122: Path had bad ownership/permissions`

This means you forgot to run `fix_perms` on the ramdisk. Run this and relaunch the VM:

```
./fix_perms.sh firmware/ramdisk.dmg
```

## Is this AI slop?

No.

Every line of code in this project was written by a human (me) over a period of
around 2 months.

I did experiment with using AI tools a few times during this project, but never
let them touch the code, and eventually got frustrated with them and went back
to traditional techniques. It's possible I am just not that good of an AI
prompter, but the LLMs I tried kept going off track / getting things wrong, and
I found the workflow kind of annoying.

I found the most useful things in getting this to work were:
- reading the [XNU kernel source](https://github.com/apple-oss-distributions/xnu)
- [poking around the hardware in a hypervisor](https://github.com/jprx/gxf-playground)
- inspecting kernel core dumps of real Mac systems
- using the Virtualization.framework GDB stub to inspect a running VMAPPLE VM
- reversing SPTM/ TXM in Binja
- a little bit of trial and error

## References

A number of projects before this one worked on adding iOS / macOS support to
qemu. This project is the first to support a number of features required for
emulating newer chips (eg. SPTM/ TXM/ MIE), but builds on the knowledge of
earlier work.

Here are a collection of references I found helpful while working on this:

- [Worth Doing Badly's original blog post on emulating iOS 12 in qemu](https://worthdoingbadly.com/xnuqemu/)
- [Aleph Research's blog post on getting bash running in emulated iOS for iPhone 6S](https://alephsecurity.com/2019/06/17/xnu-qemu-arm64-1/)
- [Cyclance/ Blackberry's blog post on getting macOS 11 for the DTK to run in qemu](https://web.archive.org/web/20220705161340/https://blogs.blackberry.com/en/2021/05/strong-arming-with-macos-adventures-in-cross-platform-emulation)
- [Trung Nguyen's iPhone 11 emulation in qemu-t8030](https://github.com/TrungNguyen1909/qemu-t8030)
- [Sven Peter's writeup on SPRR/ GXF](https://blog.svenpeter.dev/posts/m1_sprr_gxf/)
- [Asahi Linux docs](https://asahilinux.org/docs/)

## Credits

`nvram.bin` is extracted from Brandon Azad's [iPhone device tree
dump](https://gist.githubusercontent.com/bazad/1faef1a6fe396b820a43170b43e38be1/raw/e05ea511bb048941aaf234680e1f35e7589ef1e2/devicetree-iPhone12,3-17C54.txt).
Specifically, from `chosen/nvram-proxy-data`.
