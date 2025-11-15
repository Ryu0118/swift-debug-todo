import Foundation

struct GetIssueRequest: APIRequest {
    typealias Response = GitHubIssue

    let owner: String
    let repo: String
    let issueNumber: Int
    let token: String

    var url: String {
        "https://api.github.com/repos/\(owner)/\(repo)/issues/\(issueNumber)"
    }

    var method: HTTPMethod {
        .get
    }

    var headers: [String: String] {
        [
            "Authorization": "Bearer \(token)",
            "Accept": "application/vnd.github+json",
        ]
    }

    var body: (any RequestBody)? {
        nil
    }

    func parseResponse(from data: Data, httpURLResponse: HTTPURLResponse) throws -> GitHubIssue {
        let decoder = JSONDecoder()
        return try decoder.decode(GitHubIssue.self, from: data)
    }
}
