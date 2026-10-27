UBFUESlpBottomWinRepeatRank = class2("UBFUESlpBottomWinRepeatRank", UBFSlpPlpViewLogic)
UBFDebug:monitoringClass(UBFUESlpBottomWinRepeatRank)
UBFLogicCreator:registerLogic(WinRepeatRank2023LogicId.UE_SLP_BOTTOM, UBFUESlpBottomWinRepeatRank)

local CELL_WIDTH = 150
local VIEW_WIDTH = 600
local VIEW_HEIGHT = 231
local GIFT_BOX_ICON_SIZE = 256
local HEAD_IMAGE_SCALE = 0.65
local NumberUtil = require "amf.middleware.ui.util.NumberUtil"
local deferred = require "amf.script.sugar.deferred"
local Meta = require("amf.feature.localactivity.winrepeatrank.meta.WinRepeatRankMeta")

local function _getSlpBottomData(bottomCarouselData)
    return (bottomCarouselData and bottomCarouselData.data) or EMPTY_TABLE
end

local function _updateGiftBoxTouchLayer(root, giftBox)
    if not isSafeCocosObj(root) or not isSafeCocosObj(giftBox) then return nil end

    local touchParent = giftBox.getParent and giftBox:getParent() or root
    if not isSafeCocosObj(touchParent) then
        touchParent = root
    end

    local touchLayer = touchParent:getChildByName("giftBoxTouchLayer")
    if not isSafeCocosObj(touchLayer) then
        touchLayer = UBFLayer:create()
        touchLayer:setName("giftBoxTouchLayer")
        touchLayer:ignoreAnchorPointForPosition(false)
        touchParent:addChild(touchLayer)
    end

    touchLayer:setAnchorPoint(ccp(0.5, 0.5))
    local giftBoxPos = giftBox:getPosition()
    local giftBoxScaleX = giftBox.getScaleX and math.abs(giftBox:getScaleX()) or 1
    local giftBoxScaleY = giftBox.getScaleY and math.abs(giftBox:getScaleY()) or 1
    local giftBoxVisualWidth = GIFT_BOX_ICON_SIZE * giftBoxScaleX
    local giftBoxVisualHeight = GIFT_BOX_ICON_SIZE * giftBoxScaleY
    touchLayer:setContentSize(CCSizeMake(giftBoxVisualWidth, giftBoxVisualHeight))
    touchLayer:setPositionXY(giftBoxPos.x, giftBoxPos.y)
    return touchLayer
end

function UBFUESlpBottomWinRepeatRank.createDefaultCreateData(initParams)
    local createData = UBFSlpPlpViewLogic.createDefaultCreateData(initParams)
    createData.selfView = {
        viewType = UBFUiViewType.UI,
        lua = "ubf/UBFActivity/actFolder/WinRepeatRank2023/views/UISource/UBFUEBottomWinRepeatRank_UI.lua",
        position = {x = 0, y = 0},
    }

    return createData
end

function UBFUESlpBottomWinRepeatRank:onViewCreate()
    UBFSlpPlpViewLogic.onViewCreate(self)
    self:initData()
end

function UBFUESlpBottomWinRepeatRank:onPlayEnterTransition(finishImmediately)
    local promise = UBFPromise:create()
    local finish = function()
        if not self:isViewSafe() then
            promise:resolve()
            return
        end
        self:finishAnim()
        promise:resolve()
    end

    if self.contentReadyPromise then
        self.contentReadyPromise:next(finish, finish)
    else
        finish()
    end

    return promise
end

function UBFUESlpBottomWinRepeatRank:getSlpBottomData()
    return _getSlpBottomData(self.createData.bottomCarouselData)
end

function UBFUESlpBottomWinRepeatRank:initData()
    local slpBottomData = self:getSlpBottomData()
    local eventDataInfo = slpBottomData.eventDataInfo
    if eventDataInfo then
        self.raceType = eventDataInfo.raceType
        self.myRank = eventDataInfo.newRank
        self.playerList = slpBottomData.rankList
        self.rankRewardMap = slpBottomData.rankRewardMap or {}
        self.eventDataInfo = eventDataInfo
        self:initContent()
    end
