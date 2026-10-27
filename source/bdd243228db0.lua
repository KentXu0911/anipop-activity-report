
local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local MarkEventCenter = require "amf.feature.dailyreward.mark.event.MarkEventCenter"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local ACT_NAME = "TeamCamping"
local ResConfig = require"amf.feature.localactivity.teamcamping.meta.ResConfig"
local Manager = class("Manager",BaseFeatureManager)
local LOCAL_PATH = 'amf.feature.localactivity.'..string.lower( ACT_NAME )
local Meta = require(LOCAL_PATH .. '.const.TeamCampingConst.lua')
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local ActivityFakeIconFactory = require "amf.feature.mainscene.module.icon.util.ActivityFakeIconFactory"
local FRIEND_GO_TIP_REMINDER_OWNER = "teamCampingFriendGoIconTip"

local function isDataDrivenIcon(icon)
    return icon and not icon.isDisposed and type(icon.refreshProvider) == "function"
end

local ActivityIconButton = require "amf.feature.mainscene.module.icon.view.ActivityIconButton"

local function isLegacyActivityIcon(icon)
    return icon and icon:is(ActivityIconButton)
end

function Manager:_getConstPath()
    return LOCAL_PATH .. '.const.TeamCampingConst.lua'
end

function Manager:_getModelPath()
    return LOCAL_PATH .. '.model.TeamCampingModel.lua'
end

function Manager:setHeartBeatManager(mgr)
    self._heartBeatManager = mgr
end

function Manager:getLocalDataServer()
    return self:getModel()
end

function Manager:getData()
    return self:getModel()
end

function Manager:getConst()
    return Meta
end

function Manager:getFuncId()
   return self:getConst().actId
end

function Manager:closeAll(callType)
    self:notify( self:getBaseEvent().kCloseAllPanel )
    if self.model then

        self.model:closeAll(callType)
    end
end

function Manager:setModel(model)
    self.model = model
end

function Manager:_init()
    self:registerActProps()
    self:registerActLinkage()
    self.iconCanChangePower = true
    local TeamCampingDc = require"amf.feature.localactivity.teamcamping.dc.TeamCampingDC"
    self.dc= TeamCampingDc
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
    PropEventCenter:register(PropEvent.RESOLVE_ICON, self._onResolveIcon, self)
end

function Manager:registerActProps()
    require ("amf.feature.localactivity.teamcamping.prop.AMFProp_54316")
    require ("amf.feature.localactivity.teamcamping.prop.AMFProp_54317")
    require ("amf.feature.localactivity.teamcamping.prop.AMFProp_54318")
    require ("amf.feature.localactivity.teamcamping.prop.AMFProp_54322")
end

function Manager:addActItem(reward)
    if reward.itemId == Meta.powerBuffId1 then
        self:getData():add50BuffEndTime(reward.num)
    elseif reward.itemId == Meta.powerBuffId2 then
        self:getData():add20BuffEndTime(reward.num)
    elseif reward.itemId == Meta.scoreBuff20 then
        self:getData():addScoreBuffEndTime(reward.num)
    elseif reward.itemId == Meta.collectionId then
        self:setPower(self:getPower() + reward.num)
    end
end

function Manager:createIcon(...)
    return GameItemCreator:getPropIcon(...)
end

function Manager:registerActLinkage()
    --todo

    MarkEventCenter:register(MarkEvent.MARK_PREOPEN_CHECK, self.onMarkPreOpenEvent, self)
end
-- 检测引导标记
function Manager:hasGuideIndex(index)
    local hasIndex = self:getModel():hasGuide(index)

    return hasIndex
end

-- 设置引导标记
function Manager:addGuideIndex(index, needSaveLocal)
    self:getModel():setGuide(index)
    local ActCommonHttp = require 'amf.middleware.activity.http.ActCommonHttp'
    ActCommonHttp:setActGuideFlag(self:getConst().actId, index)
end


-- 获取需要启动的额外功能列表
function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "Download",
        },
        {
            key = "Panel",
        },
        {
            key = "Rewards",
        },
        {
            key = "Haptics",
            path = {
                plugPath = "amf.feature.localactivity.teamcamping.plug.HapticsPlug",
                const = self:_getConstPath()
            },
        },
        {
            key = "ActSent",
            path = {
                plugPath = "amf.middleware.activitylinkage.ability.sendextraprop.plug.ActSentPlug",
                const = self:_getConstPath()
            },
        },
        {
            key = "ActSend",
            path = {
                plugPath = "amf.feature.localactivity.teamcamping.plug.TeamCampingSendPlug",
                const = self:_getConstPath()
            },
        },
        {
            key = "DC",
        },
    }
end



-- 震动
function Manager:playHaptics(type)
    self:callHapticsFunc("playHaptics", type)
end

-- 资源加载
function Manager:loadRes(delegate)
    delegate = delegate or {}
    if not delegate.resList then
        safeRunCall(delegate.failCallback)
        return
    end
    self:callDownloadFunc("getAssetsUtil"):loadMiniFiles(delegate.resList)
        :next(delegate.successCallback, delegate.failCallback)
end

