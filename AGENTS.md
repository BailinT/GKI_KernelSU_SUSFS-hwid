# GKI_KernelSU_SUSFS HWID 测试副本规则

接着上个窗口继续时，先读 `docs/当前会话交接.md`。

本目录是 `zzh20188/GKI_KernelSU_SUSFS` 的独立测试副本，不修改远程上游仓库。

## 仓库地址（四个别搞混）

| 角色 | 地址 | 默认分支 |
|---|---|---|
| 上游源头 | https://github.com/WildKernels/GKI_KernelSU_SUSFS | main |
| 中间 fork（本仓库 upstream） | https://github.com/zzh20188/GKI_KernelSU_SUSFS | dev |
| 自有 fork（**不带 ID 校验**） | https://github.com/BailinT/GKI_KernelSU_SUSFS | dev |
| **本仓库**（带 ID 校验） | https://github.com/BailinT/GKI_KernelSU_SUSFS-hwid | main |

- `origin` = https://github.com/BailinT/GKI_KernelSU_SUSFS-hwid.git；`upstream` = https://github.com/zzh20188/GKI_KernelSU_SUSFS.git，push URL 已设为 `DISABLED`。
- 不带 ID 校验的 `BailinT/GKI_KernelSU_SUSFS` 出的包任何设备都能刷；本仓库出的包只认 `hwid/allowlist.txt` 内的设备，名单外 early boot panic。两边产物别混。

## 规则

- 本地分支名是 `hwid-main`，跟踪的却是 `origin/main`，两者**不同名**。所以 `git push origin HEAD` 会在远程新建一个 `hwid-main` 分支，而**不会**推到 `main`（构建仍是旧代码）。必须显式写 `git push origin hwid-main:main`。
- `hwid/allowlist.txt` 是允许启动内核的完整白名单，一行一个；修改后必须重新构建。
- 白名单外或读取不到 HWID 的设备会在 early boot 阶段 panic，并在 1 秒后重启。
- HWID 来源 key 因厂商而异，`hwid_lock.c` 的 `hwid_keys[]` 必须覆盖：`androidboot.chipid`（欧加真等高通）、`androidboot.cpuid`（小米/红米/POCO/黑鲨、HyperOS）、`androidboot.emmcid`（努比亚/红魔）、`androidboot.serialno`（vivo/iQOO、联想/摩托、兜底）、`oplusboot.serialno`（欧加备用）。
- 本仓库编的是**通用 GKI**（5.10~6.12 全矩阵，不绑机型），所以小米/红米/红魔这类非欧加设备都走这个仓库；`Action-Build-hwid` 只编一加官方清单内核（下拉框 61 项全是 `oneplus_*`），`smXXXX-hwid` 只编欧加真 OKI 内核，那三个仓库不需要米系/红魔的 key。
- 改了 `hwid_keys[]` 就要同步 `hwid/probe_hwid.sh` 的 key 循环，两边列表必须一致，否则探测脚本会漏掉内核真正会读的 key。
- 校验逻辑必须**逐个 key 都比对白名单**，不能首个 key 读到值就返回；同一台设备可能同时存在多个 key，只有其中一个在白名单里。
- 新设备第一次上锁前，先用 dry run 出一版验证：`HWID_LOCK_DRY_RUN=1` 或建 `hwid/DRYRUN` 文件，刷机后 `dmesg | grep "HWID lock"` 看内核实际读到什么，再关掉 dry run 正式构建。
- panic 发生在 console/pstore 初始化之前，`/sys/fs/pstore` **不会**留下日志，靠日志排查行不通。
- Android 12+ 的 `androidboot.*` 参数放在 **bootconfig**（`/proc/bootconfig`）而不是 cmdline（`/proc/cmdline` 里一个都没有），所以读取必须走 `xbc_find_value()`，只解析 `boot_command_line` 一定读不到。注入点在 `setup_command_line()` 之后，而 `setup_boot_config()` 必然更早（后者产出的 `extra_command_line` 是前者的输入），xbc 在此处一定可用。
- **不用刷机就能查设备 ID 源**：把 `hwid/probe_hwid.sh` 放到 `/sdcard`，用 MT 管理器直接跑，会输出 bootconfig / cmdline 两侧的逐 key 结果到 `/sdcard/hwid_probe.log`。上锁前先跑这个，比出 dry run 内核快得多。要核对某个 ID 是不是来自预期的 key，把它当第一个参数传进去：`sh /sdcard/probe_hwid.sh 91c3b8f2`，命中的那行会标 `** MATCHES EXPECTED **`；不传参数也会照常 dump 全部 key，只是不做比对。实测小米 14 Pro（shennong）：`androidboot.cpuid=0x0000044864acd92f`（bootconfig），`androidboot.chipid` 与 `oplusboot.serialno` 均不存在。
- 注入点在共享的 `.github/workflows/build.yml`（`repo sync` 之后、编译之前），一处覆盖全部 Android 版本。
- **刷之前先验产物二进制，别只信 CI 日志**：直接在产物 `Image` 上搜字符串即可确认锁真的编进去了 —— 应命中 `androidboot.cpuid`、`HWID lock: device authorized via`、白名单里的 ID 本身；`HWID lock: DRY RUN` 应**不命中**（命中说明误进 dry run，刷了等于没上锁）。ripgrep 在二进制文件上也能判定命中，用 count 模式即可。
- `gh run download -n <artifact>` 会**自动解包**成散文件，不是 zip；AnyKernel3 必须打包成 zip（`anykernel.sh`/`Image`/`META-INF/`/`tools/` 位于 zip **根目录**）才能刷。要现成 zip 就走网页端 Artifacts 下载。
- 本仓库编译 5.10~6.12，`hwid_lock.c` 不要 include `<linux/panic.h>`（5.10 无此头）；`kstrtoull` 用 `<linux/kernel.h>` 即可，不要 include `<linux/kstrtox.h>`（5.10 无此头）。
