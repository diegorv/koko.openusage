import Foundation

/// One enabled Claude or Codex account held by a CLIProxyAPI hub, from `GET auth-files`. The Codex
/// fields are the hub's decoded `id_token` claims.
struct CLIProxyHubAccount: Codable, Equatable, Sendable {
    enum Provider: String, Codable, Sendable {
        case claude
        case codex
    }

    var id: String
    var authIndex: String
    var provider: Provider
    var email: String?
    var chatgptAccountID: String?
    var planType: String?
}

/// A hub failure. The copy never carries the management key, a body, or a header.
enum CLIProxyHubError: Error, LocalizedError, Equatable {
    case unreachable
    case timeout
    case httpStatus(Int)
    case badKey
    /// HTTP 403: the hub refuses management access with any key (remote management off, no key set
    /// on the hub, or this Mac's IP banned after failed attempts).
    case accessDenied
    case untrustedCertificate
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unreachable:
            "Can't reach the CLIProxyAPI hub. Check the hub URL and your connection."
        case .timeout:
            "The CLIProxyAPI hub didn't respond in time. Try again later."
        case .httpStatus(let status) where (400..<500).contains(status):
            "The CLIProxyAPI hub returned an error (HTTP \(status)). Check the hub URL, and that the account is signed in on the hub."
        case .httpStatus(let status):
            "The CLIProxyAPI hub returned an error (HTTP \(status)). Try again later."
        case .badKey:
            "The CLIProxyAPI hub rejected the management key. Check the key in Settings."
        case .accessDenied:
            "The CLIProxyAPI hub refused management access. Make sure remote management is enabled on the hub, or wait if this Mac was blocked after failed attempts."
        case .untrustedCertificate:
            "The CLIProxyAPI hub's certificate isn't trusted. Use a hub with a trusted certificate."
        case .invalidResponse:
            "The CLIProxyAPI hub sent a response OpenUsage can't read."
        }
    }
}

/// Talks to a CLIProxyAPI hub's management API (`<hubURL>/v0/management/<path>`). The hub holds the
/// upstream tokens; OpenUsage only ever sends the management key. Contract:
/// docs/research/cliproxy-hub-plan.md ("Hub contract").
struct CLIProxyHubClient: Sendable {
    static let requestTimeout: TimeInterval = 15
    /// The placeholder the hub swaps for the account's real access token.
    static let tokenPlaceholder = "Bearer $TOKEN$"

    var hubURL: URL
    var managementKey: String
    var http: any HTTPClient

    /// The default transport never logs hub bodies: an `api-call` body carries upstream payloads and a
    /// rejected-key body can echo the key.
    init(hubURL: URL, managementKey: String, http: any HTTPClient = URLSessionHTTPClient(logsErrorBodies: false)) {
        self.hubURL = hubURL
        self.managementKey = managementKey
        self.http = http
    }

    /// Appending path components keeps a hub served under a path prefix (`https://host/proxy`) on that
    /// prefix, with or without a trailing slash.
    func managementURL(_ path: String) -> URL {
        hubURL.appendingPathComponent("v0/management").appendingPathComponent(path)
    }

    /// The hub's enabled Claude and Codex accounts.
    func listAccounts() async throws -> [CLIProxyHubAccount] {
        let response = try await send(method: "GET", path: "auth-files", body: nil)
        guard let files = ProviderParse.jsonObject(response.body)?["files"] as? [[String: Any]] else {
            throw fail(.invalidResponse, path: "auth-files")
        }
        var accounts: [CLIProxyHubAccount] = []
        var unusable = 0
        for file in files {
            // The hub's disk-fallback listing emits `type` instead of `provider`.
            guard let provider = (file["provider"] as? String ?? file["type"] as? String)
                .flatMap({ CLIProxyHubAccount.Provider(rawValue: $0.lowercased()) }),
                  (file["disabled"] as? Bool) != true
            else { continue }
            guard let id = file["id"] as? String, let authIndex = Self.authIndex(file["auth_index"]) else {
                unusable += 1
                continue
            }
            let idToken = file["id_token"] as? [String: Any]
            accounts.append(CLIProxyHubAccount(
                id: id,
                authIndex: authIndex,
                provider: provider,
                email: file["email"] as? String,
                chatgptAccountID: idToken?["chatgpt_account_id"] as? String,
                planType: idToken?["plan_type"] as? String ?? idToken?["chatgpt_plan_type"] as? String
            ))
        }
        if unusable > 0 {
            AppLog.warn(.http, "cliproxy hub \(hubURL.host ?? "?") auth-files: skipped \(unusable) entries without id or auth_index")
        }
        return accounts
    }

