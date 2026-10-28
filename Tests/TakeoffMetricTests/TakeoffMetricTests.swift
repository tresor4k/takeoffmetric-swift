import Foundation
import TakeoffMetric
import XCTest

// vectors.json is written by the Go module github.com/tresor4k/takeoffmetric-go
// (every row through ByID, the output of Search for a few queries, Sources).
// The tests compare the whole Swift table to it; no value is typed by hand.

struct VSource: Decodable, Equatable {
    let publisher: String
    let title: String
    let url: String
    let type: String
}

struct VConstant: Decodable {
    let id: String
    let category: String
    let material_or_item: String
    let quantity: String
    let value: Double?
    let value_text: String
    let unit: String
    let value_si: Double?
    let unit_si: String
    let condition: String
    let source: VSource
    let date_opened: String
    let date_opened_unix: Double
    let used_by_tool_url: [String]
    let engine_file: [String]
    let engine_symbol: [String]
    let notes: String
    let withheld: Bool
    let withheld_hosts: [String]
}

struct VSearch: Decodable {
    let query: String
    let ids: [String]
}

struct Vectors: Decodable {
    let dataset_version: String
    let count: Int
    let withheld_count: Int
    let constants: [VConstant]
    let searches: [VSearch]
    let sources: [VSource]
}

func here() -> URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent()
}

func loadVectors() throws -> Vectors {
    try JSONDecoder().decode(Vectors.self, from: Data(contentsOf: here().appendingPathComponent("vectors.json")))
}

func vsource(_ s: Source) -> VSource {
    VSource(publisher: s.publisher, title: s.title, url: s.url, type: s.type)
}

final class TakeoffMetricTests: XCTestCase {
    func testCounts() throws {
        let v = try loadVectors()
        XCTAssertEqual(v.dataset_version, "1.2.0")
        XCTAssertEqual(TakeoffMetric.all().count, v.count)
        XCTAssertEqual(v.constants.count, v.count)
        XCTAssertEqual(TakeoffMetric.all().filter { $0.withheld }.count, v.withheld_count)
    }

    func testEveryRowMatchesGo() throws {
        let v = try loadVectors()
        XCTAssertEqual(TakeoffMetric.all().map { $0.id }, v.constants.map { $0.id }, "table order")
        for w in v.constants {
            guard let c = TakeoffMetric.byID(w.id) else {
                XCTFail("\(w.id): byID returned nil")
                continue
            }
            XCTAssertEqual(c.id, w.id)
            XCTAssertEqual(c.category, w.category, w.id)
            XCTAssertEqual(c.materialOrItem, w.material_or_item, w.id)
            XCTAssertEqual(c.quantity, w.quantity, w.id)
            XCTAssertEqual(c.value, w.value, "\(w.id) value")
            XCTAssertEqual(c.valueText, w.value_text, w.id)
            XCTAssertEqual(c.unit, w.unit, w.id)
            XCTAssertEqual(c.valueSI, w.value_si, "\(w.id) value_si")
            XCTAssertEqual(c.unitSI, w.unit_si, w.id)
            XCTAssertEqual(c.condition, w.condition, w.id)
            XCTAssertEqual(vsource(c.source), w.source, w.id)
            XCTAssertEqual(c.dateOpened.timeIntervalSince1970, w.date_opened_unix, "\(w.id) \(w.date_opened)")
            XCTAssertEqual(c.usedByToolURL, w.used_by_tool_url, w.id)
            XCTAssertEqual(c.engineFile, w.engine_file, w.id)
            XCTAssertEqual(c.engineSymbol, w.engine_symbol, w.id)
            XCTAssertEqual(c.notes, w.notes, w.id)
            XCTAssertEqual(c.withheld, w.withheld, w.id)
            XCTAssertEqual(c.withheldHosts, w.withheld_hosts, w.id)
        }
    }

    func testWithheldRowsCarryNoNumber() {
        for c in TakeoffMetric.all() where c.withheld {
            XCTAssertNil(c.value, c.id)
            XCTAssertNil(c.valueSI, c.id)
            XCTAssertEqual(c.valueText, "", c.id)
            XCTAssertFalse(c.withheldHosts.isEmpty, c.id)
            XCTAssertFalse(c.source.url.isEmpty, c.id)
        }
        for c in TakeoffMetric.all() where !c.withheld {
            XCTAssertNotNil(c.value, c.id)
            XCTAssertEqual(c.withheldHosts, [], c.id)
        }
    }

    func testSearchMatchesGo() throws {
        let v = try loadVectors()
        XCTAssertGreaterThanOrEqual(v.searches.filter { !$0.ids.isEmpty }.count, 5)
        for s in v.searches {
            XCTAssertEqual(TakeoffMetric.search(s.query).map { $0.id }, s.ids, "search \"\(s.query)\"")
        }
    }

    func testSourcesMatchGo() throws {
        let v = try loadVectors()
        XCTAssertEqual(TakeoffMetric.sources().map(vsource), v.sources)
    }

    func testUnknownID() {
        XCTAssertNil(TakeoffMetric.byID("XXX-000"))
        XCTAssertNil(TakeoffMetric.byID(""))
    }

    func testEmbeddedCSVIsTheDataFile() throws {
        let file = here().appendingPathComponent("../../data/constants.csv").standardizedFileURL
        let text = String(decoding: try Data(contentsOf: file), as: UTF8.self)
        XCTAssertEqual(TakeoffMetric.csv(), text, "run python sync_data.py")
    }
}
