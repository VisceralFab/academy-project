import SwiftUI

struct ReadLabSummaryView: View {
    let store: ReadLabStore
    let onBack: () -> Void
    let onEditProfile: () -> Void
    let onEditLearning: () -> Void
    let onEditFocus: () -> Void
    let onDone: () -> Void
    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width < 850
            ZStack {
                ReadLabPastelBackground()
                VStack(spacing: 10) {
                    ReadLabStepHeader(step: 5, onBack: onBack)
                        .padding(.horizontal, compact ? 24 : 64)
                    List {
                        Section {
                            ReadLabPageTitle(title: "Your learning journey is ready!", subtitle: "One last look, then let the adventure begin.", compact: compact)
                                .padding(.vertical, 20)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        }
                        Section {
                            row("Child’s name", value: store.data.profile.childName, action: onEditProfile)
                            row("Age range", value: store.data.profile.ageRange?.rawValue ?? "Not specified", action: onEditProfile)
                            row("Reading familiarity", value: store.data.profile.readingFamiliarity?.rawValue ?? "Not selected", action: onEditProfile)
                            row("Learning differences", value: store.data.preferences.diagnosis.rawValue, action: onEditLearning)
                            row("Reading font", value: store.data.preferences.useDyslexicFont ? "OpenDyslexic Bold" : "System Rounded", action: onEditLearning)
                            row("Progress overview", value: store.data.preferences.trackReadingProgress ? "Enabled" : "Disabled", action: onEditLearning)
                            row("Reading path", value: store.data.selectedPath.title, action: onEditFocus)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: 1120)
                    HStack {
                        Spacer()
                        ReadLabActionButton(title: "Let’s Begin", action: onDone)
                    }
                    .padding(.horizontal, compact ? 24 : 64)
                    .padding(.vertical, 10)
                }
                .padding(.top, 14)
                .padding(.bottom, 8)
            }
        }
    }
    private func row(_ title: String, value: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).readLabFont(16, rounded: false).foregroundStyle(.secondary)
                    Text(value).readLabFont(20, weight: .medium).foregroundStyle(ReadLabStyle.ink)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }.padding(.vertical, 8)
        }.accessibilityHint("Edit \(title.lowercased())")
    }
}
