The H1S isn't in the `elaxptr/baseus-desktop` supported list, and no one has documented its specific packet protocol yet. Here's the real picture and your best path forward:

---

## The Honest Situation for Bowie H1S

The H1S is an **over-ear headphone** (not earbuds), which means it almost certainly uses **Bluetooth Classic (A2DP/HFP/AVRCP)** for audio and a **BLE sidecar channel** for app-controlled features like EQ and ANC. No one has publicly reversed the H1S protocol yet — so you'll need to do it yourself. The good news is that it's a well-understood process and the tools are all free.

---

## Step-by-Step: Sniff the Protocol on Mac

### 1. Install PacketLogger (free, Apple tool)

This is the cleanest way to sniff BLE on Mac — no Android required.

```bash
# Download "Additional Tools for Xcode" from:
# https://developer.apple.com/download/all/?q=Additional+Tools
# PacketLogger is inside the Hardware folder
```

Open PacketLogger, connect your H1S to your iPhone/Mac, then trigger actions in the Baseus app (toggle ANC, change EQ) while the log is running. You'll see the raw bytes being written.

### 2. Alternatively: Use nRF Connect on Android

If you have an Android phone, this is even easier — no sniffing needed for initial GATT discovery:

- Install **nRF Connect** (free, Nordic Semiconductor)
- Connect to "Baseus Bowie H1s"
- It will show you all **Services** and **Characteristics** the headset exposes
- Screenshot/note the UUIDs — the custom 128-bit ones (not standard `0x180x`) are where the controls live

### 3. Capture the traffic

On Android: go to **Developer Options → Enable Bluetooth HCI snoop log**, reproduce actions in the Baseus app, then pull the log:

```bash
adb pull /data/misc/bluetooth/logs/btsnoop_hci.log
# Open in Wireshark, filter: btatt
```

Look for `Write Request` packets to custom UUIDs when you toggle ANC or change EQ in the app.

---

## What You're Looking For

You'll discover something like this (example pattern — actual bytes will differ):

```
Service:    0000xxxx-0000-1000-8000-00805f9b34fb  (vendor custom)
  Char UUID: 0000fff1-...  [Write Without Response]  ← command channel
  Char UUID: 0000fff4-...  [Notify]                  ← status/events

ANC off:          AA 05 00 01 00
ANC on:           AA 05 00 01 01  
Transparency:     AA 05 00 01 02
EQ Balanced:      AA 06 00 02 00
EQ Bass Boost:    AA 06 00 02 01
```

---

## Once You Have the Bytes: Python on Mac

```python
import asyncio
from bleak import BleakScanner, BleakClient

# Replace with actual UUIDs from your sniff
CMD_CHAR = "0000fff1-0000-1000-8000-00805f9b34fb"

COMMANDS = {
    "anc_off":        bytes([0xAA, 0x05, 0x00, 0x01, 0x00]),
    "anc_on":         bytes([0xAA, 0x05, 0x00, 0x01, 0x01]),
    "transparency":   bytes([0xAA, 0x05, 0x00, 0x01, 0x02]),
    "eq_balanced":    bytes([0xAA, 0x06, 0x00, 0x02, 0x00]),
    "eq_bass":        bytes([0xAA, 0x06, 0x00, 0x02, 0x01]),
}

async def send(command_name: str):
    device = await BleakScanner.find_device_by_name("Baseus Bowie H1s")
    async with BleakClient(device) as client:
        await client.write_gatt_char(CMD_CHAR, COMMANDS[command_name])
        print(f"Sent: {command_name}")

asyncio.run(send("anc_on"))
```

Install: `pip install bleak`

---

## Practical Checklist

1. **Install nRF Connect** on your phone → connect H1S → note all custom service/characteristic UUIDs
2. **Enable HCI snoop log** on Android → use Baseus app to trigger ANC + EQ changes → pull `btsnoop_hci.log`
3. **Open in Wireshark**, filter `btatt.opcode == 0x52` (Write Without Response) — these are your command bytes
4. Map byte patterns to actions
5. **Build the Python controller** on Mac with `bleak`

---

If you get as far as step 3 and paste the Wireshark output here, I can help you decode the packet structure and write the full Python controller for your Mac. That's usually where it gets tricky.
