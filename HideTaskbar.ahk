
#NoEnv			;Not using environment variables
#SingleInstance force

setTimer, checkTaskBarIfActive, 50	;Timer checking every 50ms if taskbar stopped being active
;setTimer, checkMousePosition, 50	;Timer checking mouse coursor once taskbar became active
;setTimer, activateAllPrograms, 50	;Timer for "activating all programs" task
;setTimer, checkIfWeShouldActivateTaskbar, 50	;Timer that checks if the mouse cursor should trigger 
SetTimer, WatchCursor, 200			;Timer that checks if mouse position moved away from sidebar
SetTimer, checkIfHideTaskbarEdge, 10		;Superfast timer that checks if we should hide the taskbar edge "line"
						;It's only that fast when taskbar is in "Active mode"

CoordMode, Mouse, Screen
	
taskBarActive := 1		;Flag set if taskBar became active
topWindowSet := 0		;Flag set to true of Top Window has been set to be activated once taskbar becomes inactive
triggeredByWindowsKey := 0	;Flag set in case the taskbar was triggered by windows key, not mouse cursor
dontShowTaskbar := 0		;Flag set to true if taskBar shouldn't be shown
startMenuActive := 0		;Flag set to true if StartMenu is active
sideBarAction := 0		;Flag that is set if we are using sidebar
ciwsatX := -1			;The x and y coordinates for the mouse click after the taskbar slided out
ciwsatY := -1
taskBarSlidingOut := 0			;Flag set once sideBar is sliding out
taskBarSlidingIn := 0			;Flag set when taskbar sliding in
blockRightEdgeOfTheScreen := 0		;Flag set to true once the taskbar started to slide in (to block moving mouse to the edge while taskbar is sliding in)
					;This is a must due to Windows glitch
firstDisplayWidth := 0			;Width of the first display
secondDisplayWidth := 0			;The width of the second monitor
					;If the 2nd monitor is on the left, the width is negative
					;If the 2nd monitor is on the right of first one, the width is positive
clickedRmbOnStart := 0			;Flag set if we clicked right mouse button on the Start Menu

;Changable settings
userAcountName := "Luk"		;User name for the account(needed to avoid the window with the Profile picture in Start Menu)
waitBeforeShowTaskbar := 300	;time in ms before the taskbar will be shown once the mouse cursor is on the edge
mouseOffsetForAllPrograms := 5	;How many pixels we can move in each direction if the "showAllPrograms" feature shall be activated
AllProgramsLocationX := 1590	;The X-axis position of "all programs" button in Menu Start
AllProgramsLocationY := 880	;The Y-axis position of "all programs" button in Menu Start
waitBeforeShowingAllPrograms := 300	;How much we wait before the all programs are triggered
moveMouseOnTheEdgeValue := 10		;Number of pixels, the mouse will be pushed to the left once in contact with the right edge
taskBarOffset := 5			;How much the mouse can go beyond the taskbar for it not to close yet
waitBeforeCheckingIfCloseTaskbar := 300		;How much time before the TaskBar is closed after we moved our cursor out of "active zone"
sideBarOffsetBeforeActivatingTaskbar := 30			;Width in pixels of a frame in which the taskbar will not be yet activated

SysGet, Mon2, Monitor, 2
if(Mon2Right = 0)
{
	secondDisplayWidth := Mon2Left
}
else
{
	secondDisplayWidth := Mon2Right
}
SysGet, Mon1, Monitor, 1
firstDisplayWidth := Mon1Right
return

