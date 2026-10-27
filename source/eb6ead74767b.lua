local PromotionEvent2025DC = require "amf.feature.promotionevent2025.dc.PromotionEvent2025DC"
local LastPeriodRankPanelVM = class("LastPeriodRankPanelVM", AMFBasePanelVM)
local deferred = require "amf.script.sugar.deferred"

local Builder = _G.newBuilder(LastPeriodRankPanelVM)

function Builder:ctor()
    self.panelPath = "amf.feature.promotionevent2025.view.panel.LastPeriodRankPanel"
    self.rankData = nil
end

function Builder:setLastRankData(rankData)
    self.rankData = rankData
    return self
end

function Builder:setOpenParams(openParams)
    self.openParams = openParams
    return self
end

function LastPeriodRankPanelVM:init(delegate)
    self._promotionEventManager = _G.amfBean("PromotionEventManager")
    self._userManager = _G.amfBean("UserManager")
    self.openParams = delegate.openParams or {}
    self.openFrom = (self.openParams.fromBanner and 3)
        or (self.openParams.jumpInfo and 2)
        or 1

    self.lastRankData = nil
    self:initRankData(delegate.rankData)

    self.panel_id = UICreateUtil:getPanelId("LastPeriodRankPanel")
end

function LastPeriodRankPanelVM:initRankData(lastRankData)
    self.lastRankData = self._promotionEventManager:handleRankData(lastRankData, false)

    local lastDanDiff = self._promotionEventManager:getLastDanDiff()
    for k,v in ipairs(self.lastRankData) do 
        if tostring(v.uid) == tostring(self._userManager:getUid()) then
            v.isMe = true
            self.myRankInfo = v
        end
    end

    table.sort(self.lastRankData, function ( a,b )
        return a.rank < b.rank
    end)
end

function LastPeriodRankPanelVM:onCloseBtnTapped()
    if self.isDisposed then return end
    if self:isLocked() then return end

    self._clickCloseBtn = true
    self:close()
end

function LastPeriodRankPanelVM:onMainBtn()
    if self.isDisposed then return end
    if self:isLocked() then return end

    if self._promotionEventManager:needHistoryRankReward() then
        self:doGetReward():next(function()
            self:doDanChnage()
        end)
    else
        self:doDanChnage()
    end
end

function LastPeriodRankPanelVM:onQuestionBtnTapped()
    if self.isDisposed then return end
    if self:isLocked() then return end

    self:lock()
    self._promotionEventManager:showDescPanel():next(function()
        self:unlock()
    end, function()
        self:unlock()
    end)

    PromotionEvent2025DC:prein_panel_click(self.panel_id, self.dcType, 1)
end

function LastPeriodRankPanelVM:doGetReward()
    local promise = deferred.new()
    self:lock()

    local outerExchangeShopData
    self._promotionEventManager:requestGetRewardsLastRank():next(function(exchangeShopData)
        outerExchangeShopData = exchangeShopData

        local dan = self._promotionEventManager:getDan()
        local danDiff = self._promotionEventManager:getLastDanDiff()
        local lastDan = dan - danDiff
        local str = ""
        for k,v in pairs(exchangeShopData.rewardDirectList) do 
            str = str .. v.itemId .. "_" .. v.num .. ";"
        end
        for k,v in pairs(exchangeShopData.rewardList) do 
            str = str .. v.itemId .. "_" .. v.num .. ";"
        end
        for k,v in pairs(exchangeShopData.yuanBaoList) do 
            str = str .. v.itemId .. "_" .. v.num .. ";"
        end

        PromotionEvent2025DC:get_rank_reward(
            self.panel_id,
            lastDan,
            self.myRankInfo.rank,
            str,
            dan,
            danDiff,
            self.openFrom
        )

    end):next(function()
        local p = deferred.new()
        self:callViewFunc("playBoxJumpAnim", function()
            p:resolve()
        end)
        return p
    end):next(function()
        local dan = self._promotionEventManager:getDan()
        local danDiff = self._promotionEventManager:getLastDanDiff()
        local lastDan = dan - danDiff
        local rankConfig = self._promotionEventManager:getCurDanRewardByRank(self.myRankInfo.rank)
        local skinType = tonumber(rankConfig.boxIcon or 1)
        local taskType = self._promotionEventManager:getDataValue("lastPeriodCollectionType")

        return self._promotionEventManager:showRewardsBoxPanel(outerExchangeShopData, skinType, {taskType = taskType}, lastDan)
    end):next(function()
        self:unlock()
        promise:resolve()
    end, function()
        self:unlock()
        promise:reject()
    end)

    return promise
end

function LastPeriodRankPanelVM:doDanChnage()
    local promise = deferred.new()
    self:lock()

    self:callViewFunc("doDanChnage", function()
        self:unlock()
        promise:resolve()
    end)

    return promise
end

function LastPeriodRankPanelVM:onEnterPanelRun()
    if self.isDisposed then return end

    if not self._promotionEventManager:getLastRankFlag() then
        self._promotionEventManager:setLastRankFlag()
    end

    local inGroup = MaintenanceManager:getInstance():isEnabledInGroup("unlock_2025", 'ON')

    if inGroup then
        self:callViewFunc("playShowAnim")
    else
        self:lock()
        self:callViewFunc("playShowAnim"):next(function()
            self:unlock()
        end, function()
            self:unlock()
        end)
    end
end

return LastPeriodRankPanelVM
