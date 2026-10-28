// TakeoffMetric US construction estimating constants, dataset version 1.2.0.
//
// A port of the Go module github.com/tresor4k/takeoffmetric-go: the same table
// (data/constants.csv), embedded as typed, read-only records. Lookup only: the
// package computes nothing. Method: https://takeoffmetric.com/methodology/
//
// Estimating values only: confirm with your plans, your supplier and your local
// code before ordering or building.

import Foundation

/// One row of the constants table. `value` and `valueSI` are the numbers of the
/// row; `valueText` keeps the value as the source prints it.
///
/// When `withheld` is true the publisher does not allow republication: `value`
/// and `valueSI` are nil, `valueText` is empty, and the value is read at
/// `source.url`.
public struct Constant: Equatable, Hashable {
    /// Stable row id, for example "CON-001".
    public let id: String
    /// concrete, rebar, aggregates, earthwork, ...
    public let category: String
    /// The product or material the value is for.
    public let materialOrItem: String
    /// What the value measures.
    public let quantity: String
    /// The value in US customary units; nil when `withheld`.
    public let value: Double?
    /// `value` exactly as written in the table.
    public let valueText: String
    /// Unit of `value`.
    public let unit: String
    /// SI conversion of `value`; nil when `withheld` or when the table leaves it empty.
    public let valueSI: Double?
    /// Unit of `valueSI`.
    public let unitSI: String
    /// The condition the value applies to (loose, bank, compacted, ...).
    public let condition: String
    /// The publication the value was read in.
    public let source: Source
    /// Date the source was opened and the value read (midnight UTC).
    public let dateOpened: Date
    /// TakeoffMetric calculator pages that use the value.
    public let usedByToolURL: [String]
    /// Site source files holding the value (not part of this package).
    public let engineFile: [String]
    /// Symbols in those files, one per `engineFile` entry.
    public let engineSymbol: [String]
    public let notes: String
    /// True when the publisher does not allow republication of the value.
    public let withheld: Bool
    /// Domains of the publishers concerned, set only when `withheld`.
    public let withheldHosts: [String]
}

/// The publication a constant was read in.
public struct Source: Equatable, Hashable {
    public let publisher: String
    public let title: String
    public let url: String
    /// federal_public_domain, manufacturer_datasheet, trade_association, supplier or other.
    public let type: String
}

/// Every constant, in table order.
public func all() -> [Constant] {
    table.constants
}

/// The constant with the given id, for example "CON-001", or nil.
public func byID(_ id: String) -> Constant? {
    guard let i = table.index[id] else { return nil }
    return table.constants[i]
}

/// The constants whose id, category, material, quantity, condition, publisher
/// or notes contain every word of `query`, ignoring case. An empty query
/// returns nothing.
public func search(_ query: String) -> [Constant] {
    let words = query.lowercased().split(whereSeparator: { $0.isWhitespace }).map { Array($0.utf8) }
    if words.isEmpty { return [] }
    return table.constants.filter { c in
        let text = Array([c.id, c.category, c.materialOrItem, c.quantity, c.condition,
                          c.source.publisher, c.notes].joined(separator: " ").lowercased().utf8)
        return words.allSatisfy { containsBytes(text, $0) }
    }
}

/// Each distinct source of the table once, sorted by publisher, then title,
/// then URL (byte order, as in the Go module).
public func sources() -> [Source] {
    var seen = Set<Source>()
    var out: [Source] = []
    for c in table.constants where !seen.contains(c.source) {
        seen.insert(c.source)
        out.append(c.source)
    }
    return out.sorted { a, b in
        if a.publisher != b.publisher { return less(a.publisher, b.publisher) }
        if a.title != b.title { return less(a.title, b.title) }
        return less(a.url, b.url)
    }
}

/// The embedded table as published (UTF-8, comma-separated). Withheld rows
/// carry no value in it either. See `Constant` and data/LICENSE for the
/// licence of each part.
public func csv() -> String {
    constantsCSV
}

// MARK: - Loading

private struct Table {
    let constants: [Constant]
    let index: [String: Int]
}

/// Parsed once, on first use (Swift initialises globals lazily and thread-safely).
private let table: Table = {
    do {
        return try load()
    } catch {
        fatalError("TakeoffMetric: embedded data is invalid: \(error)")
    }
}()

private struct DataError: Error, CustomStringConvertible {
    let description: String
}

private func load() throws -> Table {
    let rows = try parseCSV(Array(constantsCSV.utf8))
    var constants: [Constant] = []
    var index: [String: Int] = [:]
    for (i, r) in rows.dropFirst().enumerated() {
        do {
            let c = try parse(r)
            index[c.id] = constants.count
            constants.append(c)
        } catch {
            throw DataError(description: "data/constants.csv row \(i + 2): \(error)")
        }
    }
    return Table(constants: constants, index: index)
}

