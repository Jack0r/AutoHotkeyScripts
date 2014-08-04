;----------------------------------------------------------------------------
;
; Min2Tray
;
versionString = 1.7.9
versionDate   = 20111011
;
; _minimize a window to system tray area of taskbar as icon.
;  BossKey feature for minimizing several windows at once.
;  make window always-on-top and maximize window vertically
;  or horizontally. StartupMinimize hides certain windows
;  upon start of Min2Tray. and much more!
;
; _requires ms windows nt/2000/xp/vista/7 or newer.
;  (not tested under win 8, yet ;-)
;
; _licensed under the terms of the GPLv3
;  created by Junyx / KTC^brain in June 2005
;
; _program is a 2-in-1 thingy:
;   _started without parameters on cmdline it behaves as
;    the main program waiting for hotkey action
;   _startet with ahk_window_id on cmdline by main program
;    it will hide that particular window and generate
;    a (hopefully) meaningful tray icon
;
; _inspired by:
;   ActualWindowMinimizer (unfortunately payware)
;   NiftyWindows by Enovatic-Solutions (nice tweaks)
;   ac'tivAid by Heise Zeitschriften Verlag GmbH & Co. KG
;
; _contains some code from:
;   minimize.ahk (from AHK docs, no author)
;   Forms Framework by majkinetor
;
; _thanks to:
;   Chris Mallett (support response in a flash!)
;   Rajat (for some wonderful scripts)
;   GSX-R600 / KTC^game (for testing)
;   Lemmy / KTC^game (for testing)
;   Demokos and Andreone (French translation, now obsolete)
;   all users who gave feedback
;
;----------------------------------------------------------------------------
;
; init
;
#NoEnv
#MaxMem 1
#Persistent
#NoTrayIcon
#KeyHistory 0
#SingleInstance Off

; language, check-ups etc.
Gosub, h_InitGeneral

#UseHook On
#WinActivateForce
StringCaseSense, On
DetectHiddenWindows, On
SetWinDelay 10

; cmdline: no args -> behaviour: starter
If ( %0% < 1 ) {
   ;=========================================================================
   ; started as hotkey-launcher (starter)
	Goto, h_InitStarter
	Return
}
; end of auto-execution for starter here!
;============================================================================

;============================================================================
; function as tray menu for minimized window (helper) starts here

;----------------------------------------------------------------------------
; Helper -- init
;
whoami := "helper"
f_SetLanguage( whoami )

h_ID0 = 0
; go thru all arguments on command line
Loop, %0% {
   tmp := %A_Index%

   If ( InStr( tmp, "0x", TRUE ) = 1 ) {
      ; get several (at least one) window id
      h_ID0++
      h_ID%h_ID0% = %tmp%
   } Else If ( h_ID0 = 0 ) {
      If ( tmp = "__justTriggerAction__")
         h_JTA := TRUE
      Else  ; get title for multi window mode
         h_MultiTitle = %tmp%
   }
}

If ( h_ID0 = 0 )
   Goto, h_ExitWithParamError

; memorize frontmost window id for later comparison
; with winID of minimized window (only if hiding just 1 window)
If ( h_ID0 = 1 )
   h_activeWinID := f_GetOwnerOrSelf( WinActive("A") )
Else
   h_activeWinID := FALSE

; h_ID0 now holds the count of window IDs used (1 or more)
; h_ID1 is the first window ID, h_ID2 the next and so on
newID0 = 0  ; count of true hidden windows
Loop, %h_ID0% {
   h_WinID := h_ID%A_Index%
   Loop {
      skipThis := FALSE

      ; set "last used window"
      WinWait, ahk_id %h_WinID%,, 1
      If ( ErrorLevel ) {
         ; It timed out, so go on with next window id
         skipThis := TRUE   ; outer loop skip
      	Break
      }
      
      WinGetClass, h_Class
      WinGet, h_Application, ProcessName

      ; substitution of "evil class"
      newWinID := f_GetOwnerOrSelf( h_WinID )
      If ( h_WinID = newWinID )
         ; no substitution: leave the loop!
         Break
      Else
         ; go another looping round with new content in h_WinID...
         h_WinID := newWinID
   }
   If ( skipThis )
      Continue ; skipping since window couldn't be made "last used one"

   If f_IsForbiddenWinClass( h_Class )
   	Continue

   ; get win title for later usage
   WinGetTitle, h_Title

   If ( h_JTA )   ; JustTriggerAction (for StartupMinimize) and exit (default)
      retVal := f_TriggerAction( h_WinID, h_Application "|" h_Class "|jta_e", "", h_Title )
      ; retVal will be "m2t" to indicate that minimizing should continue
      ; otherwise exit now.

   ; hide the window away if NOT in JustTriggerAction mode
   ; OR if retVal is set to "cont"
   If ( Not h_JTA Or retVal = "m2t" ) {

      If ( m2t_NoMinGlobal )
         h_NoMin := TRUE
      Else {
         ; read out app|class|nm for "no minimize"
         h_NoMin := FALSE
         RegRead, h_NoMin, HKCU, %h_RegSubkey%, %h_Application%|nm   ; generic app
   		If ( Not h_NoMin )
      		RegRead, h_NoMin, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|nm
      }

      If ( Not h_NoMin ) {
         ; only minimize window to taskbar prior to hiding if not already done
         WinGet, h_MinMax, MinMax
         If ( h_MinMax <> -1 ) {
            WinMinimize
            Sleep, 75
         }
      } Else
         ; give it a sec to breathe
         Sleep, 15

      WinHide
      newID0++ ; one more win hidden
      newID%newID0% = %h_WinID%  ; update with substituted or original class
      newApp%newID0% = %h_Application%
      newTit%newID0% = %h_Title%
   } Else  ; default: exit after JustTriggerAction
      ExitApp, 0
}

If ( newID0 = 0 )
   ExitApp, 1  ; no windows found for hiding

; newID0 now holds the count of window IDs hidden (1 or more)
; newID1 is the first window ID, newID2 the next and so on
; newApp1 is the first application name
; newTit1 is the first window title
; at least newID1 __must__ be assigned at this point!

; if "h_MultiTitle" is set, user requested a "MultiMode" helper to be started
If ( h_MultiTitle ) {
   ; set new vars when in multi mode
   h_Application = __multi__
   h_Title = %h_MultiTitle%
   StringReplace, tmp, h_MultiTitle, %A_SPACE%, , All
   StringReplace, tmp, tmp, %A_TAB%, , All
   StringReplace, tmp, tmp, `r`n, , All
   h_Class = %tmp%
   ; "h_MM" is only TRUE if we are in MultiMode
   h_MM := TRUE
} Else {
   h_MM := FALSE
}

; re-activate last used window after hiding 
Sleep, 50
If ( newID1 = h_activeWinID AND h_NoMin )
   ; fall back to "SendInput" only if
   ; window is frontmost and "no minimize" is used
   SendInput, !{ESC}
Else
   WinActivateBottom, A

OnExit, h_Unhide
Gosub, h_SetMenu
Gosub, h_SetTray
Gosub, h_SetTimedCheck

; read out of registry and assign user un-minimize hotkey
h_hkKey =
RegRead, h_hkKey, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|ch
f_AssignHotkey( h_hkKey, "h_Unhide" )

; set helper-wide variable holding window id or "" if in MultiMode
If ( h_MM )
   h_taID := ""
Else
   h_taID := newID1

f_TriggerAction( h_taID, h_Application "|" h_Class "|hide_ea", "", h_MenuWin )

Return	; end of auto execution, wait for menu action

;----------------------------------------------------------------------------
; Helper -- subs
;

h_TriggerExitApp:
   ; trigger action (if any) before exiting
   OnExit
   f_TriggerAction( h_taID, h_Application "|" h_Class "|exit_eb", "", h_MenuWin )
ExitApp

h_Unhide:
   SetTimer, h_CheckForWin, Off
   ; flushes the hotkey buffer before exiting
   ; no more detection of hotkey modifier WIN under windows desktop
   Suspend, On
   f_TriggerAction( h_taID, h_Application "|" h_Class "|unhide_eb", "", h_MenuWin )
   ; memorize currently active window for later (for TA commands)
   ; on "forbidden classes" use last active window then 
   If f_IsForbiddenWinClass()
      SendInput, !{ESC}
   h_taActiveWinID := WinActive("A")
   ; start unhiding now
   Loop, %newID0% {
      ; open windows in reverse order
      tmp := newID0 - (A_Index - 1)
      h_WinID := newID%tmp%
      If ( h_WinID = "" )
         Continue
      WinShow, ahk_id %h_WinID%
      WinRestore, ahk_id %h_WinID%
      WinActivate, ahk_id %h_WinID%
      Sleep, 75
   }
   Gosub, h_TriggerExitApp
Return

h_Close:
   Msgbox, 36, %h_MenuWin% - %lng_WindowTitle%, %lng_hClose1%%h_MenuWin%%lng_hClose2%
   IfMsgBox, No	; do not close
      Return
   SetTimer, h_CheckForWin, Off
   Suspend, On
   f_TriggerAction( h_taID, h_Application "|" h_Class "|close_eb", "", h_MenuWin )
   Loop, %newID0% {
      h_WinID := newID%A_Index%
      If ( h_WinID = "" )
         Continue
      WinShow, ahk_id %h_WinID%
      WinClose, ahk_id %h_WinID%
   }
   Gosub, h_TriggerExitApp
Return

h_SetTimedCheck:
   ; get interval from registry, if any
	RegRead, tmp, HKCU, %h_RegSubkey%\Misc, CheckForWinEveryMiliSec
	If ( ErrorLevel OR tmp < 200 OR tmp > 10000 )
		tmp = 2000
	SetTimer, h_CheckForWin, %tmp%
Return

h_CheckForWin:
   hiddenWin = %newID0%
   Loop, %newID0% {
      h_WinID := newID%A_Index%
      ; window already unhidden or non-existing?
      WinGet, tmp, Style, ahk_id %h_WinID%
      Transform, tmp, BitAnd, %tmp%, 0xF0000000
      If ( tmp = 0x10000000 OR tmp = 0x90000000 OR Not WinExist( "ahk_id " h_WinID ) ) {
         ; decrement count of hidden windows
         hiddenWin--
         ; MultiMode: remove entry from sub menu if win ID is still valid
			If ( h_MM AND h_WinID <> "" ) {
	         tmpOld := f_StringLeft( A_Index ": " newTit%A_Index% " [" newApp%A_Index% "]" )
	        	Menu, MultiWinMenu, Delete, %tmpOld%
	         newID%A_Index% = ; invalidate win ID
			}
      } Else {
		   ; get current title
			WinGetTitle, tmpNew, ahk_id %h_WinID%
         If ( h_MM ) {
            ; we are in MultiMode
            ; check for changed window title
	         If ( tmpNew <> newTit%A_Index% ) {
	            tmpOld := f_StringLeft( A_Index ": " newTit%A_Index% " [" newApp%A_Index% "]" )
	            newTit%A_Index% = %tmpNew%
	            tmp    := f_StringLeft( A_Index ": " newTit%A_Index% " [" newApp%A_Index% "]" )
	           	Menu, MultiWinMenu, Rename, %tmpOld%, %tmp%
	         }
		   } Else {
            ; NOT in MultiMode
            ; check for changed window title
		      If ( tmpNew <> h_Title ) {
               If ( h_sotcEnabled ) {
                  If ( RegExMatch( tmpNew, h_sotcMatch ) ; show window after
                       Or h_sotcMatch = "" ) ; title changed or RegEx matches
                     Gosub, h_Unhide
		         } Else {  ; update window title and redraw menu
		            h_Title = %tmpNew%
		            Gosub, h_SetMenu
                  f_TriggerAction( h_taID, h_Application "|" h_Class "|sotc_ea", "", h_MenuWin )
		         }
		      }
		   }
		}
   }
   If ( hiddenWin <= 0 ) {
      ; there are no hidden windows anymore
      Gosub, h_TriggerExitApp
   }

   ; redraw tray, if changed (for StealthMode)
   f_ShowTrayIcon( h_appExe, h_appExeIcon )
Return

h_SetTray:
   h_ciEnabled := FALSE
	; first look for custom icon
	RegRead, tmp, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|ci
	If ( Not ErrorLevel ) {
		StringSplit, tmparray, tmp, |
		h_appExe     = %tmparray1%
		h_appExeIcon = %tmparray2%
		h_ciEnabled  := TRUE
	} Else {
      ; look for generic icon (for app)
		RegRead, tmp, HKCU, %h_RegSubkey%, %h_Application%|ci
		If ( Not ErrorLevel ) {
			StringSplit, tmparray, tmp, |
			h_appExe     = %tmparray1%
			h_appExeIcon = %tmparray2%
   		h_ciEnabled  := TRUE
		} Else If ( ( h_Application = "explorer.exe" ) AND ( h_Class = "ExploreWClass" ) ) {
      	; special treatment for explorer windows
			h_appExe     = %A_WinDir%\system32\shell32.dll
			h_appExeIcon = 5
		} Else {
			h_appExeIcon = 1
         ; get module full path (owner.exe)
         Win_Get(newID1, "M", tmpOwner )
         SplitPath, tmpOwner, , tmpDir, , tmpNameNoEx
         ; look for app.ico file
         h_appExe = %tmpDir%\%tmpNameNoEx%.ico
         If Not FileExist( h_appExe ) {
            ; use first icon from owner.exe of window
            h_appExe = %tmpOwner%
         }
		}
	}
	f_ShowTrayIcon( h_appExe, h_appExeIcon )
Return

