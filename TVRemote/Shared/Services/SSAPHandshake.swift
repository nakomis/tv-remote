import Foundation

/// The registration handshake webOS expects before it will accept commands.
///
/// The TV will not talk to an unregistered client. Registration sends a
/// manifest declaring which permissions the client wants; the TV puts a prompt
/// on screen, and once someone accepts it with the physical remote the TV
/// replies with a `client-key`. Storing that key and presenting it on
/// subsequent connections is what stops the prompt appearing every time.
///
/// The manifest below is the long-standing public one used by third-party
/// webOS remotes — the `signed` block and its signature are LG's own test
/// certificate, which every model accepts. It is not a secret and grants no
/// access beyond what the user approves on the prompt.
enum SSAPHandshake {

    static func registerPayload(clientKey: String?) -> [String: Any] {
        var payload: [String: Any] = [
            "forcePairing": false,
            "pairingType": "PROMPT",
            "manifest": manifest,
        ]
        if let clientKey, !clientKey.isEmpty {
            payload["client-key"] = clientKey
        }
        return payload
    }

    // Computed rather than stored: a stored `[String: Any]` is a mutable
    // global as far as the compiler is concerned, which Swift 6 rejects.
    private static var manifest: [String: Any] {[
        "manifestVersion": 1,
        "appVersion": "1.1",
        "signed": [
            "created": "20140509",
            "appId": "com.lge.test",
            "vendorId": "com.lge",
            "localizedAppNames": [
                "": "LG Remote App",
                "ko-KR": "리모컨 앱",
                "zxx-XX": "ЛГ Rэмotэ Aпp",
            ],
            "localizedVendorNames": ["": "LG Electronics"],
            "permissions": [
                "TEST_SECURE", "CONTROL_INPUT_TEXT", "CONTROL_MOUSE_AND_KEYBOARD",
                "READ_INSTALLED_APPS", "READ_LGE_SDX", "READ_NOTIFICATIONS",
                "SEARCH", "WRITE_SETTINGS", "WRITE_NOTIFICATION_ALERT",
                "CONTROL_POWER", "READ_CURRENT_CHANNEL", "READ_RUNNING_APPS",
                "READ_UPDATE_INFO", "UPDATE_FROM_REMOTE_APP",
                "READ_LGE_TV_INPUT_EVENTS", "READ_TV_CURRENT_TIME",
            ],
            "serial": "2f930e2d2cfe083771f68e4fe7bb07",
        ],
        "permissions": [
            "LAUNCH", "LAUNCH_WEBAPP", "APP_TO_APP", "CLOSE",
            "TEST_OPEN", "TEST_PROTECTED", "CONTROL_AUDIO",
            "CONTROL_DISPLAY", "CONTROL_INPUT_JOYSTICK",
            "CONTROL_INPUT_MEDIA_RECORDING", "CONTROL_INPUT_MEDIA_PLAYBACK",
            "CONTROL_INPUT_TV", "CONTROL_POWER", "READ_APP_STATUS",
            "READ_CURRENT_CHANNEL", "READ_INPUT_DEVICE_LIST",
            "READ_NETWORK_STATE", "READ_RUNNING_APPS", "READ_TV_CHANNEL_LIST",
            "WRITE_NOTIFICATION_TOAST", "READ_POWER_STATE", "READ_COUNTRY_INFO",
        ],
        "signatures": [[
            "signatureVersion": 1,
            "signature": "eyJhbGdvcml0aG0iOiJSU0EtU0hBMjU2Iiwia2V5SWQiOiJ0ZXN0LXNpZ25pbmctY2VydCIsInNpZ25hdHVyZVZlcnNpb24iOjF9.hrVRgjCwXVvE2OOSpDZ58hR+59aFNwYDyjQgKk3auukd7pcegmE2CzPCa0bJ0ZsRAcKkCTJrWo5iDzNhMBWRyaMOv5zWSrthlf7G128qvIlpMT0YNY+n/FaOHE73uLrS/g7swl3/qH/BGFG2Hu4RlL48eb3lLKqTt2xKHdCs6Cd4RMfJPYnzgvI4BNrFUKsjkcu+WD4OO2A27Pq1n50cMchmcaXadJhGrOqH5YmHdOCj5NSHzJYrsW0HPlpuAx/ECMeIZYDh6RMqaFM2DXzdKX9NmmyqzJ3o/0lkk/N97gfVRLW5hA29yeAwaCViZNCP8iC9aO0q9fQojoa7NQnAtw==",
        ]],
    ]}
}

/// The SSAP command URIs this app uses.
enum SSAP {
    static let turnOff = "ssap://system/turnOff"
    static let volumeUp = "ssap://audio/volumeUp"
    static let volumeDown = "ssap://audio/volumeDown"
    static let setVolume = "ssap://audio/setVolume"
    static let setMute = "ssap://audio/setMute"
    static let getVolume = "ssap://audio/getVolume"
    static let getExternalInputList = "ssap://tv/getExternalInputList"
    static let switchInput = "ssap://tv/switchInput"
    static let getForegroundAppInfo = "ssap://com.webos.applicationManager/getForegroundAppInfo"
}
