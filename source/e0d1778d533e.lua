
local deferred = require "amf.script.sugar.deferred"
local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
local PaymentTracer = require 'amf.middleware.purchase.dc.trace.PaymentTracer'
local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"
---集卡-礼包 2026年03月11日 星期三
---@class CollectCardGiftModel
local CollectCardGiftModel = class("CollectCardGiftModel")


function CollectCardGiftModel:ctor()

    self._packages = nil
    self._moduleExtraData = nil

    self.moduleName = "cardCollect"

    self.dcFeature = "collect_card"
    self.dcSource = "card_gift"
    self.newGift_stage = "activity_scene"

    ---@type PaymentTracer[]
    self._rmbTracerArr = nil

    ---@type CollectCardManager
    self._mgr = _G.amfBean("CollectCardManager")

    self._isBuySucced = false
    self._isHaveCompCard = false
end

-- function CollectCardGiftModel:isOpen()
--     return true
-- end

--region getter

function CollectCardGiftModel:getPackageByCardIdx(idx)
    if not self._packages or #self._packages <= 0 then return nil end
    if idx <= 0 then return nil end
    local cardId = self:getCardIdByIdx(idx)
    local packageIdByCardId = self._moduleExtraData.packageIdByCardId or {}
    local packageId = packageIdByCardId[tostring(cardId)]
    for index, package in ipairs(self._packages) do
        if package:getGoodsId() == packageId then
            return package
        end
    end
    return nil
end

---@return CommonGiftData
function CollectCardGiftModel:getPackage()
    local idx = self:getSelectedIdx()
    return self:getPackageByCardIdx(idx)
end

function CollectCardGiftModel:getPackageId()
    local package = self:getPackage()
    return package and package:getGoodsId() or 0
end

function CollectCardGiftModel:getPackageRewards()
    local package = self:getPackage()
    return package and package:getItems() or nil
end

function CollectCardGiftModel:getTipType()
    local type = self._moduleExtraData and self._moduleExtraData.tips or 0
    return type
end

function CollectCardGiftModel:getCardIds()
    return self._moduleExtraData and self._moduleExtraData.cardIds or {}
end

function CollectCardGiftModel:getCardIdByIdx(idx)
    local ids = self:getCardIds()
    return ids[idx] or 0

end

function CollectCardGiftModel:getMustGetCardId()
    return self._moduleExtraData and self._moduleExtraData.needGetId or 0
end

function CollectCardGiftModel:_getPayResultParams(cardId)
    local albumId = 0
    local star = 0
    ---@type CardData
    local cardData = self._mgr:getCardDataById(cardId)
    if cardData then
        albumId = cardData.albumId
        star = cardData and cardData:getStarLevel() or 0
        if cardData:getCardType() == self._mgr:getConst().CardType.GOLD then star = star + 1 end
    end

    local str = string.format("%d_%d_%d", cardId, star, albumId)
    return {params={
        show_cards = str,
        circulation = self._mgr:getModel():getRoundId(),
    }}
end

function CollectCardGiftModel:isCanCompAlbumByCardId(cardId)
    local cardData = self._mgr:getCardDataById(cardId)
    if cardData == nil or cardData.getGotNum == nil then
        printx(48, "cardData error.cardData=",tts(cardData))
        return
    end
    if not cardData or cardData:getGotNum() > 0 then return false end
    ---@type AlbumData
    local albumData = self._mgr:getAlbumDataById(cardData.albumId)
    if not albumData then return false end

    local unIds = albumData:getUnCollectionCards()
    if unIds and #unIds == 1 then
        return unIds[1] == cardId
    end
    return false

end
--endregion