function Manager:flyCollection(reward, startWorldPos,  bubbleScale,innerFlyEndCall)
    if not innerFlyEndCall and type(bubbleScale) == "function" then
        innerFlyEndCall = bubbleScale
        bubbleScale = nil
    end
    if type(innerFlyEndCall) == "number" then
        -- he_log_error("innerFlyEndCall=number")
        innerFlyEndCall = nil
    end
    local actIcon = self:getActivityIcon()
    if not isSafeCocosObj(actIcon) then
        safeRunCall(innerFlyEndCall)
        return
    end
    local isIconV2 = isDataDrivenIcon(actIcon)

    local scene = Director:sharedDirector():getRunningScene()
    if scene and scene:is(UBFGamePlayScene) then
        safeRunCall(innerFlyEndCall)
        return
    end

    local function createFakeIcon()
        if isIconV2 then
            return ActivityFakeIconFactory:create(actIcon)
        end
        local iconBtn = actIcon:clone()
        local isLegacyIcon = isLegacyActivityIcon(iconBtn)
        if isLegacyIcon then
            local nowScore = self:getPower()
            local addNum = reward.num
            iconBtn:setPower(nowScore - addNum)
        end
        iconBtn.onCustomCloseAction = function(obj,endCall)
            local function closeIcon()
                iconBtn:runAction(ActionUtil:sequence({
                    CCScaleTo:create(0.4,0),
                    CCCallFunc:create(function()
                        safeRunCall(endCall)
                        safeRunCall(innerFlyEndCall)
                    end)
                }))
            end
            if isLegacyIcon then
                iconBtn:rollNumber(closeIcon)
            else
                closeIcon()
            end
        end
        return iconBtn
    end

    local collectEndWorldPos = actIcon:getPositionInWorldSpace()

    local function iconCreator(  )
        local icon = self:createIcon(reward)
        return icon
    end
    local RewardFlyHelper = require"amf.feature.localactivity.processgiftautopopup.RewardFlyHelper"
    local flyEndCall = isIconV2 and innerFlyEndCall or function() end
    RewardFlyHelper:rewardFlyFunc(true, reward, startWorldPos, collectEndWorldPos, iconCreator,
    flyEndCall, CCSizeMake(126,126), createFakeIcon, 0.7)
end

function Manager:getPower()
    local actInfo = self:getActInfo()
    if not actInfo then return self:getData():getDataByKey("power",0) or 0  end
    local extra = {}
    if actInfo.extra and actInfo.extra ~= "" then
        extra = table.deserialize(actInfo.extra)
    end
    if extra and extra.power then
        return tonumber(extra.power) or 0
    else
        return self:getData():getDataByKey("power",0) or 0
    end

end

function Manager:getActInfo()
    return self:callActFunc("getActInfo")
end

function Manager:setPower(score)
    self:getData():setValue("power", score)
    local actInfo = self:getActInfo()
    if not actInfo then return end
    if actInfo.extra and actInfo.extra ~= "" then
        local extra = table.deserialize(actInfo.extra)
        if extra and extra.power then
            extra.power = score
            actInfo.extra = table.serialize(extra)
        end
    end

    local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
    ActivityEventCenter:dispatch(ActivityEvent.SET_ACT_INFO,actInfo)
    local icon = self:getActivityIcon()
    if icon and not isDataDrivenIcon(icon) then
        icon:updateState()
    end
end


function Manager:isInRewardTime()
    local hasGetRewards = self:getData():getDataByKey("bigReward",false)
    return  self:getData():isActInReward() or hasGetRewards
end