    /// Sends `request` upstream through the hub as the account at `authIndex`, and returns the
    /// upstream response. A non-2xx upstream status is a normal response here: the caller's mapper
    /// decides what it means.
    func apiCall(authIndex: String, request: HTTPRequest) async throws -> HTTPResponse {
        var header = request.headers.filter { $0.key.lowercased() != "authorization" }
        header["Authorization"] = Self.tokenPlaceholder
        var payload: [String: Any] = [
            "auth_index": authIndex,
            "method": request.method,
            "url": request.url.absoluteString,
            "header": header
        ]
        // The hub takes the upstream payload as a JSON string, so the body is encoded twice.
        if let body = request.body {
            payload["data"] = String(decoding: body, as: UTF8.self)
        }
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])

        let response = try await send(method: "POST", path: "api-call", body: data)
        guard let envelope = ProviderParse.jsonObject(response.body),
              let statusCode = envelope["status_code"] as? Int,
              let body = Self.unwrapBody(envelope["body"])
        else {
            throw fail(.invalidResponse, path: "api-call")
        }
        return HTTPResponse(statusCode: statusCode, headers: Self.headers(envelope["header"]), body: body)
    }

    // MARK: - Transport

    private func send(method: String, path: String, body: Data?) async throws -> HTTPResponse {
        var headers = ["Authorization": "Bearer \(managementKey)", "Accept": "application/json"]
        if body != nil {
            headers["Content-Type"] = "application/json"
        }
        let response: HTTPResponse
        do {
            response = try await http.send(HTTPRequest(
                method: method, url: managementURL(path), headers: headers, body: body, timeout: Self.requestTimeout
            ))
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { throw error }
            throw fail(Self.transportError(error), path: path)
        }
        switch response.statusCode {
        case 200..<300: return response
        case 401: throw fail(.badKey, path: path)
        case 403: throw fail(.accessDenied, path: path)
        default: throw fail(.httpStatus(response.statusCode), path: path)
        }
    }

    /// Logs the failure by kind only: never the key, a body or a header.
    private func fail(_ error: CLIProxyHubError, path: String) -> CLIProxyHubError {
        AppLog.warn(.http, "cliproxy hub \(hubURL.host ?? "?") \(path) failed: \(error)")
        return error
    }

    private static func transportError(_ error: Error) -> CLIProxyHubError {
        guard let urlError = error as? URLError else { return .invalidResponse }
        switch urlError.code {
        case .timedOut:
            return .timeout
        case .serverCertificateUntrusted, .serverCertificateHasUnknownRoot, .serverCertificateHasBadDate,
             .serverCertificateNotYetValid, .secureConnectionFailed:
            return .untrustedCertificate
        default:
            return .unreachable
        }
    }

    // MARK: - Envelope decoding

    private static func authIndex(_ value: Any?) -> String? {
        if let text = value as? String, !text.isEmpty { return text }
        if let number = value as? Int { return String(number) }
        return nil
    }

    /// The envelope's `body` is normally the upstream payload as a JSON string. A string that is itself
    /// a JSON string literal (encoded once more) unwraps one more level, and an object body is accepted
    /// as-is.
    private static func unwrapBody(_ value: Any?) -> Data? {
        guard let value, !(value is NSNull) else { return Data() }
        if let text = value as? String {
            if let inner = try? JSONSerialization.jsonObject(with: Data(text.utf8), options: .fragmentsAllowed) as? String {
                return Data(inner.utf8)
            }
            return Data(text.utf8)
        }
        guard JSONSerialization.isValidJSONObject(value) else { return nil }
        return try? JSONSerialization.data(withJSONObject: value)
    }

    /// Header values arrive as a string or, from Go's `http.Header`, a string array. Keys are
    /// lowercased to match `HTTPResponse.header(_:)`.
    private static func headers(_ value: Any?) -> [String: String] {
        guard let raw = value as? [String: Any] else { return [:] }
        var headers: [String: String] = [:]
        for (name, value) in raw {
            if let text = value as? String {
                headers[name.lowercased()] = text
            } else if let list = value as? [String] {
                headers[name.lowercased()] = list.joined(separator: ", ")
            }
        }
        return headers
    }
}
