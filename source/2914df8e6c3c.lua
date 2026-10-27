--[[
    OpenCardAnimLayer - 开包动画UI容器

    职责：
    1. 作为UI容器，管理子节点
    2. 响应状态机状态变化，执行对应的UI操作
    3. 处理用户交互（点击继续、点击跳过等）
]]
local OpenCardAnimLayer = class("OpenCardAnimLayer", Layer)
local deferred = require "amf.script.sugar.deferred"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local Const = _G.amfBean("CollectCardManager"):getConst()
local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"
local CollectCardLog = require "amf.feature.localactivity.collectcard.log.CollectCardLog"
local OpenCardAnimConfig = require_debug "amf.feature.localactivity.collectcard.view.opencardanim.OpenCardAnimConfig"
local OpenCardAnimStateMachine = require_debug "amf.feature.localactivity.collectcard.view.opencardanim.OpenCardAnimStateMachine"
local OpenCardAnimModel = require_debug "amf.feature.localactivity.collectcard.view.opencardanim.OpenCardAnimModel"
local OpenCardUIBuilder = require_debug "amf.feature.localactivity.collectcard.view.opencardanim.OpenCardUIBuilder"
local CardAnimator = require_debug "amf.feature.localactivity.collectcard.view.opencardanim.CardAnimator"
local OpenCardAnimController = require_debug "amf.feature.localactivity.collectcard.view.opencardanim.OpenCardAnimController"
local WeekTaskEventCenter = require 'amf.feature.localactivity.weektask.event.WeekTaskEventCenter'

local Config = OpenCardAnimConfig


function OpenCardAnimLayer:create(delegate)
    local layer = OpenCardAnimLayer.new()
    layer:initLayer()
    layer:init(delegate)
    return layer
end

function OpenCardAnimLayer:init(delegate)
    self:initWithComponents()
    self:initData(delegate)
    self:initStateMachine()
end

--[[
    初始化组件
    创建 Model、UIBuilder、Animator、Controller
    并建立依赖关系
]]
function OpenCardAnimLayer:initWithComponents()
    -- 数据模型（不依赖其他组件）
    self.model = OpenCardAnimModel.new()

    -- UI构建器（不依赖其他组件）
    self.uiBuilder = OpenCardUIBuilder.new()

    -- 动画播放器（依赖 Model、UIBuilder）
    self.animator = CardAnimator.new(self.model, self.uiBuilder)

    -- 流程控制器（依赖 Model、Animator、UIBuilder）
    self.animController = OpenCardAnimController.new(self.model, self.animator, self.uiBuilder)
    self.animController:setDelegate(self)
end

function OpenCardAnimLayer:initStateMachine()
    self.stateMachine = OpenCardAnimStateMachine.new(self)
end

function OpenCardAnimLayer:initData(delegate)
    self.model:initData(delegate)
    self.animFinishCallback = delegate.animFinishCallback
    self.openCardFlowId = delegate.openCardFlowId
end

function OpenCardAnimLayer:dispatchAnimEvent(eventName, data)
    data = data or {}
    data.openCardFlowId = self.openCardFlowId
    CollectCardEventCenter:dispatch(eventName, data)
end

function OpenCardAnimLayer:isMyOpenCardFlowEvent(event)
    local data = event:getData() or {}
    return data.openCardFlowId == self.openCardFlowId
end

-- ==================== Getter 方法 ====================
-- 提供给 Controller 和 Animator 访问

function OpenCardAnimLayer:getManager()
    return self.model:getManager()
end

function OpenCardAnimLayer:getStateMachine()
    return self.stateMachine
end

function OpenCardAnimLayer:getUIBuilder()
    return self.uiBuilder
end

function OpenCardAnimLayer:getModel()
    return self.model
end

function OpenCardAnimLayer:getStarShopIcon()
    return self.starShopIcon
end

function OpenCardAnimLayer:setStarShopIcon(icon)
    self.starShopIcon = icon
end

function OpenCardAnimLayer:getRewards()
    return self.model:getRewards()
