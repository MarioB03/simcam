import SwiftUI
import SimCamHostKit

struct LauncherView: View {
    @Bindable var controller: LauncherController
    let udid: String?
    let isCapturing: Bool
    let startCapture: () async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Modo", selection: $controller.mode) {
                ForEach(LauncherController.Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch controller.mode {
            case .installed:
                HStack(spacing: 6) {
                    Picker("App", selection: $controller.selectedBundleId) {
                        ForEach(controller.apps) { Text($0.name).tag(Optional($0.bundleId)) }
                    }
                    .labelsHidden()
                    Button("Refrescar", systemImage: "arrow.clockwise") {
                        if let udid { controller.refreshApps(udid: udid) }
                    }
                    .labelStyle(.iconOnly)
                }
            case .project:
                HStack(spacing: 6) {
                    Text(controller.projectPath.map { ($0 as NSString).lastPathComponent } ?? "Sin proyecto")
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Elegir…") { chooseProject() }
                }
                Picker("Scheme", selection: $controller.selectedScheme) {
                    ForEach(controller.schemes, id: \.self) { Text($0).tag(Optional($0)) }
                }
                .labelsHidden()
            }

            Button {
                guard let udid else { return }
                Task {
                    if !isCapturing { await startCapture() }
                    controller.launch(udid: udid)
                }
            } label: {
                Label(controller.isWorking ? "Trabajando…" : "Lanzar con SimCam", systemImage: "bolt.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(udid == nil || controller.isWorking || !canLaunch)
            .keyboardShortcut(.defaultAction)

            if let err = controller.lastError {
                Text(err).font(.caption2).foregroundStyle(.red).lineLimit(3)
            }
        }
    }

    /// "Hacer todo" sólo se habilita si el modo activo tiene su selección hecha.
    private var canLaunch: Bool {
        switch controller.mode {
        case .installed: return controller.selectedBundleId != nil
        case .project: return controller.selectedScheme != nil
        }
    }

    private func chooseProject() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            controller.projectPath = url.path
            controller.selectedScheme = nil
            controller.refreshSchemes()
        }
    }
}
