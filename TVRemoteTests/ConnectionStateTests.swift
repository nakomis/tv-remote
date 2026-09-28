import Testing
@testable import TVRemote

struct ConnectionStateTests {

    @Test("Only the connected state counts as connected")
    func isConnected() {
        #expect(ConnectionState.connected.isConnected)
        #expect(!ConnectionState.connecting.isConnected)
        #expect(!ConnectionState.pairing.isConnected)
        #expect(!ConnectionState.disconnected.isConnected)
        #expect(!ConnectionState.failed("nope").isConnected)
    }

    @Test("Connecting and pairing are the busy states")
    func isBusy() {
        #expect(ConnectionState.connecting.isBusy)
        #expect(ConnectionState.pairing.isBusy)
        #expect(!ConnectionState.connected.isBusy)
        #expect(!ConnectionState.disconnected.isBusy)
        #expect(!ConnectionState.failed("nope").isBusy)
    }

    @Test("A failure describes itself with its own reason")
    func failureCarriesReason() {
        #expect(ConnectionState.failed("The TV said no.").describedForHuman == "The TV said no.")
        #expect(ConnectionState.pairing.describedForHuman == "Accept the prompt on the TV")
    }

    @Test("A silent failure puts back the state from before the attempt")
    func silentFailureRestoresPreviousState() {
        // The background watcher: must stay retryable, never parked busy.
        #expect(ConnectionState.disconnected.afterSilentFailure == .disconnected)
        #expect(ConnectionState.failed("earlier").afterSilentFailure == .failed("earlier"))
        // powerOn's wake loop: keeps showing progress between attempts.
        #expect(ConnectionState.connecting.afterSilentFailure == .connecting)
    }

    @Test("A silent failure never leaves the app claiming a connection or a prompt")
    func silentFailureNeverClaimsConnectedOrPairing() {
        #expect(ConnectionState.connected.afterSilentFailure == .disconnected)
        #expect(ConnectionState.pairing.afterSilentFailure == .disconnected)
    }
}
