// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "keyboard_language",
  platforms: [
    .iOS("13.0")
  ],
  products: [
    .library(name: "keyboard-language", targets: ["keyboard_language"])
  ],
  dependencies: [],
  targets: [
    .target(
      name: "keyboard_language",
      dependencies: [],
      resources: [
        .process("Resources")
      ]
    )
  ]
)
