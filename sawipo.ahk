; #NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
#Persistent
#MaxThreads 40
#SingleInstance Force
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
CoordMode, ToolTip, Screen
CoordMode, Mouse, Screen
CoordMode, Pixel, Screen
SetTitleMatchMode, 3

If !A_IsAdmin
{
    try Run *RunAs "%A_ScriptFullPath%"
    ExitApp
}

Global inifile := "sawipo.ini"
Global excwin := "ExcludedWindows.txt"
Global WindowSet
Global WinList := []
Global LastUsedProfile
Global menutitletext := "active:"

FileCheck()

BuildProfileMenu()

return


; Labels
menuhandle:
	If (A_ThisMenu == "Tray" && A_ThisMenuItem == menutitletext . " " . LastUsedProfile)
		MoveWindowsToSavedPosition()
		
	If (A_ThisMenu == "profiles")
		ProfileHandle(A_ThisMenuItem)
		
	If (A_ThisMenu == "deleteprofile") 
		DeleteProfileHandle(A_ThisMenuItem)
		
	If (A_ThisMenuItem == "open sawipo.ini")
		Run, %inifile%
		
	If (A_ThisMenuItem == "open ExcludedWindows.txt")
		Run, %excwin%
return


; Functions
AddNewProfil() {
	InputBox, OutputVar, Sawipo, New profile name:,, 150, 125
	IniWrite, this, %inifile%, %OutputVar%, delete
	IniDelete, %inifile%, %OutputVar%, delete
	WindowSet := OutputVar
	Menu, Tray, Rename, %menutitletext% %LastUsedProfile%, %menutitletext% %OutputVar%
	Menu, Tray, Default, %menutitletext% %OutputVar%
	Menu, profiles, Add, %OutputVar%, menuhandle, +Radio
	Menu, deleteprofile, Add, %OutputVar%, menuhandle
	LastUsedProfile := OutputVar
	SaveWinPos()
	CheckUncheckMenuItems()
}

BuildProfileMenu() {
	sections := []
	IniRead, OutputVarSectionNames, %inifile%
	ReplacedStr := StrReplace(OutputVarSectionNames, "Settings`n")
	sections := StrSplit(ReplacedStr, "`n")
	altprofile := sections[1]
	IniRead, LastUsedProfile, %inifile%, Settings, LastUsedProfile, %altprofile%
	(LastUsedProfile == "") ? LastUsedProfile := altprofile
	WindowSet := LastUsedProfile

	Menu, Tray, NoStandard
	Menu, Tray, Add, %menutitletext% %LastUsedProfile%, menuhandle
	Menu, Tray, Disable, %menutitletext% %LastUsedProfile%
	Menu, Tray, Add
	Menu, Tray, Add, open sawipo.ini, menuhandle
	Menu, Tray, Add, open ExcludedWindows.txt, menuhandle
	Menu, Tray, Add
	Menu, Tray, Add, add profile, AddNewProfil
	MenuItemProfileDelete(sections)
	Menu, Tray, Add
	Menu, Tray, Add, save windows positions, SaveWinPos
	Menu, Tray, Add
	MenuItemProfiles(sections)
	Menu, Tray, Add
	Menu, Tray, Add, move windows, MoveWindowsToSavedPosition
	Menu, Tray, Add
	Menu, Tray, Add, exit, MyExit
	Menu, Tray, Default, %menutitletext% %LastUsedProfile%
	Menu, Tray, Tip, Sawipo
	Menu, Tray, Click, 1
}

CheckUncheckMenuItems() {
	IniRead, OutputVarSectionNames, %inifile%
	ReplacedStr := StrReplace(OutputVarSectionNames, "Settings`n")
	sections := StrSplit(ReplacedStr, "`n")
	Loop % sections.MaxIndex()
	{
		profile := sections[A_Index]
		Menu, Profiles, Uncheck, %profile%
	}
	Menu, Profiles, Check, %WindowSet%
        IniWrite, %WindowSet%, %inifile%, Settings, LastUsedProfile
}

DeleteProfileHandle(profile) {
	MsgBox, 4, Sawipo, delete profile: %profile% ?
	
	IfMsgBox No
		Return
	
	IfMsgBox Yes 
	{
		IniRead, OutputVarSectionNames, %inifile%
		ReplacedStr := StrReplace(OutputVarSectionNames, "Settings`n")
		sections := StrSplit(ReplacedStr, "`n")
		If (sections.MaxIndex() != 1) {
			IniDelete, %inifile%, %profile%
			If (LastUsedProfile == profile)
				SelectFirstFoundedSettings()
			Menu, profiles, Delete, %profile%
			Menu, deleteprofile, Delete, %profile%
			CheckUncheckMenuItems()
		} Else {
			MsgBox, The last profile can't be deleted.
		}
	}
	
}

FileCheck() {
	If !FileExist(inifile) {
                IniWrite, default, %inifile%, Settings, LastUsedProfile
		IniWrite, this, %inifile%, default, delete
		IniDelete, %inifile%, default, delete
	}
	If !FileExist(excwin) {
                FileAppend,
(
.ahk
.ini
Epic Games Launcher
Pinnacle Game Profiler
), %excwin%
	}
}

isExcludedWindow(wt) {
	file := []
	r := false
	Loop
	{
		FileReadLine, line, %excwin%, %A_Index%
		If ErrorLevel
			Break

		If InStr(wt, line)
                	r := true
	}
	return r
}

