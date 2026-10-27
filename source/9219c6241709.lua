local deferred = require "amf.script.sugar.deferred"
local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
---@class SprintRealPrizeManagerV2 : BaseFeatureManager
local Manager = class("SprintRealPrizeManagerV2", BaseFeatureManager)

Manager.ACT_ID = 4103

function Manager:ctor()
    ---@type SprintRealPrizeModel
    self._model = nil
    ---@type SprintRealPrizeConst
    self._const = nil

    ---@type SprintRealPrize_Config
    self._actConfig = nil
    self._actReady = false
end

function Manager:_init()
    BaseFeatureManager._init(self)
    -- self:registerActProps()

end

function Manager:isEnabled()
    -- self:checkActValid()
    local ret = true

    self:getConfig()
    if self._actConfig and self._actConfig.isSupport() then
        -- ret = self._model:getDataByKey(self._model.F.gotRealReward) -- 领奖期，获奖的
        ret = true
    else
        ret = false
    end

    return ret
end

function Manager:isActReady()
    return self._actReady

end

function Manager:getActSource()
    return "sprintrealprize2/Config.lua"
end

function Manager:getConfig()
    -- local isActResLoaded = _G.amfBean("ActivityMgr"):isActResLoaded(Manager.ACT_ID)
    -- printx(48, "[gk] 4103 isActResLoaded=", isActResLoaded)
    if self._actReady and not self._actConfig then
        local config = require("activity/" .. self:getActSource())
        self._actConfig = config
    end
    return self._actConfig
end


function Manager:checkActValid(source)
    if not source then return false end
    local actInfo = _G.amfBean("ActivityMgr"):getActInfo(self.ACT_ID)
    return actInfo~=nil
end

--活动注入
function Manager:registerActProps()
    self._actReady = true
    if not self.bRegisterItem then
        self.bRegisterItem = true
        require "amf.feature.localactivity.sprintrealprize2.config.AMFProp_SprintRealPrize"
        GiftEventCenter:registerFeature(self)

        if not self._isStage2Check then self:onActEnterStage2() end
    end
end

-- 获取常量路径
function Manager:_getConstPath()
    return "amf.feature.localactivity.sprintrealprize2.config.SprintRealPrizeConst"
end

-- 获取常量
---@return SprintRealPrizeConst
function Manager:getConst()
    -- return self._const
    return BaseFeatureManager.getConst(self)
end

-- 获取model路径
function Manager:_getModelPath()
    return "amf.feature.localactivity.sprintrealprize2.model.SprintRealPrizeModel"
end

function Manager:getDataByKey(key, defaultValue) return self:getModel():getDataByKey(key, defaultValue) end
function Manager:setDataByKey(key, value) return self:getModel():setDataByKey(key, value, true) end

function Manager:isGotRealReward()
    -- do return true end --debug
    if not self._actReady then
        printx(48, "Error, 还没有请求maininfo")
    end
    return self:getDataByKey(self._model.F.gotRealReward)
end

function Manager:isIconShowReward()
    return self:isGotRealReward() and (not self:isContactFilled())
end

-- function Manager:isInActTime()
--     local mainBeginTime = self:getModel():getMainBeginTime()
--     local mainEndTime = self:getModel():getMainEndTime()
--     local now = TimeKit:timeInSec()
--     return (now >= mainBeginTime and now < mainEndTime)
-- end


-- function Manager:createIcon( reward )
--     if reward.itemId == self:getConst().shiwuId then
--         local icon = UICreateUtil:createSpriteFile("amf/activity/sprintrealprize2/materials/collection.png", true)
--         return icon
--     else
--         return GameItemCreator:getPropIcon(reward)
--     end
-- end

----------------------- 加道具 -----------------------------
-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    self:_addRewards(rewardItems, nil, params)
end

-- 不要调用，但需要修改业务逻辑相关添加
function Manager:_addRewards(rewardItems, payType, params)
    local dcFeature, dcSource
    if params and params.dcFeature and params.dcSource then
        dcFeature, dcSource = params.dcFeature, params.dcSource
    end

    _G.GainPropData:create()
        :setFeature(dcFeature)
        :setSource(dcSource)
        :setProps(rewardItems)
        :execute()
    self:refreshStarButton()
