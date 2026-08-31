//
//  ModeGuideView.swift
//  Shikaku
//
//  What a way to play is, and how it ends. Reached from "Ways to play" in
//  Learn, and from the info button inside each mode.
//

import SwiftUI

struct ModeGuideView: View {
    let mode: Mode

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.s4) {
                    Text(ModeGuide.oneLine(mode))
                        .font(Theme.heading)
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(ModeGuide.explanation(mode))
                        .font(.body)
                        .foregroundStyle(Theme.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(Layout.s5)
                .frame(maxWidth: 560, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(ModeGuide.title(mode))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The "Ways to play" list, shared by Learn's section and Settings' row so
/// neither holds prose of its own.
struct ModeGuideList: View {
    var body: some View {
        List {
            Section {
                ForEach(ModeGuide.listed) { mode in
                    NavigationLink {
                        ModeGuideView(mode: mode)
                    } label: {
                        row(mode)
                    }
                }
            } footer: {
                Text("Every mode is offline, and none of them rank you against anyone.")
            }
        }
        .navigationTitle("Ways to play")
        .scrollContentBackground(.hidden)
        .background(Theme.floor)
    }

    @ViewBuilder
    func row(_ mode: Mode) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ModeGuide.title(mode))
                .foregroundStyle(Theme.ink)
            Text(ModeGuide.oneLine(mode))
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

extension View {
    /// The info button every mode screen carries: same sheet, same prose,
    /// five call sites that cannot drift.
    func modeGuide(_ mode: Mode) -> some View {
        modifier(ModeGuideButton(mode: mode))
    }
}

private struct ModeGuideButton: ViewModifier {
    let mode: Mode
    @State private var showing = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showing = true } label: {
                        Image(systemName: "info.circle")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("About this mode")
                }
            }
            .sheet(isPresented: $showing) {
                NavigationStack {
                    ModeGuideView(mode: mode)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") { showing = false }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
    }
}
