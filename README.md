# takeoffmetric-swift

Dependency-free Swift package (Foundation only) that embeds version 1.2.0 of the US construction estimating constants
published by [TakeoffMetric](https://takeoffmetric.com/) as typed, read-only records: bag yields, aggregate and soil
densities, swell and compaction ratios, rebar weights, dressed lumber sizes, block counts, shingle coverage, asphalt unit
weights and air properties. These are published constants with their sources, not original research: each record gives
the value, its unit, an SI conversion, the condition it applies to and the source it was read in.

It is a port of the Go module [takeoffmetric-go](https://github.com/tresor4k/takeoffmetric-go): same table, same
lookups. The tests compare every record, the search results and the source list to vectors written by the Go module.

55 of the 148 records carry no value: their publishers do not allow republication. Those records keep the quantity, its
unit and the link to the source; `withheld` is true, `value` and `valueSI` are nil, and `withheldHosts` lists the domains
concerned. Read the value at `source.url`.

```swift
import TakeoffMetric

let c = TakeoffMetric.byID("CON-007")       // c?.value is a Double?, nil when c?.withheld
let rows = TakeoffMetric.search("bank density")
let all = TakeoffMetric.all()
let src = TakeoffMetric.sources()
```

The package is a lookup library and computes nothing. To turn dimensions into quantities, use the calculators on the
site, for example the [concrete calculator](https://takeoffmetric.com/concrete/concrete-calculator/). How they use
these values: [methodology](https://takeoffmetric.com/methodology/).

Estimating values only: confirm with your plans, your supplier and your local code before ordering or building.

## Updating the data

`python sync_data.py` copies `../TakeoffMetrics-go/data/constants.csv` (or the file given as first argument) into
`data/` and regenerates `Sources/TakeoffMetric/ConstantsCSV.swift`, which embeds the same bytes as a string literal (no
resource bundle). It accepts only the 1.1.x header (with `values_withheld` and `withheld_hosts`). Then regenerate
`Tests/TakeoffMetricTests/vectors.json` from the Go module and run `swift test`.

## Licence

- Code: MIT, see LICENSE.
- Constants (`data/` and the copy embedded in `Sources/TakeoffMetric/ConstantsCSV.swift`), see data/LICENSE:
  - the compilation (selection of rows, SI conversions, conditions, notes, column structure): CC BY 4.0, attribution
    TakeoffMetric Editorial;
  - values from federal publications: works of the US government, in the public domain;
  - any other value stays under the terms of its publisher and is not relicensed by CC BY 4.0; each row names its
    publisher and links its source (`source_publisher`, `source_title`, `source_url`);
  - 55 rows carry no value (`values_withheld` = `true`): their publishers do not allow republication.
- Cite as: TakeoffMetric Editorial, *US Construction Estimating Constants*, version 1.2.0, 2026, takeoffmetric.com.
- The calculation engine of takeoffmetric.com is not included in this package.
