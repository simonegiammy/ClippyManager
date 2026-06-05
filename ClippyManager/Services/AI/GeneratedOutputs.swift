import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

#if canImport(FoundationModels)

/// Guaranteed-shape bullet list.
@available(macOS 26, *)
@Generable
struct GeneratedBullets {
    @Guide(description: "Between 2 and 7 short key points, each a single line.")
    var points: [String]

    func asText() -> String {
        points.map { "• \($0)" }.joined(separator: "\n")
    }
}

/// A single table row.
@available(macOS 26, *)
@Generable
struct GeneratedTableRow {
    @Guide(description: "The cells of this row, one value per column, same order as headers.")
    var cells: [String]
}

/// Guaranteed-shape table that renders to GitHub-flavored markdown.
@available(macOS 26, *)
@Generable
struct GeneratedTable {
    @Guide(description: "Column headers.")
    var headers: [String]
    @Guide(description: "Data rows. Each row's cells align with the headers.")
    var rows: [GeneratedTableRow]

    func asMarkdown() -> String {
        guard !headers.isEmpty else { return "" }
        let head = "| " + headers.joined(separator: " | ") + " |"
        let sep  = "| " + headers.map { _ in "---" }.joined(separator: " | ") + " |"
        let body = rows.map { "| " + $0.cells.joined(separator: " | ") + " |" }.joined(separator: "\n")
        return ([head, sep] + (body.isEmpty ? [] : [body])).joined(separator: "\n")
    }
}

#endif
