# SimCam

**A fake camera for the iOS Simulator.** SimCam captures the part of your Mac desktop that sits behind the Simulator window and feeds it to an iOS app as if it were the device camera. You can test barcode/QR scanners and camera flows in the Simulator with no physical device and no changes to the app.

<p>
  <img src="https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/macOS-14+-000000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/ScreenCaptureKit-capture-3A3C52" alt="ScreenCaptureKit">
  <img src="https://img.shields.io/badge/Vision-barcode_decoding-3A3C52" alt="Vision">
  <img src="https://img.shields.io/badge/Objective--C-runtime_swizzling-438EFF" alt="Objective-C">
  <img src="https://img.shields.io/badge/tests-46_passing-3FD37F" alt="46 tests passing">
</p>

The macOS host app runs as a companion panel docked to the Simulator window, similar to RocketSim. It sticks to the Simulator's right edge, follows it when you move it and minimises with it.

## Why

The iOS Simulator has no camera. Scanning a code there usually means one of three workarounds: a debug-only "paste a barcode" screen, mocks inside the app, or reaching for a real device. SimCam removes that step. Open a QR code or a product label on your Mac, drag the Simulator over it, and the app's own `AVFoundation` scanner reads it.

## How it works

```
┌───────────────────────────┐      /stream  (MJPEG)       ┌──────────────────────────┐
│ SimCam Host (macOS)        │ ──────────────────────────▶ │ iOS app in the Simulator  │
│  · ScreenCaptureKit        │      /codes   (SSE)         │  + SimCamInject.dylib     │
│  · Vision barcode decoding │ ──────────────────────────▶ │  (AVFoundation swizzling) │
│  · HTTP on 127.0.0.1:8474  │                             └──────────────────────────┘
│  · window docking          │
└───────────────────────────┘
```

1. **Capture.** The host finds the Simulator window and uses ScreenCaptureKit to capture the desktop region underneath it.
2. **Decode.** Vision decodes barcodes on the Mac. Barcode detection with Vision doesn't work inside the iOS 26 Simulator, so decoding happens host-side.
3. **Serve.** Frames go out as MJPEG on `/stream`, and each detected code goes out as a Server-Sent Event on `/codes`.
4. **Inject.** The app launches with `DYLD_INSERT_LIBRARIES` pointing at `SimCamInject.dylib`. The dylib swizzles `AVCaptureSession`, `AVCaptureDevice`, `AVCaptureVideoPreviewLayer` and `AVCaptureMetadataOutput`. The app's preview then shows the live frames, and its delegate receives real `AVMetadataMachineReadableCodeObject`s through `metadataOutput(_:didOutput:from:)`.

Supported symbologies: `.qr`, `.code128`, `.ean8`, `.ean13`, `.upce`, `.code39`.

## Project layout

| Module | What it is |
|---|---|
| **SimCamHost** | macOS SwiftUI app. It captures the screen, serves the frames, builds and launches Simulator apps with the dylib injected, and docks its window to the Simulator. |
| **SimCamHostKit** | Testable core of the host: crop and anchor geometry, MJPEG/SSE framing, the HTTP server, and the `simctl`/`xcodebuild` services. |
| **SimCamProbe** | Headless CLI variant of the host, for debugging and CI. |
| **SimCamInject** | Objective-C dylib (simulator slice only) that hooks `AVFoundation` inside the target app. |
| **SimCam** | Swift client for the camera feed: MJPEG parser, decoder and session. |
| **SimCamSample** | Sample iOS app for end-to-end testing. |

## Quick start

Requirements: a Mac with Apple Silicon, Xcode with the iOS Simulator, and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
# 1. Build, bundle and sign the macOS app (the dylib is embedded)
./scripts/build-simcam-host-app.sh

# 2. Open ~/Applications/SimCam Host.app and grant Screen Recording (first run only)
#    System Settings → Privacy & Security → Screen Recording

# 3. Press "Capturar", pick an installed app or an Xcode project + scheme,
#    then press "Lanzar con SimCam" (the UI is in Spanish)
```

The host app has a fixed bundle id, so the Screen Recording permission survives rebuilds. If macOS keeps asking again with ad-hoc signing, set `SIMCAM_SIGN_IDENTITY="Apple Development: Your Name"` before running the script.

For headless use (`swift run SimCamProbe`), manual dylib builds and log-based verification, see [`SimCamInject/README.md`](SimCamInject/README.md).

## Tests

```bash
cd SimCamHost && swift test   # 37 tests: geometry, framing, server, services
cd SimCam && swift test       # 9 tests: MJPEG parsing and decoding
```

## Limitations

SimCam is an experimental MVP, meant for debug builds in the Simulator only.

- **Process-wide swizzling.** The hooks assume a single active capture session. Any other `AVFoundation` capture use in the same app also gets the fake camera.
- **Always-on clients.** The dylib connects to `127.0.0.1:8474` as soon as it loads and retries every second, even if the scanner is never opened.
- **No detection overlay.** The synthetic metadata objects have empty `corners`, so apps that draw a box around the code won't draw one. Code delivery still works.
- **Simulator only.** The dylib is built for the `iphonesimulator` slice and injected manually. On a real device, the app uses its real camera, untouched.

## Author

Built by [Mario Belenguer](https://mariobelenguer.web.app) · [GitHub](https://github.com/MarioB03) · Released under the [MIT License](LICENSE).