end

function Manager:refreshStarButton()
    _G.amfEC:notifyNormal(NormalEvent.USER_ASSET_CHANGE)
end

function Manager:onActPassDay()
    BaseFeatureManager.onActPassDay(self)
    -- local observerNum = self:getObserverNum()
    -- if observerNum > 0 then
    --     self:notify(CollectCardEvent.CLOSE_ALL_PANEL)
    --     CommonTip:showTip('新的一天开始了，数据已更新，\n请尝试重进活动~')
    -- end
end

function Manager:hasRealPrize(rewards)
    local const = self:getConst()
    local realPropId = const.REAL_PROP_ID
    return table.find(rewards or {}, function (rewardItem)
        return rewardItem.itemId == realPropId
    end)
end

function Manager:onActPlayLevelEnd(evt)
    if not self:isEnabled() then return end
    local data = evt:getData()
    if not data.isWin then return end
    if data.isSubMode then return end

    local runtimeRefer = data.runtimeRefer
    local runtime = runtimeRefer and runtimeRefer.value
    if not runtime then return end

    -- 1.判断本次打关是否有效
    local modEndLevelData = runtime:getEndLevelModData(UBFActivityIdConst.kSprintRealPrizeV2)
    local passLevelJson = modEndLevelData and modEndLevelData.passLevelJson
    if not passLevelJson or not passLevelJson.clientMaxLevel then return end

-- TODO 给后端发送协议，确认是否中奖
    -- 2.判断本次打关是否达到N值，达到才可以抽奖
    if self:isCanRewardLottery() then
        -- 3.向后端请求抽奖
        self:requestRewardLottery():next(function ()
            local rewards = self:getDataByKey(self._model.F.rewards)
            if rewards then self:_rewardLotteryCheck(runtime, table.clone(rewards)) end
        end, function ()
            printx(48, "requestRewardLottery error.")

        end)

    end
end
function Manager:_rewardLotteryCheck(runtime, rewards)
    local result = rewards and not table.isEmpty(rewards)
    if result then
        -- local rewards = {}
        --clear data
        self._model:setDataByKey(self._model.F.rewards, {})
        local isRealPrize = self:hasRealPrize(rewards)
        if not isRealPrize then self:addRewardsNormal(rewards, {dcFeature="pass_rewards", dcSource="get_reward"}) end
        self._actConfig.dcAct("pass_rewards", "get_reward", {t1=isRealPrize and 1 or 2})
        self._actConfig.dcJoin()

        -- 设置流程节点启动状态
        runtime:setEnabledProcessNodes(UBFActivityIdConst.kSprintRealPrizeV2, {
            [UBFProcessNodeEnum.SPRINT_REAL_PRIZE_V2] = {
                isProcessEnabled = true
            },
        })
        -- 设置流程节点的数据
        runtime:setModData(UBFActivityIdConst.kSprintRealPrizeV2, {
            -- 是否为实物奖励
            isRealPrize = isRealPrize,
            -- 奖励数据
            rewards = rewards,
            -- 弹出填写地址接口
            openContactPanel = function(ubfDelegate, closeCallback)
                self:openContactPanel(closeCallback, ubfDelegate)
            end
        })
    end

end

