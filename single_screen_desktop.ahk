/*
@title Single-Monitor-Desktop
@version 1.0
@author blunt
@description AHK v2 script to minimize windows only on the current monitor.
@license MIT
*/

#Requires AutoHotkey v2.0

; --- 全局设置 / Global Settings ---
SetWinDelay -1 ; 极速模式，消除窗口操作延迟
global LastMinimizedWindows := []
global LastActiveWindowID := 0

; --- 快捷键设定 / Hotkey: Alt + D ---
!d:: {
    global LastMinimizedWindows, LastActiveWindowID

    ; 模式 A：恢复窗口 (Restore Mode)
    if (LastMinimizedWindows.Length > 0) {
        loop LastMinimizedWindows.Length {
            windowHandle := LastMinimizedWindows.Pop()
            if WinExist(windowHandle) {
                WinRestore(windowHandle)
            }
        }
        
        ; 恢复焦点记忆 (Focus Memory)
        if (LastActiveWindowID && WinExist(LastActiveWindowID)) {
            WinActivate(LastActiveWindowID)
        }
        
        LastActiveWindowID := 0 
        return
    }

    ; 模式 B：最小化模式 (Minimize Mode)
    MouseGetPos(&mouseX, &mouseY)
    
    ; 定位显示器逻辑 (Screen Detection)
    monitorIndex := 1
    monitorCount := MonitorGetCount()
    loop monitorCount {
        MonitorGet(A_Index, &mL, &mT, &mR, &mB)
        if (mouseX >= mL && mouseX <= mR && mouseY >= mT && mouseY <= mB) {
            monitorIndex := A_Index
            break
        }
    }
    MonitorGet(monitorIndex, &mLeft, &mTop, &mRight, &mBottom)

    ; 记录当前活跃窗口 (Record Active Window)
    LastActiveWindowID := WinExist("A")
    allWindows := WinGetList()
    
    Critical "On" ; 开启临界区保护，提升执行效率
    for windowHandle in allWindows {
        ; 排除非窗口类（任务栏、桌面等）
        if !WinExist(windowHandle) || WinGetClass(windowHandle) = "Shell_TrayWnd" || WinGetClass(windowHandle) = "WorkerW" || WinGetClass(windowHandle) = "Progman"
            continue

        if (WinGetMinMax(windowHandle) != -1) {
            WinGetPos(&wX, &wY, &wWidth, &wHeight, windowHandle)
            centerX := wX + (wWidth / 2)
            centerY := wY + (wHeight / 2)

            ; 判断中心点是否在目标屏幕
            if (centerX >= mLeft && centerX <= mRight && centerY >= mTop && centerY <= mBottom) {
                style := WinGetStyle(windowHandle)
                if (style & 0x20000) { ; 0x20000 为 WS_MINIMIZEBOX
                    LastMinimizedWindows.Push(windowHandle)
                    WinMinimize(windowHandle)
                }
            }
        }
    }
    Critical "Off"
}