//
//  SettingsView.swift
//  Shikaku
//
//  Restore lives HERE, unconditionally — not only inside the paywall sheet,
//  which only opens when you hit a wall. Anyone who reinstalled needs a
//  place to restore from.
//

import SwiftUI

struct SettingsView: View {
    @Environment(ProgressStore.self) private var progress
    @Environment(EntitlementStore.self) private var entitlements

    var body: some View {
        List {
            Section("Play") {
                Toggle("Haptics", isOn: hapticsBinding)
                Toggle("Show mistakes", isOn: errorFeedbackBinding)
            }
            Section {
                if entitlements.isUnlocked {
                    Label("Full game unlocked", systemImage: "checkmark.seal")
                        .foregroundStyle(Theme.inkSoft)
                } else {
                    Button("Restore purchase") {
                        Task { await entitlements.restore() }
                    }
                }
            } footer: {
                Text("Shikaku Full is a one-time purchase, shared with your family.")
            }
            Section {
                LabeledContent("Version", value: Bundle.main.shortVersion)
            }
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .background(Theme.floor)
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { progress.settings.hapticsEnabled },
            set: { newValue in
                progress.settings.hapticsEnabled = newValue
                // Applied on change AND at launch — only-on-change is how a
                // setting ends up doing nothing.
                Haptics.enabled = newValue
            })
    }

    private var errorFeedbackBinding: Binding<Bool> {
        Binding(
            get: { progress.settings.errorFeedback },
            set: { newValue in progress.settings.errorFeedback = newValue })
    }
}

extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}