function Manager:openEnergyPanel(closeCallback,extra)
    if self:isInRewardTime() then
        local powerBuffText = ResConfig:getTextConfig().PowerBuff or {}
        CommonTip:showTip(powerBuffText.RewardTimeSettleHint or "领奖期啦，\n领奖完成后铲子会结算成资源~")
        return
    end
    local Meta = self:getConst()
    local vm
    local Builder = self:callActSentFunc("getEnergyPanelBuilder")
    local userState = self:getUserState()
    if extra and extra.testState then
        userState = extra.testState
    end
    -- local stage = self:getStageFromAct()
    -- local t1 = self:isInLevelState() and 2 or 1
    -- local t2 = stage
    local panelId = UICreateUtil:getPanelId("EnergyPanel")
    -- config.sendDC( 'show', 'forward_guide',{panel_id = panelId,t1 = t1,t2 = t2} )
    self.dc:power_show({
        panel_id = panelId,
        t1 = extra.from
    })
    local collectionMeta = Meta.collectionMeta
    local topLv =  _G.amfBean("LevelUnLockManager"):getLocalTopLevel(false)
    local myTopLv = _G.getTopLevelId()

    local topConfig = {}
    local iconScale = 0.4
    if userState == Meta.State.kFMJ then
        topConfig = {
            title = "非满级玩家闯关获取",
            iconCreator = function()
                local icon = GameItemCreator:getPropIcon({
                    itemId = Meta.collectionId,
                    num = 1
                })
                icon:setScale(0.4)
                return icon
            end,
            layers = {
                {
                    nodeList = {
                        {
                            title = "过关可得",
                            num = 10,
                        },
                        {
                            title = "首闯困难关",
                            num = 20,
                            flagColor = "green",
                            flagText = "困难关",

                        },
                        {
                            title = "首闯超难关",
                            num = 50,
                            flagColor = "purple",
                            flagText = "超难关",
                        },
                    },
                    btnConfig = {
                        str = "去闯关",
                        callback = function()
                            vm:onPassBtnTapped()
                            self.dc:power_click({
                                panel_id = panelId,
                                t1 = 1 ,
                            })
                        end
                    }
                }
            }
        }
    elseif userState == Meta.State.kOther then
        topConfig = {
            title = "满级玩家闯关获取",
            iconCreator = function()
                local icon = GameItemCreator:getPropIcon({
                    itemId = Meta.collectionId,
                    num = 1
                })
                icon:setScale(0.4)
                return icon
            end,
            layers = {
                {
                    nodeList = {
                        {
                            title = "成功补星",
                            imgCreator = function()
                            local icon = Sprite:createWithSpriteFrameName("other/iconV2/ui_icon_star_02_v2")
                                icon:setScale(0.7)
                                return icon
                            end,
                            num = 10,
                        },
                        {
                            title = "成功补彩星",
                            imgCreator = function()
                            local icon = Sprite:createWithSpriteFrameName("other/iconV2/ui_icon_star_01_v2")
                                icon:setScale(0.7)
                                return icon
                            end,
                            num = 20,
                        },
                    },
                    btnConfig = {
                        str = "去补星",
                        callback = function()
                            vm:onStarBtnTapped()
                            self.dc:power_click({
                                panel_id = panelId,
                                t1 = 3,
                            })
                        end
                    }
                },
                {
                    nodeList = {
                        {
                            title = "挑战精英关",
                            imgCreator = function()
                            local icon = Sprite:createWithSpriteFrameName("TeamBuilding_TempRes/EnergyPanel/hideFlower")
                            icon:setScale(1)
                            return icon
                            end,
                            num = 10,
                        },
                    },
                    btnConfig = {
                        str = "去精英关",
                        callback = function()
                            vm:onHideBtnTapped()
                            self.dc:power_click({
                                panel_id = panelId,
                                t1 = 2,
                            })
                        end
                    }
                },
            }
        }
    elseif userState == Meta.State.kFMZ then
        topConfig = {
            title = "满级满彩玩家闯关获取",
            iconCreator = function()
                local icon = GameItemCreator:getPropIcon({
                    itemId = Meta.collectionId,
                    num = 1
                })
                icon:setScale(0.4)
                return icon
            end,
            layers = {
                {
                    commonTitle = "首闯随机挑战",
                    nodeList = {
                        {
                            num = 20,
                            flagColor = "red",
                            flagText = "普通关",
                        },
                        {
                            num = 50,
                            flagColor = "red",
                            flagText = "进阶关",
                        },
                    },
                    btnConfig = {
                        str = "去随机挑战",
                        callback = function()
                            vm:onRandomBtnTapped()
                            self.dc:power_click({
                                panel_id = panelId,
                                t1 = 4,
                            })
                        end
                    }
                },
                {
                    nodeList = {
                        {
                            title = "挑战精英关",
                            imgCreator = function()
                            local icon = Sprite:createWithSpriteFrameName("TeamBuilding_TempRes/EnergyPanel/hideFlower")
                            icon:setScale(1)
                            return icon
                            end,
                            num = 10,
                        },
                    },
                    btnConfig = {
                        str = "去精英关",
                        callback = function()
                            vm:onHideBtnTapped()
                            self.dc:power_click({
                                panel_id = panelId,
                                t1 = 2,
                            })
                        end
                    }
                },
            }
        }
    else
        topConfig = {
            title = "满级满星玩家闯关获取",
            iconCreator = function()
                local icon = GameItemCreator:getPropIcon({
                    itemId = Meta.collectionId,
                    num = 1
                })
                icon:setScale(0.4)
                return icon
            end,
            layers = {
                {
                    commonTitle = "首闯随机挑战",
                    nodeList = {
                        {
                            num = 20,
                            flagColor = "red",
                            flagText = "普通关",
                        },
                        {
                            num = 50,
                            flagColor = "red",
                            flagText = "进阶关",
                        },
                    },
                    btnConfig = {
                        str = "去随机挑战",
                        callback = function()
                            vm:onRandomBtnTapped()
                            self.dc:power_click({
                                panel_id = panelId,
                                t1 = 4,
                            })
                        end
                    }
                },
                {
                    nodeList = {
                        {
                            title = "刷分成功",
                            -- imgCreator = function()
                            --     local icon = Sprite:createWithSpriteFrameName("TeamBuilding_TempRes/EnergyPanel/hideFlower")
                            --     icon:setScale(0.7)
                            --     return icon
                            -- end,
                            num = 10,
                        },
                    },
                    btnConfig = {
                        str = "去刷分",
                        callback = function()
                            vm:onScoreBtnTapped()
                            self.dc:power_click({
                                panel_id = panelId,
                                t1 = 5,
                            })
                        end
                    }
                },
            }
        }
    end
    topConfig.extraString = "活动正式开始后可通过闯关获取"


    local titleNode = nil
    local MultiLabel = require"amf.middleware.ui.kit.component.multilabel.MultiLabel"
    if self:getPower() < 10 then
        local icon = self:createIcon({
            itemId = Meta.collectionId,
            num = 1
        })
        icon:setScale(0.5)
        local powerBuffText = ResConfig:getTextConfig().PowerBuff or {}
        local label = MultiLabel:createEasyMultiLabel(CCSizeMake(300,0),{
            icon, powerBuffText.NotEnough or "铲子不足"
        },{
            fontSize = 38,
            color = hex2ccc4("689648ff")
        })
        label:setAnchorPoint(ccp(0.5,0.5))
        titleNode = label
    end

    local builder = Builder.new()
    :setTitle(titleNode,30)
    :setActKey(Meta.actKey)
    :setCloseCallback(function()
        self:setActivityLinkageStatus()
        safeRunCall(closeCallback)
    end)
    :setIconCreateFunc(function()
        local icon = self:createIcon({
            itemId = self:getConst().collectionId,
        })
        icon:setScale(iconScale)
        return icon
    end)
    -- :setPanelColorType(_G.PanelColorTypeConfig.kMatchFestival2025Map)
    :setCloseAllFunc(function()
        self:closeAll()
    end)
    :setActCallback(function(actKey)
        self.dc:power_click({
            panel_id = panelId,
            t1 = actKey ,
        })
    end)
    :setTopConfig(topConfig)
    :setCacheKey(tostring(self:getConst().actId))
    :setPreheatCanGet(false) -- 这个活动预热期出不了板子
    :setBuffParams({
        getEndTime = function()
            if _G.pcTest then return TimeKit:timeInSec() + math.random(1,3600) end
            local buffList = self:getData():getDataByKey("collectBuffList",{})
            local endTime = 0
            for k,v in pairs(buffList) do
                if tonumber(v.endTime)/1000 > TimeKit:timeInSec() then
                    if endTime  == 0 then
                        endTime = tonumber(v.endTime)/1000
                    else
                        endTime = math.min(endTime,tonumber(v.endTime)/1000)
                    end
                end
            end
            return endTime
        end,
        getBuffTimes = function()
            if _G.pcTest then return 2 end
            local buffList = self:getData():getDataByKey("collectBuffList",{})
            local times = 1
            for k,v in pairs(buffList) do
                if tonumber(v.endTime)/1000 > TimeKit:timeInSec() then
                    times = times * Meta.buffTimesMap[v.itemId]
                end
            end
            return times
        end,
    })
    if builder.setIgnoreActRedDot then
        -- builder = builder:setIgnoreActRedDot(true)
    end
    vm = builder:build()
    vm:popout()
    self:setActivityLinkageStatus()
    self:callPanelFunc("managePanelVM", vm)
end

---rewards
function Manager:addRewardsWhenBought(goodsId, rewardItems, params)
    self:callPlug("Rewards","addRewardsWhenBought",goodsId, rewardItems, {
        dcExtra = params
    })
end

-- 商城加奖励
function Manager:addRewardsForShop( rewardBean, params ,dateAddEndCall, evt )
    self:callPlug("Rewards","addRewardsForShop",rewardBean, {
        dcExtra = params
    },dateAddEndCall,evt)
