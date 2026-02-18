@attached(member, names: arbitrary)
public macro ContractClient(spec: String) = #externalMacro(
    module: "StarscreamMacrosImpl",
    type: "ContractClientMacro"
)
