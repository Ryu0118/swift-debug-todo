import Foundation

/// Errors that can occur during network requests
enum NetworkError: LocalizedError, Sendable {
    case convertStringToURLFailed
    case unknown
    case invalidResponse

    case redirectError(statusCode: Int, response: HTTPURLResponse, data: Data)

    case badRequest(response: HTTPURLResponse, data: Data)  // 400
    case unauthorized(response: HTTPURLResponse, data: Data)  // 401
    case forbidden(response: HTTPURLResponse, data: Data)  // 403
    case notFound(response: HTTPURLResponse, data: Data)  // 404
    case requestTimeout(response: HTTPURLResponse, data: Data)  // 408
    case conflict(response: HTTPURLResponse, data: Data)  // 409
    case otherClientError(statusCode: Int, response: HTTPURLResponse, data: Data)

    case internalServerError(response: HTTPURLResponse, data: Data)  // 500
    case badGateway(response: HTTPURLResponse, data: Data)  // 502
    case serviceUnavailable(response: HTTPURLResponse, data: Data)  // 503
    case gatewayTimeout(response: HTTPURLResponse, data: Data)  // 504
    case otherServerError(statusCode: Int, response: HTTPURLResponse, data: Data)

    case parseError(Error)

    var statusCode: Int? {
        switch self {
        case .redirectError(let statusCode, _, _):
            return statusCode
        case .badRequest(let response, _):
            return response.statusCode
        case .unauthorized(let response, _):
            return response.statusCode
        case .forbidden(let response, _):
            return response.statusCode
        case .notFound(let response, _):
            return response.statusCode
        case .requestTimeout(let response, _):
            return response.statusCode
        case .conflict(let response, _):
            return response.statusCode
        case .otherClientError(let statusCode, _, _):
            return statusCode
        case .internalServerError(let response, _):
            return response.statusCode
        case .badGateway(let response, _):
            return response.statusCode
        case .serviceUnavailable(let response, _):
            return response.statusCode
        case .gatewayTimeout(let response, _):
            return response.statusCode
        case .otherServerError(let statusCode, _, _):
            return statusCode
        default:
            return nil
        }
    }

    var errorDescription: String? {
        switch self {
        case .convertStringToURLFailed:
            return "内部でエラーが発生しました"
        case .unknown:
            return "不明なエラーが発生しました"
        case .invalidResponse:
            return "無効なレスポンスを受信しました"
        case .redirectError(let statusCode, _, _):
            return "リダイレクトエラー: ステータスコード \(statusCode)"
        case .badRequest:
            return "不正なリクエスト (400)"
        case .unauthorized:
            return "認証が必要です (401)"
        case .forbidden:
            return "アクセスが拒否されました (403)"
        case .notFound:
            return "リソースが見つかりません (404)"
        case .requestTimeout:
            return "リクエストがタイムアウトしました (408)"
        case .conflict:
            return "リソースの競合が発生しました (409)"
        case .otherClientError(let statusCode, _, _):
            return "クライアントエラー: ステータスコード \(statusCode)"
        case .internalServerError:
            return "サーバー内部エラー (500)"
        case .badGateway:
            return "不正なゲートウェイ (502)"
        case .serviceUnavailable:
            return "サービスが利用できません (503)"
        case .gatewayTimeout:
            return "ゲートウェイタイムアウト (504)"
        case .otherServerError(let statusCode, _, _):
            return "サーバーエラー: ステータスコード \(statusCode)"
        case .parseError(let error):
            return "データの解析に失敗しました: \(error.localizedDescription)"
        }
    }

    var responseData: Data? {
        switch self {
        case .redirectError(_, _, let data),
            .badRequest(_, let data),
            .unauthorized(_, let data),
            .forbidden(_, let data),
            .notFound(_, let data),
            .requestTimeout(_, let data),
            .conflict(_, let data),
            .otherClientError(_, _, let data),
            .internalServerError(_, let data),
            .badGateway(_, let data),
            .serviceUnavailable(_, let data),
            .gatewayTimeout(_, let data),
            .otherServerError(_, _, let data):
            return data
        default:
            return nil
        }
    }
}
