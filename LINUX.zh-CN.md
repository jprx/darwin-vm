# 在 Linux 上运行 darwin-vm

本文档说明如何在**不用 Mac** 的情况下，在 Linux 主机上跑通 darwin-vm 的固件准备流程（`get_files.sh` / `fix_perms.sh`）。这不是上游 darwin-vm 自带的功能——它默认固件准备这一步必须在 macOS 上做（因为要调用 `hdiutil`/`ditto`/`codesign`）；这里的所有改动都是叠加在原有流程之上的，**完全不影响 macOS 那条路径**。

英文版见 [LINUX.md](LINUX.md)。

## 额外的主机依赖

除了主 README 里已经列出的 `jq`、`wget`，Linux 主机还需要：

- **ipsw**（github.com/blacktop/ipsw）。直接 `go install .../ipsw@latest` 会失败（它的 go.mod 里有 `replace` 指令），需要克隆源码自己编译：
  ```
  git clone https://github.com/blacktop/ipsw.git
  cd ipsw && go build -o ipsw ./cmd/ipsw
  sudo cp ipsw /usr/local/bin/
  ```
- **ldid**（github.com/ProcursusTeam/ldid）。用来替代 macOS 的 `codesign` 做临时（ad-hoc）签名；它的 `-S`/`-h` 输出格式跟 `codesign -s -` / `codesign -d -vvv` 是文本兼容的，可以直接复用原来的 grep 解析逻辑。
  ```
  sudo apt-get install -y libplist-dev
  git clone https://github.com/ProcursusTeam/ldid.git
  cd ldid && make
  sudo cp ldid /usr/local/bin/
  ```
- **linux-apfs-rw 内核模块**（github.com/linux-apfs/linux-apfs-rw）。实测发现 `firmware/ramdisk.dmg` 其实是一个**裸的 APFS 容器**（没有 UDIF/HFS+ 那层包装），所以直接用这个树外的、实验性的读写 APFS 驱动挂载即可。需要对应当前内核版本的 headers：
  ```
  sudo apt-get install -y linux-headers-$(uname -r)
  git clone https://github.com/linux-apfs/linux-apfs-rw.git
  cd linux-apfs-rw && make
  sudo modprobe libcrc32c
  sudo insmod apfs.ko
  ```
  `insmod` 不会在重启后自动生效——每次重启都要重新加载一次（或者自己配置 `depmod`/`modules-load.d`）。

## 具体改了什么

- **`dmgutil.sh`（新增）**：把 DMG 挂载/卸载、目录拷贝的逻辑统一收拢到这一个文件里，供 `get_files.sh` 和 `fix_perms.sh` 共用。在 macOS 上它只是 `hdiutil`/`ditto` 的一层薄封装，行为跟原来完全一样；在 Linux 上则用 `apfs` 内核模块挂载，用 `cp -a --remove-destination` 拷贝文件（这个 `--remove-destination` 是必须的：Linux 版 apfs 驱动的实验性写支持没实现 `O_TRUNC`，所以覆盖已存在的文件必须走"先删除再创建"，而不是"原地截断"，否则 `cp` 会报 "Operation not supported"）。
- **`get_files.sh` / `fix_perms.sh`**：现在会 `source dmgutil.sh`，并且不再在 Linux 上直接打印"这不是 Mac"然后退出——打补丁 ramdisk、修复权限这两步在两个平台上走的是同一套逻辑，只是底层调用 `dmgutil.sh` 里对应平台的实现。`codesign` 在 Linux 上对应换成了 `ldid -Cadhoc -S` / `ldid -h`。
- `chown root:wheel` 在 Linux 上变成了 `chown 0:0`——数值上是同一对 uid/gid（macOS 的 `wheel` 组 gid 就是 0，跟 Linux 的 `root` 组一样），XNU 只看数字 id，不看组名。

以上这些改动**完全不影响 macOS 路径**：每一处新增分支都用 `[[ "$(uname)" == "Darwin" ]]` 做了判断，所以把这份改过的代码直接拿到 Mac 上跑是安全的——走的还是原来一模一样的 `hdiutil`/`ditto`/`codesign` 调用。

## 启动噪音的两处补丁

这个 VM 里有两条日志会持续刷屏，原因都是**没有模拟真正的 SEP（安全隔区协处理器）**、也**没有真正的 dyld 共享缓存**。两条都不影响功能正确性——命令照样能跑、结果照样正确——但第一条是真正的无限重试循环，第二条则是每次起新进程都会重新打印一次，所以都做了处理。这两个补丁对 **iOS 和 macOS 客户机都生效**（两者共用同一套 XNU 代码路径），而且跟宿主机是 Mac 还是 Linux 无关——如果你在真正的 Mac 上构建固件，同样值得带上这两个改动。

1. **`ACMTRM: waitForSEPEndpoint: timed out waiting for AppleSEPManager`**（每隔约 5 秒刷一次，无限重复）。`AppleCredentialManager` 根据设备树认为这台设备"应该有 SEP"，于是永久重试。试过 `trm_enabled=0` 这个 boot-arg，也试过把设备树属性 `sepfw-load-at-boot` 设成 0，**都没能止住**——真正有效的做法是在 `dt_fixup.py` 里把 `sep` 这个设备树节点整个删掉：
   ```python
   d['arm-io'].remove_child('sep')
   ```
   这样对应的驱动从一开始就找不到 SEP 节点可探测，也就不会去重试了。（`run.sh` 里的 `BOOT_ARGS` 仍然保留了 `trm_enabled=0 hidrm_enabled=0`，虽然单独用没能解决问题，但留着无害，算是双重保险。）

2. **`shared_region: %p [%d(%s)] check_np(...) vm_shared_region_start_address() returned 0x1`**——这条是**无条件打印**的（翻遍能想到的 boot-arg 和 sysctl 都没能关掉它），只要有进程调用 `check_np()` 系统调用（也就是几乎每次起新进程）就会打印一次。`patch_bootkc.py`（新增脚本，已经接入 `get_files.sh` 的 `main()`，在下载完 `bootkc`之后自动执行）会原地把这条 `printf` 格式字符串的**第一个字节改成 `\0`**，把它截断成空字符串。这只是改了 1 个字节的数据，**没有改动任何一条指令**：printf 系函数在格式字符串里没有 `%` 占位符时根本不会去读可变参数列表，所以这个改动除了"不再打印这行日志"之外不可能产生任何其他副作用。已经在 iOS（`iPhone17,3`）和 macOS（`Mac16,10`）两份 `bootkc` 上分别验证过——这段字符串在两边都**只出现一次、字节完全相同**。

这两个补丁都是 `get_files.sh` 自动执行的一部分，不需要手动操作，也不用担心重新拉取固件之后忘记补。

## 已验证的主机配置

主 README 里的兼容性表格说的是**客户机**（跑在 VM 里的 iOS/macOS 设备型号）。上面这套 Linux 宿主机方案是在下面这台机器上验证通过的：

| 项目 | 配置 |
|---|---|
| CPU | AMD Ryzen 9 9950X（16核 / 32线程） |
| 主板 | ASUS ROG Crosshair X870E Hero |
| 显卡 | NVIDIA GeForce RTX 2080 Ti |
| 内存 | 64 GB |
| 架构 | x86_64 |
| 操作系统 | Ubuntu 24.04 LTS，内核 7.0.0-30-generic |

这些配置**都不是硬性要求**——整套流程主要是单线程 CPU 工作加一个软件模拟的 qemu 虚拟机，性能远低于此的 Linux 机器大概率也能跑起来。列在这里只是作为"已验证可用"的参考配置。
