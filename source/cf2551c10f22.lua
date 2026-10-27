local deferred = require "amf.script.sugar.deferred"
local ClickContinue = require "amf.middleware.ui.kit.component.skip.ClickContinue"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local RewardFlyHelper = require "amf.feature.localactivity.processgiftautopopup.RewardFlyHelper"
local UIButton = require "amf.middleware.ui.kit.component.button.UIButton"
local Const = _G.amfBean("CollectCardManager"):getConst()
local FinishAlbumPanel = class("FinishAlbumPanel", AMFBasePanel)

local FRAMETIME = 1/30

function FinishAlbumPanel:getAssetsList()
    local list = {
    }
    if not self.mgr then self.mgr = _G.amfBean("CollectCardManager") end
    local albumIconResource = self.mgr:getAlbumUIResource()
    list = table.union(list, albumIconResource)

    local fx_path = self.mgr:getPeriodConfigByKey("FINISH_ROUND_BANZI")
    table.insert(list, fx_path)

    return list
end

function FinishAlbumPanel:getUIInfo()
    return "amf/feature/localactivity/collectcard/view/uisource/CommonEmptyPanel_UI.lua"
end

function FinishAlbumPanel:init()
    if not self.mgr then self.mgr = _G.amfBean("CollectCardManager") end
    local animLayer = Layer:create()
    self.centerNode:addChild(animLayer)
    self.animLayer = animLayer
end

function FinishAlbumPanel:initDataToUI(roundId, albumId, gotNumThisTime, rewards)
    self.roundId = roundId
    self.albumId = albumId
    self.gotNumThisTime = gotNumThisTime
    self.rewards = rewards
end

function FinishAlbumPanel:playStep1Anim()
    return self:showTitleSpine()
end

function FinishAlbumPanel:playStep2Anim()
    return self:showAlbumNode()
end

function FinishAlbumPanel:playStep3Anim()
    return self:showSubTitleAndRewardBubble()
        :next(function()
            return self:showCollectButton()
        end)
end

function FinishAlbumPanel:playStep4Anim()
    return self:playRewardFlyAnim()
        :next(function()
            self:closePanel()
        end)
end

function FinishAlbumPanel:showTitleSpine()
    local d = deferred.new()
    local fx_path = self.mgr:getPeriodConfigByKey("FINISH_ROUND_BANZI")
    local titleSpine = UICreateUtil:createSpine(fx_path)
    self.animLayer:addChild(titleSpine)
    if self.roundId == 1 then
        titleSpine:setAttachment("er", nil)
    elseif self.roundId == 2 then
        titleSpine:setAttachment("er", "er")
    elseif self.roundId == 3 then
        titleSpine:setAttachment("er", "san")
    else
        titleSpine:setAttachment("er", "wujin")
    end

    titleSpine:setAttachment("wc12", nil)
    titleSpine:playOnce("in")
    self.mgr:playEffect(Const.Sound.ALBUM_FINISH_SHOW)
    setTimeOut(function()
        if self.isDisposed then return end
        self.mgr:playEffect(Const.Sound.ALBUM_TITLE_DOWN)
        self.mgr:playHaptics(Const.Haptics.CARD_DROP)
    end, 10*FRAMETIME)

    setTimeOut(function()
        if self.isDisposed then return end
        d:resolve()
    end, 32*FRAMETIME)
    titleSpine:setPositionXY(0, 20)
    self.titleSpine = titleSpine
    return d
end

function FinishAlbumPanel:showClickContinue(clickCallback)
    self.clickContinue = ClickContinue.Builder.new()
        :setTarget(Director:sharedDirector():getRunningSceneLua())
        :setText("点击任意处继续")
        :setClickCallback(clickCallback)
        :build()
    self.clickContinue:showOnScene(SceneLayerShowKey.TOP_LAYER)
end

function FinishAlbumPanel:hideClickContinue()
    if self.clickContinue and not self.clickContinue.isDisposed then
        self.clickContinue:close()
        self.clickContinue = nil
    end
end

function FinishAlbumPanel:showAlbumNode()
    local albumData = self.mgr:cloneAlbumData(self.albumId)
    local albumUI = self.mgr:createAlbumCellUI(albumData)
    albumUI:updateProgressUI(albumData:getCardsCount()-self.gotNumThisTime, albumData:getCardsCount())
    albumUI:setPositionXY(0, 0)
    albumUI:setScale(1.2)
    albumUI:setNoNewTag()
    local albumNode = Node:create()
    albumNode:setAnchorPoint(ccp(0.5, 0.5))
    albumNode:setContentSize(CCSizeMake(212, 268))
    albumNode:addChild(albumUI)
    self.animLayer:addChild(albumNode)

    albumNode:setScale(0.5)
    albumNode:setPositionXY(-15, 40)
    self.mgr:playEffect(Const.Sound.ALBUM_NODE_SHOW)
    local AsyncRunner = require "amf.script.sugar.AsyncRunner"
    local asyncRunner = AsyncRunner:create()
    asyncRunner:add(function(done)
        if self.isDisposed then return end
        albumNode:runAction(ActionUtil:sequence{
            CCScaleTo:create(4*FRAMETIME, 1.05),
            CCScaleTo:create(4*FRAMETIME, 1),
            CCCallFunc:create(done),
        })
    end)

    asyncRunner:add(function(done)
        if self.isDisposed then return end
        local maxCount = albumData:getCardsCount()
        albumUI:playAddProgressFullAnim(maxCount, done)
        self.mgr:playEffect(Const.Sound.ALBUM_PROGRESS_UP)
    end)

    asyncRunner:add(function(done)
        if self.isDisposed then return end
        albumNode:runAction(ActionUtil:sequence{
            CCMoveBy:create(5*FRAMETIME, ccp(0, -20)),
            CCMoveBy:create(5*FRAMETIME, ccp(0, 280)),
            CCCallFunc:create(done),
            CCMoveBy:create(5*FRAMETIME, ccp(0, -15)),
        })
    end)

    local d = deferred.new()
    asyncRunner:add(function(done)
        if self.isDisposed then return end
        d:resolve()
    end)

    asyncRunner:run()

    return d
