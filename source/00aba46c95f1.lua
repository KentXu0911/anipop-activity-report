local MultiLabel = require "amf.middleware.ui.kit.component.multilabel.MultiLabel"
local PreheatPanel = class("TeamCampingPreheatPanel", AMFBasePanel)
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local TeamCampingConst = require "amf.feature.localactivity.teamcamping.const.TeamCampingConst"
local ResConfig = require "amf.feature.localactivity.teamcamping.meta.ResConfig"

PreheatPanel.panelStateMeta = {
    preheat = 1, -- 预热阶段强弹
    first = 2, -- 首次出现的时候强弹
    last = 3, -- 还剩最后时间时候强弹
 }

function PreheatPanel:getAssetsList()
    return ResConfig:getPreheatPanelAssetsList()
end
function PreheatPanel:getUIInfo()
    return ResConfig:getUIPath("PreheatPanel")
end

function PreheatPanel:initData(extra)
    self.extra = extra or {
        score = 0,
     }
    self.panelState = extra.panelState
    self.firstPanelState = extra.panelState
    if extra.score > 9999 then
        self.scoreTex:setString("9999+")
    else
        self.scoreTex:setString(extra.score or 0)
    end
    local mgr = _G.amfBean("TeamCampingManager")
    if mgr then
        if self.panelState == PreheatPanel.panelStateMeta.preheat then
            mgr:saveFlagToLocalByKey("hasOpenPreheat")
        elseif self.panelState == PreheatPanel.panelStateMeta.first then
            mgr:saveFlagToLocalByKey("hasOpenMainPanel")
        elseif self.panelState == PreheatPanel.panelStateMeta.last then
            mgr:saveFlagToLocalByKey("hasOpenRecallPanel", true)
        end

        local buildAllReward = mgr:getData():getConfigByKey("buildAllReward", {})
        local rewards = buildAllReward.rewards
        local plug = mgr:_getPlug("ActSend")
        rewards = plug:replaceFinalRewardsList(rewards)
        local extraRewards = plug:getFinalExtraReward()
        rewards = plug:mergeShowRewards(rewards, extraRewards)
        local rewardList = {}
        local CollectCardConst = require"amf.feature.localactivity.collectcard.config.CollectCardConst"
        local newCardId = CollectCardConst.CardPack_5_itemId
        for k, v in pairs(rewards) do
            if not _G.amfBean("PropManager"):isHeadFrame(v.itemId) and not (v.itemId == newCardId)  then
                table.insert(rewardList, v)
            end
        end
        local cashMinNum, cashMaxNum = mgr:getData():getCashMinMax(buildAllReward.cashRange)
        self.initData1 = {
            maxCash = cashMaxNum,
            rewards = rewardList,
         }
    end

end

