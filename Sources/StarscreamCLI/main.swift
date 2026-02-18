import ArgumentParser

@main
struct StarscreamCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "starscream-cli",
        abstract: "Generate typed contract clients from Soroban contracts"
    )

    func run() throws {
        print("starscream-cli: not yet implemented")
    }
}
