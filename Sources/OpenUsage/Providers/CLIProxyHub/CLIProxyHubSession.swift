import Foundation

/// One hub, shared by all of its cards. It caps the `api-call`s in flight and shares a hub-wide
/// failure: every card whose refresh started before the failure was seen gets that same error
/// without calling the hub, so a refresh pass finds a down hub once per call slot, not once per card.
@MainActor
final class CLIProxyHubSession {
    static let maxConcurrentCalls = 4

    let hubID: String
    let client: CLIProxyHubClient

    private var inFlight = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    /// Bumped at each hub-wide failure, so a waiting call can tell whether one happened after it started.
    private var failureCount = 0
    private var hubFailure: (error: CLIProxyHubError, count: Int)?

    nonisolated init(hubID: String, client: CLIProxyHubClient) {
        self.hubID = hubID
        self.client = client
    }

    func apiCall(authIndex: String, request: HTTPRequest) async throws -> HTTPResponse {
        let startedAfter = failureCount
        await acquireSlot()
        defer { releaseSlot() }
        if let hubFailure, hubFailure.count > startedAfter {
            throw hubFailure.error
        }
        do {
            let response = try await client.apiCall(authIndex: authIndex, request: request)
            hubFailure = nil
            return response
        } catch let error as CLIProxyHubError where error.isHubWide {
            failureCount += 1
            hubFailure = (error, failureCount)
            throw error
        }
    }

    private func acquireSlot() async {
        guard inFlight >= Self.maxConcurrentCalls else {
            inFlight += 1
            return
        }
        await withCheckedContinuation { waiters.append($0) }
    }

    /// A waiting call takes over the freed slot directly, so `inFlight` never drops below the cap
    /// while calls are queued.
    private func releaseSlot() {
        if waiters.isEmpty {
            inFlight -= 1
        } else {
            waiters.removeFirst().resume()
        }
    }
}

extension CLIProxyHubError {
    /// Failures of the hub itself, which every account on it would hit. A management 4xx or an
    /// unreadable envelope may concern one account only, so it fails just that card.
    var isHubWide: Bool {
        switch self {
        case .unreachable, .timeout, .badKey, .accessDenied, .untrustedCertificate: true
        case .httpStatus(let status): status >= 500
        case .invalidResponse: false
        }
    }
}
