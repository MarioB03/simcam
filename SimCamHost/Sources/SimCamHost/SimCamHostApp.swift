import SwiftUI
import SimCamHostKit

@main struct SimCamHostApp: App {
    @State private var capture = CaptureController()
    @State private var launcher = LauncherController()
    @State private var anchor = AnchorController()

    var body: some Scene {
        Window("SimCam", id: "main") {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    SectionCard(title: "Simulador", systemImage: "iphone") {
                        simulatorSection
                    }

                    SectionCard(title: "Lanzar app", systemImage: "play.circle") {
                        LauncherView(
                            controller: launcher,
                            udid: capture.selectedSimUDID,
                            isCapturing: capture.state == .running,
                            startCapture: { await capture.start() }
                        )
                    }
                }
                .controlSize(.small)
                .padding(12)
            }
            .frame(width: 300, height: 350)
            .background(WindowAccessor { anchor.attach(window: $0) })
            .onChange(of: capture.selectedID) { _, newValue in anchor.targetID = newValue }
            .task {
                await capture.refresh()
                // Auto-poblar las apps del simulador al abrir (sin tener que pulsar Refrescar).
                if let udid = capture.selectedSimUDID { launcher.refreshApps(udid: udid) }
                anchor.targetID = capture.selectedID
            }
        }
        .windowResizability(.contentSize)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.title3)
                .foregroundStyle(.tint)
            Text("SimCam").font(.headline)
            Spacer()
            StatusBadge(
                text: anchor.isAnchored ? "Anclado" : "Libre",
                color: anchor.isAnchored ? .green : .secondary
            )
        }
    }

    // MARK: - Simulador

    @ViewBuilder private var simulatorSection: some View {
        HStack(spacing: 6) {
            Picker("Simulador", selection: $capture.selectedID) {
                ForEach(capture.windows) { w in Text(w.title).tag(Optional(w.id)) }
            }
            .labelsHidden()
            Button("Refrescar", systemImage: "arrow.clockwise") { Task { await capture.refresh() } }
                .labelStyle(.iconOnly)
        }

        HStack(spacing: 6) {
            switch capture.state {
            case .idle:
                Label("Cámara parada", systemImage: "stop.circle").foregroundStyle(.secondary)
            case .running:
                Label("Capturando · \(capture.fps) fps", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.green)
            case .error(let msg):
                Label(msg, systemImage: "exclamationmark.triangle").foregroundStyle(.red).lineLimit(2)
            }
            Spacer()
            if capture.state == .running {
                Button("Detener") { Task { await capture.stop() } }
            } else {
                Button("Capturar") { Task { await capture.start() } }
            }
        }
        .font(.caption)
    }
}

// MARK: - Componentes reutilizables

/// Tarjeta de sección con cabecera icónica, estilo inspector.
private struct SectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background.secondary, in: .rect(cornerRadius: 10))
    }
}

/// Pastilla de estado (punto + texto) para el header.
private struct StatusBadge: View {
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text).font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(.quaternary, in: .capsule)
    }
}
