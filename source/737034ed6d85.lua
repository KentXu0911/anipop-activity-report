UBFPlpBottomWinRepeatRank = class2("UBFPlpBottomWinRepeatRank", UBFSlpPlpViewLogic)
UBFDebug:monitoringClass(UBFPlpBottomWinRepeatRank)
UBFLogicCreator:registerLogic(WinRepeatRank2023LogicId.PLP_BOTTOM, UBFPlpBottomWinRepeatRank)
local FRAMETIME = 1/30
local UIHelper = UBFViewHelper.migrator.UIHelper
local UIUtils = UBFViewHelper.migrator.UIUtils
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local NumberUtil = require "amf.middleware.ui.util.NumberUtil"
local Meta = require("amf.feature.localactivity.winrepeatrank.meta.WinRepeatRankMeta")
local AsyncRunner = require "amf.script.sugar.AsyncRunner"

function UBFPlpBottomWinRepeatRank.createDefaultCreateData(initParams)
    local createData = UBFSlpPlpViewLogic.createDefaultCreateData(initParams)
    createData.selfView = {
        rawData = {
            type = UBFRawViewCreator.ViewType.kUI,
            lua = "ubf/UBFActivity/actFolder/WinRepeatRank2023/views/UISource/UBFSlpBottomWinRepeatRank_UI.lua",
            position = ccp(0, 1280)
        }
    }

    createData.upDownFxAnimRawData = {
        type = UBFRawViewCreator.ViewType.kSpine,
        json = "ubfRes/ui/mod/WinRepeatRank2023/spine/up_down_fx.skel",
        anchorPoint = ccp(0.5, 0.5),
    }
    createData.extraViews = {
        upDownFxAnim = {
            rawData = createData.upDownFxAnimRawData,
            noCache = true,
            onlyPrepare = true,
        }
    }

    return createData
end

function UBFPlpBottomWinRepeatRank:onViewCreate()
    UBFSlpPlpViewLogic.onViewCreate(self)
    self:initData()
    self:initUI()
end

function UBFPlpBottomWinRepeatRank:onPlayEnterTransition(finishImmediately)
    local promise = UBFPromise:create()
    self:startAnim()
    promise:resolve()

    return promise
end

function UBFPlpBottomWinRepeatRank:getPlpBottomData()
    return self.createData.plpBottomData
end

function UBFPlpBottomWinRepeatRank:initData()
    local plpBottomData = self:getPlpBottomData()
    local eventDataInfo = plpBottomData.eventDataInfo
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
    self.playerList = eventDataInfo.activityGroupCommonList.rankList
    self.eventDataInfo = eventDataInfo
end

function UBFPlpBottomWinRepeatRank:initUI()
    self:initContent()
end

