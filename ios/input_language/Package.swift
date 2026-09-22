// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "input_language",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "input-language", targets: ["input_language"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "input_language",
      dependencies: [],
      resources: [
        .process("Resources")
      ]
    )
  ]
)
