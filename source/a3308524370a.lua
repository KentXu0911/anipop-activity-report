UBFWinningActsBannerView = class2("UBFWinningActsBannerView", UBFUiViewLogic)
UBFLogicCreator:registerLogic(WinningActsBannerLogicId.MAIN, UBFWinningActsBannerView)
UBFDebug:monitoringClass(UBFWinningActsBannerView)
local RES_DIR_PATH = "ubf/UBFGamePlayScene/logics/sceneModules/gameMod/modFolder/WinningActsBanner/views/UISource/"
local FRAME_TIME = 1 / 30
local UIHelper = UBFViewHelper.migrator.UIHelper
local UIUtils = UBFViewHelper.migrator.UIUtils
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local Meta = require("amf.feature.localactivity.winrepeatrank.meta.WinRepeatRankMeta")
local AsyncRunner = require "amf.script.sugar.AsyncRunner"

function UBFWinningActsBannerView.prepareCreateData(createData, uiCreateDelegate)
    local bannerData = createData.bannerData
    local viewConfig = UBFWinningActsBannerViewConfig[bannerData.bannerType]
    createData.selfView = {
        viewType = UBFUiViewType.UI,
        lua = RES_DIR_PATH .. "UBFWinningActsBanner_UI.lua",
        position = {x = 0, y = 0},
    }   
    createData.popoutParams = {
        sharedDarkLayer = true,
    }
    createData.extraViews = {
        flyRewardLayer = {
            viewType = UBFUiViewType.NODE,
            addToSelf = true,
            z = 200
        },
        extraRewardNode = {
            viewType = UBFUiViewType.UI,
            lua = RES_DIR_PATH .. "extraRewardsTip_UI.lua",
            position = {x = 20, y = 70},
            z = 10,
            onlyPrepare = true
        },
        trophyEffect = {
            viewType = UBFUiViewType.SPINE,
            skel = "ubfRes/ui/mod/WinningActsBanner/spine/texiao.skel",
            onlyPrepare = true
        },
        boxAnim = {
            viewType = UBFUiViewType.SPINE,
            skel = "ubfRes/ui/mod/WinningActsBanner/spine/baoxiang.skel",
            onlyPrepare = true
        },
        boxProgressIdleAnim = {
            viewType = UBFUiViewType.SPINE,
            skel = "ubfRes/ui/mod/WinningActsBanner/spine/bj_tx.skel",
            onlyPrepare = true
        },
        boxProgressOpenAnim = {
            viewType = UBFUiViewType.SPINE,
            skel = "ubfRes/ui/mod/WinningActsBanner/spine/bj.skel",
            onlyPrepare = true
        },
        rewardNumAnim = {
            viewType = UBFUiViewType.SPINE,
            skel = "ubfRes/ui/mod/WinningActsBanner/spine/shuzi_tx.skel",
            onlyPrepare = true
        },
    }

    for k, v in pairs(viewConfig) do
        createData.extraViews[k] = v
    end
    
    for i = 1, 5, 1 do
        createData.extraViews["trophy_" .. i] = {
            viewType = UBFUiViewType.SPINE,
            skel = "ubfRes/ui/mod/WinningActsBanner/spine/jiangbei.skel",
            z = 1,
        }
    end

    return createData
end

function UBFWinningActsBannerView:onViewCreate()
    UBFUiViewLogic.onViewCreate(self)
    self:initData()
    self:refExtraViews()
    self:initUI()
end

function UBFWinningActsBannerView:initData()
    local bannerData = self.createData.bannerData
    local winRepeatRankPlpData = self.createData.bannerData.winRepeatRankPlpData
    self.bannerType = bannerData.bannerType
    self.curWinNum = bannerData.curWinNum
    self.collectionRate = winRepeatRankPlpData and winRepeatRankPlpData.collectionRate or 1
    self.winRankRewards = winRepeatRankPlpData and winRepeatRankPlpData.winRankRewards or {}
    self.baseScores = winRepeatRankPlpData and winRepeatRankPlpData.baseScores or {1, 5, 25, 75, 150}
    self.extraRewards = bannerData.extraRewards or {}
    self.boxReward = bannerData.boxReward or {}
    self.curBoxWinProgress = bannerData.curBoxWinProgress
    self.boxTotalWinProgress = bannerData.boxTotalWinProgress
    self.lastWinNum = math.max(0, self.curWinNum - 1)
    self.rewardData = {}
    self.trophyExtraRewardViewData = {}

    self:initRewardData()
end

function UBFWinningActsBannerView:initRewardData()
    -- 额外连胜奖励
    local winNum = math.clamp(self.curWinNum, 1, 5)
    for k, v in pairs(self.extraRewards) do
        if not v.streakWinNum then
            v.streakWinNum = self.curWinNum 
        end
        if v.streakWinNum == self.curWinNum then
            table.insert(self.rewardData, v)
        end
    end

    -- 飞连胜排行榜奖杯
    if self:isWinRankTypeUI() then
        for k, v in pairs(self.winRankRewards) do
            table.insert(self.rewardData, v)
        end
    end

    self.rewardData = self:mergeRewards(self.rewardData)
end

function UBFWinningActsBannerView:refExtraViews()
    local viewConfig = UBFWinningActsBannerViewConfig[self.bannerType]
    for k, v in pairs(viewConfig) do
        self:referenceView(k, self:getView(k), true)
    end
end

-------------------------------初始状态-----------------------------
function UBFWinningActsBannerView:initUI()
    self:initTitle()
    self:initBannerSkin()
    self:initTrophyAnimate()
    self:initTrophyEffect()
    self:initBallAnimate()
    self:initWinRankView()
    self:initWinBoxView()
    self:initRewardView()
    self:refreshProgressBar(self.lastWinNum)
end

