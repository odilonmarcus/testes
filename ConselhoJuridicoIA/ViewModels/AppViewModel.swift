import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppViewModel: ObservableObject {
    @Published var question = ""
    @Published var depth: AnalysisDepth = .complete
    @Published var document: ImportedDocument?
    @Published var entries: [DebateEntry] = []
    @Published var finalSynthesis = ""
    @Published var isRunning = false
    @Published var statusText = "Pronto para analisar"
    @Published var errorMessage: String?

    @Published var openAIKey = KeychainStore.read(.openAI)
    @Published var anthropicKey = KeychainStore.read(.anthropic)
    @Published var openAIModel: String
    @Published var anthropicModel: String

    @Published var isTestingConnections = false
    @Published var connectionTestMessage: String?

    private let defaults = UserDefaults.standard
    private let engine = DebateEngine()
    private let importer = DocumentImporter()
    private let openAI = OpenAIClient()
    private let anthropic = AnthropicClient()

    init() {
        self.openAIModel = UserDefaults.standard.string(forKey: "openAIModel") ?? AppSettings.defaults.openAIModel
        self.anthropicModel = UserDefaults.standard.string(forKey: "anthropicModel") ?? AppSettings.defaults.anthropicModel
    }

    var canRun: Bool {
        !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isRunning
    }

    var hasCredentials: Bool {
        !openAIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func saveSettings() {
        do {
            try KeychainStore.save(openAIKey.trimmingCharacters(in: .whitespacesAndNewlines), for: .openAI)
            try KeychainStore.save(anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines), for: .anthropic)
            defaults.set(openAIModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "openAIModel")
            defaults.set(anthropicModel.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "anthropicModel")
            statusText = "Ajustes salvos com segurança"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetModelDefaults() {
        openAIModel = AppSettings.defaults.openAIModel
        anthropicModel = AppSettings.defaults.anthropicModel
    }

    func testConnections() {
        guard hasCredentials else {
            connectionTestMessage = "Informe as duas chaves antes de testar."
            return
        }

        saveSettings()
        isTestingConnections = true
        connectionTestMessage = "Testando OpenAI…"

        let openAIKeySnapshot = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let anthropicKeySnapshot = anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let openAIModelSnapshot = openAIModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let anthropicModelSnapshot = anthropicModel.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                _ = try await openAI.generate(
                    apiKey: openAIKeySnapshot,
                    model: openAIModelSnapshot,
                    system: "Teste técnico de conexão.",
                    prompt: "Responda somente com OK.",
                    maxOutputTokens: 64
                )

                connectionTestMessage = "OpenAI OK. Testando Claude…"

                _ = try await anthropic.generate(
                    apiKey: anthropicKeySnapshot,
                    model: anthropicModelSnapshot,
                    system: "Teste técnico de conexão.",
                    prompt: "Responda somente com OK.",
                    maxOutputTokens: 64
                )

                isTestingConnections = false
                connectionTestMessage = "Conexões verificadas: OpenAI e Claude estão funcionando."
                statusText = "Conexões verificadas"
            } catch {
                isTestingConnections = false
                connectionTestMessage = nil
                errorMessage = "Falha no teste de conexão: \(error.localizedDescription)"
            }
        }
    }

    func chooseDocument() {
        do {
            if let selected = try importer.chooseDocument() {
                document = selected
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeDocument() {
        document = nil
    }

    func startAnalysis() {
        guard canRun else { return }
        guard hasCredentials else {
            errorMessage = "Configure as chaves da OpenAI e Anthropic antes de iniciar."
            return
        }

        isRunning = true
        errorMessage = nil
        entries.removeAll()
        finalSynthesis = ""
        statusText = "Iniciando conselho jurídico…"

        let questionSnapshot = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let documentSnapshot = document
        let depthSnapshot = depth
        let openAIKeySnapshot = openAIKey
        let anthropicKeySnapshot = anthropicKey
        let settings = AppSettings(openAIModel: openAIModel, anthropicModel: anthropicModel)

        Task {
            do {
                let synthesis = try await engine.run(
                    question: questionSnapshot,
                    document: documentSnapshot,
                    depth: depthSnapshot,
                    openAIKey: openAIKeySnapshot,
                    anthropicKey: anthropicKeySnapshot,
                    settings: settings,
                    onEntry: { [weak self] entry in
                        self?.entries.append(entry)
                        if entry.role == "Parecer consolidado" {
                            self?.finalSynthesis = entry.content
                        }
                    },
                    onStatus: { [weak self] status in
                        self?.statusText = status
                    }
                )
                finalSynthesis = synthesis
                isRunning = false
            } catch {
                isRunning = false
                statusText = "Análise interrompida"
                errorMessage = error.localizedDescription
            }
        }
    }

    func clearSession() {
        question = ""
        document = nil
        entries.removeAll()
        finalSynthesis = ""
        errorMessage = nil
        isRunning = false
        statusText = "Sessão apagada"
    }

    func copyFinal() {
        guard !finalSynthesis.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(finalSynthesis, forType: .string)
        statusText = "Parecer copiado"
    }

    func exportFinalAsPDF() {
        guard !finalSynthesis.isEmpty else { return }
        let panel = NSSavePanel()
        panel.title = "Exportar parecer em PDF"
        panel.nameFieldStringValue = "Parecer-Conselho-Juridico-IA.pdf"
        panel.allowedContentTypes = [.pdf]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try PDFExporter.export(text: exportText(), to: url)
            statusText = "PDF exportado"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func exportText() -> String {
        """
        CONSELHO JURÍDICO IA

        QUESTÃO ANALISADA
        \(question)

        \(document.map { "DOCUMENTO: \($0.name)\n" } ?? "")
        PARECER CONSOLIDADO
        \(finalSynthesis)

        Nota: conteúdo gerado por modelos de IA como apoio à análise profissional. Valide legislação, jurisprudência, prazos e fatos em fontes oficiais.
        """
    }
}
