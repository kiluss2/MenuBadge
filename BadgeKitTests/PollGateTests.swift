import Testing
import BadgeKit

@Test func gateResumesOnlyWhenAllClear() {
    var gate = PollGate()
    #expect(gate.shouldPoll)
    #expect(gate.set(.screenLocked, true) == false)
    #expect(!gate.shouldPoll)
    #expect(gate.set(.screensAsleep, true) == false)
    #expect(gate.set(.screenLocked, false) == false)
    #expect(!gate.shouldPoll)
    #expect(gate.set(.screensAsleep, false) == true)
    #expect(gate.shouldPoll)
    #expect(gate.set(.sessionInactive, false) == false)
}
