import AppKit
import Foundation

struct PDFExporter {
    static func export(text: String, to url: URL) throws {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 520, height: 800))
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 24, height: 24)
        textView.font = .systemFont(ofSize: 11)
        textView.string = text

        // NSPrintInfo.shared.dictionary() returns NSMutableDictionary, while
        // NSPrintInfo(dictionary:) expects a typed Swift dictionary.
        // Build the typed dictionary directly to keep Xcode 16 happy.
        let printOptions: [NSPrintInfo.AttributeKey: Any] = [
            .jobDisposition: NSPrintInfo.JobDisposition.save,
            .jobSavingURL: url
        ]

        let printInfo = NSPrintInfo(dictionary: printOptions)
        printInfo.orientation = .portrait
        printInfo.topMargin = 36
        printInfo.bottomMargin = 36
        printInfo.leftMargin = 42
        printInfo.rightMargin = 42
        printInfo.horizontalPagination = .fit
        printInfo.verticalPagination = .automatic

        let operation = NSPrintOperation(view: textView, printInfo: printInfo)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false

        guard operation.run() else {
            throw NSError(
                domain: "PDFExporter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Não foi possível gerar o PDF."]
            )
        }
    }
}
