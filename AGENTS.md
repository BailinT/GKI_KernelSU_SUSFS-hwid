# GKI_KernelSU_SUSFS HWID 测试副本规则

接着上个窗口继续时，先读 `docs/当前会话交接.md`。

- 本目录是 `BailinT/GKI_KernelSU_SUSFS` 的独立测试副本，不修改原目录或远程原仓库。
- `origin` 指向新仓库 `BailinT/GKI_KernelSU_SUSFS-hwid`（PRIVATE）；`upstream` 指向原仓库，push URL 已设为 `DISABLED`。
- `hwid/allowlist.txt` 是允许启动内核的完整白名单，一行一个；修改后必须重新构建。
- 白名单外或读取不到 HWID 的设备会在 early boot 阶段 panic，并在 1 秒后重启。
- 注入点在共享的 `.github/workflows/build.yml`（`repo sync` 之后、编译之前），一处覆盖全部 Android 版本。
- 本仓库编译 5.10~6.12，`hwid_lock.c` 不要 include `<linux/panic.h>`（5.10 无此头）。
