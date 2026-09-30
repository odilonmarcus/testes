import Foundation

struct DebateEntry: Identifiable, Hashable {
    enum Speaker: String, Hashable {
        case gpt = "GPT"
        case claude = "Claude"
        case system = "Sistema"
    }

    let id = UUID()
    let speaker: Speaker
    let role: String
    let round: Int?
    let content: String
    let createdAt = Date()
}

enum AnalysisDepth: String, CaseIterable, Identifiable {
    case quick = "Rápida"
    case complete = "Completa"
    case deep = "Profunda"

    var id: String { rawValue }

    var rounds: Int {
        switch self {
        case .quick: return 2
        case .complete: return 4
        case .deep: return 6
        }
    }

    var maxOutputTokens: Int {
        switch self {
        case .quick: return 1800
        case .complete: return 2600
        case .deep: return 3400
        }
    }

    var subtitle: String {
        switch self {
        case .quick: return "2 rodadas • menor consumo"
        case .complete: return "4 rodadas • recomendado"
        case .deep: return "6 rodadas • análise extensa"
        }
    }
}

struct ImportedDocument: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let text: String
    let wasTruncated: Bool

    var characterCount: Int { text.count }
}

struct AppSettings {
    var openAIModel: String
    var anthropicModel: String

    static let defaults = AppSettings(
        openAIModel: "gpt-6-sol",
        anthropicModel: "claude-sonnet-5-5"
    )
}
