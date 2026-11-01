import SwiftUI

/// Settings' "CLIProxyAPI Hubs" card: one row per hub with its on/off switch and a remove button, an
/// "Add Hub" form, and a Relaunch row once a change is saved (hub cards are built at launch).
struct CLIProxyHubSettingsSection: View {
    let notice: CLIProxyHubRelaunchNotice
    @Environment(LayoutStore.self) private var layout
    @AppStorage(DensitySetting.key) private var density = DensitySetting.regular

    @State private var settings: CLIProxyHubSettings
    @State private var isAdding = false
    @State private var urlInput = ""
    @State private var keyInput = ""
    @State private var labelInput = ""
    @State private var pendingRemoval: CLIProxyHubConfig.Hub?

    init(notice: CLIProxyHubRelaunchNotice) {
        self.notice = notice
        _settings = State(initialValue: CLIProxyHubSettings(notice: notice))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: density.headerToCardSpacing) {
            Text("CLIProxyAPI Hubs")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
            VStack(spacing: 0) {
                if let loadError = settings.loadError {
                    inlineNotice(loadError)
                } else {
                    ForEach(settings.hubs, id: \.id) { hub in
                        hubRow(hub)
                        Divider()
                    }
                    if isAdding {
                        addForm
                    } else {
                        fullWidthButton("Add Hub") { openForm() }
                    }
                }
                if let actionError = settings.actionError {
                    inlineNotice(actionError)
                }
                if notice.isPending {
                    Divider()
                    relaunchRow
                }
            }
            .cardSurface()
            .clipShape(Theme.cardShape)
        }
        .onAppear { settings.reload() }
        .onChange(of: layout.screen) { _, screen in
            if screen == .settings { settings.reload() } else { pendingRemoval = nil }
        }
        .alert(
            "Remove Hub?",
            isPresented: Binding(get: { pendingRemoval != nil }, set: { if !$0 { pendingRemoval = nil } }),
            presenting: pendingRemoval
        ) { hub in
            Button("Remove", role: .destructive) { settings.remove(hubID: hub.id) }
            Button("Cancel", role: .cancel) {}
        } message: { hub in
            Text("\(name(of: hub)) and its saved management key are removed from OpenUsage. The hub itself is not changed.")
        }
    }

    // MARK: - Rows

    private func hubRow(_ hub: CLIProxyHubConfig.Hub) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(name(of: hub))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(hub.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 8)
            Button {
                pendingRemoval = hub
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Remove Hub")
            Toggle("", isOn: Binding(
                get: { hub.enabled },
                set: { settings.setEnabled($0, hubID: hub.id) }
            ))
            .settingsSwitchStyle()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, density.controlRowPadding)
    }

    private var addForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Hub URL", text: $urlInput, prompt: Text("https://hub.example.ts.net"))
            SecureField("Management Key", text: $keyInput, prompt: Text("Management Key"))
            TextField("Label", text: $labelInput, prompt: Text(labelPlaceholder))
            HStack(spacing: 8) {
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                Button("Cancel") { closeForm() }
                    .buttonStyle(.borderless)
            }
            .controlSize(.small)
        }
        .textFieldStyle(.roundedBorder)
        .labelsHidden()
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Rectangle().fill(.fill.quinary))
    }

    private var relaunchRow: some View {
        HStack(spacing: 10) {
            Text(notice.relaunchFailed ? "Quit and reopen OpenUsage to apply." : "Relaunch to apply hub changes.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Button("Relaunch") { notice.relaunch() }
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, density.controlRowPadding)
    }

    // MARK: - Helpers

    private func name(of hub: CLIProxyHubConfig.Hub) -> String {
        hub.label ?? URL(string: hub.url)?.host ?? hub.id
    }

    /// The label defaults to the hub's host, so the field shows it once the URL has one.
    private var labelPlaceholder: String {
        let host = URL(string: urlInput.trimmingCharacters(in: .whitespacesAndNewlines))?.host
        return host.map { "Label (\($0))" } ?? "Label (Optional)"
    }

    private var canSave: Bool {
        !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func openForm() {
        urlInput = ""
        keyInput = ""
        labelInput = ""
        settings.clearActionError()
        isAdding = true
    }

    private func closeForm() {
        settings.clearActionError()
        isAdding = false
        keyInput = ""
    }

    private func save() {
        settings.addHub(url: urlInput, managementKey: keyInput, label: labelInput)
        if settings.actionError == nil { closeForm() }
    }

    private func fullWidthButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).frame(maxWidth: .infinity)
        }
        .glassButtonStyle()
        .controlSize(.regular)
        .padding(.horizontal, 12)
        .padding(.vertical, density.controlRowPadding)
    }

    private func inlineNotice(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(Theme.notice)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
