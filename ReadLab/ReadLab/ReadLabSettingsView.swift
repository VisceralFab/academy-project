import SwiftUI

struct ReadLabSettingsView: View {
    @Bindable var store: ReadLabStore
    @Environment(\.dismiss) private var dismiss
    @State private var report: ReportFile?
    @State private var reportError: String?
    private struct ReportFile: Identifiable { let id = UUID(); let url: URL }
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(ReadLabStyle.actionFill, in: Circle())
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
                Section {
                    Button { exportReport() } label: {
                        Label("Download performance report", systemImage: "arrow.down.doc.fill")
                            .fontWeight(.semibold)
                            .foregroundStyle(ReadLabStyle.actionFill)
                    }
                    .frame(minHeight: 40)
                    .accessibilityHint("Creates a PDF you can save to Files, print or send by email")
                    .accessibilityIdentifier("downloadReportButton")
                } header: {
                    Text("Performance report")
                } footer: {
                    Text(store.data.preferences.trackReadingProgress
                         ? "A PDF with the child’s profile, current level, success rate by path and theme, daily practice and every recorded exercise."
                         : "Progress tracking is off, so the report will contain only the child’s profile. Turn on “Track reading progress” to record exercises.")
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
        .sheet(item: $report) { file in
            ReadLabShareSheet(items: [file.url]).ignoresSafeArea()
        }
        .alert("The report could not be created", isPresented: Binding(get: { reportError != nil }, set: { if !$0 { reportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(reportError ?? "")
        }
    }
    private func exportReport() {
        normalizeName()
        do { report = ReportFile(url: try ReadLabPerformanceReport.makePDF(from: store.data)) }
        catch { reportError = error.localizedDescription }
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
