import Foundation

/// An `HTTPClient` that sends every request as one hub account's `api-call`, so `ClaudeUsageClient`,
/// `CodexUsageClient` and their mappers run unchanged on top of a CLIProxyAPI hub. The request's own
/// `Authorization` is replaced by the hub's token placeholder, so no upstream token leaves the hub.
/// Calls go through the hub's shared session, which caps them and shares hub-wide failures.
struct CLIProxyHubHTTPClient: HTTPClient {
    let session: CLIProxyHubSession
    let authIndex: String

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        try await session.apiCall(authIndex: authIndex, request: request)
    }
}
