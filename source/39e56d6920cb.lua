local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local BattlePassInLevelModule = require "amf.feature.localactivity.battlepass.module.BattlePassInLevelModule"
local IconTipEventCenter = require "amf.feature.icontip.event.IconTipEventCenter"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local Manager = class("BattlePassManager", BaseFeatureManager)

function Manager:isEnabled()
    local dataEnable = self:getModel():isDataEnabled()
    local timeEnable = self:isInMainTime()
    local timeEnableInReward = timeEnable or self:isInRewardTime()
    local resEnable = self:isResEnabled()
    if dataEnable and timeEnableInReward and not resEnable then
        self:callDownloadFunc("startDownload")
    end
    return dataEnable and timeEnable and resEnable
end

function Manager:isEnabled2()
    local dataEnable = self:getModel():isDataEnabled()
    local timeEnable = self:isInMainTime() or self:isInRewardTime()
    local resEnable = self:isResEnabled()
    if dataEnable and timeEnable and not resEnable then
        self:callDownloadFunc("startDownload")
    end
    return dataEnable and timeEnable and resEnable
end

function Manager:isResEnabled()
    local labels = self:getConst().downloadLabels
    if not labels or table.isEmpty(labels) then return true end
    return self:callDownloadFunc("checkDownloadSuccess")
end

function Manager:_init()
    self._dc = require(self:_getDCPath())
    self._inLevelModule = BattlePassInLevelModule:create(self)
    IconTipEventCenter:register(IconTipEvent.CHECK_ICON_TIP, self.onActCheckIconTip, self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActInfoUpdate, self)
end

function Manager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
    self:_registerAutoPopup()
end

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
            key = "SendProp",
            path = {
                plugPath = "amf.feature.localactivity.battlepass.plug.BattlePassActSendPlug",
            },
        },
    }
end

function Manager:_getConstPath()
    return "amf.feature.localactivity.battlepass.const.BattlePassConst"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.battlepass.model.BattlePassModel"
end

function Manager:_getDCPath()
    return "amf.feature.localactivity.battlepass.dc.BattlePassDC"
end

function Manager:getDC()
    return self._dc
end

---------------------------------------------------------------------------
-- Data sync
---------------------------------------------------------------------------
function Manager:updateData(data, fromServer)
    if not data then return end
    self:getModel():fromServer(data)
    self:refreshPackageMetas()
end

function Manager:refreshPackageMetas()
    local packageInfos = self:getModel():getPackageMetas()
    if not packageInfos then return end
    for k, v in pairs(packageInfos) do
        local meta = self:getModel():getPackageMetaById(k)
        if meta then
            GoodsManager:registerGoods({
                goodsId = k,
                packageMeta = meta,
            })
        end
    end
end

---------------------------------------------------------------------------
-- Icon
---------------------------------------------------------------------------
function Manager:hasReward()
    if not self:isEnabled2() then return false end
    local hasReward = self:getModel():hasBattlePassReward()
    return hasReward
end

function Manager:getMsgNum()
    return 0
end

---------------------------------------------------------------------------
-- IconTip 进度抽条
---------------------------------------------------------------------------

-- 获取当前进度新达到且尚未弹过抽条的档位 cfg
-- 返回 nil 表示没有新达到的档，不需要弹
function Manager:_getCurrentTierCfg(value)
    local bpModel = self:getModel()
    local cfg = bpModel:getConfigByKey("battlePass", {})
    local shownIndex = bpModel:getFlagFromLocalByKey("iconTipShownTierIndex", false) or 0
    -- 找所有 value 达到的档中，index > shownIndex 的最大那档（即最新解锁的档）
    local newTierCfg = nil
    local newTierIndex = 0
    for index = 1, #cfg do
        local v = cfg[index]
        if value >= (v.need or 0) and index > shownIndex then
            if index > newTierIndex then
                newTierCfg = v
                newTierIndex = index
            end
        end
    end
    if newTierCfg then
        -- 记录已弹到的最大档
        bpModel:saveFlagToLocalByKey("iconTipShownTierIndex", false, newTierIndex)
    end
    return newTierCfg
end

