; ==============================================================================
; 功能：进阶版 Alt + D (完美对标 Windows 原生逻辑)
; 逻辑：
; 1. 如果当前屏幕有可见窗口 -> 最小化它们（并更新记录）
; 2. 如果当前屏幕已清空 -> 尝试恢复上一次记录的窗口
; ==============================================================================

SetWinDelay -1
global LastMinimizedWindows := []
global LastActiveWindowID := 0

!d:: {
    global LastMinimizedWindows, LastActiveWindowID

    ; 1. 获取当前显示器范围
    MouseGetPos(&mouseX, &mouseY)
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

    ; 2. 扫描当前屏幕上是否有“可见”窗口
    currentVisibleWindows := []
    allWindows := WinGetList()
    
    for windowHandle in allWindows {
        if !WinExist(windowHandle) || WinGetClass(windowHandle) = "Shell_TrayWnd" || WinGetClass(windowHandle) = "WorkerW" || WinGetClass(windowHandle) = "Progman"
            continue

        ; 只处理非最小化状态的窗口
        if (WinGetMinMax(windowHandle) != -1) {
            WinGetPos(&wX, &wY, &wWidth, &wHeight, windowHandle)
            centerX := wX + (wWidth / 2)
            centerY := wY + (wHeight / 2)

            if (centerX >= mLeft && centerX <= mRight && centerY >= mTop && centerY <= mBottom) {
                style := WinGetStyle(windowHandle)
                if (style & 0x20000) { 
                    currentVisibleWindows.Push(windowHandle)
                }
            }
        }
    }

    ; --- 核心逻辑判断 ---
    
    ; 情况 A：当前屏幕还有窗口在挡着 -> 执行最小化
    if (currentVisibleWindows.Length > 0) {
        LastMinimizedWindows := [] ; 清空旧记录，开始新记录
        LastActiveWindowID := WinExist("A") ; 记录当前的焦点窗口

        Critical "On"
        for windowHandle in currentVisibleWindows {
            LastMinimizedWindows.Push(windowHandle)
            WinMinimize(windowHandle)
        }
        Critical "Off"
    } 
    ; 情况 B：当前屏幕已经是桌面了 -> 尝试恢复
    else if (LastMinimizedWindows.Length > 0) {
        loop LastMinimizedWindows.Length {
            windowHandle := LastMinimizedWindows.Pop()
            if WinExist(windowHandle) {
                WinRestore(windowHandle)
            }
        }
        if (LastActiveWindowID && WinExist(LastActiveWindowID)) {
            WinActivate(LastActiveWindowID)
        }
        LastActiveWindowID := 0
    }
}