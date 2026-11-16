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
                    Text("Age range · optional").readLabFont(17, weight: .semibold)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 14)], spacing: 14) {
                        ForEach(ReadLabAgeRange.allCases) { age in
                            Button { profile.ageRange = age; nameFocused = false } label: {
                                Text(age.rawValue).readLabFont(22, weight: .medium)
                                    .frame(maxWidth: .infinity, minHeight: 58)
                                    .background(profile.ageRange == age ? ReadLabStyle.blue : .white, in: RoundedRectangle(cornerRadius: 18))
                                    .overlay { if profile.ageRange == age { RoundedRectangle(cornerRadius: 18).strokeBorder(ReadLabStyle.ink, lineWidth: 2) } }
                            }
                            .buttonStyle(ReadLabTapStyle())
                            .accessibilityAddTraits(profile.ageRange == age ? .isSelected : [])
                        }
                    }.frame(maxWidth: 500)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reading familiarity · required").readLabFont(17, weight: .semibold)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 245), spacing: 18)], spacing: 18) {
                        ForEach(ReadLabReadingFamiliarity.allCases) { choice in
                            ReadLabChoiceCard(title: choice.rawValue, subtitle: choice.detail, selected: profile.readingFamiliarity == choice) {
                                profile.readingFamiliarity = choice; nameFocused = false
                            }
                        }
                    }
                }
            }.foregroundStyle(ReadLabStyle.ink)
        }
    }
}
