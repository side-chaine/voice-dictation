#Requires AutoHotkey v2.0
#SingleInstance Force

LOGF := "C:\Users\nikit\dictate.log"
WSL_OUT := "\\wsl.localhost\Ubuntu\tmp\dictate_out.txt"
WSL_DONE := "\\wsl.localhost\Ubuntu\tmp\dictate_out.done"
WSL := "wsl.exe -d Ubuntu -e /home/nikit/.local/bin/dictate-record.sh"
isRecording := false
isProcessing := false

Dbg(msg) {
    FileAppend(A_Now " | " msg "`n", LOGF)
}

TrayTip("Диктовка", "Скрипт запущен", 1)
Dbg("script started")

*RAlt:: {
    global isRecording, isProcessing
    if (isRecording || isProcessing)
        return
    isRecording := true
    Dbg("RAlt DOWN")
    try {
        Run(WSL " start", , "Hide")
        Dbg("start launched")
    } catch as e {
        Dbg("start ERROR: " e.Message)
    }
    ToolTip("Запись...")
    SoundBeep(880, 120)
    SetTimer(() => ToolTip(), -1500)
}

*RAlt up:: {
    global isRecording, isProcessing
    if (!isRecording)
        return
    isRecording := false
    isProcessing := true
    ToolTip()
    Dbg("RAlt UP")
    try {
        Run(WSL " stop", , "Hide")
        Dbg("stop launched")
    } catch as e {
        Dbg("stop ERROR: " e.Message)
    }
    deadline := A_TickCount + 60000
    while (A_TickCount < deadline) {
        if (FileExist(WSL_DONE))
            break
        Sleep(200)
    }
    if (!FileExist(WSL_DONE)) {
        Dbg("stop TIMEOUT (no done marker)")
        isProcessing := false
        SoundBeep(200, 200)
        TrayTip("Таймаут", "Диктовка", 1)
        return
    }
    text := Trim(FileRead(WSL_OUT, "UTF-8"))
    Dbg("text: [" text "]")
    if (text == "" || text == "SILENCE") {
        isProcessing := false
        SoundBeep(300, 120)
        Dbg("silence")
        return
    }
    if (SubStr(text, 1, 4) == "ERR:") {
        if (InStr(text, "curl") || InStr(text, "http") || InStr(text, "busy")) {
            SoundBeep(250, 250)
            Dbg("heal: " text)
            try {
                Run('wsl.exe -d Ubuntu -u root -e systemctl restart whisper-server', , "Hide")
                Dbg("heal: server restart launched")
            } catch as e {
                Dbg("heal ERROR: " e.Message)
            }
            TrayTip("Сервер перезапущен", "Диктовка", 1)
            return
        }
        isProcessing := false
        SoundBeep(250, 250)
        Dbg("stop error: " text)
        return
    }
    saved := ClipboardAll()
    A_Clipboard := text
    ClipWait(1)
    if (WinActive("ahk_exe WindowsTerminal.exe"))
        SendText(text)
    else
        Send("^v")
    Sleep(150)
    A_Clipboard := saved
    isProcessing := false
    SoundBeep(1200, 100)
    Dbg("pasted")
}