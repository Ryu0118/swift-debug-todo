import Foundation

struct CreateIssueRequest: APIRequest {
    typealias Response = GitHubIssue

    let owner: String
    let repo: String
    let title: String
    let issueBody: String?
    let token: String

    var url: String {
        "https://api.github.com/repos/\(owner)/\(repo)/issues"
    }

    var method: HTTPMethod {
        .post
    }

    var headers: [String: String] {
        [
            "Authorization": "Bearer \(token)",
            "Accept": "application/vnd.github+json",
            "Content-Type": "application/json",
        ]
    }

    var body: (any RequestBody)? {
        JSONRequestBody(body: Body(title: title, body: issueBody))
    }

    func parseResponse(from data: Data, httpURLResponse: HTTPURLResponse) throws -> GitHubIssue {
        let decoder = JSONDecoder()
        return try decoder.decode(GitHubIssue.self, from: data)
    }
}

extension CreateIssueRequest {
    fileprivate struct Body: Codable, Sendable {
        let title: String
        let body: String?
    }
}