private func parse(_ r: [String]) throws -> Constant {
    guard r.count == 20 else { throw DataError(description: "\(r.count) fields, want 20") }
    let withheld: Bool
    switch r[18] {
    case "true":
        withheld = true
        // A withheld row must carry no number at all.
        if r[4] != "" || r[6] != "" { throw DataError(description: "withheld row has a value") }
    case "false":
        withheld = false
        if r[19] != "" { throw DataError(description: "withheld_hosts set on a row that is not withheld") }
    default:
        throw DataError(description: "values_withheld: \"\(r[18])\", want true or false")
    }
    var value: Double? = nil
    if !withheld {
        guard let x = Double(r[4]) else { throw DataError(description: "value: \"\(r[4])\"") }
        value = x
    }
    var valueSI: Double? = nil
    if r[6] != "" {
        guard let x = Double(r[6]) else { throw DataError(description: "value_si: \"\(r[6])\"") }
        valueSI = x
    }
    guard let date = parseDate(r[13]) else { throw DataError(description: "date_opened: \"\(r[13])\"") }
    return Constant(
        id: r[0], category: r[1], materialOrItem: r[2], quantity: r[3],
        value: value, valueText: r[4], unit: r[5], valueSI: valueSI, unitSI: r[7], condition: r[8],
        source: Source(publisher: r[9], title: r[10], url: r[11], type: r[12]),
        dateOpened: date,
        usedByToolURL: splitList(r[14], "; "), engineFile: splitList(r[15], "; "), engineSymbol: splitList(r[16], "; "),
        notes: r[17], withheld: withheld, withheldHosts: splitList(r[19], ";"))
}

private func splitList(_ s: String, _ separator: String) -> [String] {
    s.isEmpty ? [] : s.components(separatedBy: separator)
}

/// "YYYY-MM-DD" to midnight UTC, without Calendar or DateFormatter.
private func parseDate(_ s: String) -> Date? {
    let b = Array(s.utf8)
    guard b.count == 10, b[4] == UInt8(ascii: "-"), b[7] == UInt8(ascii: "-") else { return nil }
    func number(_ range: Range<Int>) -> Int? {
        var n = 0
        for i in range {
            guard b[i] >= UInt8(ascii: "0"), b[i] <= UInt8(ascii: "9") else { return nil }
            n = n * 10 + Int(b[i] - UInt8(ascii: "0"))
        }
        return n
    }
    guard let y = number(0..<4), let m = number(5..<7), let d = number(8..<10), (1...12).contains(m) else { return nil }
    let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
    let monthDays = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    guard d >= 1, d <= monthDays[m - 1] else { return nil }
    // Days from 1970-01-01 (H. Hinnant, days_from_civil).
    let yy = m <= 2 ? y - 1 : y
    let era = (yy >= 0 ? yy : yy - 399) / 400
    let yoe = yy - era * 400
    let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    let days = era * 146097 + doe - 719468
    return Date(timeIntervalSince1970: TimeInterval(days * 86400))
}

/// RFC 4180 records, as encoding/csv reads them: quoted fields with "" for a
/// quote, LF or CRLF line ends, blank lines skipped, a bare quote refused.
private func parseCSV(_ b: [UInt8]) throws -> [[String]] {
    let quote = UInt8(ascii: "\""), comma = UInt8(ascii: ","), lf = UInt8(ascii: "\n"), cr = UInt8(ascii: "\r")
    var rows: [[String]] = []
    var row: [String] = []
    var field: [UInt8] = []
    var i = 0
    var line = 1
    func endField() {
        row.append(String(decoding: field, as: UTF8.self))
        field.removeAll(keepingCapacity: true)
    }
    while i < b.count {
        // Start of a field.
        if b[i] == quote {
            i += 1
            while true {
                guard i < b.count else { throw DataError(description: "line \(line): unterminated quoted field") }
                if b[i] == quote {
                    if i + 1 < b.count && b[i + 1] == quote {
                        field.append(quote)
                        i += 2
                        continue
                    }
                    i += 1
                    break
                }
                if b[i] == lf { line += 1 }
                field.append(b[i])
                i += 1
            }
            if i < b.count && b[i] != comma && b[i] != lf && !(b[i] == cr && i + 1 < b.count && b[i + 1] == lf) {
                throw DataError(description: "line \(line): extraneous character after a quoted field")
            }
        } else {
            while i < b.count && b[i] != comma && b[i] != lf && !(b[i] == cr && i + 1 < b.count && b[i + 1] == lf) {
                if b[i] == quote { throw DataError(description: "line \(line): bare quote in a field") }
                field.append(b[i])
                i += 1
            }
        }
        endField()
        if i >= b.count { break }
        if b[i] == comma {
            i += 1
            if i >= b.count { endField() }
            continue
        }
        // End of record.
        i += b[i] == cr ? 2 : 1
        line += 1
        rows.append(row)
        row = []
        // Blank lines are skipped.
        while i < b.count && (b[i] == lf || (b[i] == cr && i + 1 < b.count && b[i + 1] == lf)) {
            i += b[i] == cr ? 2 : 1
            line += 1
        }
    }
    if !row.isEmpty { rows.append(row) }
    if let n = rows.first?.count, let bad = rows.firstIndex(where: { $0.count != n }) {
        throw DataError(description: "record \(bad + 1): \(rows[bad].count) fields, want \(n)")
    }
    return rows
}

/// Byte-wise substring test, like strings.Contains.
private func containsBytes(_ text: [UInt8], _ word: [UInt8]) -> Bool {
    if word.count > text.count { return false }
    if word.isEmpty { return true }
    var i = 0
    while i + word.count <= text.count {
        if text[i] == word[0] && text[i..<(i + word.count)].elementsEqual(word) { return true }
        i += 1
    }
    return false
}

/// Byte order of the UTF-8 encodings, like Go's < on strings.
private func less(_ a: String, _ b: String) -> Bool {
    a.utf8.lexicographicallyPrecedes(b.utf8)
}