end

function OpenCardAnimLayer:getCardPackLayer()
    return self.cardPackLayer
end

function OpenCardAnimLayer:getCardPackNodes()
    return self.cardPackNodes
end

function OpenCardAnimLayer:getShowCardLayer()
    return self.showCardLayer
end

function OpenCardAnimLayer:setShowCardLayer(layer)
    self.showCardLayer = layer
end

function OpenCardAnimLayer:getCurCardPackSp()
    return self.curCardPackSp
end

function OpenCardAnimLayer:setCurCardPackSp(sp)
    self.curCardPackSp = sp
end

function OpenCardAnimLayer:getOpeningIdx()
    return self.model:getOpeningIdx()
end

-- 委托给 Model（供 UIBuilder.createStarShopIcon 的 refreshNum 方法使用）
function OpenCardAnimLayer:getLocalStarNum()
    return self.model:getLocalStarNum()
end

function OpenCardAnimLayer:addLocalStarNum(num)
    self.model:addLocalStarNum(num)
end

function OpenCardAnimLayer:addScrollShowLayer(layer)
    self.scrollShowLayer = layer
    self:addChild(layer)
end

-- 委托给 Animator
function OpenCardAnimLayer:playSkipLightAnim(animScale)
    self.animator:playSkipLightAnim(self, animScale)
end

-- ==================== 状态转换触发方法 ====================

function OpenCardAnimLayer:onCardPackOpened()
    self.model:setSortedCardList({})
    self.stateMachine:enterState(Config.AnimState.OPEN, {
        isContinue = true
    })
end

function OpenCardAnimLayer:onAllCardPackOpened()
    self.model:setSortedCardList({})
    self.stateMachine:enterState(Config.AnimState.STOPATLAST)
end

-- ==================== 状态响应方法 ====================
-- 由状态机调用，执行对应状态的UI操作

--[[
    SHOW 状态：展示卡包，等待玩家点击开包
    流程：创建卡包节点 -> 播放入场动画 -> 显示"点击继续"
]]
function OpenCardAnimLayer:onStateShow()
    self:initCardAnimLayer()
    self.cardPackLayer:setScale(0.7)
    self.cardPackLayer:runAction(ActionUtil:sequence{
        CCScaleTo:create(4*Config.FRAME_TIME, 1.1),
        CCScaleTo:create(3*Config.FRAME_TIME, 1),
        CCCallFunc:create(function()
            if self.isDisposed then return end
            self:showClickContinueNode(function()
                if self.isDisposed then return end
                self.stateMachine:enterState(Config.AnimState.OPEN)
            end)
            self:dispatchAnimEvent(CollectCardEvent.CARD_PACK_ANIM_SHOW)
        end)
    })
    self.model:getManager():playEffect(Const.Sound.CARDPACK_APPEAR)
end

function OpenCardAnimLayer:onStateFinishShow()
    self:hideClickContinueNode()
end

-- 初始化卡包动画层（创建卡包节点）
function OpenCardAnimLayer:initCardAnimLayer()
    local cardPackLayer = Layer:create()
    self:addChild(cardPackLayer)
    local count = 0
    local nodeInfos = {}
    local rewards = self.model:getRewards()
    for i, reward in ipairs(rewards) do
        if count >= 8 then break end
        local itemId = reward.itemId
        if self.model:getManager():isCardPack(itemId) then
            local level = self.model:getManager():getCardPackLevel(itemId)
            local sp = self.uiBuilder:createCardPackSpine(level)
            cardPackLayer:addChildAt(sp, 0)
            count = count + 1
            table.insert(nodeInfos, {node = sp, width = 200})
        end
    end
    if not table.isEmpty(nodeInfos) then
        LayoutUtil.sortNodes(nodeInfos, nil, -280+self.uiBuilder:getCardPackSpace(count))
    end
    cardPackLayer:setScale(0)
    self.cardPackNodes = nodeInfos
    self.cardPackLayer = cardPackLayer
end

