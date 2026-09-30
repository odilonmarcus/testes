import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var saved = false

    var body: some View {
        Form {
            Section("Credenciais") {
                SecureField("Chave da OpenAI", text: $viewModel.openAIKey)
                SecureField("Chave da Anthropic", text: $viewModel.anthropicKey)

                Text("As chaves são armazenadas no Keychain deste Mac e não são gravadas junto com a sessão.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Testar conexões") {
                        viewModel.testConnections()
                    }
                    .disabled(!viewModel.hasCredentials || viewModel.isTestingConnections)

                    if viewModel.isTestingConnections {
                        ProgressView().controlSize(.small)
                    }

                    if let message = viewModel.connectionTestMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Modelos") {
                TextField("Modelo GPT", text: $viewModel.openAIModel)
                TextField("Modelo Claude", text: $viewModel.anthropicModel)

                HStack {
                    Text("Os IDs ficam editáveis para acompanhar atualizações dos provedores.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Restaurar padrões") {
                        viewModel.resetModelDefaults()
                    }
                }
            }

            Section("Privacidade") {
                Text("O aplicativo não cria histórico local das análises. O conteúdo é enviado diretamente às APIs configuradas. As políticas de retenção e tratamento de dados dos provedores continuam aplicáveis.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button(saved ? "Salvo" : "Salvar ajustes") {
                    viewModel.saveSettings()
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        saved = false
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }
}