end

-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    self:callPlug("Rewards", "addRewardsNormal", rewardItems, {
        dcExtra = params,
    })
end


function Manager:buildAndUpdateIcon(donotCreateNewFlag)
    local icon=self:getActivityIcon()
    if isLegacyActivityIcon(icon) then
        icon:resetAnim()
        -- icon:resetTipAnim(donotCreateNewFlag)
    end
end


function Manager:getActivityIcon()
    return self:callActFunc("getActIcon")
end

function Manager:refreshActivityIconV2(reason, icon)
    icon = icon or self:getActivityIcon()
    if not isDataDrivenIcon(icon) then
        return false, "notIconV2"
    end

    local ok, refreshed, detail = pcall(icon.refreshProvider, icon, reason)
    if not ok then
        return true, false, refreshed
    end
    return true, refreshed, detail
end

function Manager:acquireActivityIconV2ReminderSuppression(icon, reason)
    if not isDataDrivenIcon(icon) or type(icon.acquireReminderSuppression) ~= "function" then
        return false
    end

    local ok = pcall(
        icon.acquireReminderSuppression,
        icon,
        FRIEND_GO_TIP_REMINDER_OWNER
    )
    if not ok then
        if type(icon.hideAllReminderUI) == "function" then
            pcall(icon.hideAllReminderUI, icon)
        end
        return false
    end
    self._friendGoTipReminderIconV2 = icon
    return true
end

function Manager:releaseActivityIconV2ReminderSuppression(icon, reason)
    icon = self._friendGoTipReminderIconV2 or icon
    self._friendGoTipReminderIconV2 = nil
    if not icon or type(icon.releaseReminderSuppression) ~= "function" then
        return false
    end

    self:refreshActivityIconV2(reason, icon)
    pcall(
        icon.releaseReminderSuppression,
        icon,
        FRIEND_GO_TIP_REMINDER_OWNER
    )
    return true
end

function Manager:getTipList()
    local actInfo = self:getActInfo()
    if not actInfo or not actInfo.extra then
        return {}
    end
    local extra = table.deserialize(actInfo.extra or "{}")
    if extra and extra.tipList then
        -- printx(41,"extra.tipList",tts(extra.tipList))
        return extra.tipList or {}
    end
    return {}
end


function Manager:getTipSortedList()
    local tipList = self:getTipList()
    local TipEnum = Meta.TipEnum
    local ret={
        [TipEnum.FriendGo]={},
        [TipEnum.Upgrade]={},
        [TipEnum.FindFriend]={},
        [TipEnum.GetNewInvitation]={},
        [TipEnum.GetFriendInvitation]={}
    }
    -- 遍历传入的 data 表
    for _, item in pairs(tipList) do
        local entry = {
            type = item.type,
            headUrl = item.headUrl,
            frame = item.frame and tonumber(item.frame),
            add = item.add,
			levelUp = item.levelUp
        }

        -- 根据 type 分类
        if item.type == 1 then
            table.insert(ret[TipEnum.GetNewInvitation], entry)
        elseif item.type == 2 then
            table.insert(ret[TipEnum.GetFriendInvitation], entry)
        elseif item.type == 3 then
            table.insert(ret[TipEnum.FriendGo], entry)
        elseif item.type == 4 then
            table.insert(ret[TipEnum.Upgrade], entry)
        end
    end
    table.sort(ret[TipEnum.FriendGo], function(a, b)
        return a.add > b.add
    end)

	table.sort(ret[TipEnum.Upgrade], function(a, b)
			if a.levelUp > b.levelUp then
				return true
			else if a.levelUp < b.levelUp then
				return false
			else
				return a.add > b.add
			end
		end
    end)

    if self:needFindFriend() then
        ret[TipEnum.FindFriend]={{}}
    end

    for k, v in pairs(ret) do
        if #v == 0 then
            ret[k] = nil
        end
    end

    local last = self._lastShowTipList or {}
    local function reset()
        self._lastShowTipList = ret
        self._nextTipIndex = 1
        self._nextEnumIndex = 1
    end

    local function compare(t1, t2)
        -- 先比较键数量
        if #t1 ~= #t2 then return false end

        -- 比较每个键的值
        for k, v in pairs(t1) do
            if not t2[k] then return false end
            for kk, vv in pairs(v) do
                if vv ~= t2[k][kk] then return false end
            end
        end
        return true
    end

    for _, v in pairs(TipEnum) do
        if (ret[v] and last[v] and not compare(ret[v], last[v]))
            or (last[v] and not ret[v]) or (not last[v] and ret[v]) then
            reset()
            break
        end
    end

    return self._lastShowTipList
end

function Manager:needFindFriend()
    return #(self:getData():getTeamGroups())<=3
end

function Manager:checkIconTip(config)
    if not self:isOpen() then return end
    local tipList = self:getTipSortedList()
    if not tipList then return end

    local TipEnum = Meta.TipEnum
    local checkList = {
        TipEnum.Upgrade,
        TipEnum.FriendGo,
        TipEnum.GetFriendInvitation,
        TipEnum.GetNewInvitation,
        TipEnum.FindFriend
    }
    self._nextEnumIndex = self._nextEnumIndex or 1
    if self._nextEnumIndex > #checkList then
        return
    end

    for i = self._nextEnumIndex, #checkList do
        local tipEnum = checkList[i]
        if i > self._nextEnumIndex then
            self._nextTipIndex = 1
        end
        if tipList[tipEnum] then
            for j = self._nextTipIndex, #tipList[tipEnum] do
                self._nextTipIndex = j + 1
                self._nextEnumIndex = i

                local creatorDelegate, typeIndex = self:showTipType(tipEnum, tipList[tipEnum][j])
                if creatorDelegate then
                    local delegate = {
                        iconKey = tostring(self:getConst().actId),
                        iconType = IconTipType.MESSAGE,
                        creatorDelegate = creatorDelegate,
                        typeIndex = typeIndex,
                        config = config,
                        popFunc = function()
                            self:buildAndUpdateIcon()
                        end
                    }
                    local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
                    IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, delegate)
                    return
                end
            end
        end
    end