function UBFWinningActsBannerView:initTitle()
    local winNum = math.clamp(self.curWinNum, 1, 9999)
    local digits = self:splitNumberByDigits(winNum)
    local len = #digits
    for i = 1, 4, 1 do
        self:callView("title_" .. i, "setVisible", i == len)
    end

    for i = 1, len, 1 do
        local bottomViewName = string.format("bottom_%d_%d", len , i)
        local topViewName = string.format("top_%d_%d", len , i)
        self:callView(bottomViewName, "setString", digits[i])
        self:callView(topViewName, "setString", digits[i])
        if EnvUtil:isUnity() then
            self:callView(topViewName, "enableOutline", hex2ccc4("932F18FF"), 2)
            self:callView(topViewName, "enableShadow", hex2ccc4("9C471DFF"), ccp(0, -2), 0)
        end
    end 

    -- 上层数字，需要修改
    local needRemoveLabelNames = {
        "desc_label146", "desc_label147", "desc_label118", "desc_label119",  "desc_label4",
        "desc_label5", "desc_label0","desc_label1", 
    }
    if EnvUtil:isUnity() then
        for k, v in pairs(needRemoveLabelNames) do
            self:callView(v, "enableOutline", hex2ccc4("932F18FF"), 2)
            self:callView(v, "enableShadow", hex2ccc4("9C471DFF"), ccp(0, -2), 0)
        end
    end

    -- 去掉底层数字
    local needRemoveLabelNames = {
        "bottom_1_1", "bottom_2_1", "bottom_2_2", "bottom_3_1",  "bottom_3_2", "bottom_3_3", "bottom_4_1",
        "bottom_4_2", "bottom_4_3","bottom_4_4", "desc_label148", "desc_label149", "desc_label149",
        "desc_label120", "desc_label121", "desc_label6", "desc_label7", "desc_label2","desc_label3"
    }
    for k, v in pairs(needRemoveLabelNames) do
        local view = self:getView(v)
        UBFViewHelper:setVisibleSafe(view, false)
    end
end

function UBFWinningActsBannerView:initBannerSkin()
    if self:isBoxTypeUI() then
        local capInsets = {
            x = 24,
            y = 21,
            w = 2,
            h = 1
        }
        local box_barBackFrameName = 'UBFUi/WinningActsBanner/common/矩形_1913'
        if self.bannerType == WinningActsBannerType.BOX_WINRANK_PRE then
            box_barBackFrameName = 'UBFUi/WinningActsBanner/common/矩形_1913_i001'
        elseif self.bannerType == WinningActsBannerType.BOX_WINRANK_FINALS then
            box_barBackFrameName = 'UBFUi/WinningActsBanner/common/矩形_1913_i003'
        end
        self:getView("box_progress"):setBackBySpriteFrames(box_barBackFrameName, capInsets)
        
        if self.curWinNum > 5 then
            local curPos = self:callView("moveNode", "getPosition")
            self:callView("moveNode", "setPosition", ccp(curPos.x - 580, curPos.y))
        end
    end

    --如果背景使用的是紫色，需要更换进度条底色
    if self:isUsePurpleBg() then
        local backFrameName = 'UBFUi/WinningActsBanner/common/进度条底_紫'
        local backCapInsets = {
            x = 6,
            y = 2,
            w = 7,
            h = 5
        }
        self:getView("progressBar"):setBackBySpriteFrames(backFrameName, backCapInsets)
    end
end

function UBFWinningActsBannerView:initTrophyAnimate()
    if not self:isViewSafe("trophy") then
        return
    end
    for i = 1, 5, 1 do
        local trophyView = self:retrieveCachedView("trophy_" .. i)
        local animateName = self:getTrophyAnimName(i, "idle_jingtai")
        if self.lastWinNum == i then
            animateName = self:getTrophyAnimName(i, "idle")
        elseif self.lastWinNum > i then
            animateName = self:getTrophyAnimName(i, "close_idle")
        end
        self:replaceView("trophy_" .. i, trophyView)
        self:callView("trophy_" .. i, "playByName", animateName)
        if i == 5 then
            self:initTrophyExtraRewardsView()
        end
        -- 进场隐藏前序节点
        if self:isBoxTypeUI() and self.curWinNum > 5 and i < 5 then
            self:callView("trophy_" .. i, "setVisible", false)
        end
    end
end

--初始化额外奖励节点
function UBFWinningActsBannerView:initTrophyExtraRewardsView()
    if table.isEmpty(self.extraRewards) then
        return
    end
    if not self:isViewSafe("trophy") then
        return
    end
    for k, v in pairs(self.extraRewards) do
        if not v.streakWinNum then
            v.streakWinNum = self.curWinNum 
        end
        local isCanCreate = v.streakWinNum >= self.curWinNum
        if v.streakWinNum > 5 then
            isCanCreate = self.curWinNum == v.streakWinNum
        end
        if isCanCreate then
            --当大于5连胜的奖励放在第五个奖杯处
            local index = math.clamp(v.streakWinNum, 1, 5)
            local extraRewardViewName = string.format("trophyExtraReward_%s_%s", v.rewardId, index)              
            if not self:isViewSafe(extraRewardViewName) then
                if not self.trophyExtraRewardViewData[index] then
                    self.trophyExtraRewardViewData[index] = {}
                end
                table.insert(self.trophyExtraRewardViewData[index], v)
                local updateData = {parentViewName = "trophy_" .. index}
                if v.isMultiple then
                    --倍数
                    local viewData = UBFHelper:shallowClone(v.pendantViewData)
                    UBFHelper:shallowMerge(viewData, updateData)
                    self:createAndAddViewAsync(viewData, extraRewardViewName):next(function(anim)
                        if not isSafeCocosObj(anim) then return end
                        if not self:isViewSafe() then return end
                        local posList = {ccp(28, 49), ccp(34, 55), ccp(36, 63), ccp(41, 70), ccp(25, 76)}
                        anim:setPosition(posList[index])
                    end)
                else
                    --给数量
                    self:createAndAddPreparedViewAsync("extraRewardNode", extraRewardViewName, updateData):next(function(view)
                        if not self:isViewSafe() or not isSafeCocosObj(view) then
                            return
                        end
                        local posList = {ccp(12, 49), ccp(18, 55), ccp(22, 63), ccp(25, 70), ccp(30, 76)}
                        view:setPosition(posList[index])
                        view:getChildByName("tipNum"):setString("+" .. v.num)
                        self:createAndAddViewAsync(v.viewData):next(function(node)
                            if not self:isViewSafe() or not isSafeCocosObj(node) then
                                return
                            end
                            local pos = view:getChildByName("tipIcon"):getPosition()
                            node:setPosition(ccp(pos.x, pos.y))
                            node:setScale(0.4)
                            view:addChildAt(node, 1)
                            view:getChildByName("tipIcon"):removeFromParentAndCleanup(false)
                            self:referenceView("extraRewardTipIcon" .. index, node)
                        end)
                    end)
                end
            else
                UBFThrow("该奖励节点已存在" .. v.rewardId)
            end
        end
    end