function Manager:onActCheckIconTip(evt)
    if not self:isEnabled() then return false end
    local data = evt:getData()
    if not data or not data.stage then return false end
    -- 仅在场景2（过关后）和场景4（子页面返回）触发
    if data.stage ~= "STAGE_TWO" and data.stage ~= "STAGE_FOUR" then return false end
    local model = self:getModel()
    local value = model:getBattlePassValue()
    -- 尚未有进度则不触发
    if value <= 0 then return false end
    local tierCfg = self:_getCurrentTierCfg(value)
    if not tierCfg then return false end
    local need = tierCfg.need or 1
    local taskFlag = model:getTaskFlag()
    local TASK_LABEL_PREFIX = {
        FMJ   = "过最高关",   -- 非满级
        MJFMC = "补星",       -- 满级非满星
        MJMC  = "随机挑战",   -- 满级满星
    }
    local labelPrefix = TASK_LABEL_PREFIX[taskFlag] or TASK_LABEL_PREFIX.FMJ

    local delegate = {
        iconKey  = tostring(self:getConst().actId),
        iconType = IconTipType.MESSAGE,
        typeIndex = 1,
        creatorDelegate = {
            tipsType           = HomeIconTipsType.PROGRESS,
            min                = 0,
            max                = need,
            value              = 0,          -- 动画从0开始
            targetValue        = math.min(value, need),
            progressChangeTime = 0.8,
            textMode           = 0,          -- n/m 格式
            labelPrefixes      = labelPrefix,
            templateId         = 1,          -- 满格时右侧展示单宝箱
        },
        config = { priority = "A" },
    }

    IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, delegate)
end

---------------------------------------------------------------------------
-- Rewards
---------------------------------------------------------------------------
function Manager:addRewardsNormal(rewardItems, params)
    local plug = self:_getPlug("Rewards")
    local dcFeature, dcSource = plug:_getDCFeatureAndSource(params)
    local gainData = _G.GainPropData:create()
        :setFeature(dcFeature)
        :setSource(dcSource)
        :setProps(rewardItems)
    if params and params.extraMap then
        gainData:setExtraMap(params.extraMap)
    end
    gainData:execute()
end

---------------------------------------------------------------------------
-- Time
---------------------------------------------------------------------------
function Manager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function Manager:getEndTime()
    return self:getModel():getEndTime()
end

function Manager:isInMainTime()
    return self:getModel():isInMainTime()
end

function Manager:isInRewardTime()
    return self:getModel():isInRewardTime()
end

---------------------------------------------------------------------------
-- Goods
---------------------------------------------------------------------------
function Manager:requestBuyGiftPackage(goodsId, buyType, buyCount, successCallback, failCallback, cancelCallback)
    local buyContext = BuyContext.new(goodsId, buyType)
    :setFeatureAndSource(self:getConst().dcFeature, "power_gift")
    :setUnifiedBuy(true, GiftPackageConst.StageType.ACTIVITY, "big_vine_battle_pass")
    :setCallback(successCallback, failCallback, cancelCallback)
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
end

function Manager:getActName()
    return self:getConst().actChName
end


---------------------------------------------------------------------------
-- 强弹相关
---------------------------------------------------------------------------
function Manager:openActivity(closeCallback, extra, userClick, duanMianData)
    local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
    ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY, {
        actId = self:getConst().actId,
        failCallback = closeCallback,
        endCallback = closeCallback,
        userClick = userClick,
        extra = extra,
        duanMianData = duanMianData
    })
end

