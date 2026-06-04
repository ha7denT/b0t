#if DEBUG
    import Foundation
    import os

    /// Process memory sampling for the Q6 validation harness. Programmatic
    /// (turnkey on-device) — Instruments remains the optional gold-standard
    /// cross-check (see `docs/specs/phase-2c-q6-model-lineup-validation.md` §5).
    enum MemoryProbe {
        /// Resident physical footprint of this process, in bytes. This is the
        /// number iOS's jetsam compares against the app's limit.
        static func physFootprint() -> UInt64 {
            var info = task_vm_info_data_t()
            var count = mach_msg_type_number_t(
                MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
            let kr = withUnsafeMutablePointer(to: &info) { ptr in
                ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                    task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
                }
            }
            return kr == KERN_SUCCESS ? UInt64(info.phys_footprint) : 0
        }

        /// Bytes still available to this process before the OS memory limit.
        /// iOS-only; returns 0 elsewhere.
        static func availableMemory() -> UInt64 {
            #if os(iOS)
                return UInt64(os_proc_available_memory())
            #else
                return 0
            #endif
        }

        static func mib(_ bytes: UInt64) -> String {
            String(format: "%.0f MiB", Double(bytes) / 1_048_576.0)
        }
    }
#endif
