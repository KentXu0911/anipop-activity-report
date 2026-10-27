local UBFHappyDeliveryPassLevelView = class("UBFHappyDeliveryPassLevelView")

local SFX = {
    goin = UBFAudioKey.kHappyDeliveryGoin,
    upgrade1 = UBFAudioKey.kHappyDeliveryUpgrade1,
    upgrade2 = UBFAudioKey.kHappyDeliveryUpgrade2,
    upgrade3 = UBFAudioKey.kHappyDeliveryUpgrade3,
    boxdown = UBFAudioKey.kHappyDeliveryBoxDown,
    open1 = UBFAudioKey.kHappyDeliveryOpen1,
    open2 = UBFAudioKey.kHappyDeliveryOpen2,
    idle = UBFAudioKey.kHappyDeliveryIdle,
    progress = UBFAudioKey.kHappyDeliveryProgress,
}

local function playSfx(key)
    UBFAudioManager:playSound(SFX[key])
end

local HappyDeliveryConst = require "amf.feature.localactivity.happydelivery.config.HappyDeliveryConst"
local function playHaptics(key)
    HapticsManager:playInActScene(HappyDeliveryConst.Haptics[key])
end

local function progressToWidth(progress)
    if progress <= 0 then return 0 end
    return 65 + (progress - 1) * 83
end

local BAR_ANIM_TIME = 0.7

function UBFHappyDeliveryPassLevelView:ctor()
end

function UBFHappyDeliveryPassLevelView:create(displayData, scene, scheduler, onSuccess)
    local inst = UBFHappyDeliveryPassLevelView.new()
    inst:_init(displayData, scene, scheduler, onSuccess)
    return inst
end

function UBFHappyDeliveryPassLevelView:_init(displayData, scene, scheduler, onSuccess)
    self._scheduler  = scheduler
    self._onSuccess  = onSuccess
    self._entries    = {}
    local initBoxLevel   = displayData.initBoxLevel   or 1
    local curProgress    = displayData.curProgress    or 0
    local totalProgress  = displayData.totalProgress  or 1
    local upgradeScript  = type(displayData.upgradeScript) == "table" and displayData.upgradeScript or {0, 0, 0}
    for i = 1, 3 do
        if upgradeScript[i] == nil then upgradeScript[i] = 0 end
    end
    local isLuckyUpgrade = displayData.isLuckyUpgrade
    local finalRewards   = displayData.finalRewards   or {}
    local mergedRewards  = {}
    local mergedMap      = {}
    for _, reward in ipairs(finalRewards) do
        local id = reward.itemId or reward.rewardId
        if id and mergedMap[id] then
            mergedMap[id].num = (mergedMap[id].num or 0) + (reward.num or 0)
        elseif id then
            local entry = {itemId = id, num = reward.num or 0}
            table.insert(mergedRewards, entry)
            mergedMap[id] = entry
        end
    end
    local finalSplitCount = displayData.finalSplitCount or 0
    local finalBoxCount   = finalSplitCount > 0 and (1 + finalSplitCount) or 0

    local oldProgress = curProgress
    local newProgress = math.min(curProgress + 1, totalProgress)
    local isFull      = newProgress >= totalProgress

    self._curBoxLevel    = initBoxLevel
    self._initBoxLevel   = initBoxLevel
    self._upgradeScript  = upgradeScript
    self._isLuckyUpgrade = isLuckyUpgrade
    self._finalRewards   = mergedRewards
    self._finalSplitCount = finalBoxCount
    self._totalUpgrades  = #upgradeScript
    self._isFull         = isFull
    self._taskIndex      = displayData.taskIndex
    self._totalProgress  = totalProgress
    self._panelId        = UICreateUtil:getPanelId("HappyDeliveryPassLevel")

    local clampedTotal = math.min(math.max(totalProgress, 1), 5)
    local clampedOld   = math.min(math.max(oldProgress,   0), clampedTotal)
    local clampedNew   = math.min(math.max(newProgress,   0), clampedTotal)
    self._clampedTotal = clampedTotal
    self._clampedNew   = clampedNew

    local winSize  = CCDirector:sharedDirector():getWinSize()
    local panelH   = 1560
    local offsetY  = (winSize.height - panelH) / 2
    local ui = UBFRawViewCreator:createView({
        type     = UBFRawViewCreator.ViewType.kUI,
        lua      = "ubf/UBFActivity/actFolder/HappyDelivery/view/happydeliverypasslevel_UI.lua",
        position = ccp(0, offsetY),
    })
    self._ui = ui

    _G.amfBean("PopoutManager"):add(ui, 180)
    self._panel = ui.fields.panel or ui

    self._label1   = ui.fields.label1
    self._continue = ui.fields["continue"]
    self._box      = ui.fields.box
    self._title    = ui.fields.title
    if isSafeCocosObj(self._title) then self._title:setZOrder(20) end

    self._rBg          = ui.fields.r_bg
    self._rLabel2      = ui.fields.r_label2
    self._rLabel2Text  = ui.fields.r_label2_label_copy
    self._rTitle       = ui.fields.r_title
    if isSafeCocosObj(self._rTitle) then self._rTitle:setZOrder(20) end
    self._rBottom      = ui.fields.r_bottom

    for _, node in ipairs({self._rBg, self._rLabel2, self._rTitle, self._rBottom}) do
        if isSafeCocosObj(node) then node:setVisible(false) end
    end

    local bars = {}
    for i = 1, 5 do
        bars[i] = ui.fields["bar" .. i]
    end
    self._bars = bars

    self:_setupBars(totalProgress, oldProgress, newProgress)
    self:_setupDeliverLabel(isFull, newProgress, totalProgress)
    self:_setupBoxSpine(initBoxLevel)

    if isSafeCocosObj(self._boxContainer) then
        self._boxContainer:setPositionY(self._boxContainer:getPositionY() - 3)
    end
    if isSafeCocosObj(self._label1) then
        self._label1:setPositionXY(self._label1:getPositionX() + 6, self._label1:getPositionY() - 3)
    end
    for i = 1, 5 do
        if isSafeCocosObj(self._bars[i]) then
            self._bars[i]:setPositionX(self._bars[i]:getPositionX() - 3)
        end
    end

    local touchTarget = ui
    self._touchTarget = touchTarget
    UBFViewHelper:setTouchHandler(touchTarget, function()
        printx(15, "[HappyDelivery] bg tapped bgTapEnabled=", self._bgTapEnabled, "isFull=", self._isFull)
        if not self._bgTapEnabled then return end
        if self._isFull then
            playSfx("goin")
            playHaptics("GO_IN")
            if isSafeCocosObj(self._boxSpine) then
                self:_stopBoxIdleLoop()
                local animName = "in" .. math.min(self._curBoxLevel, 3)
                local idleName = "shengji_" .. math.min(self._curBoxLevel, 3) .. "idle"
                self._boxSpine:setScale(0.57)
                UBFViewHelper:makeAdvancedSpine(self._boxSpine)
                self._boxSpine:playOnce(animName, function()
                    if isSafeCocosObj(self._boxSpine) then
                        self:_playBoxIdleLoop(idleName)
                    end
                end)
                UBFViewHelper.Animation:play({
                    target  = self._boxSpine,
                    type    = UBFViewHelper.Animation.Type.kSpawn,
                    actions = {
                        {type = UBFViewHelper.Animation.Type.kScale, to = 1, duration = 8/30},
                        {type = UBFViewHelper.Animation.Type.kPosition, byY = -105, duration = 8/30},
                    },
                })
            end
            self:_enterRewardPhase()
        else
            self:_closeAndSuccess()
        end
    end)
end