end

function FinishAlbumPanel:showSubTitleAndRewardBubble()
    return deferred.success()
            :next(function()
                return self:_showSubTitle()
            end)
            :next(function()
                return self:_showRewardBubble()
            end)
end

function FinishAlbumPanel:_showSubTitle()
    local d = deferred.new()
    local text = "收集完成！获得以下奖励！"
    local subTitle = TTFLabel:createAnimalYH(text, 30)
    subTitle:setAnchorPoint(ccp(0.5, 0.5))
    subTitle:enableOutline(ccc4(141, 51, 51, 255), 2)
    subTitle:enableShadow(ccc4(41, 1, 1, 61), ccp(0, -2))
    subTitle:setGradientColors(ccc4(253, 253, 79, 255), ccc4(253, 171, 13, 255))
    self.animLayer:addChild(subTitle)
    subTitle:setPositionXY(0, 0)
    subTitle:setOpacity(0)
    subTitle:runAction(CCSequence:createWithTwoActions(
        CCFadeIn:create(2*FRAMETIME),
        CCCallFunc:create(function()
            d:resolve()
        end)
    ))
    return d
end

function FinishAlbumPanel:_showRewardBubble()
    local Bubble = require "amf.middleware.ui.kit.component.Bubble"
    local rewardLayer = Layer:create()
    self.animLayer:addChild(rewardLayer)
    rewardLayer:setPosition(ccp(0, -150))
    local bubbleList = {}
    local nodeInfos = {}
    for i, v in ipairs(self.rewards) do
        local bubble = Bubble.Builder.new()
            :setReward(v)
            :build()
        bubble:setAutoGroupOpacity(true)
        rewardLayer:addChild(bubble)
        table.insert(bubbleList, bubble)
        local bubbleWidth = bubble:getContentSize().width
        table.insert(nodeInfos, {node = bubble, width = 188})
        ActionUtil:setOpacityU3D(bubble, 0)
        bubble:setScale(0.5)
    end
    LayoutUtil.sortNodes(nodeInfos)
    local d = deferred.new()
    for i, bubble in ipairs(bubbleList) do
        local delay = (i-1) * 3 * FRAMETIME
        bubble:runAction(ActionUtil:sequence{
            CCDelayTime:create(delay),
            CCCallFunc:create(function()
                if self.isDisposed then return end
                self.mgr:playEffect(Const.Sound.ALBUM_SHOW_REWARD)
            end),
            ActionUtil:spawn{
                ActionUtil:fadeInU3D(bubble, FRAMETIME),
                ActionUtil:sequence{
                    CCScaleTo:create(5*FRAMETIME, 1.05),
                    CCScaleTo:create(5*FRAMETIME, 1),
                    CCCallFunc:create(function()
                        printx(33, "reward bubble show anim end, index:", i)
                        d:resolve()
                    end)
                }
            }
        })
    end
    self.bubbleList = bubbleList
    return d
end

function FinishAlbumPanel:showCollectButton()
    local d = deferred.new()
    local btn = UIButton:createButton({
        str = "收下",
        touchFunc = function()
            local Const = self.mgr:getConst()
            self.mgr:playEffect(Const.Sound.CLICK_COMMON_01)
            self.mgr:playHaptics(Const.Haptics.BUTTON_NORMAL)
            d:resolve()
        end
    })
    btn:playShowAnim()
    self.animLayer:addChild(btn)
    btn:setPosition(ccp(0, -420))
    return d
end

function FinishAlbumPanel:playRewardFlyAnim()
    local d = deferred.new()
    if table.isEmpty(self.bubbleList) then
        d:resolve()
        return d
    end

    local needFlyNum = 0
    for i, reward in ipairs(self.rewards) do
        if not reward.doNotFly then
            needFlyNum = needFlyNum + 1
        end
    end


    local function onFlyEnd()
        needFlyNum = needFlyNum - 1
        if needFlyNum <= 0 then
            d:resolve()
        end
    end

    if needFlyNum == 0 then
        d:resolve()
        return d
    end

    for i, bubble in ipairs(self.bubbleList) do
        local reward = self.rewards[i]
        local worldPos = bubble:getPositionInWorldSpace()
        bubble:playHideAnim(function()
            if self.isDisposed then return end
            bubble:setVisible(false)
            local flyContext = FlyItemContext.new({
                {itemId = reward.itemId, num = reward.num}
            }, worldPos)
            :setFinishCallback(onFlyEnd)
            _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)
        end, nil, true, 0.1)
    end

    return d
end

function FinishAlbumPanel:closePanel()
    self:sendCommand("onCloseBtnTapped")
end

function FinishAlbumPanel:recycle()
    self:hideClickContinue()
    AMFBasePanel.recycle(self)
end

return FinishAlbumPanel