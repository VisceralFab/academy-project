import SwiftUI
import UIKit

/// Builds the carer's PDF performance report from the data stored on this device.
enum ReadLabPerformanceReport {
    static let pageSize = CGSize(width: 595, height: 842) // A4 in points

    static func makePDF(from data: ReadLabData, now: Date = .now) throws -> URL {
        let format = UIGraphicsPDFRendererFormat()
        let childName = data.profile.childName.trimmingCharacters(in: .whitespacesAndNewlines)
        format.documentInfo = [
            kCGPDFContextTitle as String: "ReadLab performance report",
            kCGPDFContextCreator as String: "ReadLab"
        ]
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize), format: format)
        let pdf = renderer.pdfData { context in
            let writer = ReportWriter(context: context, generated: now)
            writer.beginPage()
            write(data, childName: childName, now: now, into: writer)
        }

        let safeName = (childName.isEmpty ? "Reader" : childName)
            .components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: "-")
        let stamp = now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ReadLab-Report-\(safeName)-\(stamp).pdf")
        try pdf.write(to: url, options: .atomic)
        return url
    }

    // MARK: Content

    private static func write(_ data: ReadLabData, childName: String, now: Date, into w: ReportWriter) {
        let log = data.exerciseLog
        let responses = log.filter { $0.outcome == .correct || $0.outcome == .retry }

        w.title("Performance report")
        w.paragraph("\(childName.isEmpty ? "Reader" : childName) · generated \(now.formatted(date: .long, time: .shortened))",
                    font: .systemFont(ofSize: 12), color: ReportWriter.muted)
        w.space(10)

        if !data.preferences.trackReadingProgress {
            w.notice("Progress tracking is currently turned off, so no exercise data is being collected. Turn on “Track reading progress” in Account to start recording practice.")
        }

        // Child profile
        w.heading("Child profile")
        w.keyValues([
            ("Name", childName.isEmpty ? "Reader" : childName),
            ("Age range", data.profile.ageRange?.rawValue ?? "Not specified"),
            ("Reading familiarity", data.profile.readingFamiliarity?.rawValue ?? "Not specified"),
            ("Learning differences", data.preferences.diagnosis.rawValue),
            ("Reading font", data.preferences.useDyslexicFont ? "OpenDyslexic Bold" : "System Rounded"),
            ("Current reading path", data.selectedPath.title)
        ])

        // Highlights
        w.heading("Highlights")
        let correct = responses.filter { $0.outcome == .correct }.count
        let days = Set(log.map { Calendar.current.startOfDay(for: $0.date) }).count
        let firstDate = log.map(\.date).min()
        let lastDate = log.map(\.date).max()
        w.keyValues([
            ("Recorded period", firstDate.map { "\($0.formatted(date: .abbreviated, time: .omitted)) – \(lastDate!.formatted(date: .abbreviated, time: .omitted))" } ?? "No practice recorded yet"),
            ("Days with practice", "\(days)"),
            ("Activities completed", "\(data.totals.values.map(\.completedActivities).reduce(0, +))"),
            ("Practice responses", "\(data.totals.values.map(\.attempts).reduce(0, +))"),
            ("Overall success rate", rate(correct, responses.count)),
            ("Readings checked by a grown-up", "\(log.filter { $0.outcome == .assisted }.count)")
        ])

        // Per path overview
        w.heading("Overview by reading path")
        w.table(columns: [("Path", 0.28), ("Current level", 0.14), ("Activities", 0.14), ("Responses", 0.14), ("Correct", 0.14), ("Success", 0.16)],
                rows: ReadingPath.allCases.map { path in
                    let t = data.totals[path.rawValue, default: .init()]
                    return [path.title,
                            "\(data.difficulty(for: path).level) of 5",
                            "\(t.completedActivities)", "\(t.attempts)", "\(t.successfulAnswers)",
                            rate(t.successfulAnswers, t.attempts)]
                })
        w.paragraph("The starting level is based on age (1 = easiest, 5 = hardest). In word practice, completing a topic unlocks its next level. In stories, three correct responses raise the level. Repeated misses can lower the level in any path.",
                    font: .systemFont(ofSize: 9), color: ReportWriter.muted)

        // Per theme
        let byTheme = Dictionary(grouping: responses) { "\($0.path.rawValue)|\($0.themeID)" }
        if !byTheme.isEmpty {
            w.heading("Results by theme")
            let rows = byTheme.values.sorted { ($0.first!.path.rawValue, $0.first!.themeID) < ($1.first!.path.rawValue, $1.first!.themeID) }
                .map { group -> [String] in
                    let first = group[0]
                    let ok = group.filter { $0.outcome == .correct }.count
                    let last = group.map(\.date).max()!
                    return [first.path.title, themeTitle(first.themeID), "\(group.count)", "\(ok)", rate(ok, group.count),
                            last.formatted(date: .abbreviated, time: .omitted)]
                }
            w.table(columns: [("Path", 0.22), ("Theme", 0.24), ("Responses", 0.13), ("Correct", 0.12), ("Success", 0.12), ("Last practised", 0.17)], rows: rows)
        }

        // Daily trend
        let byDay = Dictionary(grouping: log) { Calendar.current.startOfDay(for: $0.date) }
        if !byDay.isEmpty {
            w.heading("Practice by day")
            let rows = byDay.keys.sorted(by: >).map { day -> [String] in
                let entries = byDay[day]!
                let resp = entries.filter { $0.outcome == .correct || $0.outcome == .retry }
                let ok = resp.filter { $0.outcome == .correct }.count
                return [day.formatted(date: .abbreviated, time: .omitted),
                        "\(entries.filter { $0.outcome == .completed }.count)",
                        "\(resp.count)", "\(ok)", rate(ok, resp.count),
                        "\(entries.filter { $0.outcome == .assisted }.count)"]
            }
            w.table(columns: [("Date", 0.24), ("Activities", 0.14), ("Responses", 0.15), ("Correct", 0.13), ("Success", 0.14), ("With grown-up", 0.20)], rows: rows)
        }

        // Full log
        w.heading("Exercise log")
        if log.isEmpty {
            w.paragraph("No exercises have been recorded yet.", font: .systemFont(ofSize: 11), color: ReportWriter.muted)
        } else {
            w.paragraph("Every recorded exercise, newest first.", font: .systemFont(ofSize: 10), color: ReportWriter.muted)
            let rows = log.reversed().map { r -> [String] in
                [r.date.formatted(date: .numeric, time: .shortened), r.path.title, themeTitle(r.themeID),
                 r.item.isEmpty ? "—" : r.item, r.outcome.label, "\(r.level)"]
            }
            w.table(columns: [("Date", 0.17), ("Path", 0.15), ("Theme", 0.14), ("Exercise", 0.28), ("Result", 0.18), ("Level", 0.08)],
                    rows: rows, fontSize: 8.5)
        }
        w.space(14)
        w.paragraph("Every little effort helps. These numbers describe practice, not a grade. Data is stored only on this device.",
                    font: .italicSystemFont(ofSize: 9), color: ReportWriter.muted)
    }

    private static func rate(_ ok: Int, _ total: Int) -> String {
        total == 0 ? "—" : "\(Int((Double(ok) / Double(total) * 100).rounded()))%"
    }
    private static func themeTitle(_ id: String) -> String {
        ReadingTheme.all.first { $0.id == id }?.title ?? "—"
    }
}

