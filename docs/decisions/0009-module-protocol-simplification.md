# 0009 — `Module` protocol uses `[any Tool]` directly (no `ToolHandle` wrapper)

**Status:** Accepted
**Date:** 2026-05-04
**Deciders:** Jamee
**Supersedes:** PRD §5.3's original `Module` sketch where the protocol returned `[ToolHandle]`.

## Context

PRD §5.3 sketched the `Module` protocol with a `toolHandles: [ToolHandle]` field. The intent was to keep the model-facing tool surface decoupled from the FoundationModels SDK so future MCP transport could slot in.

During Phase 3 brainstorming on 2026-05-04, ADR-0008's "MCP in scope for Tools in v1" clause was settled as **architecture-only** (Q2): no wire protocol, no external server contact in v1; the architecture must stay compatible. With that lock in place, the question became whether `ToolHandle` was load-bearing.

Inspection: `FoundationModels.Tool` already encodes the MCP shape via `@Generable` (name, description, JSON-schema input via `@Generable Arguments`, JSON-encodable output via `@Generable Output`). A `ToolHandle` wrapper that holds the same fields would re-serialise on every call, with no new information.

## Decision

`Module.tools: [any Tool]` — no `ToolHandle` indirection. Concrete bridges conform to `FoundationModels.Tool` directly.

## Rationale

- `Tool` (from `FoundationModels`) is already MCP-shaped — `@Generable` macros derive the same JSON-schema-input / typed-output / name / description shape an MCP tool spec would carry. A wrapper would re-serialise without adding information.
- `Module` retains the user-facing role of "unit of distribution" (one `.md` file = one Module = one or more related Tools = one permission scope). That's the marketplace-compat seam ADR-0008 needs in v1, and it's preserved without `ToolHandle`.
- A future MCP-client transport (Phase 3.5+ or later) lands as a new `Tool`-conforming type that wraps a remote endpoint — `MCPRemoteTool: Tool`. The `Module` surface stays unchanged; the indirection happens inside the new Tool type, not in a wrapper.
- Phase 3 ships fewer abstractions: the `Module` protocol is two properties (`tools`, `requiredPermissions`) and one initialiser. Less surface to maintain, fewer naming conflicts, simpler tests.

## Consequences

- PRD §5.3's `Module` sketch is contradicted by code as of Phase 3. This ADR is the corrective record; §5.3 is otherwise treated as historical.
- `b0tModules` cannot represent a Module that produces non-`FoundationModels.Tool` outputs without expanding the protocol. If that becomes a need (e.g., a Module that emits structured MCP-only output before MCP transport lands), we add a method to the protocol then. YAGNI for v1.
- `ContextAssembler` reaches into the `[any Tool]` array via `as? PermissionAware` to detect permissioned tools. If a future tool type doesn't conform to `PermissionAware` but should, the dynamic-cast pattern stays correct (it returns `nil` and the tool is treated as non-permissioned).
- The `ToolCallRecord` type (`b0tBrain`) is independent of this decision — it's the runtime-observed *invocation*, not the *interface*, and remains useful regardless of how `Module` exposes tools.

## What this decision does not change

- ADR-0008's marketplace-compat clause: a Module remains a self-contained unit identified by `module_id`, instantiated via the registry's dispatch table, with explicit `requiredPermissions`. Adding new Modules in v2 still requires a Swift type plus a registry entry.
- The "Tool == MCP-shape" property: any `FoundationModels.Tool` is automatically MCP-compatible.
- `Module` stays a protocol (not a concrete struct or generic). Multiple Modules can implement it differently.

## When to revisit

- If MCP-client transport lands and the `Tool`-conformance approach for remote endpoints proves awkward (e.g., remote calls need streaming or chunked output that the synchronous `Tool.call(arguments:)` shape can't express), reconsider whether a more abstract `ToolHandle` would have been better.
- If marketplace-distribution moves to v1 (currently out of scope per ADR-0008), reconsider whether per-Module Swift types are still the right unit, or whether a runtime descriptor format would be more appropriate.
