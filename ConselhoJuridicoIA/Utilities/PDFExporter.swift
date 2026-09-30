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

        var printOptions = NSPrintInfo.shared.dictionary()
        printOptions[.jobDisposition] = NSPrintInfo.JobDisposition.save
        printOptions[.jobSavingURL] = url

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
            throw NSError(domain: "PDFExporter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Não foi possível gerar o PDF."])
        }
    }
}
