import SwiftUI

struct ReadLabChildProfileView: View {
    @Binding var profile: ReadLabChildProfile
    let onBack: () -> Void
    let onContinue: () -> Void
    @FocusState private var nameFocused: Bool
    var body: some View {
        ReadLabStepLayout(step: 2, onBack: onBack, actionEnabled: profile.isValid, onAction: { nameFocused = false; onContinue() }) { compact in
            VStack(alignment: .leading, spacing: 30) {
                ReadLabPageTitle(title: "Let’s get to know your child.", subtitle: "A few details to make this journey feel like theirs.", compact: compact)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Child’s name · required").readLabFont(17, weight: .semibold)
                    TextField("e.g. Luca", text: $profile.childName)
                        .textContentType(.givenName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .readLabFont(22)
                        .padding(20)
                        .background(.white, in: RoundedRectangle(cornerRadius: 18))
                        .frame(maxWidth: 460)
                        .focused($nameFocused)
                        .submitLabel(.done)
                        .accessibilityLabel("Child name")
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Age range · required").readLabFont(17, weight: .semibold)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 14)], spacing: 14) {
                        ForEach(ReadLabAgeRange.allCases) { age in
                            Button { profile.ageRange = age; nameFocused = false } label: {
                                Text(age.rawValue).readLabFont(22, weight: .medium)
                                    .foregroundStyle(ReadLabStyle.ink)
                                    .frame(maxWidth: .infinity, minHeight: 58)
                                    .background(.white, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18)
                                            .strokeBorder(profile.ageRange == age ? ReadLabStyle.blue : .clear, lineWidth: 3)
                                    }
                            }
                            .buttonStyle(ReadLabTapStyle())
                            .accessibilityAddTraits(profile.ageRange == age ? .isSelected : [])
                            .accessibilityIdentifier("ageRange-\(age.rawValue)")
                        }
                    }.frame(maxWidth: 500)
                }

            }.foregroundStyle(ReadLabStyle.ink)
        }
    }
}
