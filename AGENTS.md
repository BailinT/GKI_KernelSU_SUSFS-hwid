# GKI_KernelSU_SUSFS HWID 测试副本规则

接着上个窗口继续时，先读 `docs/当前会话交接.md`。

- 本目录是 `zzh20188/GKI_KernelSU_SUSFS` 的独立测试副本，不修改远程上游仓库。
- `origin` 指向新仓库 `BailinT/GKI_KernelSU_SUSFS-hwid`（PRIVATE）；`upstream` 指向 `zzh20188/GKI_KernelSU_SUSFS`，push URL 已设为 `DISABLED`。
- `hwid/allowlist.txt` 是允许启动内核的完整白名单，一行一个；修改后必须重新构建。
- 白名单外或读取不到 HWID 的设备会在 early boot 阶段 panic，并在 1 秒后重启。
- HWID 来源 key 因厂商而异，`hwid_lock.c` 的 `hwid_keys[]` 必须覆盖：`androidboot.chipid`（欧加真等高通）、`androidboot.cpuid`（小米/HyperOS）、`androidboot.serialno`、`oplusboot.serialno`。
- 校验逻辑必须**逐个 key 都比对白名单**，不能首个 key 读到值就返回；同一台设备可能同时存在多个 key，只有其中一个在白名单里。
- 新设备第一次上锁前，先用 dry run 出一版验证：`HWID_LOCK_DRY_RUN=1` 或建 `hwid/DRYRUN` 文件，刷机后 `dmesg | grep "HWID lock"` 看内核实际读到什么，再关掉 dry run 正式构建。
- panic 发生在 console/pstore 初始化之前，`/sys/fs/pstore` **不会**留下日志，靠日志排查行不通。
- Android 12+ 的 `androidboot.*` 参数放在 **bootconfig**（`/proc/bootconfig`）而不是 cmdline（`/proc/cmdline` 里一个都没有），所以读取必须走 `xbc_find_value()`，只解析 `boot_command_line` 一定读不到。注入点在 `setup_command_line()` 之后，而 `setup_boot_config()` 必然更早（后者产出的 `extra_command_line` 是前者的输入），xbc 在此处一定可用。
- **不用刷机就能查设备 ID 源**：把 `hwid/probe_hwid.sh` 放到 `/sdcard`，用 MT 管理器直接跑，会输出 bootconfig / cmdline 两侧的逐 key 结果到 `/sdcard/hwid_probe.log`。上锁前先跑这个，比出 dry run 内核快得多。实测小米 14 Pro（shennong）：`androidboot.cpuid=0x0000044864acd92f`（bootconfig），`androidboot.chipid` 与 `oplusboot.serialno` 均不存在。
- 注入点在共享的 `.github/workflows/build.yml`（`repo sync` 之后、编译之前），一处覆盖全部 Android 版本。
- 本仓库编译 5.10~6.12，`hwid_lock.c` 不要 include `<linux/panic.h>`（5.10 无此头）；`kstrtoull` 用 `<linux/kernel.h>` 即可，不要 include `<linux/kstrtox.h>`（5.10 无此头）。