---callback(ret, packages)
function CollectCardGiftModel:requestGiftData(callback, userClick)
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        CommonTip:showTip("网络异常，请检查网络~")
        safeRunCall(callback, false, nil)
        return
    end

    --后端收到字段为true时会把tips的弹出状态清零
    local needRefresh = true

    local callbackPromise = deferred.new()
    callbackPromise:next(function (packages)
        -- if EnvUtil:isDevelopMode() then printx(48, "CollectCardGiftModel get data=", tts(packages)) end
        self._packages = packages
        local ret = true
        if packages and #packages > 0  then
            local moduleExtraMap = packages and #packages > 0 and packages[1]:getExtraValue("moduleExtra") or nil
            -- moduleExtraMap = "{\"configId\":15,\"packageIdByCardId\":{\"21406\":4618,\"21503\":4618},\"cardIds\":[21406,21503],\"tips\":0}" --debug
            local extraConfig = (moduleExtraMap) and table.deserialize(moduleExtraMap) or {}
            self._moduleExtraData = extraConfig
            if extraConfig then
                self:_sortCardIdsByStar()
                local ids = self:getCardIds()
                if not ids or table.isEmpty(ids) or #ids < 1 then
                    ret = false
                    printx(48, "CollectCardGiftModel error ids=", tts(ids))
                else
                    self:_initRmbTracer(userClick)

                    local curSelectIdx = self:getSelectedIdx()
                    local resetSelectIdx = curSelectIdx
                    if self:isCanShowBanner() then
                        resetSelectIdx = 0
                    end
                    if #ids == 1 then --只有一个
                        resetSelectIdx = 1
                    end
                    if resetSelectIdx ~= curSelectIdx then
                        self:setSelectedIdx(resetSelectIdx)
                        if EnvUtil:isDevelopMode() then
                            printx(48, "CollectCardGiftModel 重置选择下标=", resetSelectIdx)
                        end
                    end

                end
            else
                ret = false
            end
        else
            ret = false
        end
        if ret then

            CollectCardEventCenter:dispatch(CollectCardEvent.ON_GIFT_ICON_UPDATE, self._isHaveCompCard)
        else
            self:removeGiftIcon()
        end
        safeRunCall(callback, ret, packages)
    end, function ()
        CommonTip:showTip("网络异常，请稍后重试~")
        safeRunCall(callback, false, nil)
    end)

    GiftEventCenter:dispatch(GiftEvent.PULL_ACTIVITY_PACKAGE, {
        actId = 9087,
        moduleName = self.moduleName,
        callbackPromise = callbackPromise,
        params = {
            moduleVersion = 1,
            needRefresh = needRefresh
        },
    })
end



function CollectCardGiftModel:requestBuy(succCallback, failCallback)
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        CommonTip:showTip("网络异常，请检查网络~")
        safeRunCall(failCallback)
        return
    end
    local package = self:getPackage()
    if not package then
        safeRunCall(failCallback)
        return
    end

    local goodsId = package:getGoodsId()
    local cardId = self:getSelectedCardId()
    local rmbTracer = self:_getSelectedRmbTracer()

    local dc_others = self:_getPayResultParams(cardId)
    local showRewards = self:getPackageRewards()
    local function onSuccess(evt)
        local isActEnable = self._mgr and self._mgr:isActValid()
        if rmbTracer then rmbTracer:paySuccess(dc_others) end
        self._isBuySucced = true
        --删除礼包icon
        self:removeGiftIcon()

        if isActEnable then
            -- 加卡 增加1就行，可能完成小卡册，或者整轮完成
            self._mgr:onGetCard(cardId, 1)
        end

        -- self._mgr:addRewardsNormal(showRewards)

        local function onPopupCardRewardPanel()
            -- CommonTip:showTip("礼包-弹出卡片奖励")
            ---@type NewCardShowRewardVM
            local ShowRewardsPanelVM = require "amf.feature.localactivity.collectcard.view.NewCardShowRewardVM"
            local vm = ShowRewardsPanelVM.Builder.new()
                :setTitle("恭喜获得")
                -- :setRewards(showRewards)
                :setCardId(cardId)
                :setCloseCallback(function ()
                    safeRunCall(succCallback)
                    -- self._mgr:tryStartSettleAlbumFlow()
                    printx(48, "卡片奖励get, COLLECT_CARD_FLOW")
                    _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
                        flowType = "settle",
                        onComplete = function()
                            printx(33, "SettleCardRewardFlow complete callback")
                        end,
                        onError = function()
                            printx(33, "SettleCardRewardFlow error callback")
                        end,
                    })
                    self:setSelectedIdx(0)
                end)
                :setButtonText("收下")
                :build()
            vm:popout()
        end

        local ShowRewardsPanelVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelVM"
        local vm = ShowRewardsPanelVM.Builder.new()
            :setTitle("恭喜获得")
            :setRewards(showRewards)
            :setCloseCallback(function ()
                if isActEnable then
                    onPopupCardRewardPanel()
                end
            end)
            :setButtonText("收下")
            :build()
        vm:popout()
    end

    local function onFail(evt)
        if rmbTracer then rmbTracer:payFail(dc_others) end
        safeRunCall(failCallback)
    end

    local function onCancel()
        if rmbTracer then rmbTracer:payCancel(dc_others) end
        safeRunCall(failCallback)
    end

    local buyContext = BuyContext.new(goodsId, MoneyType.kRmb)
        :setFeatureAndSource(self.dcFeature, self.dcSource)
        :setBuyCount(1)
        :setCallback(onSuccess, onFail, onCancel)
        :setUnifiedBuy(true, self.newGift_stage, self.moduleName)
        :setPreOrderExtraParam({cardId=cardId})
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
    if rmbTracer then rmbTracer:click() end
