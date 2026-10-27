UBFUEPlpBottomWinRepeatRank = class2("UBFUEPlpBottomWinRepeatRank", UBFSlpPlpViewLogic)
UBFDebug:monitoringClass(UBFUEPlpBottomWinRepeatRank)
UBFLogicCreator:registerLogic(WinRepeatRank2023LogicId.UE_PLP_BOTTOM, UBFUEPlpBottomWinRepeatRank)

local FRAMETIME = 1 / 30
local CELL_WIDTH = 150
local CELL_CENTER_X = 75
local CELL_CENTER_Y = 112
local VIEW_WIDTH = 600
local VIEW_HEIGHT = 231
local SCROLL_VIEW_HEIGHT = 300
local SCROLL_VIEW_POSITION_Y = VIEW_HEIGHT + (SCROLL_VIEW_HEIGHT - VIEW_HEIGHT) * 0.5
local GIFT_BOX_ICON_SIZE = 256
local RANK_SCROLL_MOVE_TIME = 0.5
local OTHER_CELL_MOVE_TIME = 6 * FRAMETIME
local MY_CELL_FAST_MOVE_TIME = 6 * FRAMETIME
local MY_CELL_LONG_MOVE_TIME = 9 * FRAMETIME
local HEAD_IMAGE_SCALE = 0.65
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local NumberUtil = require "amf.middleware.ui.util.NumberUtil"
local deferred = require "amf.script.sugar.deferred"
local Meta = require("amf.feature.localactivity.winrepeatrank.meta.WinRepeatRankMeta")

local function _getPlpBottomData(bottomCarouselData)
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

function UBFUEPlpBottomWinRepeatRank.createDefaultCreateData(initParams)
    local createData = UBFSlpPlpViewLogic.createDefaultCreateData(initParams)
    createData.selfView = {
        viewType = UBFUiViewType.UI,
        lua = "ubf/UBFActivity/actFolder/WinRepeatRank2023/views/UISource/UBFUEBottomWinRepeatRank_UI.lua",
        position = {x = 0, y = 0},
    }

    createData.upDownFxAnim = {
        viewType = UBFUiViewType.SPINE,
        skel = "ubfRes/ui/mod/WinRepeatRank2023/spine/up_down_fx.skel",
        anchorPoint = {x = 0.5, y = 0.5},
    }
    createData.extraViews = {
        upDownFxAnim = {
            viewType = UBFUiViewType.SPINE,
            skel = createData.upDownFxAnim.skel,
            anchorPoint = createData.upDownFxAnim.anchorPoint,
            onlyPrepare = true,
        },
    }

    return createData
end

function UBFUEPlpBottomWinRepeatRank:onViewCreate()
    UBFSlpPlpViewLogic.onViewCreate(self)
    self:initData()
end

function UBFUEPlpBottomWinRepeatRank:onPlayEnterTransition(finishImmediately)
    local promise = UBFPromise:create()
    local start = function()
        if not self:isViewSafe() then
            promise:resolve()
            return
        end
        self:startAnim():next(function()
            promise:resolve()
        end, function()
            promise:resolve()
        end)
    end

    if self.contentReadyPromise then
        self.contentReadyPromise:next(start, start)
    else
        start()
    end

    return promise
end

function UBFUEPlpBottomWinRepeatRank:getPlpBottomData()
    return _getPlpBottomData(self.createData.bottomCarouselData)
end

function UBFUEPlpBottomWinRepeatRank:initData()
    local plpBottomData = self:getPlpBottomData()
    local eventDataInfo = plpBottomData.eventDataInfo
    if eventDataInfo then
        self.raceType = eventDataInfo.raceType
        self.lastRank = eventDataInfo.oldRank
        self.myRank = eventDataInfo.newRank
        self.lastScore = eventDataInfo.oldScore
        self.myScore = eventDataInfo.newScore
        self.oldShowScore = eventDataInfo.oldShowScore
        self.oldShowRank = eventDataInfo.oldShowRank
        self.hasRankUp = self.myRank < self.lastRank
        self.hasRankChange = (self.myRank ~= self.lastRank and self.lastRank ~= 0)
        self.hasScoreChange = self.myScore > self.lastScore
        self.playerList = plpBottomData.rankList
        self.rankRewardMap = plpBottomData.rankRewardMap or {}
        self.eventDataInfo = eventDataInfo
        self:initContent()
    end
