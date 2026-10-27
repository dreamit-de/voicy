import XCTest
@testable import Voicy

final class MicrophoneSelectionTests: XCTestCase {
    private let builtIn = AudioInputDevice(uid: "BuiltInMicrophoneDevice", name: "MacBook Pro-Mikrofon", deviceID: 10)
    private let airPods = AudioInputDevice(uid: "AA-BB-CC:input", name: "AirPods Pro", deviceID: 42)
    private let usb = AudioInputDevice(uid: "AppleUSBAudioEngine:Rode:NT-USB", name: "NT-USB", deviceID: 77)

    func test_noChoice_followsSystemDefault() {
        let result = MicrophoneSelection.resolve(
            preferredUID: nil,
            devices: [builtIn, airPods],
            systemDefaultUID: airPods.uid
        )
        XCTAssertEqual(result, .systemDefault(airPods))
        XCTAssertEqual(result.device, airPods)
        XCTAssertFalse(result.isFallback)
    }

    func test_emptyChoice_isTreatedAsSystemDefault() {
        let result = MicrophoneSelection.resolve(
            preferredUID: "",
            devices: [builtIn],
            systemDefaultUID: builtIn.uid
        )
        XCTAssertEqual(result, .systemDefault(builtIn))
    }

    /// The bug this feature fixes: AirPods became the macOS default, but the
    /// user pinned the USB mic — the pinned device must win.
    func test_connectedChoice_winsOverSystemDefault() {
        let result = MicrophoneSelection.resolve(
            preferredUID: usb.uid,
            devices: [builtIn, airPods, usb],
            systemDefaultUID: airPods.uid
        )
        XCTAssertEqual(result, .chosen(usb))
        XCTAssertEqual(result.device, usb)
        XCTAssertFalse(result.isFallback)
    }

    func test_disconnectedChoice_fallsBackVisiblyToSystemDefault() {
        let result = MicrophoneSelection.resolve(
            preferredUID: usb.uid,
            devices: [builtIn, airPods],
            systemDefaultUID: builtIn.uid
        )
        XCTAssertEqual(result, .fallback(missingUID: usb.uid, systemDefault: builtIn))
        XCTAssertEqual(result.device, builtIn)
        XCTAssertTrue(result.isFallback)
    }

    func test_matchesByUID_notByName() {
        let renamed = AudioInputDevice(uid: usb.uid, name: "Podcast-Mikro", deviceID: 99)
        let result = MicrophoneSelection.resolve(
            preferredUID: usb.uid,
            devices: [builtIn, renamed],
            systemDefaultUID: builtIn.uid
        )
        XCTAssertEqual(result.device?.name, "Podcast-Mikro")
        XCTAssertEqual(result.device?.deviceID, 99)
    }

    func test_noDevices_resolvesToNoDevice() {
        XCTAssertNil(MicrophoneSelection.resolve(preferredUID: nil, devices: [], systemDefaultUID: nil).device)
        let fallback = MicrophoneSelection.resolve(preferredUID: usb.uid, devices: [], systemDefaultUID: nil)
        XCTAssertEqual(fallback, .fallback(missingUID: usb.uid, systemDefault: nil))
        XCTAssertNil(fallback.device)
    }

    /// A default UID that is not in the list (e.g. a device without input
    /// streams, or a race during reconnect) yields no device rather than a
    /// guess — the recorder then reports "Kein Mikrofon verfügbar".
    func test_unknownSystemDefault_yieldsNoDevice() {
        let result = MicrophoneSelection.resolve(
            preferredUID: nil,
            devices: [builtIn],
            systemDefaultUID: "Unknown"
        )
        XCTAssertEqual(result, .systemDefault(nil))
    }
}
