import Foundation

/// Client for interacting with the GitHub API.
actor GitHubAPIClient {
    private var accessToken: String?
    private let httpClient: HTTPClient

    init() {
        httpClient = HTTPClient()
    }

    /// Sets the access token for API requests.
    ///
    /// - Parameter token: The GitHub access token.
    func setAccessToken(_ token: String?) {
        self.accessToken = token
    }

    /// Creates a new issue in the specified repository.
    ///
    /// - Parameters:
    ///   - owner: The repository owner (username or organization).
    ///   - repo: The repository name.
    ///   - title: The issue title.
    ///   - body: The issue body (optional).
    /// - Returns: The created GitHub issue.
    func createIssue(
        owner: String,
        repo: String,
        title: String,
        body: String? = nil
    ) async throws -> GitHubIssue {
        guard let token = accessToken else {
            throw GitHubAPIError.notAuthenticated
        }

        let request = CreateIssueRequest(
            owner: owner,
            repo: repo,
            title: title,
            issueBody: body,
            token: token
        )

        do {
            let (issue, response) = try await httpClient.send(for: request)

            // GitHub API expects 201 for successful creation
            guard response.statusCode == 201 else {
                throw GitHubAPIError.unknownError(
                    statusCode: response.statusCode,
                    message: "Unexpected status code"
                )
            }

            return issue
        } catch let error as NetworkError {
            throw mapNetworkError(error)
        }
    }

    /// Updates an issue's title, body, state, and state reason.
    ///
    /// - Parameters:
    ///   - owner: The repository owner (username or organization).
    ///   - repo: The repository name.
    ///   - issueNumber: The issue number.
    ///   - title: The new title (optional).
    ///   - body: The new body (optional).
    ///   - state: The new state ("open" or "closed", optional).
    ///   - stateReason: The reason for the state change (optional).
    /// - Returns: The updated GitHub issue.
    func updateIssue(
        owner: String,
        repo: String,
        issueNumber: Int,
        title: String? = nil,
        body: String? = nil,
        state: String? = nil,
        stateReason: String? = nil
    ) async throws -> GitHubIssue {
        guard let token = accessToken else {
            throw GitHubAPIError.notAuthenticated
        }

        let request = UpdateIssueRequest(
            owner: owner,
            repo: repo,
            issueNumber: issueNumber,
            title: title,
            issueBody: body,
            state: state,
            stateReason: stateReason,
            token: token
        )

        do {
            let (issue, _) = try await httpClient.send(for: request)
            return issue
        } catch let error as NetworkError {
            throw mapNetworkError(error)
        }
    }

    /// Validates the current access token.
    ///
    /// - Returns: `true` if the token is valid, `false` otherwise.
    func validateToken() async -> Bool {
        guard let token = accessToken else {
            return false
        }

        let request = ValidateTokenRequest(token: token)

        do {
            let (_, response) = try await httpClient.send(for: request)
            return response.statusCode == 200
        } catch {
            return false
        }
    }

    /// Maps NetworkError to GitHubAPIError
    private func mapNetworkError(_ error: NetworkError) -> GitHubAPIError {
        switch error {
        case .invalidResponse:
            return .invalidResponse
        case .unauthorized:
            return .unauthorized
        case .forbidden:
            return .forbidden
        case .notFound:
            return .repositoryNotFound
        case let .badRequest(_, data):
            if let errorResponse = try? JSONDecoder().decode(GitHubErrorResponse.self, from: data) {
                if errorResponse.message.contains("validation") {
                    return .validationFailed(errorResponse.message)
                }
            }
            return .unknownError(statusCode: 400, message: "Bad request")
        case let .otherClientError(statusCode, _, data):
            if statusCode == 422 {
                let errorResponse = try? JSONDecoder().decode(GitHubErrorResponse.self, from: data)
                return .validationFailed(errorResponse?.message ?? "Validation failed")
            }
            let errorResponse = try? JSONDecoder().decode(GitHubErrorResponse.self, from: data)
            return .unknownError(
                statusCode: statusCode,
                message: errorResponse?.message ?? "Unknown error"
            )
        case let .otherServerError(statusCode, _, data):
            let errorResponse = try? JSONDecoder().decode(GitHubErrorResponse.self, from: data)
            return .unknownError(
                statusCode: statusCode,
                message: errorResponse?.message ?? "Unknown error"
            )
        default:
            if let statusCode = error.statusCode {
                return .unknownError(statusCode: statusCode, message: error.localizedDescription)
            }
            return .unknownError(statusCode: 0, message: error.localizedDescription)
        }
    }
}

// MARK: - Error Response Model

private struct GitHubErrorResponse: Codable {
    let message: String
    let documentationUrl: String?

    enum CodingKeys: String, CodingKey {
        case message
        case documentationUrl = "documentation_url"
    }
}

// MARK: - Errors

/// Errors that can occur when interacting with the GitHub API.
public enum GitHubAPIError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case unauthorized
    case forbidden
    case repositoryNotFound
    case validationFailed(String)
    case unknownError(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated. Please sign in with GitHub."
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .unauthorized:
            return "Unauthorized. Please check your access token."
        case .forbidden:
            return "Forbidden. You don't have permission to perform this action."
        case .repositoryNotFound:
            return "Repository not found. Please check the owner and repository name."
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .unknownError(let statusCode, let message):
            return "GitHub API error (\(statusCode)): \(message)"
        }
    }
}
