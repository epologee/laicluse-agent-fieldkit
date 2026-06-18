# Fixture: parallel orchestrations above a shared leaf

Anonymised reproduction of the duplication shape that drydry's eight
formulation prompts (as of v1.0.12) failed to catch on multiple audit
runs. Two entry points to the same domain action orchestrate their own
preflight stack before calling the same leaf; the orchestrations drift
in shape and discipline over time without either side noticing.

The bats test in this directory does not parse this file. It is here as
the reference example for the formulation prompt added in this commit,
so a future maintainer can re-read why the prompt exists.

## Shared leaf

```swift
enum SessionAction {
    static func beginSegments(/* ... */) async throws -> SessionResult {
        // The single network/database call that actually starts the
        // session. Both call sites below funnel into this.
    }
}
```

## Entry point A: AppIntent path

```swift
struct StartSessionIntentHelper {
    func executeStartSession(/* ... */) async throws -> IntentResult {
        let permits        = try await loadPermits()
        let plates         = try await loadPlates()
        let activeSessions = try await loadActiveSessions()
        try await cleanupOrphans(in: activeSessions)
        let schedule       = try await fetchSchedule()
        let plan           = computePlan(permits, plates, schedule)
        return try await SessionAction.beginSegments(plan: plan)
        // Auth is lazy: relies on a withSessionRetry wrapper to log in
        // when a 401 comes back from the leaf.
    }
}
```

## Entry point B: in-app accessory bar path

```swift
final class SessionEngine {
    func startResidentSession(/* ... */) async throws -> SessionResult {
        try await ensureLoggedIn()  // <-- eager auth, asymmetric with A
        try residentPermitGuard()
        try plateGuard()
        try scheduleGuard()
        let plan = computePlan(/* ... */)
        try await cleanupOrphans()  // <-- same step as A, different order
        return try await SessionAction.beginSegments(plan: plan)
    }
}
```

## Drift hypothesis (what breaks if these stay divergent)

A fix is applied in one orchestration and not the other. A new preflight
step appears in A but never propagates to B. The auth strategy
asymmetry between the two means that one entry point can surface a
"session expired" error to the user while the other silently retries
and succeeds. The leaf is shared, so a reader of the leaf sees no
duplication; the duplication lives one level up, in the stack of
domain steps every entry point happens to assemble for itself.

## Verifier signature

A single ripgrep against the shared leaf surfaces both call sites:

```
rg 'SessionAction\.beginSegments\b' path/to/scope/
```

Anything more than one hit inside the same domain action is a candidate
pair to read.
