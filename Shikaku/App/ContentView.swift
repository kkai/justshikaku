//
//  ContentView.swift
//  Shikaku
//

import SwiftUI

struct ContentView: View {
    @State private var path: [Route] = []
    @Environment(PaywallPresenter.self) private var paywall

    var body: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .sheet(item: paywallBinding) { feature in
            PaywallView(feature: feature)
        }
    }

    /// `presented` is private(set) on the presenter; dismissal goes through
    /// `dismiss()` so there is exactly one way the sheet closes.
    private var paywallBinding: Binding<PaidFeature?> {
        Binding(
            get: { paywall.presented },
            set: { newValue in if newValue == nil { paywall.dismiss() } })
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .play(let size, let difficulty):
            PlayHostView(size: size, difficulty: difficulty)
        case .resume:
            ResumeGameView()
        case .learn:
            LearnMenuView()
        case .lesson(let technique):
            LessonView(technique: technique)
        case .daily(let day):
            DailyHostView(day: day)
        case .techniqueRoom(let technique, let seed):
            TechniqueRoomHostView(technique: technique, seed: seed)
        case .drill(let technique):
            DrillView(technique: technique)
        case .proof:
            ReplayView()
        case .spotIt(let technique):
            SpotItView(technique: technique)
        case .climb:
            ClimbView()
        case .stats:
            StatsView()
        case .settings:
            SettingsView()
        }
    }
}
