import SwiftUI

struct ReadLabSettingsView: View {
    @Bindable var store: ReadLabStore
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 44)).foregroundStyle(ReadLabStyle.ink)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(store.data.profile.childName).readLabFont(22, weight: .semibold)
                            Text("Your ReadLab journey").readLabFont(16, rounded: false).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 8)
                }
                Section("Reading path") {
                    ForEach(ReadingPath.allCases) { path in
                        Button {
                            store.data.selectedPath = path
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: path.symbol).frame(width: 30)
                                Text(path.title)
                                Spacer()
                                if store.data.selectedPath == path { Image(systemName: "checkmark").fontWeight(.semibold) }
                            }.foregroundStyle(.primary).frame(minHeight: 40)
                        }
                        .accessibilityAddTraits(store.data.selectedPath == path ? .isSelected : [])
                    }
                }
                Section("Reading preferences") {
                    Toggle("Use OpenDyslexic Bold", isOn: $store.data.preferences.useDyslexicFont)
                    Toggle("Track reading progress", isOn: Binding(get: { store.data.preferences.trackReadingProgress }, set: { store.setTracking($0) }))
                    if store.data.preferences.trackReadingProgress {
                        NavigationLink("Practice overview") { ReadLabProgressView(store: store) }
                    }
                }
                Section("Child profile") {
                    TextField("Child name", text: $store.data.profile.childName)
                        .textContentType(.givenName)
                        .onSubmit { normalizeName() }
                    Picker("Age range", selection: $store.data.profile.ageRange) {
                        Text("Not specified").tag(Optional<ReadLabAgeRange>.none)
                        ForEach(ReadLabAgeRange.allCases) { Text($0.rawValue).tag(Optional($0)) }
                    }
                    Picker("Reading familiarity", selection: $store.data.profile.readingFamiliarity) {
                        Text("Not specified").tag(Optional<ReadLabReadingFamiliarity>.none)
                        ForEach(ReadLabReadingFamiliarity.allCases) { Text($0.rawValue).tag(Optional($0)) }
                    }
                }
                Section("Learning support") {
                    Picker("Learning differences", selection: $store.data.preferences.diagnosis) {
                        ForEach(ReadLabDiagnosis.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Toggle("Followed by a specialist", isOn: $store.data.specialist.isFollowedBySpecialist)
                    if store.data.specialist.isFollowedBySpecialist {
                        TextField("Specialist profession", text: $store.data.specialist.profession)
                        TextField("Specialist name", text: $store.data.specialist.name)
                    }
                }
                Section {
                    Text("Practice adapts to each child’s pace. Reading activities use English. Voice input is processed on this device when supported; recordings are not saved.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text("Turning off progress tracking clears the practice overview. Your place in an activity is still saved.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "xmark") { normalizeName(); dismiss() }
                        .labelStyle(.iconOnly)
                }
            }
        }
        .onDisappear { normalizeName() }
    }
    private func normalizeName() {
        let name = store.data.profile.childName.trimmingCharacters(in: .whitespacesAndNewlines)
        store.data.profile.childName = name.isEmpty ? "Reader" : name
    }
}

struct ReadLabProgressView: View {
    let store: ReadLabStore
    var body: some View {
        List {
            ForEach(ReadingPath.allCases) { path in
                let totals = store.data.totals[path.rawValue, default: .init()]
                Section(path.title) {
                    LabeledContent("Completed activities", value: totals.completedActivities.formatted())
                    LabeledContent("Successful responses", value: totals.successfulAnswers.formatted())
                    LabeledContent("Practice responses", value: totals.attempts.formatted())
                    Text("Every little effort helps. There are no grades here.").foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Practice overview")
        .navigationBarTitleDisplayMode(.inline)
    }
}
