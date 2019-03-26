// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "SammysServer",
    dependencies: [
		.package(url: "https://github.com/vapor/vapor.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor/fluent-postgresql.git", from: "1.0.0"),
		.package(url: "https://github.com/vapor/jwt.git", from: "3.0.0"),
		.package(url: "https://github.com/vapor-community/stripe-provider.git", from: "2.2.0")
    ],
    targets: [
        .target(name: "App", dependencies: ["Vapor", "FluentPostgreSQL", "JWT", "Stripe"]),
        .target(name: "Run", dependencies: ["App"]),
        .testTarget(name: "AppTests", dependencies: ["App"])
	]
)
