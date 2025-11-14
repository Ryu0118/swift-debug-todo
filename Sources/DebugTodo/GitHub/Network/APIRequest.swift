import Foundation

/// Protocol defining an API request
protocol APIRequest: Sendable {
    associatedtype Response: Sendable = Data

    var url: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: (any RequestBody)? { get }

    func parseResponse(from data: Data, httpURLResponse: HTTPURLResponse) throws -> Response
}

extension APIRequest {
    var queryItems: [URLQueryItem] {
        []
    }

    var headers: [String: String] {
        [:]
    }

    var body: (any RequestBody)? {
        nil
    }
}

extension APIRequest where Response == Data {
    func parseResponse(from data: Data, httpURLResponse _: HTTPURLResponse) throws -> Response {
        data
    }
}

extension APIRequest {
    func buildURLRequest() throws -> URLRequest {
        guard var url = URL(string: url) else {
            throw NetworkError.convertStringToURLFailed
        }

        if !queryItems.isEmpty {
            url.append(queryItems: queryItems)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body {
            request.httpBody = body.data
        }

        return request
    }
}
