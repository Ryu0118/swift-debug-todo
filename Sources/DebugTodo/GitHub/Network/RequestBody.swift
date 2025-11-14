import Foundation

/// Protocol for request body types
protocol RequestBody: Sendable {
    var data: Data? { get }
}

/// JSON request body implementation
struct JSONRequestBody<Body: Encodable & Sendable>: RequestBody {
    let body: Body
    let data: Data?

    init(body: Body, encoder: JSONEncoder = JSONEncoder()) {
        self.body = body
        data = try? encoder.encode(body)
    }
}
