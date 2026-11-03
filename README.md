# Network Dot

**English** | [简体中文](README.zh-CN.md)

A tiny native macOS internet indicator at the bottom-right of **every screen**. No menu-bar or Dock icon.

**[Download the latest release](https://github.com/A-Very-Long-Name/Network-Dot/releases/latest)**

NOTE: Code and descriptions created by ChatGPT/Codex. All ideas are otherwise original.

## Install

**macOS 13 Ventura or later · Apple Silicon and Intel (Universal)**

1. Download `Network-Dot-1.1.1-universal.dmg` from Releases.
2. Open the disk image and drag **Network Dot** to **Applications**.
3. Open the app from Applications. Choose whether to launch at login in the welcome dialog.
4. Right-click the small dot at the bottom-right for settings, language, details, or Quit.

**This release is ad-hoc signed, not Apple-notarized.** macOS may block the first launch. If you trust this download, follow [Apple's official instructions](https://support.apple.com/102445) in System Settings → Privacy & Security → Open Anyway. Do not disable Gatekeeper. Managed school Macs may prevent this exception; ask the administrator if necessary.

## Status

| Dot | Meaning |
| --- | --- |
| Green | At least one HTTPS probe succeeded within the last 2 seconds. |
| Red | Network interface disconnected, or no successful probe for 2 seconds. |
| Gray | First checks after launch, wake, or a network change. |

One probe starts every second against the preferred target, **Apple by default**. If it fails or has not responded after 0.6 seconds, the other targets are tried in parallel. The first success cancels remaining probes and becomes the preferred target. While using a backup, Apple (or the first custom URL) is retried once per minute. Each request has a 1.5-second timeout; rounds do not overlap. Healthy requests are reduced from three per second to one (about 67% fewer). Slow or failing targets cause additional backup requests. The display checks freshness every 0.25 seconds. Interface disconnection and successful recovery update as soon as their callbacks arrive. **The 2-second threshold is measured from the last successful response, not the exact moment an outage starts.** In-flight responses and OS scheduling can affect observed delay. Short latency spikes may cause a brief red dot.

The center is 8 points across with a one-physical-pixel black border, aligned for both standard and Retina displays. Non-activating overlay panels span Spaces and full-screen apps, and are reasserted after desktop/app transitions. Behavior during OS-controlled transition animations, screen lock, and protected system surfaces is not guaranteed. Only the small 16×16-point panel receives mouse events; everything else remains interactive.

## Checks and school networks

Apple is preferred for its small, fixed 68-byte success page. Google gstatic and Cloudflare remain backups. No ICMP ping is used. A single blocked website does not turn the dot red if another target passes.

| Default HTTPS target | Required response |
| --- | --- |
| `https://www.apple.com/library/test/success.html` | HTTP 200 + `<TITLE>Success</TITLE>` |
| `https://www.gstatic.com/generate_204` | HTTP 204 |
| `https://www.cloudflare.com/cdn-cgi/trace` | HTTP 200 + `ip=` |

System TLS certificate validation must pass, and the final response hostname must match the original. Redirected sign-in portals and unexpected content do not pass the built-in checks. If **all** targets are blocked, the app cannot distinguish that from an internet outage. Green means at least one probe is reachable; it does not mean every service works.

Custom HTTPS URLs: up to five, one per line, with your preferred target first. Same-host HTTP 2xx counts as success, without a content check. Use small public pages that do not require sign-in. Leave the field empty to restore defaults. For school use, test multiple permitted external websites on the actual school network.

## Privacy

No telemetry, analytics, browsing-history access, packet capture, or file upload. Requests go directly from the Mac to the configured endpoints; their operators see ordinary request information including the public IP address. Preferences (URLs, language, first-run choice) are stored locally. No request log is written. No Accessibility, Screen Recording, or administrator permission is needed for the app itself. Internet connectivity is required for probes.

## Launch at login and uninstall

Choose **Launch at login** in the dot's context menu, or manage it in System Settings → General → Login Items. On first run, login startup is your choice. Quit does not disable the next login launch. To uninstall, turn off Launch at login, quit, then move the app to Trash.

## Build

Requires Xcode Command Line Tools with a current macOS SDK. No third-party dependencies.

```sh
./scripts/test.sh
./scripts/build.sh
./scripts/package.sh
```

`dist/Network Dot.app` contains both arm64 and x86_64 slices. Tests cover state transitions, failure expiration, immediate recovery, network-change reset, primary-only rounds, failover, duplicate suppression, and periodic preferred-target retry. Intel and older macOS builds are compile-checked; live testing was on Apple Silicon macOS 27.2. No claim of testing every multi-monitor or full-screen configuration.

For notarized distribution, use your own Developer ID Application certificate, submit the app with `xcrun notarytool`, and staple the ticket before packaging. This repository contains no signing credentials.