function UBFHappyDeliveryPassLevelView:_setupBars(totalProgress, oldProgress, newProgress)
    printx(15, "[HappyDelivery] _setupBars totalProgress=", totalProgress, "old=", oldProgress, "new=", newProgress)
    local bars = self._bars
    for i = 1, 5 do
        printx(15, "[HappyDelivery] bar", i, "=", bars[i], "safeCocosObj=", isSafeCocosObj(bars[i]))
        if isSafeCocosObj(bars[i]) then
            bars[i]:setVisible(i == totalProgress)
        end
    end

    local activeBar = bars[totalProgress]
    printx(15, "[HappyDelivery] activeBar=", activeBar, "safe=", isSafeCocosObj(activeBar))
    if not isSafeCocosObj(activeBar) then return end
    local p1NodeName = "bar" .. totalProgress .. "_p1"
    local p1 = activeBar:findChildByName(p1NodeName)
    printx(15, "[HappyDelivery] p1NodeName=", p1NodeName, "p1=", p1, "safe=", isSafeCocosObj(p1))
    if not isSafeCocosObj(p1) then return end

    local dotH   = p1:getContentSize().height + 2
    local p1PosX = p1:getPositionX()
    local p1PosY = p1:getPositionY() + 2

    local initW = progressToWidth(oldProgress)
    printx(15, "[HappyDelivery] bar clip initW=", initW, "targetW=", progressToWidth(newProgress), "dotH=", dotH)
    local clip  = SimpleClippingNode:create(CCSizeMake(initW, dotH))
    clip:setPositionXY(p1PosX, p1PosY)
    clip:setAnchorPoint(p1:getAnchorPoint())

    p1:removeFromParentAndCleanup(false)
    p1:setPositionXY(0, 0)
    p1:setAnchorPoint(ccp(0, 0))
    clip:addChild(p1)
    activeBar:addChild(clip)

    self._barClip       = clip
    self._barDotH       = dotH
    self._activeBar     = activeBar
    local fullW         = progressToWidth(newProgress)
    self._barFullW      = (newProgress >= totalProgress) and (fullW + 5) or fullW
    self._oldProgress   = oldProgress
    self._newProgress   = newProgress
    self._totalProgress = totalProgress

    self:_runBarAnim()
end

function UBFHappyDeliveryPassLevelView:_setupDeliverLabel(isFull, newProgress, totalProgress)
    if not isSafeCocosObj(self._label1) then return end
    if isFull then
        self._label1:setString("<font><outline color=#914706 width=2><color=#dfdfdf>拆快递啦！</color></font>")
    else
        local left = totalProgress - newProgress
        local richStr = "<font><outline color=#914706 width=2><color=#dfdfdf>再过</c><color=#ffcf2d>" .. left .. "关</c><color=#dfdfdf>拆快递！</color></font>"
        self._label1:setString(richStr)
    end
    UBFViewHelper:setOpacitySafe(self._label1, 0, true)
end

function UBFHappyDeliveryPassLevelView:_setupBoxSpine(level)
    if not isSafeCocosObj(self._box) then return end
    self._box:setVisible(false)

    local spine = UICreateUtil:createSpine("ubfRes/ui/mod/HappyDelivery/spine/hezi.skel")
    if not isSafeCocosObj(spine) then return end

    UBFViewHelper:makeAdvancedSpine(spine)
    local lvl      = math.min(level, 3)
    local nameIdle = "shengji_" .. lvl .. "idle"
    spine:playByName(nameIdle, false)
    spine:pause()
    spine:setScale(0.57 * 0.8)
    UBFViewHelper:setOpacitySafe(spine, 0, true)
    local frame = 0
    self:_scheduleEntry(function()
        frame = frame + 1
        if frame % 2 ~= 0 then return end
        local f = frame / 2
        if not isSafeCocosObj(spine) then return true end
        if f <= 3 then
            UBFViewHelper:setOpacitySafe(spine, math.floor(255 * f / 3), true)
        end
        if f <= 6 then
            local s
            if f <= 3 then
                s = 0.8 + (1.05 - 0.8) * f / 3
            else
                s = 1.05 + (1 - 1.05) * (f - 3) / 3
            end
            spine:setScale(0.57 * s)
        end
        if f >= 6 then
            spine:setScale(0.57)
            UBFViewHelper:setOpacitySafe(spine, 255, true)
            if self._isFull then
                self:_playBoxIdleLoop(nameIdle)
            end
            return true
        end
    end)

    local boxSize = self._box:getContentSize()
    local tapW    = boxSize.width
    local tapH    = boxSize.height

    local container = UBFLayerColor:create()
    container:changeWidthAndHeight(tapW, tapH)
    container:setColor(ccc3(0, 0, 0))
    container:setOpacity(0)
    container:setAnchorPoint(ccp(0, 1))

    local boxPos = self._box:getPosition()
    container:setPositionXY(boxPos.x, boxPos.y)

    spine:setPositionXY(tapW / 2, 0)
    spine:setAnchorPoint(ccp(0.5, 0.5))
    container:addChild(spine)

    local boxParent = self._box:getParent()
    if isSafeCocosObj(boxParent) then
        boxParent:addChild(container, 0)
    end

    self._boxSpine     = spine
    self._boxContainer = container
end



function UBFHappyDeliveryPassLevelView:_playTxLvUp()
    local parent = isSafeCocosObj(self._boxSpine) and self._boxSpine:getParent()
    if not isSafeCocosObj(parent) then return end

    local txSpine = UICreateUtil:createSpine("ubfRes/ui/mod/HappyDelivery/spine/tx.skel")
    if not isSafeCocosObj(txSpine) then return end

    UBFViewHelper:makeAdvancedSpine(txSpine)
    txSpine:setPositionXY(160, -70)
    parent:addChild(txSpine)
    txSpine:playOnce("lv-up", function()
        if isSafeCocosObj(txSpine) then
            txSpine:removeFromParentAndCleanup(true)
        end
    end)
end

function UBFHappyDeliveryPassLevelView:_playTxLvUpRuo()
    local parent = isSafeCocosObj(self._boxSpine) and self._boxSpine:getParent()
    if not isSafeCocosObj(parent) then return end

    local txSpine = UICreateUtil:createSpine("ubfRes/ui/mod/HappyDelivery/spine/tx.skel")
    if not isSafeCocosObj(txSpine) then return end

    UBFViewHelper:makeAdvancedSpine(txSpine)
    txSpine:setPositionXY(160, -70)
    parent:addChild(txSpine)
    txSpine:playOnce("lv-up_ruo", function()
        if isSafeCocosObj(txSpine) then
            txSpine:removeFromParentAndCleanup(true)
        end
    end)
end

local BOX_DOWN_POS = {
    [2] = {260, -315},
    [3] = {70, -155},
    [4] = {260, -140},
    [5] = {70, 45},
    [6] = {260, 45},
}

function UBFHappyDeliveryPassLevelView:_playTxBoxDown(splitCount)
    self:_stopTxBoxDown()
    playSfx("boxdown")
    playHaptics("BOX_DOWN")
    local parent = isSafeCocosObj(self._boxSpine) and self._boxSpine:getParent()
    if not isSafeCocosObj(parent) then return end

    local txSpine = UICreateUtil:createSpine("ubfRes/ui/mod/HappyDelivery/spine/tx.skel")
    if not isSafeCocosObj(txSpine) then return end

    UBFViewHelper:makeAdvancedSpine(txSpine)
    local pos = BOX_DOWN_POS[splitCount] or {180, -315}
    txSpine:setPositionXY(pos[1], pos[2])
    parent:addChild(txSpine)
    txSpine:playOnce("box_down", function()
        if isSafeCocosObj(txSpine) then
            txSpine:removeFromParentAndCleanup(true)
        end
        if self._txBoxDownSpine == txSpine then
            self._txBoxDownSpine = nil
        end
    end)
    self._txBoxDownSpine = txSpine
end

function UBFHappyDeliveryPassLevelView:_stopTxBoxDown()
    if isSafeCocosObj(self._txBoxDownSpine) then
        self._txBoxDownSpine:removeFromParentAndCleanup(true)
    end
    self._txBoxDownSpine = nil
end


-- 统一管理 scheduler entry：注册时自动跟踪，回调结束时自动移除，dispose 时统一清理
function UBFHappyDeliveryPassLevelView:_scheduleEntry(callback, interval, paused)
    local entry
    entry = self._scheduler:scheduleScriptFunc(function(...)
        local done = callback(entry, ...)
        if done then
            self._scheduler:unscheduleScriptEntry(entry)
            self._entries[entry] = nil
        end
    end, interval or 0, paused or false)
    self._entries[entry] = true
    return entry
