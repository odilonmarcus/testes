import Foundation

struct DebateEngine {
    let openAI = OpenAIClient()
    let anthropic = AnthropicClient()

    typealias EntryHandler = @MainActor (DebateEntry) -> Void
    typealias StatusHandler = @MainActor (String) -> Void

    func run(
        question: String,
        document: ImportedDocument?,
        depth: AnalysisDepth,
        openAIKey: String,
        anthropicKey: String,
        settings: AppSettings,
        onEntry: @escaping EntryHandler,
        onStatus: @escaping StatusHandler
    ) async throws -> String {
        var entries: [DebateEntry] = []
        let documentBlock = makeDocumentBlock(document)
        let sharedRules = sharedLegalRules

        await onStatus("GPT está estruturando a tese…")
        let initialGPT = try await openAI.generate(
            apiKey: openAIKey,
            model: settings.openAIModel,
            system: gptSystem + sharedRules,
            prompt: """
            <questao>
            \(question)
            </questao>
            \(documentBlock)

            Você está na primeira rodada. Estruture a tese da forma mais forte possível. Identifique fatos, premissas, pontos jurídicos, estratégia, riscos iniciais e informações faltantes. Não invente fatos nem fontes.
            """,
            maxOutputTokens: depth.maxOutputTokens
        )
        let first = DebateEntry(speaker: .gpt, role: "Advogado da tese", round: 1, content: initialGPT)
        entries.append(first)
        await onEntry(first)

        await onStatus("Claude está fazendo o contraditório…")
        let initialClaude = try await anthropic.generate(
            apiKey: anthropicKey,
            model: settings.anthropicModel,
            system: claudeSystem + sharedRules,
            prompt: """
            <questao>
            \(question)
            </questao>
            \(documentBlock)

            <proposta_gpt>
            \(initialGPT)
            </proposta_gpt>

            Atue como advogado do contraditório. Tente desmontar a tese com rigor. Procure premissas não comprovadas, interpretações alternativas, riscos processuais, probatórios, contratuais, regulatórios, prazos, competência, legitimidade, ônus da prova e possíveis efeitos adversos. Não discorde por esporte: reconheça pontos realmente sólidos.
            """,
            maxOutputTokens: depth.maxOutputTokens
        )
        let second = DebateEntry(speaker: .claude, role: "Advogado do contraditório", round: 1, content: initialClaude)
        entries.append(second)
        await onEntry(second)

        if depth.rounds >= 2 {
            for round in 2...depth.rounds {
                let transcript = compactTranscript(entries)

                await onStatus("GPT está revisando a tese — rodada \(round)/\(depth.rounds)…")
                let gpt = try await openAI.generate(
                    apiKey: openAIKey,
                    model: settings.openAIModel,
                    system: gptSystem + sharedRules,
                    prompt: """
                    <questao>
                    \(question)
                    </questao>
                    \(documentBlock)

                    <debate_anterior>
                    \(transcript)
                    </debate_anterior>

                    Rodada \(round). Refaça a tese considerando o contraditório. Aceite críticas válidas, rebata apenas o que puder ser sustentado, corrija exageros e torne a estratégia mais robusta. Diga claramente o que mudou em relação à rodada anterior e quais pontos continuam sem segurança suficiente.
                    """,
                    maxOutputTokens: depth.maxOutputTokens
                )
                let gptEntry = DebateEntry(speaker: .gpt, role: round == depth.rounds ? "Revisor da tese" : "Advogado da tese", round: round, content: gpt)
                entries.append(gptEntry)
                await onEntry(gptEntry)

                await onStatus("Claude está auditando a revisão — rodada \(round)/\(depth.rounds)…")
                let claude = try await anthropic.generate(
                    apiKey: anthropicKey,
                    model: settings.anthropicModel,
                    system: claudeSystem + sharedRules,
                    prompt: """
                    <questao>
                    \(question)
                    </questao>
                    \(documentBlock)

                    <debate_anterior>
                    \(compactTranscript(entries))
                    </debate_anterior>

                    Rodada \(round). Audite a nova versão do GPT. Dê prioridade a vulnerabilidades que ainda não foram resolvidas. Identifique argumentos que parecem fortes apenas porque foram repetidos. Separe: (1) objeções superadas, (2) objeções ainda relevantes, (3) novos riscos, (4) fatos ou documentos que mudariam a conclusão.
                    """,
                    maxOutputTokens: depth.maxOutputTokens
                )
                let claudeEntry = DebateEntry(speaker: .claude, role: round == depth.rounds ? "Auditor final" : "Advogado do contraditório", round: round, content: claude)
                entries.append(claudeEntry)
                await onEntry(claudeEntry)
            }
        }

        await onStatus("Preparando o parecer consolidado…")
        let finalTranscript = compactTranscript(entries, maxCharacters: 95_000)
        let synthesis = try await openAI.generate(
            apiKey: openAIKey,
            model: settings.openAIModel,
            system: relatorSystem + sharedRules,
            prompt: """
            <questao>
            \(question)
            </questao>
            \(documentBlock)

            <debate_completo>
            \(finalTranscript)
            </debate_completo>

            Redija o PARECER CONSOLIDADO. Não declare um vencedor. Integre os melhores argumentos dos dois lados e preserve divergências reais.

            Estrutura obrigatória:
            1. Resumo executivo
            2. Fatos e premissas consideradas
            3. Tese mais defensável neste momento
            4. Principais argumentos favoráveis
            5. Principais objeções e vulnerabilidades
            6. Provas, documentos ou fatos que precisam ser obtidos
            7. Pontos que exigem validação em fonte jurídica oficial
            8. Estratégias ou caminhos alternativos
            9. Matriz de riscos (alto/médio/baixo, com justificativa, sem inventar probabilidades)
            10. Próximas providências sugeridas para investigação e preparação

            Se o material não permitir uma conclusão segura, diga isso expressamente.
            """,
            maxOutputTokens: max(depth.maxOutputTokens, 3200)
        )

        let finalEntry = DebateEntry(speaker: .system, role: "Parecer consolidado", round: nil, content: synthesis)
        await onEntry(finalEntry)
        await onStatus("Análise concluída")
        return synthesis
    }

