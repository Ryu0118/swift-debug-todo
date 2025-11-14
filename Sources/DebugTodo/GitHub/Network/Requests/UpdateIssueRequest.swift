import Foundation

struct UpdateIssueRequest: APIRequest {
    typealias Response = GitHubIssue

    let owner: String
    let repo: String
    let issueNumber: Int
    let title: String?
    let issueBody: String?
    let state: String?
    let stateReason: String?
    let token: String

    var url: String {
        "https://api.github.com/repos/\(owner)/\(repo)/issues/\(issueNumber)"
    }

    var method: HTTPMethod {
        .patch
    }

    var headers: [String: String] {
        [
            "Authorization": "Bearer \(token)",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
        ]
    }

    var body: (any RequestBody)? {
        JSONRequestBody(
            body: Body(
                title: title,
                body: issueBody,
                state: state,
                stateReason: stateReason
            ))
    }

    func parseResponse(from data: Data, httpURLResponse: HTTPURLResponse) throws -> GitHubIssue {
        let decoder = JSONDecoder()
        return try decoder.decode(GitHubIssue.self, from: data)
    }
}

extension UpdateIssueRequest {
    fileprivate struct Body: Codable, Sendable {
        let title: String?
        let body: String?
        let state: String?
        let stateReason: String?

        enum CodingKeys: String, CodingKey {
            case title
            case body
            case state
            case stateReason = "state_reason"
        }
    }
}
