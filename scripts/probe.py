#!/usr/bin/env python3
"""Probe a webOS television over SSAP.

A development aid, not part of the app. It performs the same registration
handshake the iOS app performs, then reports what the TV says about its
volume and its external inputs — which is how the app's assumptions about
payload shapes were checked against a real set.

    python3 scripts/probe.py [host]

The first run puts a pairing prompt on the TV; accept it with the physical
remote. The client key is cached in scripts/.client-key so later runs are
silent.

Read-only: it issues no commands that change anything. Note that webOS flashes
its on-screen volume bar whenever setVolume is called at all, even with the
value the TV is already at, so seeing the overlay does not mean the level moved.
"""
import asyncio, json, pathlib, ssl, sys
import websockets

HOST = sys.argv[1] if len(sys.argv) > 1 else "172.29.0.19"
KEY_FILE = pathlib.Path(__file__).parent / ".client-key"

MANIFEST = {
    "manifestVersion": 1,
    "appVersion": "1.1",
    "signed": {
        "created": "20140509",
        "appId": "com.lge.test",
        "vendorId": "com.lge",
        "localizedAppNames": {"": "LG Remote App"},
        "localizedVendorNames": {"": "LG Electronics"},
        "permissions": [
            "TEST_SECURE", "CONTROL_INPUT_TEXT", "CONTROL_MOUSE_AND_KEYBOARD",
            "READ_INSTALLED_APPS", "READ_LGE_SDX", "READ_NOTIFICATIONS", "SEARCH",
            "WRITE_SETTINGS", "WRITE_NOTIFICATION_ALERT", "CONTROL_POWER",
            "READ_CURRENT_CHANNEL", "READ_RUNNING_APPS", "READ_UPDATE_INFO",
            "UPDATE_FROM_REMOTE_APP", "READ_LGE_TV_INPUT_EVENTS", "READ_TV_CURRENT_TIME",
        ],
        "serial": "2f930e2d2cfe083771f68e4fe7bb07",
    },
    "permissions": [
        "LAUNCH", "LAUNCH_WEBAPP", "APP_TO_APP", "CLOSE", "TEST_OPEN",
        "TEST_PROTECTED", "CONTROL_AUDIO", "CONTROL_DISPLAY",
        "CONTROL_INPUT_JOYSTICK", "CONTROL_INPUT_MEDIA_RECORDING",
        "CONTROL_INPUT_MEDIA_PLAYBACK", "CONTROL_INPUT_TV", "CONTROL_POWER",
        "READ_APP_STATUS", "READ_CURRENT_CHANNEL", "READ_INPUT_DEVICE_LIST",
        "READ_NETWORK_STATE", "READ_RUNNING_APPS", "READ_TV_CHANNEL_LIST",
        "WRITE_NOTIFICATION_TOAST", "READ_POWER_STATE", "READ_COUNTRY_INFO",
    ],
    "signatures": [{
        "signatureVersion": 1,
        "signature": "eyJhbGdvcml0aG0iOiJSU0EtU0hBMjU2Iiwia2V5SWQiOiJ0ZXN0LXNpZ25pbmctY2VydCIsInNpZ25hdHVyZVZlcnNpb24iOjF9.hrVRgjCwXVvE2OOSpDZ58hR+59aFNwYDyjQgKk3auukd7pcegmE2CzPCa0bJ0ZsRAcKkCTJrWo5iDzNhMBWRyaMOv5zWSrthlf7G128qvIlpMT0YNY+n/FaOHE73uLrS/g7swl3/qH/BGFG2Hu4RlL48eb3lLKqTt2xKHdCs6Cd4RMfJPYnzgvI4BNrFUKsjkcu+WD4OO2A27Pq1n50cMchmcaXadJhGrOqH5YmHdOCj5NSHzJYrsW0HPlpuAx/ECMeIZYDh6RMqaFM2DXzdKX9NmmyqzJ3o/0lkk/N97gfVRLW5hA29yeAwaCViZNCP8iC9aO0q9fQojoa7NQnAtw==",
    }],
}


async def main():
    stored = KEY_FILE.read_text().strip() if KEY_FILE.exists() else None
    # webOS 23 refuses plaintext on 3000: it accepts the TCP connection then
    # closes it without an HTTP response. Port 3001 is TLS with a self-signed
    # certificate, so verification has to be off.
    uri = f"wss://{HOST}:3001"
    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE
    print(f"→ connecting to {uri}")

    async with websockets.connect(uri, ssl=context, max_size=None) as ws:
        payload = {"forcePairing": False, "pairingType": "PROMPT", "manifest": MANIFEST}
        if stored:
            payload["client-key"] = stored
        await ws.send(json.dumps({"type": "register", "id": "register_0", "payload": payload}))

        key = None
        while key is None:
            message = json.loads(await asyncio.wait_for(ws.recv(), timeout=90))
            if message.get("type") == "error":
                print("✗ registration error:", message.get("error"))
                return
            body = message.get("payload", {})
            if "client-key" in body:
                key = body["client-key"]
            elif body.get("pairingType"):
                print("… accept the prompt on the TV with the physical remote")

        KEY_FILE.write_text(key)
        print(f"✓ registered (client key cached in {KEY_FILE.name})")

        counter = [0]

        async def ask(uri_, payload_=None):
            counter[0] += 1
            request_id = f"req_{counter[0]}"
            frame = {"type": "request", "id": request_id, "uri": uri_}
            if payload_:
                frame["payload"] = payload_
            await ws.send(json.dumps(frame))
            while True:
                reply = json.loads(await asyncio.wait_for(ws.recv(), timeout=10))
                if reply.get("id") == request_id:
                    return reply

        for label, uri_ in [
            ("volume", "ssap://audio/getVolume"),
            ("inputs", "ssap://tv/getExternalInputList"),
            ("foreground app", "ssap://com.webos.applicationManager/getForegroundAppInfo"),
        ]:
            reply = await ask(uri_)
            print(f"\n=== {label} ({uri_}) ===")
            print(json.dumps(reply.get("payload", {}), indent=2)[:2000])


if __name__ == "__main__":
    asyncio.run(main())