LWin Up::			;Left Windows key goes up (before or after StartMenu was activated
if(taskBarActive = 1)		;If taskbar was active before we hit the key
{
	Send {LWin}			;Send simple LWin command
	if(triggeredByWindowsKey = 1)		;If it's the first of hitting LWin, end the trigger
		triggeredByWindowsKey := 0	;And set triggeredByWindowsKey flag to 0 to finish the "triggered by WinKey" time
	else					;If we pushed it for the 3rd, 5th time and so on
		triggeredByWindowsKey := 1	;Set it back on to activated
}
else					;if taskbar was not active before we hit the key
{
	MouseGetPos, previousX, previousY	;we save the position of cursor's X and Y to check later on for "Show All Programs" activity, in case cursor didn't move much
	triggeredByWindowsKey := 1	;We set the flag that it was
	taskBarSlidingOut := 1		;We set the flag for the duration of taskBar sliding out
	WinShow ahk_class Shell_TrayWnd		;Unhide the taskbar
	WinActivate, ahk_class Shell_TrayWnd	;Activate the taskbar
	WinWaitActive, ahk_class Shell_TrayWnd	;Wait once the taskbar is fully showed

	taskBarActive := 1			;We set the flag for taskbar as active
	WinShow Start ahk_class Button		;We show the Start Button
	Send {LWin}			;And send a LWin key to show the StartMenu
}
return

RWin Up::				;Same as above but for the RWin Key
if(taskBarActive = 1)
{
	Send {RWin}
	if(triggeredByWindowsKey = 1)
		triggeredByWindowsKey := 0	;And set triggeredByWindowsKey flag to 0 to finish the "triggered by WinKey" time
	else
		triggeredByWindowsKey := 1
}
else
{
	MouseGetPos, previousX, previousY
	triggeredByWindowsKey := 1
	taskBarSlidingOut := 1
	WinShow ahk_class Shell_TrayWnd
	WinActivate, ahk_class Shell_TrayWnd
	WinWaitActive, ahk_class Shell_TrayWnd

	taskBarActive := 1
	WinShow Start ahk_class Button
	Send {RWin}
}
return

LWin & r:: Send #r	;If we hit combination of Windows key+r (opens Run window) we use default action
RWin & r:: Send #r

RButton::
ifwinactive, ahk_class DV2ControlHost					;if the Start Menu is active
{
	MouseGetPos,,, id_win_under_mouse			;We get the xPos of the mouse and id of the window below
	WinGetClass, class_under_mouse, ahk_id %id_win_under_mouse%	;We get the name of the class of window under mouse cursor
	WinGetTitle, title_under_mouse, ahk_id %id_win_under_mouse%

	;If it turns out that we clicked with right mouse button on the start Orb
	if(title_under_mouse = "Start" and class_under_mouse = "Button")
	{
		MouseGetPos, currentX, currentY				;we get mouse position after the wait
		
		;and we set the flag to true
		clickedRmbOnStart := 1
	}
}
;if the flag was not set to 1, it means it's a simple right click and we send right click message
if(clickedRmbOnStart = 0)
{
	Click Down Right
}
return

RButton Up::
;if the flag was set
if(clickedRmbOnStart = 1)
{
	MouseGetPos, currentX2, currentY2				;we get mouse position after the wait
	if(currentX2 = currentX and currentY2 = currentY)
	{
		MouseClick, left, AllProgramsLocationX, AllProgramsLocationY	;We click on the given coordinates

		MouseMove, currentX, currentY					;And move back mouse cursor to it's original position
	}
	clickedRmbOnStart := 0
}
else	;otherwise it's a simple right click and we sent right click up message
{
	Click Up Right
}
return

LButton::		;Moves the mouse cursor to the left in case we want to use slidebar
MouseGetPos, posx, posy		;Gets mouse position
ciwsatX := posx			;We get the previous mouse position BEFORE we clicked the mouse and move to the edge of the screen
ciwsatY := posy
If(posx = A_ScreenWidth - 1)		;If mouse position is 1 pixel to the left from the width of the screen(so is touching the edge)
{
	if(taskBarActive = 0)			;If taskbar is not active
	{
		if(taskBarSlidingOut = 1)	;If taskBar is sliding out
		{
			clickX := posx		;We get the position of cursor in case we clicked something during
			clickY := posy		;the process of taskbar sliding out
		}
		else
		{
		sideBarAction := 1		;We set the flag for the action being in process
		dontShowTaskbar := 1		;We set flag to not show taskbar
		posx := posx - moveMouseOnTheEdgeValue		;Calculate the new posx for the mouse
		Click Down, %posx%, %posy%		;Click mouse button and keep it down
		dontShowTaskbar := 0			;Set the flag to not show the TaskBar
		}
	}
	else					;If taskbar is active it means it's a simple click and we don't need to move the cursor
	{
		triggeredByWindowsKey := 0	;We set the flag to false in case the taskbar was triggered by the win Key
		Click Down			;And we send the click down command
	}
}
else if(triggeredByWindowsKey = 1)	;if the TaskBar was triggered by the windows key
{	
	WinGetPos tbrX, , widthOfTaskbar, , ahk_class Shell_TrayWnd
	if(posx > A_ScreenWidth - 1 - widthOfTaskbar)			;if we clicked anywhere in the taskBar width
	{
		triggeredByWindowsKey := 0			;We end the "Trigger time"
		if(taskBarSlidingOut = 1)	;If sidebar is sliding out and we triggered the win key, AND we clicked mouse
		{
			clickX := posx		;We remember the cursor position for delayed mouse button down action
			clickY := posy
			if(triggeredByWindowsKey = 1)
				triggeredByWindowsKey := 0	;And set triggeredByWindowsKey flag to 0 to finish the "triggered by WinKey" time
			else
				triggeredByWindowsKey := 1
		}
		else
			Click Down					;And we send Click Down command
	}
	else
		Click Down				;If we didn't click in the width of taskbar we just send click command
}
else
{
	if(taskBarSlidingOut = 1)
	{
		clickX := posx
		clickY := posy
	}
	else
		Click Down			;in all other cases it was just a simple click down
}
return

LButton Up::				;Needed to be remmaped so that the LButton doesn't hides this functionality			
ciwsatX := -1
ciwsatY := -1
Click Up
return

checkTaskBarIfActive:			;We check if TaskBar needs to be hidden
	WinGetPos tbrX, tbrY, tbrWidth, tbrHeight, ahk_class Shell_TrayWnd
	;if TaskBar is near the edge(normal Windows position)
	if tbrX =				;if tbrX is empty, meaning the TaskBar is hidden completely
	{
		SetTimer, checkIfHideTaskbarEdge, Off		;We don't need to check taskbar while it's hidden
		if(taskBarActive = 0)
		{
			taskBarSlidingIn := 0			;We set the flag to false as it's finished sliding in
			ClipCursor( 0, 0, 0, A_ScreenWidth - 3, A_ScreenHeight, secondDisplayWidth)		;We set the mouse area as max screen size
		}
		else				;In case something is wrong and the taskbar is still active
		{
			taskBarSlidingIn := 0
			taskBarActive := 0		;We set all flags needed to false
			topWindowSet := 0
			triggeredByWindowsKey := 0
			WinHide Start ahk_class Button		;Needed for Windows glitch, during fast paced changes in taskbar(in case someone constantly moves mouse quickly from and to the edge)
			ClipCursor( 0, 0, 0, A_ScreenWidth - 3, A_ScreenHeight, secondDisplayWidth) 
		}
	}
	else if (tbrX = A_ScreenWidth - tbrWidth)		;if TaskBar is in FULL shown position
	{
		topWindowSet := 0				;We set flag to keep checking the open windows to find the most top one
		taskBarActive := 1				;We set flag to true as TaskBar is fully Active
		taskBarSlidingOut := 0
		SetTimer, checkIfHideTaskbarEdge, 10		;We set timer to check for the future sliding in of taskbar
	}
	else						;If the taskbar started to slide in
	{
		taskBarSlidingIn := 1			;We set the flag
		ClipCursor( 1, 0, 0, A_ScreenWidth - 3, A_ScreenHeight, secondDisplayWidth)		;Limit the mouse area
		SetTimer, checkIfHideTaskbarEdge, 10		;We set timer to check for the future sliding in of taskbar
	}
	Gosub, checkMousePosition			;We run both subroutines, they need to be in chronological order, otherwise timers become asynchronous
	Gosub, checkIfWeShouldActivateTaskbar		;All 3 timers use mutual variables, and timers become unstable if they overlap during different times
return

checkMousePosition:					;Timer to check if the TaskBar should start hiding
	if(taskBarActive = 1)				;If it's Active
	{
		
		MouseGetPos, xPos,, id_win_under_mouse			;We get the xPos of the mouse and id of the window below
		WinGetClass, class_under_mouse, ahk_id %id_win_under_mouse%	;We get the name of the class of window under mouse cursor

		;Below we put all exceptions
		;Windows on which if we hover our mouse the taskbar will NOT
		;be slided in; All other windows if we hover our mouse over, will make the taskbar to slide in
		;We use the class name of the window that will be exception
		;Below, there is other set of the same exceptions, and they are exact copy of the exceptions below
		;If this list is updated the exceptions below must be updated also

		;ahk_class DV2ControlHost - start menu
		If (class_under_mouse = "DV2ControlHost")		;if the below class is Start Menu it means the TaskBar must stay visable
			return
		else if (class_under_mouse = "BaseBar")			;if it's BaseBar
			return
		else if (class_under_mouse = "#32768")			;if it's one of the menu's
			return
		else if (class_under_mouse = "#32770")			;if it's sound volume meter in tray
			return
		else If (class_under_mouse = "Shell_TrayWnd")		;if it's Tray Window
			return
		else if(class_under_mouse = "TaskListOverlayWnd")	;if it's one of the task windows
			return
		else if(class_under_mouse = "TaskListThumbnailWnd")	
			return
		else if(class_under_mouse = "NotifyIconOverflowWindow")	;if it's notifier window
			return
		else if(class_under_mouse = "WindowsForms10.Window.8.app.0.378734a")
			return
		else if(class_under_mouse = "WindowsForms10.Window.8.app.0.33c0d9d")
			return
		else if(class_under_mouse = "WindowsForms10.Window.20808.app.0.33c0d9d")	;DisplayFusion
			return
		else if(class_under_mouse = "WindowsForms10.Window.0.app.0.378734a")
			return
		else if(class_under_mouse = "WindowsForms10.Window.0.app.0.3aa54a0")	;Connectify
			return
		else if(class_under_mouse = "WindowsForms10.Window.20808.app.0.3aa54a0")	;Connectify
			return
		else if(class_under_mouse = "WindowsForms10.Window.20808.app.0.218f99c")	;3RVX
			return
		else if(class_under_mouse = "ClockFlyoutWindow")	;if it's clock window
			return
		else if(class_under_mouse = "SysFader")			;used when some item from control panel in Menu Start run
			return

		WinGetPos tbrX, tbrY, tbrWidth, tbrHeight, ahk_class Shell_TrayWnd	;Now we check if the mouse went beyond the allowed offset since taskBar left edge ended
		if (xPos > tbrX - taskBarOffset)
			return

		Sleep, %waitBeforeCheckingIfCloseTaskbar%		;We wait to negate the accidental moving mouse cursor past "active" zone

		if(taskBarActive = 1)				;And after sleep we check again if the cursor is out of active zone, if it is it means TaskBar should close now
		{
			MouseGetPos, xPos,, id_win_under_mouse			;We get the xPos of the mouse and id of the window below
			WinGetClass, class_under_mouse, ahk_id %id_win_under_mouse%	;We get the name of the class of window under mouse cursor

			;ahk_class DV2ControlHost - start menu
			If (class_under_mouse = "DV2ControlHost")		;if the below class is Start Menu it means the TaskBar must stay visable
				return
			else if (class_under_mouse = "BaseBar")			;if it's BaseBar
				return
			else if (class_under_mouse = "#32768")			;if it's one of the menu's
				return
			else if (class_under_mouse = "#32770")			;if it's sound volume meter in tray
				return
			else If (class_under_mouse = "Shell_TrayWnd")		;if it's Tray Window
				return
			else if(class_under_mouse = "TaskListOverlayWnd")	;if it's one of the task windows
				return
			else if(class_under_mouse = "TaskListThumbnailWnd")	
				return
			else if(class_under_mouse = "NotifyIconOverflowWindow")	;if it's notifier window
				return
			else if(class_under_mouse = "WindowsForms10.Window.8.app.0.378734a")
				return
			else if(class_under_mouse = "WindowsForms10.Window.8.app.0.33c0d9d")
				return
			else if(class_under_mouse = "WindowsForms10.Window.20808.app.0.33c0d9d")	;DisplayFusion
				return
			else if(class_under_mouse = "WindowsForms10.Window.0.app.0.378734a")	
				return
			else if(class_under_mouse = "WindowsForms10.Window.0.app.0.3aa54a0")	;Connectify
				return
			else if(class_under_mouse = "WindowsForms10.Window.20808.app.0.3aa54a0")	;Connectify
				return
			else if(class_under_mouse = "WindowsForms10.Window.20808.app.0.218f99c")	;3RVX
				return
			else if(class_under_mouse = "ClockFlyoutWindow")
				return
			else if(class_under_mouse = "SysFader")
				return
		

			WinGetPos tbrX, tbrY, tbrWidth, tbrHeight, ahk_class Shell_TrayWnd	;Now we check if the mouse went beyond the allowed offset since taskBar left edge ended
			if (xPos > tbrX - taskBarOffset)
				return

			topWindowSet := 0

			if(topWindowSet = 0 and triggeredByWindowsKey = 0)	;if we didn't look for the TopWindow yet and start menu was not triggered by LWin/RWin
			{
				WinGet, open_windows_list, List			;We get the list of open windows
				WinGet, numberOfWindows, Count			;We get number of Windows open
				notMinimizedWindowFound := 0			;Flag in case there is no normal/max window, in which case we activate the desktop

				;The first inner loop, that loops over the all open windows
				;It is used to make the previously open(not minimized window) active once the
				;taskbar gets hidden again, for example if we open taskbar and we click it
				;it will make the taskbar active, and the previously open window inactive
				;with this loop it will make the previously active window active again
				Loop, %numberOfWindows%				;We loop over all open windows
				{
					;We get the index of the current window in the loop
					;%A_Index% gets the id of the current loop(starts from 1 not 0)
					winId := open_windows_list%A_Index%

					;We get class and title of the window
					WinGetClass, class, ahk_id %winId%
					WinGetTitle, title, ahk_id %winId%

					;Below we put all exceptions
					;Windows that will NOT be possible to be made active once
					;the taskbar is slided in
					;We use the class name or the title name of the windows

					;"Shell_TrayWnd" is tray window
					if (class = "Shell_TrayWnd")			;If it's Tray Window we skip this iteration
						continue
					;"BaseBar" applies to programs opened window for example
					if (class = "BaseBar")
						continue
					;"Progman" is desktop
					if (class = "Progman")
						continue
					If(class = "Button")				;In Case it's Start button
					{
						if(title = "Start")
						{
							continue
						}
					}
					if(class = "Desktop User Picture")		;In case it's the Profile Picture in the Start Menu
					{
						if(title = userAcountName)
							continue
					}
					if(class = "DV2ControlHost")			;If it's Start Menu
						continue
					if(class = "TaskListOverlayWnd")		;Task windows
						continue
					if(class = "TaskListThumbnailWnd")
						continue
					if(class = "tooltips_class32")
						continue
					if(class = "BaseBar")
						continue
					if(class = "ClockFlyoutWindow")			
						continue
					if(class = "SysFader")
						continue
					if(class = "MilkDrop2")
						continue
					if(class = "AU3Reveal")				;Autoit Window Spy
						continue
					if class =					;if it's some window without a class
						continue
					if title =					;or title
						continue
					if title = Taskbar
						continue
					if title = checksum tooltip			;If it's checksum tooltip window, don't put it on top
						continue
					if title = MilkDrop 2
						continue
						

					IfWinActive, ahk_class class
					{
						WinGet, prev_active_window_id, ID, A
						topWindowSet := 1
						break
					}

					;MinMax: Retrieves the minimized/maximized state for a window. OuputVar is made blank if no matching window exists; otherwise, it is set to one of the following numbers:
					;-1: The window is minimized (WinRestore can unminimize it). 
					;1: The window is maximized (WinRestore can unmaximize it).
					;0: The window is neither minimized nor maximized.
					WinGet, minMaxState, MinMax, ahk_id %winId%
					
					if(minMaxState > -1 and topWindowSet = 0)		;if we found the window that can be activated once taskbar is hidden
					{
						prev_active_window_id := winId			;we copy it's ID
						topWindowSet := 1				;we set flag that we found at least 1 not minimized window
												;we break the loop, as there is no need to look more(we found the most top one window, as the list of windows is ordered from the most top to bottom window)
					}
				}
				if(topWindowSet = 1)						;If we found any window we activate it
				{
					;WinGetClass, class, ahk_id %prev_active_window_id%
					;if(class = "MMCMainFrame")
					;{
					;}
					;else
					;	MsgBox %class%
					WinActivate, ahk_id %prev_active_window_id%
					
					;This segment is for the windows "twitch" where the Start Menu becomes still visable even though other window has been activated
					;Sleep, 500		;We wait over the normal perion in which the taskbar should start sliding right

					WinGetPos tbrX, , tbrWidth, , ahk_class Shell_TrayWnd	;We get taskbar dimensions
					if(tbrX = A_ScreenWidth - tbrWidth)			;If taskBar didn't move even though it should
					{
						;Send {LWin}					;We send LWin command
					}
				}
				else								;If there is no window to activate, we activate Desktop
				{
					WinActivate, Program Manager ahk_class Progman
				}
			}
		}
	}
return

activateAllPrograms:							;Activates all programs in Menu Start
ifwinactive, ahk_class DV2ControlHost					;if the Start Menu is active
{
	if(startMenuActive < 1)						;startMenu was not active before?
	{
		startMenuActive := 1					;we set its flag as active		
		
		if(triggeredByWindowsKey = 1)			;if the menu was triggered by WinKey we were already waiting a little, so we substract that time
		{
			if(waitBeforeShowingAllPrograms - waitBeforeCheckingIfCloseTaskbar > 200)	;if the difference is more than 200ms
				Sleep, waitBeforeShowingAllPrograms - waitBeforeCheckingIfCloseTaskbar	;We set it as delay time
			else				;if it's less we set it as min 200ms
				Sleep, 200
		}
		else						;if the menu was triggered by mouse button
		{
			MouseGetPos, previousX, previousY		;We get mouse current position
			Sleep, %waitBeforeShowingAllPrograms%			;we wait given time
			
		}

		MouseGetPos, currentX, currentY				;we get mouse position after the wait
		if(currentX > previousX - mouseOffsetForAllPrograms	;if the position finds itself within set limit
		and currentX < previousX + mouseOffsetForAllPrograms 
		and currentY > previousY - mouseOffsetForAllPrograms 
		and currentY < previousY + mouseOffsetForAllPrograms
		and currentX > 0 and currentX < firstDisplayWidth)	;if the cursor is not on the first monitor we don't move it
		{	 
			MouseClick, left, AllProgramsLocationX, AllProgramsLocationY	;We click on the given coordinates

			MouseMove, currentX, currentY					;And move back mouse cursor to it's original position
		}
	}
}
else									;if Start Menu is not active
{
	if(startMenuActive = 0)
	{
	}
	else
		startMenuActive := 0						;we set it as notActive
}
return

checkIfWeShouldActivateTaskbar:						;We check if we should activate Taskbar
GetKeyState, state, LButton						;We get Left mouse button state
MouseGetPos, posx, posy				;We get current position

if((ciwsatX <> posx or ciwsatY <> posy) and ciwsatX > A_ScreenWidth - sideBarOffsetBeforeActivatingTaskbar)
	sideBarAction := 1

;if ciwsatX <> posx true it means the button was already down before we moved cursor to the edge, which means we shouldn't block the TaskBar sliding out
if ((state = "U" or (ciwsatX <> posx and ciwsatX < A_ScreenWidth - sideBarOffsetBeforeActivatingTaskbar)) and dontShowTaskbar = 0 and taskBarActive = 0 and sideBarAction = 0)		;If it's in Up state, and flag to not show Taskbar is set to false, and if taskBar is not activated
{
	ifWinNotActive, ahk_class Shell_TrayWnd				;if The TrayWnd is not active
	{
		;Retrieves the current position of the mouse cursor
		MouseGetPos, posx, posy
		
		If(posx = A_ScreenWidth - 1 or posx = A_ScreenWidth - 2)	;if mouse cursor is on the right edge of the screen
		{
			Sleep, %waitBeforeShowTaskbar%			;We wait given time

			GetKeyState, state, LButton 
			if((state = "U" or (ciwsatX <> posx and ciwsatX < A_ScreenWidth - sideBarOffsetBeforeActivatingTaskbar)) and dontShowTaskbar = 0  and taskBarActive = 0 and sideBarAction = 0)	;if the needed conditions didn't change
			{
				ifWinNotActive, ahk_class Shell_TrayWnd			;if Tray is not active
				{
					;Retrieves the current position of the mouse cursor
					MouseGetPos, posx, posy
					If(posx = A_ScreenWidth - 1 or posx = A_ScreenWidth - 2)	;if the mouse is still "touching" the right edge, and the mouse button is not pressed
					{
						if(sideBarAction = 0)
						{
							;MsgBox %ciwsatX%
							;MsgBox %sideBarAction%
							taskBarSlidingOut := 1
							WinShow ahk_class Shell_TrayWnd		;We show Taskbar
							;we activate the Tray Bar
							WinActivate, ahk_class Shell_TrayWnd

							taskBarActive := 1		;and we set it's flag to true
							WinShow Start ahk_class Button	;We show Start Button
							taskBarSlidingOut := 0
						}
					}
				}
			}
		}
	}
}
return

WatchCursor:					;Checks if sidebar action finished
if(sideBarAction = 1)				;If it's in motion
{
	GetKeyState, state, LButton
	MouseGetPos, posX
	;We also check if the state of the button is Up, if not it means we're still sliding the sidebar
	if(posX < A_ScreenWidth - sideBarOffsetBeforeActivatingTaskbar and state = "U")		;We check the mouse position; if it's X is lower than the width of right sidebar
	{
	;MsgBox cos
	sideBarAction := 0			;We end the "sideBar mode"
	}
}
if(taskBarSlidingOut = 1)				;if we're in the process of sliding the taskbar out
{
	WinGetPos tbrX, tbrY, tbrWidth, tbrHeight, ahk_class Shell_TrayWnd	;Now we check if the mouse went beyond the allowed offset since taskBar left edge ended
	if (tbrX > 0 and tbrX = A_ScreenWidth - tbrWidth)		;if TaskBar finished sliding out
	{

		if(clickX >= 0 and clickY >= 0)				;if we clicked mouse before the taskbar started to slide out
		{
			MouseGetPos, posX, posY
			if(posx > clickX - mouseOffsetForAllPrograms	;if the position finds itself within set limit
				and posx < clickX + mouseOffsetForAllPrograms 
				and posy > clickY - mouseOffsetForAllPrograms 
				and posy < clickY + mouseOffsetForAllPrograms)
			{
				taskBarSlidingOut := 0		;We nullify the flag
				Click, %clickX%, %clickY%	;and we click on the previous position
				clickX := -1
				clickY := -1
				MouseMove posx, posy		;and we move back the mouse to where it was before moved
			}
			else				;if the position of mouse is beyond the acceptable frame
			{

					taskBarSlidingOut := 0		;we don't click the mouse button

					clickX := -1
					clickY := -1

			}
		}
		else
		{

		}
		
	}
}
return


checkIfHideTaskbarEdge:
	WinGetPos tbrX, tbrY, tbrWidth, tbrHeight, ahk_class Shell_TrayWnd
	;if TaskBar is near the edge(normal Windows position)
		if(tbrX = A_ScreenWidth - 2 and taskBarSlidingOut = 0)
	{
		if(triggeredByWindowsKey = 0)	;if this is not trigger time
		{
			;Sleep, 100		;we sleep 100ms to let pass the taskbar if it's moving from the hidden position to the left, and check it again
			WinGetPos tbrX, tbrY, tbrWidth, tbrHeight, ahk_class Shell_TrayWnd
			if(tbrX = A_ScreenWidth - 2 and taskBarSlidingOut = 0)
			{
				if(triggeredByWindowsKey = 0)	;if the situation didn't change(meaning the taskbar is in default windows hidden position)
				{
					;taskBarActive := 0	;We set all flags needed to false
					topWindowSet := 0
					triggeredByWindowsKey := 0
					WinHide ahk_class Shell_TrayWnd			;And we hide taskbat
					WinHide Start ahk_class Button		;We Hide Start button
				}
			}
		}
		if(taskBarActive = 1 and triggeredByWindowsKey = 1)		;In case we hit the LWin/RWin button when the taskbar STARTED to slide into hidden position
		{
			;Sleep, 100
			WinGetPos tbrX, tbrY, tbrWidth, tbrHeight, ahk_class Shell_TrayWnd
			if(tbrX = A_ScreenWidth - 2)
			{
				if(taskBarActive = 1 and triggeredByWindowsKey = 1)
				{
					;taskBarActive := 0
					topWindowSet := 0
					triggeredByWindowsKey := 0
					WinHide ahk_class Shell_TrayWnd
					WinHide Start ahk_class Button
				}
			}
		}
	}
return


ClipCursor( Confine=True, x1=0 , y1=0, x2=1, y2=1, secondDisplayWidth=0) 
{ 
	;If the second display is on, and is on the left(negative value) we add it to the left bound
	;of the Clip method
	if(secondDisplayWidth < 0)
	{
		x1 := x1 + secondDisplayWidth
	}

	VarSetCapacity(R,16,0),  NumPut(x1,&R+0),NumPut(y1,&R+4),NumPut(x2,&R+8),NumPut(y2,&R+12) 
	Return Confine ? DllCall( "ClipCursor", UInt,&R ) : DllCall( "ClipCursor" ) 
}

ExitApp