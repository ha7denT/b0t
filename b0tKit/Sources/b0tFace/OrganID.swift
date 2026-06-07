/// The ten organs of the anatomical GUI, per ADR-0017 (supersedes ADR-0010's roster).
///
/// Stable across all phases — fixed anatomical subsystems, not derived from modules.
/// Arranged as two vertical columns: left = world-facing I/O, right = inward / mind,
/// with the processor as the top crown and the heart at bottom centre.
///
/// `reasoning` is the **processor** crown slot (ADR-0017 renamed Reasoning → Processor;
/// the case name is retained as the stable processor identifier / model-management surface).
public enum OrganID: String, CaseIterable, Sendable, Hashable {
    // Top crown (distinguished) — the processor / inference engine
    case reasoning  // processor crown

    // Left column — world-facing I/O (top → bottom)
    case network
    case location
    case sensors
    case tools

    // Right column — inward / mind (top → bottom)
    case memory
    case identity
    case modules
    case journal

    // Bottom-centre (distinguished)
    case heart
}