end

function UBFUESlpBottomWinRepeatRank:onUpdate(data)
    self.createData.bottomCarouselData = data.bottomCarouselData
    self:initData()
end

function UBFUESlpBottomWinRepeatRank:unreferenceCellView(cellName, node)
    if cellName then
        self:_unreferenceView(cellName)
    end

    local selfView = self:getMainAgented()
    local refMap = selfView and selfView.fields
    if not refMap or not node then return end

    local removeTargets = {[node] = true}
    for _, child in pairs(node.fields or EMPTY_TABLE) do
        removeTargets[child] = true
    end

    for viewName, view in pairs(refMap) do
        if removeTargets[view] then
            refMap[viewName] = nil
        end
    end
end

function UBFUESlpBottomWinRepeatRank:cleanupContent()
    self.contentVersion = (self.contentVersion or 0) + 1
    if self.scrollView == self:getView("ScrollView") then
        self:removeView("ScrollView")
    elseif isSafeCocosObj(self.scrollView) then
        self.scrollView:removeFromParentAndCleanup(true)
    end
    self.scrollView = nil

    for _, node in ipairs(self.nodeList or {}) do
        local cellName = node and node.cellName
        self:unreferenceCellView(cellName, node)
        if cellName then
            if self._cachedViews then
                self._cachedViews[cellName] = nil
            end
            if self._pendingViewCreateData then
                self._pendingViewCreateData[cellName] = nil
            end
        end
        if isSafeCocosObj(node) then
            node:removeFromParentAndCleanup(true)
        end
    end

    local playerCount = #(self.playerList or EMPTY_TABLE)
    local oldPlayerCount = math.max(self.lastPlayerCellCount or 0, playerCount)
    for i = 1, oldPlayerCount do
        local cellName = "playerCell_" .. i
        self:unreferenceCellView(cellName, self:getView(cellName))
        if self._cachedViews then
            local cachedView = self._cachedViews[cellName]
            self:unreferenceCellView(cellName, cachedView)
            if isSafeCocosObj(cachedView) then
                cachedView:removeFromParentAndCleanup(true)
            end
            self._cachedViews[cellName] = nil
        end
        if self._pendingViewCreateData then
            self._pendingViewCreateData[cellName] = nil
        end
    end

    self.nodeList = {}
    self.myNode = nil
    self.myNodeIndex = nil
    self.lastPlayerCellCount = playerCount
    return self.contentVersion
end