function PreheatPanel:initUI()
    local mgr = _G.amfBean("TeamCampingManager")
    self.mianBan = {}
    -- self.mianBan[1]=self.mianBan1
    -- self.mianBan[2]=self.mianBan2
    -- self.mianBan[1]:setVisible(false)
    -- self.mianBan[2]:setVisible(false)
    -- self.mianBan[self:getActState()]:setVisible(true)
    if self.panelState == PreheatPanel.panelStateMeta.last then
        if self.group_286 then
            self.group_286:setVisible(false)
        end
    else
        self:initHeadIcon()
    end

    local mgr = _G.amfBean("TeamCampingManager")
    local headFrameId = TeamCampingConst.headFrameTypeId
    local myProfile = _G.amfBean("ProfileManager"):getProfile()

    -- local profile = ProfileRef.new()
    -- profile.headUrl = myProfile.headUrl
    -- profile.headFrame = headFrameId
    if self.rewardHead then
        local headImage = HeadImage:create({
            headUrl = myProfile.headUrl,
            headFrame = headFrameId,
        })
        LayoutUtil:centerReplaceBy(self.rewardHead, headImage)
        headImage:setRotation(-5)
    end
    -- headImage:findChildByName()
    local mt = MultiLabel:create(CCSizeMake(600, 100))
    mt:setAnchorPoint(ccp(0.5, 0.5))
    mt:setLineVerticalAlignment(kCCVerticalTextAlignmentCenter)
    -- LayoutUtil:centerTextH(mt)
    -- LayoutUtil:centerTextV(mt)
    mt:setVerticalAlignment(kCCVerticalTextAlignmentCenter)
    mt:setHorizontalAlignment(kCCTextAlignmentCenter)
    LayoutUtil:centerAdd(self.TimeClock, mt)
    LayoutUtil:move(self.TimeClock, -280, -57)
    -- self.TimeClock:addChild(mt)
    self.timeLabel = mt
    self.TopBtn:setTouchHandler(function()
        self.hasClick = true
        _G.amfBean("TeamCampingManager"):openDescPanel(function()
        end, not mgr:getFlagFromLocalByKey("DescPanelShow_teamCamping"))
        mgr:saveFlagToLocalByKey("DescPanelShow_teamCamping", nil, true)
    end)
    self:getHandAnim()
    self.handAnim:setVisible(false)
    local ly = LayerColor:createWithColor(ccc3(255, 0, 0))
    ly:setContentSize(CCSizeMake(240, 80))
    ly:setOpacity(0)

    self.NowScore:addChild(ly)
    local panelLayout = ResConfig:getPanelLayout("PreheatPanel")
    local nowScoreOffset = panelLayout.NowScoreOffset or { x = -86, y = -19 }
    LayoutUtil:move(ly, nowScoreOffset.x, nowScoreOffset.y)
    ly:setTouchHandler(function()
        mgr:openEnergyPanel(function(isFail)
        end, {
            from = self.firstPanelState + 1,
         })
    end)

    local power = self.extra.score or 0
    if self.panelState == PreheatPanel.panelStateMeta.preheat then
        self.NowScore:setVisible(false)
    end
    self:_applyThemeTitleText()
    self:onTick()
end

function PreheatPanel:_getThemeTitleText()
    local commonText = ResConfig:getTextConfig().Common or {}
    return commonText.MainTitle or "露营吧！朋友"
end

function PreheatPanel:_applyThemeTitleText()
    local titleText = self:_getThemeTitleText()
    if self.title and not self.title.isDisposed then
        self.title:setString(titleText)
    end
end

function PreheatPanel:initHeadIcon()
    local headImage = self:findChildByName("head1")
    local myProfile = _G.amfBean("ProfileManager"):getProfile()
    self:loadUserHeadIcon(headImage, myProfile)
    -- headImage:findChildByName()
end

function PreheatPanel:loadUserHeadIcon(headIcon, profile)
    if headIcon.isDisposed then
        return
    end

    if headIcon.__ui_helper_headimage then
        headIcon.__ui_helper_headimage:removeFromParentAndCleanup(true)
    end

    -- local image = HeadImageLoader:createWithParams({
    -- 	showAnim = true,
    --     profile = profile,
    --     peakFlag = {canTouch = false},
    -- })

    local image = HeadImage:create({
        headUrl = profile.headUrl,
        headFrame = profile.headFrame,
     })

    image:ignoreAnchorPointForPosition(false)
    image:setAnchorPoint(ccp(0, 0))
    local size = headIcon:getContentSize()
    local scaleX = size.width / image:getContentSize().width * image:getScaleX()
    local scaleY = size.height / image:getContentSize().height * image:getScaleY()
    image:setScaleX(0.65)
    image:setScaleY(0.65)
    image:setPositionX(-10)
    image:setPositionY(-10)
    headIcon:addChild(image)

    headIcon.__ui_helper_headimage = image
end