h_SetMenu:
   h_cnEnabled := FALSE ; custom name in use?

	RegRead, h_appName, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|cn 	; look for custom name
	If ( Not ErrorLevel ) {
		h_MenuWin   = %h_appName%
		h_TrayTitle = %h_appName%
		h_cnEnabled := TRUE
	} Else {
		RegRead, h_appName, HKCU, %h_RegSubkey%, %h_Application%|cn 	; look for generic custom name
		If ( Not ErrorLevel ) {
			h_MenuWin   = %h_appName%
			h_TrayTitle = %h_appName%
			h_cnEnabled := TRUE
		} Else {
         h_Title    := f_StringLeft( h_Title )
			h_MenuWin   = %h_Title% [%h_Application%]
			h_TrayTitle = %h_Title%`n[%h_Application%]

         ; Jaakon's Mode asks for custom name if none is specified
         If ( m2t_JaakonMode ) {
   		   Gosub, h_ChangeName
   		   If ( Not ErrorLevel ) { 
               ; only set vars if OK was pressed in input box within h_ChangeName
        			h_MenuWin   = %h_appName%
      			h_TrayTitle = %h_appName%
      			h_cnEnabled := TRUE
   		   }
   		   m2t_JaakonMode := FALSE
   		}
		}
	}

   ; ShowOnTitleChange enabled?
   h_sotcEnabled := FALSE
   RegRead, h_sotcMatch, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|sotc
   If ( Not ErrorLevel )
      h_sotcEnabled := TRUE

   ; NoMinimize enabled?
   RegRead, h_nmEnabled, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|nm
   If ( ErrorLevel )
      h_nmEnabled := FALSE  ; default: nope

	Menu, TRAY, DeleteAll	; tabularasa
	Menu, TRAY, Click, %m2t_clickCount%
	Menu, TRAY, NoStandard
	Menu, TRAY, Add, %h_MenuWin%, h_MenuHandler

	; MultiWin mode
   If ( h_MM ) {
      Loop, %newID0% {
         tmp := f_StringLeft( A_Index ": " newTit%A_Index% " [" newApp%A_Index% "]" )
        	Menu, MultiWinMenu, Add, %tmp%, h_MenuHandlerMultiWin
      }
      ; possibly ready for left click -> unhide this win
      Menu, TRAY, Add, %lng_MenuMultiWin%, :MultiWinMenu
   }
   Menu, TRAY, Add

   ; UserMenu
   umCount := 0  ; count of menu entries
   Loop, 25 {
      RegRead, umLabel%A_Index%, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|uml%A_Index% 
      If ( ErrorLevel Or umLabel%A_Index% = "" )
         Break
      RegRead, umAction%A_Index%, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|uma%A_Index%
      If ( ErrorLevel Or umAction%A_Index% = "" )
         Break

      ; increment counter and add menu entry
      umCount++
      Menu, TRAY, Add, % umLabel%A_Index%, h_UserMenuHandler

      ; optionally add hotkey
      RegRead, tmp, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|umk%A_Index%
      If ( ( Not ( tmp = "" Or ErrorLevel ) )
             And f_AssignHotkey( tmp, "h_UserMenuHandler" ) )
         umKey%A_Index% := tmp
   }
   If ( umCount > 0 )
      Menu, TRAY, Add

   ; "normal" menu
   Menu, TRAY, Add, %lng_MenuPrefs%, h_MenuHandler
   Menu, TRAY, Add
	Menu, TRAY, Add, %lng_MenuClose%, h_MenuHandler
	Menu, TRAY, Add, %lng_MenuUnhide%, h_MenuHandler
	Menu, TRAY, Default, %lng_MenuUnhide%
	Menu, TRAY, Tip, %h_TrayTitle%
Return

h_UserMenuHandler:
   If ( umCount <= 0 )
      Return
   If ( h_MM ) ; NO action in multi window mode
      Return
   Loop, %umCount% {
      ; fire up the desired TriggerAction
      If ( umLabel%A_Index% = A_ThisMenuItem 
           Or ( umKey%A_Index% And umKey%A_Index% = A_ThisHotkey ) ) {
         Sleep, 75
         ; wait for modifier keys to be released,
         ; avoids popping up of windows start menu
         If ( A_ThisHotkey )
            f_KeyWaitModifier()
         f_TriggerAction( newID1, h_Application "|" h_Class "|uma" A_Index, "__override__", h_MenuWin )
         Break
      }
   }
Return

h_MenuHandler:
   If ( A_ThisMenuItem = lng_MenuUnhide OR A_ThisMenuItem = h_MenuWin )
      Gosub, h_Unhide

   ; do not execute a new command while another one is still showing a GUI
   If ( h_noMenuAction OR h_noGUIAction ) {
      SoundPlay, *16 
      Return
   }

   ; subs creating GUIs, no interference allowed here
   h_noMenuAction := TRUE

   If ( A_ThisMenuItem = lng_MenuClose )
      Gosub, h_Close
   If ( A_ThisMenuItem = lng_MenuPrefs )
      Gosub, h_HelperPrefs

   h_noMenuAction := FALSE
Return

h_MenuHandlerMultiWin:
   ; this routine unhides the selected window
   StringSplit, tmp, A_ThisMenuItem, :%A_Space%, %A_Space%
   h_WinID := newID%tmp1%
   If ( h_WinID = "" )
      Return
   ; unhide this particular window
   WinShow, ahk_id %h_WinID%
   WinRestore, ahk_id %h_WinID%
   WinActivate, ahk_id %h_WinID%
   ; update sub menu
  	Menu, MultiWinMenu, Delete, %A_ThisMenuItem%
   ; remove win ID from list
   newID%tmp1% =
Return

h_HelperPrefs:
   h_noGUIAction := TRUE
   Suspend, On

	; is this window on BossKey list?
	RegRead, h_bkEnabled, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|bk	; app+class on bosskey list?
   If ( ErrorLevel )
      h_bkEnabled := FALSE	; default: nope

	; is this window on startup minimize list?
	RegRead, h_StartupMin, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|sm
   If ( ErrorLevel )
      h_StartupMin := FALSE	; default: nope

   addWinKey =
   chkWin = 0
   newKey = %h_hkKey%

   ; strip off modifier WIN and check the box instead
   If InStr( newKey, "#" ) {
      chkWin = 1
      StringReplace, newKey, newKey, # 
   }
      
   Gui, 2:Default
   Gui, +AlwaysOnTop +LastFound -MinimizeBox -MaximizeBox
   WinGet, hwnd_gui2, ID   ; for h_Change_Icon

   ; --- left hand site
   ; hotkey
   Gui, Add, Text, ym, %lng_SetupUnhideKey%:
   Gui, Add, Checkbox, Section y+8 Checked%chkWin% vaddWinKey, WIN +
   Gui, Add, Hotkey, ys yp-4 w180 vnewKey, %newKey%
   ; hint
   Gui, Add, Text, xm w250 R3, %lng_SetupHint%

   ; custom icon
   Gui, Add, Checkbox, xm Section Checked%h_ciEnabled% vnewCI, %lng_SetupCustomIcon%
   ; custom name
   Gui, Add, Checkbox, Checked%h_cnEnabled% vnewCN gh_CNtextToggle, %lng_SetupCustomName%:
   Gui, Add, Edit, r1 w240 Limit80 vnewCNtext, %h_MenuWin%
   Gosub, h_CNtextToggle

	; disable some options if in MultiWin mode
	If ( h_MM )
   	tmpDis = Disabled
	Else
   	tmpDis =
   ; BossKey
   Gui, Add, Checkbox, %tmpDis% Y+14 Checked%h_bkEnabled% vnewBK, %lng_SetupOnBKList%
   ; startup minimize
   Gui, Add, Checkbox, %tmpDis% Checked%h_StartupMin% vnewSM, %lng_SetupOnSMList%
   ; ShowOnTitleChange
   Gui, Add, Checkbox, %tmpDis% Checked%h_sotcEnabled% vnewSOTC gh_SOTCmToggle, %lng_SetupShowOnTitleChange%
   Gui, Add, Text, %tmpDis%, %lng_SetupSOTCRegEx%
   Gui, Add, Edit, %tmpDis% w240 Limit80 vnewSOTCm, %h_sotcMatch%
   Gosub, h_SOTCmToggle
   ; NoMinimize
   Gui, Add, Checkbox, w250 %tmpDis% Checked%h_nmEnabled% vnewNM, %lng_SetupNoMinimize%
   ; events
   Gui, Add, Button, Y+14 w242 gh_2ButtonEvents, %lng_SetupEventTitleH%

   ; ok + cancel
   Gui, Add, Button, ym Section w90 gh_2ButtonOK Default, %lng_SetupOK%
   Gui, Add, Button, wp g2BtnCancel, %lng_SetupCancel%
   ; special text to prevent BossKey from working
   Gui, Add, Text, wp Hidden, Min2TrayBKnoHide

   Gui, Show, Center, %h_MenuWin% - %lng_SetupTitle%
Return

h_CNtextToggle:
   ; enable/disable "custom name" text field according to checkbox state
   GuiControlGet, isChecked, , newCN
   If ( isChecked )
      GuiControl, Enable, newCNtext
   Else
      GuiControl, Disable, newCNtext
Return

h_SOTCmToggle:
   ; enable or disable RegEx input field according to checkbox state
   GuiControlGet, isChecked, , newSOTC
   If ( isChecked )
      GuiControl, Enable, newSOTCm
   Else
      GuiControl, Disable, newSOTCm
Return

h_2ButtonOK:
   Gui, +OwnDialogs
   Gui, Submit, NoHide

   ; unhide key
   h_hkKey := f_ComposeHotkey( newKey, addWinKey, h_hkKey, "h_Unhide", "", h_Application "|" h_Class "|ch", lng_SetupUnhideKey )
   If ( h_hkKey = "__invalid__" )
      Return

	; show-on-title-change
	If ( newSOTC ) {
		h_sotcEnabled := TRUE
		h_sotcMatch := newSOTCm
		RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|sotc, %h_sotcMatch%
	} Else {
		h_sotcEnabled := FALSE
		h_sotcMatch =
		RegDelete, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|sotc
	}
	; NoMinimize
	If ( newNM ) {
		h_nmEnabled := TRUE
		RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|nm, %h_nmEnabled%
	} Else {
		h_nmEnabled := FALSE
		RegDelete, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|nm
	}
	; remove from/add to bosskey list
	If ( newBK ) {
		h_bkEnabled := TRUE
		RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|bk, %h_bkEnabled%
	} Else {
		h_bkEnabled := FALSE
		RegDelete, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|bk
		RegDelete, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|bk_wt
	}
	; remove from/add to startup minimize list
	If ( newSM ) {
		h_StartupMin := TRUE
		RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|sm, %h_StartupMin%
	} Else {
		h_StartupMin := FALSE
		RegDelete, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|sm
		RegDelete, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|sm_wt
	}
   ; custom icon
   If ( newCI And !h_ciEnabled )
      Gosub, h_ChangeIcon
   Else If ( !newCI And h_ciEnabled )
      Gosub, h_RemoveIcon
   ; custom name
   If ( newCN And ( !h_cnEnabled Or newCNtext <> h_MenuWin ) ) {
      If ( StrLen( newCNtext ) > 0 ) {
         h_appName := f_StringLeft( newCNtext )
         RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|cn, %h_appName%
         If ( Not m2t_JaakonMode )
            Gosub, h_SetMenu
      }
   } Else If ( !newCN And h_cnEnabled ) {
      RegDelete, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|cn
      If ( Not ErrorLevel ) {
         m2t_JaakonMode := FALSE   ; disable Jaakon's Mode to set script built name
         Gosub, h_SetMenu
      }
   }
   
   Goto, 2GuiClose      
Return

2BtnCancel:
2GuiEscape:
2GuiClose:
   ; clean up window, etc.
   Gui, 2:Destroy
   Suspend, Off
   h_noGUIAction := FALSE
Return

; ---------------------------- gui 5 for events -------------------------
h_2ButtonEvents:
   WinGet, lastUsedWin, ID
   Gui, +Disabled
   Gui, 5:Default
   Gui, +Owner2 +ToolWindow

   tmpEVreg1 := h_Application "|" h_Class "|hide_ea"
   tmpEVreg2 := h_Application "|" h_Class "|unhide_eb"
   tmpEVreg3 := h_Application "|" h_Class "|close_eb"
   tmpEVreg4 := h_Application "|" h_Class "|exit_eb"
   tmpEVreg5 := h_Application "|" h_Class "|sotc_ea"
   tmpEVreg6 := h_Application "|" h_Class "|jta_e"

   ; are we in MultiWin mode
   If ( h_MM )
      countEV = 5 ; yes -> hide JustTriggerAction
   Else
      countEV = 6 ; no -> show all

   Loop, %countEV% {
      tmpEVreg = tmpEVreg%A_Index%
      tmpEVlng := lng_SetupEvent%A_Index%
      Gui, Add, Text, w340, %tmpEVlng%:
      Gui, Add, Edit, w330 Limit255 vnewEV%A_Index%, % f_TriggerAction( "", %tmpEVreg%, "", "__readout__")
   }

   ; ok + cancel
   Gui, Add, Button, ym Section w90 g5ButtonOK Default, %lng_SetupOK%
   Gui, Add, Button, wp g5BtnCancel, %lng_SetupCancel%
   ; hint
   Gui, Add, Text, xm w440, %lng_SetupEventHint1%
   Gui, Add, Edit, w440 r8 ReadOnly, %lng_SetupEventHint2%

   Gui, Show, Center, %h_MenuWin% - %lng_SetupEventTitleH%
Return

5ButtonOK:
   Gui, +OwnDialogs
   Gui, Submit, NoHide

   Loop, %countEV% {
      tmpEV = newEV%A_Index%
      If f_TriggerAction( "", %tmpEV%, "__parse__" ) {
         tmpEVreg := tmpEVreg%A_Index%   ; get content of values!
         tmpEV := %tmpEV%
         tmpEV = %tmpEV%   ; auto-trim variable!
         If ( tmpEV = "" )
            RegDelete, HKCU, %h_RegSubkey%, %tmpEVreg%
         Else
            RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %tmpEVreg%, %tmpEV%
      } Else {
         tmpEVlng := lng_SetupEvent%A_Index%
         Msgbox, 48, %h_MenuWin% - %lng_SetupEventTitleH%, %lng_SetupEventError%`n"%tmpEVlng%".
         Return
      }
   }   

   Goto, 5GuiClose
Return

5BtnCancel:
5GuiEscape:
5GuiClose:
   WinActivate, ahk_id %lastUsedWin%
   Gui, 5:Destroy
   Gui, 2:Default
   Gui, -Disabled
Return

h_ChangeName:
	SysGet, tmp, 15	; caption height - for rough computation of dialog height
	tmp *= 7	; old hardcoded default height was: 125
   InputBox, h_appName, %h_MenuWin% - %lng_WindowTitle%, %lng_ChangeNameSelector%, , , %tmp%, , , , , %h_MenuWin%
   If ( Not ErrorLevel ) {
      StringLen, tmp, h_appName
      If ( tmp < 1 )
         Return

      h_appName := f_StringLeft( h_appName )
      RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|cn, %h_appName%

      If ( Not m2t_JaakonMode )
         Gosub, h_SetMenu
   }
   ; ... returns with ErrorLevel still set - needed by h_SetMenu
Return

h_ChangeIcon:
   If FileExist( h_appExe ) {
      tmpFile  := h_appExe
      tmpIndex := h_appExeIcon
   } Else {
      tmpFile  := h_StarterIcon
      tmpIndex := 1
   } 

   If Not Dlg_Icon( tmpFile, tmpIndex, hwnd_gui2)
      Return

   h_appExe     := tmpFile
   h_appExeIcon := tmpIndex
   RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|ci, %h_appExe%|%h_appExeIcon%

   Gosub, h_SetTray
Return

h_RemoveIcon:
   Gui, +OwnDialogs

   RegDelete, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|ci
   If ( ErrorLevel )
      Return

   Gosub, h_SetTray
Return

;----------------------------------------------------------------------------
; Helper error -- subs
;

h_ExitWithParamError:
   f_ShowErrorMsg( lng_ExitWithParamError )
ExitApp, 1

;-----------------------------------------------------------------------------
; Helper functions
;

Dlg_Icon(ByRef Icon, ByRef Index, hGui=0) {      
   /*
   (c) by majkinetor
   see: <http://code.google.com/p/mm-autohotkey/>
   Parameters:
   		Icon	- Default icon resource, output.
   		Index	- Default index within resource, output.
   		hGui	- Optional handle of the parent GUI.
   Returns:
   		False if user canceled the dialog or if error occurred 
   */
   VarSetCapacity(wIcon, 1025, 0), wIcon := Icon
	if !A_IsUnicode
	    If (Icon) && !DllCall("MultiByteToWideChar", "UInt", 0, "UInt", 0, "Str", Icon, "Int", StrLen(Icon), "UInt", &wIcon, "Int", 1025) 
			return false

	adrPickIconDlg := DllCall("GetProcAddress", "Uint", DllCall("LoadLibrary", "str", "shell32.dll"), "Uint", 62)
	r := DllCall(adrPickIconDlg, "uint", hGui, "str", wIcon, "uint", 1025, "intp", --Index)
	IfEqual, r, 0, return false
	Index++

	if !A_IsUnicode
	{	
		VarSetCapacity(Icon, len := DllCall("lstrlenW", "UInt", &wIcon) ) 
		r := DllCall("WideCharToMultiByte" , "UInt", 0, "UInt", 0, "UInt", &wIcon, "Int", len, "Str", Icon, "Int", len, "UInt", 0, "UInt", 0) 
		IfEqual, r, 0, return false
	} else VarSetCapacity(wIcon, -1), Icon := wIcon
	
   Return True 
}

;============================================================================
; launcher for minimizing (starter) starts here

;----------------------------------------------------------------------------
; Starter -- init
;

