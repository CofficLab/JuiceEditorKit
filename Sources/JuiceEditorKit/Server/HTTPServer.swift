import Foundation
import MagicKit
import NIOCore
import os
import SwiftUI
import Vapor

public class HTTPServer: ObservableObject, SuperLog, SuperThread {
    let emoji = "📺"

    public var app: Application?
    public let directoryPath: String
    public let isDevMode = false
    public var port: Int = 49493
    public let vueDevServerURL = "http://localhost:5173"
    public var delegate: EditorDelegate
    public var translateApiURL: String = ""
    public var drawIoLink: String = ""

    @Published public var isRunning: Bool = false

    var baseURL: URL { URL(string: "http://localhost:\(port)")! }

    public let logger = Config.makeLogger("HttpServer")

    public init(directoryPath: String, delegate: EditorDelegate) {
        self.directoryPath = directoryPath
        self.delegate = delegate
    }

    private func configureRoutes(app: Application) throws {
        if isDevMode {
            self.dev(app: app)
        } else {
            self.prod(app: app)
        }

        self.getNode(app: app)
        self.translate(app: app)
    }

    public func start() throws {
        let verbose = true
        var currentPort = port
        var serverStarted = false

        while !serverStarted && currentPort < port + 100 { // Try 100 ports
            do {
                self.app = Application(.production)

                guard let app = self.app else {
                    throw HTTPServerError.appNotInitialized
                }

                app.logger.logLevel = .critical
                app.environment.arguments = ["vapor"]

                try configureRoutes(app: app)

                app.http.server.configuration.port = currentPort

                try app.start()
                serverStarted = true

                self.main.async {
                    self.port = currentPort
                    self.translateApiURL = self.baseURL.absoluteString + "/api/translate"
                    self.drawIoLink = self.baseURL.absoluteString + "/draw/index.html?"
                    self.emitStarted()
                    self.isRunning = true
                }

                os_log("\(self.t)Server started on port \(currentPort) 🎉🎉🎉")
            } catch let error as NIOCore.IOError where error.errnoCode == EADDRINUSE {
                logger.warning("\(self.t)Port \(currentPort) is in use, trying next port")
                currentPort += 1
                self.app?.shutdown()
                self.app = nil
            } catch {
                logger.error("\(self.t)Unexpected error: \(error.localizedDescription)")
                logger.error("\(self.t)Error type: \(type(of: error))")
                logger.error("\(self.t)Error details: \(String(describing: error))")
                throw error
            }
        }

        if !serverStarted {
            throw HTTPServerError.noAvailablePort
        }
    }

    public func run() throws {
        try app?.run()
    }

    deinit {
        app?.shutdown()
        self.isRunning = false // Set isRunning to false when server shuts down
    }

    public func startServer() {
        Task {
            do {
                try await self.startAsync()
                self.main.async {
                    self.isRunning = true
                }
            } catch {
                self.main.async {
                    self.isRunning = false
                }
            }
        }
    }

    private func startAsync() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                try self.start()
                continuation.resume()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum HTTPServerError: Error {
    case noAvailablePort
    case appNotInitialized
}

// MARK: Event Name

extension Notification.Name {
    static let httpServerStarted = Notification.Name("httpServerStarted")
}

// MARK: Emitter

extension HTTPServer {
    public func emitStarted() {
        NotificationCenter.default.post(name: .httpServerStarted, object: nil)
    }
}
