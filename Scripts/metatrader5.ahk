; === MetaTrader 5 Chart Enhancements (AutoHotkey v2.0) ===
; Makes MetaTrader 5 charts feel like TradingView
;
; Features:
;   1. Scroll wheel to zoom in/out horizontally
;   2. Left-drag to pan horizontally (auto Ctrl key)
;   3. Double-click to auto-fit chart
;   4. Shift+scroll to pan horizontally through time
;   5. Middle-click to activate Crosshair tool
;   6. Ctrl+scroll for fast zoom
;
; NOTE: MT5 does not support free vertical panning like TradingView.
;       The chart always auto-centers vertically on price action.
;       This is a platform limitation, not something AHK can fix.
;
; Based on NinjaTrader script, adapted for MT5
; =====================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

; --- Script Performance Settings ---
ProcessSetPriority "High"
A_MaxHotkeysPerInterval := 200

; --- Global Variables ---
global isCtrlSent := false
global isLButtonDown := false
global StartX := 0
global StartY := 0

; --- Configuration ---
global HORIZONTAL_PAN_BARS := 5       ; Number of bars to pan with Shift+scroll
global ZOOM_MULTIPLIER := 1           ; How many zoom steps per scroll tick

; --- Helper Function: Check if MetaTrader 5 Chart window is active ---
IsChartWindow() {
    try {
        hwnd := WinExist("A")
        if (!hwnd)
            return false

        class := WinGetClass(hwnd)
        title := WinGetTitle(hwnd)

        ; Check if it's an MT5 window with chart-like characteristics
        return (InStr(class, "MetaQuotes") || InStr(class, "Afx:")) && !InStr(title, "Navigator") && !InStr(title, "Toolbox") && !InStr(title, "Market Watch")
    } catch {
        return false
    }
}

; --- Drag Detection Function ---
CheckForDrag() {
    global isLButtonDown, isCtrlSent, StartX, StartY

    if (!isLButtonDown) {
        SetTimer(CheckForDrag, 0)
        return
    }

    if (isCtrlSent)
        return

    ; Check if mouse has moved enough to be a drag
    MouseGetPos(&CurrentX, &CurrentY)
    DistanceX := Abs(CurrentX - StartX)
    DistanceY := Abs(CurrentY - StartY)

    if (DistanceX > 3 || DistanceY > 3) {
        if (IsChartWindow()) {
            ; Hold Ctrl to enable horizontal panning in MT5
            Send "{Control Down}"
            isCtrlSent := true
            SetTimer(CheckForDrag, 0)
        }
    }
}

; === GLOBAL HOTKEY: Mouse Button Release ===
; Must be global to catch release even outside MetaTrader window
~LButton Up:: {
    global isLButtonDown, isCtrlSent

    isLButtonDown := false
    SetTimer(CheckForDrag, 0)

    if (isCtrlSent) {
        Send "{Control Up}"
        isCtrlSent := false
    }
}

; === CONTEXT-SENSITIVE HOTKEYS ===
; These only activate when MetaTrader 5 is the active window
#HotIf WinActive("ahk_exe terminal64.exe") || WinActive("ahk_exe terminal.exe")

; --- Scroll Wheel to Zoom (TradingView-style) ---
WheelUp:: {
    if (IsChartWindow()) {
        Loop ZOOM_MULTIPLIER {
            Send "{NumpadAdd}"  ; Zoom in (larger candles, fewer bars)
        }
    } else {
        Send "{WheelUp}"
    }
}

WheelDown:: {
    if (IsChartWindow()) {
        Loop ZOOM_MULTIPLIER {
            Send "{NumpadSub}"  ; Zoom out (smaller candles, more bars)
        }
    } else {
        Send "{WheelDown}"
    }
}

; --- Shift+Scroll for Horizontal Pan ---
+WheelUp:: {
    if (IsChartWindow()) {
        Loop HORIZONTAL_PAN_BARS {
            Send "{Left}"
        }
    }
}

+WheelDown:: {
    if (IsChartWindow()) {
        Loop HORIZONTAL_PAN_BARS {
            Send "{Right}"
        }
    }
}

; --- Ctrl+Scroll for Fast Zoom ---
^WheelUp:: {
    if (IsChartWindow()) {
        Loop (ZOOM_MULTIPLIER * 3) {
            Send "{NumpadAdd}"
        }
    }
}

^WheelDown:: {
    if (IsChartWindow()) {
        Loop (ZOOM_MULTIPLIER * 3) {
            Send "{NumpadSub}"
        }
    }
}

; --- Middle-Click to Activate Crosshair Tool ---
MButton:: {
    if (IsChartWindow()) {
        Send "^f"  ; Ctrl+F toggles crosshair in MT5
    } else {
        Send "{MButton}"
    }
}

; --- Left Click: Drag & Double-Click Detection ---
~LButton:: {
    global isLButtonDown, isCtrlSent, StartX, StartY

    ; Double-click detection (within 200ms)
    if (A_TimeSincePriorHotkey < 200 && A_PriorHotkey = "~LButton") {
        if (IsChartWindow()) {
            ; Double-click: return to current bar
            Send "{Home}"
        }
        return
    }

    ; Skip if modifier key is already held
    if (GetKeyState("Ctrl", "P") || GetKeyState("Shift", "P") || GetKeyState("Alt", "P"))
        return

    ; Start drag detection
    MouseGetPos(&StartX, &StartY)
    isLButtonDown := true
    isCtrlSent := false
    SetTimer(CheckForDrag, 20)
}

#HotIf  ; Reset context

; === TOOLTIP ON STARTUP ===
ToolTip "MT5 TradingView Controls Active`nScroll=Zoom | Shift+Scroll=Pan | MClick=Crosshair"
SetTimer () => ToolTip(), -3000