end

function Manager:showTipType(tipEnum, data)
    local openAddFriend = false
    local TipEnum = Meta.TipEnum
    if tipEnum== TipEnum.FindFriend or tipEnum == TipEnum.GetNewInvitation or tipEnum == TipEnum.GetFriendInvitation then
        openAddFriend = true
        if not self:needFindFriend() then
            return
        end
    end

    local creatorDelegate, typeIndex
    if tipEnum == TipEnum.FriendGo then
        local headInfo = self:getHeadInfo(data)
        creatorDelegate = self:createTip(headInfo, nil, "队友走了一大步", openAddFriend)
        creatorDelegate.cutInCallback = function()
            local icon = self:getActivityIcon()
            if isSafeCocosObj(icon) and self:hasHint() then
                if isDataDrivenIcon(icon) then
                    self:acquireActivityIconV2ReminderSuppression(icon, "teamCampingIconTipCutIn")
                    return
                end
                if icon:getRedDot() then
                    icon:getRedDot():setVisible(false)
                end
            end
        end

        creatorDelegate.endCallback = function()
            local icon = self:getActivityIcon()
            if self:releaseActivityIconV2ReminderSuppression(icon, "teamCampingIconTipEnded") then
                return
            end
            if isSafeCocosObj(icon) and self:hasHint() then
                icon:getRedDot():setVisible(true)
            end
        end
        typeIndex = 1
    elseif tipEnum == TipEnum.Upgrade then
        local headInfo = self:getHeadInfo(data)
        creatorDelegate = self:createTip(headInfo, "up", "可以升级啦~", openAddFriend)
        typeIndex = 2
    elseif tipEnum == TipEnum.FindFriend then
        creatorDelegate = self:createTip(nil, "", "找个好朋友~", openAddFriend)
        typeIndex = 3
    elseif tipEnum == TipEnum.GetNewInvitation then
        creatorDelegate = self:createTip(nil, "redDot", "收到朋友邀请", openAddFriend)
        typeIndex = 4
    elseif tipEnum == TipEnum.GetFriendInvitation then
        creatorDelegate = self:createTip(nil, "friend", "收到好友邀请", openAddFriend)
        typeIndex = 5
    end
    return creatorDelegate, typeIndex
end

function Manager:getHeadInfo(data)
    if not data.headUrl then
        return nil
    end
    return {
        headUrl = data.headUrl,
        headFrame = data.frame or HeadFrameType.kNormal
    }
end

function Manager:createTip(headInfo, showNode, str, openAddFriend)
    local delegate = {}
    delegate.tipsType = HomeIconTipsType.NORMAL_RECT
    delegate.text = str
    delegate.iconOffset = ccp(-30,40)
    delegate.redPointType = lua_switch(showNode){
        ["friend"] = 1,
        ["up"] = 2,
    }
    if showNode == "redDot" then
        delegate.redPointCreate = function()
            local icon =  AMFCompHelper:createSimpleRedDot()
            icon:setScale(0.7)
            return icon
        end
    end
    delegate.profile = headInfo
    delegate.iconTouchCallback = function()
        self:openActivity(nil, {openAddFriend = openAddFriend}, true)
    end
    delegate.duration = 5
    return delegate
end

function Manager:onActUBFStartLevel()
    -- 重置Icon为不弹出tip
    if self.iconTip then
        self.iconTip:stopTip()
    end

    self:buildAndUpdateIcon(true)

    -- 关闭icon数字可变动
    if self:getData():isActInMain() then
        self.iconCanChangePower = false
    end
end


function Manager:onActBeforeStartLevel()
    -- 关闭icon数字可变动
    if self:getData():isActInMain() then
        self.iconCanChangePower = false
    end
end

-- 在新关开启的指定时间内（暂定4小时），玩家主线关满星前，闯头部新关不触发关卡内结算面板点叉的场景4强弹
function Manager:ignoreForTopLevelPlayer()
    local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    if userState == _G.UserStateConst.UserSegmentState.MHZC  then
        return false
    end

    if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then
        return false
    end

    return true
end

function Manager:checkPopFunctionStage4()
    return false
end

function Manager:popFunctionStage4(onHandleOver)
    safeRunCall(onHandleOver)
end


function Manager:updateTipView()
    if not self:isEnabled() then
        return
    end
    self:callActFunc("updateTipView")
end

function Manager:needAwardShow()
    local powerNum = self:getPower() or 0
    if powerNum > 0 then return true end
    return false
end



function Manager:hasHint()
    if not self:getData():isBaseDataEnabled() then return false end
    if self:getData():isActInReward()  then return false end
    if self:getData():getDataByKey("haveInvite") then return true end
    for k,v in pairs(self:getData():getDataByKey("buildList",{})) do
        if v.mateProgress > v.mateLastProgress then
            return true
        end
    end
end

function Manager:hasReward()
    if not self:getData():isBaseDataEnabled() then return false end
    return self:hasBuildLvRewards()
    or self:hasBigRewards()
    -- or self:hasPersonalRewards()
    or self:hasAwardRewards()
end

function Manager:hasAwardRewards()
    if not self:getData():isBaseDataEnabled() then return false end
    if self:getData():isActInReward() then
        return self:getPower() > 0
    else
        return false
    end

end

function Manager:hasBuildLvRewards()
    local buildList = self:getData():getDataByKey("buildList",{})
    local dataList = {}
    for k,v in pairs(buildList) do
        local value,min,max,isFullLevel = self:getData():getBuildProgress(v.buildId)
        local isLvUp = value >= max
        if isLvUp then
            return true
        end
    end
end

function Manager:hasBigRewards()
    local hasGetRewards = self:getData():getDataByKey("bigReward",false)
    for id = 1,4 do
        local lv = self:getData():getBuildNowLv(id)
        if lv < 5 then
            return false
        end
    end
    return not hasGetRewards
end

function Manager:getShowMsgNum()
    if not self:isEnabled() then return 0 end
end