    private func makeDocumentBlock(_ document: ImportedDocument?) -> String {
        guard let document else { return "<documentos>Nenhum documento foi anexado.</documentos>" }
        let truncationNotice = document.wasTruncated
            ? "\n[AVISO: o documento excedeu o limite local e foi truncado. Não trate a ausência de trechos posteriores como inexistência.]"
            : ""
        return """
        <documentos>
        <documento nome="\(document.name)">
        \(document.text)\(truncationNotice)
        </documento>
        </documentos>
        """
    }

    private func compactTranscript(_ entries: [DebateEntry], maxCharacters: Int = 70_000) -> String {
        let full = entries.map { entry in
            let round = entry.round.map { " — rodada \($0)" } ?? ""
            return "### \(entry.speaker.rawValue) / \(entry.role)\(round)\n\(entry.content)"
        }.joined(separator: "\n\n")

        guard full.count > maxCharacters else { return full }
        let suffix = full.suffix(maxCharacters)
        return "[Trechos mais antigos do debate foram resumidos pela limitação de contexto local.]\n\n" + suffix
    }

    private var sharedLegalRules: String {
        """

        REGRAS DE CONFIABILIDADE:
        - A análise é apoio profissional, não substitui verificação jurídica independente.
        - Não invente leis, artigos, súmulas, precedentes, números de processo, datas, decisões, fatos ou citações.
        - Quando uma autoridade jurídica não estiver no material fornecido ou não puder ser afirmada com segurança, escreva "VALIDAR EM FONTE OFICIAL".
        - Diferencie fatos fornecidos, inferências, hipóteses e questões jurídicas.
        - Não trate memória do modelo como atualização legislativa ou jurisprudencial em tempo real.
        - Aponte conflitos de informação e lacunas probatórias.
        - Escreva em português do Brasil, com linguagem profissional, direta e utilizável por advogado.
        """
    }

    private var gptSystem: String {
        """
        Você atua como ADVOGADO DA TESE e estrategista jurídico. Seu papel é construir a versão mais robusta do argumento apresentado, mas sem esconder fragilidades nem fabricar fundamento. Você deve melhorar a tese quando o contraditório trouxer objeções válidas.
        """
    }

    private var claudeSystem: String {
        """
        Você atua como ADVOGADO DO CONTRADITÓRIO e auditor jurídico. Sua função é testar a tese de forma adversarial, identificar vulnerabilidades reais e propor interpretações alternativas. Não concorde por cortesia e não discorde por esporte.
        """
    }

    private var relatorSystem: String {
        """
        Você atua como RELATOR NEUTRO de um conselho jurídico formado por dois modelos. Sua função é consolidar o debate, separar consenso de divergência e produzir um memorando útil para decisão humana. Não declare vencedor e não esconda incertezas.
        """
    }
}
