require "amf.feature.winningstreak.module.bottle.config.WinningStreakBottleConst"
local WinningStreakBottleModel = require "amf.feature.winningstreak.module.bottle.model.WinningStreakBottleModel"
local deferred = require "amf.script.sugar.deferred"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local IconTipEventCenter = require "amf.feature.icontip.event.IconTipEventCenter"
local HomeIconTipsFactory = require "amf.feature.icontip.module.display.HomeIconTipsFactory"

local WinningStreakBottleManager = class("WinningStreakBottleManager")

local _instance
function WinningStreakBottleManager:getInstance()
    if not _instance then
        _instance = WinningStreakBottleManager.new()
        _instance:init()
    end
    return _instance
end

function WinningStreakBottleManager:init()
    self._assetsUtil = _G.amfBean("AssetsUtil")
    self._levelUnlockMgr =  _G.amfBean("LevelUnLockManager")

    self._icon = nil
    self._isCreatingIcon = false

    self._model = WinningStreakBottleModel:create()
    self:registerModelFunc()

    _G.amfEC:registerFeature(self)
    IconTipEventCenter:register(IconTipEvent.CHECK_ICON_TIP, self.onActCheckIconTip, self)
end

function WinningStreakBottleManager:registerModelFunc()
    local funcList = {
        "getWinningNum",
        "getMainConfig",
        "getEndTime",
        "getBeginTime",
        "getMetaId",
        "getTargetWinNum",
        "getAddPercent",
        "getAvailable",
        "getBuffState",
        "getActiveBuffLevelCount",
        "getLatestShowWinCnt",
        "checkIsFullShow",
        "checkCanSkipFullShow",
        "setWinningNum",
        "setIsFullShow",
        "setCanSkipFullShow",
        "setLatestShowWinCnt",
        "addWinningNum",
        "fillWinningNum",
    }

    for _, funcName in ipairs(funcList) do
        self[funcName] = function(context, ...)
            return self._model[funcName](self._model, ...)
        end
    end
end

------------------------------------------------------------------------------

function WinningStreakBottleManager:requestMainConfig()
    local promise = deferred.new()

    self._model:requestGetBottleMainInfo():next(function(response)
        self:checkIcon()
        promise:resolve()
    end, function(response)
        promise:reject()
    end)

    return promise
end

function WinningStreakBottleManager:syncMainConfigByActInfo(actInfo)
    self._model:syncMainConfigByActInfo(actInfo)
    self:checkIcon()
end

function WinningStreakBottleManager:isEnabled()
    if not self._model then return false end

    local mainConfig = self:getMainConfig()
    if not mainConfig or not mainConfig.metaId then return false end

    if TimeKit:timeInMillis() >= mainConfig.endTs 
        or TimeKit:timeInMillis() < mainConfig.beginTs
    then return false end

    if not self:isUserStateValid() then return false end

    return true
end

function WinningStreakBottleManager:isUserStateValid()
    return not _G.amfBean("UserStateManager"):isColorfulStarFull() 
end

function WinningStreakBottleManager:isAvailableLevel(levelId, levelScene)
    local isMainLevel = LevelConfigBridge:isLevelTypeByID(levelId, GameLevelType.kMainLevel, levelScene)
    if not isMainLevel then return false end

    local userStateManager = _G.amfBean("UserStateManager")
    if not userStateManager then return false end

    if userStateManager:isFMJ() then 
        local toplevelId = _G.getTopLevelId()
        return toplevelId == levelId 
	end

    return not userStateManager:isColorfulStarFull() 
end

function WinningStreakBottleManager:updatePassLevelData(levelContext)
    if not self:isEnabled() then return end

    if levelContext.isLevelPass then
        self:addWinningNum()
        return
    end

    if self:getAvailable() then
        self:setWinningNum(0)
        self:setIsFullShow(false)
    end

    self:updateIcon()
end

