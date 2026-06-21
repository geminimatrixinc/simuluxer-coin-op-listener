# Coin-Op Simulator — iRacing AHK Setup (On-Site Reference)

This is the on-site reference for the AutoHotkey approach to auto-filling iRacing form fields
from a USB QR scanner. Use this when the kiosk web form is not viable (e.g. iRacing owns the
screen and you cannot inject a browser overlay).

---

## How It Works

```
USB QR Scanner (acts as keyboard)
        |
        v
 coin-op-listener.ahk  (runs in background, global keyboard hook)
        |
        +---> Parses JSON from QR payload
        |
        +---> POST /api/session/start  (logs session to logs/sessions.csv)
        |
        +---> Activates iRacing window, types name → Tab → email → Tab → phone → Tab
```

The AHK script runs silently in the system tray and intercepts all keyboard input system-wide,
so it works even when iRacing has focus.

---

## Prerequisites (install once on the simulator PC)

| Requirement | Notes |
|---|---|
| **Node.js** (v18+) | https://nodejs.org — needed for the session logging server |
| **AutoHotkey v2** | https://www.autohotkey.com — v2 only, not v1 |
| **Git** | To pull the repo |

Verify after install:
```
node -v
npm -v
```

---

## First-Time Setup on Simulator PC

```bat
cd C:\_GIT
git clone <your-repo-url> coin-op-simulator
cd coin-op-simulator
npm install
```

---

## Starting the Stack

### Option A — Everything at once (recommended)

Edit `scripts\launch-simulator-and-kiosk.bat` first:
```bat
set "SIMULATOR_BAT=C:\Path\To\iRacing\launcher.bat"   <- update this line
```

Then double-click or run:
```bat
scripts\launch-simulator-and-kiosk.bat
```

This starts iRacing, waits 10 seconds, then starts the kiosk listener server.

### Option B — Manual / step by step

**1. Start the Node session-logging server** (keeps session records in `logs/sessions.csv`):
```bat
scripts\start-kiosk.bat
```
Server runs at `http://localhost:3000`. Keep this window open.

**2. Start the AHK listener:**
```bat
scripts\ahk\start-listener-ahk.bat
```
A small AHK icon appears in the system tray. It is now listening for scanner input globally.

**3. Start iRacing normally** (or via `scripts\start-iracing.bat`).

---

## QR Code Payload Format

QR codes must encode a flat JSON string — no nested objects, no arrays:

```json
{"name":"Alex Mercer","email":"alex@arcade.com","phone":"5550199"}
```

The scanner must be in **USB HID keyboard emulation mode** with **Enter suffix enabled**
(this is the factory default for most fixed-mount scanners).

---

## What Happens on Scan

1. Scanner types the JSON string + Enter into the air (no window needs focus)
2. AHK captures the buffer, validates it is JSON with `name`, `email`, `phone`
3. AHK POSTs the payload to `http://localhost:3000/api/session/start` (logged to CSV)
4. AHK activates the iRacing window and types:
   - `name` field value
   - `Tab`
   - `email` field value
   - `Tab`
   - `phone` field value
   - `Tab` (moves off last field, triggers validation)

**iRacing's name field must be focused** when the scan fires. If it isn't, see
*Troubleshooting* below.

---

## Configuration (edit the .ahk file directly)

File: `scripts\ahk\coin-op-listener.ahk`

| Variable | Default | What to change |
|---|---|---|
| `IRACING_TITLE` | `"iRacing.com Simulator"` | Must match the exact iRacing window title |
| `NODE_LOG_URL` | `"http://localhost:3000/api/session/start"` | Change port if needed |
| `SCANNER_RESET_MS` | `120` | Max ms between keystrokes to count as one scan |
| `MIN_PAYLOAD_LEN` | `8` | Minimum chars to attempt parsing |

After editing, restart the AHK listener (right-click tray icon → Exit, then re-run the `.bat`).

---

## Inspecting iRacing Form Fields

To find exact window/control info for targeting specific fields:

**Window Spy (quickest — ships with AHK):**
1. Right-click the AHK tray icon → **Window Spy**
2. Hover over each iRacing form field
3. Note the `ahk_class`, `ahk_exe`, and pixel coordinates shown

**Diagnostic hotkey (built into the script):**
Run this one-off AHK snippet while iRacing is open to list all detectable controls:
```ahk
for ctrl in WinGetControls("iRacing.com Simulator")
    MsgBox ctrl
```
If the fields are named Edit controls, we can switch from pixel-coordinate clicks to
`ControlSetText` which is immune to window repositioning.

**Microsoft Inspect.exe** (Windows SDK):
- Hover over fields for full UIA accessibility tree — control names, automation IDs, classes.

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| AHK tray icon missing | Re-run `scripts\ahk\start-listener-ahk.bat`; check AHK v2 is installed |
| "iRacing window not found" tray tip | Verify `IRACING_TITLE` matches exactly — use Window Spy to confirm |
| Fields filled in wrong order | The name field was not focused when scan fired; click into name field first or add a `ControlFocus` call targeting the first field |
| Nothing happens on scan | Check strict scanner timing — scanner must type at ≥35 chars/sec. Use a real USB HID scanner, not manual keyboard |
| Session not logged to CSV | Confirm Node server is running (`http://localhost:3000/api/session/latest` should return JSON) |
| AHK found but wrong version | Script requires v2 — check `%ProgramFiles%\AutoHotkey\v2\` exists |

---

## File Map

```
coin-op-simulator\
├── server.js                          Node session-logging server (port 3000)
├── logs\sessions.csv                  Auto-created — all session records
├── public\
│   ├── index.html                     Web kiosk UI (alternative to AHK path)
│   └── app.js                         Web kiosk QR logic
└── scripts\
    ├── launch-simulator-and-kiosk.bat  Start everything (edit SIMULATOR_BAT first)
    ├── start-kiosk.bat                 Start Node server + browser kiosk only
    ├── start-kiosk.ps1                 PowerShell backing script for above
    ├── start-iracing.bat               Focus iRacing and send Enter
    └── ahk\
        ├── start-listener-ahk.bat      Launch the AHK listener
        └── coin-op-listener.ahk        Main AHK script — edit config here
```

---

## Pulling Updates on the Simulator PC

```bat
cd C:\_GIT\coin-op-simulator
git pull
npm install
```

Then restart the AHK listener and Node server.