end

function UBFWinningActsBannerView:initTrophyEffect()
    if not self:isViewSafe("trophy") then
        return
    end
    local winNum = self.lastWinNum
    if winNum >= 1 and winNum < 5 then
        local updateData = {
            parentViewName = "trophy",
            z = -1
        }
        self:createAndAddPreparedViewAsync("trophyEffect", "lastTrophyEffect", updateData):next(function(view)
            if not isSafeCocosObj(view) then return end
            if self:isViewSafe("trophy_" .. winNum) then
                local pos = self:callView("trophy_" .. winNum, "getPosition")
                view:setPosition(ccp(pos.x, pos.y))
                view:playLoop("guangshu")
                view:setScale(0)
                view:runAction(UBFViewHelper:spawn{CCFadeIn:create(FRAME_TIME * 2), CCScaleTo:create(FRAME_TIME * 5, 1)})
            end
        end)
    else
        if self.curWinNum > 5 then
            self:playLightBeamAppearAni()
        end
    end
end

function UBFWinningActsBannerView:initBallAnimate()
    if not self:isViewSafe("ball") then
        return
    end
    local winNum = self.lastWinNum
    for i = 1, 5, 1 do
        local smallBallViewName = string.format("ball_%d_smallBall", i)
        local bigBallViewName = string.format("ball_%d_bigBall", i)
        local bigBallBackViewName = string.format("ball_%d_bigBall_bigBallBack", i)
        local bigBallNumViewName = string.format("ball_%d_bigBall_bigBallNum", i)
        local bigBallFrontViewName = string.format("ball_%d_bigBall_bigBallFront", i)
        local bigBallNumFrontViewName = string.format("ball_%d_bigBall_bigBallNumFront", i)
        self:callView(smallBallViewName, "setVisible", winNum > i)
        self:callView(bigBallViewName, "setVisible", winNum <= i)
        self:callView(bigBallBackViewName, "setVisible", winNum ~= i)
        self:callView(bigBallNumViewName, "setVisible", winNum ~= i)
        self:callView(bigBallFrontViewName, "setVisible", winNum == i)
        self:callView(bigBallNumFrontViewName, "setVisible", winNum == i)
        self:callView(bigBallNumViewName, "setString", i)
        -- smallBallBack需要切换层级到进度条下面
        local smallBallBackViewName = string.format("ball_%d_smallBall_smallBallBack", i)
        LayoutUtil:changeParentNoBack(self:getView(smallBallBackViewName), self:getView("progressBar"), 1)
        if self:isViewSafe(smallBallBackViewName) then
            self:getView(smallBallBackViewName):setZOrder(-99)
        end
    end
end

function UBFWinningActsBannerView:initWinRankView()
    if not self:isViewSafe("winRank") then
        return
    end
    local winNum = math.clamp(self.lastWinNum, 1, 5)
    for i = 1, 5, 1 do
        local scoreStr = YH_REF_MAP.x .. math.ceil(self.baseScores[i] * (self.collectionRate or 1))
        self:callView("R" .. i, "setString", scoreStr)
        self:callView("winScore" .. i, "setString", scoreStr)
        self:callView("winBg" .. i, "setVisible", winNum == i)
        -- 进场隐藏前序节点
        if self:isBoxTypeUI() and self.curWinNum > 5 and i < 5 then
            self:callView("winRank" .. i, "setVisible", false)
        end
    end
end

function UBFWinningActsBannerView:initWinBoxView()
    if not self:isViewSafe("box") then
        return
    end
    local updateData = {
        replaceViewName = "boxSp",
        z = 1
    }
    self:createAndAddPreparedViewAsync("boxAnim", nil, updateData):next(function(view)
        if not self:isViewSafe() or not isSafeCocosObj(view) then
            return
        end
        view:setPositionY(-30)
        view:playByName("idle")
    end)
    local boxStr, progress = self:getBoxProgressAndText(true)
    self:callView("box_text", "setString", boxStr)
    self:refreshBoxProgressBar(progress)

    local isShowBox = self.curWinNum > 5
    self:callView("box", "setVisible", isShowBox)
end