function WinningStreakBottleManager:dc(category, subCategory, t1, t2, t3, t4, extraData)
    local params = {
        game_type = "stage",
        game_name = "combobottle",
        category = category,
        sub_category = subCategory,
        t1 = t1,
        t2 = t2,
        t3 = t3,
        t4 = t4,
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end

    DcUtil:dcForUserTrack(params)
end

----------------------------- icon --------------------------------
function WinningStreakBottleManager:createIcon()
    local promise = deferred.new()
    if self._isCreatingIcon then
        return promise:resolve()
    end

    if self._icon then
        self:updateIcon()
        return promise:resolve()
    end

    self._isCreatingIcon = true

    self._assetsUtil:loadMiniFiles(_G.WinningStreakBottleConst.ICON_RES):next(function()
        self:_createIconWithResReady()
        self._isCreatingIcon = false
        promise:resolve()
    end, function()
        self._isCreatingIcon = false
        promise:reject()
    end)

    return promise
end

function WinningStreakBottleManager:_createIconWithResReady()
    local Icon = require "amf.feature.winningstreak.module.bottle.view.icon.Icon"
    self._icon = Icon:create()
    IconEventCenter:addIconEvent(self._icon)
    self:updateIcon()
end

function WinningStreakBottleManager:checkIcon()
    if self:isEnabled() then
        self:createIcon()
    else
        self:removeIcon()
    end
end

function WinningStreakBottleManager:getIcon()
    return self._icon
end

function WinningStreakBottleManager:updateIcon()
    if self._icon then
        self._icon:updateIcon()
    end
end

function WinningStreakBottleManager:removeIcon()
    IconEventCenter:removeIconEvent(_G.IconKey.kWinningStreakBottle)
    self._icon = nil
end

-------------------------------- 面板 ------------------------------------------

function WinningStreakBottleManager:showMainPanel()
    local promise = deferred.new()

    local recallManager = _G.amfBean("Recall2025Manager")
    local recallEnable = recallManager and recallManager:isEnabled() and recallManager:isIconEnabled()
    local recallMaxCount = recallManager and recallManager:getMaxBonusCount() or 0
    local WinningStreakScoreBottlePanelVM = require "amf.feature.winningstreak.module.bottle.view.WinningStreakScoreBottlePanelVM"
    local panel = WinningStreakScoreBottlePanelVM.Builder.new()
        :setIsKeepWinActivate(self:getAvailable())
        :setProgressWinCnt(self:getWinningNum())
        :setKeepWinCnt(self:getActiveBuffLevelCount())
        :setNeedWinNum(self:getTargetWinNum())
        :setLatestShowWinCnt(self:getLatestShowWinCnt())
        :setRecallData(recallEnable, recallMaxCount)
        :setCloseCallback(function()
            promise:resolve()
        end)
        :setLoadResFailCallback(function()
            promise:reject()
        end)
        :build()

    panel:popout()

    if EnvUtil:isDevelopMode() then
        local TestUtils = require "amf.feature.winningstreak.module.bottle.view.TestUtils"
        local testUtils = TestUtils.new()
        testUtils:showTest(panel)
        testUtils.testButtonCtrl.onTapped()

        local promise2 = deferred.new()
        promise:next(function()
            testUtils:close()
            promise2:resolve()
        end, function()
            testUtils:close()
            promise2:reject()
        end)

        return promise2
    end

    return promise
end

function WinningStreakBottleManager:showFullBottlePanel()
    local promise = deferred.new()

    local FullBottleAnimPanelVM = require "amf.feature.winningstreak.module.bottle.view.FullBottleAnimPanelVM"
    local panel = FullBottleAnimPanelVM.Builder.new()
        :setCloseCallback(function()
            self:updateIcon()
            promise:resolve()
        end)
        :setLoadResFailCallback(function()
            promise:reject()
        end)
        :build()

    panel:popout(nil, true, nil, 0)

    return promise
end

--------------------------------------- 事件 ---------------------------------------------

function WinningStreakBottleManager:onActEnterStage3()
    if not self:isEnabled() then return end
    if not self:getAvailable() then return end
    if self:checkIsFullShow() then return end 

    local levelId = _G.getTopLevelId()
    if self._levelUnlockMgr:isInNewLevelTime() and self._levelUnlockMgr:isTopNewMainOrHideLevel(levelId) then
        self:setIsFullShow(true)
        self:updateIcon()
        return
    end

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.COMBO_BOTTLE)
    end

    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.COMBO_BOTTLE, function ( ... )
        self:showFullBottlePanel():next(function()
            self:popIconTipAfterActivate(onHandleOver)
        end, function()
            onHandleOver()
        end)
    end)
