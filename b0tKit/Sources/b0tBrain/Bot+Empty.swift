import Foundation

extension Bot {
    /// Test-friendly factory: returns a `Bot` handle to the given URL with a fresh
    /// `BotStore`. The URL doesn't need to exist on disk — useful for exercising types
    /// that hold a `Bot` reference but do not perform I/O against it (e.g. transient
    /// view-state objects in `b0tHome`).
    public static func empty(at url: URL) -> Bot {
        Bot(rootURL: url, store: BotStore())
    }
}