function Manager:isEnabled()
    local isLogicEnabled = self:getData():isDataEnabled()
    local isResEnabled = self.downloadPlug:checkDownloadSuccess()
    local hasGetRewards = self:getData():getDataByKey("bigReward",false)
    if Meta.disableAfterGetReward then
        isLogicEnabled = isLogicEnabled and not hasGetRewards
    end
    if not isResEnabled and (self:getData():isActInMain() or self:getData():isActInReward()) then
        self:callPlug("Download","startDownload")
    end
    return isLogicEnabled and isResEnabled
end


function Manager:isOpen()
    local hasGetRewards = self:getData():getDataByKey("bigReward",false)
    return self:isEnabled() and not hasGetRewards
end


function Manager:getPeriodId()
    local localActPeriodId =  self:getData():getDataByKey("period",0) or 0
    return tonumber(localActPeriodId) or 0
end

--解析活动数据
function Manager:parseData(data)
    -- local localActPeriodId =  self:getPeriodId()
    -- if data.period ~= localActPeriodId then
    --     self:getData():clearAll()
    -- end
    -- period信息在配置中，放在解析后处理
    if data then
        data.isFromServer = true
        self:getData():fromServer(data,nil )
    end
    if not self.hasServerData then
        self:updateTipView()
        self.hasServerData = true
    end

    self:setPower(self:getData():getDataByKey("power",0))

end


function Manager:passDayRefreshData()
    self:getData():onPassDay()
end


function Manager:getDcFeatureAndSource( suffix )
    return self:callRewardFunc("getDcFeatureAndSource", suffix)
end




local ResConfig = require "amf.feature.localactivity.teamcamping.meta.ResConfig"


-- function Manager:isInfiniteGroup()
--     return false
-- end


function Manager:openDescPanel(callback, needAnim, defaultPage)
    self:loadRes({
        resList = ResConfig:getDescPanelAssetsList(),
        successCallback = function ()
            if needAnim == nil then needAnim = false end
            local descPanel
            if not defaultPage then
                defaultPage = 1
            end
            local extra = {
                defaultPage = defaultPage ,
                needAnim = needAnim,
                pageBtnsVisible = true,
                closeCallback = callback,
            }
            local DescPanel_UI = ResConfig:getUIPath("DescPanel")

            local function createWithSource2(source, extra, pageMaxIdx)
                extra = extra or {}
                local pages = {}
                local pageAniNodes = {}
                local uiData = force_require(source)
                local builder = UIBuilder.new( uiData )
                local title = builder:createChild( "title" )
                local commonText = ResConfig:getTextConfig().Common or {}
                local titleText = commonText.MainTitle or "露营吧！朋友"

                local function applyThemeTitleText(node)
                    if not node or node.isDisposed then
                        return
                    end
                    if node.setString then
                        node:setString(titleText)
                    end
                    for _, childName in ipairs({"title1", "title2"}) do
                        local child = node:findChildByName(childName)
                        if child and child.setString then
                            child:setString(titleText)
                        end
                    end
                end

                applyThemeTitleText(title)

                title:findChildByName("title1"):setVisible(extra.defaultPage == 1 )
                title:findChildByName("title2"):setVisible(extra.defaultPage == 2 )
                -- title:findChildByName("title3"):setVisible(false)

                local function genPage(pageName)
                    local page, cls = builder:createChild(pageName)
                    if cls and cls.label_mainLevel then
                        cls.headFrame = cls.label_mainLevel
                        local headFrameId = self:getConst().headFrameTypeId
                        -- local myProfile = UserManager:getInstance().profile
                        local profile = TempProfileRef.new()
                        profile.headFrame = headFrameId
                        profile.headUrl = ""
                        profile.headFrames = {
                            {
                                id = profile.headFrame,
                                expireTime = 0,
                                obtainTime = 0,
                            }
                        }
                        local headImage = HeadImage:create(profile)
                        LayoutUtil:centerReplaceBy(cls.headFrame, headImage, true)
                        LayoutUtil:move(headImage, 0, -2)
                        cls.label_mainLevel = headImage
                        cls.headFrame = headImage
                    end

                    if page then
                        page.childList = cls
                        LayoutUtil:move(page,0,-60)
                        table.insert(pages, page)
                        local aniNodes = {}
                        for i=1, 20 do
                            local checkStep = 'step'..i
                            local cont = false
                            for name, _ in pairs(cls) do
                                if string.ends(name, checkStep) then
                                    table.insert(aniNodes, name)
                                    cont = true
                                    break
                                end
                            end
                            if not cont then
                                break
                            end
                        end
                        table.insert(pageAniNodes, aniNodes)
                        return true
                    end
                end

                genPage("page")
                for i=1, pageMaxIdx do
                    if not genPage("page"..i) then
                        break
                    end
                end

                if not extra.needAnim then
                    pageAniNodes = {}
                end

                local IllustrationPanelVM = require"amf.middleware.ui.kit.panel.other.IllustrationPanelVM"
                local vm
                vm = IllustrationPanelVM.Builder.new()
                            :setTitle(title)
                :setPages(pages)
                :setPageAnimNodeNames(pageAniNodes)
                :setNeedLoadRes(ResConfig:getDescPanelAssetsList())
                :setDefaultPage(extra.defaultPage or 1)
                            :setChangePageCall(function( beforePageIndex, afterPageIndex )
                                if vm and not vm.isDisposed then
                                    title:findChildByName("title1"):setVisible(afterPageIndex == 1 )
                                    title:findChildByName("title2"):setVisible(afterPageIndex == 2 )
                                    -- title:findChildByName("title3"):setVisible(false)
                                end
                            end)
                :setCloseCallback(extra.closeCallback)
                            :setClickBlankSkip(extra.clickBlankSkip or nil):
                            setPanelReadyCallback(function()
                                -- vm:setCloseBtnPos(ccp(671, -61))
                                vm:setTitlePos(ccp(360, -82))
                            end)
                            :build()
                return vm
            end

            local maxIdx = 2
            descPanel = createWithSource2(DescPanel_UI, extra, maxIdx)
            descPanel:popout()
            self:callPanelFunc("managePanelVM", descPanel)
        end,
        failCallback = callback
    })
end


-- 本地缓存
function Manager:saveFlagToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = true end
    local keyStr = 'CommonMgrBaseV2_'..self:getConst().actId..'_'.. key
    if needTime then
        local curTime = TimeKit:timeInSec()
        local dayStartTime = getDayStartTimeByTS(curTime)
        keyStr = keyStr .. ':' .. dayStartTime
    end

    self:getModel():setCache( keyStr, value)
