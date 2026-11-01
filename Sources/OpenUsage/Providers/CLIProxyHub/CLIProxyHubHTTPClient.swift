import Foundation

/// An `HTTPClient` that sends every request as one hub account's `api-call`, so `ClaudeUsageClient`,
/// `CodexUsageClient` and their mappers run unchanged on top of a CLIProxyAPI hub. The request's own
/// `Authorization` is replaced by the hub's token placeholder, so no upstream token leaves the hub.
struct CLIProxyHubHTTPClient: HTTPClient {
    var hub: CLIProxyHubClient
    var authIndex: String

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        try await hub.apiCall(authIndex: authIndex, request: request)
    }
}
