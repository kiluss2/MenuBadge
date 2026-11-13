import Testing
import BadgeKit

@Test func singleBlinkShape() {
    let k = AnimationCurves.blink(close: 0.08, open: 0.15, double: false)
    #expect(k.map(\.value) == [1, 0.1, 0.1, 1])
    #expect(abs(k.last!.time - 0.26) < 1e-9)
    #expect(zip(k, k.dropFirst()).allSatisfy { $0.time < $1.time })
}

@Test func doubleBlinkHasTwoClosures() {
    let k = AnimationCurves.blink(close: 0.08, open: 0.15, double: true)
    #expect(k.filter { $0.value == 0.1 }.count == 4)
    #expect(k.count == 8 && k.last!.value == 1)
    #expect(zip(k, k.dropFirst()).allSatisfy { $0.time < $1.time })
}

@Test func idlePauseMatchesTheNaturalBlink() {
    #expect(AnimationCurves.idlePause == 2.5...4)
    #expect(AnimationCurves.doubleBlinkChance == 0.25)
}
