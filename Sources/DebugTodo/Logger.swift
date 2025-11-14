import Logging

@MainActor
package var logger = Logger(label: "com.debugtodo")

@MainActor
private var isBootstrapped = false

/// Bootstraps the logging system with StreamLogHandler.
/// This should be called once at application startup.
/// - Parameter logLevel: The log level to use. Defaults to .info in release builds and .debug in debug builds.
@MainActor
public func bootstrapLogging(logLevel: Logger.Level? = nil) {
    guard !isBootstrapped else {
        logger.warning("Logging system already bootstrapped. Ignoring subsequent call.")
        return
    }

    LoggingSystem.bootstrap { label in
        if let logLevel {
            var handler = StreamLogHandler.standardOutput(label: label)
            handler.logLevel = logLevel
            return handler
        } else {
            return SwiftLogNoOpLogHandler()
        }
    }

    isBootstrapped = true

    logger = Logger(label: "com.debugtodo")
}

/// Sets the log level for the package logger.
/// - Parameter logLevel: The log level to set.
@MainActor
public func setLogLevel(_ logLevel: Logger.Level) {
    logger.logLevel = logLevel
}
