import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @State private var showInitialSetup = false

    var body: some View {
        NavigationSplitView {
            inputPanel
                .navigationSplitViewColumnWidth(min: 360, ideal: 420, max: 500)
        } detail: {
            TranscriptView()
        }
        .toolbar {
            ToolbarItemGroup {
                if viewModel.isRunning {
                    ProgressView()
                        .controlSize(.small)
                }
                Text(viewModel.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showSettingsWindow()
                } label: {
                    Label("Ajustes", systemImage: "gearshape")
                }

                Button(role: .destructive) {
                    viewModel.clearSession()
                } label: {
                    Label("Apagar sessão", systemImage: "trash")
                }
                .disabled(viewModel.isRunning)
            }
        }
        .onAppear {
            if !viewModel.hasCredentials {
                showInitialSetup = true
            }
        }
        .sheet(isPresented: $showInitialSetup) {
            InitialSetupView()
                .environmentObject(viewModel)
        }
        .alert("Não foi possível continuar", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "Erro desconhecido")
        }
    }

    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Conselho Jurídico IA")
                    .font(.system(size: 26, weight: .semibold))
                Text("Tese, contraditório e parecer consolidado")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Questão ou estratégia")
                    .font(.headline)
                TextEditor(text: $viewModel.question)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .frame(minHeight: 220)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                    .overlay {
                        if viewModel.question.isEmpty {
                            VStack {
                                HStack {
                                    Text("Descreva os fatos, a dúvida ou a estratégia que deseja testar…")
                                        .foregroundStyle(.tertiary)
                                        .padding(.top, 18)
                                        .padding(.leading, 16)
                                    Spacer()
                                }
                                Spacer()
                            }
                            .allowsHitTesting(false)
                        }
                    }
            }

            documentSection
            depthSection

            if !viewModel.hasCredentials {
                Button {
                    showInitialSetup = true
                } label: {
                    Label("Configurar as duas IAs", systemImage: "key")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button {
                viewModel.startAnalysis()
            } label: {
                HStack {
                    if viewModel.isRunning {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isRunning ? "Analisando…" : "Iniciar análise")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canRun || !viewModel.hasCredentials)

            Spacer()

            Text("Apoio à análise profissional. Valide legislação, jurisprudência, prazos, fatos e documentos em fontes oficiais antes de utilizar o conteúdo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
    }

    private var documentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Documento")
                .font(.headline)

            if let document = viewModel.document {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "doc.text")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(document.name)
                            .lineLimit(1)
                        Text("\(document.characterCount.formatted()) caracteres" + (document.wasTruncated ? " • conteúdo truncado" : ""))
                            .font(.caption)
                            .foregroundStyle(document.wasTruncated ? .orange : .secondary)
                    }
                    Spacer()
                    Button {
                        viewModel.removeDocument()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            } else {
                Button {
                    viewModel.chooseDocument()
                } label: {
                    Label("Adicionar PDF, TXT ou RTF", systemImage: "paperclip")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var depthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Profundidade")
                .font(.headline)
            Picker("Profundidade", selection: $viewModel.depth) {
                ForEach(AnalysisDepth.allCases) { depth in
                    Text(depth.rawValue).tag(depth)
                }
            }
            .pickerStyle(.segmented)

            Text(viewModel.depth.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func showSettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

private struct InitialSetupView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 34))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configuração inicial")
                        .font(.title2.weight(.semibold))
                    Text("Faça isso uma única vez. As chaves ficam protegidas no Keychain deste Mac.")
                        .foregroundStyle(.secondary)
                }
            }

            GroupBox("OpenAI") {
                SecureField("Cole a chave da OpenAI", text: $viewModel.openAIKey)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 4)
            }

            GroupBox("Anthropic / Claude") {
                SecureField("Cole a chave da Anthropic", text: $viewModel.anthropicKey)
                    .textFieldStyle(.roundedBorder)
                    .padding(.top, 4)
            }

            if let message = viewModel.connectionTestMessage {
                HStack(spacing: 8) {
                    if viewModel.isTestingConnections {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Text(message)
                        .font(.callout)
                }
            }

            Text("O aplicativo envia a questão e os documentos diretamente às APIs configuradas. Não existe servidor intermediário deste aplicativo.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Testar conexões") {
                    viewModel.testConnections()
                }
                .disabled(!viewModel.hasCredentials || viewModel.isTestingConnections)

                Spacer()

                Button("Salvar e começar") {
                    viewModel.saveSettings()
                    if viewModel.hasCredentials {
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.hasCredentials)
            }
        }
        .padding(28)
        .frame(width: 560)
    }
}
