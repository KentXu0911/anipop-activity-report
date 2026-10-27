local GiftMeta = require 'amf.feature.localactivity.merge.gift.GiftMeta'
local Meta = require 'amf.feature.localactivity.merge.config.MergeConfig'
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local UIButton = require "amf.middleware.ui.kit.component.button.UIButton"
local ActivityGiftPackageModule = require "amf.feature.giftpackage.module.activity.ActivityGiftPackageModule"
local deferred = require "amf.script.sugar.deferred"

local MergeGiftModule = class("MergeGiftModule", ActivityGiftPackageModule)
function MergeGiftModule:ctor(mgr)
    self._moduleName = "merge"
    self._actId = 6074
    self.mgr = mgr
    self.wantedGiftTb = nil
    self._version = 1

    -- 测试用
    -- self.testGiftMode = true
end

local bNeedShowLog = EnvUtil:isDevelopMode()
local channelId = 42

local function showLog( ... )
    if bNeedShowLog then
        if EnvUtil:isMiniGame() then
            -- UError(...)
        else
            -- printx(...)
        end
    end
end

function MergeGiftModule:requireExtraParams()
    local ret = {
        wants = {}
    }
    if not self.wantedGiftTb then return ret end
    ret.wants = self.wantedGiftTb
    return ret
end

------------------------礼包部分-----------------------------

function MergeGiftModule:createBuyButton(buttonData)
    if (not buttonData) or type(buttonData) ~= 'table' then return end

    local goodsId = buttonData.goodsId
    local price,isRMB,discount,originPrice = self:getPrice(goodsId)
    if discount and discount >= 1 then discount = nil end
    if buttonData.buyNum then
        price = price * buttonData.buyNum
    end

    local suffixStr = buttonData.suffixStr or " 购买"
    if isRMB then
        buttonData.str = "￥"..price
        if buttonData.rmbNeedSuffix then
            buttonData.str = buttonData.str .. suffixStr
        end
    else
        buttonData.str = {"gold",tostring(price),suffixStr}
    end

    if buttonData.needOriginPrice then
        buttonData.originPrice = {text = originPrice,isBelow = true}
    end

    --控制某些参数，剩下自己发挥
    buttonData.widthMode = UIButtonConfig.Widths.kShort
    buttonData.scaleMode = buttonData.scaleMode or UIButtonConfig.BtnScales.k90
    buttonData.colorMode = UIButtonConfig.ColorMode.blue
    buttonData.discount = discount and discount * 10
    if buttonData.noDiscountTip then buttonData.discount = nil end

    local button = UIButton:createButton(buttonData)
    if buttonData.touchFunc then
        button:setCallBack(buttonData.touchFunc)
    end
    button.isRMB = isRMB
    return button
end

-- 默认本地一定有礼包，查询礼包信息
function MergeGiftModule:getPrice(goodsId)
    if not goodsId or goodsId == 0 then return 0 end
    local goodsObj = GoodsManager:getGoods(goodsId)
    if not goodsObj then return 0 end
    local moneyType = goodsObj:getMoneyType()
    return goodsObj:getPrice(), moneyType == MoneyType.kRmb, goodsObj:getDiscount() / 10, goodsObj:getOriginPrice()
end

function MergeGiftModule:checkTimeToday(str)
    local actInfo = self.mgr:getActInfo()
    if not actInfo then return false end
    if not actInfo.extra then return false end
    local extra = table.deserialize(actInfo.extra)
    if not extra then return false end
    local buyTime = tonumber(extra[str] or 0)
    return TimeUtil:isSameDay(buyTime, TimeKit:timeInSec())
end

function MergeGiftModule:_checkPopStage4Gift()

    showLog(12,"_checkPopStage4Gift 11111")
    local popTime = self.mgr:getPopStage4GiftTime()
    local isIgnore = self.mgr:getIgnoredGiftToday()

    showLog(12,"_checkPopStage4Gift 22222", popTime, isIgnore )
    if popTime >= 3 or isIgnore then 
        return false 
    end 


    local payTag = self:getPayTag()

    showLog(12,"_checkPopStage4Gift 3333" , payTag)
    if (not payTag) or (payTag == 0) then
        if EnvUtil:isDevelopMode() then
            showLog(42, "你的payTag为0", debug.traceback())
        end
        return false
    end


    local successTime = self:getPassLevelTimeTody() 
    local boughtToday = self:checkTimeToday("latestBuyFlowTs")


    showLog(12,"_checkPopStage4Gift 4444" , successTime, boughtToday)
    -- 0付费
    if payTag == UsetPaymentTagServer.kNone then 
        -- 今日是否买过
        if boughtToday then return false end
        return successTime>=7
    end

    local energyNum = _G.amfBean("UserEnergyManager"):getEnergy()
    local cash = _G.amfBean("UserManager"):getCash()
    
    showLog(12,"_checkPopStage4Gift 5555" , energyNum, cash)

    local param = GiftMeta.judgeParam[payTag]
    if boughtToday then
        showLog(12,"_checkPopStage4Gift 66666" , energyNum, param.energyNum, cash, param.cashNum )
        return (energyNum < param.energyNum) or (cash < param.cashNum)
    else
        showLog(12,"_checkPopStage4Gift 66666" , energyNum, param.energyNum, cash, param.cashNum, successTime,param.passTime  )
        return (energyNum < param.energyNum) or (cash < param.cashNum) or (successTime>=param.passTime)
    end
