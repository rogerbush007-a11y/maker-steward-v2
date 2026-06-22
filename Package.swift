// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "创客管家",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "耗材管家",
            path: "Sources/耗材管家",
            exclude: [
                "Views/StatisticsView.swift.bak"
            ],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
