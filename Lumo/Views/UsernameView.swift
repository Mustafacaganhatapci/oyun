import SwiftUI

/// Kullanıcı adı belirleme sayfası. Dünya sıralamasına katılmak için gerekir.
struct UsernameView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var player: PlayerStore

    @State private var name = ""
    @FocusState private var focused: Bool
    @State private var showError = false

    /// Kaydettikten sonra nereye gidilecek (varsayılan: sıralama)
    var onDone: Route = .ranking

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackButton { app.route = .menu }
                Spacer()
                Text("Username")
                    .font(.system(.title2, design: .rounded).bold())
                    .foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            VStack(spacing: 20) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(settings.theme.accent.color)
                    .shadow(color: settings.theme.accent.opacity(0.7), radius: 14)

                Text("Choose a username")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text("This is the name shown on the world ranking.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)

                TextField("", text: $name,
                          prompt: Text("username").foregroundStyle(.white.opacity(0.35)))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focused)
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 14)
                    .background {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(showError ? settings.theme.hazard.color : .white.opacity(0.15),
                                          lineWidth: 1.5)
                    }
                    .onChange(of: name) { _, _ in showError = false }

                Text("3–16 characters · letters, numbers, _ or -")
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(showError ? settings.theme.hazard.color : .white.opacity(0.35))

                Button {
                    if player.setUsername(name) {
                        AudioEngine.shared.playTap()
                        app.route = onDone
                    } else {
                        showError = true
                        AudioEngine.shared.playFail()
                    }
                } label: {
                    Text("Save")
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))
                .padding(.top, 4)
            }
            .padding(.horizontal, 36)

            Spacer()
            Spacer()
        }
        .onAppear {
            name = player.username
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }
}
