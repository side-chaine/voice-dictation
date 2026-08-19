@echo off
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v DictateAHK /t REG_SZ /d "\"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe\" \"C:\Users\nikit\dictate.ahk\"" /f
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v DictateWSL /t REG_SZ /d "\"C:\Windows\System32\wsl.exe\" -d Ubuntu -u root -e systemctl start whisper-server" /f
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v DictateAHK
reg query "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v DictateWSL