; Coin-Op AHK Listener — COM Port (Calm/CDC Mode)
; Use this when the Eyoyo scanner is in CDC/Virtual COM port mode.
; Switch COM_PORT below to match Device Manager > Ports (COM & LPT).
;
; Requires AutoHotkey v2 (https://www.autohotkey.com/)

#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent

; --- Config ---
COM_PORT        := "COM3"       ; Change to match your scanner's COM port
BAUD_RATE       := 9600         ; Eyoyo CDC default — try 115200 if no data
IRACING_TITLE   := "iRacing.com Simulator"
NODE_LOG_URL    := "http://localhost:3000/api/session/start"
MIN_PAYLOAD_LEN := 8
; --------------

; Block duplicate instances.
if WinExist("Coin-Op COM Listener ahk_class AutoHotkey") {
    MsgBox "Coin-Op COM Listener is already running.`nCheck the system tray.", "Already Running", 48
    ExitApp
}

A_IconTip := "Coin-Op COM Listener"
TraySetIcon(A_AhkPath, 2)

DebugLog("Script started. Opening " . COM_PORT . " at " . BAUD_RATE . " baud.")
TrayTip "Coin-Op COM Listener", "Opening " . COM_PORT . "...", 1

port := OpenComPort(COM_PORT, BAUD_RATE)
if !port {
    MsgBox "Could not open " . COM_PORT . ".`n`nCheck Device Manager to confirm the port number, then edit COM_PORT at the top of this script.", "COM Port Error", 16
    ExitApp
}

TrayTip "Coin-Op COM Listener", COM_PORT . " open. Waiting for scan...", 1
DebugLog(COM_PORT . " opened successfully.")

; Poll the COM port every 50ms.
SetTimer () => ReadComPort(port), 50

; -------------------------------------------------------------------

OpenComPort(portName, baud) {
    try {
        comStr := portName . ":baud=" . baud . " parity=N data=8 stop=1"
        p := FileOpen(comStr, "rw `n")
        if !IsObject(p) {
            return false
        }
        return p
    } catch {
        return false
    }
}

global gComBuffer := ""

ReadComPort(port) {
    global gComBuffer
    try {
        while port.AtEOF != 1 {
            ch := port.Read(1)
            if (ch = "") {
                break
            }
            if (ch = "`n" || ch = "`r") {
                raw := Trim(gComBuffer)
                gComBuffer := ""
                if (StrLen(raw) >= MIN_PAYLOAD_LEN) {
                    DebugLog("Received: " . raw)
                    ToolTip "SCAN RECEIVED`nLength: " . StrLen(raw) . "`nData: " . SubStr(raw, 1, 80)
                    SetTimer () => ToolTip(), -4000
                    ProcessPayload(raw)
                } else if (StrLen(raw) > 0) {
                    DebugLog("Ignored (too short): " . raw)
                }
            } else {
                gComBuffer .= ch
            }
        }
    } catch as err {
        DebugLog("COM read error: " . err.Message)
    }
}

ProcessPayload(raw) {
    try {
        data := ParseJson(raw)
    } catch {
        DebugLog("JSON parse failed: " . raw)
        return
    }

    if !(data.Has("name") && data.Has("email") && data.Has("phone")) {
        DebugLog("Missing fields in payload.")
        return
    }

    LogToNode(data)
    SendToIRacing(data)
}

SendToIRacing(data) {
    global IRACING_TITLE
    if !WinExist(IRACING_TITLE) {
        TrayTip "Coin-Op COM Listener", "iRacing window not found.", 1
        DebugLog("iRacing window not found.")
        return
    }
    WinActivate IRACING_TITLE
    WinWaitActive IRACING_TITLE, , 2
    Sleep 250
    SendText data["name"]
    Send "{Tab}"
    Sleep 50
    SendText data["email"]
    Send "{Tab}"
    Sleep 50
    SendText data["phone"]
    Send "{Tab}"
    DebugLog("Fields sent to iRacing for: " . data["name"])
}

LogToNode(data) {
    global NODE_LOG_URL
    try {
        body := '{"name":"' . JsonEscape(data["name"]) . '","email":"' . JsonEscape(data["email"]) . '","phone":"' . JsonEscape(data["phone"]) . '"}'
        http := ComObject("WinHttp.WinHttpRequest.5.1")
        http.Open("POST", NODE_LOG_URL, true)
        http.SetRequestHeader("Content-Type", "application/json")
        http.Send(body)
    } catch {
        ; Logging is best-effort.
    }
}

JsonEscape(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    return s
}

ParseJson(text) {
    text := Trim(text)
    if (SubStr(text, 1, 1) != "{" || SubStr(text, -1) != "}") {
        throw Error("Not a JSON object")
    }
    inner := SubStr(text, 2, StrLen(text) - 2)
    result := Map()
    pos := 1
    while (pos <= StrLen(inner)) {
        kStart := InStr(inner, '"', , pos)
        if (kStart = 0)
            break
        kEnd := InStr(inner, '"', , kStart + 1)
        if (kEnd = 0)
            break
        key := SubStr(inner, kStart + 1, kEnd - kStart - 1)

        colon := InStr(inner, ":", , kEnd + 1)
        if (colon = 0)
            break
        vStart := InStr(inner, '"', , colon + 1)
        if (vStart = 0)
            break
        vEnd := InStr(inner, '"', , vStart + 1)
        if (vEnd = 0)
            break
        value := SubStr(inner, vStart + 1, vEnd - vStart - 1)
        result[key] := value
        pos := vEnd + 1
    }
    return result
}

DebugLog(msg) {
    logFile := A_ScriptDir . "\coin-op-comport-debug.log"
    stamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    FileAppend "[" . stamp . "] " . msg . "`n", logFile
}