function UBFUESlpBottomWinRepeatRank:initContent()
    local contentVersion = self:cleanupContent()

    local contentLayer = UBFLayer:create()
    contentLayer:setAnchorPoint(ccp(0, 0))
    contentLayer:setName("contentView")

    local scrollW = math.max(VIEW_WIDTH, #self.playerList * CELL_WIDTH)
    local scrollLayer = UBFLayer:create()
    scrollLayer:setAnchorPoint(ccp(0, 0))
    scrollLayer:setName("ScrollLayer")
    scrollLayer:addChild(contentLayer)
    contentLayer:setPositionXY(0, 0)
    scrollLayer:setPositionXY(0, -VIEW_HEIGHT)
    function scrollLayer:getWidth()
        if scrollLayer.isDisposed then return 0 end
        return scrollW
    end

    local HorizontalScrollable = UBFViewHelper:toolkit("HorizontalScrollable")
    local scrollView = HorizontalScrollable:create(VIEW_WIDTH, 300, true, true, -1000, false)
    scrollView:setName("ScrollView")
    scrollView:setGlobalScroll(UBFUiTouchPriority.BottomCarousel - 1)
    scrollView:setIgnoreHorizontalMove(true)
    scrollView:setContent(scrollLayer)
    scrollView:setScrollableWidth(scrollW)
    function scrollView:containsPoint(worldPos)
        if scrollView.isDisposed then return false end
        local relaPos = scrollView:convertToNodeSpace(worldPos)
        return relaPos.x >= 0
            and relaPos.x <= scrollView.width
            and relaPos.y <= 0
            and relaPos.y >= -scrollView.height
    end

    scrollView:setPositionXY(0, VIEW_HEIGHT)
    self.scrollView = scrollView
    self:addChildView("ScrollView", scrollView, "horizontalContainer")
    self:initScrollViewGiftBoxHitTest(scrollView)

    local promises = {}
    for i, info in ipairs(self.playerList) do
        local cellName = "playerCell_" .. i
        local promise = self:createAndAddViewAsync({
            viewType = UBFUiViewType.UI,
            lua = "ubf/UBFActivity/actFolder/WinRepeatRank2023/views/UISource/UBFUEBottomWinRepeatRankCell_UI.lua",
            -- autoReference = true,
        }, cellName):next(function(node)
            if not self:isViewSafe() or not isSafeCocosObj(node) then return end
            if contentVersion ~= self.contentVersion then
                node:removeFromParentAndCleanup(true)
                self:unreferenceCellView(cellName, node)
                if self._cachedViews then
                    self._cachedViews[cellName] = nil
                end
                if self._pendingViewCreateData then
                    self._pendingViewCreateData[cellName] = nil
                end
                return
            end
            self:retrieveCachedView(cellName)
            node.info = table.clone(info)
            node.cellName = cellName
            contentLayer:addChild(node)
            node:setPositionXY((i - 1) * CELL_WIDTH, 0)
            self:referenceView(cellName, node, true)
            self:updatePlayerNode(node, info, cellName)
            if info.isMe then
                self.myNode = node
                self.myNodeIndex = i
            end
            self.nodeList[i] = node
        end)
        table.insert(promises, promise)
    end

    self.contentReadyPromise = deferred.all(promises):next(function()
        if not self:isViewSafe() or contentVersion ~= self.contentVersion then return end
        local offset = self:getScrollLabelOffsetByCellIndex(self.myNodeIndex or self.myRank)
        self.scrollView:gotoPositionX(offset, 0)
        self:finishAnim()
    end)
end

function UBFUESlpBottomWinRepeatRank:initScrollViewGiftBoxHitTest(scrollView)
    if not isSafeCocosObj(scrollView) or not isSafeCocosObj(scrollView.touchLayer) then return end
    scrollView.touchLayer:setGlobalHitTestPoint(function(worldPos)
        return scrollView:containsPoint(worldPos)
    end, false)
end

function UBFUESlpBottomWinRepeatRank:getScrollLabelOffsetByCellIndex(cellIndex)
    local scrollW = math.max(VIEW_WIDTH, #self.playerList * CELL_WIDTH)
    local cellCenterX = (cellIndex - 0.5) * CELL_WIDTH
    local offset = VIEW_WIDTH * 0.5 - cellCenterX
    local minOffset = VIEW_WIDTH - scrollW
    if offset > 0 then
        return 0
    elseif offset < minOffset then
        return minOffset
    end
    return offset
end

function UBFUESlpBottomWinRepeatRank:getCellRefs(node)
    if not isSafeCocosObj(node) then return nil end
    local fields = node.fields or {}
    local root = fields.listItemCenter or node
    local function child(parent, name)
        return fields[name]
    end

    local rankPart = child(root, "rankPart")
    local topOther = child(rankPart, "topOther")
    local headPart = child(root, "headPart")
    local collectPart = child(root, "collectPart")
    return {
        root = root,
        listItemBg = child(root, "listItemBg"),
        listItemBg2 = child(root, "listItemBg2"),
        rankPart = rankPart,
        top1 = child(rankPart, "top1"),
        top2 = child(rankPart, "top2"),
        top3 = child(rankPart, "top3"),
        topOther = topOther,
        topOtherBg = child(topOther, "topOtherBg"),
        topOtherBg2 = child(topOther, "topOtherBg2"),
        topOtherLabel = child(topOther, "topOtherLabel"),
        headPart = headPart,
        headImage = child(headPart, "headImage"),
        headFrame = child(headPart, "headFrame"),
        headFrame2 = child(headPart, "headFrame2"),
        collectPart = collectPart,
        collectPartBg = child(collectPart, "collectPartBg"),
        collectPartBg2 = child(collectPart, "collectPartBg2"),
        collectPartScore = child(collectPart, "collectPartScore"),
        giftBox = child(root, "giftBox"),
        noPoppleTip = child(root, "noPoppleTip"),
        effectHolder = child(root, "effectHolder"),
    }
end

function UBFUESlpBottomWinRepeatRank:getReferencedCellViewName(cellName, node, viewName)
    if not cellName or not isSafeCocosObj(node) then return nil end
    local refs = self:getCellRefs(node)
    local target = refs and refs[viewName]
    if not isSafeCocosObj(target) then return nil end

    local prefixedName = cellName .. "_" .. viewName
    if self:getView(prefixedName) == target then
        return prefixedName
    end
    if self:getView(viewName) == target then
        return viewName
    end
end

function UBFUESlpBottomWinRepeatRank:updateGiftBoxItemImage(node, rank, rewards)
    local giftBoxViewName = self:getReferencedCellViewName(node and node.cellName, node, "giftBox")
    if not giftBoxViewName then return end

    local updateData = {
        itemId = _G._UEItemIdConvertor_NoSetID or 99999999,
    }
    if #rewards == 1 and rewards[1] then
        local reward = rewards[1]
        updateData.itemId = reward.itemId
        updateData.num = reward.num
    elseif #rewards > 1 then
        updateData.itemImage = {Frame = self:getGixtBoxSpriteFrameName(rank)}
    end
    self:updateView(giftBoxViewName, updateData)

    local refs = self:getCellRefs(node)
    local giftBox = refs and refs.giftBox
    if #rewards == 1 and isSafeCocosObj(giftBox) and giftBox.updateItemType then
        giftBox.item = updateData
        giftBox:updateItemType()
    end
end

function UBFUESlpBottomWinRepeatRank:getShowScore(score)
    if score < 100000 then
        return NumberUtil:formatBigNumber(score, 2)
    else
        return NumberUtil:formatBigNumber(score, 1)
    end
end

function UBFUESlpBottomWinRepeatRank:createHeadData(info, replaceViewName)
    local function getRandomHeadImage()
        return HeadImageType.k_birth_0
    end

    local headUrl = info.profile and info.profile.headUrl
    if not info.isEmpty and not headUrl then
        headUrl = getRandomHeadImage()
    end

    return {
        creator = function()
            local profile = {headUrl = headUrl, uid = info.uid}
            local head = HeadImage:create(profile, {
                ignoreHeadFrame = true,
            })
            return head
        end,
        replaceViewName = replaceViewName,
    }
end

function UBFUESlpBottomWinRepeatRank:updatePlayerNode(node, info, cellName)
    local rank = info.rank
    local isMe = info.isMe
    local score = info.score
    local refs = self:getCellRefs(node)
    if not refs or not isSafeCocosObj(refs.rankPart) then
        return
    end

    refs.listItemBg:setVisible(not isMe)
    refs.listItemBg2:setVisible(isMe)
    refs.collectPartBg:setVisible(not isMe)
    refs.collectPartBg2:setVisible(isMe)
    refs.headFrame:setVisible(not isMe)
    refs.headFrame2:setVisible(isMe)
    refs.topOtherBg:setVisible(not isMe)
    refs.topOtherBg2:setVisible(isMe)
    refs.collectPart:setVisible(not info.isEmpty)
    refs.noPoppleTip:setVisible(info.isEmpty)

    refs.collectPartScore:enableOutline(hex2ccc4("85450099"), 2)
    refs.collectPartScore:setString(self:getShowScore(score))

    local replaceViewName = self:getReferencedCellViewName(cellName, node, "headImage")
    if replaceViewName then
        self:updateView(replaceViewName, {scale = HEAD_IMAGE_SCALE})
        self:createAndAddViewAsync(self:createHeadData(info, replaceViewName))
    end

    refs.top1:setVisible(rank == 1)
    refs.top2:setVisible(rank == 2)
    refs.top3:setVisible(rank == 3)
    refs.topOther:setVisible(rank > 3)
    refs.topOtherLabel:setString("" .. rank)

    local bHasReward, rewards, extraRewards, mergeRewards = self:checkHasRankRewards(rank)
    if bHasReward then
        self:updateGiftBoxItemImage(node, rank, mergeRewards)
    end
    refs.giftBox:setVisible(bHasReward)
    local touchLayer = _updateGiftBoxTouchLayer(refs.root, refs.giftBox)
    if touchLayer then
        touchLayer:setTouchEnabled(bHasReward, -1001, true, nil, true)
        touchLayer:removeAllEventListeners()
        touchLayer:ad(DisplayEvents.kTouchTap, function()
            self:onGiftBoxClick(node, refs.giftBox)
        end)
    end
end

function UBFUESlpBottomWinRepeatRank:onGiftBoxClick(node, giftBox)
    if not self:isViewSafe() then return end
    if not self.animFinished then return end
    if not isSafeCocosObj(node) or not isSafeCocosObj(giftBox) then return end

    local cellInfo = node.info
    local curRank = cellInfo and cellInfo.rank
    local hasReward, rewards, extraRewards = self:checkHasRankRewards(curRank)
    if not hasReward then return end

    local slpBottomData = self:getSlpBottomData()
    local titleStr = string.format("%s结算时,第%d名可得", slpBottomData.titleName, curRank)
    UBFViewHelper:showUITip({
        target = giftBox,
        title = titleStr,
        rewards = rewards,
        extraRewards = extraRewards,
        disappearSec = 2
    })
end

function UBFUESlpBottomWinRepeatRank:checkHasRankRewards(rank)
    local rewardInfo = self.rankRewardMap[rank] or self.rankRewardMap[tostring(rank)]
    local rewards = rewardInfo and rewardInfo.rewards or {}
    local extraRewards = rewardInfo and rewardInfo.extraRewards
    local mergeRewards = table.union(rewards, extraRewards)
    if table.isEmpty(mergeRewards) then
        return false, {}, nil
    end
    return true, rewards, extraRewards, mergeRewards
end

function UBFUESlpBottomWinRepeatRank:getGixtBoxSpriteFrameName(rank)
    if self.raceType == Meta.mainPanelShowType.kMainPanel3 and rank > 1 then
       return 'common/icon_256/icon_baoxiang_siji_256_01'
    end
    if rank == 1 then
        return 'common/icon_256/icon_baoxiang_wuji_256_01'
    elseif rank == 2 then
        return 'common/icon_256/icon_baoxiang_sanji_256_01'
    else
        return 'common/icon_256/icon_baoxiang_erji_256_01'
    end
end

function UBFUESlpBottomWinRepeatRank:finishAnim()
    if not self:isViewSafe() then return end
    if self.scrollView and not self.scrollView.isDisposed then
        self.scrollView:setScrollEnabled(true)
    end
    self.animFinished = true
end

function UBFUESlpBottomWinRepeatRank:onPrepareItemDcContext(context)
end

function UBFUESlpBottomWinRepeatRank:onCreateProxy(exposeMethodList)
    UBFSlpPlpViewLogic.onCreateProxy(self, exposeMethodList)

    table.insert(exposeMethodList, "onPrepareItemDcContext")
end

-- debug
function UBFUESlpBottomWinRepeatRank:popout(slpBottomData)
    local uiMgr = UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
    if uiMgr:existNode(WinRepeatRank2023NodeId.UE_SLP_BOTTOM) then
        uiMgr:callNode(WinRepeatRank2023NodeId.UE_SLP_BOTTOM, "exit", true, {
            byOp = true,
        })
    end

    local delegate = uiMgr:newUiUpdateDelegate()
    delegate.nodeConfig:setWhole(WinRepeatRank2023NodeId.UE_SLP_BOTTOM, {
        logicId = WinRepeatRank2023LogicId.UE_SLP_BOTTOM,
        bottomCarouselData = {
            data = slpBottomData,
        },
    })
    delegate:createNodeAsync(WinRepeatRank2023NodeId.UE_SLP_BOTTOM):next(function(node)
        delegate:clear()
    end)
end

return UBFUESlpBottomWinRepeatRank
