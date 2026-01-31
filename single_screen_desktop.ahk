/*
@title Single-Screen-Desktop
@version 1.1.9
@author YourName
@description AHK v2 script to minimize windows only on the current monitor.
@license MIT
*/

#Requires AutoHotkey v2.0

; --- 全局环境配置 ---
; 强制使用全局屏幕坐标系，确保多显示器环境下鼠标与窗口判定永不飘移
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"

SetWinDelay -1 ; 极速模式，消除窗口最小化动画的排队感
global MonitorHistory := Map()
global LastActiveWindows := Map()

; --- 快捷键设定：Alt + D ---
!d:: {
    global MonitorHistory, LastActiveWindows

    ; 1. 定位当前操作目标（鼠标所在的显示器）
    MouseGetPos(&mouseX, &mouseY)
    mIndex := 1
    mCount := MonitorGetCount()
    loop mCount {
        MonitorGet(A_Index, &mL, &mT, &mR, &mB)
        if (mouseX >= mL && mouseX <= mR && mouseY >= mT && mouseY <= mB) {
            mIndex := A_Index
            break
        }
    }
    MonitorGet(mIndex, &mLeft, &mTop, &mRight, &mBottom)

    ; 初始化显示器独立的存储空间
    if !MonitorHistory.Has(mIndex)
        MonitorHistory[mIndex] := []

    ; 2. 扫描该物理显示器内的可见窗口
    currentVisible := []
    allWindows := WinGetList()
    
    for hwnd in allWindows {
        if !WinExist(hwnd)
            continue
            
        style := WinGetStyle(hwnd)
        exStyle := WinGetExStyle(hwnd)
        title := WinGetTitle(hwnd)
        class := WinGetClass(hwnd)

        ; 过滤系统组件及无标题的干扰窗口
        if (title == "" || class ~= "Shell_TrayWnd|WorkerW|Progman|EdgeUiInputWndClass")
            continue

        ; 兼容性判定逻辑：支持微信、Discord等自定义UI窗口
        if ((style & 0x10000000) && !(exStyle & 0x80) && WinGetMinMax(hwnd) != -1) {
            WinGetPos(&wX, &wY, &wWidth, &wHeight, hwnd)
            
            ; 计算窗口重心 P(cX, cY)
            cX := wX + (wWidth / 2)
            cY := wY + (wHeight / 2)

            ; 只有窗口中心点在目标显示器内才执行操作
            if (cX >= mLeft && cX <= mRight && cY >= mTop && cY <= mBottom) {
                currentVisible.Push(hwnd)
            }
        }
    }

    ; --- 核心逻辑决策 ---

    ; 情况 A：当前屏幕有可见窗口 -> 执行最小化并记录
    if (currentVisible.Length > 0) {
        ; 记录当前焦点：仅当活跃窗口确实在鼠标所在屏幕时才记录
        activeHwnd := WinExist("A")
        if (activeHwnd) {
            WinGetPos(&aX, &aY, &aW, &aH, activeHwnd)
            if (aX + aW/2 >= mLeft && aX + aW/2 <= mRight)
                LastActiveWindows[mIndex] := activeHwnd
        }

        MonitorHistory[mIndex] := [] ; 重置该屏幕的恢复历史
        Critical "On"
        for hwnd in currentVisible {
            MonitorHistory[mIndex].Push(hwnd)
            WinMinimize(hwnd)
        }
        Critical "Off"
    } 
    ; 情况 B：当前屏幕已经是桌面状态 -> 尝试恢复该屏幕之前的窗口
    else if (MonitorHistory.Has(mIndex) && MonitorHistory[mIndex].Length > 0) {
        history := MonitorHistory[mIndex]
        loop history.Length {
            hwnd := history.Pop()
            if WinExist(hwnd)
                WinRestore(hwnd)
        }
        
        ; 安全删除键值对，防止 "Item has no value" 报错
        if (LastActiveWindows.Has(mIndex)) {
            if WinExist(LastActiveWindows[mIndex])
                WinActivate(LastActiveWindows[mIndex])
            LastActiveWindows.Delete(mIndex)
        }
    }
}