function UBFPlpBottomWinRepeatRank:initContent()
    self.nodeList = {}
    self.myNode = nil
    local contentLayer = UBFLayer:create()
    for i, info in ipairs(self.playerList) do
        self:createAndAddViewAsync({
            rawData = {
                type = UBFRawViewCreator.ViewType.kUI,
                lua = "ubf/UBFActivity/actFolder/WinRepeatRank2023/views/UISource/UBFSlpBottomWinRepeatRankCell_UI.lua",
            }
        }, "playerCell_" .. i):next(function(node)
            if isSafeCocosObj(node) then
                node.info = table.clone(info)
                self:updatePlayerNode(node, info)
                if info.isMe then
                    self.myNode = node
                end
                contentLayer:addChild(node)
                node:setPositionXY(75 + ((i - 1) * 150), 114)
                table.insert(self.nodeList, node)
            end 
        end)
    end

    local scrollW = math.max(600, #self.playerList * 150)
    local scrollH = 231    
    local viewW = 600
    local viewH = scrollH
    local contentW = viewW
    local paddingTop = 0
    local paddingBottom = 0
    local contentView = contentLayer
    local isDebugMode = false
    -- scroll容器
    local scrollLayer = UBFLayer:create()
    scrollLayer:setAnchorPoint(ccp(0, 0))
    contentLayer:setAnchorPoint(ccp(0, 0))
    scrollLayer:setName("ScrollLayer")
    contentView:setName("contentView")
    scrollLayer:addChild(contentView)
    contentView:setPositionXY(0, 0)
    scrollLayer:setPositionXY(0, -228)
    function scrollLayer:getWidth()
        if scrollLayer.isDisposed then return 0 end
        return contentW
    end

    local HorizontalScrollable = UBFViewHelper:toolkit("HorizontalScrollable")
    local scrollView = HorizontalScrollable:create(viewW, viewH, true, true)
    scrollView:setName("ScrollView")
    scrollView:setIgnoreHorizontalMove(true)
    scrollView:setContent(scrollLayer)
    scrollView:setScrollableWidth(scrollW)
    function scrollView:containsPoint(worldPos)
        if scrollView.isDisposed then return false end
        local relaPos = scrollView:convertToNodeSpace(worldPos)
        local contains = relaPos.x >= 0
            and relaPos.x <= scrollView.width
            and relaPos.y <= 0
            and relaPos.y >= -scrollView.height
        return contains
    end
    if isDebugMode then
        scrollLayer:setOpacity(255)
    end
    scrollView:setPositionXY(60, 300)
    self.scrollView = scrollView

    self:getView():addChild(scrollView)
    local offset = self:getScrollLabelOffsetByRank(self.hasRankUp and self.lastRank or self.myRank, true)
	scrollView:gotoPositionX(offset, 0)
    scrollView:setScrollEnabled(false)
end

-- 播动画前我位于视野右侧 播动画后我位于视野左侧
function UBFPlpBottomWinRepeatRank:getScrollLabelOffsetByRank(rank, beforeAnim)
    if beforeAnim then
        return self.scrollView.width - 150 * rank
    else
        return -150 * (rank - 1) - 3
    end
end

function UBFPlpBottomWinRepeatRank:updatePlayerNode(node, info)
    local rank = info.rank
    local isMe = info.isMe
    local score = info.score
    local listItemCenter = node:getChildByName("listItemCenter")
    if not isSafeCocosObj(listItemCenter) then
        return
    end
    local rankPart = listItemCenter:getChildByName("rankPart")
    listItemCenter:getChildByName("listItemBg"):setVisible(not isMe)
    listItemCenter:getChildByName("listItemBg2"):setVisible(isMe)
    listItemCenter:getChildByName("collectPart"):getChildByName("collectPartBg"):setVisible(not isMe)
    listItemCenter:getChildByName("collectPart"):getChildByName("collectPartBg2"):setVisible(isMe)
    listItemCenter:getChildByName("headPart"):getChildByName("headFrame"):setVisible(not isMe)
    listItemCenter:getChildByName("headPart"):getChildByName("headFrame2"):setVisible(isMe)
    local topOther = rankPart:getChildByName("topOther")
    topOther:getChildByName("topOtherBg"):setVisible(not isMe)
    topOther:getChildByName("topOtherBg2"):setVisible(isMe)
    listItemCenter:getChildByName("collectPart"):setVisible(not info.isEmpty)
    listItemCenter:getChildByName("noPoppleTip"):setVisible(info.isEmpty)

    local collectPartScore = listItemCenter:getChildByName("collectPart"):getChildByName("collectPartScore")
    collectPartScore:enableOutline(isMe and hex2ccc4("85450099") or hex2ccc4("85450099"), 2)
    local showScore = tostring(score)
    if score < 100000 then
        showScore = NumberUtil:formatBigNumber(score, 2)
    else
        showScore = NumberUtil:formatBigNumber(score, 1)
    end
    collectPartScore:setString(showScore)

    local function getRandomHeadImage()
        return HeadImageType.k_birth_0
    end
    local headUrl = info.profile and info.profile.headUrl
    if not info.isEmpty and not headUrl then
        headUrl = getRandomHeadImage()
    end
    local head
    local profile = {headUrl = headUrl, uid = info.uid}
    head = HeadImage:create(profile, {
        ignoreHeadFrame = true
    })

    head:setPositionXY(65 / 2, 65 / 2)
    head:setScale(0.65)
    listItemCenter:getChildByName("headPart"):getChildByName("headImageHolder"):removeChildren()
    listItemCenter:getChildByName("headPart"):getChildByName("headImageHolder"):addChild(head)

    for i = 1, 3 do
        rankPart:getChildByName("top" .. i):setVisible(rank == i)
    end
    topOther:setVisible(rank > 3)
    topOther:getChildByName("topOtherLabel"):setString(''..rank)

	local bHasReward = self:checkHasRankRewards(rank)
    local giftBox = listItemCenter:getChildByName("giftBox")
    giftBox:changeDisplayByFrameName(self:getGixtBoxSpriteFrameName(rank))
    giftBox:setVisible(bHasReward)
	UIUtils:setTouchHandler(giftBox, function ( ... )
		if not self:isViewSafe() then return end
		if not self.animFinished then return end
		local info = node.info
		local rank = info.rank
		local bHasReward, rewards, extraRewards = self:checkHasRankRewards(rank)
		if not bHasReward then return end
		local plpBottomData = self:getPlpBottomData()
		local titleStr = string.format( '%s结算时,第%d名可得', plpBottomData.titleName, rank)
		local tipParams = {
			target = giftBox,
			title = titleStr,
			rewards = rewards,
            extraRewards = extraRewards,
		}
        local tipNode = UBFViewHelper:showUITip(tipParams)
	end)
end

function UBFPlpBottomWinRepeatRank:checkHasRankRewards(rank)
    local actMainManager = UBFActHelper:getActMainManager(UBFActivityIdConst.kWinRepeatRank2023)
    local rewards, extraRewards
    if actMainManager then
        rewards, extraRewards = actMainManager:getPlpBottomCellRewardList(self.raceType, rank)
    end
    -- 必须要有rewards
    if table.isEmpty(rewards) then
        return false, {}, nil
    end
    return true, rewards, extraRewards
end

function UBFPlpBottomWinRepeatRank:getGixtBoxSpriteFrameName(rank)
    if self.raceType == Meta.mainPanelShowType.kMainPanel3 then
        if rank == 1 then
            return 'common/icon_256/icon_baoxiang_siji_256_01'
        elseif rank== 2 then 
            return 'common/icon_256/icon_baoxiang_sanji_256_01'
        elseif rank == 3 then
            return 'common/icon_256/icon_baoxiang_yiji_256_01'
        else
            return 'common/icon_256/icon_baoxiang_yiji_256_01'
        end
    else
        if rank == 1 then
            return 'common/icon_256/icon_baoxiang_siji_256_01'
        elseif rank== 2 or rank== 3 then 
            return 'common/icon_256/icon_baoxiang_sanji_256_01'
        elseif rank == 4 or rank== 5 then
            return 'common/icon_256/icon_baoxiang_yiji_256_01'
        else
            return 'common/icon_256/icon_baoxiang_yiji_256_01'
        end
    end
end

function UBFPlpBottomWinRepeatRank:startAnim()
    local asyncRunner = AsyncRunner:create()
	local myNode = self.myNode
    if not isSafeCocosObj(myNode) then
        return
    end
    local listItemCenter = myNode:getChildByName("listItemCenter")
	if myNode and self.hasScoreChange then
		-- 收集物上升
		local label = listItemCenter:getChildByName("collectPart"):getChildByName("collectPartScore")
		asyncRunner:add(function (done)
            if not self:isViewSafe() then 
                safeRunCall(done)
                return 
            end
			label:runAction(UIHelper:sequence{
				CCScaleTo:create(3*FRAMETIME, 1.5, 1.5),
				CCCallFunc:create(done)
			})
		end)
		asyncRunner:add(function ( done )
            if not self:isViewSafe() then 
                safeRunCall(done)
                return 
            end
			ActionUtil:rollingNumber({
				label = label,
				startNumber = self.lastScore,
				endNumber = self.myScore,
				callback = done,
			})
		end)

		asyncRunner:add(function (done)
            if not self:isViewSafe() then 
                safeRunCall(done)
                return 
            end
			local function updateNumber()
				if not self:isViewSafe() then return end
				local showScore = tostring(self.myScore)
				if self.myScore < 100000 then
					showScore = NumberUtil:formatBigNumber(self.myScore, 2)
				else
					showScore = NumberUtil:formatBigNumber(self.myScore, 1)
				end
				label:setString(showScore)
			end
			label:runAction(UIHelper:sequence{
				CCDelayTime:create(10*FRAMETIME),
				CCCallFunc:create(updateNumber),
				CCScaleTo:create(3*FRAMETIME, 1, 1),
				CCCallFunc:create(done)
			})
		end)
	end

	if myNode and self.hasRankChange then
		if self.hasRankUp then
			asyncRunner:add(function (done)
                if not self:isViewSafe() then 
                    safeRunCall(done)
                    return 
                end
				local offset = self:getScrollLabelOffsetByRank(self.myRank, false)
				local curOffset = self.scrollView:getXOffset()
				if offset <= curOffset then return done() end
				local moveTime = 0.75
				self.scrollView:gotoPositionX(offset, moveTime)
				done()
			end)
			asyncRunner:add(function(done)
                if not self:isViewSafe() then 
                    safeRunCall(done)
                    return 
                end
				for i = self.lastRank-1, self.myRank, -1 do
					local node = self.nodeList[i]
					local offset = 150
					if node then
						node:runAction(UIHelper:sequence{
							CCDelayTime:create(2*FRAMETIME*(self.lastRank-i)),
							CCCallFunc:create(function()
								if not self:isViewSafe() then return end
								self:switchNodeRank(node, i+1, i)
							end),						
							CCMoveBy:create(8*FRAMETIME, ccp(offset, 0)),
							CCCallFunc:create(function()
								if not self:isViewSafe() then return end
                                local _listItemCenter = node:getChildByName("listItemCenter")
								local effectHolder = _listItemCenter:getChildByName("effectHolder")
								local anim = self:createAndAddViewAsync({
                                    rawData = self.createData.upDownFxAnimRawData,
                                }, "animCell_" .. i):next(function(node)
									effectHolder:addChild(node)
                                    node:setPositionXY(0, 20)
                                    node:playOnceAndDispose("down")
							    end)
							end)
						})						
					end
				end
				listItemCenter:runAction( UIHelper:sequence{
					CCScaleTo:create(2*FRAMETIME, 0.99, 0.99),
					CCScaleTo:create(3*FRAMETIME, 1.15, 1.15),
					CCScaleTo:create(((self.lastRank - self.myRank)>=4 and 22 or 15)*FRAMETIME, 1.2, 1.2),
					CCScaleTo:create(2*FRAMETIME, 0.96, 0.96),
					CCScaleTo:create(3*FRAMETIME, 1, 1),
					CCCallFunc:create(function()
                        if not self:isViewSafe() then 
                            safeRunCall(done)
                            return 
                        end
						local effectHolder = listItemCenter:getChildByName("effectHolder")
						local anim = self:createAndAddViewAsync({
							rawData = self.createData.upDownFxAnimRawData,
						}, "_animCell_up"):next(function(node)
							effectHolder:addChild(node)
							node:setPositionXY(0, 20)
							node:playOnceAndDispose("up")
						end)
						done()
					end)						
				})

				myNode:runAction(UIHelper:sequence{
					CCDelayTime:create(5*FRAMETIME),
					CCCallFunc:create(function()
						if not self:isViewSafe() then return end
						self:switchNodeRank(myNode, self.myRank, self.lastRank)
					end),
					CCMoveBy:create(((self.lastRank - self.myRank)>=4 and 12 or 8)*FRAMETIME, ccp(150*(self.myRank-self.lastRank), 0)),
				})
			end)
		end
	end

	if myNode and self.oldShowRank ~= 0 and self.oldShowRank < self.myRank and not self.hasRankUp then
		--下降
		asyncRunner:add(function(done)
			if not self:isViewSafe() then 
                safeRunCall(done)
                return 
            end
			setTimeOut(done, 0.5)
		end)

		asyncRunner:add(function(done)
            if not self:isViewSafe() then 
                safeRunCall(done)
                return 
            end
			local anim = self:createAndAddViewAsync({
                rawData = self.createData.upDownFxAnimRawData,
			}, "myNodeanim"):next(function(node)
                local effectHolder = listItemCenter:getChildByName("effectHolder")
                if isSafeCocosObj(effectHolder) then
                    effectHolder:addChild(node)
                    node:setPositionXY(0, 20)
                    node:playOnceAndDispose("down")
                end
			end)
			done()
		end)
	end

	asyncRunner:add(function(done)
        if not self:isViewSafe() then 
            safeRunCall(done)
            return 
        end
		self.scrollView:setScrollEnabled(true)
		self.animFinished = true
		done()
	end)
	asyncRunner:run()
end

function UBFPlpBottomWinRepeatRank:switchNodeRank(node, rank, lastRank)
	local listItemCenter = node:getChildByName("listItemCenter")
	local rankPart = listItemCenter:getChildByName("rankPart")
	local topOther = rankPart:getChildByName("topOther")

	local info = node.info
	info.rank = rank 

	local disapearUseTime = 2*FRAMETIME
	local showUseTime = 3*FRAMETIME
	local allUseTime = disapearUseTime + showUseTime
	if lastRank > 3 and rank > 3 then
		--数字变数字
		local function changeRank()
			--替换排名
			if not self:isViewSafe() then return end
			topOther:getChildByName("topOtherLabel"):setString(''..rank)
		end

		topOther:runAction(UIHelper:sequence{
			ActionUtil:fadeToU3D(topOther, disapearUseTime, 100),
			CCCallFunc:create(changeRank),
			ActionUtil:fadeToU3D(topOther, showUseTime, 255),
		})
	else
		--数字变皇冠
		--旧的消失
		if lastRank > 3 then
			topOther:runAction(UIHelper:sequence{
				ActionUtil:fadeOutU3D(topOther, allUseTime),
			})
		else
			rankPart:getChildByName("top" .. lastRank):runAction(CCFadeOut:create(allUseTime))
		end

		--新的出现
		if rank > 3 then
			topOther:getChildByName("topOtherLabel"):setString(''..rank)
			topOther:runAction(CCFadeIn:create(allUseTime))
			topOther:setVisible(true)
		else
			rankPart:getChildByName("top" .. rank):runAction(CCFadeIn:create(allUseTime))
			rankPart:getChildByName("top" .. rank):setVisible(true)
		end
	end

	--礼盒
	local giftBox = listItemCenter:getChildByName("giftBox")
	local bCurHasBoxShow = giftBox:isVisible() 
	local bHasReward = self:checkHasRankRewards(rank)
	if bCurHasBoxShow then
		local function changeBoxSp()
			--替换礼盒icon
			if not self:isViewSafe() then return end
			if bHasReward then
				giftBox:setVisible(true)
				giftBox:changeDisplayByFrameName( self:getGixtBoxSpriteFrameName(rank) )
			else
				giftBox:setVisible(false)
			end
		end
		--礼盒出现
		giftBox:runAction(UIHelper:sequence{
			ActionUtil:fadeToU3D(giftBox, disapearUseTime,100),
			CCCallFunc:create(changeBoxSp),
			ActionUtil:fadeToU3D(giftBox, showUseTime,255),
		})
	else
		--替换礼盒icon，同时出现
		if bHasReward then
			giftBox:setVisible(true)
			giftBox:setOpacity(0)
			giftBox:changeDisplayByFrameName(self:getGixtBoxSpriteFrameName(rank))
			giftBox:runAction(UIHelper:sequence{
				CCFadeIn:create(allUseTime),
			})
		end
	end
end
