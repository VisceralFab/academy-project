import SwiftUI

struct ReadLabSummaryView: View {
    let store: ReadLabStore
    let onBack: () -> Void
    let onEditProfile: () -> Void
    let onEditLearning: () -> Void
    let onEditFocus: () -> Void
    let onDone: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width < 850
            let short = geometry.size.height < 800
            let scroll = typeSize.isAccessibilitySize || geometry.size.height < 620
            let rowHeight: CGFloat = short ? 50 : 60
            ZStack {
                ReadLabPastelBackground()
                VStack(spacing: short ? 14 : 22) {
                    ReadLabStepHeader(step: 5, onBack: onBack)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your learning journey is ready!")
                            .readLabFont(short || compact ? 36 : 48, weight: .medium)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("One last look, then let the adventure begin.")
                            .readLabFont(short ? 18 : 21, weight: .light, rounded: false)
                    }
                    .frame(maxWidth: 1080, alignment: .leading)
                    .padding(.top, short ? 10 : 22)
                    List {
                        row("Child’s name", value: store.data.profile.childName, stacked: scroll, action: onEditProfile)
                        row("Age range", value: store.data.profile.ageRange?.rawValue ?? "Not specified", stacked: scroll, action: onEditProfile)
                        row("Learning differences", value: store.data.preferences.diagnosis.rawValue, stacked: scroll, action: onEditLearning)
                        row("Reading font", value: store.data.preferences.useDyslexicFont ? "OpenDyslexic Bold" : "System Rounded", stacked: scroll, action: onEditLearning)
                        row("Progress overview", value: store.data.preferences.trackReadingProgress ? "Enabled" : "Disabled", stacked: scroll, action: onEditLearning)
                        row("Reading path", value: store.data.selectedPath.title, stacked: scroll, action: onEditFocus)
                    }
                    .environment(\.defaultMinListRowHeight, rowHeight)
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(!scroll)
                    .contentMargins(.vertical, 0, for: .scrollContent)
                    .frame(maxWidth: 1120)
                    .frame(height: scroll ? nil : rowHeight * 6 + 24)
                    .accessibilityIdentifier("onboardingSummary")
                    Spacer(minLength: 0)
                    HStack {
                        Spacer()
                        ReadLabActionButton(title: "Let’s Begin", action: onDone)
                    }
                    ReadLabPrivacyCaption()
                }
                .padding(.horizontal, compact ? 24 : 64)
                .padding(.top, 14)
                .padding(.bottom, 8)
            }.foregroundStyle(ReadLabStyle.ink)
        }
    }

    private func row(_ title: String, value: String, stacked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if stacked {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(title).readLabFont(16, rounded: false).foregroundStyle(.secondary)
                        Text(value).readLabFont(18, weight: .medium).foregroundStyle(ReadLabStyle.ink)
                    }
                } else {
                    Text(title).readLabFont(16, rounded: false).foregroundStyle(.secondary)
                        .frame(width: 180, alignment: .leading)
                    Text(value).readLabFont(18, weight: .medium).foregroundStyle(ReadLabStyle.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
            }
            .frame(minHeight: 28, alignment: .leading)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
        .accessibilityIdentifier("summary-\(title)")
        .accessibilityHint("Edit \(title.lowercased())")
    }
}
