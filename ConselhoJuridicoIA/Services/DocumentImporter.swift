import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

struct DocumentImporter {
    static let maximumCharacters = 140_000

    @MainActor
    func chooseDocument() throws -> ImportedDocument? {
        let panel = NSOpenPanel()
        panel.title = "Adicionar documento à análise"
        panel.prompt = "Adicionar"
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.pdf, .plainText, .text, .rtf]

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return try importDocument(at: url)
    }

    func importDocument(at url: URL) throws -> ImportedDocument {
        let ext = url.pathExtension.lowercased()
        let rawText: String

        if ext == "pdf" {
            guard let pdf = PDFDocument(url: url) else {
                throw NSError(domain: "DocumentImporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Não foi possível abrir o PDF."])
            }
            rawText = (0..<pdf.pageCount)
                .compactMap { pdf.page(at: $0)?.string }
                .joined(separator: "\n\n")

            if rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                throw NSError(
                    domain: "DocumentImporter",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Este PDF parece ser apenas uma imagem digitalizada e não contém texto pesquisável. Converta-o com OCR antes de anexar."]
                )
            }
        } else if ext == "rtf" {
            let attributed = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
            rawText = attributed.string
        } else {
            rawText = try String(contentsOf: url, encoding: .utf8)
        }

        let normalized = rawText
            .replacingOccurrences(of: "\u{0000}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalized.isEmpty else {
            throw NSError(domain: "DocumentImporter", code: 3, userInfo: [NSLocalizedDescriptionKey: "O documento não contém texto utilizável."])
        }

        let wasTruncated = normalized.count > Self.maximumCharacters
        let text = wasTruncated ? String(normalized.prefix(Self.maximumCharacters)) : normalized

        return ImportedDocument(name: url.lastPathComponent, text: text, wasTruncated: wasTruncated)
    }
}