end

function UBFHappyDeliveryPassLevelView:_unscheduleAll()
    if not self._scheduler or not self._entries then return end
    for e in pairs(self._entries) do
        self._scheduler:unscheduleScriptEntry(e)
    end
    self._entries = {}
end

function UBFHappyDeliveryPassLevelView:_runBarAnim()
    local dotH    = self._barDotH  or 0
    local startW  = progressToWidth(self._oldProgress or 0)
    local targetW = self._barFullW or 0
    local deltaW  = targetW - startW

    -- 延迟 0.5 秒再启动进度条增长及相关动画
    local BAR_START_DELAY = 8/30
    local delayElapsed = 0
    self:_scheduleEntry(function(_, dt)
        delayElapsed = delayElapsed + dt
        if delayElapsed < BAR_START_DELAY then return end

        playHaptics("STEP_FINISH")

        local spineStarted = false
        local sfxPlayed = false
        local elapsed = 0
        self:_scheduleEntry(function(_, dt2)
            elapsed = elapsed + dt2
            if not spineStarted and elapsed >= 10/30 then
                spineStarted = true
                self:_playBarProgressSpine(function()
                    self:_playLabelEntrance(self._label1, 0, true)
                end)
            end
            if not sfxPlayed and elapsed >= math.min(10/30 + 0.4, BAR_ANIM_TIME) then
                sfxPlayed = true
                playSfx("progress")
            end
            local t = math.min(elapsed / BAR_ANIM_TIME, 1)
            local eased = t * t * (3 - 2 * t)
            local curW = math.max(math.floor(startW + deltaW * eased), 0)
            if isSafeCocosObj(self._barClip) then
                self._barClip:setContentSize(CCSizeMake(curW, dotH))
            end
            if isSafeCocosObj(self._barProgressSpine) and isSafeCocosObj(self._barClip) then
                local clipPos = self._barClip:getPosition()
                local spOffX = self._totalProgress == 1 and -36 or (self._isFull and -35 or -30)
                self._barProgressSpine:setPositionXY(clipPos.x + curW + spOffX, clipPos.y + dotH / 2 - 67)
            end
            if t >= 1 then
                if self._isFull then
                    self:_scheduleEntry(function(_, dt3)
                        elapsed = elapsed + dt3
                        if elapsed >= BAR_ANIM_TIME + 1 then
                            self._bgTapEnabled = true
                            return true
                        end
                    end)
                else
                    self._bgTapEnabled = true
                end
                return true
            end
        end)
        return true
    end)
end



function UBFHappyDeliveryPassLevelView:_playBarProgressSpine(onDone)
    local bar = self._activeBar
    local clip = self._barClip
    if not isSafeCocosObj(bar) or not isSafeCocosObj(clip) then return end

    local spine = UICreateUtil:createSpine("ubfRes/ui/mod/HappyDelivery/spine/jindu_guannei.skel")
    if not isSafeCocosObj(spine) then return end
    UBFViewHelper:makeAdvancedSpine(spine)

    local clipSize = clip:getContentSize()
    local clipPos  = clip:getPosition()
    local spineOffsetX = self._totalProgress == 1 and -36 or (self._isFull and -35 or -30)
    spine:setPositionXY(clipPos.x + clipSize.width + spineOffsetX, clipPos.y + clipSize.height / 2 - 67)
    bar:addChild(spine, 10)
    spine:playOnce("in", function()
        if isSafeCocosObj(spine) then spine:removeFromParentAndCleanup(true) end
        self._barProgressSpine = nil
        if onDone then onDone() end
    end)
    self._barProgressSpine = spine
end

function UBFHappyDeliveryPassLevelView:_stopLabelAnim(label)
    if not label then return end
    local entry = label._labelAnimEntry
    if entry and self._entries and self._entries[entry] then
        self._scheduler:unscheduleScriptEntry(entry)
        self._entries[entry] = nil
    end
    label._labelAnimEntry = nil
end

function UBFHappyDeliveryPassLevelView:_playLabelEntrance(label, delay, loopAfter)
    if not isSafeCocosObj(label) then return end
    self:_stopLabelAnim(label)
    UBFViewHelper:setOpacitySafe(label, 0, true)
    label:setScale(1)

    local frame = 0
    local delayFrames = math.floor(delay * 60 + 0.5)
    local tick = 0
    local fadeFrames = 3

    label._labelAnimEntry = self:_scheduleEntry(function()
        tick = tick + 1
        if tick <= delayFrames then return end
        if tick % 2 ~= 0 then return end
        frame = frame + 1
        if not isSafeCocosObj(label) then return true end

        if frame <= fadeFrames then
            local opacity = math.floor(255 * frame / fadeFrames)
            UBFViewHelper:setOpacitySafe(label, opacity, true)
        end

        if frame >= fadeFrames then
            UBFViewHelper:setOpacitySafe(label, 255, true)
            label._labelAnimEntry = nil
            if loopAfter then
                self:_playLabelIdle(label)
            end
            return true
        end
    end)
end

