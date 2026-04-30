// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "b0tKit",
    platforms: [
        .iOS("26.0")
    ],
    products: [
        .library(name: "b0tCore", targets: ["b0tCore"]),
        .library(name: "b0tBrain", targets: ["b0tBrain"]),
        .library(name: "b0tSkills", targets: ["b0tSkills"]),
        .library(name: "b0tFace", targets: ["b0tFace"]),
        .library(name: "b0tAudio", targets: ["b0tAudio"]),
        .library(name: "b0tDesign", targets: ["b0tDesign"]),
    ],
    targets: [
        .target(name: "b0tCore", dependencies: ["b0tBrain"]),
        .target(name: "b0tBrain"),
        .target(name: "b0tSkills", dependencies: ["b0tBrain"]),
        .target(name: "b0tFace", dependencies: ["b0tDesign"]),
        .target(name: "b0tAudio"),
        .target(name: "b0tDesign"),

        .testTarget(name: "b0tCoreTests", dependencies: ["b0tCore"]),
        .testTarget(name: "b0tBrainTests", dependencies: ["b0tBrain"]),
        .testTarget(name: "b0tSkillsTests", dependencies: ["b0tSkills"]),
        .testTarget(name: "b0tFaceTests", dependencies: ["b0tFace"]),
        .testTarget(name: "b0tAudioTests", dependencies: ["b0tAudio"]),
        .testTarget(name: "b0tDesignTests", dependencies: ["b0tDesign"]),
    ],
    swiftLanguageModes: [.v6]
)