end

function CollectCardGiftModel:onPanelClose()
    local rmbTracer = self:_getSelectedRmbTracer()
    if not rmbTracer then return end

    local cardId = self:getSelectedCardId()
    rmbTracer:close(self:_getPayResultParams(cardId))
end

function CollectCardGiftModel:_initRmbTracer(userClick)
    self._rmbTracerArr = {}
    for index, package in ipairs(self._packages) do
        local packageId = package:getGoodsId()
        local rmbTracer = PaymentTracer.createRMBPayTracer(
            self.dcFeature,
            self.dcSource,
            packageId,
            userClick and DCPayProgressPayPanelShowType.kUserClick or DCPayProgressPayPanelShowType.kAutoPopout
        )
        self._rmbTracerArr[packageId] = rmbTracer
    end
end

function CollectCardGiftModel:_rmbTracerPayShow(others)
    local rmbTracer = self:_getSelectedRmbTracer()
    if rmbTracer then rmbTracer:show(others) end
end

function CollectCardGiftModel:_getSelectedRmbTracer()
    if not self._rmbTracerArr then return nil end
    local packageId = self:getPackageId()
    local rmbTracer = self._rmbTracerArr[packageId]
    return rmbTracer
end


function CollectCardGiftModel:onActPlayLevelEnd()
    self:_savePlayLevelNum()

end

--region 强弹

local _gift_daily_popup_1 = "gift_daily_popup_1"
local _gift_daily_popup_2 = "gift_daily_popup_2"
local _playLevelNumKey = "gift_p2_playLevelNum"

function CollectCardGiftModel:canAutoPopup()
    if not self._mgr:getModel():isInGiftTime() then return false end
    if self._isBuySucced then return false end
    local ret = self:_canAutoPopup1()
    if not ret then
        ret = self:_canAutoPopup2()
    end
    return ret
end

function CollectCardGiftModel:_canAutoPopup1()
    local ret = self._mgr:getFlagFromLocalByKey(_gift_daily_popup_1, true) == false
    if EnvUtil:isDevelopMode() then printx(48, "CollectCardGiftModel _canAutoPopup1 ret=", ret) end
    return ret
end

function CollectCardGiftModel:setAutoPopup()
    local key = _gift_daily_popup_1
    local isPopup1 = self:_canAutoPopup1()
    if not isPopup1 then key = _gift_daily_popup_2 end

    if EnvUtil:isDevelopMode() then printx(48, "CollectCardGiftModel setAutoPopup key=", key) end
    self._mgr:setFlagToLocalByKey(key, true, true)
end

function CollectCardGiftModel:_canAutoPopup2()
    local ret = self:_isPopup2_cond1()
    if not ret then return false end

    local num = self._mgr:getIntFromLocalByKey(_playLevelNumKey, true)
    ret = num > 3
    if EnvUtil:isDevelopMode() then printx(48, "CollectCardGiftModel _canAutoPopup2 ret=", ret) end
    return ret
end

---强弹条件1 - 本次礼包数据有可完成的小卡册
function CollectCardGiftModel:_isPopup2_cond1()
    local ret = self._mgr:getFlagFromLocalByKey(_gift_daily_popup_2, true) == false
    if not ret or not self._packages then return false end
    for _, cardId in pairs(self:getCardIds()) do
        if self:isCanCompAlbumByCardId(cardId) then
            return true
        end
    end
    return false
end


function CollectCardGiftModel:_savePlayLevelNum()
    if self:_canAutoPopup1() then return end

    local cond1 = self:_isPopup2_cond1()
    if not cond1 then return end

    local ret = self._mgr:getIntFromLocalByKey(_playLevelNumKey, true)
    if ret > 4 then return end
    ret = ret + 1
    self._mgr:setIntFromLocalByKey(_playLevelNumKey, true, ret)
