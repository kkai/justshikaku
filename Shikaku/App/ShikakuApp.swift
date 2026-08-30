//
//  ShikakuApp.swift
//  Shikaku
//

import SwiftUI

@main
struct ShikakuApp: App {
    @State private var progress: ProgressStore
    @State private var entitlements: EntitlementStore
    @State private var paywall: PaywallPresenter
    @State private var cache: PuzzleCache
    @State private var mastery: MasteryTracker

    init() {
        #if DEBUG
        // UI tests launch with -uiTestResetState so audits never inherit a
        // previous test's board or alerts. The DEBUG guard is non-optional:
        // a release build must not carry a switch that wipes a player's data
        // on a spoofed launch argument.
        if ProcessInfo.processInfo.arguments.contains("-uiTestResetState") {
            UserDefaults.standard.removePersistentDomain(
                forName: Bundle.main.bundleIdentifier ?? "de.kaikunze.shikaku")
        }
        #endif
        let progress = ProgressStore()
        _progress = State(initialValue: progress)
        _entitlements = State(initialValue: Self.makeEntitlementStore())
        _paywall = State(initialValue: PaywallPresenter())
        _cache = State(initialValue: PuzzleCache())
        _mastery = State(initialValue: MasteryTracker(store: progress))
        Haptics.enabled = progress.settings.hapticsEnabled
    }

    /// The App Store screenshot run needs the paid screens.
    ///
    /// Wrapped in `#if DEBUG` deliberately: a launch argument that grants the
    /// unlock must not exist in the binary that ships. `ReleaseBuildTests`
    /// checks the flag is read from inside the guard.
    private static func makeEntitlementStore() -> EntitlementStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(Self.screenshotUnlockFlag) {
            return EntitlementStore(source: PreviewEntitlementSource(owned: true))
        }
        #endif
        return EntitlementStore()
    }

    /// Outside the `#if` on purpose — the test has to be able to name it.
    static let screenshotUnlockFlag = "-ShikakuScreenshotUnlock"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(progress)
                .environment(entitlements)
                .environment(paywall)
                .environment(cache)
                .environment(mastery)
                .tint(Theme.ink)
                // One committed world. The app is the lacquered room seen from
                // above, the same view as the icon; a light re-tint of it is a
                // different app. Theme still carries live light values so the
                // appearance can return without touching this file's
                // isolation-critical structure.
                .preferredColorScheme(.dark)
        }
    }
}