function PreheatPanel:initButtons()
    if self.mainButton.setCallBack then
        self.mainButton:setCallBack(function(...)
            self:onMainButton(...)
        end)
    else
        self.mainButton:setTouchHandler(function(...)
            self:onMainButton(...)
        end)
    end
    -- local closeBtn = UIKit.Create:createCloseButton(function()
    -- 	self:onCloseBtnTapped()
    -- end,1)
    -- LayoutUtil:centerReplaceBy(self.closeBtn, closeBtn)
    -- self.closeBtn = closeBtn
    self.closeBtn:setTouchHandler(function()
        self:sendCommand("close")
    end)
    if self.isDisposed then
        return
    end
    if self.panelState == PreheatPanel.panelStateMeta.preheat then
        self.mainButton:setString("期待")
        self.midTitle2:setVisible(false)
    elseif self.panelState == PreheatPanel.panelStateMeta.first then
        self.mainButton:setString("去看看")
        self.midTitle2:setVisible(false)
        self:showHandAnim()
    else
        self.midTitle1:setVisible(false)
        self.mainButton:setString("冲刺吧")
        self:showHandAnim()
    end
    if self.tipClickArea then
        self.tipClickArea:setTouchHandler(function()
            if self.isDisposed then
                return
            end
            self:showRewardTip(self.initData1)
        end)
    end
end

function PreheatPanel:showHandAnim()
    if self.isDisposed then
        return
    end
    if not isSafeCocosObj(self.mainButton) then
        return
    end
    local array = CCArray:create()
    array:addObject(CCDelayTime:create(2))
    array:addObject(CCCallFunc:create(function()
        if not self.hasClick then
            self.handAnim:setVisible(true)
        end
    end))
    self.mainButton:runAction(CCSequence:create(array))
end

function PreheatPanel:runAction(...)
    AMFBasePanel.runAction(self, ...)
end

function PreheatPanel:onMainButton()
    local mgr = _G.amfBean("TeamCampingManager")
    self.hasClick = true
    if self.isDisposed then
        return
    end
    if self.panelState == PreheatPanel.panelStateMeta.preheat then
        self:sendCommand("close")
    elseif self.panelState == PreheatPanel.panelStateMeta.first then
        if mgr then
            local t1 = 3
            if self.firstPanelState == PreheatPanel.panelStateMeta.preheat then
                t1 = 2
            end
            mgr:openActivity(function()
                self:close()
            end, {
                from = t1,
             }, true)
        end
    elseif self.panelState == PreheatPanel.panelStateMeta.last then
        if mgr then
            mgr:openActivity(function()
                self:close()
            end, {
                from = 4,
             }, true)
        end
    end
end

function PreheatPanel:getHandAnim()
    if not self.handAnim then
        local GuideHand = require "amf.middleware.ui.kit.animation.guide.GuideHand"
        self.handAnim = GuideHand:createHandClick(0, nil, true)
        self.ui:addChild(self.handAnim)
        local pos = self.mainButton:getPosition()
        self.handAnim:setPositionXY(pos.x,pos.y)
        -- LayoutUtil:move(self.handAnim, 400, -1050)
    end
    self.handAnim:setVisible(true)
    return self.handAnim
end

function PreheatPanel:getUpdateInterval()
    return -1
end

function PreheatPanel:getActState()
    if self.panelState == PreheatPanel.panelStateMeta.first or self.panelState == PreheatPanel.panelStateMeta.preheat then
        return 1
    else
        return 2
    end
end