end

function UBFUEPlpBottomWinRepeatRank:update(newSlpBottomData)
    self.createData.bottomCarouselData = newSlpBottomData
    self:initData()
end

function UBFUEPlpBottomWinRepeatRank:initContent()
    self.nodeList = {}
    self.myNode = nil

    local contentLayer = UBFLayer:create()
    contentLayer:setAnchorPoint(ccp(0, 0))
    contentLayer:setName("contentView")

    local scrollW = math.max(VIEW_WIDTH, #self.playerList * CELL_WIDTH)
    local scrollLayer = UBFLayer:create()
    scrollLayer:setAnchorPoint(ccp(0, 0))
    scrollLayer:setName("ScrollLayer")
    contentLayer:setPositionXY(0, 0)
    scrollLayer:addChild(contentLayer)
    scrollLayer:setPositionXY(0, -SCROLL_VIEW_POSITION_Y)
    function scrollLayer:getWidth()
        if scrollLayer.isDisposed then return 0 end
        return scrollW
    end

    local HorizontalScrollable = UBFViewHelper:toolkit("HorizontalScrollable")
    local scrollView = HorizontalScrollable:create(VIEW_WIDTH, SCROLL_VIEW_HEIGHT, true, true, -1000, false)
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

    scrollView:setPositionXY(0, SCROLL_VIEW_POSITION_Y)
    self.scrollView = scrollView
    self:addChildView("ScrollView", scrollView, "horizontalContainer")
    self:initScrollViewGiftBoxHitTest(scrollView)

    local promises = {}
    for i, info in ipairs(self.playerList) do
        local cellName = "playerCell_" .. i
        local promise = self:createAndAddViewAsync({
            viewType = UBFUiViewType.UI,
            lua = "ubf/UBFActivity/actFolder/WinRepeatRank2023/views/UISource/UBFUEBottomWinRepeatRankCell_UI.lua",
            autoReference = true,
        }, cellName):next(function(node)
            if not self:isViewSafe() or not isSafeCocosObj(node) then return end
            local cellRoot = UBFLayer:create()
            cellRoot:setAnchorPoint(ccp(0.5, 0.5))
            cellRoot:setName(cellName .. "_Root")
            cellRoot.fields = node.fields
            cellRoot.info = table.clone(info)
            cellRoot.cellName = cellName
            node.info = cellRoot.info
            node.cellName = cellName
            contentLayer:addChild(cellRoot)
            cellRoot:addChild(node)
            cellRoot:setPositionXY((i - 0.5) * CELL_WIDTH, CELL_CENTER_Y)
            node:setPositionXY(-CELL_CENTER_X, -CELL_CENTER_Y)
            self:referenceView(cellName, node, true)
            self:updatePlayerNode(cellRoot, info, cellName)
            if info.isMe then
                self.myNode = cellRoot
            end
            self.nodeList[i] = cellRoot
        end)
        table.insert(promises, promise)
    end

    self.contentReadyPromise = deferred.all(promises):next(function()
        if not self:isViewSafe() then return end
        local offset = self:getScrollLabelOffsetByRank(self.hasRankUp and self.lastRank or self.myRank, true)
        self.scrollView:gotoPositionX(offset, 0)
        self.scrollView:setIgnoreHorizontalMove(false)
    end)
end

function UBFUEPlpBottomWinRepeatRank:initScrollViewGiftBoxHitTest(scrollView)
    if not isSafeCocosObj(scrollView) or not isSafeCocosObj(scrollView.touchLayer) then return end
    scrollView.touchLayer:setGlobalHitTestPoint(function(worldPos)
        return scrollView:containsPoint(worldPos)
    end, false)
end

-- 播动画前我位于视野右侧，播动画后我位于视野左侧
function UBFUEPlpBottomWinRepeatRank:getScrollLabelOffsetByRank(rank, beforeAnim)
    if beforeAnim then
        return self.scrollView.width - CELL_WIDTH * rank
    else
        return -CELL_WIDTH * (rank - 1) - 3
    end
end

function UBFUEPlpBottomWinRepeatRank:getCellRefs(node)
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

function UBFUEPlpBottomWinRepeatRank:getReferencedCellViewName(cellName, node, viewName)
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

function UBFUEPlpBottomWinRepeatRank:updateGiftBoxItemImage(node, rank, rewards)
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

function UBFUEPlpBottomWinRepeatRank:getShowScore(score)
    if score < 100000 then
        return NumberUtil:formatBigNumber(score, 2)
    else
        return NumberUtil:formatBigNumber(score, 1)
    end
end

function UBFUEPlpBottomWinRepeatRank:createHeadData(info, replaceViewName)
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

function UBFUEPlpBottomWinRepeatRank:updatePlayerNode(node, info, cellName)
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

function UBFUEPlpBottomWinRepeatRank:onGiftBoxClick(node, giftBox)
    if not self:isViewSafe() then return end
    if not self.animFinished then return end
    if not isSafeCocosObj(node) or not isSafeCocosObj(giftBox) then return end

    local cellInfo = node.info
    local curRank = cellInfo and cellInfo.rank
    local hasReward, rewards, extraRewards = self:checkHasRankRewards(curRank)
    if not hasReward then return end

    local plpBottomData = self:getPlpBottomData()
    local titleStr = string.format("%s结算时,第%d名可得", plpBottomData.titleName, curRank)
    UBFViewHelper:showUITip({
        target = giftBox,
        title = titleStr,
        rewards = rewards,
        extraRewards = extraRewards,
        disappearSec = 2
    })
end

function UBFUEPlpBottomWinRepeatRank:checkHasRankRewards(rank)
    local rewardInfo = self.rankRewardMap[rank] or self.rankRewardMap[tostring(rank)]
    local rewards = rewardInfo and rewardInfo.rewards or {}
    local extraRewards = rewardInfo and rewardInfo.extraRewards
    local mergeRewards = table.union(rewards, extraRewards)
    if table.isEmpty(mergeRewards) then
        return false, {}, nil
    end
    return true, rewards, extraRewards, mergeRewards
end

function UBFUEPlpBottomWinRepeatRank:getGixtBoxSpriteFrameName(rank)
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

function UBFUEPlpBottomWinRepeatRank:deferAction(target, actions)
    local d = deferred.new()
    if not self:isViewSafe() or not isSafeCocosObj(target) then
        d:resolve()
        return d
    end
    local sequence = {}
    for _, action in ipairs(actions) do
        table.insert(sequence, action)
    end
    table.insert(sequence, CCCallFunc:create(function()
        d:resolve()
    end))
    target:runAction(UBFViewHelper:sequence(sequence))
    return d
end

function UBFUEPlpBottomWinRepeatRank:deferCall(func)
    local d = deferred.new()
    safeRunCall(func, function()
        d:resolve()
    end)
    return d
end

function UBFUEPlpBottomWinRepeatRank:deferDelay(delay)
    local d = deferred.new()
    if not self:isViewSafe() then
        d:resolve()
    else
        setTimeOut(function()
            d:resolve()
        end, delay)
    end
    return d
end

function UBFUEPlpBottomWinRepeatRank:playUpDownFx(parentViewName, viewName, animationName)
    if not parentViewName then return end
    self:createAndAddPreparedViewAsync("upDownFxAnim", viewName, {
        parentViewName = parentViewName,
        position = {x = 0, y = 20},
    }):next(function(node)
        if not self:isViewSafe() or not isSafeCocosObj(node) then return end
        node:playOnceAndDispose(animationName)
    end)
end

function UBFUEPlpBottomWinRepeatRank:startAnim()
    local myNode = self.myNode
    if not isSafeCocosObj(myNode) then
        self:finishAnim()
        return deferred.success()
    end

    local refs = self:getCellRefs(myNode)
    if not refs or not isSafeCocosObj(refs.root) then
        self:finishAnim()
        return deferred.success()
    end

    local flow = deferred.success()
    local function addTask(task)
        flow = flow:next(function()
            if not self:isViewSafe() then return deferred.success() end
            return task()
        end)
    end

    if self.hasScoreChange then
        local label = refs.collectPartScore
        addTask(function()
            return self:deferAction(label, {
                CCScaleTo:create(3 * FRAMETIME, 1.5, 1.5),
            })
        end)
        addTask(function()
            return self:deferCall(function(done)
                if not self:isViewSafe() or not isSafeCocosObj(label) then
                    done()
                    return
                end
                ActionUtil:rollingNumber({
                    label = label,
                    startNumber = self.lastScore,
                    endNumber = self.myScore,
                    callback = done,
                })
            end)
        end)
        addTask(function()
            return self:deferAction(label, {
                CCDelayTime:create(10 * FRAMETIME),
                CCCallFunc:create(function()
                    if not self:isViewSafe() or not isSafeCocosObj(label) then return end
                    label:setString(self:getShowScore(self.myScore))
                end),
                CCScaleTo:create(3 * FRAMETIME, 1, 1),
            })
        end)
    end

    if self.hasRankChange and self.hasRankUp then
        addTask(function()
            return self:deferCall(function(done)
                if not self:isViewSafe() then
                    done()
                    return
                end
                local offset = self:getScrollLabelOffsetByRank(self.myRank, false)
                local curOffset = self.scrollView:getXOffset()
                if offset <= curOffset then
                    done()
                    return
                end
                self.scrollView:gotoPositionX(offset, RANK_SCROLL_MOVE_TIME)
                done()
            end)
        end)
        addTask(function()
            return self:deferCall(function(done)
                if not self:isViewSafe() then
                    done()
                    return
                end
                for i = self.lastRank - 1, self.myRank, -1 do
                    local node = self.nodeList[i]
                    local effectHolderViewName = self:getReferencedCellViewName(node and node.cellName, node, "effectHolder")
                    if isSafeCocosObj(node) and effectHolderViewName then
                        node:runAction(UBFViewHelper:sequence({
                            CCDelayTime:create(2 * FRAMETIME * (self.lastRank - i)),
                            CCCallFunc:create(function()
                                if not self:isViewSafe() then return end
                                self:switchNodeRank(node, i + 1, i)
                            end),
                            CCMoveBy:create(OTHER_CELL_MOVE_TIME, ccp(CELL_WIDTH, 0)),
                            CCCallFunc:create(function()
                                if not self:isViewSafe() then return end
                                self:playUpDownFx(effectHolderViewName, "animCell_" .. i, "down")
                            end),
                        }))
                    end
                end

                refs.root:runAction(UBFViewHelper:sequence({
                    CCScaleTo:create(2 * FRAMETIME, 0.99, 0.99),
                    CCScaleTo:create(3 * FRAMETIME, 1.15, 1.15),
                    CCScaleTo:create(((self.lastRank - self.myRank) >= 4 and 22 or 15) * FRAMETIME, 1.2, 1.2),
                    CCScaleTo:create(2 * FRAMETIME, 0.96, 0.96),
                    CCScaleTo:create(3 * FRAMETIME, 1, 1),
                    CCCallFunc:create(function()
                        if self:isViewSafe() then
                            local effectHolderViewName = self:getReferencedCellViewName(myNode.cellName, myNode, "effectHolder")
                            self:playUpDownFx(effectHolderViewName, "_animCell_up", "up")
                        end
                        done()
                    end),
                }))

                myNode:runAction(UBFViewHelper:sequence({
                    CCDelayTime:create(5 * FRAMETIME),
                    CCCallFunc:create(function()
                        if not self:isViewSafe() then return end
                        self:switchNodeRank(myNode, self.myRank, self.lastRank)
                    end),
                    CCMoveBy:create(((self.lastRank - self.myRank) >= 4 and MY_CELL_LONG_MOVE_TIME or MY_CELL_FAST_MOVE_TIME), ccp(CELL_WIDTH * (self.myRank - self.lastRank), 0)),
                }))
            end)
        end)
    end

    if self.oldShowRank ~= 0 and self.oldShowRank < self.myRank and not self.hasRankUp then
        addTask(function()
            return self:deferDelay(0.5)
        end)
        addTask(function()
            return self:deferCall(function(done)
                if self:isViewSafe() then
                    local effectHolderViewName = self:getReferencedCellViewName(myNode.cellName, myNode, "effectHolder")
                    self:playUpDownFx(effectHolderViewName, "myNodeanim", "down")
                end
                done()
            end)
        end)
    end

    return flow:next(function()
        self:finishAnim()
    end)
end

function UBFUEPlpBottomWinRepeatRank:finishAnim()
    if not self:isViewSafe() then return end
    if self.scrollView and not self.scrollView.isDisposed then
        self.scrollView:setIgnoreHorizontalMove(true)
        self.scrollView:setScrollEnabled(true)
    end
    self.animFinished = true
end

function UBFUEPlpBottomWinRepeatRank:switchNodeRank(node, rank, lastRank)
    local refs = self:getCellRefs(node)
    if not refs or not isSafeCocosObj(refs.rankPart) then return end

    local info = node.info
    info.rank = rank

    local disapearUseTime = 2 * FRAMETIME
    local showUseTime = 3 * FRAMETIME
    local allUseTime = disapearUseTime + showUseTime
    if lastRank > 3 and rank > 3 then
        refs.topOther:runAction(UBFViewHelper:sequence({
            ActionUtil:fadeToU3D(refs.topOther, disapearUseTime, 100),
            CCCallFunc:create(function()
                if not self:isViewSafe() then return end
                refs.topOtherLabel:setString("" .. rank)
            end),
            ActionUtil:fadeToU3D(refs.topOther, showUseTime, 255),
        }))
    else
        if lastRank > 3 then
            refs.topOther:runAction(UBFViewHelper:sequence({
                ActionUtil:fadeOutU3D(refs.topOther, allUseTime),
            }))
        else
            local oldTop = refs["top" .. lastRank]
            if isSafeCocosObj(oldTop) then
                oldTop:runAction(CCFadeOut:create(allUseTime))
            end
        end

        if rank > 3 then
            refs.topOtherLabel:setString("" .. rank)
            refs.topOther:runAction(CCFadeIn:create(allUseTime))
            refs.topOther:setVisible(true)
        else
            local newTop = refs["top" .. rank]
            if isSafeCocosObj(newTop) then
                newTop:runAction(CCFadeIn:create(allUseTime))
                newTop:setVisible(true)
            end
        end
    end

    local giftBox = refs.giftBox
    local bCurHasBoxShow = giftBox:isVisible()
    local bHasReward, rewards, extraRewards, mergeRewards = self:checkHasRankRewards(rank)
    if bCurHasBoxShow then
        giftBox:runAction(UBFViewHelper:sequence({
            ActionUtil:fadeToU3D(giftBox, disapearUseTime, 100),
            CCCallFunc:create(function()
                if not self:isViewSafe() then return end
                if bHasReward then
                    self:updateGiftBoxItemImage(node, rank, mergeRewards)
                    giftBox:setVisible(true)
                else
                    giftBox:setVisible(false)
                end
            end),
            ActionUtil:fadeToU3D(giftBox, showUseTime, 255),
        }))
    elseif bHasReward then
        giftBox:setVisible(true)
        giftBox:setOpacity(0)
        self:updateGiftBoxItemImage(node, rank, mergeRewards)
        giftBox:runAction(UBFViewHelper:sequence({
            CCFadeIn:create(allUseTime),
        }))
    end
end

function UBFUEPlpBottomWinRepeatRank:onPrepareItemDcContext(context)
end

function UBFUEPlpBottomWinRepeatRank:onCreateProxy(exposeMethodList)
    UBFSlpPlpViewLogic.onCreateProxy(self, exposeMethodList)

    table.insert(exposeMethodList, "onPrepareItemDcContext")
end

-- debug
function UBFUEPlpBottomWinRepeatRank:popout(plpBottomData)
    local uiMgr = UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
    if uiMgr:existNode(WinRepeatRank2023NodeId.UE_PLP_BOTTOM) then
        uiMgr:callNode(WinRepeatRank2023NodeId.UE_PLP_BOTTOM, "exit", true, {
            byOp = true,
        })
    end

    local delegate = uiMgr:newUiUpdateDelegate()
    delegate.viewLogicConfig:setDefaultInitParams({
        plpBottomData = plpBottomData,
    })
    delegate.nodeConfig:setWhole(WinRepeatRank2023NodeId.UE_PLP_BOTTOM, {
        logicId = WinRepeatRank2023LogicId.UE_PLP_BOTTOM,
        plpBottomData = plpBottomData,
    })
    delegate:createNodeAsync(WinRepeatRank2023NodeId.UE_PLP_BOTTOM):next(function(node)
        delegate:clear()
    end)
end

return UBFUEPlpBottomWinRepeatRank
