---auto create by ui_editor
---@class RankRewardPanel : UeAMFBasePanel
---field start
---@field getBtn UEButton
---field end
---auto create end don't delete

local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local AnimationUtil = require "amf.middleware.ui.util.AnimationUtil"
local ActionUtil = require 'amf.middleware.ui.util.ActionUtil'
local MusicMasterConfig = require 'amf.feature.localactivity.musicmaster.config.MusicMasterConfig'
local Tween = require "amf.middleware.ui.util.Tween"

local oneFrame = 1/30

local RankRewardPanel = class("RankRewardPanel",UeAMFBasePanel)

function RankRewardPanel:getUIInfo( )
    return "amf.feature.localactivity.musicmaster.view.uisource.RankRewardPanel_UI", {'noUse'}
end

function RankRewardPanel:getAssetsList()
    return {
        "amf/activity/musicmaster/materials/MusicMasterIcons.plist",
        "amf/activity/musicmaster/spine/show_vfx.skel",
    }
end

function RankRewardPanel:initData( delegate )
end

function RankRewardPanel:initButtons(  )
    self.getBtn:setTouchHandler( preventContinuousClick(function()
        if self.isDisposed then return end
        if self.bubbleLayer then
            self.bubbleLayer:flyFunc( function()
                if self.isDisposed then return end
                self:sendCommand("onCloseBtnTapped")
            end)

            Tween.to(self.titleRankPart, 0.2 ,{ fAlpha = 0 })
            Tween.to(self.titleTip, 0.2 ,{ fAlpha = 0 })
            Tween.to(self.getBtn, 0.2 ,{ fAlpha = 0 })
            Tween.to(self.titleLabel, 0.2 ,{ fAlpha = 0 })
            if self.boxAnim then
                Tween.to(self.boxAnim, 0.2 ,{ fAlpha = 0 })
            end
            self.darkLayer:runAction( CCFadeTo:create(0.15, 0) ) 

        else
            self:sendCommand("onCloseBtnTapped")
        end
    end))
end

function RankRewardPanel:init( delegate )
    UeAMFBasePanel.init(self, delegate)
    self:initData( delegate )
    self:initButtons(  )
end