end

function Manager:getFlagFromLocalByKey(key, needTime)
    local keyStr = 'CommonMgrBaseV2_'..self:getConst().actId..'_'.. key
    if needTime then
        local curTime = TimeKit:timeInSec()
        local dayStartTime = getDayStartTimeByTS(curTime)
        keyStr = keyStr .. ':' .. dayStartTime
    end
    return self:getModel():getCache(keyStr, false)
end


function Manager:openPreHeatPanel(callback,delegate)
    -- todo
    self:getModel():requestGetPreInfo(function(evt)
        if not delegate then
            delegate = {}
        end
        local data = evt.data or {}
        delegate.score = data.power
        local TeamCampingPreheatPanelVM = require"amf.feature.localactivity.teamcamping.views.TeamCampingPreheatPanelVM"
        local vm = TeamCampingPreheatPanelVM:create(delegate)
        vm:setCloseCallback(callback)
        vm:popout()
        self:callPlug("Panel", "managePanelVM",vm)
    end,function(evt)
        local errCode = evt and evt.data or nil
        if errCode then
            CommonTip:showTip(localize("error.tip."..tostring(errCode)))
        end
        safeRunCall(callback)
    end)
end


function Manager:getUserState()
    local userState = self:getConst().State.kOther
    local state = _G.amfBean("UserStateManager"):getUserSegmentState()
    if  state ==  _G.UserStateConst.UserSegmentState.FMJ then
        userState = self:getConst().State.kFMJ
    elseif state ==  _G.UserStateConst.UserSegmentState.MHZC then
        userState = self:getConst().State.kMHZC
    elseif state == _G.UserStateConst.UserSegmentState.FMZ then
        userState = self:getConst().State.kFMZ
    else
        userState = self:getConst().State.kOther
    end
    return userState
end


function Manager:getActivityLinkageStatus()
    return self:callActSentFunc("getActivityLinkageStatus")
end


function Manager:setActivityLinkageStatus(status)
    status = status or self:getActivityLinkageStatus()
    local str = table.serialize(status)
    self:getModel():setCache("ActivityLinkageStatus",str)
end

function Manager:checkActivityLinkageStatusChange()
    local status = self:getActivityLinkageStatus()

    local str = self:getModel():getCache("ActivityLinkageStatus", "")
    if str ~= "" then
        local oldStatus = table.deserialize(str)
        for k, v in pairs(status) do
            if v and v ~= oldStatus[k] then
                return true
            end
        end
        return false
    end
    return true
end

-- 签到banner
function Manager:onMarkPreOpenEvent(evt)
    if not self:checkMarkBannerEnable() then return end

    local contextList = evt:getData()
    local context = MarkPreOpenContext.new()
        :setPriority(ActFestivalConst.Priority.LINK_ACTIVITY)
        :setExtLoadFiles({
            "amf/activity/teamcamping/materials/banner.png"
        })
        :setEnabledCheckFunc(function()
            return self:checkMarkBannerEnable()
        end)
        :setPreOpenFunc(function(callback)
            safeRunCall(callback)
        end)
        :setBannerCreator(function()
            local banner = Sprite:create("amf/activity/teamcamping/materials/banner.png")

            local endTime = self:getData():getMainEndTime()
            local label = TTFLabel:createWithConfig({
                text = "",
                fontSize = 18,
                hA = kCCTextAlignmentCenter,
                vA = kCCVerticalTextAlignmentCenter,
                outlineColor = hex2ccc4("00000050"),
                outlineSize = 2,
            })
            label:setAnchorPoint(ccp(0.5, 0.5))
            label:setPositionXY(banner:getContentSize().width / 2 - 6, banner:getContentSize().height / 2 - 33)
            banner:addChild(label)
            local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
            TimeUtil:countDownLabel(label, endTime, nil, "已结束", nil, YH_REF_MAP.noEarClock_t)

            local UIButton = require "amf.middleware.ui.kit.component.button.UIButton"
            local btn = UIButton:createButton({
                scaleMode = UIButtonConfig.BtnScales.k50,
                str = "去看看",
                touchFunc = function()
                    if not self:checkMarkBannerEnable() then
                        CommonTip:showTip(self:getConst().actChName .. "活动已结束!")
                        return
                    end
                    _G.amfBean("AutoPopupMgr"):resetPopup()
                    MarkEventCenter:dispatch(MarkEvent.MARK_CLOSE)
                    self:callActFunc("openActivity", {
                        extra = { from = 6 },
                        userClick = true,
                    })
                end
            })
            banner:addChild(btn)
            btn:setPositionXY(514,54)
            return banner
        end, ccp(305, 91))
    table.insert(contextList, context)
end

function Manager:openActivity(closeCallback, extra, userClick)
        self:callActFunc("openActivity", {
            extra =  extra,
            userClick = userClick,
            failCallback = closeCallback,
            endCallback = closeCallback,
    })
end


function Manager:checkMarkBannerEnable()
    if not self:isOpen() then return end
    local curTime = TimeKit:timeInSec()
    local beginTime = self:getData():getMainBeginTime()
    local mainEndTime = self:getData():getMainEndTime()
    if curTime < beginTime or curTime >= mainEndTime then return false end
    return true
end

function Manager:getMainSceneButtonShowConfig()
    local scoreBuffRate, endTime = self:getCurAvailableBuffAndEndTime({
        levelId = _G.getTopLevelId(),
        levelScene = UBFLevelSceneType.kMain,
    })
    endTime = math.floor(tonumber(endTime) / 1000)

    local showConfig = {}
    local nowTime = TimeKit:timeInSec()
    if endTime and endTime > nowTime then
        table.insert(showConfig,
            {
                uniqueId =  _G.BuffTypeConfig.SCORE_BUFF,
                actId = self.getConst().actId,
                actName = self.getConst().actChName,
                showStr = "",
                endTime = endTime,
                rate = scoreBuffRate + 1,
            }
        )
    end

    if not self:isOpen() then
        return showConfig
    end

    local buffRate, buffEndTime = self:getData():getBuffRateAndTime()
    if buffEndTime and buffEndTime > nowTime then
        table.insert(showConfig,
            {
                uniqueId = "TeamBuildingDoubleBuff",
                actId = self.getConst().actId,
                actName = self.getConst().actChName,
                iconCreator = function()
                    return self:createIcon({itemId = Meta.collectionId, num = 1})
                end,
                endTime = buffEndTime,
                rate = buffRate,
            }
        )
    end
    return showConfig