-------------------------- 每秒定时器 --------------------------
function PreheatPanel:onTick()
    if self.isDisposed then
        return
    end
    local input = {
        endTimeInSec = self.extra.endTimeInSec,
     }
    local ret = TimeUtil:timeFormatVer1(input)
    if not self.timeLabel then
        return
    end
    self.timeLabel:clearLines()
    if self.panelState == PreheatPanel.panelStateMeta.preheat then -- 预热阶段
        local retString = ret.retString
        if retString == "" then
            retString = "00:00:00"
        end
        -- if ret.retString ~= "" then
        self.timeLabel:addTTFLabel({
            color = hex2ccc4("FFFFFFFF"),
            outlineSize = 3,
            outlineColor = hex2ccc4("00000033"),
            text = "Ø ",
            fontSize = 33,
            labelType = MultiLabel.LabelType.kNODE,
         })
        self.timeLabel:addTTFLabel({
            color = hex2ccc4("FFFFFFFF"),
            outlineSize = 3,
            outlineColor = hex2ccc4("00000033"),
            text = retString,
            fontSize = 30,
            labelType = MultiLabel.LabelType.kNODE,
            useMonospaceNumber = true,
         })
        self.timeLabel:addTTFLabel({
            color = hex2ccc4("FFFFFFFF"),
            outlineSize = 3,
            outlineColor = hex2ccc4("00000033"),
            text = " 后开启",
            fontSize = 30,
            labelType = MultiLabel.LabelType.kNODE,
         })
    elseif self.panelState == PreheatPanel.panelStateMeta.first then -- 首次进入
        self.timeLabel:addTTFLabel({
            color = hex2ccc4("FFFFFFFF"),
            outlineSize = 3,
            outlineColor = hex2ccc4("00000033"),
            text = "Ø ",
            fontSize = 33,
            labelType = MultiLabel.LabelType.kNODE,
         })
        self.timeLabel:addTTFLabel({
            color = hex2ccc4("FFFFFFFF"),
            outlineSize = 3,
            outlineColor = hex2ccc4("00000033"),
            text = ret.retString,
            fontSize = 30,
            labelType = MultiLabel.LabelType.kNODE,
            useMonospaceNumber = true,
         })
        self.timeLabel:addTTFLabel({
            color = hex2ccc4("FFFFFFFF"),
            outlineSize = 3,
            outlineColor = hex2ccc4("00000033"),
            text = "【活动已开启】",
            fontSize = 30,
            labelType = MultiLabel.LabelType.kNODE,
         })
    else -- 最后了
        self.timeLabel:addTTFLabel({
            color = hex2ccc4("FFFFFFFF"),
            outlineSize = 3,
            outlineColor = hex2ccc4("00000033"),
            text = "还有",
            fontSize = 30,
            labelType = MultiLabel.LabelType.kNODE,
         })
        self.timeLabel:addTTFLabel({
            color = hex2ccc4("FFFFFFFF"),
            outlineSize = 3,
            outlineColor = hex2ccc4("00000033"),
            text = ret.retString,
            fontSize = 30,
            labelType = MultiLabel.LabelType.kNODE,
            useMonospaceNumber = true,
         })
    end
end

