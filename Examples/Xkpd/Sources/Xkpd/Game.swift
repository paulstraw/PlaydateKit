import PlaydateKit

// MARK: - Game

final class Game: PlaydateGame {
    // MARK: Lifecycle

    init() {
        Network.setEnabled(true, callback: Self.onNetEnabled)
    }

    // MARK: Internal

    static nonisolated(unsafe) let instance = Game()

    enum State {
        case initializingNetwork
        case initializingNetworkFailed(Network.NetErr)
        case waitingForNetworkAccess
        case networkAccessDenied
        case networkReady
    }

    func update() -> Bool {
        Graphics.clear(color: .white)
        switch state {
        case .initializingNetwork:
            drawStatus("Initializing network…")
        case .initializingNetworkFailed(let err):
            drawStatus("Initializing network failed: \(err.rawValue)")
        case .waitingForNetworkAccess:
            drawStatus("Waiting for network access…")
        case .networkAccessDenied:
            drawStatus("Network access denied")
        case .networkReady:
            if browser == nil {
                self.browser = ComicsBrowser()
            }

            browser.unsafelyUnwrapped.update()
        }

        return true
    }

    func gameWillPause() {
        guard let browser else {
            return
        }

        browser.onWillPause()
    }

    // MARK: Private

    private var netErr: Network.NetErr? = nil

    private var state: State = .initializingNetwork

    private var browser: ComicsBrowser? = nil

    private func drawStatus(_ text: String) {
        Graphics.drawMode = .fillBlack
        Graphics.setFont(Font.NicoBold16)
        Graphics.drawTextInRect(text, in: Rect(
            x: 0,
            y: 110,
            width: Display.width,
            height: 20,
        ), aligned: .center)
    }

    private func onNetEnabled(_ err: Network.NetErr) {
        switch err {
        case .ok:
            let reply = Network.HTTPConnection.requestAccess(
                server: "xkcd.com",
                port: 443,
                useSSL: true,
                purpose: "to load comics using the xkcd API.",
                callback: Self.onAccessResponse
            )

            switch reply {
            case .allow:
                state = .networkReady
            case .deny:
                state = .networkAccessDenied
            case .ask:
                state = .waitingForNetworkAccess
            @unknown default:
                System.error("Unknown access reply \(reply.rawValue)")
            }
        default:
            state = .initializingNetworkFailed(err)
        }
    }

    private func onAccessResponse(_ allowed: Bool) {
        state = allowed ? .networkReady : .networkAccessDenied
    }

    private static nonisolated(unsafe) let onNetEnabled: @convention(c) (_ err: Network.NetErr) -> Void = { err in
        instance.onNetEnabled(err)
    }

    private static nonisolated let onAccessResponse: @convention(c) (_ allowed: Bool, _ userdata: UnsafeMutableRawPointer?) -> Void = { allowed, userdata in
        instance.onAccessResponse(allowed)
    }
}
