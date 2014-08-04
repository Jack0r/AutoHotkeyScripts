;————————————————————————————————————————————-
; CONTROL T - CONVERT SELECTED TEXT OR LINE TO TITLE CASE
;————————————————————————————————————————————-

^t::
Clipboard =
SendInput, ^c
ClipWait,0.1
if % strlen(Clipboard) = 0
	{
	send,{HOME}{SHIFTDOWN}{END}{SHIFTUP}
	SendInput, ^c
	ClipWait,0.1
	Selection = true
}

if % strlen(Clipboard) <> 0
	{
	Clipboard := ChangeCase(Clipboard,"Title")
	SendInput, ^v
	selection = false
}

if selection then
send {DOWN}{HOME}
return

;————————————————————————————————————————————-
; CONTROL U - CONVERT SELECTED TEXT OR LINE TO UPPER CASE
;————————————————————————————————————————————-

^u::
Clipboard =
SendInput, ^c
ClipWait,0.1
if % strlen(Clipboard) = 0
	{
	send,{HOME}{SHIFTDOWN}{END}{SHIFTUP}
	SendInput, ^c
	ClipWait,0.1
	Selection = true
}

if % strlen(Clipboard) <> 0
	{
	Clipboard := ChangeCase(Clipboard,"Upper")
	SendInput, ^v
	selection = false
}

if selection then
send {DOWN}{HOME}
return

;————————————————————————————————————————————-
; CONTROL L - CONVERT SELECTED TEXT OR LINE TO LOWER CASE
;————————————————————————————————————————————-

^l::
clipboard =
SendInput, ^c
ClipWait,0.1
if % strlen(Clipboard) = 0
	{
	send,{HOME}{SHIFTDOWN}{END}{SHIFTUP}
	SendInput, ^c
	ClipWait,0.1
	Selection = true
}

if % strlen(Clipboard) <> 0
	{
	Clipboard := ChangeCase(Clipboard,"Lower")
	SendInput, ^v
	selection = false
}

if selection then
send {DOWN}{HOME}
return

;————————————————————————————————————————————-
; ChangeCase FUNCTION
;————————————————————————————————————————————-

ChangeCase(String, Mode) {
	Exceptions = DVD,VCR,CD,VHS,TV,HH,RV,SUV,ATV,RV,ATV,TGIF,IHOP,BBQ,BLT,HMO,PPO,CCU,ICU,OSHA,EPA,NASA,EU,DIY,COO,CIO,CEO,CFO,EVP,VP,MD,DDS,DVDs,CDs,TVs,SUVs,RVs,PBS,TLC,VoD,TiVo,AOL,PTA,BCBS,R&B,HD,LCD,WIFI,WIFI,iPod,XM,PlayStation,USB,PayPal,MSN,BMW,NFL,NBA,NASCAR,NHL,AT&T,McDonalds,ICD,CRT-D,CRT-P,ATM,PIN,ICDs,CABG,McDonald's,P3M,P6M,P12M,iPhone,VoIP,iPhoto,iDVD,iWeb,MobileMe,iCal,iSync,iTunes,iWork,iPad,P30D,N12M,P90D,AMEX,etc.,www,U.S.,i.e.,e.g.,(s),(ren),vs.,ZC
Exceptions2 = /A,/B,/C,/D,/E,/F,/G,/H,/I,/J,/K,/L,/M,/N,/O,/P,/Q,/R,/S,/T,/U,/V,/W,/X,/Y,/Z
	StringLower Mode, Mode
If (Mode = "upper")
	StringUpper String, String
If (Mode = "lower")
	StringLower String, String
If (Mode = "title")
	StringUpper String, String, T
	Loop Parse, Exceptions, `,
	String := RegExReplace(String,"i)\b" A_LoopField "\b", A_LoopField)
Return String
}