--[[
    OPEN 状态：开始开包
    流程：启动开包动画 -> 显示跳过按钮（如果卡包数量>=5）
]]
function OpenCardAnimLayer:onStateOpen(delegate)
    self:dispatchAnimEvent(CollectCardEvent.CARD_PACK_ANIM_OPEN)
    if delegate and delegate.isContinue then return end
    self:startOpenCardAnim()
    if #self.model:getRewards() >= 2 then
        self:showClickSkipNode(function()
            self.stateMachine:enterState(Config.AnimState.SKIP)
        end)
    end
end

function OpenCardAnimLayer:onStateFinishOpen()

end

function OpenCardAnimLayer:startOpenCardAnim()
    self.animController:startOpenCardAnim(
        self.cardPackNodes,
        self.model:getRewards()
    )
end

--[[
    OPENING 状态：正在开包
    流程：更新UI（显示当前进度）-> 等待开包完成
]]
function OpenCardAnimLayer:onStateOpening(delegate)
    self._openingEndCallback = delegate.endCallback
    self.model:setOpeningIdx(delegate.curIdx)
    -- OPENING状态下，关闭按钮触发小跳（与全局点击一致）
    self._openingBackKeyFunc = function(context, evt)
        if self.isDisposed then return end
        if not self:isMyOpenCardFlowEvent(evt) then return end
        evt:setReceived()
        local stateMachine = self:getStateMachine()
        if stateMachine and stateMachine:getState() == Config.AnimState.OPENING and not self.animController._cardShowFinish then
            self.animController:skipOpenCardAnim()
        end
    end
    CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_FLOW_BACK_CLICKED, self._openingBackKeyFunc, self)
    self:dispatchAnimEvent(CollectCardEvent.CARD_PACK_ANIM_OPENING, {
        openingIdx = self.model:getOpeningIdx(),
    })
end

function OpenCardAnimLayer:onStateFinishOpening(nextState)
    if self._openingBackKeyFunc then
        CollectCardEventCenter:unregister(CollectCardEvent.CARD_PACK_FLOW_BACK_CLICKED, self._openingBackKeyFunc)
        self._openingBackKeyFunc = nil
    end
    -- 如果是跳过，不执行后续逻辑
    if nextState == Config.AnimState.SKIP then
        return
    end

    -- 如果是最后一个卡包，直接结束
    local isLastPack = self.model:getOpeningIdx() and self.model:getOpeningIdx() >= #self.model:getRewards()
    if isLastPack then
        safeRunCall(self._openingEndCallback)
        return
    end

    -- 结算重复卡 -> 切换下一个卡包
    self.model:markPackSettled(self.model:getOpeningIdx())
    deferred.success()
    :next(function()
        if self.isDisposed then return end
        if self.animController.skipAllCardAnim then return end
        return self.animController:settleCards(self.model:getShownCardList(), self.scrollShowLayer)
    end)
    :next(function()
        if self.isDisposed then return end
        if self.animController.skipAllCardAnim then return end
        return self.animController:switchToNextCardPack()
    end)
    :next(function()
        if self.isDisposed then return end
        if self.animController.skipAllCardAnim then return end
        safeRunCall(self._openingEndCallback)
    end)
end

function OpenCardAnimLayer:playCurCardPackOutAnim()
    self.animController:playCurCardPackOutAnim()
end


function OpenCardAnimLayer:notifyWeekTask()
    --周任务推数据变更
    --获取开卡的总数
    local getCardList = self.model:getGetCardList()
    local allNum = 0
    for i,v in pairs(getCardList) do
        allNum = allNum + v
    end

    WeekTaskEventCenter:dispatch(_G.WeekTaskEvent.ACT_TASK_COMPLETE, { type=_G.WeekTaskType.CARD_ACT_GET_NUM, num=allNum})