isWindowFullScreen( winTitle = "A" ) {
	;checks if the specified window is full screen

	WinGetTitle, winTitle, %winTitle%
	winID := WinExist( winTitle )

	If ( !winID )
		Return false

    	WinGetClass, c, ahk_id %winID%
    	If ((c = "Progman") || (c = "WorkerW"))
		Return False

	WinGet style, Style, ahk_id %WinID%
	WinGetPos ,,,winW,winH, %winTitle%

	; 0x800000 is WS_BORDER.
	; 0x20000000 is WS_MINIMIZE.
	; no border and not minimized

	ret:=(((style == 0x160B0000) || (style == 0x16CF0000)) && (winH >= A_ScreenHeight && winW >= A_ScreenWidth)) OR !(((style & 0x20800000) or winH < A_ScreenHeight or winW < A_ScreenWidth)) ? true : false
	Return ret
}

ListAllowedWindows() {
	ReturnList := []
	; DetectHiddenWindows, On
	WinGet windows, List
	Loop %windows%
	{
		id := windows%A_Index%

		WinGetTitle WinTitle, ahk_id %id%
		If !WinTitle
			Continue

		WinGetClass, c, ahk_id %id%
		If (c = "Progman") || (c = "WorkerW")
			Continue

		WinGet, Style, Style, ahk_id %id%
		If !(Style & 0x10000000) ; 0x10000000 is WS_VISIBLE
			Continue

		If isWindowFullScreen("ahk_id " . id)
			Continue

		WinGetPos, x, y, w, h, ahk_id %id%
		If (x == -32000) or (y == -32000)
			Continue

		If isExcludedWindow(WinTitle)
			Continue

                WinGet, app, ProcessName, ahk_id %id%

		ReturnList.Push({title: WinTitle, app: app, x: x, y:y, w: w, h: h})
		r .= WinTitle . "`n"

	}
	; DetectHiddenWindows, Off
	; MsgBox, %r%
	Return ReturnList
}

MenuItemProfiles(sections) {
	Loop % sections.MaxIndex()
	{
		profile := sections[A_Index]
		Menu, profiles, Add, %profile%, menuhandle, Radiobutton +Radio
	}
	
	Menu, profiles, Check, %LastUsedProfile%
	Menu, Tray, Add, profiles, :profiles
}

MenuItemProfileDelete(sections) {
	Loop % sections.MaxIndex()
	{
		profile := sections[A_Index]
		Menu, deleteprofile, Add, %profile%, menuhandle
	}
	Menu, Tray, Add, delete profile, :deleteprofile
}

MoveWindowsToSavedPosition() {
	WinList := []
	WinList := ListAllowedWindows()
	Loop % WinList.MaxIndex()
	{
		bda := WinList[A_Index]
		title := bda["title"]
		id := WinExist(title)
		
                If InStr(title, "Discord")
                        title := "Discord"
                
                If InStr(title, "Google Chrome")
                        title := "Google Chrome"
                        
                If InStr(title, "YouTube")
                        title := "YouTube"

		IniRead, str, %inifile%, %WindowSet%, %title%, SKIP
		If (str == "SKIP")
			Continue

		inibda := StrSplit(str, ";")

		app := inibda[1]
		x := inibda[2]
		y := inibda[3]
		w := inibda[4]
		h := inibda[5]
		
		WinMove, ahk_id %id%,, x, y, w, h
	}
}

MyExit() {
	ExitApp
}

ProfileHandle(profile) {
	WindowSet := profile
	Menu, Tray, Rename, %menutitletext% %LastUsedProfile%, %menutitletext% %profile%
	Menu, Tray, Default, %menutitletext% %profile%
	LastUsedProfile := profile
	CheckUncheckMenuItems()
}

SaveWinPos() {
	MsgBox, 4, Sawipo, Save windows position in %LastUsedProfile% ?
	
	IfMsgBox No
		Return
	
	IfMsgBox Yes 
	{
		WinList := []
		WinList := ListAllowedWindows()
		Loop % WinList.MaxIndex()
		{
			bda := WinList[A_Index]
			app := bda["app"]
			title := bda["title"]
			x := bda["x"]
			y := bda["y"]
			w := bda["w"]
			h := bda["h"]
			
	                If InStr(title, "Discord")
	                        title := "Discord"
	                
	                If InStr(title, "Google Chrome")
	                        title := "Google Chrome"
	                        
	                If InStr(title, "YouTube")
	                        title := "YouTube"
	
	            IniWrite, %app%;%x%;%y%;%w%;%h%, %inifile%, %WindowSet%, %title%
		}
	}
}

SelectFirstFoundedSettings() {
	IniRead, OutputVarSectionNames, %inifile%
	ReplacedStr := StrReplace(OutputVarSectionNames, "Settings`n")
	sections := StrSplit(ReplacedStr, "`n")
	OldLastUsedProfile := LastUsedProfile
	LastUsedProfile := sections[sections.MaxIndex()]
	(LastUsedProfile == "") ? LastUsedProfile := "default"
	WindowSet := LastUsedProfile
	
	Menu, Profiles, Check, %WindowSet%
	Menu, Tray, Rename, %menutitletext% %OldLastUsedProfile%, %menutitletext% %WindowSet%
	Menu, Tray, Default, %menutitletext% %WindowSet%
}