function Manager:isCanRewardLottery()
    -- propIntervalNormal\propIntervalMaxLevel\realRewardInterval
    local ret = true

    --道具的
    local dailyPropWinLimit = self:getDataByKey(self._model.F.dailyPropWinLimit, 0)
    local todayPropWinCount = self:getDataByKey(self._model.F.todayPropWinCount, 0)
    if todayPropWinCount >= dailyPropWinLimit then ret = false end
    if ret then
        local totalPropWinLimit = self:getDataByKey(self._model.F.totalPropWinLimit, 0)
        local totalPropWinCount = self:getDataByKey(self._model.F.totalPropWinCount, 0)
        if totalPropWinCount >= totalPropWinLimit then ret = false end
    end

    if ret then
        local stage = self:getUserLevelState()
        local propMaxLv = 0
        if stage == 0 then
            propMaxLv = self:getDataByKey(self._model.F.propIntervalNormal, 0)
        else
            propMaxLv = self:getDataByKey(self._model.F.propIntervalMaxLevel, 0)
        end
        local todayPropPassCount = self:getDataByKey(self._model.F.todayPropPassCount, 0)
        if todayPropPassCount < propMaxLv then
            ret = false
        end
    end

    --实物
    if not ret then
        ret = not self:isGotRealReward()

        if ret then
            local realRewardInterval = self:getDataByKey(self._model.F.realRewardInterval, 0)
            local todayRealPassCount = self:getDataByKey(self._model.F.todayRealPassCount, 0)
            if todayRealPassCount < realRewardInterval then
                ret = false
            end
        end
    end

    if EnvUtil:isDevelopMode() then printx(48, "4103 isCanRewardLottery ret=", ret) end
    return ret
end

---满级状态：0=非满级, 1=满级, 2=满级满彩
function Manager:getUserLevelState()
    local curFullLevelState = not _G.amfBean("UserStateManager"):isFMJ()
    local curFullStarState = _G.amfBean("UserStateManager"):isColorfulStarFull()
    if curFullLevelState and curFullStarState then return 2 end
    if curFullLevelState then
        return 1
    else
        return 0
    end
end


--关卡内触发条件
function Manager:isEnabledInLevel(data)
    if not self:isEnabled() then return false end

    return true
end

-- 打关结束时更新数据
function Manager:updatePassLevelData(data, mainCollectionCount, collectionMap, passLevelData)
    if not self:isEnabled() then return end
    local passLevelJson = passLevelData and passLevelData.passLevelJson
    if passLevelJson then
        -- 有效的闯关行为 N值加1
        if passLevelJson.clientMaxLevel then
            local todayPropPassCount = self:getDataByKey(self._model.F.todayPropPassCount, 0)
            self:setDataByKey(self._model.F.todayPropPassCount, todayPropPassCount + 1)
            local todayRealPassCount = self:getDataByKey(self._model.F.todayRealPassCount, 0)
            self:setDataByKey(self._model.F.todayRealPassCount, todayRealPassCount + 1)
        end
    end
end

--region request and response
function Manager:requestMainInfo(lightStart)
    return self._model:requestMainInfo(lightStart)
end

function Manager:requestRewardLottery()
    local maxLevelStatus = self:getUserLevelState()
    return self._model:requestRewardLottery(maxLevelStatus)
end

--endregion

--region 地址相关

---是否已填写地址
function Manager:isContactFilled()
    local addressFilledTime = tonumber(self:getDataByKey(self._model.F.addressFilledTime, 0))
    return addressFilledTime ~= 0
end

---是否截单，不允许修改地址
function Manager:isContactCutoff()
    -- do return true end --debug
    local addressFilledTime = tonumber(self:getDataByKey(self._model.F.addressFilledTime, 0))
    local isFilled = addressFilledTime ~= 0
    if not isFilled then return false end

    local cutoffTimes = self:getDataByKey(self._model.F.cutoffTimes) or {}
    local firstCutoffTime = 0
    for index, value in ipairs(cutoffTimes) do
        firstCutoffTime = tonumber(value)
        if addressFilledTime < firstCutoffTime then
            break
        end
    end

    local curTime = TimeKit:timeInMillis()
    return curTime >= firstCutoffTime
end

---打开填写地址
function Manager:openContactPanel(closeCallback, ubfDelegate)
    if EnvUtil:isMiniGame() then
        local loadRes = {"activity/sprintrealprize2/res/materials/shiwu.png"}
        _G.amfBean("AssetsUtil"):loadMiniFiles(loadRes):next(function()
            self:_openContactPanel(closeCallback, ubfDelegate)
        end, function ()
            safeRunCall(closeCallback)
        end)
    else
        self:_openContactPanel(closeCallback, ubfDelegate)
    end

end

