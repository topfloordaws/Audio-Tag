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
            // C++20 for TagLib to support std::u8string
            cxxSettings: [
                .unsafeFlags(["-std=gnu++20"])
            ],
            // Only needed if a Swift target in this package
            // or a consumer uses C++ interop.
            swiftSettings: [
                .interoperabilityMode(.Cxx)
            ]
        ),
    ],
    // Global default for this package’s C++ targets
    cxxLanguageStandard: .gnucxx20
)