end
--[[
    STOPATLAST 状态：最后一包开完，等待玩家点击收下
    流程：播放卡包出场动画 -> 显示"收下"按钮 -> 结算
]]
function OpenCardAnimLayer:onStateStopAtLast()
    self:dispatchAnimEvent(CollectCardEvent.CARD_PACK_ANIM_STOP_AT_LAST)


    self:notifyWeekTask()

    self:playCurCardPackOutAnim()
    local showBtnDelay = 10 * Config.FRAME_TIME
    self:hideClickSkipNode(showBtnDelay)
    self._isShowClickBtn = false
    self:showClickBtn("收下", function()
        if self.isDisposed then return end
        if self._isShowClickBtn then return end
        self._isShowClickBtn = true
        self:hideClickBtn()
        self:setFlowCloseBtnVisible(false)
        self.model:getManager():playEffect(Const.Sound.CLICK_COMMON_01)
        self.model:getManager():playHaptics(Const.Haptics.BUTTON_NORMAL)
        self.model:markPackSettled(self.model:getOpeningIdx())
        deferred.success()
        :next(function()
            return self.animController:settleCards(self.model:getShownCardList(), self.scrollShowLayer)
        end)
        :next(function()
            if self.isDisposed then return end
            self.stateMachine:enterState(Config.AnimState.FINISH)
        end)
    end, showBtnDelay)
end

function OpenCardAnimLayer:onStateFinishStopAtLast()
    self:hideClickBtn()
end

--[[
    SKIP 状态：跳过所有动画，直接展示最终结果
    流程：显示所有卡牌 -> 显示"收下"按钮 -> 结算
]]
function OpenCardAnimLayer:onStateSkip()
    local totalNum = #self.model:getRewards()
    local settledNum = self.model:getSettledPackCount()
    local skippedNum = math.max(totalNum - settledNum, 0)
    self:dispatchAnimEvent(CollectCardEvent.CARD_PACK_ANIM_SKIP, {
        skippedNum = skippedNum,
    })

    local getCardList = self.model:getGetCardList()
    local allNum = 0
    for i,v in pairs(getCardList) do
        allNum = allNum + v
    end
    WeekTaskEventCenter:dispatch(_G.WeekTaskEvent.ACT_TASK_COMPLETE, { type=_G.WeekTaskType.CARD_ACT_GET_NUM, num=allNum})

    local showBtnDelay = 25 * Config.FRAME_TIME
    self:hideClickSkipNode(showBtnDelay)
    self:hideClickContinueNode()
    self:removeGlobalClick()

    self.animController:skipAllAnimShowFinal()
    self._isShowClickBtn2 = false
    self:showClickBtn("收下", function()
        if self.isDisposed then return end
        if self._isShowClickBtn2 then return end
        self._isShowClickBtn2 = true
        self:hideClickBtn()
        self:setFlowCloseBtnVisible(false)
        deferred.success()
        :next(function()
            return self.animController:settleAllCards(self.model:getFinalShownCardList(), self.scrollShowLayer)
        end)
        :next(function()
            if self.isDisposed then return end
            self.stateMachine:enterState(Config.AnimState.FINISH)
        end)
    end, showBtnDelay)
end

function OpenCardAnimLayer:onStateFinishSkip()

end

--[[
    FINISH 状态：动画结束
]]
function OpenCardAnimLayer:onStateFinish()
    self:dispatchAnimEvent(CollectCardEvent.CARD_PACK_ANIM_FINISH)
    safeRunCall(self.animFinishCallback)
    self.animFinishCallback = nil
end

-- ==================== UI交互方法 ====================

-- 显示"点击继续"提示
function OpenCardAnimLayer:showClickContinueNode(clickFunc, text, customHitTest)
    local ClickContinue = require("amf.middleware.ui.kit.component.skip.ClickContinue")
    local clickJumpLayer = ClickContinue.Builder.new()
    :setTarget(self)
    :setText(text or "点击任意位置继续")
    :setShowAnimTime(2*Config.FRAME_TIME)
    :setCustomHitTest(customHitTest)
    :setClickCallback(function()
        if clickFunc then clickFunc() end
    end)
    :build()
    clickJumpLayer:showOnScene(SceneLayerShowKey.TOP_LAYER)
    self.clickJumpLayer = clickJumpLayer
