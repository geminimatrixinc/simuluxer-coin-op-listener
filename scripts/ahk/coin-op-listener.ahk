; Coin-Op AHK Listener
; Captures scanner input globally, parses JSON payload, focuses iRacing
; and types the player name into the focused field.
;
; Requires AutoHotkey v2 (https://www.autohotkey.com/)
;
; Edit IRACING_TITLE if your iRacing window title differs.

#Requires AutoHotkey v2.0
#SingleInstance Off
Persistent

if !A_IsAdmin {
    ; Re-launch as admin so the hook works over elevated windows like iRacing.
}

; Exit if this script is already running.
if WinExist("Coin-Op Listener ahk_class AutoHotkey") {
    MsgBox "Coin-Op Listener is already running.`nCheck the system tray.", "Already Running", 48
    ExitApp
}

A_TrayMenu.Delete()
TraySetIcon(A_AhkPath, 2)
A_IconTip := "Coin-Op Listener"

global IRACING_TITLE := "iRacing.com Simulator"
global NODE_LOG_URL  := "http://localhost:3000/api/session/start"
global SCANNER_RESET_MS := 120
global MIN_PAYLOAD_LEN  := 8

; Wait for "{" — the start of our JSON payload — then capture the rest.
; This means the hook is idle (not running) until a scan actually begins,
; so normal keyboard use is never affected.
~*{::
{
    ih := InputHook("V T1 L1024")
    ih.KeyOpt("{Enter}", "E")
    ih.Start()
    ih.Wait()
    raw := "{" . ih.Input
    reason := ih.EndReason
    DebugLog("OnScanEnd reason=" . reason . " len=" . StrLen(raw) . " raw=" . raw)
    ToolTip "SCAN CAPTURED`nReason: " . reason . "`nLength: " . StrLen(raw) . "`nData: " . SubStr(raw, 1, 80)
    SetTimer () => ToolTip(), -4000
    if (StrLen(raw) < MIN_PAYLOAD_LEN) {
        DebugLog("Rejected: too short (" . StrLen(raw) . " chars)")
        return
    }
    ProcessPayload(raw)
}

DebugLog(msg) {
    logFile := A_ScriptDir . "\coin-op-debug.log"
    stamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    FileAppend "[" . stamp . "] " . msg . "`n", logFile
}

ProcessPayload(raw) {
    try {
        data := ParseJson(raw)
    } catch {
        ; Not JSON, ignore.
        return
    }

    if !(data.Has("name") && data.Has("email") && data.Has("phone")) {
        return
    }

    LogToNode(data)
    SendToIRacing(data)
}

SendToIRacing(data) {
    global IRACING_TITLE
    if !WinExist(IRACING_TITLE) {
        TrayTip "Coin-Op Listener", "iRacing window not found.", 1
        DebugLog("iRacing window not found.")
        return
    }

    ; Split "First Last" into two parts on the first space.
    fullName := data["name"]
    spacePos := InStr(fullName, " ")
    if (spacePos > 0) {
        firstName := SubStr(fullName, 1, spacePos - 1)
        lastName  := SubStr(fullName, spacePos + 1)
    } else {
        firstName := fullName
        lastName  := ""
    }

    WinActivate IRACING_TITLE
    WinWaitActive IRACING_TITLE, , 2
    Sleep 500

    ; Clear and fill first name.
    Send "^a"
    Send "{Delete}"
    SendText firstName
    Send "{Tab}"
    Sleep 2000

    ; Clear and fill last name.
    Send "^a"
    Send "{Delete}"
    SendText lastName
    Send "{Tab}"
    Sleep 2000

    ; Clear and fill email.
    Send "^a"
    Send "{Delete}"
    SendText data["email"]

    ; Pause so the user can review all fields before submitting.
    Sleep 5000
    Send "{Tab}"
    Sleep 50
    Send "{Enter}"
    DebugLog("Fields sent — First: " . firstName . " Last: " . lastName . " Email: " . data["email"])
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

; Minimal JSON parser sufficient for flat {"name":"..","email":"..","phone":".."} payloads.
ParseJson(text) {
    text := Trim(text)
    if (SubStr(text, 1, 1) != "{" || SubStr(text, -1) != "}") {
        throw Error("Not a JSON object")
    }
    inner := SubStr(text, 2, StrLen(text) - 2)
    result := Map()
    pos := 1
    while (pos <= StrLen(inner)) {
        ; Find key opening quote.
        kStart := InStr(inner, '"', , pos)
        if (kStart = 0) {
            break
        }
        kEnd := InStr(inner, '"', , kStart + 1)
        if (kEnd = 0) {
            break
        }
        key := SubStr(inner, kStart + 1, kEnd - kStart - 1)

        ; Find colon then value opening quote.
        colon := InStr(inner, ":", , kEnd + 1)
        if (colon = 0) {
            break
        }
        vStart := InStr(inner, '"', , colon + 1)
        if (vStart = 0) {
            break
        }
        vEnd := InStr(inner, '"', , vStart + 1)
        if (vEnd = 0) {
            break
        }
        value := SubStr(inner, vStart + 1, vEnd - vStart - 1)
        result[key] := value

        pos := vEnd + 1
    }
    return result
}