function RankRewardPanel:initUI()

    local darkLayer = UICreateUtil:createDarkLayer(0)
    self.darkLayerHolder:addChild(darkLayer)
    self.darkLayer = darkLayer

    --头像
    local profileMgr = _G.amfBean("ProfileManager")
    local headImage = HeadImage:create({
        headUrl = profileMgr:getHeadUrl() or "",
    },{ignoreHeadFrame = true})
    headImage:setScale(1.3)
    self.titleHeadFrameHolder:addChild(headImage)

    if self.vm.needJumpBox then
        local boxSkin = self.vm:getBoxAnimSkin(self.vm.rank)
        local spineFileName = self.vm:getBoxAnimFileName(self.vm.rank)

        local boxAnim = UICreateUtil:createSpineManuallyRelease(spineFileName)
        AnimationUtil:makeAdvancedSpine(boxAnim)
        boxAnim:setPositionXY(0, 0)
        boxAnim:setSkin(boxSkin)
        boxAnim:playByName('daiji',true)
        self.boxHolder:addChild(boxAnim)
        self.boxAnim = boxAnim
        self.boxAnim:setVisible(false)
    end

    self.titleLabel:setVisible(false)

    self.getBtn:setScale(0)
    self.titleRankPart:setScale(0)
    self.titleTip:setScale(0)
    Tween.to(self.titleRankPart, 0 ,{ fAlpha = 0 })
    Tween.to(self.titleTip, 0 ,{ fAlpha = 0 })
    Tween.to(self.getBtn, 0 ,{ fAlpha = 0 })
    Tween.to(self.titleLabel, 0 ,{ fAlpha = 0 })


    --title
    local groupName = MusicMasterConfig:getGroupName( self.vm.areaDuan )
    self.titleLabel:setString(groupName)

        --
    local showStr = ""
    if self.vm.rank ==1 then
        showStr = "令人惊讶的成绩，再接再厉"
    elseif self.vm.rank ==2 then
        showStr = "就差一点，再来一次一定能更好"
    elseif self.vm.rank ==3 then
        showStr = "再接再励，下次成绩会更好"
    elseif self.vm.rank ==4 then
        showStr = "已经很棒了，距离前三甲只差一步"
    else
        showStr = "能完成比赛，就已经是赢家了！"
    end

    self.titleTip:setString(showStr)

    --ranklabel
    local showNameList = {"初级","中级","高级","大师","王者"}
    local showIndex = self.vm.areaDuan + 1
    local duanName = showNameList[showIndex] or showNameList[#showNameList]
    self.titleRankLabel:setString("<kerning=2.5>第<color=#D95200FF>"..self.vm.rank .."</color>名")
end

function RankRewardPanel:onPostPopout()
    local asyncRunner = AsyncRunner:create()

    --宝箱跳到中间、标题出现、遮罩淡入
    --排名放大 渐变出现 播爆炸特效
    --tip渐变出现
    --宝箱打开消失，界面上移，气泡出现

    asyncRunner:add(function (done)
        --宝箱跳到中间、标题出现、遮罩淡入
        if self.isDisposed then return end

        local function titleShow()
            --标题出现、遮罩淡入
            if self.isDisposed then return end
            self.titleLabel:setVisible(true)
            self.titleRankPart:setScale(0.5)
            Tween.to(self.titleRankPart, 0.3 ,{ fAlpha = 1 })
            
            setTimeOut( done, 0.1 )
        end

        if self.boxAnim then
            self.boxAnim:setVisible(true)
            self.boxAnim:setScale(0.2)
            self.boxAnim:setWorldPositon(ccp(self.vm.startWorldPos.x,self.vm.startWorldPos.y))

            local array1 = CCArray:create()
            array1:addObject( CCEaseSineIn:create( CCJumpTo:create(oneFrame*15, ccp(0,0), 340, 1) ) )
            array1:addObject( CCScaleTo:create(oneFrame*15, 0.5) )

            local array = CCArray:create()
            array:addObject( CCSpawn:create(array1) )
            array:addObject(CCCallFunc:create(function()
                if self.isDisposed then return end
                -- self.boxAnim:playByName('tixing',false)
                -- self.boxAnim:addAnimation('idle',false)
            end))
            self.boxAnim:runAction( CCSequence:create(array) )

            self.darkLayer:runAction( CCFadeTo:create(0.15, 230) ) 

            setTimeOut( titleShow, oneFrame*15 )
        else

            self.darkLayer:runAction( CCFadeTo:create(0.15, 230) ) 
            
            titleShow()
        end
        
    end)

    asyncRunner:add(function (done)
        if self.isDisposed then return end
        --排名放大 渐变出现 播爆炸特效
        --tip渐变出现

        self.titleTip:setScale(1)
        Tween.to(self.titleRankPart, 0.3 ,{ fAlpha = 1 })
        Tween.to(self.titleTip, 0.3 ,{ fAlpha = 1 })
        Tween.to(self.titleLabel, 0.3 ,{ fAlpha = 1 })

        local array = CCArray:create()
        array:addObject( CCScaleTo:create(oneFrame*5, 1.08) )
        array:addObject(CCCallFunc:create(function()
            if self.isDisposed then return end

            local show_vfxAnim = UICreateUtil:createSpine("amf/activity/musicmaster/spine/show_vfx.skel")
            AnimationUtil:makeAdvancedSpine(show_vfxAnim)
            show_vfxAnim:setPositionXY(0,-50)
            show_vfxAnim:playOnceAndDispose("show")
            self.titleRankPart:addChild( show_vfxAnim )
        end))
        array:addObject( CCScaleTo:create(oneFrame*10, 1) )
        array:addObject(CCCallFunc:create(function()
            if self.isDisposed then return end
            setTimeOut( done, 0.4 )
        end))
        
        self.titleRankPart:runAction( CCSequence:create(array) )
    end)

    asyncRunner:add(function (done)
        --宝箱打开
        if self.isDisposed then return end

        if self.boxAnim then
            local function boxOpen()
                if self.isDisposed then return end
                self.boxAnim:setVisible(true)
                self.boxAnim:playByName('xuli1',false)
                self.boxAnim:addAnimation('kai',false)
                self.boxAnim:addAnimation('idle',true)
            end
            local array = CCArray:create()
            array:addObject( CCDelayTime:create(0) )
            array:addObject(CCCallFunc:create(function()
                boxOpen()
            end))
            self.boxAnim:runAction(CCSequence:create(array))
            setTimeOut( done, oneFrame*19 )
        else
            safeRunCall(done)
        end
    end)

    asyncRunner:add(function (done)
        --宝箱打开消失，界面上移，气泡出现
        if self.isDisposed then return end

        local function titleMoveFunc()
            --界面上移，气泡出现
            if self.isDisposed then return end
            local array1 = CCArray:create()
            array1:addObject( CCScaleTo:create(0.3, 0.6) )
            array1:addObject( CCMoveBy:create(0.3, ccp(0,150+40)) )

            local array = CCArray:create()
            array:addObject( CCSpawn:create(array1) )
            array:addObject(CCCallFunc:create(function()
                if self.isDisposed then return end

                local showRewards = table.clone(self.vm.rewards)
                local targetPos = self.vm.colectTargetWorldPos
                for i,v in ipairs(showRewards) do
                    if v.itemId == MusicMasterConfig.CollectId then
                        v.flyFunc = function( reward, worldPos, scale, callBack )
                            local iconCreator = function()
                                return GameItemCreator:getPropIcon({itemId=reward.itemId,num=reward.num})
                            end 
                            local RewardFlyHelper = require 'amf.feature.localactivity.processgiftautopopup.RewardFlyHelper.lua'
                            RewardFlyHelper:rewardFlyFunc(true,reward,worldPos,ccp(targetPos.x,targetPos.y),iconCreator,callBack,CCSizeMake(30,30),nil,scale)
                        end
                    else
                        v.doNotFly = true
                    end
                end
                

                --气泡出现、领取按钮出现
                local BubbleShowLayer = require "amf.middleware.ui.kit.panel.reward.component.BubbleShowLayer"
                local bubbleLayer = BubbleShowLayer.Builder.new()
                :setRewards(showRewards)
                :setNoLight(false)
                :build()
                bubbleLayer:createRealBubbles()
                bubbleLayer:setPositionXY(0,236)
                self.rewardHolder:addChild(bubbleLayer)
                self.bubbleLayer = bubbleLayer

                self:flyBubble( function()
                    if self.isDisposed then return end
                    self.getBtn:setScale(1)
                    Tween.to(self.getBtn, 0.3 ,{ fAlpha = 1 })
                    safeRunCall(done)
                end)
            end))

            self.titlePart:runAction(CCSequence:create(array))
            Tween.to(self.titleTip, 0.3 ,{ fAlpha = 0 })

            local array1 = CCArray:create()
            array1:addObject( CCMoveBy:create(0.3, ccp(0,150)) )
            self.titleLabel:runAction(CCSequence:create(array1))

            if self.boxAnim then
                --宝箱下移
                local array1 = CCArray:create()
                array1:addObject( CCScaleTo:create(0.3, 0.5) )
                array1:addObject( CCMoveBy:create(0.3, ccp(0,-158)) )

                local array = CCArray:create()
                array:addObject( CCSpawn:create(array1) )

                self.boxAnim:runAction(CCSequence:create(array))
            end
        end

        titleMoveFunc()
    end)

    asyncRunner:run()
end

--bubble飞行(开宝箱用)
function RankRewardPanel:flyBubble(done)

    local rewardsNum = #self.vm.rewards
    local flyDuration = 0.05
    local flyIndex = 1

    local flyToTable = {}
    local posNum = rewardsNum >= 10 and 9 or rewardsNum

    local toScale = self.bubbleLayer:getBubbleScale()
    for i = 1,posNum do
        local worldPos = self.bubbleLayer:getBubbleWorldPos(i)
        local newPos = self.ui:convertToNodeSpace(worldPos)
        table.insert(flyToTable,newPos)
    end

    for i = 1,rewardsNum do
        --先验证，再实际处理，以免内存泄漏
        Tween.to(self.bubbleLayer:getBubble(i),(i-1)*flyDuration,{onComplete = function()
            if self.isDisposed then return end

            local node = self.bubbleLayer:createRealBubble(i)
            node:pretreat()

            local startPos = self.getBtn:getPosition()
            local endPos
            if i <= 9 then
                endPos = flyToTable[i]
            else
                endPos = flyToTable[(i-1) % 3 + 7]
                endPos = ccp(endPos.x,endPos.y)
            end

            node:setPositionXY(startPos.x,startPos.y)
            node:setScale(0)
            ActionUtil:setOpacity(node,255)
            self.ui:addChild(node)

            --如果是第十个，开启挪动
            if i == 9 and rewardsNum >= 10 then
                local num = 0
                local index = 0
                local lineNum = math.ceil((rewardsNum-9)/3)
                local coeffcient = flyDuration*30*3
                local function onTick()
                    if self.isDisposed then return end

                    if num >= coeffcient*lineNum then
                        if self.schedId then
                            CCDirector:sharedDirector():getScheduler():unscheduleScriptEntry(self.schedId)
                            self.schedId = nil
                        end
                        return
                    end
                    num = num + 1
                    index = index + 1

                    --因为scroll中间默认空5像素，所以移动必须+5 像素
                    self.bubbleLayer:gotoPosY((self.bubbleLayer:getBubbleHeight() + 5)/coeffcient*index,1/30)
                end
                self.schedId = CCDirector:sharedDirector():getScheduler():scheduleScriptFunc(onTick, 1/30, false)
            end

            --通过检测，开启飞行
            flyIndex = flyIndex + 1
            local offsetY = 0
            --最后一行最后两个不改位置
            local function needChangePos(index)
                local lastNum = rewardsNum - index
                if lastNum >= 2 then
                    return true
                elseif lastNum < 2 and rewardsNum % 3 ~= 1 then
                    return false
                else
                    return true
                end
            end

            local function isLastLine(index)
                local lastNum = rewardsNum % 3
                if lastNum == 0 then lastNum = 3 end
                return index > (rewardsNum - lastNum)
            end

            if rewardsNum >= 10 and i >= 8 and needChangePos(i) then
                if i % 3 == 1 then offsetY = 0
                elseif i % 3 == 2 then offsetY = -self.bubbleLayer:getBubbleHeight() / 3
                else offsetY = -self.bubbleLayer:getBubbleHeight() / 3 * 2 end
            end

            --因为最后一行拉不下去，导致额外处理
            if isLastLine(i) then
                offsetY = offsetY + 15
            end

            Tween.to(node,flyDuration * 3,{x = endPos.x,y = endPos.y - offsetY,scale = {toScale,toScale},ease = CCEaseSineInOut,onComplete = function()
                if self.isDisposed then return end

                node:removeFromParentAndCleanup(false)

                self.bubbleLayer:replaceRealBubble(i,node)

                if i == rewardsNum then
                    safeRunCall(done)
                end

                node:playExtraShowAnim()
            end})
        end})
    end
end

return RankRewardPanel
