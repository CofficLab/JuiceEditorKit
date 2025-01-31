import Foundation
import Vapor
import OSLog

public extension HTTPServer {
    func chat(app: Application) {
        app.post("api", "chat") { req async throws -> Response in
            struct ChatRequest: Content {
                let text: String
            }

            let req = try req.content.decode(ChatRequest.self)

            os_log("\(self.t)Chat request -> \(req.text)")

            return Response(
                status: .ok,
                headers: [
                    "Content-Type": "text/event-stream",
                    "Cache-Control": "no-cache",
                    "Connection": "keep-alive",
                ],
                body: .init(stream: { writer in
                    Task {
                        do {
                            try await self.delegate.chat(req.text) { chunk in
                                let data = chunk.data(using: .utf8)!
                                writer.write(.buffer(.init(data: data)))
                            }
                            writer.write(.end)
                        } catch {
                            writer.write(.error(error))
                        }
                    }
                })
            )
        }
    }
}
