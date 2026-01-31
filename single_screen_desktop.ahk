/*
@title Single-Screen-Desktop (V2 Fix Version)
@version 1.1.8
@description 修复 v2 语法下 CoordMode 参数失效的问题，保持全局坐标一致性
*/

#Requires AutoHotkey v2.0

; 【核心修复】v2 中只需锁定 Mouse 坐标模式。WinGetPos 在 v2 中默认即为屏幕坐标。
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen" ; 某些像素计算函数会用到，作为全局锁定的双保险

SetWinDelay -1
global MonitorHistory := Map()
global LastActiveWindows := Map()

!d:: {
    global MonitorHistory, LastActiveWindows

    ; 1. 获取全局鼠标位置
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

    if !MonitorHistory.Has(mIndex)
        MonitorHistory[mIndex] := []

    ; 2. 扫描物理显示器范围内的窗口
    currentVisible := []
    allWindows := WinGetList()
    
    for hwnd in allWindows {
        if !WinExist(hwnd)
            continue
            
        style := WinGetStyle(hwnd)
        exStyle := WinGetExStyle(hwnd)
        title := WinGetTitle(hwnd)
        class := WinGetClass(hwnd)

        ; 过滤系统组件
        if (title == "" || class ~= "Shell_TrayWnd|WorkerW|Progman|EdgeUiInputWndClass")
            continue

        ; 判定：可见 + 非浮窗 + 非最小化
        if ((style & 0x10000000) && !(exStyle & 0x80) && WinGetMinMax(hwnd) != -1) {
            ; AHK v2 的 WinGetPos 始终返回屏幕绝对坐标
            WinGetPos(&wX, &wY, &wWidth, &wHeight, hwnd)
            
            cX := wX + (wWidth / 2)
            cY := wY + (wHeight / 2)

            ; 只有在目标显示器矩形内的窗口才会被处理
            if (cX >= mLeft && cX <= mRight && cY >= mTop && cY <= mBottom) {
                currentVisible.Push(hwnd)
            }
        }
    }

    ; --- 逻辑判断 ---
    if (currentVisible.Length > 0) {
        ; 记录焦点窗口
        activeHwnd := WinExist("A")
        if (activeHwnd) {
            WinGetPos(&aX, &aY, &aW, &aH, activeHwnd)
            if (aX + aW/2 >= mLeft && aX + aW/2 <= mRight)
                LastActiveWindows[mIndex] := activeHwnd
        }

        MonitorHistory[mIndex] := []
        Critical "On"
        for hwnd in currentVisible {
            MonitorHistory[mIndex].Push(hwnd)
            WinMinimize(hwnd)
        }
        Critical "Off"
    } 
    else if (MonitorHistory.Has(mIndex) && MonitorHistory[mIndex].Length > 0) {
        history := MonitorHistory[mIndex]
        loop history.Length {
            hwnd := history.Pop()
            if WinExist(hwnd)
                WinRestore(hwnd)
        }
        if (LastActiveWindows.Has(mIndex) && WinExist(LastActiveWindows[mIndex])) {
            WinActivate(LastActiveWindows[mIndex])
        }
        LastActiveWindows.Delete(mIndex)
    }
}