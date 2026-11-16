import SwiftUI

/// Shared by setup and Account; specialist details remain optional.
struct ReadLabSpecialistSection: View {
    @Binding var specialist: ReadLabSpecialistInfo
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Toggle("My child is followed by a specialist", isOn: $specialist.isFollowedBySpecialist)
                .readLabFont(20, weight: .semibold)
            if specialist.isFollowedBySpecialist {
                TextField("Specialist profession · optional", text: $specialist.profession)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Specialist profession")
                TextField("Specialist name · optional", text: $specialist.name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Specialist name")
            }
        }.padding(26).readLabCard()
    }
}
