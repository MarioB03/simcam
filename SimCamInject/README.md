# SimCamInject

Dylib de inyección para el Simulador de iOS que permite que el escáner de códigos de
barras/QR de **una app iOS funcione en el Simulador sin cámara real y sin tocar la app**.
La inyección intercepta AVFoundation mediante swizzling ObjC, pinta frames reales en la
capa de preview y entrega los códigos decodificados al delegate — todo desde fuera.

---

## Qué hace

| Componente | Función |
|---|---|
| **SimCamHost / SimCamProbe** | Proceso macOS que captura la región del escritorio tapada por la ventana del Simulador, decodifica QR/códigos con Vision y sirve el resultado sobre HTTP `127.0.0.1:8474` |
| **`/stream`** | MJPEG de los frames capturados (preview en la app) |
| **`/codes`** | SSE — JSON `{"type","stringValue"}` por cada código detectado |
| **SimCamInject.dylib** | Se inyecta en la app objetivo vía `DYLD_INSERT_LIBRARIES`; swizzlea `AVCaptureSession` y `AVCaptureMetadataOutput` para que el escáner funcione en el Simulador sin cámara real |

La dylib es **solo para el Simulador** (`iphonesimulator` slice). En dispositivo real la
app usa la cámara física; la dylib no se inyecta.

---

## Requisitos

- Simulador arrancado (`xcrun simctl bootstatus <UDID> -b`).
- **Permiso de Grabación de pantalla** concedido al terminal (o a `swift`) en Ajustes del sistema → Privacidad.
- `xcodegen` instalado (`brew install xcodegen`).

---

## Tipos de código compatibles

Los tipos habituales de `AVCaptureMetadataOutput`:

`.qr`, `.code128`, `.ean8`, `.ean13`, `.upce`, `.code39`

El host decodifica estos tipos con Vision en el Mac. (Vision de códigos **no funciona
dentro del Simulador** en iOS 26.x — por eso la decodificación es del lado del Mac.)

---

## Uso con la app GUI (recomendado)

La forma más cómoda de usar SimCam es a través de la app **SimCam Host**, una app macOS
firmada con bundle id fijo (`com.simcam.host`). Al tener un bundle id estable, el permiso
de **Grabación de pantalla** se concede una sola vez y persiste entre recompilaciones y
reinicios, sin tener que volver a pedir permiso cada vez.

### 1. Compilar y empaquetar la app

```bash
# desde la raíz del repo
./scripts/build-simcam-host-app.sh
```

Esto compila `SimCamHost` en release, ensambla el bundle en `~/Applications/SimCam Host.app`
y lo firma. Solo es necesario repetirlo si cambias el código fuente del host.

> Para usar una identidad de firma estable (necesario si el permiso TCC se pierde con la
> firma ad-hoc), exporta tu identidad antes de ejecutar:
> ```bash
> export SIMCAM_SIGN_IDENTITY="Apple Development: Tu Nombre"
> ./scripts/build-simcam-host-app.sh
> ```

### 2. Conceder Grabación de pantalla (solo la primera vez)

1. Abre `~/Applications/SimCam Host.app`.
2. Ve a **Ajustes del Sistema → Privacidad y Seguridad → Grabación de pantalla**.
3. Activa **SimCam Host** en la lista.
4. Cierra y reabre la app.

A partir de aquí el permiso queda asociado al bundle id `com.simcam.host` y **no se pierde
al recompilar**.

### 3. Flujo de uso desde la GUI

1. Pulsa **Capturar** — el estado cambia a verde y el fps sube de 0.
2. Elige la fuente de la app iOS que quieres probar:
   - **App instalada en el Simulador**: selecciónala de la lista.
   - **Proyecto Xcode**: indica la ruta al `.xcodeproj`/`.xcworkspace` y elige el scheme; la app lo compila e instala automáticamente.
3. Pulsa **Lanzar con SimCam** — SimCam inyecta la dylib y abre la app con la cámara simulada activa.
4. Abre el escáner dentro de la app iOS — verás el preview en vivo y los códigos detectados.

---

## Uso headless (SimCamProbe — debugging/CI)

`SimCamProbe` es la variante de línea de comandos, útil para debugging o integración en CI
donde no hay GUI. El permiso de Grabación de pantalla debe concederse al terminal o proceso
que lo ejecute (lo cual puede ser frágil en CI sin configuración adicional).

### 1. Arrancar el host

```bash
cd SimCamHost
swift run SimCamProbe
```

El host imprime:

```
PROBE: sirviendo en http://127.0.0.1:8474/stream
```

Si el sistema pide permiso de Grabación de pantalla, concédelo y vuelve a ejecutar el comando.