/// Minimal paginating text/table layout for UIGraphicsPDFRenderer.
private final class ReportWriter {
    static let ink = UIColor(red: 0.149, green: 0.224, blue: 0.263, alpha: 1)
    static let accent = UIColor(red: 0.16, green: 0.49, blue: 0.73, alpha: 1)
    static let muted = UIColor(red: 0.40, green: 0.45, blue: 0.50, alpha: 1)
    static let stripe = UIColor(red: 0.94, green: 0.97, blue: 0.99, alpha: 1)

    private let context: UIGraphicsPDFRendererContext
    private let generated: Date
    private let margin: CGFloat = 40
    private let footerHeight: CGFloat = 30
    private var y: CGFloat = 0
    private var page = 0
    private var width: CGFloat { ReadLabPerformanceReport.pageSize.width - margin * 2 }
    private var bottom: CGFloat { ReadLabPerformanceReport.pageSize.height - margin - footerHeight }

    init(context: UIGraphicsPDFRendererContext, generated: Date) {
        self.context = context
        self.generated = generated
    }

    func beginPage() {
        context.beginPage()
        page += 1
        y = margin
        // Header band
        let band = CGRect(x: 0, y: 0, width: ReadLabPerformanceReport.pageSize.width, height: 6)
        Self.accent.setFill(); UIRectFill(band)
        draw("ReadLab", at: CGPoint(x: margin, y: 16), font: .systemFont(ofSize: 10, weight: .bold), color: Self.accent)
        // Footer
        let footer = "Page \(page) · ReadLab performance report · \(generated.formatted(date: .abbreviated, time: .omitted))"
        draw(footer, at: CGPoint(x: margin, y: ReadLabPerformanceReport.pageSize.height - margin + 6),
             font: .systemFont(ofSize: 8), color: Self.muted)
        y = margin + 8
    }

