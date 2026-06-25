// SimCamProbe — host headless (lado Mac): captura detrás de la ventana del Simulador (con seguimiento),
// decodifica códigos con Vision y sirve /stream + /codes en 127.0.0.1:8474. Vía de arranque del host
// recomendada para usar SimCamInject con la app. Ver SimCamInject/README.md.
import SimCamHostKit
import Foundation

guard let target = try await SimulatorWindowLocator.current().first else {
    FileHandle.standardError.write(Data("PROBE: no se encontró ventana de Simulador\n".utf8))
    exit(1)
}
print("PROBE: target='\(target.title)' frame=\(target.scWindow.frame) scale=\(target.scaleFactor)")
let encoder = JPEGEncoder()
let decoder = BarcodeDecoder()
let server = MJPEGServer()
try server.start()
print("PROBE: sirviendo en http://\(SimCamProtocol.host):\(SimCamProtocol.port)\(SimCamProtocol.path)")
let capturer = ScreenCapturer(target: target) { buffer in
    if let jpeg = encoder.encode(buffer) { server.broadcast(jpeg: jpeg) }
    if let code = decoder.decode(buffer).first,
       let json = try? JSONEncoder().encode(["type": code.type, "stringValue": code.stringValue]) {
        server.broadcastCode(json)
    }
}
try await capturer.start()
print("PROBE: capturando (con seguimiento) 300s")
try await Task.sleep(nanoseconds: 300_000_000_000)
await capturer.stop()
server.stop()
print("PROBE: fin")
