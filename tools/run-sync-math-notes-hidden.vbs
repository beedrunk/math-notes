Option Explicit

Dim shell
Dim command

Set shell = CreateObject("WScript.Shell")
shell.CurrentDirectory = "D:\math-notes"

command = "powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File ""D:\math-notes\tools\sync-math-notes.ps1"""

WScript.Quit shell.Run(command, 0, True)
