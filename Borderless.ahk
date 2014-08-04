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