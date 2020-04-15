import Foundation
import DcCore

class DcLogger: Logger {
    func verbose(_ message: String) {
        logger.verbose(message)
    }

    func debug(_ message: String) {
        logger.debug(message)
    }

    func info(_ message: String) {
        logger.info(message)
    }

    func warning(_ message: String) {
        logger.warning(message)
    }

    func error(_ message: String) {
        logger.error(message)
    }


}