h_InitStarter:
   whoami := "starter"
   f_SetLanguage( whoami )

   ; lockfile checking
   m2t_lockFileName = %A_Temp%\Min2Tray.lck
   
   IniRead, m2t_chkName, %m2t_lockFileName%, M2Tlock, Name
   IniRead, m2t_chkPID, %m2t_lockFileName%, M2Tlock, PID
   IniRead, m2t_chkDate, %m2t_lockFileName%, M2Tlock, Date

   If ( ( m2t_chkName <> "ERROR" ) And ( m2t_chkPID <> "ERROR" ) And ( m2t_chkDate <> "ERROR" ) ) {
      Process, Exist, %m2t_chkPID%			; PID still existing...
      If ( ErrorLevel ) {
      	Process, Exist, %m2t_chkName%		; and name still existing
      	If ( ErrorLevel )
      		Goto, ExitWithRunningError	; error&exit
      }
   }

   ; check existence of AutoHotkey.exe 
   If ( Not A_IsCompiled ) {
      h_ahkFullPath = %A_AhkPath%
      IfNotExist, %h_ahkFullPath%
     	   Goto, ExitWithAHKError
   }

   ; disable mouse support if less than 2 buttons avail.
	m2t_noMButton := FALSE
	m2t_noRButton := FALSE
	SysGet, tmp, 43
   If ( tmp < 3 ) {
      m2t_noMButton := TRUE
   }
   If ( tmp < 2 ) {
      f_ShowErrorMsg( lng_No2BtnMouseMsg )
      m2t_noRButton := TRUE
   }

   ; values needed for f_StartNewHelper()
   ; - if altered while M2T is running, restart is required
   ; - these values are only correct for non-small captions
   CoordMode, Mouse, Relative
   SysGet, h_BorderWidth, 32	; SM_CXSIZEFRAME
   SysGet, h_BorderHeight, 33	; SM_CYSIZEFRAME
   SysGet, h_CaptionHeight, 4	; SM_CYCAPTION
   SysGet, h_ButtonWidth, 30	; SM_CXSIZE
   If A_OSVersion in WIN_7,WIN_VISTA,WIN_2003
   {  ; estimated button width for Windows after XP
      h_ButtonWidth := Ceil(h_ButtonWidth * 1.3)
   }
   h_BorderButtonWidth   := h_BorderWidth + h_ButtonWidth
   h_BorderCaptionHeight := h_CaptionHeight + h_BorderHeight

   h_helperPIDs :=	; h_helperPIDs%h_hPIDcount% -- array for PIDs of started helpers
   h_hPIDcount  := 0

   Menu, TRAY, NoStandard
   Menu, TRAY, Add, %lng_MenuAbout%, m2t_MenuHandler
   Menu, TRAY, Add
   Menu, TRAY, Add, %lng_MenuBKEditList%, m2t_MenuHandler
   Menu, TRAY, Add, %lng_MenuSMEditList%, m2t_MenuHandler
   Menu, TRAY, Add, %lng_MenuPrefs%, m2t_MenuHandler
   Menu, TRAY, Add
   Menu, TRAY, Add, %lng_MenuRestoreOnly%, m2t_MenuHandler
   Menu, TRAY, Add, %lng_MenuQuitRestoreAll%, m2t_MenuHandler
   Menu, TRAY, Add, %lng_MenuQuitOnly%, m2t_MenuHandler
   Menu, TRAY, Tip, %lng_TrayTitle%

   ; --- assigning keys
   ; key for minimizing
   m2t_hkKey =
   RegRead, m2t_hkKey, HKCU, %h_RegSubkey%\Starter, HotkeyMinimize
   f_AssignHotkey( m2t_hkKey, "h_StartNewHelperHOTKEY" )
   ; stealthmode key
   m2t_hkStealth =
	RegRead, m2t_hkStealth, HKCU, %h_RegSubkey%\Starter, HotkeyStealth
	If ( ErrorLevel OR m2t_hkStealth = "" )
	   m2t_hkStealth = ^#!PgUp   ; default: Ctrl+Win+Alt+PgUp
	f_AssignHotkey( m2t_hkStealth, "h_StealthModeToggle" )
	; get bosskey mode
	RegRead, bkMode, HKCU, %h_RegSubkey%\Misc, BossKeyMode
	If bkMode not in 0,1,2
	   bkMode := 0  ; 0 = Blacklist, 1 = Whitelist, 2 = Topmost
   ; bosskey
   m2t_hkBossKey =
	RegRead, m2t_hkBossKey, HKCU, %h_RegSubkey%\Starter, HotkeyBossKey
	f_AssignHotkey( m2t_hkBossKey, "h_BossKey" )
   ; BossKeyListToggleWin key
   m2t_hkBKAdd =
	RegRead, m2t_hkBKAdd, HKCU, %h_RegSubkey%\Starter, HotkeyBossKeyAdd
	f_AssignHotkey( m2t_hkBKAdd, "h_BossKeyListToggleWin" )
   ; CTRL+SHIFT+MButton (or user defined) for BossKeyListToggleWin?
   If ( m2t_noMButton )
      m2t_BKAddMouse := FALSE
   Else {
      ; 3-button-mouse available
      tmp =
   	RegRead, tmp, HKCU, %h_RegSubkey%\Starter, HotkeyBossKeyAddMouse
      If f_AssignHotkey( tmp, "h_BossKeyListToggleWin" )
         m2t_BKAddMouse := TRUE
      Else
         m2t_BKAddMouse := FALSE
   }
   ; maximizer keys
   m2t_hkYMax =
	RegRead, m2t_hkYMax, HKCU, %h_RegSubkey%\Starter, HotkeyYMax
	f_AssignHotkey( m2t_hkYMax, "h_YMaxWindow" )
   m2t_hkXMax =
	RegRead, m2t_hkXMax, HKCU, %h_RegSubkey%\Starter, HotkeyXMax
	f_AssignHotkey( m2t_hkXMax, "h_XMaxWindow" )
   ; always-on-top key
   m2t_hkAOT =
	RegRead, m2t_hkAOT, HKCU, %h_RegSubkey%\Starter, HotkeyAOT
	f_AssignHotkey( m2t_hkAOT, "h_AlwaysOnTop" )
   ; prefs window key
   m2t_hkPrefs =
	RegRead, m2t_hkPrefs, HKCU, %h_RegSubkey%\Starter, HotkeyPrefs
	If ( ErrorLevel OR m2t_hkPrefs = "" )
	   m2t_hkPrefs = ^#!P  ; default: Ctrl+Win+Alt+P
	f_AssignHotkey( m2t_hkPrefs, "m2t_PrefsKeyHandler" )
   ; no-buttons key (toggle sys-menu)
   m2t_hkNoB =
	RegRead, m2t_hkNoB, HKCU, %h_RegSubkey%\Starter, HotkeyNoButtons
	f_AssignHotkey( m2t_hkNoB, "h_NoButtons" )
   ; middle mouse button
   If ( m2t_noMButton )
      m2t_hkMButton = 0 ; no 3-button-mouse avail.
   Else {
	   RegRead, m2t_hkMButton, HKCU, %h_RegSubkey%\Starter, HotkeyMButton
	   If ( ErrorLevel )    ; no reg key: set default value
         m2t_hkMButton = 1 ; click on title with 3rd button
	   If ( m2t_hkMButton = 1 OR m2t_hkMButton = 2 )
	      f_AssignHotkey( "~MButton", "h_StartNewHelperMMOUSE" )
   }
   ; right mouse on close button minimizes window
   If ( m2t_noRButton )
      m2t_hkRButton = 0 ; no 2-button-mouse avail. (Mac, anyone?)
   Else {
      RegRead, m2t_hkRButton, HKCU, %h_RegSubkey%\Starter, HotkeyRButton
      If ( m2t_hkRButton = 1 )
         f_AssignHotkey( "~RButton", "h_StartNewHelperRMOUSE" )
      Else
         m2t_hkRButton = 0    ; default: no right click on close
   }
   ; bosskey MultiWin mode
	RegRead, m2t_BkMultiWin, HKCU, %h_RegSubkey%\Starter, BossKeyMultiWin
	If ( m2t_BkMultiWin )
	   m2t_BkMultiWin := TRUE
	Else
      m2t_BkMultiWin := FALSE
   ; bosskey to stealth mode
	RegRead, m2t_Bk2sMode, HKCU, %h_RegSubkey%\Starter, BossKeyToStealth
	If ( m2t_Bk2sMode )
	   m2t_Bk2sMode := TRUE
	Else
      m2t_Bk2sMode := FALSE
   ; stealth mode current session only
	RegRead, m2t_SmSessOnly, HKCU, %h_RegSubkey%\Starter, StealthSessionOnly
	If ( m2t_SmSessOnly OR ErrorLevel )
	   m2t_SmSessOnly := TRUE    ; default: YES
	Else
      m2t_SmSessOnly := FALSE
   Gosub, h_UpdateSessionOnlyState
   ; forced mode
	RegRead, m2t_ForcedMode, HKCU, %h_RegSubkey%\Starter, ForcedMode
	If ( m2t_ForcedMode )
	   m2t_ForcedMode := TRUE
	Else
      m2t_ForcedMode := FALSE
   ; show no error messages mode
	RegRead, m2t_NoErrorMsgs, HKCU, %h_RegSubkey%\Misc, NoErrorMessages
	If ( m2t_NoErrorMsgs )
	   m2t_NoErrorMsgs := TRUE
	Else
	   m2t_NoErrorMsgs := FALSE
   ; globally enable events
	RegRead, m2t_EventsEnabled, HKCU, %h_RegSubkey%\Misc, EventsEnabled
	If ( m2t_EventsEnabled )
	   m2t_EventsEnabled := TRUE
	Else
	   m2t_EventsEnabled := FALSE
   ; startup minimizing
	RegRead, m2t_StartupTimeSpan, HKCU, %h_RegSubkey%\Starter, StartupMinTimeSpan
	If ( ErrorLevel OR m2t_StartupTimeSpan < 1 OR m2t_StartupTimeSpan > 100000 )
		m2t_StartupTimeSpan = 25
	RegRead, m2t_StartupInterval, HKCU, %h_RegSubkey%\Starter, StartupMinInterval
	If ( ErrorLevel OR m2t_StartupInterval < 200 OR m2t_StartupInterval > 10000 )
		m2t_StartupInterval = 2000
	RegRead, m2t_StartupEnabled, HKCU, %h_RegSubkey%\Starter, StartupMinEnabled
	If ( m2t_StartupEnabled ) {
	   m2t_StartupEnabled := TRUE
	   SetTimer, m2t_StartupMinCheck, %m2t_StartupInterval%
	   SetTimer, m2t_StartupMinOff, %m2t_StartupTimeSpan%000   ; *1000
	} Else
      m2t_StartupEnabled := FALSE

   ; create temporary lockfile
   m2t_ownPID := DllCall("GetCurrentProcessId")
   WinGet, m2t_ownName, ProcessName, ahk_pid %m2t_ownPID%
   
   IniWrite, %m2t_ownName%, %m2t_lockFileName%, M2Tlock, Name
   IniWrite, %m2t_ownPID%, %m2t_lockFileName%, M2Tlock, PID
   IniWrite, %A_Now%, %m2t_lockFileName%, M2Tlock, Date

	OnExit, h_QuitStarter
   Gosub, m2t_SetTimedCheck
   f_ShowTrayIcon( h_StarterIcon, h_StarterIcon# )

   ; --- modifiy registry settings
   ; remove orphaned keys
   RegDelete, HKCU, %h_RegSubkey%\Misc, BossKeyOptIn
Return

m2t_SetTimedCheck:
   ; get interval from registry, if any
	RegRead, tmp, HKCU, %h_RegSubkey%\Misc, CheckForWinEveryMiliSec
	If ( ErrorLevel OR tmp < 200 OR tmp > 10000 )
		tmp = 2000
	SetTimer, m2t_CheckForWin, %tmp%
Return

m2t_CheckForWin:
   ; redraw Starter tray, if changed (for StealthMode)
   f_ShowTrayIcon( h_StarterIcon, h_StarterIcon# )
Return

m2t_StartupMinCheck:
   ; when called scan thru registry entries of windows to be minimized
   ; (the entries will have "|sm" at the end)
   ; make use of the f_BossKey() function to do the job right(TM)
   f_BossKey( "sm" )
Return

m2t_StartupMinOff:
   SetTimer, m2t_StartupMinCheck, Off
   SetTimer, m2t_StartupMinOff, Off
Return

m2t_PrefsKeyHandler:
   ; this is the jump-in for prefs hotkey
   tmpMI = %lng_MenuPrefs%
   ; a bit ugly, but alas...
   Goto, m2t_MenuHandlerDo

m2t_MenuHandler:
   ; this is the jump-in for tray events
   tmpMI = %A_ThisMenuItem%
   ; here starts the real work:
m2t_MenuHandlerDo:
   If ( tmpMI = lng_MenuRestoreOnly )
      Gosub, h_RestoreStarter

   ; do not execute a new command while another one is still showing a GUI
   If ( m2t_noMenuAction OR m2t_noGUIAction ) {
      SoundPlay, *16 
      Return
   }

   ; subs creating GUIs, no interference allowed here
   m2t_noMenuAction := TRUE
   
   If ( tmpMI = lng_MenuAbout )
      Gosub, h_AboutStarter
   If ( tmpMI = lng_MenuBKEditList )
      Gosub, h_BossKeyPurgeList
   If ( tmpMI = lng_MenuSMEditList )
      Gosub, h_StartupMinPurgeList
   If ( tmpMI = lng_MenuPrefs )
      Gosub, h_SetHotkeyStarter
   If ( tmpMI = lng_MenuQuitRestoreAll )
      Gosub, h_QuitRestoreStarter
   If ( tmpMI = lng_MenuQuitOnly )
      Gosub, h_QuitStarter

   m2t_noMenuAction := FALSE
Return

h_StartNewHelperHOTKEY:
   f_StartNewHelper( "ASAP" )
Return

h_StartNewHelperMMOUSE:
   If ( m2t_hkMButton = 1 )  ; check for titlebar click?
      f_StartNewHelper( "MMOUSE" )
   Else
      f_StartNewHelper( "ASAP" )
Return

h_StartNewHelperRMOUSE:
   If ( m2t_hkRButton = 1 )
      f_StartNewHelper( "RMOUSE" )
Return

h_AboutStarter:
   Msgbox, 64, %lng_WindowTitle%, %lng_About%
Return

h_RestoreStarter:
	; close all helpers -> unhide every window
   Loop {
      If ( h_hPIDcount = 0 )
      	Break
      h_process := h_helperPIDs%h_hPIDcount%
      Process, Exist, %h_process%
      If ( ErrorLevel ) {
      	; helper still exists
      	WinClose, ahk_pid %h_process%
      }
      h_hPIDcount--
      Sleep, 50
   }
Return

h_QuitRestoreStarter:
   Gosub, h_RestoreStarter
   ; ...
h_QuitStarter:
   Gosub, h_UpdateSessionOnlyState
   Gosub, h_CleanUpLockFile
ExitApp

h_UpdateSessionOnlyState:
   If ( m2t_SmSessOnly )
      f_StealthMode( "OFF" )
Return

h_CleanUpLockFile:
   IfNotExist, %m2t_lockFileName%
      Return
   
   FileDelete, %m2t_lockFileName%
   If ( ErrorLevel ) {
      FileSetAttrib, -RHS, %m2t_lockFileName%	; one more try...
      FileDelete, %m2t_lockFileName%
      If ( ErrorLevel ) {
      	; f_ck it! and exit with code "2"
         tmp = %lng_ExitWithLockError% "%m2t_lockFileName%".
         f_ShowErrorMsg( tmp )
      	ExitApp, 2
      }
   }
Return

h_SetHotkeyStarter:
   m2t_noGUIAction := TRUE
   Suspend, On

   chkWinHK  = 0
   chkWinBK  = 0
   chkWinBKA = 0
   chkWinSK  = 0
   chkWinAK  = 0
   chkWinPK  = 0
   chkWinYK  = 0
   chkWinXK  = 0
   chkWinNK  = 0
   newKey         = %m2t_hkKey%
   newBossKey     = %m2t_hkBossKey%
   newBKAdd       = %m2t_hkBKAdd%
   newStealthKey  = %m2t_hkStealth%
   newAOTKey      = %m2t_hkAOT%
   newPrefsKey    = %m2t_hkPrefs%
   newYMaxKey     = %m2t_hkYMax%
   newXMaxKey     = %m2t_hkXMax%
   newNoBKey      = %m2t_hkNoB%

   ; strip off modifier WIN from hotkey and check the box instead
   If InStr( newKey, "#" ) {
      chkWinHK = 1
      StringReplace, newKey, newKey, # 
   }
   ; strip off modifier WIN from bosskey and check the box instead
   If InStr( newBossKey, "#" ) {
      chkWinBK = 1
      StringReplace, newBossKey, newBossKey, # 
   }
   ; strip off modifier WIN from BossKeyListToggle and check the box instead
   If InStr( newBKAdd, "#" ) {
      chkWinBKA = 1
      StringReplace, newBKAdd, newBKAdd, # 
   }
   ; strip off modifier WIN from stealth-key and check the box instead
   If InStr( newStealthKey, "#" ) {
      chkWinSK = 1
      StringReplace, newStealthKey, newStealthKey, # 
   }
   ; strip off modifier WIN from AOT-key and check the box instead
   If InStr( newAOTKey, "#" ) {
      chkWinAK = 1
      StringReplace, newAOTKey, newAOTKey, # 
   }
   ; strip off modifier WIN from Prefs key and check the box instead
   If InStr( newPrefsKey, "#" ) {
      chkWinPK = 1
      StringReplace, newPrefsKey, newPrefsKey, # 
   }
   ; strip off modifier WIN from Max-keys and check the box instead
   If InStr( newYMaxKey, "#" ) {
      chkWinYK = 1
      StringReplace, newYMaxKey, newYMaxKey, # 
   }
   If InStr( newXMaxKey, "#" ) {
      chkWinXK = 1
      StringReplace, newXMaxKey, newXMaxKey, #
   }
   ; strip off modifier WIN from no-buttons key and check the box instead
   If InStr( newNoBKey, "#" ) {
      chkWinNK = 1
      StringReplace, newNoBKey, newNoBKey, # 
   }

   Gui, +AlwaysOnTop -MinimizeBox -MaximizeBox +LastFound
   ; --- left hand site
   ; hint
   Gui, Add, Text, ym w250 R3 Section, %lng_SetupHint% 
   ; hotkey + mbutton + forcedmode
   Gui, Add, Text, xs Section, %lng_SetupKey%:
   Gui, Add, Checkbox, Section y+8 Checked%chkWinHK% vaddWinKeyHK, WIN +
   Gui, Add, Hotkey, ys yp-4 w180 vnewKey, %newKey%
   ; bosskey
   Gui, Add, Text, xs Y+14 Section, %lng_SetupBossKey%:
   Gui, Add, Checkbox, Section y+8 Checked%chkWinBK% vaddWinKeyBK, WIN +
   Gui, Add, Hotkey, ys yp-4 w180 vnewBossKey, %newBossKey%
   ; BossKeyListToggle
   Gui, Add, Text, xs Y+14 Section, %lng_SetupBKListToggle%:
   Gui, Add, Checkbox, Section y+8 Checked%chkWinBKA% vaddWinKeyBKA, WIN +
   Gui, Add, Hotkey, ys yp-4 w180 vnewBKAdd, %newBKAdd%
   ; stealth-key
   Gui, Add, Text, xs Y+14 Section, %lng_SetupStealthKey%:
   Gui, Add, Checkbox, Section y+8 Checked%chkWinSK% vaddWinKeySK, WIN +
   Gui, Add, Hotkey, ys yp-4 w180 vnewStealthKey, %newStealthKey%
   ; Max-keys
   Gui, Add, Text, xs Y+14 Section, %lng_SetupYMaxKey%:
   Gui, Add, Checkbox, Section y+8 Checked%chkWinYK% vaddWinKeyYK, WIN +
   Gui, Add, Hotkey, ys yp-4 w180 vnewYMaxKey, %newYMaxKey%
   Gui, Add, Text, xs Y+14 Section, %lng_SetupXMaxKey%:
   Gui, Add, Checkbox, Section y+8 Checked%chkWinXK% vaddWinKeyXK, WIN +
   Gui, Add, Hotkey, ys yp-4 w180 vnewXMaxKey, %newXMaxKey%
   ; no-buttons key
   Gui, Add, Text, xs Y+14 Section, %lng_SetupNoBKey%:
   Gui, Add, Checkbox, Section y+8 Checked%chkWinNK% vaddWinKeyNK, WIN +
   Gui, Add, Hotkey, ys yp-4 w180 vnewNoBKey, %newNoBKey%
   ; AOT-key
   Gui, Add, Text, xs Y+14 Section, %lng_SetupAOTKey%:
   Gui, Add, Checkbox, Section y+8 Checked%chkWinAK% vaddWinKeyAK, WIN +
   Gui, Add, Hotkey, ys yp-4 w180 vnewAOTKey, %newAOTKey%
   ; Show-Prefs-hotkey
   Gui, Add, Text, xs Y+14 Section, %lng_SetupPrefsKey%:
   Gui, Add, Checkbox, Section y+8 Checked%chkWinPK% vaddWinKeyPK, WIN +
   Gui, Add, Hotkey, ys yp-4 w180 vnewPrefsKey, %newPrefsKey%
   ; startup minimize
   Gui, Add, Checkbox, xs y+36 Section vnewStartupEnabled Checked%m2t_StartupEnabled%
   Gui, Add, Button,   ys-18 x+0 w220 gh_ButtonStartup, %lng_SetupStartupEnable%
   ; --- right hand site
   ; mbutton options
   If ( m2t_noMButton ) ; disable controls if no 3-button-mouse
		tmpDis = Disabled
	Else
   	tmpDis =
   tmp0 = 0
   tmp1 = 0
   tmp2 = 0
   tmp%m2t_hkMButton% = 1 ; check the active radiobox
   Gui, Add, Text, ym Section w250 %tmpDis%, %lng_SetupMButtonTitle%
   Gui, Add, Radio, w230 vnewMButton0 %tmpDis% Checked%tmp0%, %lng_SetupMButtonOpt0%
   Gui, Add, Radio, w230 vnewMButton1 %tmpDis% Checked%tmp1%, %lng_SetupMButtonOpt1%
   Gui, Add, Radio, w230 vnewMButton2 %tmpDis% Checked%tmp2%, %lng_SetupMButtonOpt2%
   ; rbutton click on close on/off
   If ( m2t_noRButton ) ; disable controls if no 2-button-mouse
		tmpDis = Disabled
	Else
   	tmpDis =
   Gui, Add, Checkbox, Y+10 w250 vnewRButton %tmpDis% Checked%m2t_hkRButton%, %lng_SetupRButton%
   ; bosskey options
   tmp0 = 0
   tmp1 = 0
   tmp2 = 0
   tmp%bkMode% = 1 ; check the active radiobox
   Gui, Add, Text, w250 Y+10, %lng_SetupBKTitle%
   Gui, Add, Radio, w230 vnewBKmode0 Checked%tmp0%, %lng_SetupBKOpt0%
   Gui, Add, Radio, w230 vnewBKmode1 Checked%tmp1%, %lng_SetupBKOpt1%
   Gui, Add, Radio, w230 vnewBKmode2 Checked%tmp2%, %lng_SetupBKOpt2%
   ; on/off options
   Gui, Add, Checkbox, Section Y+10 w250 vnewBKAddMouse %tmpDis% Checked%m2t_BKAddMouse%, %lng_SetupBKAddMouse%
   Gui, Add, Checkbox, w250 vnewBkMultiWin Checked%m2t_BkMultiWin%, %lng_SetupBkMultiWin%
   Gui, Add, Checkbox, w250 vnewBk2sMode Checked%m2t_Bk2sMode%, %lng_SetupBk2sMode%
   Gui, Add, Checkbox, w250 vnewSmSessOnly Checked%m2t_SmSessOnly%, %lng_SetupStealthSessOnly%
   Gui, Add, Checkbox, w250 vnewForcedMode Checked%m2t_ForcedMode%, %lng_SetupForcedMode%
   Gui, Add, Checkbox, w250 vnewNoMinGlobal Checked%m2t_NoMinGlobal%, %lng_SetupNoMinGlobal%
   Gui, Add, Checkbox, w250 vnewJaakonMode Checked%m2t_JaakonMode%, %lng_SetupJaakonMode%
   ; set AOT transparency
   tmp0 := TRUE
	RegRead, trans, HKCU, %h_RegSubkey%\Starter, TransparentAOT
   If ( trans < 1 Or trans > 255 ) {
      trans = 225 ; default to moderate transparency
      tmp0 := FALSE
   }
   Gui, Add, Checkbox, w250 vnewTransChk gh_AOTtransToggle Checked%tmp0%, %lng_SetupAOTSlider1%
   Gui, Add, Text, xs y+8 w20 vTransText1, %lng_SetupAOTSlider2%
   Gui, Add, Slider, yp-4 x+5 w128 vnewTransVal Invert Range1-256 Center NoTicks Line1 Page16, %trans%
   Gui, Add, Text, yp+4 x+5 w20 vTransText2, %lng_SetupAOTSlider3%
   Gosub, h_AOTtransToggle
   ; on/off options (cont.)
   tmp0 := m2t_clickCount - 1
   Gui, Add, Checkbox, xs w250 vnewClick2Mode Checked%tmp0%, %lng_SetupClick2Mode%
   Gui, Add, Checkbox, w250 vnewNoErrorMsgs Checked%m2t_NoErrorMsgs%, %lng_SetupNoErrorMsgsMode%
   Gui, Add, Checkbox, w250 vnewEventsEnabled Checked%m2t_EventsEnabled%, %lng_SetupEventEnable%
   ; trigger actions for bosskey
   Gui, Add, Button, y+14 w242 gh_ButtonEvents, %lng_SetupEventTitleBK%

   ; --- ok + cancel
   Gui, Add, Button, ym Section w90 gh_ButtonOK Default, %lng_SetupOK%
   Gui, Add, Button, wp gBtnCancel, %lng_SetupCancel%
   ; special text to prevent BossKey from working
   Gui, Add, Text, wp Hidden, Min2TrayBKnoHide
   
   Gui, Show, Center, %lng_SetupTitle%
Return

h_AOTtransToggle:
   ; enable/disable transparency slider according to checkbox state
   GuiControlGet, isChecked, , newTransChk
   If ( isChecked )
      action = Enable
   Else
      action = Disable
   GuiControl, %action%, TransText1
   GuiControl, %action%, TransText2
   GuiControl, %action%, newTransVal
Return

h_ButtonOK:
   Gui, +OwnDialogs
   Gui, Submit, NoHide

   ; hotkey for minimizing
   m2t_hkKey := f_ComposeHotkey( newKey, addWinKeyHK, m2t_hkKey, "h_StartNewHelperHOTKEY", "Starter", "HotkeyMinimize", lng_SetupKey )
   If ( m2t_hkKey = "__invalid__" )
      Return

   ; hotkey for always-on-top
   m2t_hkAOT := f_ComposeHotkey( newAOTKey, addWinKeyAK, m2t_hkAOT, "h_AlwaysOnTop", "Starter", "HotkeyAOT", lng_SetupAOTKey )
   If ( m2t_hkAOT = "__invalid__" )
      Return

   ; hotkey for preferences window
   m2t_hkPrefs := f_ComposeHotkey( newPrefsKey, addWinKeyPK, m2t_hkPrefs, "m2t_PrefsKeyHandler", "Starter", "HotkeyPrefs", lng_SetupPrefsKey )
   If ( m2t_hkPrefs = "__invalid__" )
      Return

   ; hotkeys for maximizing
   m2t_hkYMax := f_ComposeHotkey( newYMaxKey, addWinKeyYK, m2t_hkYMax, "h_YMaxWindow", "Starter", "HotkeyYMax", lng_SetupYMaxKey )
   If ( m2t_hkYMax = "__invalid__" )
      Return
   m2t_hkXMax := f_ComposeHotkey( newXMaxKey, addWinKeyXK, m2t_hkXMax, "h_XMaxWindow", "Starter", "HotkeyXMax", lng_SetupXMaxKey )
   If ( m2t_hkXMax = "__invalid__" )
      Return

   ; hotkey for no-buttons
   m2t_hkNoB := f_ComposeHotkey( newNoBKey, addWinKeyNK, m2t_hkNoB, "h_NoButtons", "Starter", "HotkeyNoButtons", lng_SetupNoBKey )
   If ( m2t_hkNoB = "__invalid__" )
      Return

   ; hotkey for stealth mode
   m2t_hkStealth := f_ComposeHotkey( newStealthKey, addWinKeySK, m2t_hkStealth, "h_StealthModeToggle", "Starter", "HotkeyStealth", lng_SetupStealthKey )
   If ( m2t_hkStealth = "__invalid__" )
      Return

   ; bosskey
   m2t_hkBossKey := f_ComposeHotkey( newBossKey, addWinKeyBK, m2t_hkBossKey, "h_BossKey", "Starter", "HotkeyBossKey", lng_SetupBossKey )
   If ( m2t_hkBossKey = "__invalid__" )
      Return

   ; BossKeyListToggleWin
   m2t_hkBKAdd := f_ComposeHotkey( newBKAdd, addWinKeyBKA, m2t_hkBKAdd, "h_BossKeyListToggleWin", "Starter", "HotkeyBossKeyAdd", lng_SetupBKListToggle )
   If ( m2t_hkBKAdd = "__invalid__" )
      Return

   ; bosskey mode
   If ( newBKmode2 )
      bkMode := 2   ; topmost
   Else If ( newBKmode1 )
      bkMode := 1   ; opt-in
   Else
      bkMode := 0   ; default: Blacklist 
   RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Misc, BossKeyMode, %bkMode%

   ; mbutton mode
   If ( Not m2t_noMButton ) {
	   If ( newMButton1 ) ; title-click
	      m2t_hkMButton := 1
	   Else If ( newMButton2 ) ; just third mouse button
	      m2t_hkMButton := 2
	   Else ; set mbutton-action off
	      m2t_hkMButton := 0 
	   If ( m2t_hkMButton = 1 OR m2t_hkMButton = 2 )
	      f_AssignHotkey( "~MButton", "h_StartNewHelperMMOUSE" )
	   Else ; set mbutton-action off
	      f_AssignHotkey( "~MButton" )
	   RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, HotkeyMButton, %m2t_hkMButton%
	}

   ; rbutton click on close
   If ( Not m2t_noRButton ) {
      m2t_hkRButton = 0
      If ( newRButton ) {
         If f_AssignHotkey( "~RButton", "h_StartNewHelperRMOUSE" ) {
         	m2t_hkRButton = 1
   	   	RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, HotkeyRButton, %m2t_hkRButton%
         }
   	} Else {
   		f_AssignHotkey( "~RButton" )
   	   RegDelete, HKCU, %h_RegSubkey%\Starter, HotkeyRButton
      }
   }

   ; CTRL+SHIFT+MButton for BossKeyListToggleWin
   m2t_BKAddMouse := FALSE
   If ( newBKAddMouse ) {
      If f_AssignHotkey( "^+MButton", "h_BossKeyListToggleWin" ) {
	   	RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, HotkeyBossKeyAddMouse, ^+MButton
      	m2t_BKAddMouse := TRUE
      }
	} Else {
		f_AssignHotkey( "^+MButton", "" )
	   RegDelete, HKCU, %h_RegSubkey%\Starter, HotkeyBossKeyAddMouse
   }

   ; bosskey MultiWin mode
	If ( newBkMultiWin )
	   m2t_BkMultiWin := TRUE
	Else
	   m2t_BkMultiWin := FALSE
   RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, BossKeyMultiWin, %m2t_BkMultiWin%

   ; bosskey to stealth mode
	If ( newBk2sMode )
	   m2t_Bk2sMode := TRUE
	Else
	   m2t_Bk2sMode := FALSE
   RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, BossKeyToStealth, %m2t_Bk2sMode%

   ; stealth mode is current session only 
	If ( newSmSessOnly )
	   m2t_SmSessOnly := TRUE
	Else
	   m2t_SmSessOnly := FALSE
   RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, StealthSessionOnly, %m2t_SmSessOnly%

   ; AOT transparency
   If ( newTransChk And newTransVal < 256 And newTransVal >= 1 )
      RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, TransparentAOT, %newTransVal%
   Else
      RegDelete, HKCU, %h_RegSubkey%\Starter, TransparentAOT
   
   ; forced mode
	If ( newForcedMode )
	   m2t_ForcedMode := TRUE
	Else
	   m2t_ForcedMode := FALSE
   RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, ForcedMode, %m2t_ForcedMode%

   ; startup minimizing enabled
	If ( newStartupEnabled )
	   m2t_StartupEnabled := TRUE
	Else
	   m2t_StartupEnabled := FALSE
	RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, StartupMinEnabled, %m2t_StartupEnabled%

   ; NoMinGlobal
	If ( newNoMinGlobal )
	   m2t_NoMinGlobal := TRUE
	Else
	   m2t_NoMinGlobal := FALSE
   RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Misc, NoMinimize, %m2t_NoMinGlobal%

   ; Jaakon's mode
	If ( newJaakonMode )
	   m2t_JaakonMode := TRUE
	Else
	   m2t_JaakonMode := FALSE
   RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Misc, JaakonMode, %m2t_JaakonMode%

   ; tray menu ClickCount = 2 ?
	If ( newClick2Mode )
	   m2t_clickCount := 2
   Else
	   m2t_clickCount := 1
   RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Misc, ClickCount, %m2t_clickCount%

   ; show no error messages mode
	If ( newNoErrorMsgs )
	   m2t_NoErrorMsgs := TRUE
	Else
	   m2t_NoErrorMsgs := FALSE
	RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Misc, NoErrorMessages, %m2t_NoErrorMsgs%

   ; global actions enabled
	If ( newEventsEnabled )
	   m2t_EventsEnabled := TRUE
	Else
	   m2t_EventsEnabled := FALSE
	RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Misc, EventsEnabled, %m2t_EventsEnabled%

   Goto, GuiClose
Return

BtnCancel:
GuiEscape:
GuiClose:
   GUI, 1:Destroy
   Suspend, Off
   m2t_noGUIAction := FALSE
Return

; --------------------------- gui 6 for startup -----------------------
h_ButtonStartup:
   WinGet, lastUsedWin, ID
   Gui, +Disabled
   Gui, 6:Default
   Gui, +Owner1 +ToolWindow

   Gui, Add, Text, Section, %lng_SetupStartupTS1%
   Gui, Add, Text, , %lng_SetupStartupIN1%
   Gui, Add, Edit, ys w80
   Gui, Add, UpDown, vnewTimeSpan Range1-99999, %m2t_StartupTimeSpan%
   Gui, Add, Edit, w80
   Gui, Add, UpDown, vnewInterval Range200-999999, %m2t_StartupInterval%
   Gui, Add, Text, ys, %lng_SetupStartupTS2%
   Gui, Add, Text, , %lng_SetupStartupIN2%
   Gui, Add, Text, xm, %lng_SetupStartupHint%

   ; --- ok + cancel
   Gui, Add, Button, ym Section w90 g6ButtonOK Default, %lng_SetupOK%
   Gui, Add, Button, wp g6BtnCancel, %lng_SetupCancel%

   Gui, Show, Center, %lng_WindowTitle% - %lng_SetupStartupTitle%
Return

6ButtonOK:
   Gui, +OwnDialogs
   Gui, Submit, NoHide

   ; no range checking needed because updown control did it already!
   m2t_StartupTimeSpan = %newTimeSpan%
	RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, StartupMinTimeSpan, %m2t_StartupTimeSpan%
   m2t_StartupInterval = %newInterval%
	RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, StartupMinInterval, %m2t_StartupInterval%

   Goto, 6GuiClose
Return

6BtnCancel:
6GuiEscape:
6GuiClose:
   WinActivate, ahk_id %lastUsedWin%
   Gui, 6:Destroy
   Gui, 1:Default
   Gui, -Disabled
Return

; ---------------------------- gui 7 for events -------------------------
h_ButtonEvents:
   WinGet, lastUsedWin, ID
   Gui, +Disabled
   Gui, 7:Default
   Gui, +Owner1 +ToolWindow

   tmpEVreg1 = BossKeyEventBefore
   tmpEVreg2 = BossKeyEventAfter

   Loop, 2 {
      tmpEVreg = tmpEVreg%A_Index%
      tmpEVlng := lng_SetupEventBK%A_Index%
      Gui, Add, Text, w340, %tmpEVlng%:
      Gui, Add, Edit, r1 w330 Limit255 vnewEV%A_Index%, % f_TriggerAction( "", %tmpEVreg%, h_RegSubkey "\Starter", "__readout__")
   }

   ; --- ok + cancel
   Gui, Add, Button, ym Section w90 g7ButtonOK Default, %lng_SetupOK%
   Gui, Add, Button, wp g7BtnCancel, %lng_SetupCancel%
   ; hint
   Gui, Add, Text, xm w440, %lng_SetupEventHint1%
   Gui, Add, Edit, w440 r8 ReadOnly, %lng_SetupEventHint2%

   Gui, Show, Center, %lng_WindowTitle% - %lng_SetupEventTitleBK%
Return

7ButtonOK:
   Gui, +OwnDialogs
   Gui, Submit, NoHide

   Loop, 2 {
      tmpEV = newEV%A_Index%
      If f_TriggerAction( "", %tmpEV%, "__parse__" ) {
         tmpEVreg := tmpEVreg%A_Index%   ; get content of values!
         tmpEV := %tmpEV%
         tmpEV = %tmpEV%   ; auto-trim variable!
         If ( tmpEV = "" )
            RegDelete, HKCU, %h_RegSubkey%\Starter, %tmpEVreg%
         Else
            RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Starter, %tmpEVreg%, %tmpEV%
      } Else {
         tmpEVlng := lng_SetupEventBK%A_Index%
         Msgbox, 48, %lng_WindowTitle% - %lng_SetupEventTitleBK%, %lng_SetupEventError%`n"%tmpEVlng%".
         Return
      }
   }   

   Goto, 7GuiClose
Return

7BtnCancel:
7GuiEscape:
7GuiClose:
   WinActivate, ahk_id %lastUsedWin%
   Gui, 7:Destroy
   Gui, 1:Default
   Gui, -Disabled
Return

h_BossKey:
   f_TriggerAction( "", "BossKeyEventBefore", h_RegSubkey "\Starter" )
   If ( m2t_Bk2sMode ) {
      ; enforce StealthMode
      f_StealthMode( "ON" )
   	f_ShowTrayIcon( h_StarterIcon, h_StarterIcon# )
   }
   success := f_BossKey()
   If ( success )
      f_TriggerAction( "", "BossKeyEventAfter", h_RegSubkey "\Starter" )
Return

h_BossKeyListToggleWin:  ; *erm* the names don't get any better :-|
   f_BossKeyListToggleWin()
Return

h_BossKeyPurgeList:
   plPre = bk
   lng_PurgeList = %lng_BKPurgeList%
   lng_PurgeListTitle = %lng_BKPurgeListTitle%
   lng_PurgeListReq = %lng_BKPurgeListReq%
   Gosub, h_PurgeList
Return

h_StartupMinPurgeList:
   plPre = sm
   lng_PurgeList = %lng_SMPurgeList%
   lng_PurgeListTitle = %lng_SMPurgeListTitle%
   lng_PurgeListReq = %lng_SMPurgeListReq%
   Gosub, h_PurgeList
Return

; ---------------------------- gui 4 for PurgeList -------------------------
h_PurgeList:
   ; this subroutine requires
   ; plPre, lng_PurgeList, lng_PurgeListTitle, lng_PurgeListReq
   ; to be assigned beforehand
   m2t_noGUIAction := TRUE
   Suspend, On
   ; setup listview
   Gui, 4:Default
   Gui, +AlwaysOnTop -MinimizeBox -MaximizeBox
   Gui, Add, Text, w520, %lng_PurgeList%:
   Gui, Add, ListView, r15 wp+20 Count30 -Multi Grid ReadOnly AltSubmit gPurgeListView vPurgeListView, RegName|Application|Class|Window title or ID
   ; add entries to listview
   Loop, HKCU, %h_RegSubkey%
   {
      StringSplit, tmp, A_LoopRegName, |
   	If ( tmp0 = 3 AND tmp3 = plPre ) {
         tmpApp = %tmp1%
         tmpClass = %tmp2%
      }
   	Else If ( tmp0 = 2 AND tmp2 = plPre ) {
         tmpApp = %tmp1%
         tmpClass = <ANY>
      }
   	Else
         Continue
   
      wtList =
      RegRead, wtList, HKCU, %h_RegSubkey%, %A_LoopRegName%_wt
      If ( wtList = "" )
         wtList = <ANY>
   
      LV_Add( "", A_LoopRegName, tmpApp, tmpClass, wtList )
   }
   LV_ModifyCol( 1, 0 ) ; col#1 is invisible
   LV_ModifyCol( 2, "AutoHdr" )
   LV_ModifyCol( 3, "AutoHdr" )
   LV_ModifyCol( 4, "AutoHdr" )
   ; buttons   
   disabledBtns := TRUE ; initially the buttons are disabled
   Gui, Add, Button, Disabled ys Section w90 g4BtnEdit Default, %lng_SetupEdit%
   Gui, Add, Button, Disabled wp g4BtnRemove, %lng_SetupRemove%
   Gui, Add, Button, wp g4GuiClose, %lng_SetupClose%
   Gui, Show, Center, %lng_PurgeListTitle%
Return

PurgeListView:
   If ( A_GuiControlEvent = "I" ) {
      ; enable buttons if row is selected
      If ( disabledBtns ) {
         GuiControl, Enabled, %lng_SetupEdit%
         GuiControl, Enabled, %lng_SetupRemove%
         disabledBtns := FALSE
      }
      ; re-disable buttons if no row is selected   
      rowNumber := LV_GetNext()
      If ( Not rowNumber ) {
         GuiControl, Disabled, %lng_SetupEdit%
         GuiControl, Disabled, %lng_SetupRemove%
         disabledBtns := TRUE
      }
   }
   ; double clicking = edit
   If ( A_GuiControlEvent = "DoubleClick" ) {
      If ( disabledBtns )
         Return
      Gosub, 4BtnEdit
   }
Return

4BtnRemove:
   Gui, +OwnDialogs
   ; get row# and regName
   rowNumber := LV_GetNext()
   If ( rowNumber ) {
      LV_GetText( regName, rowNumber, 1 )
      LV_GetText( tmpApp, rowNumber, 2 )
      LV_GetText( tmpClass, rowNumber, 3 )
      LV_GetText( tmpWTlist, rowNumber, 4 )
   } Else
      Return
   ; ask user
   Msgbox, 36, %lng_PurgeListTitle%, %tmpApp% | %tmpClass% | %tmpWTlist%`n`n%lng_PurgeListReq%
      IfMsgBox, No
         Return
   ; do the dirty work
   LV_Delete( rowNumber )
   RegDelete, HKCU, %h_RegSubkey%, %regName%
   RegDelete, HKCU, %h_RegSubkey%, %regName%_wt
Return

4GuiEscape:
4GuiClose:
   GUI, 4:Destroy
   Suspend, Off
   m2t_noGUIAction := FALSE
Return

; ------------------------ gui 8 for PurgeList edit window ---------------------
4BtnEdit:
   Gui, +OwnDialogs
   ; get row# and regName
   rowNumber := LV_GetNext()
   If ( rowNumber )
      LV_GetText( regName, rowNumber, 1 ) 
   Else
      Return
   ; spawn edit window
   WinGet, lastUsedWin, ID
   Gui, +Disabled
   Gui, 8:Default
   Gui, +Owner4 +ToolWindow
   ; split reg-key data
   StringSplit, tmp, regName, |
   If ( tmp0 = 3 AND tmp3 = plPre ) {
      data1 = %tmp1%
      data2 = %tmp2%
   } Else If ( tmp0 = 2 AND tmp2 = plPre ) {
      data1 = %tmp1%
      data2 =        ; no class!
   } Else {
      Gosub, 8GuiClose
      Return
   }
   RegRead, data3, HKCU, %h_RegSubkey%, %regName%_wt
   ; buttons
   Gui, Add, Text, w320, Application
   Gui, Add, Edit, r1 w300 Limit255 Disabled vnewData1, %data1%
   Gui, Add, Text, w320, Class
   Gui, Add, Edit, r1 w300 Limit255 vnewData2, %data2%
   Gui, Add, Text, w320, Window title or ID
   Gui, Add, Edit, r1 w300 Limit255 vnewData3, %data3%
   ; --- ok + cancel
   Gui, Add, Button, ym Section w90 g8ButtonOK Default, %lng_SetupOK%
   Gui, Add, Button, wp g8BtnCancel, %lng_SetupCancel%
   Gui, Add, Text, xm w400, %lng_PurgeListHint%
   Gui, Show, Center, %lng_WindowTitle% - %lng_PurgeListTitle%
Return

8ButtonOK:
   Gui, +OwnDialogs
   Gui, Submit, NoHide
   ; at least the application name is needed!
   If ( newData1 = "" )
      Return
   ; remove old keys
   newRegName = %regName%
   RegDelete, HKCU, %h_RegSubkey%, %newRegName%
   RegDelete, HKCU, %h_RegSubkey%, %newRegName%_wt
   ; set new reg-key
   If ( newData2 = "" ) {
      ; generic, without "class"
      newRegName = %newData1%|%plPre%
      RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %newRegName%, 1
   } Else {
      ; with "class"
      newRegName = %newData1%|%newData2%|%plPre%
      RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %newRegName%, 1
   }
   ; also use window list?
   If ( newData3 <> "" ) {
      RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %newRegName%_wt, %newData3%
   }
   ; do the dirty work
   Gosub, 8GuiClose
   ; operate on GUI4!
   If ( newData2 = "" )
      newData2 = <ANY>
   If ( newData3 = "" )
      newData3 = <ANY>
   LV_Modify( rowNumber, "", newRegName, newData1, newData2, newData3 )
   LV_ModifyCol( 1, 0 ) ; col#1 is invisible
   LV_ModifyCol( 2, "AutoHdr" )
   LV_ModifyCol( 3, "AutoHdr" )
   LV_ModifyCol( 4, "AutoHdr" )
Return

8BtnCancel:
8GuiEscape:
8GuiClose:
   WinActivate, ahk_id %lastUsedWin%
   Gui, 8:Destroy
   Gui, 4:Default
   Gui, -Disabled
Return

h_StealthModeToggle:
   ; toggle stealth
   f_StealthMode()
	; update/remove icon for Starter
	f_ShowTrayIcon( h_StarterIcon, h_StarterIcon# )
Return

h_YMaxWindow:
	f_MaxWindow( "", "Y" )
Return

h_XMaxWindow:
	f_MaxWindow( "", "X" )
Return

h_AlwaysOnTop:
   f_AlwaysOnTop()
Return

h_NoButtons:
   f_NoButtons()
Return

;-----------------------------------------------------------------------------
; Starter functions
;

f_BossKey( bkPre="" ) {
   ; hide all visible windows with one keystroke
   ; returns TRUE if windows to be hidden were found
   Global bkMode, h_RegSubkey, m2t_hkBossKey, m2t_BkMultiWin, m2t_NoMinGlobal
   Static m2t_smList

   If ( Not bkPre )
      bkPre = bk  ; set a default

   ; set special values for SM mode
   If ( bkPre="sm" ) {
      fbkMode  := 1     ; 1 = opt-in mode
      multiWin := FALSE ; "StartupMinimize" hides to seperate icons
      smMode   := TRUE  ; this is just a flag: we are in SM mode right now
   } Else {
      fbkMode  := bkMode
      multiWin := m2t_BkMultiWin
      smMode   := FALSE
   }

	; build list with currently active (visible) windows
	DetectHiddenWindows, Off
	WinGet, bkWinID, List
	DetectHiddenWindows, On
	If ( bkWinID = 0 )  ; no windows to hide
	   Return FALSE

	; in topmost mode:
   ; get frontmost window's unique id
	If ( fbkMode = 2 ) {
      ; on "forbidden classes" use last active window then 
      If f_IsForbiddenWinClass()
         SendInput, !{ESC}
   	tmID := WinActive("A")
      tmID := f_GetOwnerOrSelf( tmID )
   }

	; go thru list and hide all windows, except those that are opt'ed-out by user
	; bkHideID holds the count of windows to hide, bkHideID1 is the first...
	bkHideID = 0
	Loop, %bkWinID%
	{
		tmpWinID := bkWinID%A_Index%
		WinGetClass, bkClass, ahk_id %tmpWinID%
   	; skip these classes
		If f_IsForbiddenWinClass( bkClass, "TfPSPad,SysShadow,ThunderRT6Main" )  ;,BaseBar
		   Continue
      ; do not minimize windows with a text of "Min2TrayBKdisable" in GUI,
      ; prevents BossKey to hide the prefs window of BK-helper
      If ( bkClass = "AutoHotkeyGUI" ) {
         WinGetText, wText, ahk_id %tmpWinID%
         If InStr( wText, "Min2TrayBKnoHide", TRUE )
            Continue
      }

      bkEnabled := FALSE
		WinGet, bkApplication, ProcessName, ahk_id %tmpWinID%
		subKey = %bkApplication%|%bkClass%	; app+class
		RegRead, legacyEnabled, HKCU, %h_RegSubkey%, %subKey%|%bkPre%
		If ( Not legacyEnabled ) {
         subKey = %bkApplication% ; generic app (without class)
			RegRead, legacyEnabled, HKCU, %h_RegSubkey%, %subKey%|%bkPre%
      }

      ; read out app|class|bk_wt or app|class|sm_wt for window titles
      RegRead, wtList, HKCU, %h_RegSubkey%, %subKey%|%bkPre%_wt
      If ( ErrorLevel Or wtList = "" ) {  
         ; legacy mode
         bkEnabled = %legacyEnabled%
      } Else {
         ; extended mode (scan for window title or window id)
         StringSplit, wtList, wtList, |
         Loop, %wtList0% {
            regTit := wtList%A_Index%
            ; check for possible window id
            If ( InStr( regTit, "0x", TRUE ) = 1 ) {
               If ( regTit = tmpWinID ) {
                  bkEnabled := TRUE
                  Break
               }
            }
            ; check for matching window title (RegEx)
            WinGetTitle, winTit, ahk_id %tmpWinID%
            If ( RegExMatch( winTit, regTit ) ) {
               bkEnabled := TRUE
               Break
            }
         }
      }

      ; note: bkNoMin does only affect StartupMinimize!
      ;       other cases will be handled by Helper.
      If ( m2t_NoMinGlobal )
         bkNoMin := TRUE
      Else {
         bkNoMin := FALSE
         ; read out app|class|nm for "no minimize"
         RegRead, bkNoMin, HKCU, %h_RegSubkey%, %bkApplication%|nm   ; generic app
   		If ( Not bkNoMin )
            RegRead, bkNoMin, HKCU, %h_RegSubkey%, %bkApplication%|%bkClass%|nm
      }

      ; remember id of window if not already done
      If ( Not bkReactivateID )
         bkReactivateID = %tmpWinID%

		; 0 = blacklist mode: hide all windows, BUT user-specified ones
		; 1 = whitelist mode : hide ONLY user-specified windows
		; 2 = topmost mode: hide all windows, BUT the topmost (active) one
		If (( fbkMode = 1 AND bkEnabled ) OR ( fbkMode = 0 AND Not bkEnabled ))
       OR ( fbkMode = 2 AND tmID <> tmpWinID ) {
		   bkHideID++
		   bkHideID%bkHideID% := tmpWinID

         ; read out app|class|jta_e for JustTriggerAction
         If ( smMode ) {
            RegRead, tmp, HKCU, %h_RegSubkey%, %subKey%|jta_e
               If ( tmp ) {
                  bkJTA%bkHideID% := TRUE
                  bkNoMin := TRUE
               }
         }

         ; skip starting of new helper if already SM'ed
         If ( smMode ) {
            If Not InStr(m2t_smList, tmpWinID "|", TRUE) {
               ; first: minimize to task bar (for a smooth experience :-)
      		   If ( Not bkNoMin ) {
            	   WinMinimize, ahk_id %tmpWinID%
            	}
            }
         }

		   ; reset remembered id if win is the one that gets hidden
		   If ( bkReactivateID = tmpWinID )
		      bkReactivateID = 0
		}
	}
   ; make remembered window active again
   If ( bkReactivateID ) {
      Sleep, 75
      IfWinNotActive, ahk_id %bkReactivateID%
         WinActivate
   }

   ; go and hide windows
   If ( bkHideID = 0 )
      Return FALSE   ; nothing to hide, pal
   Else If ( multiWin ) {
      ; hide to ONE icon
      f_StartNewHelper( "RESET" )
      Loop, %bkHideID% {
         WinID := bkHideID%A_Index%
         f_StartNewHelper( "ADD", WinID )
      }
      f_StartNewHelper( "SUBMIT", "BossKey'ed" )
   } Else {
      ; hide to MULTIPLE icons
      Loop, %bkHideID% {
         WinID := bkHideID%A_Index%

         ; skip starting of new helper if already SM'ed
         If ( smMode )
            If InStr(m2t_smList, WinID "|", TRUE)
               Continue

         ; doJTA = TRUE if we are in SM mode and user set JTA
         doJTA := bkJTA%A_Index%
         f_StartNewHelper( "ASAP", WinID, doJTA )

         ; if in "StartupMinimize" mode:
         ; add this window id to list of already processed ones
         If ( smMode )
            m2t_smList = %m2t_smList%%WinID%|
      }
   }
   Return TRUE
}

f_StartNewHelper( listCmd="", winID=FALSE, doJTA=FALSE ) {
   ; returns TRUE on success or the list of window IDs ("GET")
   Global  ; assumption: all vars are global except those declared Local
   Local h_MouseX, h_MouseY, h_WindowWidth
   Local h_WinStyle, h_ID, h_newPID, cmdLine, winCount, max, helperTitle
   Static listID  ; listID: list of memorized window IDs seperated by "|"

   ; commands
   If ( listCmd = "SUBMIT" ) {
      If ( listID = "" )
         Return   ; nothing on list
      If ( winID ) {
         ; cut title to 25 chars, max.
         StringLeft, tmp, winID, 25
         helperTitle = "%tmp%"
      } Else
         helperTitle = "MultiWindows"
      winID = %listID%
      Gosub, h_suStartNewHelper1
      Return TRUE 
   } Else If ( listCmd = "RESET" ) {
      listID =
      Return TRUE
   } Else If ( listCmd = "GET" )
      Return listID

   ; check window ID
	If ( winID ) {
      IfWinNotExist, ahk_id %winID%
         Return FALSE
	} Else {
		; set "last used window"
      WinWait, A, , 1
      If ( ErrorLevel )
         ; it timed out, so return an error
         Return FALSE
      ; retrieve window ID
      WinGet, winID, ID
	}
   WinGet, winStyle, Style ; winID found, lastfoundwin set
   If ( m2t_ForcedMode )
      cmpWinStyle = 0x10000000   ; ( WS_VISIBLE )
   Else
      cmpWinStyle = 0x10020000   ; ( WS_VISIBLE | WS_MINIMIZEBOX )
   If Not ( winStyle & cmpWinStyle = cmpWinStyle )
      Return FALSE   ; window style not suitable for hiding

   ; commands needing "winID"
   If ( listCmd = "ADD" ) {
      listID = %listID%%winID%|
      Return TRUE ; right now do nothing but adding
   } Else If ( listCmd = "ASAP" ) {
      Gosub, h_suStartNewHelper1  ; minimize immediately
      Return TRUE
   } Else If ( listCmd = "MMOUSE" ) { ; middle click on title bar?
      WinGetPos, , , h_WindowWidth
      MouseGetPos, h_MouseX, h_MouseY
      If   ( h_MouseY > 0 )
       And ( h_MouseY < h_BorderCaptionHeight )
       And ( h_MouseX < h_WindowWidth )
       And ( h_MouseX > 0 ) {
         Gosub, h_suStartNewHelper1
         Return TRUE
      }
   } Else If ( listCmd = "RMOUSE" ) { ; right click on close button?
      WinGetPos, , , h_WindowWidth
      MouseGetPos, h_MouseX, h_MouseY
      If   ( h_MouseY > 0 )
       And ( h_MouseY < h_BorderCaptionHeight )
       And ( h_MouseX < h_WindowWidth )
       And ( h_MouseX > h_WindowWidth - h_BorderButtonWidth ) {
         Gosub, h_suStartNewHelper1
         Return TRUE
      }
   }
   Return FALSE

   ; sub-routines for this function
   h_suStartNewHelper1:
      ; if there are more then "max" window ID, spawn another helper
      ; this hopefully avoids too long command lines
      max = 15
      StringSplit, tmpID, winID, |
      winCount = 0
      Loop, %tmpID0% {
         tmp := tmpID%A_Index%
         If ( tmp ) {
            cmdline = %cmdline% %tmp%
            winCount++
         }
         If ( winCount = max ) {
            Gosub, h_suStartNewHelper2
            winCount = 0
            cmdline =
         }
      }
      ; if there was some "left-over"
      If ( winCount > 0 )
         Gosub, h_suStartNewHelper2
   Return

   ; another sub routine just for spawning the helper
   h_suStartNewHelper2:
      ; if "helperTitle" is set, user wants to spawn a "MultiMode" helper
      If ( helperTitle )
         cmdLine = %helperTitle% %cmdLine%
      Else If ( doJTA )
         cmdLine = __justTriggerAction__ %cmdLine%

      If ( A_IsCompiled )
         Run, "%A_ScriptFullPath%" %cmdLine%, , UseErrorLevel, h_newPID
      Else
      	Run, "%h_ahkFullPath%" "%A_ScriptFullPath%" %cmdLine%, , UseErrorLevel, h_newPID
      
      If ( ErrorLevel = "ERROR" )	; helper could not be started
      	Return
      
      h_hPIDcount++
      h_helperPIDs%h_hPIDcount% = %h_newPID%
   Return   
}

f_BossKeyListToggleWin() {
   ; add or remove current window to/from BossKey list
   Global lng_BKListToggleOn, lng_BKListToggleOff, h_RegSubkey

   WinGet, h_WinID, ID, A
   Loop {
      endFunction := FALSE

      ; set last used win
      WinWait, ahk_id %h_WinID%,, 1
      If ( ErrorLevel ) {
         ; It timed out, so go on with next window id
         endFunction := TRUE
      	Break
      }
      
      WinGetClass, h_Class
      WinGet, h_Application, ProcessName
   
      ; substitution of "evil class"
      newWinID := f_GetOwnerOrSelf( h_WinID )
      If ( h_WinID = newWinID )
         ; no substitution: leave the loop!
         Break
      Else
         ; go another looping round with new content in h_WinID...
         h_WinID := newWinID 
   }
   If ( endFunction )
      Return

   If f_IsForbiddenWinClass( h_Class )
   	Return

	WinGetTitle, title
   If ( StrLen(title) > 50 ) {
      StringLeft, title, title, 47
      title = %title%...
   }

	RegRead, bkEnabled, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|bk	; app+class on bosskey list?
   If ( ErrorLevel Or Not bkEnabled ) {
		RegWrite, REG_SZ, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|bk, 1
      txt = "%title%":`n%lng_BKListToggleOn%
	} Else {
		RegDelete, HKCU, %h_RegSubkey%, %h_Application%|%h_Class%|bk
      txt = "%title%":`n%lng_BKListToggleOff%
	}

   f_TrayTip(txt)
   Return
}

;-----------------------------------------------------------------------------
; Starter error -- subs
;

ExitWithAHKError:
   f_ShowErrorMsg( lng_ExitWithAHKError )
ExitApp, 1

ExitWithRunningError:
   f_ShowErrorMsg( lng_ExitWithRunningError )
ExitApp, 1

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; general -- subs
;

h_InitGeneral:
   ; at least this version of AHK is needed
   h_MinReqAHK = 1.0.48
   ; key in HKCU to store stuff under
   h_RegSubkey = Software\KTC\Min2Tray
   ; set "generic" language
   f_SetLanguage( "general" )   
   ; some sanity checks   
   If ( A_OSType <> "WIN32_NT" ) {
      f_ShowErrorMsg( lng_ExitWithOSError )
      ExitApp, 1
   }
   If ( A_AhkVersion < h_MinReqAHK ) {
      f_ShowErrorMsg( lng_ExitWithVersionError )
      ExitApp, 1
   }
   ; user defined/ default tray icon for starter and as default helper icon
   h_StarterIcon# = 1
   h_StarterIcon  = %A_ScriptDir%\Min2Tray.ico
   If Not FileExist( h_StarterIcon ) {
      If ( A_IsCompiled )
         h_StarterIcon  = %A_ScriptFullPath%
      Else {
         h_StarterIcon  = %A_ScriptDir%\Min2Tray.exe
         If Not FileExist( h_StarterIcon ) {
            h_StarterIcon# = 175
            h_StarterIcon  = %A_WinDir%\system32\shell32.dll
         }
      }
   }
   ; --- get registry settings
   ; DebugMode - throw some debug infos into logfile
	RegRead, m2t_DebugMode, HKCU, %h_RegSubkey%\Misc, DebugMode
	If ( m2t_DebugMode )
	   m2t_DebugMode := TRUE
	Else
      m2t_DebugMode := FALSE
   ; Jaakon's mode - prompt for custom name if none present
	RegRead, m2t_JaakonMode, HKCU, %h_RegSubkey%\Misc, JaakonMode
	If ( m2t_JaakonMode )
	   m2t_JaakonMode := TRUE
	Else
      m2t_JaakonMode := FALSE
   ; NoMinimizeGlobal - globally enable "nominimize" for all apps
	RegRead, m2t_NoMinGlobal, HKCU, %h_RegSubkey%\Misc, NoMinimize
	If ( m2t_NoMinGlobal )
	   m2t_NoMinGlobal := TRUE
	Else
      m2t_NoMinGlobal := FALSE
   ; DontBugMe - switch off all notifications (tray tip, tool tip)
	RegRead, m2t_DontBugMe, HKCU, %h_RegSubkey%\Misc, DontBugMe
	If ( m2t_DontBugMe )
	   m2t_DontBugMe := TRUE
	Else
      m2t_DontBugMe := FALSE
   ; 1 or 2 click menu?
	RegRead, m2t_clickCount, HKCU, %h_RegSubkey%\Misc, ClickCount
	If m2t_clickCount not in 1,2
	   m2t_clickCount := 1
Return

;+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
; general -- functions
;

Win_Get(Hwnd, pQ="", ByRef o1="", ByRef o2="", ByRef o3="", ByRef o4="", ByRef o5="", ByRef o6="", ByRef o7="", ByRef o8="", ByRef o9="") {
   /*
   (c) by majkinetor
   see: <http://code.google.com/p/mm-autohotkey/>
   Parameters:
   		pQ			- List of query parameters.
   		o1 .. o9	- Reference to output variables. R,L,B & N query parameters can return multiple outputs.
   Query:
   		C,I		- Class, pId.
   		R,L,B,N	- One of the window rectangles: R (window Rectangle), L (cLient rectangle screen coordinates), B (ver/hor Border), N (captioN rect).
   					  N returns the size of the caption regardless of the window style or theme. These coordinates include all title-bar elements except the window menu.
   					  The function returns x, y, w & h separated by space. 
   					  For all 4 query parameters you can additionaly specify x,y,w,h arguments in any order (except Border which can have only x(hor) and y(ver) arguments) to
   					  extract desired number into output variable.
   		S,E		- Style, Extended style.
   	   P,A,O		- Parents handle, Ancestors handle, Owners handle.
   		M			- Module full path (owner exe), unlike WinGet,,ProcessName which returns only name without path.
   		T			- Title for a top level window or text for a child window.
   		D			- DC.
   		#			- Non-negative integer. If present must be first option in the query string. Function will return window information
   					  not for passed window but for its ancestor. 1 is imidiate parent, 2 is parent's parent etc... 0 represents root window.
   Returns:
   		o1       - first output is returned as function result
   */ 
	c := SubStr(pQ, 1, 1)
	if c is integer 
	{
		if (c = 0)
			Hwnd := DllCall("GetAncestor", "uint", Hwnd, "uint", 2, "UInt")
		else loop, %c%
			Hwnd := DllCall("GetParent", "uint", Hwnd, "UInt")

		pQ := SubStr(pQ, 2)
	}
		
	if pQ contains R,B,L
		VarSetCapacity(WI, 60, 0), NumPut(60, WI),  DllCall("GetWindowInfo", "uint", Hwnd, "uint", &WI)
	
	oldDetect := A_DetectHiddenWindows
	DetectHiddenWindows, on
	
	k := i := 0
	loop
	{
		i++, k++
		if (_ := SubStr(pQ, k, 1)) = ""
			break

		if !IsLabel("Win_Get_" _ )
			return A_ThisFunc "> Invalid query parameter: " _
		Goto %A_ThisFunc%_%_%

		Win_Get_C:
				WinGetClass, o%i%, ahk_id %hwnd%		
		continue

		Win_Get_I:
				WinGet, o%i%, PID, ahk_id %hwnd%		
		continue

		Win_Get_N:
				rect := "title"
				VarSetCapacity(TBI, 44, 0), NumPut(44, TBI, 0), DllCall("GetTitleBarInfo", "uint", Hwnd, "str", TBI)
				title_x := NumGet(TBI, 4, "Int"), title_y := NumGet(TBI, 8, "Int"), title_w := NumGet(TBI, 12) - title_x, title_h := NumGet(TBI, 16) - title_y 
				WinGet, style, style, ahk_id %Hwnd%				
				title_h :=  style & 0xC00000 ? title_h : 0			  ; if no WS_CAPTION style, set 0 as win sets randoms otherwise...
				goto Win_Get_Rect
		Win_Get_B:
				rect := "border"
				border_x := NumGet(WI, 48, "UInt"),  border_y := NumGet(WI, 52, "UInt")	
				goto Win_Get_Rect
		Win_Get_R:
				rect := "window"
				window_x := NumGet(WI, 4,  "Int"),  window_y := NumGet(WI, 8,  "Int"),  window_w := NumGet(WI, 12, "Int") - window_x,  window_h := NumGet(WI, 16, "Int") - window_y
				goto Win_Get_Rect
		Win_Get_L: 
				client_x := NumGet(WI, 20, "Int"),  client_y := NumGet(WI, 24, "Int"),  client_w := NumGet(WI, 28, "Int") - client_x,  client_h := NumGet(WI, 32, "Int") - client_y
				rect := "client"
		Win_Get_Rect:
				k++, arg := SubStr(pQ, k, 1)
				if arg in x,y,w,h
				{
					o%i% := %rect%_%arg%, j := i++
					goto Win_Get_Rect
				}
				else if !j
						  o%i% := %rect%_x " " %rect%_y  (_ = "B" ? "" : " " %rect%_w " " %rect%_h)
				
		rect := "", k--, i--, j := 0
		continue
		Win_Get_S:
			WinGet, o%i%, Style, ahk_id %Hwnd%
		continue
		Win_Get_E: 
			WinGet, o%i%, ExStyle, ahk_id %Hwnd%
		continue
		Win_Get_P: 
			o%i% := DllCall("GetParent", "uint", Hwnd, "UInt")
		continue
		Win_Get_A: 
			o%i% := DllCall("GetAncestor", "uint", Hwnd, "uint", 2, "UInt") ; GA_ROOT
		continue
		Win_Get_O: 
			o%i% := DllCall("GetWindowLong", "uint", Hwnd, "int", -8, "UInt") ; GWL_HWNDPARENT
		continue
		Win_Get_T:
			if DllCall("IsChild", "uint", Hwnd)
				 WinGetText, o%i%, ahk_id %hwnd%
			else WinGetTitle, o%i%, ahk_id %hwnd%
		continue
		Win_Get_M: 
			WinGet, _, PID, ahk_id %hwnd%
			hp := DllCall( "OpenProcess", "uint", 0x10|0x400, "int", false, "uint", _ ) 
			if (ErrorLevel or !hp) 
				continue
			VarSetCapacity(buf, 512, 0), DllCall( "psapi.dll\GetModuleFileNameEx" (A_IsUnicode ? "W" : "A"), "uint", hp, "uint", 0, "str", buf, "uint", 512),  DllCall( "CloseHandle", hp ) 
			o%i% := buf 
		continue
		Win_Get_D:
			o%i% := DllCall("GetDC", "uint", Hwnd, "UInt")
		continue
	}	
	DetectHiddenWindows, %oldDetect%
	return o1
}

f_IsForbiddenWinClass( winClass="", addForbidWC="" ) {
   ; returns TRUE if winClass is "fobidden"
   ; if winClass is not supplied, takes the currently active window
   static forbidWC   ; not needed, but for speed up!
   ; M2T will not touch any of these window classes
   forbidWC = ,%addForbidWC%,Shell_TrayWnd,Progman,WorkerW,tooltips_class32,
   ; take the currently active window
   If ( Not winClass )
      WinGetClass, winClass, A

   f_DebugLog( "f_IsForbiddenWinClass", "winClass:" winClass ", forbidWC:" forbidWC )

   ; check for a match, but first split window class on ".",
   ; i.e. "TfPSPad.UnicodeClass" becomes "TfPSPad"   
   StringSplit, needle, winClass, .
   If needle0 And InStr(forbidWC, "," . needle1 . ",", TRUE)
      Return TRUE
   ; default: no match found
   Return FALSE
}

f_GetOwnerOrSelf( winID ) {
   ; class substitution [former f_SubstEvilClass()]
   ; winID must be passed to this function
   ; returns winID (either of owner, if any, or passed one) 

   ; find the owner of the window
   If Win_Get(winID, "O", owner)
      Return owner
   
   Return winID
}

f_StealthMode( dowhat="" ) {
   ; manipulate StealthMode registry setting
   ; dowhat may be "ON", "OFF" or "" (for "toggle")
   Global h_RegSubkey

   mode := 0
	If ( dowhat = "ON" )
	   mode := 1
	Else If ( dowhat = "OFF" )
	   mode := 0
	Else {
   	RegRead, mode, HKCU, %h_RegSubkey%\Misc, StealthMode
   	mode := Not mode
	}

   If ( mode )
	   RegWrite, REG_SZ, HKCU, %h_RegSubkey%\Misc, StealthMode, 1
   Else
	   RegDelete, HKCU, %h_RegSubkey%\Misc, StealthMode
}

f_PositionWindow( winID="", newpos="", shutup=FALSE ) {
   ; position the active window
   ; newpos = "X, Y, W, H" where any element may be blank
   Global lng_Postraytip

   If ( Not newpos )
      Return

   ; set LastFoundWindow
   If ( winID )
      winID = ahk_id %winID%
   Else
      winID = A
   IfWinNotExist, %winID%
      Return

   ; split on comma, remove spaces and tabs from elements
   StringSplit, new, newpos, `,, %A_Space%%A_Tab% 
   If ( new0 = 0 )
      Return 

   ; get current position
   WinGetPos, cur1, cur2, cur3, cur4
   ; and compare to new/wanted position
   If ( (cur1 = new1 Or new1 = "")
         And (cur2 = new2 Or new2 = "")
         And (cur3 = new3 Or new3 = "")
         And (cur4 = new4 Or new4 = "") )
      Return

   ; position window
   WinMove, , , new1, new2, new3, new4

   ; show tray tip
   If ( Not shutup ) {
   	WinGetActiveTitle, title
      If ( StrLen(title) > 50 ) {
         StringLeft, title, title, 47
         title = %title%...
      }
      txt = "%title%":`n%lng_Postraytip%
      f_TrayTip(txt)
   }
}

f_MaxWindow( winID="", orient="", shutup=FALSE ) {
	; maximize the active window either horizontally or vertically
   ; orient may be "X", "Y" or "A" for both directions
   ; set shutup to disable tray tip
	Global m2t_ForcedMode, lng_YMaxtraytip, lng_YMaxNottraytip
   Global lng_XMaxtraytip, lng_XMaxNottraytip
   Global lng_AMaxtraytip, lng_AMaxNottraytip

   If orient in Y,X,A
   {
      lng_Maxtraytip    := lng_%orient%Maxtraytip
      lng_MaxNottraytip := lng_%orient%MaxNottraytip
   } Else
      Return

   ; set LastFoundWindow
   If ( winID )
      winID = ahk_id %winID%
   Else
      winID = A
   IfWinNotExist, %winID%
      Return

   WinGet, max, MinMax
   If ( max )
      Return   ; do not maximize windows that are already maximized by system

   SysGet, mon, MonitorWorkArea
	WinGetPos, curX, curY, curW, curH

	If ( orient="Y" AND curY=monTop AND curH=monBottom )
      Or ( orient="X" AND curX=monLeft AND curW=monRight )
      Or ( orient="A" AND curY=monTop AND curH=monBottom  AND curX=monLeft AND curW=monRight )
		Return	; do not y-max or x-max if window is already maxed by this script

   ; prepare title for traytip
	WinGetActiveTitle, title
	If ( StrLen(title) > 50 ) {
	   StringLeft, title, title, 47
	   title = %title%...
	}

   If ( Not m2t_ForcedMode ) {
      ; do not force maximization
   	WinGet, winStyle, Style
   	If ( winStyle & 0x40000 <> 0x40000 ) {
         If ( Not shutup ) {
         	txt = "%title%":`n%lng_MaxNottraytip%
         	f_TrayTip(txt)
         }
   		Return	; do not max if window has no WS_SIZEBOX style
   	}
   }

   If ( orient="Y" )
      WinMove, , , , %monTop%, , %monBottom%
   Else If ( orient="X" )
      WinMove, , , %monLeft%, , %monRight%
   Else
      WinMove, , , %monLeft%, %monTop%, %monRight%, %monBottom%

   ; show tray tip
   If ( Not shutup ) {
   	txt = "%title%":`n%lng_Maxtraytip%
   	f_TrayTip(txt)
	}

	Return
}

f_NoButtons( winID="", dowhat="", shutup=FALSE ) {
   ; show or hide all the buttons (SysMenu) of window title-bar
   ; dowhat may be "ON", "OFF" or "" (for "toggle")
   Global lng_NoBtraytip

   ; set LastFoundWindow
   If ( winID )
      winID = ahk_id %winID%
   Else
      winID = A
   IfWinNotExist, %winID%
      Return

   ; check current style
   WinGet, wstyle, Style
   wstyle := wstyle & 0x80000
   If ( (wstyle = 0x80000) And (dowhat = "" Or dowhat = "ON") ) {
      ; remove buttons
      WinSet, Style, -0x80000

      ; show balloon info
      If ( Not shutup ) {
      	WinGetActiveTitle, title
         If ( StrLen(title) > 50 ) {
            StringLeft, title, title, 47
            title = %title%...
         }
         txt = "%title%":`n%lng_NoBtraytip%
         f_TrayTip(txt)
      }
   } Else If (dowhat = "" Or dowhat = "OFF") {
     ; show buttons again
      WinSet, Style, +0x80000
   }
   Return
}

