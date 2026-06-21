; Coin-Op AHK Listener
; Captures scanner input globally, parses JSON payload, focuses iRacing
; and types the player name into the focused field.
;
; Requires AutoHotkey v2 (https://www.autohotkey.com/)
;
; Edit IRACING_TITLE if your iRacing window title differs.

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

global IRACING_TITLE := "iRacing.com Simulator"
global NODE_LOG_URL  := "http://localhost:3000/api/session/start"
global SCANNER_RESET_MS := 120
global MIN_PAYLOAD_LEN  := 8

global gBuffer := ""
global gLastKeyTick := 0
global gFirstKeyTick := 0

; Hotkey-style global hook for visible characters and Enter.
; AHK ~ prefix means the key still passes through to the focused app.
~*Enter::OnEnter()

; Capture all printable characters into our buffer.
HookKey(key) {
    global
    now := A_TickCount
    if (now - gLastKeyTick > SCANNER_RESET_MS) {
        gBuffer := ""
        gFirstKeyTick := now
    }
    if (gFirstKeyTick = 0) {
        gFirstKeyTick := now
    }
    gLastKeyTick := now
    gBuffer .= key
}

; Build hotkeys for every printable ASCII character.
Loop 95 {
    c := Chr(32 + A_Index - 1)
    if (c = "") {
        continue
    }
    Hotkey "~*" c, HookCharFactory(c)
}

HookCharFactory(c) {
    return (*) => HookKey(c)
}

OnEnter(*) {
    global gBuffer
    payload := gBuffer
    gBuffer := ""
    if (StrLen(payload) < MIN_PAYLOAD_LEN) {
        return
    }
    ProcessPayload(payload)
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