function Manager:_openContactPanel(closeCallback, ubfDelegate)
    local itemList = {  }
    local reward =  {itemId = self:getConst().REAL_PROP_ID, num = 1}
    local info = {}
    local icon = GameItemCreator:getPropIcon({itemId = reward.itemId, num = reward.num, needNum = true})
    info.spr = icon
    table.insert(itemList, info)
    local isFirstFill = false

    self:getConfig()
    local customTable = {
        -- mgr = self,
        actId = self.ACT_ID,
        destTime = self._actConfig.getEndTime(), --TimeKit:timeInSec() + 3600,
        itemList = itemList,
        updateContactSuccessFunc = function()
            isFirstFill = not self:isContactFilled()
            -- printx(48, "修改地址成功")
            self:setDataByKey(self._model.F.addressFilledTime, TimeKit:timeInMillis())
        end,
        closeFunc = function(clickClose)
            self:_openContractRemind(isFirstFill, closeCallback, ubfDelegate)
        end,
        loadResFailCallback = function ()
            self:_openContractRemind(isFirstFill, closeCallback, ubfDelegate)
        end,
        contactResList = {},
        panelPath = "activity/sprintrealprize2/src/view/SprintRealPrizeContactPanel.lua",
        panelColorType = _G.PanelColorConst.ColorType.kSprintRealPrize2,
        ubfDelegate = ubfDelegate
    }

    local manager = _G.amfBean("ContactManager")
    manager:tryCreateContactPanel(customTable, closeCallback)
    if ubfDelegate then
        self._actConfig.dcAct("pass_rewards", "address_show", {t1=1})
    end
end

function Manager:_openContractRemind(isFirstFill, callback, ubfDelegate)
    local closeCallback = function ()
        safeRunCall(callback)
    end
    if not isFirstFill then
        closeCallback()
        return
    end

    local FourthPanelAVM = require("amf.middleware.ui.kit.panel.fourth.FourthPanelAVM")
    local vm
    vm = FourthPanelAVM.Builder.new()
        :setTitle("发货时间提醒")
        :setText("实物会在活动结束后15个工作日内发放，请您耐心等待~")
        :setButtonsConfig({
            {
                str = "知道了",
                touchFunc = function()
                    vm:close()
                end
            }
        })
        :setColorType(_G.PanelColorConst.ColorType.kSprintRealPrize2)
        :setLoadResFailCallback(closeCallback)
        :setCloseCallback(closeCallback)
        :build()
    vm:setUBFPopDelegate(ubfDelegate)
    vm:popout()
    -- self:managePanelVM(vm, "SendTimePanelVM")
    self._actConfig.dcAct("pass_rewards", "shipments_show")
end

--endregion


--region 强弹2 临时处理
function Manager:_isUserNotOpened()
    local ret = true
    self:getConfig()
    if self._actConfig then
        ret = not self._actConfig._isMainPanelOpened()
    end
    return ret
end

function Manager:onActEnterStage2()
    -- printx(48, "[gk] onActEnterStage2")
    if not self._actReady then return end
    self._isStage2Check = true
    local canAutoPopup = self:_isUserNotOpened()
    if not canAutoPopup then return end
    self:tryAutoPopup()
end

function Manager:tryAutoPopup()

    local popupKey = PopupCheckPoint.SPRINT_REAL_PRIZE_T2
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, popupKey)
    end

    local creator = function ()
        if not self:_isUserNotOpened() then
            safeRunCall(onHandleOver)
            return
        end

        self:openActivity(onHandleOver, nil, false)
    end

    -- _G.amfBean("AutoPopupMgr"):addPopupConfig(popupKey, creator)
    local autoPopupMgr = _G.amfBean("AutoPopupMgr")
    autoPopupMgr:addPopupConfig(popupKey, creator)
    if not autoPopupMgr:isRunnning() then
        autoPopupMgr:triggerStage2AutoPopup()
    end
end


function Manager:openActivity(closeCallback,extra,userClick)
    if not extra then extra = {} end

    self:callPlug("Act","openActivity",{
        actId = self.ACT_ID,
        extra = {
            from = extra.from,
        },
        failCallback = closeCallback,
        endCallback = closeCallback,
        userClick = userClick,
    })
end

--endregion


return Manager