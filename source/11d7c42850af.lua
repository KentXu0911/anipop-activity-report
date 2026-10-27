
local KSPromotionDC = require "amf.feature.minihub.kspromotion.dc.KSPromotionDC"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local Model = require "amf.feature.minihub.kspromotion.model.Model"
local KSPromotionIcon = require "amf.feature.mainscene.module.icon.view.iconbutton.KSPromotionIcon"

local ICON_RES_PATH = "amf/kspromotion/texture/icon.png"
local MAIN_PANEL_RES_PATH = "amf/kspromotion/texture/mainPanel.png"
local KSPromotionManager = class("KSPromotionManager")

local ACT_NAME = "幸运抽奖"
local ACT_ID = 10187

local DebugTable = {
    46054503123,
    38277280467,
    50956591827,
    45325808339,
    440133391,
    519415567,
    503703311,
}

function KSPromotionManager:ctor()
end

function KSPromotionManager:initialize()
    self._assetsUtil = _G.amfBean("AssetsUtil")
    self.model = Model:create()
     _G.amfEC:registerFeature(self)
end

function KSPromotionManager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
end

function KSPromotionManager:setMainPanel(mainPanel)
    self.mainPanel = mainPanel
end

function KSPromotionManager:getMainPanel()
    return self.mainPanel
end

function KSPromotionManager:getIsMainPanelShow()
    return self.model:getIsMainPanelShow()
end

function KSPromotionManager:getHasDraw()
    return self.model:getHasDraw()
end

function KSPromotionManager:isActEnabled()
    if not EnvUtil:isKuaiShouMiniGame() then
        return false
    end
    printx(44, _G.amfBean("ProfileManager"):getXxlId())
    if table.exist(DebugTable, tonumber(_G.amfBean("ProfileManager"):getXxlId())) then
        printx(44, "kspromotion enabled")
        return true
    end
    if not self.model:isActOpen() then
        return false
    end
    return MaintenanceManager:getInstance():isEnabledInGroup("ks_tuiguang", "ON")
end


function KSPromotionManager:createIcon()
    if self.loadingRes then
        return
    end
    self.loadingRes = true
    self:loadRes({
        resList = {ICON_RES_PATH},
        successCallback = function()
            self.icon = KSPromotionIcon:create()
            IconEventCenter:addIconEvent(self.icon)
            self.loadingRes = false
            self.icon:updateState()
            self.icon:setLabelStr("幸运抽奖")

        end,
        failCallback = function()
            self.loadingRes = false
        end,
    })
end

function KSPromotionManager:removeIcon()
    IconEventCenter:removeIconEvent(_G.IconKey.kKSPromotion)
    self.icon = nil
    self:unloadRes({
        ICON_RES_PATH
    })
end

function KSPromotionManager:getPeriodEndTime()
    return self.model:getPeriodEndTime()
end

function KSPromotionManager:getPeriodBeginTime()
    return self.model:getPeriodBeginTime()
end

function KSPromotionManager:onActEnterStage4()
    self:tryUpdateActIcon()
    if not self:checkStage4CanPop() then return end
    local function onHandleOver()
        self.model:setIsMainPanelPopup()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.KS_PROMOTION)
	end

	local function creator()

		self:showMainPanel(onHandleOver, true)
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.KS_PROMOTION, creator)
end

function KSPromotionManager:onActPassDay()
    if not self:isActEnabled() then return end
    local isClosePanel =  self:tryClosePanel()
    if isClosePanel then
        if self:getPeriodEndTime() < TimeKit:timeInSec() then
        CommonTip:showTip(ACT_NAME..'活动已结束！')
        else
            CommonTip:showTip('新的一天开始了，数据已更新，\n请尝试重进活动~')
        end
    end
    self:tryUpdateActIcon()
end


function KSPromotionManager:tryClosePanel()
   if self.mainPanel then
        self.mainPanel:close()
        self.mainPanel = nil
        return true
    end
    return false
end
function KSPromotionManager:onActEnterStage2()
    if not self:isActEnabled() then return end
    self:tryUpdateActIcon()
end

function KSPromotionManager:checkStage4CanPop()
    if self.model:getIsMainPanelPopup()  then return false end
    if not self:isActEnabled() then return false end
    if _G.getTopLevelId() < 21 then return false end

    if self.model:getIsMainPanelShow() then return false end

    return true