function UBFWinningActsBannerView:initRewardView()
    if table.isEmpty(self.rewardData) then
        return
    end
    --有奖励就提前把标题移动上去
    self.isMoveTitleDone = true
    local oriPos = self:callView("title", "getPosition")
    self:callView("title", "setPosition", ccp(oriPos.x, oriPos.y + 100))

    local mid = (#self.rewardData + 1) / 2
    local spacingX = 180
    for k, v in pairs(self.rewardData) do
        --初始化时就需要显示出来，显示的数量是基础值，没配基础值的默认显示x1
        local reward = UBFHelper:shallowClone(v)
        reward.num = v.baseNum or 1
        self:createAndAddViewAsync(v.viewData):next(function(view)  
            local bubble = self:createBubbleReward({
                reward = reward,
                createIcon = function()
                    return view
                end
            })
            bubble:setPositionXY(90 + (k - mid - 0.5) * spacingX, -40)
            self:referenceView("bubble_" .. v.rewardId, bubble)
            self:getView("reward"):addChild(bubble)
        end)
    end
end

function UBFWinningActsBannerView:refreshProgressBar(winNum, animTime, callback)
    if not self:isViewSafe("progressBar") then
        return
    end
    if self:isBoxTypeUI() and self.curWinNum > 5 then
        self:fadeOutPreOrderNode()
    else
        local progress = 25 * (winNum - 1)
        progress = math.clamp(progress, 0, 100)
        self:getView("progressBar"):setValue(progress, animTime or 0, callback)
    end
end

function UBFWinningActsBannerView:refreshBoxProgressBar(progress, animTime, callback)
    if not self:isViewSafe("box_progress") then
        return
    end
    progress = math.clamp(progress, 0, 100)
    self:getView("box_progress"):setValue(progress, animTime or 0, callback)
end

-----------------------------连胜更新动画-----------------------------
function UBFWinningActsBannerView:playProgressBarUpdateAnimate(done)
    if not self:isViewSafe("progressBar") then
        safeRunCall(done)
        return
    end
    if self.lastWinNum > 0 and self.lastWinNum < 5 then
        local lastWinNum = math.clamp(self.lastWinNum, 1, 5)
        local bigBallNumFrontViewName = string.format("ball_%d_bigBall_bigBallNumFront", lastWinNum)
        local smallBallViewName = string.format("ball_%d_smallBall", lastWinNum)
        self:callView(bigBallNumFrontViewName, "setVisible", false)
        self:callView(smallBallViewName, "setVisible", true)
        local bigBallFrontViewName = string.format("ball_%d_bigBall_bigBallFront", lastWinNum)
        local node1 = self:getView(bigBallFrontViewName)
        local node2 = self:getView(smallBallViewName)
        local arrayA, arrayB = ActionUtil:getIconChangeActionArray(node1, node2)
        node1:runAction(arrayA)
        node2:runAction(arrayB)
    end

    if self.curWinNum > 0 and self.curWinNum <= 5 then
        local curWinNum = math.clamp(self.curWinNum, 1, 5)
        local animateTime = self.lastWinNum > 0 and FRAME_TIME * 12 or 0
        self:refreshProgressBar(curWinNum, animateTime, function()
            local bigBallViewName = string.format("ball_%d_bigBall", curWinNum)
            local node = self:getView(bigBallViewName)
            local bigBallFrontViewName = string.format("ball_%d_bigBall_bigBallFront", curWinNum)
            local bigBallNumFrontViewName = string.format("ball_%d_bigBall_bigBallNumFront", curWinNum)
            self:callView(bigBallFrontViewName, "setVisible", true)
            self:callView(bigBallNumFrontViewName, "setVisible", true)
            ActionUtil:playCommonAppearAnim(node)
            safeRunCall(done)
        end)
    else
        safeRunCall(done)
    end
end

function UBFWinningActsBannerView:playWinRankUpdateAnimate(done)
    if not self:isViewSafe("winRank") then
        safeRunCall(done)
        return
    end
    if self.lastWinNum <= 0 or self.lastWinNum >= 5 then
        safeRunCall(done)
        return
    end

    local lastWinNum = math.clamp(self.lastWinNum, 1, 5)
    local lastWinRank = self:getView("winRank" .. lastWinNum)
    lastWinRank:runAction(UBFViewHelper:sequence{
        CCScaleTo:create(FRAME_TIME * 2, 0.8),
        CCFadeOut:create(FRAME_TIME * 2),
        CCCallFunc:create(function()
            self:callView("winBg" .. lastWinNum, "setVisible", false)
        end),
        CCScaleTo:create(FRAME_TIME * 2, 1),
    }) 
    
    local curWinNum = math.clamp(self.curWinNum, 1, 5)
    local curWinRankBg = self:getView("winBg" .. curWinNum)
    local curWinRankEffect = curWinRankBg:clone(true)
    self:callView("winBg" .. curWinNum, "setVisible", true)
    ActionUtil:setOpacityU3D(curWinRankEffect, 0)
    curWinRankEffect:runAction(UBFViewHelper:sequence{
        UBFViewHelper:spawn{
            CCEaseSineInOut:create(CCScaleTo:create(FRAME_TIME * 12, 1.3)),
            UBFViewHelper:sequence{
                ActionUtil:fadeInU3D(curWinRankEffect, FRAME_TIME * 1),
                ActionUtil:fadeOutU3D(curWinRankEffect, FRAME_TIME * 11)
            }
        },
        CCCallFunc:create(function()
            curWinRankEffect:removeFromParentAndCleanup(true)
            safeRunCall(done)
        end)
    })
end

function UBFWinningActsBannerView:playLastTrophyUpdateAnimate()
    if not self:isViewSafe() then
        return
    end
    if self.lastWinNum > 0 and self.lastWinNum < 5 then
        local animateName1 = self:getTrophyAnimName(self.lastWinNum, "close")
        local animateName2 = self:getTrophyAnimName(self.lastWinNum, "close_idle")
        self:callView("trophy_" .. self.lastWinNum, "playSequence", false, nil, animateName1, animateName2)
    end
end

function UBFWinningActsBannerView:playCurTrophyUpdateAnimate(done)
    if not self:isViewSafe() then
        safeRunCall(done)
        return
    end
    local curWinNum = math.clamp(self.curWinNum, 1, 5)
    local animateName1 = self:getTrophyAnimName(curWinNum, "open")
    local animateName2 = self:getTrophyAnimName(curWinNum, "idle")
    local spineAni = self:getView("trophy_" .. curWinNum)
    spineAni:playOnce(animateName1, function()
        spineAni:playLoop(animateName2)
    end)
    spineAni:setAnimationEventCallback(function(obj, animationName, eventName)
        if eventName == "tx" then
            self:playCurTrophyFrontEffect(curWinNum, done)
        end
    end)
    local trophyExtraReward = self.trophyExtraRewardViewData[curWinNum]
    if trophyExtraReward then
        for i, v in ipairs(trophyExtraReward or {}) do
            local extraRewardViewName = string.format("trophyExtraReward_%s_%s", v.rewardId, curWinNum)
            if self:isViewSafe(extraRewardViewName) then
                local extraRewardView = self:getView(extraRewardViewName)
                if v.isMultiple then                
                    extraRewardView:playByName("paizi")
                end        
            end        
        end     
    end     
end

-- 光束的消失动画
function UBFWinningActsBannerView:playLightBeamDisappearAni()
    if not self:isViewSafe("lastTrophyEffect") then
        return
    end
    local lightBeamEffect = self:getView("lastTrophyEffect")
    lightBeamEffect:runAction(UBFViewHelper:sequence{
        CCScaleTo:create(FRAME_TIME * 7, 1.1),
        CCScaleTo:create(FRAME_TIME * 5, 0)
    })
end

-- 新连胜奖杯的光束出现动画
function UBFWinningActsBannerView:playLightBeamAppearAni()
    if not self:isViewSafe("trophy") then
        return
    end
    local winNum = math.clamp(self.curWinNum, 1, 5)
    --bg
    local updateData = {parentViewName = "trophy", z = -2}
    self:createAndAddPreparedViewAsync("trophyEffect", "curTrophyBgEffect", updateData):next(function(view)
        if not isSafeCocosObj(view) then return end
        if not self:isViewSafe("trophy_" .. winNum) then
            return
        end
        local pos = self:callView("trophy_" .. winNum, "getPosition")
        local posOffsetYs = {60, 70, 80, 80, 100}
        view:setPosition(ccp(pos.x, pos.y + posOffsetYs[winNum]))
        local scales = {0.7, 0.8, 1, 1, 1 }
        view:setScale(scales[winNum])
        view:playLoop("houguang")
    end)
    
    --effect
    local updateData = {parentViewName = "trophy", z = -1}
    self:createAndAddPreparedViewAsync("trophyEffect", "curTrophyEffect", updateData):next(function(view)
        if not isSafeCocosObj(view) then return end
        if not self:isViewSafe("trophy_" .. winNum) then
            return
        end
        local pos = self:callView("trophy_" .. winNum, "getPosition")
        view:setPosition(ccp(pos.x, pos.y))
        view:playLoop("guangshu")
        if self.curWinNum <= 5 then            
            view:setScale(0.3)
            view:runAction(UBFViewHelper:sequence{
                CCScaleTo:create(FRAME_TIME * 2, 0.3),
                CCScaleTo:create(FRAME_TIME * 2, 1.1),
                CCScaleTo:create(FRAME_TIME * 5, 1),
            })
        end
    end)
end

function UBFWinningActsBannerView:playCurTrophyFrontEffect(index, done)
    local updateData = {
        parentViewName = "trophy",
        z = 5
    }
    self:createAndAddPreparedViewAsync("trophyEffect", "curTrophyFrontEffect", updateData):next(function(view)
        if not isSafeCocosObj(view) then return end
        if not self:isViewSafe("trophy_" .. index) then
            return
        end
        local pos = self:callView("trophy_" .. index, "getPosition")
        local posOffsetYs = {40, 40, 50, 55, 60}
        view:setPosition(ccp(pos.x, pos.y + posOffsetYs[index]))
        view:playOnce("qianguang", function()
            self:removeView("curTrophyFrontEffect")
            safeRunCall(done)
        end)
    end)
end

function UBFWinningActsBannerView:moveWinTrophyNode(done)
    if not self:isViewSafe() then return end
    if not self:isViewSafe("moveNode") then
        safeRunCall(done)
        return
    end
    if not self:isNeedMoveWinTrophy() then
        safeRunCall(done)
        return
    end

    -- 宝箱出现
    self:callView("box", "setVisible", true)
    local updateData = {
        parentViewName = "box",
        z = 100
    }
    self:createAndAddPreparedViewAsync("boxProgressOpenAnim", "boxEffectIdle", updateData):next(function(view)
        if not self:isViewSafe() or not isSafeCocosObj(view) then
            return
        end
        view:setPositionXY(-9, -75)
        view:playByName("guangtiao_idle")
        view:runAction(UBFViewHelper:sequence{
            CCDelayTime:create(FRAME_TIME * 8),
            CCCallFunc:create(function()
                self:callView("boxEffectIdle", "playOnceAndDispose", "guangtiao")
            end)
        })
    end)
    -- 移动位置
    local curPos = self:callView("moveNode", "getPosition")
    self:getView("moveNode"):runAction(UBFViewHelper:sequence{
        CCDelayTime:create(FRAME_TIME * 5),
        CCEaseSineInOut:create(CCMoveTo:create(FRAME_TIME * 13, ccp(curPos.x - 580, curPos.y))),
        CCCallFunc:create(function()
            safeRunCall(done)
        end)
    })

    -- 隐渐隐前序节点
    self:fadeOutPreOrderNode()
end

-- 隐渐隐前序节点 
function UBFWinningActsBannerView:fadeOutPreOrderNode()
    local fadeOutTime = self.curWinNum > 5 and 0 or FRAME_TIME * 10
    for i = 1, 4, 1 do
        local ballNode = self:getView("ball_" .. i)
        local smallBallBackNode = self:getView(string.format("ball_%d_smallBall_smallBallBack", i))
        local trophyNode = self:getView("trophy_" .. i)
        local winRankNode = self:getView("winRank" .. i)
        self:runFadeOutAction(ballNode, fadeOutTime)
        self:runFadeOutAction(smallBallBackNode, fadeOutTime)
        self:runFadeOutAction(trophyNode, fadeOutTime)
        self:runFadeOutAction(winRankNode, fadeOutTime)
    end

    if self:isViewSafe("progressBar") then
        local barNode = self:getView("progressBar"):getChildByName("barClippingNode"):getChildByName("bar")
        local barBack = self:getView("progressBar"):getChildByName("back")
        barBack:setVisible(false)

        UBFViewHelper.Shader:applyLeftRightFadeOut(barNode, 1.0, 0.02, 0.2)
    end
end

function UBFWinningActsBannerView:runFadeOutAction(node, fadeOutTime, callback)
    if not isSafeCocosObj(node) then
        return
    end
    fadeOutTime = fadeOutTime or FRAME_TIME * 10
    ActionUtil:startGroupFadeOut(node, fadeOutTime, function ()
        node:setVisible(false)
        safeRunCall(callback)
    end)
end

function UBFWinningActsBannerView:playBoxAnimate(done)
    if not self:isViewSafe() then return end
    if not self:isViewSafe("box") then
        safeRunCall(done)
        return
    end
    if self.curWinNum < 5 then
        safeRunCall(done)
        return
    end
    local boxStr, progress = self:getBoxProgressAndText()
    local progressIsFull = progress == 100
    self:getView("box_text"):runAction(UBFViewHelper:sequence{
        CCScaleTo:create(FRAME_TIME * 3, 1.2),
        CCCallFunc:create(function()
            if progressIsFull then
                self:callView("box_text", "setColor", ccc3(202, 78, 46))
                self:callView("box_text", "enableOutline", ccc3(255, 255, 255), 1)
            end
            self:callView("box_text", "setString", boxStr)
        end),
        CCScaleTo:create(FRAME_TIME * 3, 1)
    })

    local updateData = {
        parentViewName = "box_progress",
        z = 1
    }
    self:createAndAddPreparedViewAsync("boxProgressIdleAnim", nil, updateData):next(function(view)
        if not self:isViewSafe() or not isSafeCocosObj(view) then
            return
        end
        view:setPositionXY(140, -60)
        view:playByName("idle")
    end)

    self:refreshBoxProgressBar(progress, FRAME_TIME * 3, function()
        if progressIsFull and self:isViewSafe("boxSp") then
            for k, v in pairs(self.boxReward or {}) do
                table.insert(self.rewardData, v)
            end
            self:callView("boxSp", "playOnce", "kaixiang")
            self:getView("boxSp"):setAnimationEventCallback(function(obj, animationName, eventName)
                if eventName == "kai" then
                    self:getView():runAction(UBFViewHelper:sequence{
                        CCCallFunc:create(function ()
                            self:updateRewardUI(FRAME_TIME * 10)
                            local mid = (#self.boxReward + 1) / 2
                            local spacingX = 50
                            for kk, vv in pairs(self.boxReward or {}) do
                                local updateData = {parentViewName = "flyRewardLayer" , z = 20, scale = 0.4}
                                local viewData = UBFHelper:shallowClone(vv.viewData)
                                UBFHelper:shallowMerge(viewData, updateData)
                                --宝箱奖励不会重复 直接刷成最终的数量
                                local reward = table.find(self.rewardData, function (_v)
                                    return _v.rewardId == vv.rewardId
                                end)
                                local pos = ccp(25 + (kk - mid - 0.5) * spacingX, 70)
                                local startPosOffset = {x = pos.x - 15 , y = pos.y}
                                self:flyRewardIconAnimate(viewData, self:getView("boxSp"), reward, nil, nil, nil , startPosOffset)
                            end
                        end),
                        CCDelayTime:create(FRAME_TIME * 5),
                        CCCallFunc:create(function ()
                            safeRunCall(done)
                        end)
                    })
                end
            end)
        else
            safeRunCall(done)
        end
    end)
end

function UBFWinningActsBannerView:moveTitle(done)
    if not self:isViewSafe() then return end
    local actArr = CCArray:create()
    if self.isMoveTitleDone then
        actArr:addObject(CCDelayTime:create(FRAME_TIME * 30))
    else        
        local oriPos = self:callView("title", "getPosition")
        actArr:addObject(CCDelayTime:create(FRAME_TIME * 22))
        actArr:addObject(CCMoveTo:create(FRAME_TIME * 3, ccp(oriPos.x, oriPos.y + 100)))
        actArr:addObject(CCDelayTime:create(FRAME_TIME * 8))
    end
    actArr:addObject(CCCallFunc:create(function()
        safeRunCall(done)
    end))
    self:getView("title"):runAction(CCSequence:create(actArr))
    self.isMoveTitleDone = true
end

function UBFWinningActsBannerView:updateRewardUI(delayTime)
    if table.isEmpty(self.rewardData) then
        return
    end
    self:moveTitle()
    self.rewardData = self:mergeRewards(self.rewardData)
    local mid = (#self.rewardData + 1) / 2
    local spacingX = 180
    delayTime = delayTime or FRAME_TIME * 5
    for k, v in pairs(self.rewardData) do
        local pos = ccp(90 + (k - mid - 0.5) * spacingX, -40)
        local rewardBubbleViewName = "bubble_" .. v.rewardId
        if self:isViewSafe(rewardBubbleViewName) then
            local bubble = self:getView(rewardBubbleViewName)
            bubble:runAction(UBFViewHelper:sequence{
                CCDelayTime:create(delayTime), 
                CCMoveTo:create(FRAME_TIME * 5, pos)
            })
        else
            self:createAndAddViewAsync(v.viewData):next(function(view)  
                local bubble = self:createBubbleReward({
                    reward = v,
                    createIcon = function()
                        return view
                    end
                })
                bubble:setPosition(ccp(pos.x, pos.y))
                bubble:setScale(0)
                self:referenceView("bubble_" .. v.rewardId, bubble)
                self:getView("reward"):addChild(bubble)
            end)
        end
    end
end

function UBFWinningActsBannerView:setAutoCloseOnTime(delayTime, done)
    if not self:isViewSafe() then return end
    self:getView():runAction(UBFViewHelper:sequence{
        CCDelayTime:create(delayTime),
        CCCallFunc:create(function ()
            safeRunCall(done)
            if not self:isViewSafe() then return end
            self:exeOp(WinningActsBannerOpType.CLOSE)
        end)
    })
end

function UBFWinningActsBannerView:updateRewardBubbleNum(bubbleViewName, reward)
    local bubble = self:getView(bubbleViewName)
    if self:isViewSafe(bubbleViewName) then        
        bubble.bubbleNum:runAction(UBFViewHelper:sequence{
            CCEaseIn:create(CCScaleTo:create(FRAME_TIME * 3, 1.5), 2),
            CCCallFunc:create(function()
                bubble.bubbleNum:setString(YH_REF_MAP.x .. reward.num)
                bubble.bubbleNum:setColor(hex2ccc4("FFF916FF"))
                bubble.bubbleNum:enableOutline(hex2ccc4("CF5D11FF"), 2)
            end),
            CCDelayTime:create(FRAME_TIME * 5),
            CCEaseOut:create(CCScaleTo:create(FRAME_TIME * 3, 1.1), 2),
            CCEaseIn:create(CCScaleTo:create(FRAME_TIME * 3, 1.2), 2),
        })
    end
    bubble:runAction(UBFViewHelper:sequence{
        CCDelayTime:create(FRAME_TIME * 10),
        CCCallFunc:create(function()
            self:createAndAddPreparedViewAsync("rewardNumAnim"):next(function(view)
                if not self:isViewSafe() or not isSafeCocosObj(view) then
                    return
                end
                bubble:addChildAt(view, 0)
                view:setPositionXY(bubble.bubbleNum:getPositionX()- 35, bubble.bubbleNum:getPositionY())
                view:playOnceAndDispose("idle")
            end)
        end)
    })
end

function UBFWinningActsBannerView:flyRewardIconAnimate(viewData, curIocnView, reward, endCall, flyCount, flyTime, startPosOffset)
    flyCount = flyCount or 3
    for i = 1, flyCount, 1 do        
        self:createAndAddViewAsync(viewData):next(function(view)  
            local rewardBubbleViewName = "bubble_" .. reward.rewardId
            local startPos = self:getView("flyRewardLayer"):convertToNodeSpace(curIocnView:getPositionInWorldSpace())
            if reward.isMultiple then
                startPos.x = startPos.x + 20
                startPos.y = startPos.y - 40
            end
            if startPosOffset then
                startPos.x = startPos.x + startPosOffset.x
                startPos.y = startPos.y + startPosOffset.y
            end
            startPos.x = startPos.x + math.random(0, 50) - 25
            startPos.y = startPos.y + math.random(0, 50) - 25
            view:setPosition(startPos)
            local endPos = self:getView("flyRewardLayer"):convertToNodeSpace(self:callView(rewardBubbleViewName, "getPositionInWorldSpace"))
            flyTime = flyTime or FRAME_TIME * 10
            local p1, p2
            p1 = ccp(0.4 * (endPos.x - startPos.x), -0.2 * (endPos.y - startPos.y))
            p2 = ccp(0.9 * (endPos.x - startPos.x), 0.5 * (endPos.y - startPos.y))
            local bezierConfig = ccBezierConfig:new()
            bezierConfig.controlPoint_1 = ccp(startPos.x + p1.x, startPos.y + p1.y)
            bezierConfig.controlPoint_2 = ccp(startPos.x + p2.x, startPos.y + p2.y)
            bezierConfig.endPosition = endPos
            view:runAction(UBFViewHelper:sequence{
                CCDelayTime:create(FRAME_TIME * (i - 1) * 2),
                CCScaleTo:create(FRAME_TIME * 3, 0.48),
                CCScaleTo:create(FRAME_TIME * 3, 0.4),
                CCCallFunc:create(function()
                    --提前结束
                    if i == flyCount then                
                        safeRunCall(endCall)
                    end
                end),
                UBFViewHelper:spawn{
                    CCEaseSineInOut:create(CCBezierTo:create(flyTime, bezierConfig)),
                    CCScaleTo:create(flyTime, 1),
                },
                CCCallFunc:create(function()
                    local bubble = self:getView(rewardBubbleViewName)
                    if isSafeCocosObj(bubble) and i == 1 then
                        local oriScale = 1
                        bubble:runAction(UBFViewHelper:sequence{
                            CCScaleTo:create(FRAME_TIME * 3, oriScale * 0.7),
                            CCScaleTo:create(FRAME_TIME * 5, oriScale * 1.12),
                            CCScaleTo:create(FRAME_TIME * 6, oriScale * 0.98),
                            CCScaleTo:create(FRAME_TIME * 5, oriScale * 1),
                        })
                    end
                end),
                CCFadeOut:create(FRAME_TIME * 1),
                CCCallFunc:create(function()
                    if i == flyCount then                
                        self:updateRewardBubbleNum(rewardBubbleViewName, reward)
                    end
                end)
            })
        end)
    end
end

-- UI状态相关函数
function UBFWinningActsBannerView:isBoxTypeUI()
    local isBoxBannerType = self.bannerType == WinningActsBannerType.BOX 
        or self.bannerType == WinningActsBannerType.BOX_WINRANK_PRE 
        or self.bannerType == WinningActsBannerType.BOX_WINRANK_FINALS
    return isBoxBannerType
end

function UBFWinningActsBannerView:isWinRankTypeUI()
    local isWinRankType = self.bannerType == WinningActsBannerType.NORMAL_WINRANK_PRE 
        or self.bannerType == WinningActsBannerType.NORMAL_WINRANK_FINALS 
        or self.bannerType == WinningActsBannerType.BOX_WINRANK_PRE 
        or self.bannerType == WinningActsBannerType.BOX_WINRANK_FINALS
    return isWinRankType
end

function UBFWinningActsBannerView:isUsePurpleBg()
    local uiData = self:getView("bg").uiData
    local ui = uiData and uiData.ui
    if ui.spriteFrameName == "UBFUi/WinningActsBanner/bg2/紫色条" then
        return true
    end
    return false
end

function UBFWinningActsBannerView:isNeedMoveWinTrophy()
    local bannerTypeOk = self:isBoxTypeUI()
    local winNumOk = self.curWinNum == 5
    return bannerTypeOk and winNumOk
end

function UBFWinningActsBannerView:getTrophyAnimName(index, type)
    local animateName = nil
    if type == "idle_jingtai" then
        animateName = string.format("idle%d_j", index)
    elseif type == "idle" then
        animateName = string.format("idle%d", index)
    elseif type == "open" then
        animateName = (index == 5 and self.curWinNum > 5) and "idle5_kai2" or string.format("idle%d_kai", index)
    elseif type == "close_idle" then
        animateName = index == 5 and "idle5" or string.format("idle%d_guan_idle", index)
    elseif type == "close" then
        animateName = index == 5 and "idle5" or string.format("idle%d_guan", index)
    else
        UBFLogE("UBFWinningActsBannerView", string.format("playTrophyAnim error, index = %d, type = %s", index, tostring(type)))
    end

    return animateName
end

function UBFWinningActsBannerView:getBoxProgressAndText(isShowLastTime)
    local remainingWinNum = self.boxTotalWinProgress - self.curBoxWinProgress
    local curBoxWinProgress = self.curBoxWinProgress
    if isShowLastTime and curBoxWinProgress >= 1 then
        remainingWinNum = remainingWinNum + 1
        curBoxWinProgress = curBoxWinProgress - 1
    end
    local progress = math.floor(curBoxWinProgress / self.boxTotalWinProgress * 100) 
    progress = math.clamp(progress, 0, 100)
    local str = progress == 100 and "已开启" or string.format("再连胜%d关开启", remainingWinNum)

    return str, progress
end

function UBFWinningActsBannerView:mergeRewards(rewardTable)
    local rewards = {}
    for i, v in ipairs(rewardTable) do
        local found = false
        for i2, v2 in ipairs(rewards) do
            if v2.rewardId == v.rewardId then
                found = true
                v2.num = v2.num + v.num
                break
            end
        end
        if not found then
            table.insert(rewards, v)
        end
    end
    return rewards
end

-- 按位数分割数字为字符串，返回table
function UBFWinningActsBannerView:splitNumberByDigits(n)
    local s = tostring(math.abs(n))
    local t = {}
    for i = 1, #s do
        t[i] = s:sub(i, i)
    end
    return t
end

function UBFWinningActsBannerView:createBubbleReward(createData)
    local Bubble = require "amf.middleware.ui.kit.component.Bubble"
    local bubble = Bubble.Builder.new()
        :setReward(createData.reward)
        :setIconCreator(createData.createIcon)
        :build()

    return bubble
end

function UBFWinningActsBannerView:onPlayEnterTransition()
    local promise = UBFPromise:create()
    local uiRoot = self:getView()
    ActionUtil:setOpacityU3D(uiRoot, 0)
    uiRoot:runAction(UBFViewHelper:sequence{
        ActionUtil:fadeInU3D(uiRoot, FRAME_TIME * 5),
        CCCallFunc:create(function()
            promise:resolve()
        end)
    })

    return promise
end

-- 进场动画流程
function UBFWinningActsBannerView:onEnterTransitionEnd()
    local winNum = math.clamp(self.curWinNum, 1, 5)
    local asyncRunner = AsyncRunner:create()
    asyncRunner:add(function (done)
        if not self:isViewSafe() then return end
        self:getView():runAction(UBFViewHelper:spawn{
            CCDelayTime:create(FRAME_TIME * 13), 
            CCCallFunc:create(function ()
                safeRunCall(done)
            end)
        })
    end)

    -- 进度条更新动画
    asyncRunner:add(function(done)
        if not self:isViewSafe() then return end
        self:playLastTrophyUpdateAnimate()
        self:playLightBeamDisappearAni()

        -- 二选一
        if self:isWinRankTypeUI() then
            self:playWinRankUpdateAnimate(done)
        else
            self:playProgressBarUpdateAnimate(done)
        end

        -- 新连胜奖杯的光束出现动画
        if self.curWinNum <= 5 then
            self:playLightBeamAppearAni()
        end
    end)

    -- 奖杯更新动画
    asyncRunner:add(function(done)
        if not self:isViewSafe() then return end
        self:playCurTrophyUpdateAnimate(done)
    end)

    -- 飞奖励动画（依次飞行）
    -- 1飞奖杯额外奖励
    local trophyExtraReward = self.trophyExtraRewardViewData[winNum]
    if trophyExtraReward then
        for i, v in ipairs(trophyExtraReward or {}) do 
            local trophyExtraRewardViewName = string.format("trophyExtraReward_%s_%s", v.rewardId, winNum)              
            if self:isViewSafe(trophyExtraRewardViewName) then
                asyncRunner:add(function(done)
                    if not self:isViewSafe() then return end
                    local curExtraRewardView = self:getView(trophyExtraRewardViewName)
                    local curExtraRewardIocnView
                    if v.isMultiple then                
                        curExtraRewardIocnView = curExtraRewardView
                    else
                        curExtraRewardIocnView = self:getView("extraRewardTipIcon" .. winNum)
                        curExtraRewardIocnView:runAction(UBFViewHelper:sequence{
                            CCScaleTo:create(FRAME_TIME * 3, 0.48),
                            ActionUtil:fadeOutU3D(curExtraRewardView, FRAME_TIME * 4),
                            CCCallFunc:create(function()
                                curExtraRewardView:removeFromParentAndCleanup(true)
                            end),
                        })
                    end
                    if v.num > 0 then
                        local updateData = {parentViewName = "flyRewardLayer" , z = 20, scale = 0.4}
                        local viewData = UBFHelper:shallowClone(v.viewData)
                        UBFHelper:shallowMerge(viewData, updateData)
                        self:flyRewardIconAnimate(viewData, curExtraRewardIocnView, v, done, 6)
                    end
                end)
            end
        end
    end

    -- 2飞连胜排行榜动画
    if self:isWinRankTypeUI() then
        asyncRunner:add(function(done)
            if not self:isViewSafe() then return end
            local updateData = {parentViewName = "flyRewardLayer", z = 20, scale = 0.4}
            for k, v in pairs(self.winRankRewards) do
                local viewData = UBFHelper:shallowClone(v.viewData)
                UBFHelper:shallowMerge(viewData, updateData)
                local _done = k == #self.winRankRewards and done or nil
                local flyCounts = {3, 3, 5, 5, 9}
                self:flyRewardIconAnimate(viewData, self:getView("winScore" .. winNum), v, _done, flyCounts[winNum])
            end
        end)
    end

    -- 移动标题
    if not table.isEmpty(self.rewardData) then
        asyncRunner:add(function(done)
            self:moveTitle(done)
        end)
    end

    -- 宝箱移动
    asyncRunner:add(function(done)
        self:moveWinTrophyNode(done)
    end)

    -- 宝箱动画
    asyncRunner:add(function(done)
        self:playBoxAnimate(done)
    end)

    -- 自动关闭
    asyncRunner:add(function(done)
        self:setAutoCloseOnTime(1.5, done)
    end)

    asyncRunner:run()
end

-- debug
function UBFWinningActsBannerView:popout(bannerData)
    local uiMgr = UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
    if uiMgr:existNode(WinningActsBannerNodeId.MAIN) then
        uiMgr:callNode(WinningActsBannerNodeId.MAIN, "exit", true, {
            byOp = true
        })
    end
    local delegate = uiMgr:newUiUpdateDelegate()
    delegate.viewLogicConfig:setInitParams(WinningActsBannerLogicId.MAIN, bannerData)
    delegate.nodeConfig:setWhole(WinningActsBannerNodeId.MAIN, {
        logicId = WinningActsBannerLogicId.MAIN,
        bannerData = bannerData
    })
    delegate.nodeConfig:setWhole(WinningActsBannerNodeId.TAP_TO_CONTINUE, {
        logicId = UBFUiLogicId.TAP_TO_CONTINUE,
        parentNodeId = WinningActsBannerNodeId.MAIN,
        enterOrder = 1,
        z = 200,
        touch = {
            onClick = {
                opType = WinningActsBannerOpType.CLOSE
            }
        }
    })
    delegate:createNodeAsync(WinningActsBannerNodeId.MAIN):next(function(node)
        delegate:clear()
    end)
end

return UBFWinningActsBannerView