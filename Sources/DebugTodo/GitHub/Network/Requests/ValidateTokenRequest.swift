import Foundation

struct ValidateTokenRequest: APIRequest {
    typealias Response = Data

    let token: String

    var url: String {
        "https://api.github.com/user"
    }

    var method: HTTPMethod {
        .get
    }

    var headers: [String: String] {
        [
            "Authorization": "Bearer \(token)",
            "Accept": "application/vnd.github+json"
        ]
    }
}