### 2. Posicionar el código bajo la ventana del Simulador

Abre la imagen del QR o etiqueta en el Mac (Finder, Preview, navegador…) y arrastra la
ventana del **Simulador encima** del código. El host captura exactamente esa región del
escritorio, como si el Simulador fuera transparente.

### 3. Lanzar la app con la dylib inyectada

Compila la dylib (ver más abajo) y lanza la app ya instalada en el Simulador con la dylib
inyectada:

```bash
DYLIB="$PWD/SimCamInject/.build-xcode/Build/Products/Debug-iphonesimulator/SimCamInject.dylib"
SIMCTL_CHILD_DYLD_INSERT_LIBRARIES="$DYLIB" \
  xcrun simctl launch <UDID> <bundle-id>
```

> **IMPORTANTE:** la ruta de la dylib debe ser **absoluta**. Una ruta relativa es ignorada
> silenciosamente por dyld y la inyección no ocurre.

Abre el escáner en la app → verás el preview en vivo de lo que hay detrás del Simulador, y
el escaneo se produce de forma automática cuando el código queda centrado.

---

## Verificar que la inyección funciona

```bash
xcrun simctl spawn <UDID> log show \
  --last 2m \
  --predicate 'eventMessage CONTAINS "[SimCamInject]"' \
  --style compact
```

Una inyección correcta muestra, al lanzar y al abrir el escáner, líneas como:

```
[SimCamInject] dylib cargada (pid=40996)
[SimCamInject] shims AVFoundation instalados
[SimCamInject] preview layer enganchada
[SimCamInject] AVCaptureDevice.default(for:) -> fake
[SimCamInject] metadataOutput capturado
[SimCamInject] delegate capturado: <TuApp.BarcodeScannerViewController: 0x...>
[SimCamInject] entregado código (captureOutput:) type=org.gs1.EAN-13 value=1234567890128
```

El selector que se entrega al delegate es `captureOutput:didOutputMetadataObjects:fromConnection:`
(Swift: `metadataOutput(_:didOutput:from:)`).

---

## Arquitectura interna de la dylib

| Archivo | Responsabilidad |
|---|---|
| `SimCamInject.m` | `+load` — punto de entrada, arranca el swizzling |
| `AVFoundationShims.m` | Swizzle de `AVCaptureSession` y `AVCaptureDevice` |
| `PreviewLayerShim.m` | Inyecta frames MJPEG en `AVCaptureVideoPreviewLayer` |
| `PreviewClient.m/.h` | Cliente MJPEG — consume `/stream` |
| `CodeStreamClient.m/.h` | Cliente SSE — consume `/codes` |
| `SimCamDelivery.m/.h` | Fabrica `AVMetadataObject` sintéticos y los entrega al delegate |
| `SimCamMetadataObject.m/.h` | Subclase de `AVMetadataMachineReadableCodeObject` (compilada sin ARC) |
| `SimCamBridge.m/.h` | Coordinación entre preview y entrega de códigos |

La dylib se construye con XcodeGen (`project.yml`, `library.dynamic`, slice
`iphonesimulator`). El producto lleva el nombre `SimCamInject.dylib` sin prefijo `lib`.

---

## Construcción manual de la dylib

```bash
cd SimCamInject
xcodegen          # regenera SimCamInject.xcodeproj
xcodebuild \
  -project SimCamInject.xcodeproj \
  -scheme SimCamInject \
  -sdk iphonesimulator \
  -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build-xcode \
  build
# dylib en: .build-xcode/Build/Products/Debug-iphonesimulator/SimCamInject.dylib
```

---

## Limitaciones conocidas (MVP)

- **Swizzling a nivel de proceso.** `method_setImplementation` reemplaza la implementación para *todas* las instancias del proceso. La dylib asume **una única sesión de captura activa** (el escáner de la app). Si la app inyectada usara AVFoundation para otra cosa (otra `AVCaptureSession`, `AVCaptureVideoPreviewLayer` o `AVCaptureDevice.default(for:)`), también recibiría los shims fake.
- **Los clientes de red arrancan en `+load`.** `CodeStreamClient` y `PreviewClient` se conectan a `127.0.0.1:8474` en cuanto se carga la dylib y reintentan cada 1 s durante toda la vida del proceso, aunque no se abra el escáner.
- **No se dibuja el recuadro de detección.** El objeto de metadata fabricado devuelve `corners` vacío, así que la app no anima el recuadro sobre el código; la **entrega del código no se ve afectada**.
- **Solo Simulador, solo debug.** La dylib se compila para el slice `iphonesimulator` y se inyecta manualmente; en dispositivo la app usa la cámara real, intacta.