end

function WinningStreakBottleManager:onActOnlineUnlockOver()
    self:requestMainConfig()
end

-- 闪退恢复失败
function WinningStreakBottleManager:onActCrashResumeFailed(eventData)
    if not self:isEnabled() then return end
    
    local data = eventData.data
    if data and data.levelId then
        if self:isAvailableLevel(data.levelId, data.levelScene) and self:getAvailable() then
            self:setWinningNum(0)
            self:setIsFullShow(false)

            self:updateIcon()
            -- HttpBase:offlinePost('opNotifyOffline', {type = OpNotifyOfflineType.kCloseResumePanel, param = Manager.ACT_ID})
        end
    end
end

function WinningStreakBottleManager:onActCheckIconTip(evt)
    if not self:isEnabled() then return end

    local data = evt:getData()
    local stage = data.stage
    if stage ~= "STAGE_TWO" then return end

    self:checkIconTipDaily()

    -- 由于弹出时机不符合需求，此条不走框架
    -- self:checkIconTipPermanent()
end

------------------------------------ iconTip --------------------------------------

function WinningStreakBottleManager:checkIconTipDaily()

    if not self:isEnabled() then return end

    local winNum = self:getWinningNum()
    local available = self:getAvailable()
    local text, typeIndex
    if not available and winNum >= 2 then
       text = string.format("再过%d关，激活加分瓶", self:getTargetWinNum() - winNum)
       typeIndex = 1
    elseif available and winNum >= 10 then
        text = "保持连胜，加分不停！"
        typeIndex = 2
    end

    if text then
        local IconTipEventCenter = require "amf.feature.icontip.event.IconTipEventCenter"
        IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, {
            iconKey = _G.IconKey.kWinningStreakBottle,
            iconType = IconTipType.MESSAGE,
            creatorDelegate = {
                text = text,
                tipsType = HomeIconTipsType.ONLY_TEXT,
            },
            typeIndex = typeIndex,
            config = {
                type = 1,
                stage = {2},
                priority = "A",
                giftPriority = 0,
                limit = 1,
                daily = true,
                ignoreNewLevel = true,
            },
        })
    end
end

function WinningStreakBottleManager:checkIconTipPermanent()
    if not self:isEnabled() then return end
    if self:getAvailable() then
        local IconTipEventCenter = require "amf.feature.icontip.event.IconTipEventCenter"
        IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, {
            iconKey = _G.IconKey.kWinningStreakBottle,
            iconType = IconTipType.MESSAGE,
            creatorDelegate = {
                text = "保持连胜，加分不停！",
                tipsType = HomeIconTipsType.ONLY_TEXT,
            },
            typeIndex = 3,
            config = {
                type = 1,
                stage = {2},
                priority = "A",
                giftPriority = 0,
                limit = 1,
                daily = false,
                ignoreNewLevel = true,
            },
        })
    end
end

function WinningStreakBottleManager:popIconTipAfterActivate(done)
    local icon = self:getIcon()
    if not icon or icon.isDisposed then 
        safeRunCall(done)
        return 
    end

    if self._model:checkIsFullShowTip() then
        safeRunCall(done)
        return
    end

    self._model:setIsFullShowTip(true)

    IconTipEventCenter:dispatch(IconTipEvent.HIDE_ICON_TIP, {
        iconKey = _G.IconKey.kWinningStreakBottle,
    })

    local iconTip = HomeIconTipsFactory:createTextTips(icon,"保持连胜，加分不停！",{
        endCallback = function() 
            safeRunCall(done) 
        end,
        duration = 2.5,
    })

    if not iconTip then
        safeRunCall(done)
        return
    end

    iconTip:playCutInAnim(function() 
        iconTip:playIdleAnim(function()
            iconTip:playCutOutAnim(function()
                iconTip:remove()
            end)
        end)
    end)
end

return WinningStreakBottleManager
