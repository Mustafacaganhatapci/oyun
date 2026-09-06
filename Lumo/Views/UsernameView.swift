import SwiftUI

/// Kullanıcı adı belirleme sayfası. Dünya sıralamasına katılmak için gerekir.
struct UsernameView: View {
    @EnvironmentObject private var app: AppModel
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var player: PlayerStore

    @EnvironmentObject private var leaderboard: LeaderboardService

    @State private var name = ""
    @FocusState private var focused: Bool
    @State private var showError = false
    @State private var nameTaken = false
    @State private var checking = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Geri çıkmak da "soruldu" sayılır: sıralamaya katılmak isteğe
                // bağlı, adı boş bırakan oyuncuya her açılışta sormayız.
                BackButton {
                    player.markUsernamePrompted()
                    app.route = app.usernameDestination
                }
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
                Image(systemName: player.isUsernameLocked
                      ? "checkmark.seal.fill" : "person.crop.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(settings.theme.accent.color)
                    .shadow(color: settings.theme.accent.opacity(0.7), radius: 14)

                if player.isUsernameLocked {
                    lockedName
                } else {
                    chooseName
                }
            }
            .padding(.horizontal, 36)

            Spacer()
            Spacer()
        }
        .onAppear {
            name = player.username
            guard !player.isUsernameLocked else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }

    /// Ad zaten seçilmiş: yalnızca gösterilir, değiştirilemez
    private var lockedName: some View {
        VStack(spacing: 14) {
            Text("Your name")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(.white)

            Text(player.username)
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(settings.theme.lumen.color)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.08))
                }

            Text("Names are unique and chosen once, so this one cannot be changed.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)

            Button {
                AudioEngine.shared.playTap()
                app.route = app.usernameDestination
            } label: {
                Text("Continue")
            }
            .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var chooseName: some View {
        Group {
                Text("Choose a username")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(.white)

                Text("This is the name shown on the world ranking. It is chosen once and cannot be changed later.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)

                TextField("", text: $name,
                          prompt: Text("type a name").foregroundStyle(.white.opacity(0.35)))
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
                    .onChange(of: name) { _, _ in showError = false; nameTaken = false }

                Text(hint)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(showError || nameTaken
                                     ? settings.theme.hazard.color : .white.opacity(0.35))
                    .multilineTextAlignment(.center)

                Button {
                    Task { await save() }
                } label: {
                    if checking {
                        ProgressView().tint(.black)
                    } else {
                        Text("Save")
                    }
                }
                .buttonStyle(GlowButtonStyle(color: settings.theme.accent.color, prominent: true))
                .disabled(checking)
                .padding(.top, 4)
        }
    }

    private var hint: LocalizedStringKey {
        if nameTaken { return "That name is taken — pick another" }
        return "3–16 characters · letters, numbers, _ or -"
    }

    /// Adı önce biçim, sonra da küresel tekillik açısından denetler.
    /// Sahiplenme sunucuda bir işlem içinde yapıldığı için iki oyuncu aynı anda
    /// aynı adı isterse yalnızca biri alabilir.
    private func save() async {
        let candidate = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PlayerStore.isValid(candidate) else {
            showError = true
            nameTaken = false
            AudioEngine.shared.playFail()
            return
        }

        checking = true
        let claim = await leaderboard.claimUsername(candidate, playerID: player.playerID)
        checking = false

        if claim == .taken {
            nameTaken = true
            AudioEngine.shared.playFail()
            return
        }

        // .claimed ya da .offline — çevrimdışıyken sıralama da kapalı olduğundan
        // adı yerelde kabul etmek oyuncuyu boşuna bekletmekten iyidir.
        guard player.setUsername(candidate) else {
            showError = true
            AudioEngine.shared.playFail()
            return
        }
        AudioEngine.shared.playTap()
        player.markUsernamePrompted()
        app.route = app.usernameDestination
    }
}
