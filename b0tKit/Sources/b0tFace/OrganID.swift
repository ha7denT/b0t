/// The nine organs of the anatomical GUI, per ADR-0010.
///
/// Stable across all phases — fixed anatomical subsystems, not derived from modules.
public enum OrganID: String, CaseIterable, Sendable, Hashable {
    // Above eye-line (perception / knowledge / capability)
    case reasoning  // top crown
    case memory  // upper
    case identity  // upper / left
    case modules  // upper

    // Below eye-line (input / output)
    case sensors
    case tools
    case network
    case location

    // Bottom-centre (distinguished)
    case heart
}
