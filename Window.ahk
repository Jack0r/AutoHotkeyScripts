#InstallKeybdHook
#SingleInstance force
/*
Hotkeys:
Control-Alt-O: make window always on top
Win-W: make window borderless

Alt-W: make window less transparent
Alt-S: make window more transparent

Alt-X: make window clickthoughable
Alt-Z: make window under mouse unclickthroughable
*/

TurnOffSI:
SplashImage, off
SetTimer, TurnOffSI, 1000, Off
Return

^!o::
WinGet, currentWindow, ID, A
WinGet, ExStyle, ExStyle, ahk_id %currentWindow%
if (ExStyle & 0x8)  ; 0x8 is WS_EX_TOPMOST.
{
	Winset, AlwaysOnTop, off, ahk_id %currentWindow%
	SplashImage,, x0 y0 b fs12, OFF always on top.
	Sleep, 1500
	SplashImage, Off
}
else
{
	WinSet, AlwaysOnTop, on, ahk_id %currentWindow%
	SplashImage,,x0 y0 b fs12, ON always on top.
	Sleep, 1500
	SplashImage, Off
}
return

!w::
WinGet, currentWindow, ID, A
if not (%currentWindow%)
{
	%currentWindow% := 255
}
if (%currentWindow% != 255)
{
	%currentWindow% += 5
	WinSet, Transparent, % %currentWindow%, ahk_id %currentWindow%
}
SplashImage,,w100 x0 y0 b fs12, % %currentWindow%
SetTimer, TurnOffSI, 1000, On
Return

!s::
SplashImage, Off
WinGet, currentWindow, ID, A
if not (%currentWindow%)
{
	%currentWindow% := 255
}
if (%currentWindow% != 5)
{
	%currentWindow% -= 5
	WinSet, Transparent, % %currentWindow%, ahk_id %currentWindow%
}
SplashImage,, w100 x0 y0 b fs12, % %currentWindow%
SetTimer, TurnOffSI, 1000, On
Return

#w::
    WinGet, window, ID, A    ; Use the ID of the active window.
   Toggle_Window(window)
 return

Toggle_Window(window)
{
	 WinGet, S, Style, % "ahk_id " window    ; Get the style of the window
	If (S & +0x840000)       ; if not borderless
	{
		 WinSet, Style, -0x840000, % "ahk_id " window    ; Remove borders
		 return
	}
	If (S & -0x840000)       ; if borderless
	{
		 WinSet, Style, +0x840000, % "ahk_id " window    ; Reapply borders
		 return
	}
	Return    ; return if the other if's don't fire (shouldn't be possible in most cases)
}

!x::
WinGet, currentWindow, ID, A
WinSet, ExStyle, +0x80020, ahk_id %currentWindow%
return

!z::
MouseGetPos,,, MouseWin ; Gets the unique ID of the window under the mouse
WinSet, ExStyle, -0x80020, ahk_id %currentWindow%
Return
