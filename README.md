# Network Dot · 网络状态点

A tiny native macOS internet indicator at the bottom-right of **every screen**. No menu-bar or Dock icon.

每个屏幕右下角的原生网络状态小点，无菜单栏或 Dock 图标。支持简体中文和 English，自动跟随系统，也可手动切换。

**[Download the latest release / 下载最新版](https://github.com/A-Very-Long-Name/Network-Dot/releases/latest)**

## Install / 安装

**macOS 13 Ventura or later · Apple Silicon and Intel (Universal)**

1. Download `Network-Dot-1.1.0-universal.dmg` from Releases.
2. Open the disk image and drag **Network Dot** to **Applications**.
3. Open the app from Applications. Choose whether to launch at login in the welcome dialog.
4. Right-click the small dot at the bottom-right for settings, language, details, or Quit.

1. 从 Releases 下载 `Network-Dot-1.1.0-universal.dmg`。
2. 打开 DMG，把 **Network Dot** 拖入 **Applications／应用程序**。
3. 从应用程序文件夹打开，首次运行选择是否登录后自动启动。
4. 右键点击屏幕右下角小点，可查看检测详情、更改网址、切换语言或退出。

**This release is ad-hoc signed, not Apple-notarized.** macOS may block the first launch. If you trust this download, follow [Apple's official instructions](https://support.apple.com/102445) in System Settings → Privacy & Security → Open Anyway. Do not disable Gatekeeper. Managed school Macs may prevent this exception; ask the administrator if necessary.

**此版本使用临时签名，尚未经过 Apple 公证。** 首次打开可能被 macOS 阻止。确认下载来源可信后，可按 [Apple 官方说明](https://support.apple.com/102445)，在“系统设置 → 隐私与安全性”中选择“仍要打开”。无需关闭 Gatekeeper。学校管理的 Mac 可能不允许此操作，届时需联系管理员。

## Status / 状态

| Dot / 小点 | Meaning / 含义 |
| --- | --- |
| Green / 绿色 | At least one HTTPS probe succeeded within the last 2 seconds. 最近 2 秒至少一个检测成功。 |
| Red / 红色 | Network interface disconnected, or no successful probe for 2 seconds. 网络接口断开，或 2 秒没有检测成功。 |
| Gray / 灰色 | First checks after launch, wake, or a network change. 启动、唤醒或切换网络后的首次检测。 |

Probes start every second, each with a 1.5-second timeout. The display checks freshness every 0.25 seconds. Interface disconnection and successful recovery update as soon as their callbacks arrive. **The 2-second threshold is measured from the last successful response, not the exact moment an outage starts.** In-flight responses and OS scheduling can affect observed delay. Short latency spikes may cause a brief red dot.

每秒发起检测，单次超时 1.5 秒，每 0.25 秒刷新状态。网络接口断开或检测恢复成功时立即更新。**2 秒从上次成功响应计时，并非精确测量断网发生的时刻**；进行中的响应和系统调度会影响实际延迟。短暂延迟也可能使小点短暂变红。

The center is 8 points across with a one-physical-pixel black border, aligned for both standard and Retina displays. Non-activating overlay panels span Spaces and full-screen apps, and are reasserted after desktop/app transitions. Behavior during OS-controlled transition animations, screen lock, and protected system surfaces is not guaranteed. Only the small 16×16-point panel receives mouse events; everything else remains interactive.

彩色中心直径 8pt，黑边为 1 个物理像素，适配普通屏及 Retina。悬浮点跨桌面和全屏应用显示，切换后自动重新置顶，不激活应用。系统切换动画、锁屏及受保护系统界面中的显示无法保证。只有小点周围 16×16pt 区域接收鼠标事件。

## Checks and school networks / 检测与校园网络

No ICMP ping is used. A single blocked website does not turn the dot red if another target passes.

| Default HTTPS target | Required response |
| --- | --- |
| `https://www.apple.com/library/test/success.html` | HTTP 200 + `<TITLE>Success</TITLE>` |
| `https://www.gstatic.com/generate_204` | HTTP 204 |
| `https://www.cloudflare.com/cdn-cgi/trace` | HTTP 200 + `ip=` |

System TLS certificate validation must pass, and the final response hostname must match the original. Redirected sign-in portals and unexpected content do not pass the built-in checks. If **all** targets are blocked, the app cannot distinguish that from an internet outage. Green means at least one probe is reachable; it does not mean every service works.

不使用 ICMP ping。只要任一目标通过，单个目标被学校屏蔽不会导致红灯。内置目标校验 HTTPS 证书、最终域名及预期响应，减少把认证页当作互联网的情况。**全部目标被屏蔽时，仍无法与断网区分**。绿灯不保证所有网站或服务都能使用。

Custom HTTPS URLs: up to five, one per line. Same-host HTTP 2xx counts as success, without a content check. Use small public pages that do not require sign-in. Leave the field empty to restore defaults. For school use, test multiple permitted external websites on the actual school network.

自定义网址最多 5 个，一行一个 HTTPS 地址；同域 HTTP 2xx 即通过，不校验内容。请使用公开、无需登录的小页面，留空恢复默认。建议在实际校园网络上验证多个允许访问的外部目标。

## Privacy / 隐私

No telemetry, analytics, browsing-history access, packet capture, or file upload. Requests go directly from the Mac to the configured endpoints; their operators see ordinary request information including the public IP address. Preferences (URLs, language, first-run choice) are stored locally. No request log is written. No Accessibility, Screen Recording, or administrator permission is needed for the app itself. Internet connectivity is required for probes.

不收集遥测、不读取浏览记录、不抓包、不上传文件。检测请求直接发往目标服务，对方可见公网 IP 等普通访问信息。网址、语言及首次运行选项保存在本机，不写入请求日志。应用本身无需辅助功能、录屏或管理员权限。检测需要互联网连接。

## Launch at login and uninstall / 登录启动与卸载

Choose **Launch at login** in the dot's context menu, or manage it in System Settings → General → Login Items. On first run, login startup is your choice. Quit does not disable the next login launch. To uninstall, turn off Launch at login, quit, then move the app to Trash.

右键菜单可切换“登录时启动”，也可在“系统设置 → 通用 → 登录项”中管理。首次运行由用户选择。退出不会取消下次登录启动。卸载时先关闭登录启动，退出应用，再将应用移到废纸篓。

## Build / 构建

Requires Xcode Command Line Tools with a current macOS SDK. No third-party dependencies.

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/package.sh
```

`dist/Network Dot.app` contains both arm64 and x86_64 slices. Tests cover state transitions, failure expiration, immediate recovery, and network-change reset. Intel and older macOS builds are compile-checked; live testing was on Apple Silicon macOS 27.2. No claim of testing every multi-monitor or full-screen configuration.

构建需要 Xcode Command Line Tools，无第三方依赖。通用版包含 arm64 和 x86_64。状态测试覆盖超时、恢复、接口断开及网络切换。实机测试环境为 Apple Silicon macOS 27.2；Intel 和较旧系统仅完成编译检查，未覆盖所有多屏与全屏配置。

For notarized distribution, use your own Developer ID Application certificate, submit the app with `xcrun notarytool`, and staple the ticket before packaging. This repository contains no signing credentials.