---------------------------------------------------------------------------
-- 强弹注册（声明式）
---------------------------------------------------------------------------
function Manager:_registerAutoPopup()
    local PCP = _G.PopupCheckPoint
    local autoPopupMgr = self.autoPopupMgr
    local PopStage = AutoPopupConst.PopStage
    autoPopupMgr:registerPopup({
        checkPoint = PCP.BATTLE_PASS_TRIGGER,
        stages     = { PopStage.STAGE_TWO, PopStage.STAGE_FOUR },
        check      = function()
            return self:isEnabled()
                and autoPopupMgr:getPermanentShowNum(PCP.BATTLE_PASS_TRIGGER) < 1
        end,
        creator    = function(_, onPopOver)
            return function()
                autoPopupMgr:sendPermanentData(PCP.BATTLE_PASS_TRIGGER)
                self:openActivity(onPopOver)
            end
        end
    })

    autoPopupMgr:registerPopup({
        checkPoint = PCP.BATTLE_PASS_UNBUY_COMPLETE,
        stages     = { PopStage.STAGE_FOUR },
        check      = function()
            return self:isEnabled()
                and not self:getModel():getBattlePassVip()
                and self:_isAllTaskCompleted()
                and autoPopupMgr:getPermanentShowNum(PCP.BATTLE_PASS_UNBUY_COMPLETE) < 1
        end,
        creator    = function(_, onPopOver)
            return function()
                autoPopupMgr:sendPermanentData(PCP.BATTLE_PASS_UNBUY_COMPLETE)
                self:openActivity(onPopOver)
            end
        end
    })

    autoPopupMgr:registerPopup({
        checkPoint = PCP.BATTLE_PASS_BUY_COMPLETE,
        stages     = { PopStage.STAGE_TWO, PopStage.STAGE_FOUR },
        check      = function()
            return self:isEnabled()
                and self:getModel():getBattlePassVip()
                and self:_isAllTaskCompleted()
                and autoPopupMgr:getPermanentShowNum(PCP.BATTLE_PASS_BUY_COMPLETE) < 1
        end,
        creator    = function(_, onPopOver)
            return function()
                autoPopupMgr:sendPermanentData(PCP.BATTLE_PASS_BUY_COMPLETE)
                self:openActivity(onPopOver)
            end
        end
    })

    autoPopupMgr:registerPopup({
        checkPoint = PCP.BATTLE_PASS_REWARD_SETTLE,
        stages     = { PopStage.STAGE_TWO, PopStage.STAGE_FOUR },
        check      = function()
            return self:isInRewardTime()
                and self:isEnabled2()
                and autoPopupMgr:getPermanentShowNum(PCP.BATTLE_PASS_REWARD_SETTLE) < 1
        end,
        creator    = function(_, onPopOver)
            return function()
                autoPopupMgr:sendPermanentData(PCP.BATTLE_PASS_REWARD_SETTLE)
                self:_openRewardSettlePanel(onPopOver)
            end
        end
    })
end

function Manager:_openRewardSettlePanel(onPopOver)
    -- TODO: 替换为结算奖励特定面板，当前 fallback 到 openActivity
    self:openActivity(onPopOver)
end

function Manager:_isAllTaskCompleted()
    local value = self:getModel():getBattlePassValue()
    local cfg   = self:getModel():getConfigByKey("battlePass", {})
    if #cfg == 0 then return false end
    local maxNeed = 0
    for _, v in ipairs(cfg) do
        if (v.need or 0) > maxNeed then
            maxNeed = v.need
        end
    end
    return value >= maxNeed
end


---------------------------------------------------------------------------
-- Act info update（活动下线时清除本地数据）
---------------------------------------------------------------------------
function Manager:onActInfoUpdate(evt)
    local data = evt:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]
    if not actInfo and fromServer then
        if self:isEnabled() then
            self:reset()
        end
    end
end

function Manager:reset()
    self:getModel():reset()
end

---------------------------------- 关卡内 begin--------------------------------
--关卡内触发条件
function Manager:isEnabledInLevel(data)
    if not self:isEnabled() then return false end
    return true
end

--打关结束时更新数据
function Manager:updatePassLevelData(data, collectionCount, collectionMap, passLevelData)
    local passLevelJson = passLevelData and passLevelData.passLevelJson
    local needIncrValue = passLevelJson and passLevelJson.needIncrValue
    -- 更新任务进度
    if needIncrValue then
        self:getModel():addBattlePassValue(1)
        local modEnvData = data.modEnvData
        local levelInfo = data.levelInfo
        local isFullLevelLib = LevelSceneFunc:isFullLevelLib(levelInfo.levelScene)
        if modEnvData.levelSupportType == LevelSupportModeType.kNormal then
            if isFullLevelLib then
                -- 满级满星打关卡库

            else
                -- 非满级打top关

            end
        elseif modEnvData.levelSupportType == LevelSupportModeType.kExceedStar then
           -- 满级未满星刷星

        end
        self._inLevelModule:syncTaskFlagIfNeeded()
    end
end

return Manager