    func space(_ h: CGFloat) { y += h }

    func title(_ text: String) {
        paragraph(text, font: .systemFont(ofSize: 26, weight: .bold), color: Self.ink)
    }

    func heading(_ text: String) {
        ensure(60)
        y += 14
        paragraph(text, font: .systemFont(ofSize: 15, weight: .semibold), color: Self.accent)
        Self.accent.withAlphaComponent(0.35).setFill()
        UIRectFill(CGRect(x: margin, y: y, width: width, height: 1))
        y += 8
    }

    func notice(_ text: String) {
        let attr = attributed(text, font: .systemFont(ofSize: 11, weight: .medium), color: Self.ink)
        let h = height(of: attr, width: width - 24) + 20
        ensure(h)
        let box = CGRect(x: margin, y: y, width: width, height: h)
        UIColor(red: 1, green: 0.95, blue: 0.85, alpha: 1).setFill()
        UIBezierPath(roundedRect: box, cornerRadius: 8).fill()
        attr.draw(with: box.insetBy(dx: 12, dy: 10), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        y += h + 8
    }

    func paragraph(_ text: String, font: UIFont, color: UIColor) {
        let attr = attributed(text, font: font, color: color)
        let h = height(of: attr, width: width)
        ensure(h)
        attr.draw(with: CGRect(x: margin, y: y, width: width, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        y += h + 4
    }

    func keyValues(_ pairs: [(String, String)]) {
        let keyWidth = width * 0.38
        for (key, value) in pairs {
            let k = attributed(key, font: .systemFont(ofSize: 11), color: Self.muted)
            let v = attributed(value, font: .systemFont(ofSize: 11, weight: .medium), color: Self.ink)
            let h = max(height(of: k, width: keyWidth - 8), height(of: v, width: width - keyWidth)) + 6
            ensure(h)
            k.draw(with: CGRect(x: margin, y: y + 3, width: keyWidth - 8, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            v.draw(with: CGRect(x: margin + keyWidth, y: y + 3, width: width - keyWidth, height: h), options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            y += h
        }
    }

    func table(columns: [(String, CGFloat)], rows: [[String]], fontSize: CGFloat = 10) {
        let widths = columns.map { $0.1 * width }
        let pad: CGFloat = 5
        func rowHeight(_ cells: [NSAttributedString]) -> CGFloat {
            zip(cells, widths).map { height(of: $0, width: $1 - pad * 2) }.max()! + pad * 2
        }
        func drawRow(_ cells: [NSAttributedString], fill: UIColor?) {
            let h = rowHeight(cells)
            if let fill { fill.setFill(); UIRectFill(CGRect(x: margin, y: y, width: width, height: h)) }
            var x = margin
            for (cell, w) in zip(cells, widths) {
                cell.draw(with: CGRect(x: x + pad, y: y + pad, width: w - pad * 2, height: h - pad * 2),
                          options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
                x += w
            }
            y += h
        }
        let header = columns.map { attributed($0.0, font: .systemFont(ofSize: fontSize, weight: .semibold), color: .white) }
        let headerFill = Self.accent
        ensure(rowHeight(header) * 2)
        drawRow(header, fill: headerFill)
        for (index, row) in rows.enumerated() {
            let cells = row.map { attributed($0, font: .systemFont(ofSize: fontSize), color: Self.ink) }
            if y + rowHeight(cells) > bottom {
                beginPage()
                drawRow(header, fill: headerFill) // repeat header on each new page
            }
            drawRow(cells, fill: index.isMultiple(of: 2) ? Self.stripe : nil)
        }
        y += 6
    }

    // MARK: Helpers

    private func ensure(_ h: CGFloat) { if y + h > bottom { beginPage() } }

    private func attributed(_ text: String, font: UIFont, color: UIColor) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }

    private func height(of text: NSAttributedString, width: CGFloat) -> CGFloat {
        ceil(text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                               options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil).height)
    }

    private func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor) {
        attributed(text, font: font, color: color).draw(at: point)
    }
}

/// Presents the iOS share sheet (Save to Files, Mail, AirDrop, Print…).
struct ReadLabShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
