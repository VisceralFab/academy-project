import SwiftUI

struct ReadingSupportOnboarding: View {
    @Bindable var store: ReadLabStore
    @State private var path: [Step] = []
    private enum Step: Hashable { case profile, learning, focus, summary }

    var body: some View {
        NavigationStack(path: $path) {
            ReadLabWelcomeView { path.append(.profile) }
                .navigationDestination(for: Step.self) { step in
                    Group {
                        switch step {
                        case .profile:
                            ReadLabChildProfileView(profile: $store.data.profile, onBack: back) { path.append(.learning) }
                        case .learning:
                            ReadLabLearningDifferencesView(preferences: $store.data.preferences, specialist: $store.data.specialist, onBack: back) { path.append(.focus) }
                        case .focus:
                            ReadLabFocusView(selected: $store.data.selectedPath, onBack: back) { path.append(.summary) }
                        case .summary:
                            ReadLabSummaryView(store: store, onBack: back, onEditProfile: { edit(.profile) }, onEditLearning: { edit(.learning) }, onEditFocus: { edit(.focus) }) {
                                store.data.profile.childName = store.data.profile.childName.trimmingCharacters(in: .whitespacesAndNewlines)
                                store.data.hasOnboarded = true
                            }
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
    }
    private func back() { if !path.isEmpty { path.removeLast() } }
    private func edit(_ step: Step) {
        guard let index = path.firstIndex(of: step) else { return }
        path = Array(path.prefix(through: index))
    }
}
