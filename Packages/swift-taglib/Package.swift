// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "swift-taglib",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "TagLib", targets: ["TagLib"]),
    ],
    targets: [
        .target(
            name: "TagLib",
            // C++17 for TagLib
            cxxSettings: [
                .unsafeFlags(["-std=gnu++17"])
            ],
            // (Optional) Only needed if a Swift target in this package
            // or a consumer uses C++ interop.
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
    ],
    // Global default for this package’s C++ targets
    cxxLanguageStandard: .gnucxx17
)