end

--endregion

function CollectCardGiftModel:getExtraId()
    local id = (self._moduleExtraData or {}).configId
    if id == nil then id = 1 end
    return id
end

function CollectCardGiftModel:_getCanShowKey()
    local id = self:getExtraId()
    local pId = self._mgr:getModel():getPeriodId()
    local rId = self._mgr:getModel():getRoundId()
    local ret = string.format("gift_showAnim_%d_%d_%d", pId, rId, id)
    return ret
end

function CollectCardGiftModel:isCanShowAnim()
    local key = self:_getCanShowKey()
    local ret = self._mgr:getFlagFromLocalByKey(key, false) == false
    return ret

end

function CollectCardGiftModel:setShowedAnim()
    local key = self:_getCanShowKey()
    self._mgr:setFlagToLocalByKey(key, false, true)
end

function CollectCardGiftModel:isCanShowBanner()
    local tipType = self:getTipType()
    return tipType ~= 0
end

function CollectCardGiftModel:setShowedBanner(showed)
    self._moduleExtraData.tips = 0
end


function CollectCardGiftModel:_getSelectIdxKey()
    local id = self:getExtraId()
    local pId = self._mgr:getModel():getPeriodId()
    local rId = self._mgr:getModel():getRoundId()
    local ret = string.format("gift_selectIdx_%d_%d_%d", pId, rId, id)
    return ret
end

function CollectCardGiftModel:getSelectedIdx()
    -- do return 0 end --debug
    local key = self:_getSelectIdxKey()
    local ret = self._mgr:getIntFromLocalByKey(key, false)
    return ret
end

--刷新
function CollectCardGiftModel:setSelectedIdx(value)
    local key = self:_getSelectIdxKey()
    self._mgr:setIntFromLocalByKey(key, false, value)

    if value ~= 0 then
        local ids = self:getCardIds()
        local dcStr = table.join(ids, "_")
        local selectCardId = self:getSelectedCardId()
        local others = {params={show_cards=dcStr, choice_card=selectCardId}}
        self:_rmbTracerPayShow(others)
    end
end

function CollectCardGiftModel:getSelectedCardId()
    local idx = self:getSelectedIdx()
    if idx <= 0 then return 0 end
    local cardId = self:getCardIdByIdx(idx)
    return cardId
end

function CollectCardGiftModel:_sortCardIdsByStar()
    local ids = self:getCardIds()
    if not ids or #ids <= 2 then return end

    self._isHaveCompCard = false
    local cardDatas = {}
    for i, cardId in ipairs(ids) do
        local cardData = self._mgr:getCardDataById(cardId)
        local star = cardData and cardData:getStarLevel() or 0
        if cardData:getCardType() == self._mgr:getConst().CardType.GOLD then star = star + 1 end
        local albumData = self._mgr:getAlbumDataById(cardData and cardData.albumId or 0)
        local collectedCount = albumData and albumData:getCollectedCount() or 0
        table.insert(cardDatas, {id = cardId, priority = collectedCount * 100 + star})
        local canComp = self:isCanCompAlbumByCardId(cardId)
        if canComp then self._isHaveCompCard = true end
    end
    table.sort(cardDatas, function(a, b) return a.priority < b.priority end)

    local n = #cardDatas
    local sorted = {}
    if n == 3 then
        sorted[1] = cardDatas[1].id
        sorted[2] = cardDatas[3].id
        sorted[3] = cardDatas[2].id
    else
        for i = 1, n do
            sorted[i] = cardDatas[i].id
        end
    end

    self._moduleExtraData.cardIds = sorted
end

function CollectCardGiftModel:dcOpenGiftView()
    local dcStr = ""
    local ids = self:getCardIds()
    dcStr = table.join(ids, "_")
    self._mgr:dcActPlug():dcCommon(self.dcFeature, self.dcSource, {show_cards=dcStr})
end

function CollectCardGiftModel:removeGiftIcon()
    if not self._mgr then return end
    --删除礼包icon
    self._mgr:setDataByKey("giftBeginTime", 0)
    self._mgr:setDataByKey("giftEndTime", 0)
    self._mgr:updateGiftIcon()
end

return CollectCardGiftModel
