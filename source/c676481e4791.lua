local ActivityGiftPackageModule = require "amf.feature.giftpackage.module.activity.ActivityGiftPackageModule"
local AddStepGiftModule = require "amf.feature.giftpackage.module.addstep.AddStepGiftModule"
local Res = require "amf.feature.localactivity.shopreward.const.Res"

local ShopRewardAddStepModule = class("ShopRewardAddStepModule", ActivityGiftPackageModule)

function ShopRewardAddStepModule:ctor(moduleName)
    self._moduleName = moduleName or GiftPackageConst.ModuleType.SHOP_REWARD
    self._version = 1
end

function ShopRewardAddStepModule:getManager()
    return _G.amfBean("ShopRewardManager")
end

function ShopRewardAddStepModule:requireExtraParams()
    return {}
end

function ShopRewardAddStepModule:getResMap()
    local resMap = AddStepGiftModule.getResMap(self)
    local files = resMap.files or {}
    for _, file in ipairs(Res:getAddStepResList()) do
        table.insert(files, file)
    end
    resMap.files = files
    return resMap
end

function ShopRewardAddStepModule:isEnabled(stageInfo)
    self.addFivePrice = stageInfo and stageInfo.addFiveBtnDisplayPrice or 0
    local manager = self:getManager()
    return manager and manager:canShowAddStepPendant(stageInfo) or false
end

function ShopRewardAddStepModule:doCreateGiftView(commonGiftData)
    if commonGiftData and commonGiftData.setExtraValue then
        commonGiftData:setExtraValue("shopRewardAddFivePrice", self.addFivePrice or 0)
    end

    local manager = self:getManager()
    if not manager or not manager:isAddStepPackageDisplayable(commonGiftData, self.addFivePrice) then return nil end

    local ShopRewardAddStepView = require "amf.feature.giftpackage.module.addstep.shopreward.ShopRewardAddStepView"
    return ShopRewardAddStepView:create(self, commonGiftData)
end

function ShopRewardAddStepModule:getActId()
    local manager = self:getManager()
    return manager and manager:getConst().actId
end

function ShopRewardAddStepModule:onGoStoreTapped()
    local manager = self:getManager()
    if manager and not manager:isEnabled() then
        CommonTip:showTip(localize("the.activity.has.ended"))
        return
    end

    if manager then
        manager:openActivity(nil, {
            source = StoreConfig.AccurateSource.Click_Act_ShopReward_Add,
        })
    end
end

return ShopRewardAddStepModule
