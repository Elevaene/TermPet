// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TermPet",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TermPet", targets: ["TermPet"]),
        .executable(name: "TermPetLogicTests", targets: ["TermPetLogicTests"]),
        .library(name: "TermPetCore", targets: ["TermPetCore"]),
    ],
    targets: [
        .target(
            name: "TermPetCore"
        ),
        .executableTarget(
            name: "TermPet",
            dependencies: ["TermPetCore"],
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "TermPetLogicTests",
            dependencies: ["TermPetCore"],
            path: "Tests/TermPetLogicTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