end

-- 传入枚举table，拉取礼包信息，返回commonGiftData的List，靠extra的type拆风车币与rmb礼包
function MergeGiftModule:pullGiftByNames(nameTb)
    self._packages = nil
    self.wantedGiftTb = nameTb
    local promise = deferred.new()

    -- if self.testGiftMode and EnvUtil:isDevelopMode() then
    --     local returnGift = nil
    --     local goodsId = nil
    --     if nameTb[1] == Meta.GiftTypeEnum.BOOK then
    --         goodsId = 3542
    --     elseif nameTb[1] == Meta.GiftTypeEnum.BUFF then
    --         goodsId = 3539
    --     elseif nameTb[1] == Meta.GiftTypeEnum.CRUSH then
    --         goodsId = 3601
    --     elseif nameTb[1] == Meta.GiftTypeEnum.DISCOUNT then
    --         goodsId = 3589
    --     elseif nameTb[1] == Meta.GiftTypeEnum.ENERGY then
    --         goodsId = 3451
    --     elseif nameTb[1] == Meta.GiftTypeEnum.FLOW then
    --         goodsId = 3529
    --     elseif nameTb[1] == Meta.GiftTypeEnum.PROGRESS then
    --         goodsId = 3708
    --     elseif nameTb[1] == Meta.GiftTypeEnum.RANK then
    --         goodsId = 3708
    --     elseif nameTb[1] == Meta.GiftTypeEnum.SUPPLY then
    --         goodsId = 3437
    --     end
    --     returnGift = GoodsManager:getGoods(goodsId)
    --     function returnGift:isLimited()
    --         return false
    --     end
    --     function returnGift:getExtraValue()
    --         return true
    --     end
    --     promise:resolve({returnGift})
    --     return promise
    -- end

    -- printx(42, "pull start11", debug.traceback())
    local pullSuc = function()
        -- 拉成功了但是没礼包，也算失败
        if not self:hasGifts() then
            -- printx(42, "package empty reject")
            promise:reject()
            return
        end
        -- printx(42, "pull start12")
        promise:resolve(self._packages)
    end

    local pullFail = function()
        -- printx(42, "pull start13")
        promise:reject()
    end

    self:pullOnce(10, true):next(pullSuc, pullFail)
    return promise
end

-- 获取场景4可弹出的礼包id
function MergeGiftModule:_popStage4GoodsIdGet(callback)
    local pullSuc = function(giftList)
        if not self:hasGifts() then
            safeRunCall(callback)
            return
        end
        local commonGiftData = giftList[1]
        local goodsId = commonGiftData:getGoodsId()
        local checkBox = false
        if commonGiftData.extra and commonGiftData.extra.multiple then
            checkBox = commonGiftData.extra.multiple
        end
        -- printx(42, "22222222222222222", commonGiftData.extra.multiple)
        safeRunCall(callback, goodsId, checkBox)
    end

    self:pullGiftByNames({Meta.GiftTypeEnum.FLOW}):next(pullSuc, callback)
end

function MergeGiftModule:getPassLevelTimeTody()
    return self.mgr:getFlagFromLocalByKeyInt('passLevelSuccessTime',true)
end

-- 弹出礼包的时候清空
function MergeGiftModule:clearPassLevelTimeTody()
    self.mgr:saveFlagToLocalByKeyInt('passLevelSuccessTime',true,0)
end

-- 能获得收集物的主线|隐藏|活动关卡，过关的时候调一下
function MergeGiftModule:addPassLevelTimeTody()
	local curPassNum = self:getPassLevelTimeTody()
    self.mgr:saveFlagToLocalByKeyInt('passLevelSuccessTime',true,curPassNum+1)

    if bNeedShowLog then
        -- printx(channelId," **************** self.levelSucessTime", self:getPassLevelTimeTody())
    end
end

function MergeGiftModule:getPayTag()
	local perData = self.mgr:getData():getTodayPerDayMap()
    return perData.payTag or 0
end

return MergeGiftModule