end

function OpenCardAnimLayer:getClickContinueHitTest()
    return function(worldPos)
        if self.scrollShowLayer
            and not self.scrollShowLayer.isDisposed
            and self.scrollShowLayer.hitTestPoint
            and self.scrollShowLayer:hitTestPoint(worldPos) then
            return false
        end
        return true
    end
end

function OpenCardAnimLayer:setScrollShowLayerClickContinue(clickFunc)
    if not self.scrollShowLayer
        or self.scrollShowLayer.isDisposed
        or not self.scrollShowLayer.setCellTouchFunc then
        return
    end

    self.scrollShowLayer:setCellTouchFunc(function()
        if self.isDisposed then return end
        if self._scrollShowLayerClick then
            return
        end
        self._scrollShowLayerClick = true
        safeRunCall(clickFunc)
    end)

    if self.scrollShowLayer.updateViewForce then
        self.scrollShowLayer:updateViewForce()
    end
end

function OpenCardAnimLayer:hideClickContinueNode()
    if self.clickJumpLayer and not self.clickJumpLayer.isDisposed then
        self.clickJumpLayer:close()
        self.clickJumpLayer = nil
    end
end

function OpenCardAnimLayer:getFlowCloseBtn()
    if self._flowCloseBtn and not self._flowCloseBtn.isDisposed then
        return self._flowCloseBtn
    end

    local node = self
    while node do
        if node.closeBtn and not node.closeBtn.isDisposed then
            self._flowCloseBtn = node.closeBtn
            return node.closeBtn
        end
        if node.getParent then
            node = node:getParent()
        else
            node = nil
        end
    end

    return nil
end

function OpenCardAnimLayer:setFlowCloseBtnVisible(visible)
    local closeBtn = self:getFlowCloseBtn()
    if closeBtn then
        closeBtn:setVisible(visible)
    end
end

-- 显示跳过按钮
function OpenCardAnimLayer:showClickSkipNode(clickFunc)
    self:hideClickSkipNode()

    local skipRoot = Node:create()
    local scene = Director:sharedDirector():getRunningSceneLua()
    scene:addChild(skipRoot, SceneLayerShowKey.TOP_LAYER)
    self.skipRoot = skipRoot

    local clickNode = Node:create()
    skipRoot:addChild(clickNode)
    clickNode:setTouchHandler(function()
        printx(33, "OpenCardAnimLayer:showClickSkipNode click")
        if self.isDisposed then return end
        safeRunCall(clickFunc)
    end, {w = 163, h = 42}, nil, true)
    clickNode:setName("OpenCardAnimLayer_clickSkipNode")
    self.skipClickNode = clickNode

    local closeBtn = self:getFlowCloseBtn()
    local closeBtnPos = closeBtn and closeBtn:getPositionInWorldSpace()
    if closeBtnPos then
        local sp = UICreateUtil:createSpriteFile(OpenCardAnimConfig.ResPath.FlowSkipBtn)
        self.skipRoot:addChild(sp)
        self.skipRoot:makeContentSizeContainChildren()
        self.skipSpine = sp
        self.skipRoot:setPositionInWorldSpace(ccp(closeBtnPos.x, closeBtnPos.y))
        if EnvUtil:isMiniGame() then
            LayoutUtil:move(self.skipRoot, 30, 0)
        else
            LayoutUtil:move(self.skipRoot, -30, 0)
        end
    end

    self._skipCloseBtnVisibleBefore = nil
    local closeBtn = self:getFlowCloseBtn()
    if closeBtn then
        self._skipCloseBtnVisibleBefore = closeBtn:isVisible()
    end
    self:setFlowCloseBtnVisible(false)
end

