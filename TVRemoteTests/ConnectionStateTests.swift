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
}
