# Security Hardening — ad-free build

This fork branch (`security/ad-free-hardening-318a35f`) hardens the Vertical Canvas OBS plugin
against the advertising/telemetry, memory-safety, and supply-chain issues found in an independent
security review of upstream commit `318a35f`. This document is the durable record of what changed
and what must not be reverted.

## Invariants (must hold at all times)

1. **No automatic advertising or promotional UI.** The plugin must not build UI from any remote source.
2. **No stable install identifier leaves the machine.** OBS `InstallGUID` is never transmitted.
3. **No automatic Aitum API request.** There is no HTTP client in the plugin at all.
4. **No remote server can create or style plugin UI** (no server-supplied labels, QSS, URLs, or images).
5. **No PR build receives signing, notarization, release, or publishing secrets.**
6. **No unsigned artifact is represented as an official release.**
7. **No stream key appears in logs, workflow output, artifacts, crash reports, or WebSocket responses.**

## What was removed

- The automatic `https://api.aitum.tv/plugin/vertical?uuid=<InstallGUID>` request.
- `partnerBlocks` parsing/rendering (`CanvasDock::ApiInfo`) — server-controlled buttons, QSS,
  base64 images, and arbitrary-URL links.
- The Stream Suite auto-update prompt (`CanvasDock::AskUpdate`).
- The donation ("contribute") and Aitum-logo promotion buttons in the dock button row.
- The `file-updater` module and the `libcurl` dependency it required.
- The GitHub Sponsors / donation `FUNDING.yml`.

## What was intentionally kept

- User-initiated help/documentation links (settings dialog "guide"/Discord buttons) — these open
  only on explicit click.
- Non-promotional author attribution ("Made by Aitum") in the settings dialog.
- The `aitum-stream-suite` module conflict check in `obs_module_load` (prevents a broken dual install;
  it is not an advertisement).

## Regression guard

`.github/scripts/check-no-ads.sh` (run by `.github/workflows/security-guard.yaml` on every push/PR)
fails the build if compiled C/C++/header or CMake sources reintroduce the Aitum API, `InstallGUID`,
`partnerBlocks`, donation/promotion links, the Stream Suite update URL, or the updater. It ignores
pure comment lines so documentation of the removal does not trip it.

## Deployment guidance (OBS WebSocket)

The plugin registers OBS-websocket vendor requests (including `update_stream_key`,
`update_stream_server`, and `save_backtrack`). These are reachable by any authenticated
obs-websocket client. Operators **must**:

- Enable obs-websocket authentication with a strong password.
- Bind obs-websocket to loopback, or restrict it with a firewall / VPN. Do not expose it to untrusted
  networks.
- Treat the stream key as a secret: it is stored in plaintext in the plugin config JSON (an OBS
  compatibility constraint) and must never be logged, uploaded as a CI artifact, or included in
  diagnostics. No WebSocket response returns it.