function OpenCardAnimLayer:hideClickSkipNode(closeBtnShowDelay)
    if self.skipRoot then
        self.skipRoot:removeFromParentAndCleanup(true)
        self.skipRoot = nil
    end
    self.skipClickNode = nil
    self.skipSpine = nil

    if self.skipPanelVM and not self.skipPanelVM.isDisposed then
        self.skipPanelVM:close()
        self.skipPanelVM = nil
    end

    if self._skipCloseBtnVisibleBefore ~= nil then
        local setCloseBtnVisible = function ()
            self:setFlowCloseBtnVisible(self._skipCloseBtnVisibleBefore)
            self._skipCloseBtnVisibleBefore = nil
        end
        if closeBtnShowDelay then
            setTimeOut(function ()
                if self.isDisposed then return end
                setCloseBtnVisible()
            end, closeBtnShowDelay)
        else
            setCloseBtnVisible()
        end

    end
end

-- 设置全局点击（用于跳过当前卡包动画）
function OpenCardAnimLayer:setGlobalClick(clickFunc)
    local globalClickLayer = Layer:create()
    self:addChild(globalClickLayer)
    globalClickLayer:setTouchHandler(function()
        if clickFunc then clickFunc() end
    end, nil, _G.alwaysTrue, true)
    globalClickLayer:setName("OpenCardAnimLayer_globalClickLayer")
    self.globalClickLayer = globalClickLayer
end

function OpenCardAnimLayer:removeGlobalClick()
    if self.globalClickLayer then
        self.globalClickLayer:removeFromParentAndCleanup(true)
        self.globalClickLayer = nil
    end
end

-- 显示按钮（收下）, 06-29收下按钮改成 点击任意位置继续
function OpenCardAnimLayer:showClickBtn(str, clickFunc, delay)
    delay = delay or (10 * Config.FRAME_TIME)
    setTimeOut(function ()
        if self.isDisposed then return end
        self:showClickContinueNode(clickFunc, nil, self:getClickContinueHitTest())
        if self._scrollShowLayerClick then self._scrollShowLayerClick = false end
        self:setScrollShowLayerClickContinue(clickFunc)
    end, delay)

    self.backKeyClickFunc = function(context, evt)
        if self.isDisposed then return end
        if not self:isMyOpenCardFlowEvent(evt) then return end
        evt:setReceived()
        if clickFunc then clickFunc() end
    end
    CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_FLOW_BACK_CLICKED, self.backKeyClickFunc, self)

end

function OpenCardAnimLayer:hideClickBtn()
    if self.isDisposed then return end
    CollectCardEventCenter:unregister(CollectCardEvent.CARD_PACK_FLOW_BACK_CLICKED, self.backKeyClickFunc)
    self:hideClickContinueNode()
end

-- ==================== 生命周期方法 ====================

function OpenCardAnimLayer:pretreat()

end

function OpenCardAnimLayer:playShowAnim(done)
    self.stateMachine:init()
    setTimeOut(function()
        if self.isDisposed then return end
        if done then done() end
    end, 7*Config.FRAME_TIME)
end

function OpenCardAnimLayer:flyFunc()

end

function OpenCardAnimLayer:jumpShowAnim()

end

function OpenCardAnimLayer:bubbleAutoClick()

end

function OpenCardAnimLayer:dispose()
    if self.scrollShowLayer and self.scrollShowLayer.cancelDeferredCellCreation then
        self.scrollShowLayer:cancelDeferredCellCreation()
    end
    if self._openingBackKeyFunc then
        CollectCardEventCenter:unregister(CollectCardEvent.CARD_PACK_FLOW_BACK_CLICKED, self._openingBackKeyFunc)
        self._openingBackKeyFunc = nil
    end
    if self.animController then
        self.animController:dispose()
        self.animController = nil
    end
    if self.animator then
        self.animator:clearAllStarNodes()
    end
    if self.starShopIcon and not self.starShopIcon.isDisposed then
        self.starShopIcon:removeFromParentAndCleanup(true)
        self.starShopIcon = nil
    end
    self:hideClickContinueNode()
    self:hideClickSkipNode()
    self:removeGlobalClick()
    Layer.dispose(self)
end

return OpenCardAnimLayer