f_AlwaysOnTop( winID="", dowhat="", shutup=FALSE ) {
   ; make active window "always on top" or remove
   ; "aot" from window if this style is already present,
   ; indicate "aot" by doing some fancy stuff to the window
   ; dowhat may be "ON", "OFF" or "" (for "toggle")
   Global lng_AOTtraytip, h_RegSubkey
      
   ; set LastFoundWindow
   If ( winID )
      winID = ahk_id %winID%
   Else
      winID = A
   IfWinNotExist, %winID%
      Return

   ; Desktop and Tray cannot be made AOT
   WinGetClass, class
   If f_IsForbiddenWinClass( class )
   	Return

   WinGet, xstyle, ExStyle
   If ( (xstyle & 0x8) And (dowhat = "" Or dowhat = "OFF") ) {
      ;           0x8 is WS_EX_TOPMOST.
      ; remove always-on-top
      WinSet, AlwaysOnTop, Off
      ; remove tranxparency
      WinGet, trans, Transparent
      If ( trans ) { 
         WinSet, Transparent, 255
         Sleep, 50
         WinSet, Transparent, Off
      }
      f_TrayTip("")
   } Else If (dowhat = "" Or dowhat = "ON") {
      ; make it always-on-top
      WinSet, AlwaysOnTop, On
      ; get custom transparency
   	RegRead, trans, HKCU, %h_RegSubkey%\Starter, TransparentAOT
      If ( trans < 1 OR trans > 255 )
         trans = 0   ; default: no transparency
      ; set window transparency
      If ( trans > 0 )
         WinSet, Transparent, %trans%
      ; show balloon info
      If ( Not shutup ) {
         WinGetActiveTitle, title
         If ( StrLen(title) > 50 ) {
            StringLeft, title, title, 47
            title = %title%...
         }
         txt = "%title%":`n%lng_AOTtraytip%
         f_TrayTip(txt)
      }
   }
   Return
}

f_KeyWaitModifier( timeout=1.0 ) {
   ; wait for "timeout" seconds (float)
   ; for user to release all modifier keys
   KeyWait, RWin, T%timeout%
   KeyWait, LWin, T%timeout%
   KeyWait, Control, T%timeout%
   KeyWait, Alt, T%timeout%
   KeyWait, Shift, T%timeout%
}

f_DebugLog( logSrc="", logText="" ) {
   ; log "time <src> text" to logFile
   ; if debugging is activated
   Global m2t_DebugMode
   If ( Not m2t_DebugMode )
      Return
   If ( logSrc = "" OR logText = "" )
      Return
   logFile = debug.log
   logText = %A_Now% <%logSrc%> %logText%`n
   FileAppend, %logText%, %logFile%
}

f_ShowErrorMsg( error_text="" ) {
   ; show window with an error message
   Global lng_WindowTitle, h_RegSubkey

   If ( error_text = "" )
      Return

   ; skip showing if registry key is set
	RegRead, show_msg, HKCU, %h_RegSubkey%\Misc, NoErrorMessages
	If ( Not show_msg )
      Msgbox, 48, %lng_WindowTitle%, %error_text%
}

f_ShowTrayIcon( file, number ) {
   Global h_RegSubkey, h_StarterIcon, h_StarterIcon#

   Menu, TRAY, UseErrorLevel
	RegRead, stealth, HKCU, %h_RegSubkey%\Misc, StealthMode	; are we in StealthMode?
	If ( Not ErrorLevel ) {
		If ( stealth ) {
			If ( Not A_IconHidden )
				Menu, TRAY, NoIcon
			Return
		}
   }

	If ( Not A_IconHidden )	; coming from hidden icon: ALWAYS renew icon!
		If ( A_IconFile = file AND A_IconNumber = number )	; icon props not changed
			Return

   IfExist, %file%
   {
      Menu, TRAY, Icon, %file%, %number%, 1  ; 1=freeze icon
      If ( Not ErrorLevel )	; if ErrorLevel was NOT raised -> allright
         Goto, OKout
   }

   ; if ErrorLevel or not existing file -> set default icon
   Menu, TRAY, Icon, %h_StarterIcon%, %h_StarterIcon#%, 1 ; 1=freeze icon

   OKout:
      Menu, TRAY, Icon	; show icon
      Menu, TRAY, UseErrorLevel, Off
   Return
}

f_AssignHotkey( hkey, hlabel="" ) {
   ; - assign exactly one hotkey to a label
   ; - return TRUE if assignment succeeded
   ;   otherwise FALSE
   ; - remove hotkey if no label is passed
   ;   (returns TRUE if there was no error)
   retVal := FALSE

   If ( hkey = "" )
      Return retVal

   ; if label is valid -> assign new key to label
   If IsLabel( hlabel ) {  
      ; first remove hotkey
      Hotkey, %hkey%, Off, UseErrorLevel
      ; assign new key
      Hotkey, %hkey%, %hlabel%, UseErrorLevel
      If ( Not ErrorLevel )
         Hotkey, %hkey%, On
            If ( Not ErrorLevel )
               retVal := TRUE
   } Else {
      ; if no valid label -> remove hotkey
      Hotkey, %hkey%, Off, UseErrorLevel
         If ( Not ErrorLevel )
            retVal := TRUE
   }
   Return retVal
}

f_ComposeHotkey( chNewKey, chWinKey, chKey, chLabel, chRegSub, chRegKey, chErrorMsg ) {
   ; check hotkey, assign and write it to registry
   ; returns new hotkey as string
   ; or "__invalid__" if assignment failed
   ; or "" if hotkey was removed
   Global h_RegSubkey, lng_SetupInvalidHotkey1, lng_SetupInvalidHotkey2

   ; remove old hotkey
   success := f_AssignHotkey( chKey )

   f_DebugLog( "f_ComposeHotkey", "f_AssignHotkey:remove: success=" success " chNewKey=" chNewKey " chOldKey=" chKey " chLabel=" chLabel )

   If ( success ) {
      RegDelete, HKCU, %h_RegSubkey%\%chRegSub%, %chRegKey%
      chKey =
   }
   
   ; set new hotkey
   If ( chNewKey ) {
      ; do some substitution (for authors convenience)
      If ( chNewKey = "^" )
         chNewKey = SC029
      StringReplace, chNewKey, chNewKey, ZIRKUMFLEX, SC029 
      If ( chNewKey = "´" )
         chNewKey = SC00D
      StringReplace, chNewKey, chNewKey, AKUT, SC00D 

      ; add WIN modifier if option checked
      If ( chWinKey )
         chNewKey = #%chNewKey%

      ; is there not at least one modifier (WIN, CTRL, ALT, SHIFT) in the new key
      If chNewKey not contains #,^,!,+
         chNewKey = 

      ; trying to assign new hotkey
      success := f_AssignHotkey( chNewKey, chLabel )

      f_DebugLog( "f_ComposeHotkey", "f_AssignHotkey:assign: success=" success " chNewKey=" chNewKey " chOldKey=" chKey " chLabel=" chLabel )

      If ( success ) {
         chKey = %chNewKey%
         RegWrite, REG_SZ, HKCU, %h_RegSubkey%\%chRegSub%, %chRegKey%, %chKey%
      } Else {
         chKey = __invalid__
         Msgbox, 48, %h_MenuWin%, %lng_SetupInvalidHotkey1%%chErrorMsg%%lng_SetupInvalidHotkey2%
      }
   }
   ; return the new Key (or "") to be used outside this function
   Return chKey
}

f_TrayTip( txt="", secs=5 ) {
   ; show a traytip
   Global lng_WindowTitle, m2t_DontBugMe

   If ( m2t_DontBugMe )
      Return

   If ( txt = "" ) {
      ; remove traytip
      TrayTip
      Return
   }
   
   If ( secs >= 1 AND secs <= 20 )
      msecs := secs * 1000
   Else
      msecs = 5000

   TrayTip, %lng_WindowTitle%, %txt%, 20, 17 ; nopopupsound+info
   SetTimer, f_TTRemoveTrayTip, %msecs%
   Return
   
   f_TTRemoveTrayTip:
      SetTimer, f_TTRemoveTrayTip, Off
      TrayTip
      Return
}

f_StringLeft( txt, len=80 ) {
   ; get string from left with custom length
   If ( StrLen( txt ) > len ) {
      StringLeft, txt, txt, %len%
   }
   Return txt
}

f_TriggerAction( winID, valName, subKey="", winTitle="" ) {
   ; read out registry value and then 
   ; trigger an action accordingly:
   ; send key strokes, run program, show message, play sound;
   ; if subKey = "__parse__" then string in valName will just be parsed
   ; returns TRUE if parsing succeeded
   ; if subKey = "__override__" then disable check for eventsEnabled
   ; if wintitle = "__readout__" then we just return the registry value
   ; winID will be passed to the underlying functions
   Global whoami, h_RegSubkey, lng_WindowTitle
   Global h_taActiveWinID

	RegRead, eventsEnabled, HKCU, %h_RegSubkey%\Misc, EventsEnabled
	If ( Not eventsEnabled
        And Not ( subKey = "__parse__" Or subKey = "__override__"
                  Or winTitle = "__readout__" ) )
      Return

   If ( valName = "" )
      Return TRUE
      
   If ( subKey = "" Or subKey = "__override__" )
      subKey = %h_RegSubkey%

   If ( subKey = "__parse__" ) {
      value = %valName%
      doit := FALSE
   } Else {
      RegRead, value, HKCU, %subKey%, %valName%
      If ( ErrorLevel OR value = "" )
         Return ""
      If ( winTitle = "__readout__" )
         Return value
      doit := TRUE
   }

   Loop, PARSE, value, |
   {
      parseOK := FALSE

      If ( A_LoopField = "" )
         Continue
            
      StringLeft, action, A_LoopField, 4
      StringTrimLeft, args, A_LoopField, 5

      f_DebugLog( "f_TriggerAction", "action:" action ", args:" args )

      If ( action = "key1" ) {
         ; send simulated keystrokes to the window, activating it first
         parseOK := TRUE
         If ( doit ) {
            WinActivate, ahk_id %winID%
            SendInput, %args%
         }
      } Else If ( action = "key2" ) {
         ; send simulated keystrokes to the window, activating it first
         ; you can set the "typing-"delay here, too (first argument)
         parseOK := TRUE
         If ( doit ) {
            ; split on commas
            StringSplit, tmp, args, `,
            If ( tmp0 = 2 ) {
               WinActivate, ahk_id %winID%
               SetKeyDelay, %tmp1%
               Send, %tmp2%
            }
         }
      } Else If ( action = "key4" ) {
         ; send simulated keystrokes to a control's HWND (window handle)
         ; use this i.e. to send chars to "cmd.exe" 
         parseOK := TRUE
         If ( doit )
            ControlSend, , %args%, ahk_id %winID%
      } Else If ( action = "key5" ) {
         ; send simulated keystrokes to a specified control (first argument)
         parseOK := TRUE
         If ( doit ) {
            ; split on commas
            StringSplit, tmp, args, `,
            If ( tmp0 = 2 )
               ControlSend, %tmp1%, %tmp2%, ahk_id %winID% 
         }
      } Else If ( action = "key6" ) {
         ; send simulated keystrokes to a specified control (second argument)
         ; you can set the "typing-"delay here, too (first argument)
         parseOK := TRUE
         If ( doit ) {
            ; split on commas
            StringSplit, tmp, args, `,
            If ( tmp0 = 3 ) {
               SetKeyDelay, %tmp1%
               ControlSend, %tmp2%, %tmp3%, ahk_id %winID%
            }
         }
      } Else If ( action = "act1" ) {
         ; activate the window (bring it to front)
         ; this will lead to auto-termination of helper-icon
         parseOK := TRUE
         If ( doit ) {
            WinShow, ahk_id %winID%
            WinRestore, ahk_id %winID%
            WinActivate, ahk_id %winID%
         }
      } Else If ( action = "act2" ) {
         ; re-activate memorized "active window for later" (bring it to front)
         ; see at routine h_Unhide of helper
         ; useful after un-hiding Topmost-BossKey-windows
         parseOK := TRUE
         If ( doit ) {
            tmp = ahk_id %h_taActiveWinID%
            If WinExist( tmp )
               WinActivate, %tmp%
         }
      } Else If ( action = "slp1" ) {
         parseOK := TRUE
         If ( doit ) {
            ; pause timer, sleep, un-pause timer
            SetTimer, h_CheckForWin, Off
            Sleep, %args%
            SetTimer, h_CheckForWin, On
         }
      } Else If ( action = "run1" ) {
         parseOK := TRUE
         If ( doit )
            Run, %args%, , UseErrorLevel
      } Else If ( action = "run2" ) {
         parseOK := TRUE
         If ( doit )
            Run, %args%, , Hide UseErrorLevel
      } Else If ( action = "run3" ) {
         parseOK := TRUE
         If ( doit )
            Run, %args% %winID%, , UseErrorLevel
      } Else If ( action = "rnw1" ) { 
         parseOK := TRUE
         If ( doit )
            RunWait, %args%, , UseErrorLevel
      } Else If ( action = "rnw2" ) {
         parseOK := TRUE
         If ( doit )
            RunWait, %args%, , Hide UseErrorLevel
      } Else If ( action = "rnw3" ) { 
         parseOK := TRUE
         If ( doit )
            RunWait, %args% %winID%, , UseErrorLevel
      } Else If ( action = "msg1" ) {
         parseOK := TRUE
         If ( doit ) {
            If ( winTitle = "" )
               winTitle = %lng_WindowTitle%
            Else
               winTitle = %winTitle% - %lng_WindowTitle%
            Msgbox, 262144, %winTitle%, %args%
         }
      } Else If ( action = "snd1" ) {
         parseOK := TRUE
         If ( doit )
            SoundPlay, %args%, WAIT
      } Else If ( action = "snd2" ) {
         parseOK := TRUE
         If ( doit )
            SoundPlay, %args%
      } Else If ( action = "aud1" ) {
         StringUpper, args, args
         If ( args = "MUTE_ON" ) {
            parseOK := TRUE
            If ( doit )
               SoundSet, 1, , MUTE
         } Else If ( args = "MUTE_OFF" ) {
            parseOK := TRUE
            If ( doit )
               SoundSet, 0, , MUTE
         } Else If ( args = "MUTE_TOGGLE" ) {
            parseOK := TRUE
            If ( doit )
               SoundSet, +1, , MUTE
         }
      } Else If ( action = "stm1" ) {
         StringUpper, args, args
         If ( args = "ON" ) {
            parseOK := TRUE
            If ( doit )
               f_StealthMode( "ON" )
         } Else If ( args = "OFF" ) {
            parseOK := TRUE
            If ( doit )
               f_StealthMode( "OFF" )
         } Else If ( args = "TOGGLE" ) {
            parseOK := TRUE
            If ( doit )
               f_StealthMode()
         }
      } Else If ( action = "cfw1" And whoami = "helper" ) {
         StringUpper, args, args
         If ( args = "ON" ) {
            parseOK := TRUE
            If ( doit ) {
               Gosub, h_CheckForWin ; immediate update 
               SetTimer, h_CheckForWin, On   ; un-pause timer
            }
         } Else If ( args = "OFF" ) {
            parseOK := TRUE
            If ( doit )
               SetTimer, h_CheckForWin, Off
         }
      } Else If ( action = "aot1" ) {
         StringUpper, args, args
         If ( args = "ON" ) {
            parseOK := TRUE
            If ( doit )
               f_AlwaysOnTop( winID, "ON", TRUE )
         } Else If ( args = "OFF" ) {
            parseOK := TRUE
            If ( doit )
               f_AlwaysOnTop( winID, "OFF", TRUE )
         }
      } Else If ( action = "nob1" ) {
         StringUpper, args, args
         If ( args = "ON" ) {
            parseOK := TRUE
            If ( doit )
               f_NoButtons( winID, "ON", TRUE )
         } Else If ( args = "OFF" ) {
            parseOK := TRUE
            If ( doit )
               f_NoButtons( winID, "OFF", TRUE )
         }
      } Else If ( action = "max1" ) {
         StringUpper, args, args
         If ( args = "X" ) {
            parseOK := TRUE
            If ( doit )
               f_MaxWindow( winID, "X", TRUE )
         } Else If ( args = "Y" ) {
            parseOK := TRUE
            If ( doit )
               f_MaxWindow( winID, "Y", TRUE )
         } Else If ( args = "BOTH" Or args = "XY" Or args = "YX" Or args = "A" ) {
            parseOK := TRUE
            If ( doit )
               f_MaxWindow( winID, "A", TRUE )
         }
      } Else If ( action = "pos1" ) {
         parseOK := TRUE
         If ( doit )
            f_PositionWindow( winID, args, TRUE )
      } Else If ( action = "min1" ) {
         parseOK := TRUE
         If ( doit ) {
            ; break from this loop and return "m2t"
            parseOK = m2t
            Break
         }
      } Else If ( action = "reg1" ) {
         ; write to registry
         ; we need exactly 4 arguments, separated by comma
         StringSplit, tmp, args, `,, %A_Space%%A_Tab%
         If ( tmp0 <> 4 )
            Return 
         parseOK := TRUE
         If ( doit )
            RegWrite, %tmp1%, HKCU, %tmp2%, %tmp3%, %tmp4%
      } Else If ( action = "reg2" ) {
         ; delete a registry key
         ; we need exactly 2 arguments, separated by comma
         StringSplit, tmp, args, `,, %A_Space%%A_Tab%
         If ( tmp0 <> 2 )
            Return 
         parseOK := TRUE
         If ( doit )
            RegDelete, HKCU, %tmp1%, %tmp2%
      } Else {
         ; no recognized action to perform
         If ( doit )
            Continue
      }

      If ( doit )
         Sleep, 100

      If ( Not parseOK )
         Break
   }
   Return parseOK
}

; -------------------- localization starts here --------------------
f_SetLanguage( role="" ) {  
   Global
   Static lang

   If ( lang = "" ) {
      ; set display format of time once
      FormatTime, versionDate, %versionDate%, ShortDate

      ; did user request a language?
      RegRead, lang, HKCU, %h_RegSubkey%\Misc, ForceLanguage
      If ( Not lang )   ; nope!
         StringRight, lang, A_Language, 2
      StringLower, lang, lang
      If lang in 07,de,de_de	    ; = German (0407, 0807, 0c07 ...)
         lang = de
      Else If lang in 0c,fr,fr_fr ; = French (040c, 080c, 0c0c, 100c, 140c, 180c ...)
         lang = fr
      Else  ; default is English
         lang = en
   }

   ; first: set defaults
   ; --- English ---
   If ( role = "helper" ) {
      lng_ExitWithParamError     = Error: First parameter must be a number!
      lng_MenuMultiWin           = &List of minimized windows
      lng_MenuAssignHotkey       = &Hotkey for showing window(s)...
      lng_MenuClose              = &Close window(s)
      lng_MenuUnhide             = &Show window(s)
      lng_hClose1                = Do you really wanna close window(s) "
      lng_hClose2                = "?
      lng_ChangeNameSelector     = Please enter the custom name:
      lng_ChangeIconSelector     = Select an icon file for "
      lng_ChangeIconSelectorExt  = Icon files
      lng_ChangeIconMulti        = Select an icon for "
      lng_SetupUnhideKey         = Hotkey to show window(s)
      lng_SetupCustomName        = Assign custom name
      lng_SetupCustomIcon        = Assign custom icon.
      lng_SetupOnBKList          = Window is on BossKey list.
      lng_SetupShowOnTitleChange = Show window when title changes.
      lng_SetupSOTCRegEx         = Optional: Only if this Regular Expression matches:
      lng_SetupNoMinimize        = Minimize window immediately (skip task bar).
      lng_SetupOnSMList          = Window is on StartupMinimize list.
      lng_SetupEventTitleH       = TriggerActions
      lng_SetupEvent1            = TA1: After hiding window
      lng_SetupEvent2            = TA2: Before unhiding window
      lng_SetupEvent3            = TA3: Before closing window
      lng_SetupEvent4            = TA4: Before exiting helper
      lng_SetupEvent5            = TA5: After window title changed
      lng_SetupEvent6            = JTA: On StartupMinimize: Trigger these actions ONLY!`nLeave blank to execute the actions specified above.`n(Do turn on StartupMinimize globally and for this window, too.)
   } Else If ( role = "starter" ) {
      lng_No2BtnMouseMsg			= Not enough mouse buttons. Mouse support disabled!
      lng_ExitWithRunningError   = Error: Min2Tray is already running!
      lng_ExitWithAHKError       = Error: Could not find file "AutoHotkey.exe"!
      lng_ExitWithLockError      = Error: Could not erase lock-file! Please erase file manually:
      lng_MenuAbout              = &About %lng_WindowTitle%
      lng_MenuRestoreOnly        = &Restore all windows
      lng_MenuQuitRestoreAll     = Restore &all && quit
      lng_MenuQuitOnly           = &Quit only
      lng_MenuBKEditList         = Edit &BossKey list
      lng_MenuSMEditList         = Edit &StartupMinimize list
      lng_PurgeListHint          = Clear an edit control to match any class or window title/ID.`n`n"Window title" can be any part of a window's title (i.e. "secret"). Regular Expressions are supported.`n"ID" must be the unique ID of a window (i.e. "0xe02fe", same as AHKs "ahk_id").`nTo check for different window titles or IDs, concatenate them using "|" (pipe-sign).`nExample for a valid window title/ID line: "help|0xe02fe|beat the boss|0xe02fe".
      lng_BKPurgeListTitle       = BossKey list
      lng_BKPurgeList            = Select a window to be edited or removed from BossKey list
      lng_BKPurgeListReq         = Continue to remove selected entry from BossKey list?
      lng_SMPurgeList            = Select a window to be edited or removed from StartupMinimize list
      lng_SMPurgeListTitle       = StartupMinimize list
      lng_SMPurgeListReq         = Continue to remove selected entry from StartupMinimize list?
      lng_TrayTitle              = %lng_WindowTitle%
      lng_About1                 = %lng_WindowTitle% v%versionString% (%versionDate%)
      lng_About2                 = Minimize windows to the tray area of taskbar as icons`nby pressing third mouse button or custom hotkey.`nAdditional features: BossKey, always-on-top, StartupMinimize,`nhorizontal or vertical maximizing and much more.
      lng_About3                 = Distributed under the terms of the GPLv3.`nCreated by Junyx / KTC^brain in June 2005.
      ;lng_About4                 = English translation by Junyx
      lng_SetupKey               = Hotkey to minimize window
      lng_SetupMButtonTitle      = Use third (middle) mouse button for minimizing?
      lng_SetupMButtonOpt0       = Nope!
      lng_SetupMButtonOpt1       = by clicking on titlebar [DEFAULT]
      lng_SetupMButtonOpt2       = by clicking (no matter where)
      lng_SetupRButton           = Minimize by right clicking on close button of titlebar [NO]
      lng_SetupBkMultiWin        = BossKey employs MultiWindows mode. [NO]
      lng_SetupBk2sMode          = Using BossKey enforces StealthMode (SM hotkey makes icons re-appear). [NO]
      lng_SetupStealthSessOnly   = StealthMode is current session only. [YES]
      lng_SetupForcedMode        = Always force min- or maximizing of window (ForcedMode). [NO]
      lng_SetupJaakonMode        = Always prompt for custom name if none is present. [NO]
      lng_SetupNoMinGlobal       = Immediately minimize ANY window to tray (do skip task bar). [NO]
      lng_SetupClick2Mode        = Tray icon will need double-click to show window again (single-click is default). [NO]
      lng_SetupNoErrorMsgsMode   = Do not show any error messages. [NO]
      lng_SetupBossKey           = BossKey
      lng_SetupBKAddMouse        = CTRL+SHIFT+third mouse button for adding/removing a window to/from BossKey list. [NO]
      lng_SetupBKListToggle      = Hotkey for adding/removing`na window to/from BossKey list
      lng_BKListToggleOn         = window added to BossKey list.
      lng_BKListToggleOff        = window removed from BossKey list.
      lng_SetupBKTitle           = Set BossKey mode
      lng_SetupBKOpt0            = Blacklist: minimize all windows EXCEPT those from BossKey list [DEFAULT]
      lng_SetupBKOpt1            = Whitelist: minimize ONLY windows from BossKey list
      lng_SetupBKOpt2            = Topmost: minimize all windows EXCEPT the topmost (active) one
      lng_SetupStealthKey        = Hotkey for StealthMode toggle
      lng_SetupAOTKey            = Hotkey for always-on-top
      lng_SetupPrefsKey          = Hotkey to open this preferences window
      lng_SetupYMaxKey           = Hotkey for maximizing vertically
      lng_SetupXMaxKey           = Hotkey for maximizing horizontally
      lng_SetupNoBKey            = Hotkey for NoButtons toggle
      lng_SetupAOTSlider1        = Transparency for always-on-top [NO]:
      lng_SetupAOTSlider2        = Opaque
      lng_SetupAOTSlider3        = Transparent
      lng_SetupStartupTitle      = StartupMinimize
      lng_SetupStartupEnable     = StartupMinimize: Enable minimizing of certain windows upon start of Min2Tray. Active after restart. [NO]
      lng_SetupStartupTS1        = Time span:
      lng_SetupStartupTS2        = sec
      lng_SetupStartupIN1        = Interval:
      lng_SetupStartupIN2        = ms
      lng_SetupStartupHint       = Check within the given time span`nevery X milliseconds (interval)`nif an open window is to be minimized.`nStartupMinimize will be turned off`nwhen X seconds (time span) passed.
      lng_SetupEventEnable       = Globally enable TriggerActions. [NO]
      lng_SetupEventTitleBK      = TriggerActions for BossKey
      lng_SetupEventBK1          = BK1: Before BossKey minimizes windows
      lng_SetupEventBK2          = BK2: After BossKey minimized windows
   } Else {
      lng_AOTtraytip             = window is now always-on-top.
      lng_Postraytip             = custom position assigned.
      lng_AMaxtraytip            = window is now maximized.
      lng_AMaxNottraytip         = window could not be maximized.
      lng_YMaxtraytip            = window is now vertically maximized.
      lng_YMaxNottraytip         = window could not be vertically maximized.
      lng_XMaxtraytip            = window is now horizontally maximized.
      lng_XMaxNottraytip         = window could not be horizontally maximized.
      lng_NoBtraytip             = buttons (SysMenu) removed from titlebar of window.
      lng_ExitWithOSError        = Error: Wrong operating system. Need Windows NT or newer!
      lng_ExitWithVersionError   = Error: Need AutoHotkey.exe version %h_MinReqAHK% or newer!
      lng_WindowTitle            = Min2Tray
      lng_SetupOK                = &Apply
      lng_SetupCancel            = &Cancel
      lng_SetupRemove            = &Remove
      lng_SetupEdit              = &Edit
      lng_SetupClose             = &Close
      lng_MenuPrefs              = &Preferences...
      lng_SetupTitle             = Prefs - %lng_WindowTitle%
      lng_SetupHint              = Hint: Press DELETE on keyboard and confirm by clicking "%lng_SetupOK%" to clear a hotkey!
      lng_SetupInvalidHotkey1    = The following hotkey could not be assigned: "
      lng_SetupInvalidHotkey2    = ".`nPlease use a different hotkey or delete the hotkey!
      lng_SetupEventError        = The following action contains an error, please correct or delete it:
      lng_SetupEventHint1        = To trigger several actions, concatenate them using "|" (pipe-sign).`nRemove an action by clearing its edit control.`n`nSupported TriggerActions are:
      lng_SetupEventHint2        =
      ( LTrim
         key1:<keystrokes to send>
         `t- activate window and send simulated keystrokes
         `t- special chars: # = winkey; ^ = CTRL; ! = ALT; + = SHIFT
         key2:<delay,keystrokes to send>
         `t- activate window and send simulated keystrokes
         `t- you have to set the "typing"-delay here, too (in milliseconds)
         key4:<keystrokes to send>
         `t- send simulated keystrokes to window, not activating it
         `t- use this i.e. to send chars to "cmd.exe"
         key5:<control,keystrokes to send>
         `t- send simulated keystrokes to a specified control of window
         `t- i.e. for "notepad.exe": key5:Edit1,This is text in notepad.
         key6:<delay,control,keystrokes to send>
         `t- send simulated keystrokes to a specified control of window
         `t- you have to set the "typing"-delay here, too (in milliseconds)
         act1:<activate window>
         `t- activate the window bringing it to front
         `t- useful after execution of key4 or key5
         act2:<re-activate last activate window>
         `t- bring last activate and remembered window to front
         `t- i.e. after un-hiding BossKey-minimized windows
         aot1:<make window always-on-top>
         `t- the only accepted parameters are:
         `t   ON = make window always-on-top
         `t   OFF = remove always-on-top from window
         nob1:<NoButtons mode>
         `t- the only accepted parameters are:
         `t   ON = remove buttons (SysMenu) from titlebar of window
         `t   OFF = show buttons again
         max1:<maximize window>
         `t- the only accepted parameters are:
         `t   X = maximize window horizontally
         `t   Y = maximize window vertically
         `t   BOTH = maximize window in both directions
         pos1:<X,Y,W,H>
         `t- change position and/or size of window:
         `t   X,Y = upper left corner in pixels
         `t   W,H = width and height in pixels
         `t- any value is optional (include the commas!)
         `t- blank values are left untouched, i.e.:
         `t   pos1:20,,,400 = X is 20p from left and height is 400p 
         `t   pos1:50,50 = set upper left corner to X=50p and Y=50p 
         `t   pos1:,,800,200 = set window size to 800 x 200 pixels 
         aud1:<manipulate master volume>
         `t- the only accepted parameters are:
         `t   MUTE_ON = mute the master volume
         `t   MUTE_OFF = unmute
         `t   MUTE_TOGGLE = toggle mute
         snd1:<path and filename>
         `t- play a soundfile (*.wav)
         `t- wait for it to finish
         snd2:<path and filename>
         `t- play a soundfile (*.wav)
         `t- do not wait for it to finish
         run1:<path and filename>
         `t- run a program 
         `t- do not wait for it to finish
         run2:<path and filename>
         `t- run a program (try to hide its window)
         `t- do not wait for it to finish
         run3:<path and filename>
         `t- run a program, do not wait for it to finish
         `t- last command line parameter is ahk_id of window
         rnw1:<path and filename>
         `t- run a program
         `t- wait for it to finish
         rnw2:<path and filename>
         `t- run a program (try to hide its window)
         `t- wait for it to finish
         rnw3:<path and filename>
         `t- run a program, wait for it to finish
         `t- last command line parameter is ahk_id of window
         msg1:<any text you want>
         `t- display a message box with text
         `t- window has one OK button
         slp1:<delay>
         `t- time to pause (in milliseconds)
         `t- between 0 and 2147483647 (24 days)
         min1:<minimize this window>
         `t- stop further processing of actions and
         `t- do minimize this window right away
         stm1:<manipulate StealthMode>
         `t- the only accepted parameters are:
         `t   ON = enforce StealthMode (show no icons)
         `t   OFF = turn off StealthMode
         `t   TOGGLE = toggle mode
         reg1:<type,subkey,name,value>
         `t- write a value to the registry:
         `t   type: REG_SZ, REG_DWORD, REG_BINARY, REG_EXPAND_SZ
         `t         or REG_MULTI_SZ
         `t   subkey: key below HKEY_CURRENT_USER, e.g. Software\MyApp
         `t   name: name of value to write to, may be blank for "(Default)"
         `t   value: the value to be written depending on type
         reg2:<subkey,name>
         `t- delete a value from the registry:
         `t   subkey: key below HKEY_CURRENT_USER, e.g. Software\MyApp
         `t   name: the name of the value to delete
         cfw1:<manipulate CheckForWin timer>
         `t- INTERNAL USE ONLY! does break things badly!
         `t- valid only for TriggerAction of minimized window, not BossKey
         `t- timer periodically checks the state of the window
         `t- the only accepted parameters are:
         `t   OFF = pause CheckForWin timer
         `t   ON = un-pause timer (ALWAYS DO THIS!)
      )
   }

   ; second: localization begins
   If ( lang = "de" ) {
      ; --- German ---
      If ( role = "helper" ) {
         lng_ExitWithParamError     = Fehler: Keine Nummer als erster Parameter übergeben!
         lng_MenuMultiWin           = &Liste der minimierten Fenster
         lng_MenuAssignHotkey       = &Hotkey zum Fenster-Anzeigen...
         lng_MenuClose              = &Schließe Fenster
         lng_MenuUnhide             = &Zeige Fenster
         lng_hClose1                = Wollen Sie das Fenster "
         lng_hClose2                = " wirklich schließen?
         lng_ChangeNameSelector     = Geben Sie bitte den neuen Namen ein:
         lng_ChangeIconSelector     = Wählen Sie eine Icon-Datei aus für "
         lng_ChangeIconSelectorExt  = Icon-Dateien
         lng_ChangeIconMulti        = Wählen Sie ein Icon aus für "
         lng_SetupUnhideKey         = Hotkey zum Fenster zeigen
         lng_SetupCustomName        = Weise eigenen Name zu
         lng_SetupCustomIcon        = Weise eigenes Icon zu.
         lng_SetupOnBKList          = Fenster ist auf BossKey-Liste.
         lng_SetupShowOnTitleChange = Zeige Fenster bei geändertem Titel.
         lng_SetupSOTCRegEx         = Optional: Nur wenn diese Regular Expression zutrifft:
         lng_SetupNoMinimize        = Minimiere sofort (übergehe Taskbar).
         lng_SetupOnSMList          = Fenster ist auf StartupMinimize-Liste.
         lng_SetupEventTitleH       = TriggerActions
         lng_SetupEvent1            = TA1: Nach Minimieren des Fensters
         lng_SetupEvent2            = TA2: Vor Wiederanzeige des Fensters
         lng_SetupEvent3            = TA3: Vor Schließen des Fensters
         lng_SetupEvent4            = TA4: Vor Beenden des Tray-Icons (Helfer)
         lng_SetupEvent5            = TA5: Nach Änderung des Fenster-Titels
         lng_SetupEvent6            = JTA: Bei StartupMinimize: NUR diese Aktionen ausführen!`nLeer lassen zum Ausführen der oben angegebenen Aktionen.`n(StartupMinimize muss dafür global und für dieses Fenster angeschaltet sein.)
      } Else If ( role = "starter" ) {
         lng_No2BtnMouseMsg			= Nicht genügend Maus-Knöpfe. Mausunterstützung abgeschaltet!
         lng_ExitWithRunningError   = Fehler: Min2Tray wurde schon einmal gestartet!
         lng_ExitWithAHKError       = Fehler: Konnte Datei "AutoHotkey.exe" nicht ausfindig machen!
         lng_ExitWithLockError      = Fehler: Konnte Lockfile nicht löschen. Bitte Datei von Hand löschen:
         lng_MenuAbout              = &Über %lng_WindowTitle%
         lng_MenuRestoreOnly        = &Alle Fenster wiederherstellen
         lng_MenuQuitRestoreAll     = &Wiederherstellen && beenden
         lng_MenuQuitOnly           = Nur &Beenden
         lng_MenuBKEditList         = &BossKey-Liste bearbeiten
         lng_MenuSMEditList         = &StartupMinimize-Liste bearbeiten
         lng_PurgeListHint          = Eingabefeld löschen, um beliebige Klassen ("class") oder Fenstertitel/ID ("window title") zu erfassen.`n`n"Window title" kann jeder Teil des Titels eines Fensters sein (z.B. "secret"). Regular Expressions werden unterstüzt.`n"ID" muss die eindeutige ID eines Fensters sein (z.B. "0xe02fe", ist gleich AutoHotkeys "ahk_id").`nUm auf verschiedene Fenstertitel oder IDs zu testen, müssen diese mit "|" (Pipe-Zeichen) verbunden werden.`nBeispiel einer gültigen Fenstertitel/ID-Zeile: "help|0xe02fe|beat the boss|0xe02fe".
         lng_BKPurgeListTitle       = BossKey-Liste
         lng_BKPurgeList            = Fenster markieren zum Bearbeiten oder Entfernen von der BossKey-Liste
         lng_BKPurgeListReq         = Soll der markierte Eintrag aus der BossKey-Liste gelöscht werden?
         lng_SMPurgeList            = Fenster markieren zum Bearbeiten oder Entfernen von der StartupMinimize-Liste
         lng_SMPurgeListTitle       = StartupMinimize-Liste
         lng_SMPurgeListReq         = Soll der markierte Eintrag aus der StartupMinimize-Liste gelöscht werden?
         lng_TrayTitle              = %lng_WindowTitle%
         lng_About1                 = %lng_WindowTitle% v%versionString% (%versionDate%)
         lng_About2                 = Minimiert Fenster in den Tray-Bereich der Taskbar als kleine Icons.`nDazu den dritten Mausknopf bzw. den benutzerdefinierten Hotkey drücken.`nWeitere Funktionalitäten: BossKey, Always-on-top, StartupMinimize,`nhorizontales bzw. vertikales Maximieren und einiges mehr.
         lng_About3                 = Vertrieben unter den Auflagen der GPLv3.`nErstellt von Junyx / KTC^brain im Juni 2005.
         lng_SetupKey               = Hotkey zum Fenster minimieren
         lng_SetupMButtonTitle      = Dritte (mittlere) Maustaste zum Minimieren nutzen?
         lng_SetupMButtonOpt0       = Kein Bedarf!
         lng_SetupMButtonOpt1       = durch Klicken auf Titelleiste [STANDARD]
         lng_SetupMButtonOpt2       = durch Klicken (egal wohin)
         lng_SetupRButton           = Minimieren durch Rechtsklick auf Schließen-Knopf der Titelleiste [NEIN]
         lng_SetupBkMultiWin        = BossKey setzt MultiWindows-Mode ein. [NEIN]
         lng_SetupBk2sMode          = BossKey-Nutzung erzwingt StealthMode (SM-Hotkey blendet Icons wieder ein). [NEIN]
         lng_SetupStealthSessOnly   = StealthMode nur für aktuelle Sitzung. [JA]
         lng_SetupForcedMode        = Erzwinge immer Min- bzw. Maximierung des Fensters (ForcedMode). [NEIN]
         lng_SetupJaakonMode        = Frage immer nach einem "Eigenen Name", wenn noch keiner vergeben wurde. [NEIN]
         lng_SetupNoMinGlobal       = Minimiere JEDES Fenster sofort ins Tray (übergehe Taskbar). [NEIN]
         lng_SetupClick2Mode        = Tray-Icon benötigt Doppelklick um Fenster wieder anzuzeigen (sonst Einfachklick). [NEIN]
         lng_SetupNoErrorMsgsMode   = Keinerlei Fehlermeldungen anzeigen. [NEIN]
         lng_SetupBossKey           = BossKey
         lng_SetupBKAddMouse        = STRG+UMSCHALT+dritte Maustaste zum Hinzufügen/Entfernen eines Fensters zu/von der BossKey-Liste. [NEIN]
         lng_SetupBKListToggle      = Hotkey zum Hinzufügen/Entfernen`neines Fensters zu/von der BossKey-Liste
         lng_BKListToggleOn         = Fenster zur BossKey-Liste hinzugefügt.
         lng_BKListToggleOff        = Fenster von BossKey-Liste entfernt.
         lng_SetupBKTitle           = BossKey-Modus bestimmen
         lng_SetupBKOpt0            = Blacklist: Minimiere alle Fenster AUSSER die der BossKey-Liste [STANDARD]
         lng_SetupBKOpt1            = Whitelist: Minimiere NUR Fenster der BossKey-Liste
         lng_SetupBKOpt2            = Topmost: Minimiere alle Fenster AUSSER das oberste (aktive)
         lng_SetupStealthKey        = Hotkey für StealthMode Umschaltung
         lng_SetupAOTKey            = Hotkey für Always-On-Top
         lng_SetupPrefsKey          = Hotkey zum Öffnen dieses Einstellungsfensters
         lng_SetupYMaxKey           = Hotkey für vertikales Maximieren
         lng_SetupXMaxKey           = Hotkey für horizontales Maximieren
         lng_SetupNoBKey            = Hotkey für NoButtons Umschaltung
         lng_SetupAOTSlider1        = Transparenz für Always-On-Top [NEIN]:
         lng_SetupAOTSlider2        = Opak
         lng_SetupAOTSlider3        = Transparent
         lng_SetupStartupTitle      = StartupMinimize
         lng_SetupStartupEnable     = StartupMinimize: Minimiere bestimmte Fenster bei jedem Start von Min2Tray automatisch. Aktiv nach Neustart. [NEIN]
         lng_SetupStartupTS1        = Zeitspanne:
         lng_SetupStartupTS2        = Sekunden
         lng_SetupStartupIN1        = Intervall:
         lng_SetupStartupIN2        = ms
         lng_SetupStartupHint       = Prüfe innerhalb der gegebenen Zeitspanne jeweils`nnach den spezifizierten Millisekunden (Intervall),`nob ein offenes Fenster zu minimieren ist.`nNach Ablauf der Zeitspanne wird "StartupMinimize"`nabgeschaltet.
         lng_SetupEventEnable       = Schalte TriggerActions global ein. [NEIN]
         lng_SetupEventTitleBK      = TriggerActions für BossKey
         lng_SetupEventBK1          = BK1: Bevor BossKey die Fenster minimiert
         lng_SetupEventBK2          = BK2: Nachdem BossKey die Fenster minimiert hat
      } Else {
         lng_AOTtraytip             = Fenster ist nun immer im Vordergrund.
         lng_Postraytip             = Benutzerdefinierte Position zugewiesen.
         lng_AMaxtraytip            = Fenster wurde maximiert.
         lng_AMaxNottraytip         = Fenster konnte nicht maximiert werden.
         lng_YMaxtraytip            = Fenster wurde vertikal maximiert.
         lng_YMaxNottraytip         = Fenster konnte nicht vertikal maximiert werden.
         lng_XMaxtraytip            = Fenster wurde horizontal maximiert.
         lng_XMaxNottraytip         = Fenster konnte nicht horizontal maximiert werden.
         lng_NoBtraytip             = Knöpfe (SysMenu) von Titelleiste des Fensters entfernt. 
         lng_ExitWithOSError        = Fehler: Falsches Betriebssystem. Benötige Windows NT und höher!
         lng_ExitWithVersionError   = Fehler: Benötige "AutoHotkey.exe" Version %h_MinReqAHK% oder höher!
         lng_WindowTitle            = Min2Tray
         lng_SetupOK                = Ü&bernehmen
         lng_SetupCancel            = &Abbrechen
         lng_SetupRemove            = &Entfernen
         lng_SetupClose             = &Schließen
         lng_SetupEdit              = &Bearbeiten
         lng_MenuPrefs              = &Einstellungen...
         lng_SetupTitle             = Einstellungen - %lng_WindowTitle%
         lng_SetupHint              = Hinweis: Drücken Sie ENTFERNEN und bestätigen Sie mit "%lng_SetupOK%", um einen Hotkey zu löschen!
         lng_SetupInvalidHotkey1    = Folgender Hotkey konnte nicht zugewiesen werden: "
         lng_SetupInvalidHotkey2    = ".`nBitte anderen Hotkey wählen oder den Hotkey entfernen!
         lng_SetupEventError        = Die folgende Aktion enthält einen Fehler, bitte korrigieren oder löschen:
         lng_SetupEventHint1        = Eingabefeld löschen, um die angegebenen Aktionen zu entfernen.`nUm mehrere Aktionen auszulösen, müssen diese mit "|" (Pipe-Zeichen) verbunden werden.`n`nUnterstützt werden folgende Aktionen:
         lng_SetupEventHint2        =
         ( LTrim
            key1:<zu sendende Tastendrücke>
            `t- aktiviere Fenster und sende simulierte Tastendrücke
            `t- Spezialzeichen: # = WIN; ^ = STRG; ! = ALT; + = UMSCHALT
            key2:<Verzögerung,zu sendende Tastendrücke>
            `t- aktiviere Fenster und sende simulierte Tastendrücke
            `t- Tastenverzögerung muss angegeben werden (in Millisekunden)
            key4:<zu sendende Tastendrücke>
            `t- sende Tastendrücke ans Fenster, ohne es zu aktivieren
            `t- nutze dies z.B. um Zeichen an "cmd.exe" zu senden
            key5:<Control,zu sendende Tastendrücke>
            `t- sende Tastendrücke an ein spezielles Control des Fensters
            `t- z.B. für "notepad.exe": key5:Edit1,Das ist Text im Editor.
            key6:<Verzögerung,Control,zu sendende Tastendrücke>
            `t- sende Tastendrücke an ein spezielles Control des Fensters
            `t- Tastenverzögerung muss angegeben werden (in Millisekunden)
            act1:<aktiviere Fenster>
            `t- aktiviere das Fenster und bringe es damit nach vorn
            `t- nützlich nach Ausführung von key4, key5 oder key6
            act2:<reaktiviere zuletzt aktives Fenster>
            `t- zuletzt aktives und gemerktes Fenster nach vorn bringen
            `t- z.B. nach Wiederanzeige von BossKey-versteckten Fenstern
            aot1:<Always-On-Top Modus für ein Fenster>
            `t- nur folgende Parameter werden erkannt:
            `t   ON = Fenster im Vordergrund halten (Always-On-Top)
            `t   OFF = entferne Always-On-Top von Fenster
            nob1:<NoButtons Modus für ein Fenster>
            `t- nur folgende Parameter werden erkannt:
            `t   ON = Knöpfe (SysMenu) von Titelleiste des Fensters entfernt
            `t   OFF = zeige Knöpfe wieder in Titelleiste
            max1:<ein Fenster maximieren>
            `t- nur folgende Parameter werden erkannt:
            `t   X = Fenster horizontal maximieren
            `t   Y = Fenster vertikal maximieren
            `t   BOTH = Fenster in beide Richtungen maximieren
            pos1:<X,Y,W,H>
            `t- verändere Position und/oder Größe des Fensters:
            `t   X,Y = linke obere Ecke in Pixel
            `t   W,H = Breite und Höhe in Pixel
            `t- jeder Wert ist optional (Kommas aber einfügen!)
            `t- leere Wertangaben bleiben unberührt, z.B.:
            `t   20,,,400 = X ist 20p von links und Höhe ist 400p 
            `t   50,50 = setze linke obere Ecke auf X=50p und Y=50p 
            `t   ,,800,200 = setze Fenstergröße auf 800 x 200 Pixel 
            aud1:<beeinflusse System-Lautstärkeregler>
            `t- nur folgende Parameter werden erkannt:
            `t   MUTE_ON = Stummschaltung ein
            `t   MUTE_OFF = Stummschaltung aus
            `t   MUTE_TOGGLE = Stummschaltung umkehren
            snd1:<Pfad und Dateiname>
            `t- spiele eine Musikdatei ab (*.wav)
            `t- warte auf deren Ende
            snd2:<Pfad und Dateiname>
            `t- spiele eine Musikdatei ab (*.wav)
            `t- warte nicht auf deren Ende
            run1:<Pfad und Dateiname>
            `t- starte ein Programm
            `t- warte nicht auf Programmende
            run2:<Pfad und Dateiname>
            `t- starte ein Programm (Fenster wird versteckt)
            `t- warte nicht auf Programmende
            run3:<Pfad und Dateiname>
            `t- starte ein Programm, warte nicht auf Programmende
            `t- letzter Kommandozeilenparameter ist ahk_id des Fensters
            rnw1:<Pfad und Dateiname>
            `t- starte ein Programm
            `t- warte auf Programmende
            rnw2:<Pfad und Dateiname>
            `t- starte ein Programm (Fenster wird versteckt)
            `t- warte auf Programmende
            rnw3:<Pfad und Dateiname>
            `t- starte ein Programm, warte auf Programmende
            `t- letzter Kommandozeilenparameter ist ahk_id des Fensters
            msg1:<beliebiger Text>
            `t- zeige Text in einem Dialogfenster an
            `t- Fenster hat einen OK-Knopf
            slp1:<Verzögerung>
            `t- Pause (in Millisekunden)
            `t- zwischen 0 und 2147483647 (24 Tage)
            min1:<minimiere dieses Fenster>
            `t- stoppe weitere Verarbeitung von Aktionen und
            `t- minimiere dieses Fenster sofort
            stm1:<beeinflusse StealthMode>
            `t- nur folgende Parameter werden erkannt:
            `t   ON = StealthMode einschalten (keine Icons anzeigen)
            `t   OFF = StealthMode ausschalten
            `t   TOGGLE = Modus umkehren
            reg1:<Typ,Unter,Name,Wert>
            `t- schreibe einen Wert in die Registry:
            `t   Typ: REG_SZ, REG_DWORD, REG_BINARY, REG_EXPAND_SZ
            `t         oder REG_MULTI_SZ
            `t   Unter: Schlüssel unter HKEY_CURRENT_USER, z.B. Software\MyApp
            `t   Name: zu beschreibender Wertname, kann leer sein für "(Standard)"
            `t   Wert: der zu schreibende Wert, abhängig vom Typ
            reg2:<Unter,Name>
            `t- lösche einen Wert aus der Registry:
            `t   Unter: Schlüssel unter HKEY_CURRENT_USER, z.B. Software\MyApp
            `t   Name: der zu löschende Wert
            cfw1:<verändere CheckForWin-Timer>
            `t- NUR FÜR INTERNE NUTZUNG! Lässt Min2Tray öfter abstürzen!
            `t- nur anwendbar für TriggerAction eines Fensters, nicht bei BossKey
            `t- der Timer überprüft periodisch den Status des minimierten Fensters
            `t- nur folgende Parameter werden erkannt:
            `t   OFF = halte den CheckForWin-Timer an
            `t   ON = starte den Timer wieder (IMMER NOTWENDIG!)
         )
      }
   }
   ; assemble about string (with translator greets)
   lng_About = %lng_About1%`n`n%lng_About2%`n`n%lng_About3%`n
   If ( lng_About4 )
      lng_About = %lng_About%--`n%lng_About4%`n
}

;EOF
