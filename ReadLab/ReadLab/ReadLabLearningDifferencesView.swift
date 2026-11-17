import SwiftUI

struct ReadLabLearningDifferencesView: View {
    @Binding var preferences: ReadLabLearningPreferences
    let onBack: () -> Void
    let onContinue: () -> Void
    var body: some View {
        ReadLabStepLayout(step: 3, onBack: onBack, onAction: onContinue) { compact in
            VStack(alignment: .leading, spacing: 28) {
                ReadLabPageTitle(title: "Does your child have any learning differences?", compact: compact)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 18)], spacing: 18) {
                    ForEach(ReadLabDiagnosis.allCases) { choice in
                        ReadLabChoiceCard(title: choice.rawValue, subtitle: choice.detail, selected: preferences.diagnosis == choice) { preferences.diagnosis = choice }
                    }
                }
                VStack(spacing: 24) {
                    Toggle(isOn: $preferences.useDyslexicFont) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Use OpenDyslexic for the app").readLabFont(21, weight: .semibold)
                            Text("Try a different reading font. You can change this in Account.").readLabFont(17, rounded: false)
                        }
                    }
                    .accessibilityIdentifier("dyslexicToggle")
                    Divider()
                    Toggle(isOn: $preferences.trackReadingProgress) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Track reading practice and progress").readLabFont(21, weight: .semibold)
                            Text("Keep a private progress overview on this device.").readLabFont(17, rounded: false)
                        }
                    }
                }
                .padding(26).readLabCard()
            }.foregroundStyle(ReadLabStyle.ink)
        }
    }
}
