// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "takeoffmetric-swift",
    products: [
        .library(name: "TakeoffMetric", targets: ["TakeoffMetric"]),
    ],
    targets: [
        .target(name: "TakeoffMetric"),
        .testTarget(
            name: "TakeoffMetricTests",
            dependencies: ["TakeoffMetric"],
            exclude: ["vectors.json"]
        ),
    ]
)
