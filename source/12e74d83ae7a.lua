local Meta = require "amf.feature.localactivity.merge.config.MergeConfig"
local MBuyLogic = require 'amf.feature.localactivity.merge.gift.MBuyLogic'
local RewardFlyHelper = require 'amf.feature.localactivity.processgiftautopopup.RewardFlyHelper.lua'
local GiftPanelVM = class("GiftPanelVM", AMFBasePanelVM)

local Builder = newBuilder(GiftPanelVM)

function Builder:setData(v)
    self.data = v
    return self
end

local PanelType = {
    STAGE_4_POP = 1,
    MAIN_POP = 2,
    TUJIAN_HALF = 3,
    MAIN_POP2 = 4,
}

local TextConfig = {
    [PanelType.STAGE_4_POP] = {
        TITLE = "超值购买",
        DESC = "美味合合超值优惠，限时购买！",
    },
    [PanelType.MAIN_POP] = {
        TITLE = "体力多多",
        DESC = "特惠狂欢，体力大促销！",
    },
    [PanelType.TUJIAN_HALF] = {
        TITLE = "图鉴专属礼包",
        DESC = "超值高级食材，助力获得绝版头像框！",
    },
    [PanelType.MAIN_POP2] = {
        TITLE = "超值双倍补给",
        DESC = "特惠狂欢，体力大促销！",
    },
}

function GiftPanelVM:_createPanel(...)
    local GiftPanel = require('amf.feature.localactivity.merge.gift.GiftPanel')
    return GiftPanel:create(GiftPanelVM, ...)
end

function GiftPanelVM:secondLoadCompleted()
    -- printx(42, "initUI----------")
    local title = TextConfig[self.panelType].TITLE
    local desc = TextConfig[self.panelType].DESC
    self:callViewFunc("initUI", self.panelType, self.goodsId, title, desc, self.goodsObj:getItems(), self.buyPreFunc, self.noCheckBox, self.goodsObj)
end

function GiftPanelVM:init(delegate)
    -- printx(42, "initData----------")
    self.delegate = delegate
    self.from = delegate.data.from
    self.goodsId = delegate.data.goodsId
    self.goodsObj = GoodsManager:getGoods(self.goodsId)
    self.mgr = delegate.data.mgr
    self.panelType = delegate.data.panelType or PanelType.STAGE_4_POP
    local source = self.panelType == PanelType.STAGE_4_POP and 1 or 2
    self.buyPreFunc = delegate.data.buyPreFunc
    self.buySucFunc = delegate.data.buySucFunc

    self.buyLogic = MBuyLogic:create({
        actId = self.mgr.ACT_ID,
        sourceExt = self.panelType == PanelType.MAIN_POP and "main_gift" or "flow_gift",
    })

    self.tracer = self.buyLogic:createPayTracer(self.goodsId, self.from, nil, nil, source)

    self.customFlyFunc = delegate.data.customFlyFunc

    local bCanShowCheckBox = false
    if self.panelType == PanelType.MAIN_POP or self.panelType == PanelType.MAIN_POP2 then
        bCanShowCheckBox = true
    end
    -- 礼包extra里有multiple，表示有多个，可以有checkBox
    if delegate.data and delegate.data.checkBox then
        bCanShowCheckBox = true
    end
    self.noCheckBox = not bCanShowCheckBox
end

function GiftPanelVM:onButton()
    if self.isDisposed then return end
    if self:isLocked() then return end

    self.tracer:click()

    local buyPowerNum = 0
    local rewards = {}
    for _, v in pairs(self.goodsObj:getItems()) do
        if v.itemId == Meta.CollectionId then
            buyPowerNum = v.num
        end
        local r = {itemId = v.itemId, num = v.num}
        rewards[#rewards + 1] = r
    end
    local function successCallback(bBuy)
        if bBuy then
            self:lock()
            local sucCall = function(...)
                local source = self.panelType == PanelType.MAIN_POP and "main_gift" or "flow_gift"
                self.mgr:getData():addBuyGoodsCount(self.goodsId, 1)
                -- self.mgr:addRewards(rewards, {
                --     dcFeature = "happy_merge",
                --     dcSource = source,
                --     dontNeedAddNormal = true,
                -- })

                self:callViewFunc("flyRewards", function()
                    if self.isDisposed then return end
                    self:unlock()
                    self:onCloseBtnTapped()
                end, self.customFlyFunc)

                safeRunCall( self.buySucFunc ) 
            end

            local failCall = function(...)
                self:unlock()
            end

            local cancelCall = function(...)
                self:unlock()
            end

            self.buyLogic:requestBuyWithTracer(sucCall, failCall, cancelCall, self.tracer)
        end
    end

    local totalPower = self.mgr:getData():getPowerTotal()
    if buyPowerNum > 0 and totalPower + buyPowerNum > Meta.MaxPowerConfig then
        self.mgr:openSecondConfirmPanel(successCallback, totalPower, buyPowerNum)
    else
        successCallback(true)
    end
end

function GiftPanelVM:isLocked()
    return self.bLock
end

function GiftPanelVM:lock()
    self.bLock = true
end

function GiftPanelVM:unlock()
    self.bLock = false
end

function GiftPanelVM:close()
    self.tracer:close()
    if self.flowCheck then
        self.mgr:getData():requestNotShowToday(true)
    end
    if self.energyCheck then
        self.mgr:getData():requestNotShowToday()
    end
    AMFBasePanelVM.close(self)
end

function GiftPanelVM:createIcon(reward, callback)
    local icon = self.mgr:commonCreateIcon(reward)
    safeRunCall(callback, icon)
end

function GiftPanelVM:getActIcon(callback)
    local icon = _G.amfBean("IconManager"):getIconByIconKey(tostring(self.mgr.ACT_ID))
    safeRunCall(callback, icon)
end

function GiftPanelVM:getFlyActIcon(callback)
    local icon = self.mgr:createFlyActIcon()
    safeRunCall(callback, icon)
end

function GiftPanelVM:setIgnoredEnergyNotEnoughGiftToday(checked)
    self.energyCheck = checked
    self.mgr:setIgnoredEnergyNotEnoughGiftToday(checked)
end

function GiftPanelVM:setIgnoredGiftToday(checked)
    self.flowCheck = checked
    self.mgr:setIgnoredGiftToday(checked)
end

function GiftPanelVM:createBuyButton(buttonData, callback)
    local icon = self.mgr:createBuyButton(buttonData)
    safeRunCall(callback, icon)
end

return GiftPanelVM