end

function KSPromotionManager:tryUpdateActIcon()
    if not self:isActEnabled() then
        self:removeIcon()
        return
    end

    if self.icon then
        self.icon:updateAll()
        return
    end
    self:createIcon()
end

function KSPromotionManager:onActEnterMainScene(evt)
    local data = evt:getData()
    if data and data.firstEnter then
        self:tryUpdateActIcon()
    end
end

function KSPromotionManager:showMainPanel(closeFunc, isPopup)
    if  self:getMainPanel() then
        safeRunCall(closeFunc)
        return
    end

    if self:isActEnabled() then
        local t1
        if isPopup then
            t1 = "drainage_node_reward"
        else
            t1 = "vine_icon"
        end
        local panelId = UICreateUtil:getPanelId("KSPromotionMainPanel")
        KSPromotionDC:dcMainPanel("show", {
            actid = ACT_ID,
            panel_id = panelId,
            t1 = t1
        })
        local closecb =  function ()
            KSPromotionDC:dcMainPanel("click", {
                actid = ACT_ID,
                panel_id = panelId,
                t1 = 2
            })
            self:tryUpdateActIcon()
            self:setMainPanel(nil)
            safeRunCall(closeFunc)
        end
       self:loadRes({
        resList = {MAIN_PANEL_RES_PATH},
        successCallback = function()
            self.model:setIsMainPanelShow()
            local PreheatPanelVM = require "amf.middleware.ui.kit.panel.first.PreheatPanelVM"
            local vm
            vm = PreheatPanelVM.Builder.new()
                :setTitle("幸运抽奖")
                :setSpriteBg(UICreateUtil:createSpriteFile(MAIN_PANEL_RES_PATH), ccp(0, -20))
                :setTimeLabel(self.model:getPeriodEndTime(), hex2ccc4("00000080"), ccp(0, -656))
                :setButtonData({
                    str = { "去抽奖" },
                    redDot = ( not self.model:getHasDraw() ) and " " or nil,
                    touchFunc = function()
                        KSPromotionDC:dcMainPanel("click", {
                            actid = ACT_ID,
                            panel_id = UICreateUtil:getPanelId("KSPromotionMainPanel"),
                            t1 = 1
                        })
                        vm:hideConfirmButtonRedDot()
                        self.model:setHasDraw()
                        CALL_EASY_JS_ASYNC("globalThis.animalPlugin.sdkManager.openURL", function(result)
                                local r = table.deserialize(result)
                                if r and r.resCode == -1 then
                                    CommonTip:showTip("状态异常，请稍后再试~")
                                end
                            end,
                            "https://ppg.viviv.com/doodle/LZrjPwVf.html?uni_src=SUPCFS&hyId=jimu_next%2Cjimu_LZrjPwVf&bizId=jimu_LZrjPwVf&layoutType=4&noBackNavi=true&jimu_target=kwai")
                    end
                })
                :setEndString("活动已结束")
                :setCloseCallback(closecb)
                :setClockType(YH_REF_MAP.noEarClock)
                :setBeginString("活动时间：")
                :build()
            vm:addTick()
            vm:popout()
            self:setMainPanel(vm)
        end,
        failCallback = function()
            self.loadingRes = false
        end,
    })
    else
        self:removeIcon()
        safeRunCall(closeFunc)
    end
end

function KSPromotionManager:loadRes(delegate)
    local successCallback = delegate.successCallback
    local failCallback = delegate.failCallback
    local resList = delegate.resList
    if EnvUtil:isMiniGame() then
        return self._assetsUtil:loadMiniFiles(resList):next(successCallback, failCallback)
    else
        safeRunCall(successCallback)
    end
end

function KSPromotionManager:unloadRes(resList)
    if not EnvUtil:isMiniGame() then
        return
    end
    for k, v in pairs(resList) do
        if string.find(v, ".png") then
            CCTextureCache:sharedTextureCache():removeTextureForKey(
                    CCFileUtils:sharedFileUtils():fullPathForFilename(SpriteUtil:getRealResourceName(v), true)
            )
        elseif string.find(v, ".skel") then
            UICreateUtil:unloadSpineRes(v, true)
        elseif string.find(v, ".plist") then
            UICreateUtil:unloadPlist(v)
        end
    end
end



return KSPromotionManager