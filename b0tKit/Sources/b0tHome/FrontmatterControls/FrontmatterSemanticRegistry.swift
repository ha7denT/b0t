public enum FrontmatterSemanticRegistry {
    public static func kind(forKey key: String) -> FrontmatterControlKind? {
        switch key {
        case "heartbeat_bpm", "bpm": return .bpmSlider
        case "quiet_hours": return .quietHoursPicker
        case "enabled": return .enabledToggle
        default: return nil
        }
    }
}
