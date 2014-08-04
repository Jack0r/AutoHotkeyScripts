; 
; AutoHotkey Version: 1.x 
; Language: English 
; Author: Lowell Heddings | geek@howtogeek.com 
; 
; Script Function: 
; enable paste in the Windows command prompt 
; 

#IfWinActive ahk_class ConsoleWindowClass 
^V:: SendInput {Raw}%clipboard% 
return 

#IfWinActive