function UBFHappyDeliveryPassLevelView:_playLabelIdle(label)
    if not isSafeCocosObj(label) then return end
    self:_stopLabelAnim(label)

    local idleKF = {
        {0, 1}, {6, 1.1}, {11, 0.95}, {18, 1}, {180, 1},
    }
    local totalFrame = 180
    local frame = 0

    local function lerpKF(kfList, f)
        local pf, pv, nf, nv = 0, kfList[1][2], kfList[#kfList][1], kfList[#kfList][2]
        for i = 1, #kfList do
            if kfList[i][1] <= f then pf, pv = kfList[i][1], kfList[i][2] end
            if kfList[i][1] >= f then nf, nv = kfList[i][1], kfList[i][2]; break end
        end
        if nf == pf then return nv end
        return pv + (nv - pv) * (f - pf) / (nf - pf)
    end

    label._labelAnimEntry = self:_scheduleEntry(function()
        if not isSafeCocosObj(label) then return true end
        frame = frame + 1
        if frame > totalFrame then
            label:setScale(1)
            frame = 0
            return
        end
        if frame % 2 ~= 0 then return end
        label:setScale(lerpKF(idleKF, frame / 2))
    end)
end

function UBFHappyDeliveryPassLevelView:_addOpenBoxBgTint()
    if not isSafeCocosObj(self._rBg) then return end

    local visibleArea = _G.fullScreenSizeManager:getVisibleArea()
    local visibleW = visibleArea.size.width
    local visibleH = visibleArea.size.height

    local tint = UBFLayerColor:create()
    tint:changeWidthAndHeight(visibleW * 1.5, visibleH * 1.5)
    tint:setColor(ccc3(0xff, 0xae, 0x00))
    tint:setOpacity(255)
    tint:setPositionXY(0, 0)
    tint:setAnchorPoint(ccp(0.5, 0.5))
    self._rBg:addChild(tint)
    tint:setZOrder(-1)

    local targets = {}
    local children = self._rBg:getChildrenSafeList()
    for _, child in ipairs(children or {}) do
        if isSafeCocosObj(child) and child ~= tint and child ~= self._bjSpine and child:isVisible() then
            table.insert(targets, {node = child, startOpacity = child:getOpacity() or 255})
        end
    end

    local fadeFrames = 5
    local targetRatio = 0.4
    local frame = 0
    self:_scheduleEntry(function()
        frame = frame + 1
        local t = math.min(frame / fadeFrames, 1)
        for _, info in ipairs(targets) do
            if isSafeCocosObj(info.node) then
                local opacity = math.floor(info.startOpacity * (1 - t * (1 - targetRatio)))
                UBFViewHelper:setOpacitySafe(info.node, opacity, true)
            end
        end
        return frame >= fadeFrames
    end)
end

-- 关键时间点"开宝箱"：开箱动画 → 加奖励 + 展示奖励面板
function UBFHappyDeliveryPassLevelView:_openBox()
    if self._boxOpened then return end
    self._boxOpened = true
    self._bgTapEnabled = false
    self:_stopSplitIdleLoop()
    self:_stopBoxIdleLoop()
    self:_stopTxBoxDown()

    local openAnimName = self:_getOpenBoxAnimName()
    printx(15, "[HappyDelivery] _openBox animName=", openAnimName)

    self:_playOpenBoxEffects()

    local level = self._curBoxLevel or 1
    local isChang = self._inSplitPhase or level >= 5
    playSfx(isChang and "open2" or "open1")
    playHaptics("OPEN")
    if isChang then
        self:_applyOpenBoxVibrate()
        self:_addOpenBoxBgTint()
    else
        self:_applyOpenBoxVibrateShort()
    end

    self._inSplitPhase = false

    local openBoxDone = false
    local function finishOpenBox()
        if openBoxDone then return end
        openBoxDone = true
        self:_onOpenBoxAnimDone()
    end

    if isSafeCocosObj(self._boxSpine) and openAnimName then
        UBFViewHelper:makeAdvancedSpine(self._boxSpine)
        self._boxSpine:playOnce(openAnimName, function()
            finishOpenBox()
        end)
    else
        finishOpenBox()
    end

    local elapsed = 0
    self:_scheduleEntry(function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= 62/30 then
            finishOpenBox()
            return true
        end
        if openBoxDone then return true end
    end)
end

function UBFHappyDeliveryPassLevelView:_addEffectToScene(node)
    local scene = Director:sharedDirector():getRunningSceneLua()
    if scene then
        Scene.addChildAt(scene, node, 9999)
        printx(15, "[HappyDelivery] effect added to scene zOrder=9999")
    end
    table.insert(self._openBoxEffectSpines, node)
end

function UBFHappyDeliveryPassLevelView:_playOpenBoxEffects()
    self._openBoxEffectSpines = {}

    local spineParent = isSafeCocosObj(self._boxSpine) and self._boxSpine:getParent()
    local spinePos = isSafeCocosObj(self._boxSpine) and self._boxSpine:getPosition()
    if not isSafeCocosObj(spineParent) or not spinePos then return end

    local level = self._curBoxLevel or 1
    local isChang = self._inSplitPhase or level >= 5
    local txAnimName = isChang and "box_open_chang" or "box_open_duan"
    local offsetX = self._inSplitPhase and 70 or (isChang and 20 or 20)
    local offsetY = self._inSplitPhase and 95 or (isChang and 5 or 5)
    local localPos = ccp(spinePos.x + offsetX, spinePos.y + offsetY)
    local worldPos = spineParent:convertToWorldSpace(localPos)
    local uiParent = isSafeCocosObj(self._ui) and self._ui:getParent()
    local effectPos = worldPos
    printx(15, "[HappyDelivery] openBoxEffects spinePos=", spinePos.x, spinePos.y,
        "localPos=", localPos.x, localPos.y, "worldPos=", worldPos.x, worldPos.y,
        "effectPos=", effectPos.x, effectPos.y)
    local lihuaDelay = isChang and 60/30 or 25/30

    local txSpine = UICreateUtil:createSpine("ubfRes/ui/mod/HappyDelivery/spine/tx.skel")
    if isSafeCocosObj(txSpine) then
        UBFViewHelper:makeAdvancedSpine(txSpine)
        txSpine:setPositionXY(effectPos.x, effectPos.y)
        self:_addEffectToScene(txSpine)
        txSpine:playOnce(txAnimName, function()
            if isSafeCocosObj(txSpine) then txSpine:removeFromParentAndCleanup(true) end
        end)
    end

    local lihua2Spine = UICreateUtil:createSpine("ubfRes/ui/mod/HappyDelivery/spine/lihua2.skel")
    if isSafeCocosObj(lihua2Spine) then
        UBFViewHelper:makeAdvancedSpine(lihua2Spine)
        local visibleArea = _G.fullScreenSizeManager:getVisibleArea()
        local panelLocalPos = ccp(350, -visibleArea.size.height / 2)
        local lihua2WorldPos = isSafeCocosObj(self._panel) and self._panel:convertToWorldSpace(panelLocalPos) or panelLocalPos
        lihua2Spine:setPositionXY(lihua2WorldPos.x, lihua2WorldPos.y)
        lihua2Spine:setVisible(false)
        self:_addEffectToScene(lihua2Spine)
        local lihua2Delay = isChang and 60/30 or 25/30
        self:_scheduleEntry(function(_, dt)
            lihua2Delay = lihua2Delay - dt
            if lihua2Delay <= 0 then
                if isSafeCocosObj(lihua2Spine) then
                    lihua2Spine:setVisible(true)
                    lihua2Spine:playOnce("zhumianban")
                end
                return true
            end
        end)
    end

    local lihuaSpine = UICreateUtil:createSpine("ubfRes/ui/mod/HappyDelivery/spine/lihua.skel")
    if isSafeCocosObj(lihuaSpine) then
        UBFViewHelper:makeAdvancedSpine(lihuaSpine)
        lihuaSpine:setPositionXY(effectPos.x, effectPos.y)
        lihuaSpine:setVisible(false)
        self:_addEffectToScene(lihuaSpine)
        self:_scheduleEntry(function(_, dt)
            lihuaDelay = lihuaDelay - dt
            if lihuaDelay <= 0 then
                if isSafeCocosObj(lihuaSpine) then
                    lihuaSpine:setVisible(true)
                    lihuaSpine:playOnce("in", function()
                        if isSafeCocosObj(lihuaSpine) then lihuaSpine:removeFromParentAndCleanup(true) end
                        self:_fadeOutAndRemove(lihua2Spine, 5)
                    end)
                end
                return true
            end
        end)
    end
end

function UBFHappyDeliveryPassLevelView:_removeOpenBoxEffects()
    for _, spine in ipairs(self._openBoxEffectSpines or {}) do
        if isSafeCocosObj(spine) then
            spine:removeFromParentAndCleanup(true)
        end
    end
    self._openBoxEffectSpines = {}
end

function UBFHappyDeliveryPassLevelView:_fadeOutAndRemove(node, frames)
    if not isSafeCocosObj(node) then return end
    local frame = 0
    local startOpacity = node:getOpacity() or 255
    self:_scheduleEntry(function()
        frame = frame + 1
        if not isSafeCocosObj(node) then return true end
        if frame >= frames then
            node:removeFromParentAndCleanup(true)
            return true
        end
        local opacity = math.floor(startOpacity * (1 - frame / frames))
        UBFViewHelper:setOpacitySafe(node, opacity, true)
    end)
end

function UBFHappyDeliveryPassLevelView:_getOpenBoxAnimName()
    local level = self._curBoxLevel or 1
    if self._inSplitPhase then
        local splitCount = self._curSplitCount or 1
        return "open_chang5+" .. splitCount
    elseif level >= 5 then
        return "open_chang5"
    else
        return "open_duan" .. level
    end
end

function UBFHappyDeliveryPassLevelView:_onOpenBoxAnimDone()
    self:_dcOpenBox()
    if _G.GainPropData then
        local rewardList = {}
        for _, reward in ipairs(self._finalRewards) do
            table.insert(rewardList, {itemId = reward.itemId, num = reward.num})
        end
        _G.GainPropData:create()
            :setFeature("backflow_task")
            :setSource("open_box")
            :setProps(rewardList)
            :execute()
        local outsideMgr = _G.amfBean("HappyDeliveryManager")
        if outsideMgr then outsideMgr:dcJoin() end
        self:_showRewardPanel()
    else
        self:_closeAndSuccess()
    end
end

function UBFHappyDeliveryPassLevelView:_showRewardPanel()
    local rewardList = {}
    for _, reward in ipairs(self._finalRewards) do
        table.insert(rewardList, {itemId = reward.itemId, num = reward.num})
    end

    if isSafeCocosObj(self._panel) then self._panel:setVisible(false) end

    local ShowRewardsPanel = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelVM"
    local panel = ShowRewardsPanel.Builder.new()
        :setTitle("开心快递")
        :setRewards(rewardList, function(reward)
            return _G.GameItemCreator:getPropIcon({itemId = reward.itemId, num = reward.num})
        end)
        :setCloseCallback(function()
            self:_removeOpenBoxEffects()
            self:dispose()
            safeRunCall(self._onSuccess)
        end)
        :build()
    panel:popout()
end

function UBFHappyDeliveryPassLevelView:_initRewardUI()
    if isSafeCocosObj(self._rBg) then
        local bgKey       = "bg_" .. self._curBoxLevel
        local visibleArea = _G.fullScreenSizeManager:getVisibleArea()
        local visibleW    = visibleArea.size.width
        local visibleH    = visibleArea.size.height

        self._rBg:setPositionXY(720, 0)
        self._rBg:setAnchorPoint(ccp(0.5, 0.5))
        self._rBg:setScale(1)

        if not self._bgScaleInited then
            self._bgScaleInited = true
            local allChildren = self._rBg:getChildrenSafeList()
            for _, child in ipairs(allChildren or {}) do
                if isSafeCocosObj(child) then
                    local origW  = child:getContentSize().width
                    local origH  = child:getContentSize().height
                    local scaleX = origW > 0 and (visibleW * 1.5 / origW) or 1
                    local scaleY = origH > 0 and (visibleH * 1.5 / origH) or 1
                    child:setPositionXY(0, 0)
                    child:setAnchorPoint(ccp(0.5, 0.5))
                    child:setScaleX(scaleX)
                    child:setScaleY(scaleY)
                end
            end
        end

        local children = self._rBg:getChildrenSafeList()
        for _, child in ipairs(children or {}) do
            if isSafeCocosObj(child) then
                child:setVisible(child:getName() == bgKey)
            end
        end
    end

    if not self._bjSpine and isSafeCocosObj(self._rBg) then
        local bjSpine = UICreateUtil:createSpine("ubfRes/ui/mod/HappyDelivery/spine/bj.skel")
        if isSafeCocosObj(bjSpine) then
            UBFViewHelper:makeAdvancedSpine(bjSpine)
            bjSpine:playByName("bg_idle70", true)
            self._rBg:addChild(bjSpine)
            bjSpine:setPositionXY(-10, -155)
            self._bjSpine = bjSpine
        end
    end

    if isSafeCocosObj(self._rBottom) then
        local prefix    = self._finalSplitCount > 0 and "bottom4_" or "bottom3_"
        local bottomKey = prefix .. 0
        local children     = self._rBottom:getChildrenSafeList()
        for _, child in ipairs(children or {}) do
            if isSafeCocosObj(child) then
                child:setVisible(child:getName() == bottomKey)
            end
        end
    end

    if isSafeCocosObj(self._rTitle) then
        local titleKey = "t" .. self._curBoxLevel
        local children = self._rTitle:getChildrenSafeList()
        for _, child in ipairs(children or {}) do
            if isSafeCocosObj(child) then
                child:setVisible(child:getName() == titleKey)
            end
        end
    end
end

function UBFHappyDeliveryPassLevelView:_fadeInRewardNodes(rNodes, fadeDuration)
    for _, node in ipairs(rNodes) do
        if isSafeCocosObj(node) then
            node:setVisible(true)
            UBFViewHelper.Animation:play({
                target  = node,
                type    = UBFViewHelper.Animation.Type.kSequence,
                actions = {
                    {
                        type     = UBFViewHelper.Animation.Type.kOpacity,
                        from     = 0,
                        to       = 255,
                        duration = fadeDuration,
                        cascade  = true,
                    }
                },
            })
        end
    end
end

function UBFHappyDeliveryPassLevelView:_startBottomFloat()
    self:_playVisibleBottomFloat()
end

function UBFHappyDeliveryPassLevelView:_animateRewardTitle()
    if not isSafeCocosObj(self._rTitle) then return end
    local titleChild = nil
    local children = self._rTitle:getChildrenSafeList()
    for _, child in ipairs(children or {}) do
        if isSafeCocosObj(child) and child:isVisible() then
            titleChild = child
            break
        end
    end
    if not isSafeCocosObj(titleChild) then return end
    titleChild:setScale(0.8)
    UBFViewHelper.Animation:play({
        target = titleChild,
        type   = UBFViewHelper.Animation.Type.kSequence,
        actions = {
            {type = UBFViewHelper.Animation.Type.kScale, to = 1.1, duration = 4/30},
            {type = UBFViewHelper.Animation.Type.kScale, to = 1.2, duration = 4/30},
            {type = UBFViewHelper.Animation.Type.kScale, to = 1.0, duration = 6/30},
        },
    })
end

function UBFHappyDeliveryPassLevelView:_enterRewardPhase()
    printx(15, "[HappyDelivery] _enterRewardPhase start")
    self._bgTapEnabled = false

    for _, node in ipairs({self._title, self._label1, self._continue}) do
        if isSafeCocosObj(node) then node:setVisible(false) end
    end
    for i = 1, 5 do
        if isSafeCocosObj(self._bars[i]) then self._bars[i]:setVisible(false) end
    end

    self:_initRewardUI()

    local rNodes = {self._rBg, self._rLabel2, self._rTitle, self._rBottom}
    local fadeCount = #rNodes
    local doneCount = 0

    self:_refreshRewardLabel()

    local fadeDuration  = 4 / 30
    local waitDuration  = 8 / 30

    local elapsed = 0
    self:_scheduleEntry(function(_, dt)
        elapsed = elapsed + dt
        if elapsed >= waitDuration then
            self:_fadeInRewardNodes(rNodes, fadeDuration)
            self:_animateRewardTitle()

            local elapsed2 = 0
            self:_scheduleEntry(function(_, dt2)
                elapsed2 = elapsed2 + dt2
                if elapsed2 >= fadeDuration then
                    self:_initRewardTapState()
                    self._bgTapEnabled = true
                    return true
                end
            end)
            return true
        end
    end)

    UBFViewHelper:setTouchHandler(self._touchTarget, function()
        if not self._bgTapEnabled then
            if self._rewardUsed == nil then return end
            if self._boxOpened then return end
    if self._inSplitPhase then
                self._splitTapQueued = true
                printx(15, "[HappyDelivery] tap queued during split anim, splitCount=", self._curSplitCount)
            elseif self._rewardUsed < (self._totalUpgrades or 0) then
                self._upgradeTapQueueCount = (self._upgradeTapQueueCount or 0) + 1
                printx(15, "[HappyDelivery] tap queued during upgrade anim, rewardUsed=", self._rewardUsed, "queueCount=", self._upgradeTapQueueCount)
            end
            return
        end
        if self._inSplitPhase then
            self:_onSplitTap()
            return
        end
        if (self._rewardUsed or 0) >= (self._totalUpgrades or 0) then
            self:_openBox()
            return
        end
        self:_doUpgradeTap()
    end)
end

local REWARD_UPGRADE_HINTS = {
    [1] = "点击有机会升级！",
    [2] = "点我！点我！",
    [3] = "再点击一次！",
}
local REWARD_SPLIT_HINTS   = {"爆好运！点！", "猛点！", "快递要爆仓！点击！"}
local REWARD_HINT_DONE     = "点击拆开！"

function UBFHappyDeliveryPassLevelView:_refreshRewardTitle(forceKey)
    if not isSafeCocosObj(self._rTitle) then return end
    local titleKey = forceKey or ("t" .. self._curBoxLevel)
    local children = self._rTitle:getChildrenSafeList()
    for _, child in ipairs(children or {}) do
        if isSafeCocosObj(child) then
            child:setVisible(child:getName() == titleKey)
        end
    end
end

function UBFHappyDeliveryPassLevelView:_updateTsLabel()
    if not isSafeCocosObj(self._rTitle) then return end
    local ts = self._rTitle:findChildByName("ts")
    if not isSafeCocosObj(ts) then return end
    local ts2 = ts:findChildByName("ts2")
    if not isSafeCocosObj(ts2) then return end
    ts2:setString("×" .. (self._curSplitCount or 1))
end

function UBFHappyDeliveryPassLevelView:_refreshRewardBg()
    if not isSafeCocosObj(self._rBg) then return end
    local bgKey  = "bg_" .. self._curBoxLevel
    local children = self._rBg:getChildrenSafeList()
    for _, child in ipairs(children or {}) do
        if isSafeCocosObj(child) and child ~= self._bjSpine then
            child:setVisible(child:getName() == bgKey)
        end
    end
end

function UBFHappyDeliveryPassLevelView:_getRewardLabelStr()
    local usedUpgrades  = self._rewardUsed or 0
    local totalUpgrades = self._totalUpgrades or 0
    if self._inSplitPhase then
        if not self._splitHint then
            self._splitHint = REWARD_SPLIT_HINTS[math.random(#REWARD_SPLIT_HINTS)]
        end
        return self._splitHint
    elseif usedUpgrades >= totalUpgrades then
        return REWARD_HINT_DONE
    else
        return REWARD_UPGRADE_HINTS[usedUpgrades + 1] or REWARD_HINT_DONE
    end
end

function UBFHappyDeliveryPassLevelView:_refreshRewardLabel()
    local label = self._rLabel2Text
    if not isSafeCocosObj(label) then return end
    local str = self:_getRewardLabelStr()
    local isFirst = not self._rewardLabelInited
    self._rewardLabelInited = true

    if isFirst then
        label:setString(str)
        self._lastRewardLabelStr = str
        UBFViewHelper:setOpacitySafe(label, 0, true)
        self:_playLabelEntrance(label, 0, true)
        return
    end

    if str == self._lastRewardLabelStr then return end
    self._lastRewardLabelStr = str

    self:_stopLabelAnim(label)
    label:stopAllActions()
    local frame = 0
    local fadeFrames = 3
    local origScaleX = label:getScaleX()
    local origScaleY = label:getScaleY()

    self:_scheduleEntry(function()
        frame = frame + 1
        if frame % 2 ~= 0 then return end
        local f = frame / 2
        if not isSafeCocosObj(label) then return true end
        if f <= fadeFrames then
            local t = f / fadeFrames
            local s = 1 + (0.7 - 1) * t
            label:setScaleX(origScaleX * s)
            label:setScaleY(origScaleY * s)
            UBFViewHelper:setOpacitySafe(label, math.floor(255 * (1 - t)), true)
        end
        if f >= fadeFrames then
            label:setString(str)
            label:setScaleX(origScaleX)
            label:setScaleY(origScaleY)
            UBFViewHelper:setOpacitySafe(label, 0, true)
            self:_playLabelEntrance(label, 0, true)
            return true
        end
    end)
end

function UBFHappyDeliveryPassLevelView:_refreshRewardBottom()
    if not isSafeCocosObj(self._rBottom) then return end

    local shouldHide = false
    if self._finalSplitCount <= 0 then
        shouldHide = (self._rewardUsed or 0) >= (self._totalUpgrades or 0)
    else
        shouldHide = self._inSplitPhase and (self._curSplitCount or 0) >= self._finalSplitCount
    end
    if shouldHide then
        self._rBottom:setVisible(false)
        return
    end
    self._rBottom:setVisible(true)

    local usedUpgrades = self._rewardUsed or 0
    local prefix       = self._finalSplitCount > 0 and "bottom4_" or "bottom3_"
    local bottomKey    = self._inSplitPhase and "bottom4_3" or (prefix .. usedUpgrades)
    local children     = self._rBottom:getChildrenSafeList()
    for _, child in ipairs(children or {}) do
        if isSafeCocosObj(child) then
            child:setVisible(child:getName() == bottomKey)
        end
    end
end

function UBFHappyDeliveryPassLevelView:_onSplitTap()
    self:_stopSplitIdleLoop()
    local splitCount = self._curSplitCount or 1
    if splitCount >= self._finalSplitCount then
        self:_openBox()
        return
    end

    playSfx("upgrade3")
    playHaptics("UPGRADE3")
    self._bgTapEnabled = false
    self._curSplitCount = splitCount + 1
    local newCount = self._curSplitCount

    local animName = splitCount .. "-" .. newCount
    local splitScaleMap = {[2] = 0.65, [3] = 0.55}
    if isSafeCocosObj(self._boxSpine) then
        UBFViewHelper:makeAdvancedSpine(self._boxSpine)
        self._boxSpine:playOnce(animName, function()
            self:_onSplitAnimDone()
            if not EnvUtil:isMiniGame() then
                self:_playSplitIdleLoop(newCount)
            end
        end)
        local targetScale = splitScaleMap[newCount]
        if targetScale then
            local actions = {
                {type = UBFViewHelper.Animation.Type.kScale, to = targetScale, duration = 8/30},
            }
            if newCount == 2 then
                table.insert(actions, {type = UBFViewHelper.Animation.Type.kPosition, byX = -100, byY = -130, duration = 8/30})
            end
            UBFViewHelper.Animation:play({
                target  = self._boxSpine,
                type    = UBFViewHelper.Animation.Type.kSpawn,
                actions = actions,
            })
        end
    end

    self:_refreshRewardLabel()
    self:_playSplitAnims(newCount)
    self:_playTxBoxDown(newCount)
    self:_applySplitVibrate()
    if newCount >= self._finalSplitCount and isSafeCocosObj(self._rBottom) then
        self._rBottom:setVisible(false)
    end
end

function UBFHappyDeliveryPassLevelView:_onSplitAnimDone()
    local queued = self._splitTapQueued
    self._splitTapQueued = false
    local isLastSplit = (self._curSplitCount or 0) >= (self._finalSplitCount or 0)

    printx(15, "[HappyDelivery] _onSplitAnimDone queued=", queued,
        "splitCount=", self._curSplitCount, "finalSplit=", self._finalSplitCount)

    if isLastSplit then
        self:_dcGetBox()
        self:_refreshRewardBottom()
        self:_playLabelIdle(self._rLabel2Text)
    end

    if queued and isLastSplit then
        printx(15, "[HappyDelivery] auto-consuming queued split tap -> openBox")
        self:_openBox()
    else
        self._bgTapEnabled = true
    end
end

function UBFHappyDeliveryPassLevelView:_stopSplitIdleLoop()
    if self._splitIdleEntry and self._entries and self._entries[self._splitIdleEntry] then
        self._scheduler:unscheduleScriptEntry(self._splitIdleEntry)
        self._entries[self._splitIdleEntry] = nil
    end
    self._splitIdleEntry = nil
    self._splitIdleActive = false
end

function UBFHappyDeliveryPassLevelView:_stopBoxIdleLoop()
    if self._boxIdleEntry and self._entries and self._entries[self._boxIdleEntry] then
        self._scheduler:unscheduleScriptEntry(self._boxIdleEntry)
        self._entries[self._boxIdleEntry] = nil
    end
    self._boxIdleEntry = nil
    self._boxIdleActive = false
end

function UBFHappyDeliveryPassLevelView:_playBoxIdleLoop(idleName)
    if self._boxOpened then return end
    local spine = self._boxSpine
    if not isSafeCocosObj(spine) then return end

    self:_stopBoxIdleLoop()
    self._boxIdleActive = true

    local function loop()
        if not isSafeCocosObj(spine) or not self._boxIdleActive then return end
        local elapsed = 0
        self._boxIdleEntry = self:_scheduleEntry(function(_, dt)
            if not isSafeCocosObj(spine) or not self._boxIdleActive then return true end
            elapsed = elapsed + dt
            if elapsed >= 2 then
                spine:resume()
                playSfx("idle")
                spine:playOnce(idleName, function()
                    if not isSafeCocosObj(spine) or not self._boxIdleActive then return end
                    spine:playByName(idleName, false)
                    spine:pause()
                    loop()
                end)
                return true
            end
        end)
    end
    loop()
end

function UBFHappyDeliveryPassLevelView:_playSplitIdleLoop(splitCount)
    if self._boxOpened then return end
    local spine = self._boxSpine
    if not isSafeCocosObj(spine) then return end
    local idleName = splitCount .. "idle"
    local elapsed = 0
    local phase = "delay"

    self:_stopSplitIdleLoop()
    self._splitIdleActive = true

    local function loop()
        if not isSafeCocosObj(spine) or not self._splitIdleActive then return end
        elapsed = 0
        phase = "delay"
        self._splitIdleEntry = self:_scheduleEntry(function(_, dt)
            if not isSafeCocosObj(spine) or not self._splitIdleActive then return true end
            elapsed = elapsed + dt
            if phase == "delay" and elapsed >= 1 then
                phase = "playing"
                playSfx("idle")
                spine:playOnce(idleName, function()
                    if not isSafeCocosObj(spine) or not self._splitIdleActive then return end
                    loop()
                end)
                return true
            end
        end)
    end
    loop()
end

function UBFHappyDeliveryPassLevelView:_initRewardTapState()
    self._rewardUsed = 0
    self._upgradeTapQueueCount = 0
    self._splitTapQueued = false
end

function UBFHappyDeliveryPassLevelView:_doUpgradeTap()
    self._bgTapEnabled = false
    self:_stopBoxIdleLoop()
    self._rewardUsed = (self._rewardUsed or 0) + 1

    local upgradeIdx = math.min(self._rewardUsed, 3)
    playSfx("upgrade" .. upgradeIdx)
    playHaptics(({"UPGRADE1", "UPGRADE2", "UPGRADE3"})[upgradeIdx])

    local script      = self._upgradeScript or {}
    local delta       = script[self._rewardUsed] or 0
    local levelBefore = self._curBoxLevel
    local newLevel    = math.min(self._curBoxLevel + delta, 5)
    local success     = newLevel > levelBefore
    if success then
        self._curBoxLevel = newLevel
    end
    local levelAfter = self._curBoxLevel

    local totalUpgrades = self._totalUpgrades or 0
    if self._rewardUsed >= totalUpgrades and self._finalSplitCount > 0 then
        self._inSplitPhase = true
        self._curSplitCount = 1
        if isSafeCocosObj(self._bjSpine) then
            self._bjSpine:playByName("bg_idle40", true)
        end
    end

    if isSafeCocosObj(self._boxSpine) then
        local displayLevel = success and levelAfter or levelBefore
        local nameIdle = "shengji_" .. displayLevel .. "idle"
        local nameA    = "shengji_" .. math.min(levelBefore, 4) .. "a"
        local nameB    = "shengji_" .. displayLevel .. "b"
        printx(15, "[HappyDelivery] upgrade anim nameA=", nameA, "nameB=", nameB, "nameIdle=", nameIdle)
        self._boxSpine:playOnce(nameA, function()
            if not isSafeCocosObj(self._boxSpine) then return end
            self._boxSpine:playOnce(nameB, function()
                if not isSafeCocosObj(self._boxSpine) then return end
                self._boxSpine:playByName(nameIdle, false)
                self._boxSpine:pause()
                self:_onUpgradeAnimDone()
                if not self._inSplitPhase and not self._boxOpened then
                    self:_playBoxIdleLoop(nameIdle)
                end            end)
        end)
        if success then
            self:_playTxLvUp()
        else
            self:_playTxLvUpRuo()
        end
    end

    self:_refreshRewardLabel()

    local elapsed4 = 0
    self:_scheduleEntry(function(_, dt)
        elapsed4 = elapsed4 + dt
        if elapsed4 >= 4/30 then
            self:_refreshRewardBottom()
            return true
        end
    end)

    self:_playUpgradeAnims(success, levelAfter)
end

function UBFHappyDeliveryPassLevelView:_onUpgradeAnimDone()
    local totalUpgrades = self._totalUpgrades or 0
    local queueCount = self._upgradeTapQueueCount or 0

    printx(15, "[HappyDelivery] _onUpgradeAnimDone queueCount=", queueCount,
        "rewardUsed=", self._rewardUsed, "total=", totalUpgrades,
        "inSplit=", self._inSplitPhase)

    if queueCount > 0 and not self._inSplitPhase and (self._rewardUsed or 0) < totalUpgrades then
        self._upgradeTapQueueCount = queueCount - 1
        printx(15, "[HappyDelivery] auto-consuming queued tap, remaining=", self._upgradeTapQueueCount)
        self:_doUpgradeTap()
    else
        self._upgradeTapQueueCount = 0
        self._bgTapEnabled = true
        if not self._inSplitPhase then
            if (self._rewardUsed or 0) >= totalUpgrades then
                self:_dcGetBox()
            end
            self:_refreshRewardBottom()
        end
    end
end

function UBFHappyDeliveryPassLevelView:_applyOpenBoxVibrate()
    local target = self._panel
    if not isSafeCocosObj(target) then return end

    local originX = target:getPositionX()
    local originY = target:getPositionY()

    local kfList = {
        {0, 0,0}, {3, 2,0}, {6, 0,-2}, {8, -2,0}, {10, 0,2},
        {12, 3,0}, {14, 0,-3}, {16, -3,0}, {18, 0,3}, {20, 3,0},
        {22, 0,-3}, {24, -3,0}, {26, 0,3}, {28, 3,0}, {30, 0,-3},
        {32, -3,0}, {34, 0,4}, {36, 4,0}, {38, 0,-4}, {40, -4,0},
        {42, 0,4}, {44, 4,0}, {46, 0,-4}, {48, -4,0}, {50, 0,4},
        {52, 4,0}, {54, 0,-4}, {56, -4,0}, {58, 0,4}, {60, 4,0},
        {62, 0,0},
    }
    local totalFrame = 62
    local frame = 0
    local tick = 0

    local function lerpXY(f)
        local pf, px, py = 0, 0, 0
        local nf, nx, ny = totalFrame, 0, 0
        for i = 1, #kfList do
            if kfList[i][1] <= f then pf, px, py = kfList[i][1], kfList[i][2], kfList[i][3] end
            if kfList[i][1] >= f then nf, nx, ny = kfList[i][1], kfList[i][2], kfList[i][3]; break end
        end
        if nf == pf then return nx, ny end
        local t = (f - pf) / (nf - pf)
        return px + (nx - px) * t, py + (ny - py) * t
    end

    self:_scheduleEntry(function()
        tick = tick + 1
        if tick % 2 ~= 0 then return end
        frame = frame + 1
        if frame > totalFrame then
            if isSafeCocosObj(target) then target:setPositionXY(originX, originY) end
            return true
        end
        if isSafeCocosObj(target) then
            local dx, dy = lerpXY(frame)
            target:setPositionXY(originX + dx, originY + dy)
        end
    end)
end

function UBFHappyDeliveryPassLevelView:_applyOpenBoxVibrateShort()
    local target = self._panel
    if not isSafeCocosObj(target) then return end

    local originX = target:getPositionX()
    local originY = target:getPositionY()

    local kfList = {
        {0, 0,0}, {3, 2,0}, {6, 0,-2}, {8, -2,0}, {10, 0,2},
        {12, 3,0}, {14, 0,-3}, {16, -3,0}, {18, 0,3}, {20, 3,0},
        {22, 0,-3}, {24, -3,0}, {25, 0,3}, {27, 0,0},
    }
    local totalFrame = 27
    local frame = 0
    local tick = 0

    local function lerpXY(f)
        local pf, px, py = 0, 0, 0
        local nf, nx, ny = totalFrame, 0, 0
        for i = 1, #kfList do
            if kfList[i][1] <= f then pf, px, py = kfList[i][1], kfList[i][2], kfList[i][3] end
            if kfList[i][1] >= f then nf, nx, ny = kfList[i][1], kfList[i][2], kfList[i][3]; break end
        end
        if nf == pf then return nx, ny end
        local t = (f - pf) / (nf - pf)
        return px + (nx - px) * t, py + (ny - py) * t
    end

    self:_scheduleEntry(function()
        tick = tick + 1
        if tick % 2 ~= 0 then return end
        frame = frame + 1
        if frame > totalFrame then
            if isSafeCocosObj(target) then target:setPositionXY(originX, originY) end
            return true
        end
        if isSafeCocosObj(target) then
            local dx, dy = lerpXY(frame)
            target:setPositionXY(originX + dx, originY + dy)
        end
    end)
end

function UBFHappyDeliveryPassLevelView:_applySplitVibrate()
    local target = self._ui
    if not isSafeCocosObj(target) then return end

    local originY = target:getPositionY()
    local frame = 0

    self:_scheduleEntry(function()
        frame = frame + 1
        if frame >= 13 then
            if isSafeCocosObj(target) then target:setPositionXY(target:getPositionX(), originY) end
            return true
        end
        if frame >= 8 then
            local t = (frame - 8) / (13 - 8)
            local oy = -25 * (1 - t)
            if isSafeCocosObj(target) then target:setPositionXY(target:getPositionX(), originY + oy) end
        end
    end)
end

function UBFHappyDeliveryPassLevelView:_applyUIVibrate()
    local target = self._ui
    if not isSafeCocosObj(target) then return end

    local offsetX = {0, 9.9, -11.3, 2.6, 10, -4.5, -9.6, 1.6, 0, 2.2, 0, -1, 0, 0}
    local offsetY = {0, -14.1, -1.5, 18, 5.2, -8.3, 2.3, 4.3, 0, 2.1, 0, -2.1, 0, 0}
    local interval = 2
    local totalFrame = interval * #offsetX
    local originX = target:getPositionX()
    local originY = target:getPositionY()
    local frame = 0

    self:_scheduleEntry(function()
        frame = frame + 1
        if frame >= totalFrame then
            if isSafeCocosObj(target) then
                target:setPositionXY(originX, originY)
            end
            return true
        end
        local idx = math.floor(frame / interval) + 1
        local ox = offsetX[idx] or 0
        local oy = offsetY[idx] or 0
        if isSafeCocosObj(target) then
            target:setPositionXY(originX + ox, originY + oy)
        end
    end)
end

function UBFHappyDeliveryPassLevelView:_playVisibleBottomFloat()
    if not isSafeCocosObj(self._rBottom) then return end
    local children = self._rBottom:getChildrenSafeList()
    for _, child in ipairs(children or {}) do
        if isSafeCocosObj(child) and child:isVisible() then
            local bigName = child:getName() .. "_big"
            local bigNode = child:getChildByName(bigName)
            if isSafeCocosObj(bigNode) then
                self:_playBottomFloat(bigNode)
            end
            break
        end
    end
end

function UBFHappyDeliveryPassLevelView:_playBottomFloat(node)
    if not isSafeCocosObj(node) then return end
    node:stopAllActions()
    local function playFloat()
        if not isSafeCocosObj(node) then return end
        UBFViewHelper.Animation:play({
            target  = node,
            type    = UBFViewHelper.Animation.Type.kSequence,
            actions = {
                {type = UBFViewHelper.Animation.Type.kPosition, byY =  12, duration = 20/30},
                {type = UBFViewHelper.Animation.Type.kPosition, byY = -12, duration = 20/30},
                {type = UBFViewHelper.Animation.Type.kCall, func = playFloat},
            },
        })
    end
    playFloat()
end

function UBFHappyDeliveryPassLevelView:_playBottomEntrance(node)
    if not isSafeCocosObj(node) then return end
    node:stopAllActions()
    local originY = node:getPositionY()
    UBFViewHelper.Animation:play({
        target  = node,
        type    = UBFViewHelper.Animation.Type.kSequence,
        actions = {
            {type = UBFViewHelper.Animation.Type.kPosition, byY = -12, duration = 2/30},
            {type = UBFViewHelper.Animation.Type.kPosition, byY =  42, duration = 5/30},
            {type = UBFViewHelper.Animation.Type.kPosition, byY = -37, duration = 5/30},
            {type = UBFViewHelper.Animation.Type.kPosition, byY =   7, duration = 8/30},
            {type = UBFViewHelper.Animation.Type.kCall, func = function()
                if isSafeCocosObj(node) then
                    node:setPositionY(originY)
                    self:_playBottomFloat(node)
                end
            end},
        },
    })
end

function UBFHappyDeliveryPassLevelView:_playSplitAnims(newCount)
    if isSafeCocosObj(self._rTitle) then
        local elapsed = 0
        self:_scheduleEntry(function(_, dt)
            elapsed = elapsed + dt
            if elapsed >= 8/30 then
                self:_refreshRewardTitle("ts")
                self:_updateTsLabel()
                return true
            end
        end)
    end
end

function UBFHappyDeliveryPassLevelView:_playUpgradeAnims(success, levelAfter)
    -- self:_applyUIVibrate()

    if isSafeCocosObj(self._rTitle) then
        local titleChild = nil
        local children = self._rTitle:getChildrenSafeList()
        for _, child in ipairs(children or {}) do
            if isSafeCocosObj(child) and child:isVisible() then
                titleChild = child
                break
            end
        end
        if isSafeCocosObj(titleChild) then
            titleChild:setScale(1)

            local function playTitleTail(target)
                if not isSafeCocosObj(target) then return end
                UBFViewHelper.Animation:play({
                    target  = target,
                    type    = UBFViewHelper.Animation.Type.kSequence,
                    actions = {
                        {type = UBFViewHelper.Animation.Type.kScale, to = 1.45, duration = 8/30},
                        {type = UBFViewHelper.Animation.Type.kScale, to = 0.9,  duration = 4/30},
                        {type = UBFViewHelper.Animation.Type.kScale, to = 1.0,  duration = 4/30},
                    },
                })
            end

            local actions = {
                {type = UBFViewHelper.Animation.Type.kDelay, duration = 4/30},
                {type = UBFViewHelper.Animation.Type.kScale, to = 1.4, duration = 4/30},
            }
            if success then
                table.insert(actions, {type = UBFViewHelper.Animation.Type.kCall, func = function()
                    self:_refreshRewardTitle()
                    local newChild = nil
                    local ch = self._rTitle:getChildrenSafeList()
                    for _, c in ipairs(ch or {}) do
                        if isSafeCocosObj(c) and c:isVisible() then
                            newChild = c
                            break
                        end
                    end
                    local target = isSafeCocosObj(newChild) and newChild or titleChild
                    target:setScale(1.4)
                    playTitleTail(target)
                end})
            else
                table.insert(actions, {type = UBFViewHelper.Animation.Type.kCall, func = function()
                    playTitleTail(titleChild)
                end})
            end
            UBFViewHelper.Animation:play({
                target  = titleChild,
                type    = UBFViewHelper.Animation.Type.kSequence,
                actions = actions,
            })
        end
    end

    if success then
        local elapsed = 0
        self:_scheduleEntry(function(_, dt)
            elapsed = elapsed + dt
            if elapsed >= 8/30 then
                self:_refreshRewardBg()
                return true
            end
        end)
    end
end

function UBFHappyDeliveryPassLevelView:_closeAndSuccess()
    self:dispose()
    safeRunCall(self._onSuccess)
end

function UBFHappyDeliveryPassLevelView:_dcGetBox()
    local scriptStrs = {}
    for _, v in ipairs(self._upgradeScript or {}) do
        table.insert(scriptStrs, tostring(v))
    end
    local outsideMgr = _G.amfBean("HappyDeliveryManager")
    local crowdId = outsideMgr and outsideMgr:getDataByKey("userCrowdId") or 0
    local params = {
        category = "backflow_task",
        sub_category = "get_box",
        panel_id = self._panelId,
        t1 = self._taskIndex,
        t2 = self._totalProgress,
        t3 = self._initBoxLevel,
        t4 = self._curBoxLevel,
        t5 = table.concat(scriptStrs, "_"),
        t6 = crowdId,
    }
    printx(15, "[HappyDelivery] dc get_box", table.tostring(params))
    DcUtil:UserTrack(params)
end

function UBFHappyDeliveryPassLevelView:_dcOpenBox()
    local params = {
        category = "backflow_task",
        sub_category = "open_box",
        panel_id = self._panelId,
        t1 = self._taskIndex,
        t2 = self._curBoxLevel,
    }
    printx(15, "[HappyDelivery] dc open_box", table.tostring(params))
    DcUtil:UserTrack(params)
end

function UBFHappyDeliveryPassLevelView:dispose()
    if self._disposed then return end
    self._disposed = true
    self:_removeOpenBoxEffects()
    self:_stopTxBoxDown()
    self:_unscheduleAll()
    if self._ui then
        if isSafeCocosObj(self._ui) then
            _G.amfBean("PopoutManager"):remove(self._ui, true)
        end
        self._ui:dispose()
        self._ui = nil
    end
end

return UBFHappyDeliveryPassLevelView
