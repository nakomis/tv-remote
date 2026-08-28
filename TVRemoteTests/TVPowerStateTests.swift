import Testing
@testable import TVRemote

struct TVPowerStateTests {

    @Test("The states webOS actually reports are recognised", arguments: [
        ("Active", TVPowerState.active),
        ("Screen Off", TVPowerState.screenOff),
        ("Active Standby", TVPowerState.standby),
        ("Suspend", TVPowerState.suspend),
        ("Power Off", TVPowerState.off),
    ])
    func parsesReportedStates(_ reported: String, _ expected: TVPowerState) {
        #expect(TVPowerState(reported: reported) == expected)
    }

    @Test("Spacing and case in the reported string are irrelevant", arguments: [
        "screenoff", "Screen Off", "SCREEN OFF", "ScreenOff",
    ])
    func toleratesFormatting(_ reported: String) {
        #expect(TVPowerState(reported: reported) == .screenOff)
    }

    @Test("An unrecognised state is preserved, not collapsed to off")
    func unknownIsNotOff() {
        let state = TVPowerState(reported: "Warm Standby")
        #expect(state == .unknown("Warm Standby"))
        // The important half: a firmware update inventing a state must not
        // make the app decide the TV is off and drop a working connection.
        #expect(state.isAwake)
    }

    @Test("Screen off still counts as awake")
    func screenOffIsUsable() {
        // The TV still answers, and volume and inputs still work, which is
        // what someone holding a remote would expect.
        #expect(TVPowerState.screenOff.isAwake)
        #expect(TVPowerState.active.isAwake)
    }

    @Test("States on the way down do not count as awake")
    func goingDownIsNotAwake() {
        #expect(!TVPowerState.standby.isAwake)
        #expect(!TVPowerState.suspend.isAwake)
        #expect(!TVPowerState.off.isAwake)
    }

    @Test("Only states worth mentioning carry a note")
    func noteIsAbsentWhenOrdinary() {
        #expect(TVPowerState.active.note == nil)
        #expect(TVPowerState.screenOff.note == "screen off")
        #expect(TVPowerState.unknown("Warm Standby").note == "warm standby")
    }
}