end

function Manager:refreshHeartBeatEnabled()
    if not self._heartBeatManager then
        return
    end
    if self:isEnabled() then
        self._heartBeatManager:addSourceType(HeartBeatConst.SourceType.TEAM_CAMPING)
    else
        self._heartBeatManager:removeSourceType(HeartBeatConst.SourceType.TEAM_CAMPING)
    end
end

---------------------------------- 关卡内 begin--------------------------------

function Manager:isEnabledInLevel(data)
    return self:isOpen()
end

--非满级必须首闯top关
function Manager:checkIsTopFirstPlay()
    return true
end

function Manager:checkIsLevelLibFirstPlay( data )
    -- body
    if LevelSceneFunc:isFullLevelLib(data.levelScene) then
        local isFsllFirstPlay = _G.amfBean("FullStarLevelLibManager"):getModel():getContinuousLose() == 0
        return isFsllFirstPlay
    end
    return false
end

--加成时间
function Manager:getTimeLimitRateEndTime()
    local rate,time = self:getData():getBuffRateAndTime()
    return time or 0
end

function Manager:getTimeLimitBuffRate()
    local rate,time = self:getData():getBuffRateAndTime()
    return rate or 0
end

function Manager:getScoreBuffEndTime()
    return self:getData():getDataByKey("scoreBuff20EndTime") or 0
end

--关卡内活动启动数据
function Manager:getInLevelActData(levelId, runTime)
    local fullLevelLibOk = LevelSceneFunc:isFullLevelLib(runTime.levelScene)
    local fsllDifficultFlag = fullLevelLibOk and _G.amfBean("FullStarLevelLibManager"):getModel():getLevelDifficultFlagByLevelId(levelId)
    local inLevelActData = {}
    local buffEndTime = self:getTimeLimitRateEndTime()
    --是否有限时buff
    inLevelActData.hasTimeLimiteBuff = (buffEndTime > TimeKit:timeInSec() )
    --限时buff结束时间
    inLevelActData.buffEndTime = buffEndTime
    inLevelActData.timeLimiteBuffRate = self:getTimeLimitBuffRate()
    inLevelActData.fsllDifficultFlag = fsllDifficultFlag
    inLevelActData.isHasStepBuff = true -- 配合rust配置强写一个
    -- printx(16,"getInLevelActData",tts(inLevelActData))
    return inLevelActData
end


--获取分数BUFF加成值跟buff结束时间
function Manager:getCurAvailableBuffAndEndTime()
    -- if not self:isEnabled() then return 0,0 end
    local buffRate = 0.2
    local buffEndTime = self:getScoreBuffEndTime()
    return buffRate, tonumber(buffEndTime)
end

function Manager:updatePassLevelData(data, collectionCount)
    -- 获得收集物为0时不必锁定icon的power
    if not collectionCount or collectionCount == 0 then
        self.iconCanChangePower = true
    end
    if not self:isOpen() then return end
    if data.settleMentState and collectionCount and collectionCount > 0 then
        local power = self:getPower()
        self:setPower(power + collectionCount)
        local icon = self:getActivityIcon()
        local isIconV2 = isDataDrivenIcon(icon)
        local isLegacyIcon = isLegacyActivityIcon(icon)
        if isLegacyIcon then
            icon:setPower(power)
        end
        local v2Finished = false
        local function finishIconV2Collection()
            if v2Finished then return end
            v2Finished = true
            self:refreshActivityIconV2("teamCampingCollectionAnimationEnded", icon)
            self.iconCanChangePower = true
        end
        local flyCallBack = function()
            if isIconV2 then
                finishIconV2Collection()
            elseif isLegacyIcon then
                icon:rollNumber(function()
                    self.iconCanChangePower = true
                end)
            else
                self.iconCanChangePower = true
            end
        end
        local sp = self:createIcon({
            itemId = Meta.collectionId,
            num = 1})
        local flyCollectionContext = FlyActCollectionContext.new(self:getFuncId(), {{
            icon = sp,
            num = collectionCount
        }})
        flyCollectionContext:setFinishCallback(flyCallBack)
        if isIconV2 then
            local transactionOk = pcall(
                _G.amfTransaction,
                TransactionEvent.FLY_ACT_COLLECTIONS,
                flyCollectionContext
            )
            if not transactionOk then
                flyCollectionContext:finish()
                if sp and not sp.isDisposed and type(sp.dispose) == "function" then
                    pcall(sp.dispose, sp)
                end
            end
            return
        end
        _G.amfTransaction(TransactionEvent.FLY_ACT_COLLECTIONS, flyCollectionContext)
    end
end


function Manager:onActPlayLevelEnd()
    if not self:isOpen() then return end
end



---------------------------------- 关卡内 end----------------------------------

---------------------------------- RESOLVE_ICON ----------------------------------

function Manager:_onResolveIcon(event)
    local data = event:getData()
    local itemId = data.itemId
    -- 只处理 teamcamping 的收集物和加成道具
    if itemId ~= Meta.collectionId
        and itemId ~= Meta.powerBuffId1
        and itemId ~= Meta.powerBuffId2 then
        return
    end
    -- 根据 themeKey 动态返回对应主题的 collection.png
    local collectionPath = Meta.collectionPath
    data.callback({
        Atlas = "",
        Frame = collectionPath,
        IsPropPng = true,
    })
end

---------------------------------- CUSTOM_GAIN ----------------------------------

function Manager:_onCustomGain(event)
    local reward = event:getData()
    local id = reward.itemId
    if id == Meta.collectionId
        or id == Meta.powerBuffId1
        or id == Meta.powerBuffId2
        or id == Meta.scoreBuff20 then
        self:addActItem(reward)
    end
end

return Manager
