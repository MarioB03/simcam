# SimCam

Herramienta para macOS que da una **cámara "falsa" al Simulador de iOS**: captura una
región del escritorio del Mac (lo que queda detrás de la ventana del Simulador) y la
entrega a las apps iOS como si fuera la cámara del dispositivo. Permite probar escáneres
de códigos/QR y flujos de cámara en el Simulador, **sin cámara real y sin modificar la app**.

Incluye un **panel acompañante** que se ancla a la ventana del Simulador (estilo RocketSim):
se pega a su borde derecho, lo sigue al moverlo y se minimiza con él.

---

## Componentes

| Módulo | Qué es |
|---|---|
| **SimCamHost** | App macOS (SwiftUI). Captura la pantalla con ScreenCaptureKit, sirve los frames por HTTP, lanza apps del Simulador con la dylib inyectada y ancla su ventana al Simulador. |
| **SimCamHostKit** | Lógica reutilizable y testeable del host (captura, geometría, servidor MJPEG, servicios de `simctl`/`xcodebuild`, anclaje de ventana). |
| **SimCamInject** | Dylib ObjC que se inyecta en la app iOS y hace que su pipeline de `AVFoundation` reciba los frames del host. Ver [`SimCamInject/README.md`](SimCamInject/README.md). |
| **SimCam** | Cliente Swift de la señal de cámara (parser MJPEG, decodificador, sesión). |
| **SimCamSample** | App iOS de ejemplo para probar el flujo de extremo a extremo. |

---

## Cómo funciona

```
┌──────────────────────────┐        /stream (MJPEG)        ┌─────────────────────────┐
│ SimCamHost (macOS)        │  ───────────────────────────▶ │ App iOS en el Simulador  │
│  · ScreenCaptureKit       │        /codes  (SSE)          │  + SimCamInject.dylib    │
│  · servidor 127.0.0.1:8474│  ───────────────────────────▶ │  (swizzle AVFoundation)  │
│  · anclaje de ventana     │                               └─────────────────────────┘
└──────────────────────────┘
```

1. El host captura la región del escritorio bajo la ventana del Simulador y la publica en `http://127.0.0.1:8474`.
2. Al lanzar la app iOS con `DYLD_INSERT_LIBRARIES`, la dylib intercepta `AVFoundation` y alimenta esos frames a la cámara/escáner de la app.
3. La ventana del host se ancla al Simulador y lo acompaña.

---

## Inicio rápido

```bash
# 1) Empaquetar y firmar la app de macOS
./scripts/build-simcam-host-app.sh

# 2) Abrir ~/Applications/SimCam Host.app y conceder Grabación de pantalla (solo la 1ª vez)
# 3) Capturar, elegir la app del Simulador y pulsar "Lanzar con SimCam"
```

Guía detallada (incluido el uso headless por línea de comandos) en
[`SimCamInject/README.md`](SimCamInject/README.md).

---

## Requisitos

- macOS con Apple Silicon, Xcode + Simulador de iOS.
- `xcodegen` (`brew install xcodegen`) para construir la dylib.
- Permiso de **Grabación de pantalla** para la app/terminal que captura.

---

## Tests

```bash
cd SimCamHost && swift test
```

---

## Estado

Proyecto MVP / experimental. Solo Simulador (no toca dispositivos reales).
