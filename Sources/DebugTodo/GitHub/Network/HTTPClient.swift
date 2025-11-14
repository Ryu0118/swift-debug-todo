import Foundation

/// HTTP client for making network requests
struct HTTPClient: Sendable {
    let session: URLSession

    init(configuration: URLSessionConfiguration = .default) {
        let memoryCapacity = 10_485_760 // 10 MB
        let diskCapacity = 52_428_800 // 50 MB
        let urlCache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity, diskPath: nil)

        configuration.urlCache = urlCache
        configuration.requestCachePolicy = .useProtocolCachePolicy

        session = URLSession(configuration: configuration)
    }

    @discardableResult
    func send<Request: APIRequest>(for request: Request) async throws -> (Request.Response, HTTPURLResponse) {
        let urlRequest = try request.buildURLRequest()

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        // ステータスコードに基づいてエラーを処理
        switch httpResponse.statusCode {
        case 200 ... 299:
            do {
                let parsedData = try request.parseResponse(from: data, httpURLResponse: httpResponse)
                return (parsedData, httpResponse)
            } catch {
                throw NetworkError.parseError(error)
            }
        case 300 ... 399:
            throw NetworkError.redirectError(statusCode: httpResponse.statusCode, response: httpResponse, data: data)
        case 400:
            throw NetworkError.badRequest(response: httpResponse, data: data)
        case 401:
            throw NetworkError.unauthorized(response: httpResponse, data: data)
        case 403:
            throw NetworkError.forbidden(response: httpResponse, data: data)
        case 404:
            throw NetworkError.notFound(response: httpResponse, data: data)
        case 408:
            throw NetworkError.requestTimeout(response: httpResponse, data: data)
        case 409:
            throw NetworkError.conflict(response: httpResponse, data: data)
        case 400 ... 499:
            throw NetworkError.otherClientError(statusCode: httpResponse.statusCode, response: httpResponse, data: data)
        case 500:
            throw NetworkError.internalServerError(response: httpResponse, data: data)
        case 502:
            throw NetworkError.badGateway(response: httpResponse, data: data)
        case 503:
            throw NetworkError.serviceUnavailable(response: httpResponse, data: data)
        case 504:
            throw NetworkError.gatewayTimeout(response: httpResponse, data: data)
        case 500 ... 599:
            throw NetworkError.otherServerError(statusCode: httpResponse.statusCode, response: httpResponse, data: data)
        default:
            throw NetworkError.unknown
        }
    }
}