function PreheatPanel:showRewardTip(initData)
    if not self.rewardTip then
        local uIData = require "amf.feature.localactivity.teamcamping.views.uisource.RewardTip_UI"
        local ui = {}
        local builder = UIBuilder.new(uIData)
        local node, _ = builder:buildUIWithData(ui)
        self.rewardTip = node
        self.ui:addChild(self.rewardTip)
        self.rewardTip:setAnchorPoint(ccp(0.5, 0))
        self.rewardTip:setPositionInWorldSpace(ccp(360, 480))
        self.rewardTip:setScaleY(0)

        local function playCloseTween(self, callback)
            local baseScale = self.params.uiTipScale or 1
            local frameTime = 1 / 30
            local spawnList = CCArray:create()
            spawnList:addObject(CCScaleTo:create(frameTime * 2, 0.9 * baseScale, 0.9 * baseScale))
            spawnList:addObject(ActionUtil:fadeOut(self, 2 / 30))
            self:runAction(ActionUtil:sequence{ CCScaleTo:create(frameTime * 2, 1.05 * baseScale, 1.05 * baseScale), CCSpawn:create(spawnList),
                                                CCCallFunc:create(callback) })
        end

        self.rewardTip:setTouchHandler(function(evt)
            local worldPos = evt.globalPosition
            if not node:hitTestPoint(worldPos, true) then
                playCloseTween(self.rewardTip, function()
                    self.rewardTip:setVisible(false)
                    self.isShowRewardTip = false
                end)

                -- Tween.to(self.rewardTip,3/30,{
                --     fAlpha = 0,
                --     y = self.rewardTip:getPositionY() - 50,
                --     onComplete = function()
                --         self.rewardTip:setVisible(false)
                --         self.isShowRewardTip = false
                --     end
                -- })
            end
        end, nil, function(worldPos)
            return not node:hitTestPoint(worldPos, true)
        end)

        ui.group_288:setTouchHandler(function()
        end)

        local maxCash = initData.maxCash
        local rewardText = ResConfig:getTextConfig().Reward or {}
        local xSign = _G.YH_REF_MAP.x or "x"
        local tipFormat = rewardText.TipTopCash or "最多可得 <<x>>%d，\n更有露营专属限定头像框等你来拿！"
        tipFormat = string.gsub(tipFormat, "<<x>>", xSign)
        ui.topCashLabel:setString(string.format(tipFormat, initData.maxCash))
        ui.maxCashLabel:setString("最高     " .. initData.maxCash)
        ui.uEPropIcon_13:setPositionX(5)

        local rewards = initData.rewards
        -- tipkuang_9s: AnchorX=0, PositionX=-263.636, Width=535
        -- rewardList: AnchorX=0, PositionX=-214.636
        -- tipkuang_9s center relative to rewardList origin:
        --   (-263.636 + 535/2) - (-214.636) = 3.864 - (-214.636) = 218.5
        local tipkuangCenterX = 218.5
        local iconSpacing = 95
        local iconOffsetY = -30
        local rowHeight = 100

        for k, v in pairs(rewards) do
            local reward = table.clone(v)
            reward.needNum = true
            local icon = GameItemCreator:getPropIcon(reward)
            if icon.innerIcon and icon.innerIcon.numWidget then
                icon.innerIcon.numWidget:enableOutline(hex2ccc4("a153b9ff"), 2)
            elseif icon.numWidget then
                icon.numWidget:enableOutline(hex2ccc4("a153b9ff"), 2)
            end
            ui.rewardList:addChild(icon)

            local col = (k - 1) % 5
            local row = math.floor((k - 1) / 5)

            -- 计算本行的 icon 数量，用于居中
            local totalRows = math.ceil(#rewards / 5)
            local countInRow
            if row < totalRows - 1 then
                countInRow = 5
            else
                countInRow = #rewards - (totalRows - 1) * 5
            end

            -- 本行第一个 icon 的起始 x，使整行相对 tipkuang_9s 居中
            local rowStartX = tipkuangCenterX - (countInRow * iconSpacing) / 2 + iconSpacing / 2
            local x = rowStartX + col * iconSpacing
            local y = row * -rowHeight + iconOffsetY

            icon:setScale(0.7)
            icon:setPositionXY(x, y)
        end

        if #rewards <= 5 then
            local height = 563
            ui.tipkuang_9s:setContentSize(CCSizeMake(535, height * 0.82))
            ui.sprite_129:setPositionY(-558 + height * 0.18)
        end

        local locationHeadFrameId = TeamCampingConst.headFrameTypeId + 60000
        local profile = _G.amfBean("ProfileManager"):getProfile()
        local headImage = GameItemCreator:createCustomHeadFrameAndImage(locationHeadFrameId, false, true , profile)
        headImage:setAnchorPoint(ccp(0.5, 0.5))
        LayoutUtil:replaceBy(ui.headFrame, headImage)
        LayoutUtil:move(headImage, 63, -60)

        -- if self.model:getMgr():isHeadframeLowVersion() then
        --     LayoutUtil:move(headImage,-48,48)
        -- end
        LayoutUtil:move(ui.topTextNode, 10, 0)

    end

    self.rewardTip.params = {}
    if not self.isShowRewardTip then
        self.rewardTip:setVisible(true)
        self.isShowRewardTip = true
        if EnvUtil:isUnity() then
            UICreateUtil:setOpacity(self.rewardTip,255)
        end
        UITip.runAppearAnim(self.rewardTip)
    else
    end

end

return PreheatPanel
