local ActionUtil = require 'amf.middleware.ui.util.ActionUtil'
local TimeUtil = require 'amf.middleware.ui.util.TimeUtil'

local ProcessGiftMgr = class("ProcessGiftMgr")

local checkDebugMsg = {}
local qq = {
    log = function(...)
        --
--
--
--

    end,
    cacheResult = function(str)
        --
--
--
--
--
--

    end
}

--===========================================

--活动主manager
function ProcessGiftMgr:setHostMgr(hostMgr)
    self.hostMgr = hostMgr
end

--设置goods列表， {A, B, C, D, E, F, G, H}
function ProcessGiftMgr:setGoodsList(goodsIds)
    local levels = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'}
    for k, v in pairs(goodsIds) do
        if levels[k] then
            self.goodsMap[levels[k]] = v
        end
    end
end

function ProcessGiftMgr:clearGoodsMap()
    self.goodsMap = {}
end

--打点feature, source
function ProcessGiftMgr:setDcFeatureAndSource(feature, source)
    self.dcFeature = feature
    self.dcSource = source
end

--设置payTag和活动结束时间
function ProcessGiftMgr:updateData(payTag, giftEndTime)
    self.giftEndTime = giftEndTime or 0
    self.payTag = payTag or UserPaymentTag2Index[UserTagManager:getUserPaymentTag2()] or 1
end


--检测是否可以弹出礼包
function ProcessGiftMgr:checkPopout()
    checkDebugMsg = {}
    --if EnvUtil:isWindows() then
    --    self.payTag = 6
    --end

    local nonePopup = self:getNonePopupToday()
    if nonePopup then
        qq.log('checkPopout', '上次勾选过今日不再弹出')
        qq.cacheResult('上次勾选过今日不再弹出')
        return
    end

    local topLv = _G.amfBean("LevelUnLockManager"):getLocalTopLevel(false)
    local myTopLv = _G.getTopPassedLevelId()
    if topLv - myTopLv <= 30 then
        local lastOpenTime = _G.amfBean("LevelUnLockManager"):getLastOpenNewLevelTime()
        if lastOpenTime then
            local diffTime = TimeKit:timeInSec() - lastOpenTime
            if diffTime>=0 and diffTime< 4*3600 then
                qq.log('checkPopout', '发新关当日头部30关玩家四小时内不强弹')
                qq.cacheResult('发新关当日头部30关玩家四小时内不强弹礼包')
                return
            end
        end
    end

    qq.log('checkPopout', tts(self.local_data))
    local payTag = self.payTag
    if self['get_goodsId_pay_'..payTag] then
        local popGiftId = self['get_goodsId_pay_'..payTag](self)
        local canPop = popGiftId and (not self:isPoppedToday(popGiftId))
        qq.cacheResult('最终检测结果：'..(canPop and '允许强弹礼包：'..popGiftId or '不允许强弹'))
        if canPop then
            self.popGiftId = popGiftId
        else
            self.popGiftId = nil
        end
        qq.log('canPop', canPop, self.popGiftId)
        return canPop
    end
end

function ProcessGiftMgr:disableMock()
    self.disMock = true
end

function ProcessGiftMgr:useNewGiftPackages(value)
    self.useNewPackages = value
end

--强弹礼包界面
function ProcessGiftMgr:openGiftPanelByPopup(callback, PopupGiftPanelVM)
    if EnvUtil:isWindows() and not self.disMock then
        self.popGiftId = 2626
        self.payTag = 2
    end

    if not PopupGiftPanelVM then
        PopupGiftPanelVM = require(self.giftPanelLua)
    end 

    if self.popGiftId then
        self:setPopped(self.popGiftId)
        self:resetPassLevelToday()

        local multipleGift = self:getGoodsNumByPayTag(self.payTag)>1
        
        local panelVM = PopupGiftPanelVM:create(self.popGiftId, multipleGift, self, callback)
        -- printx(41,"aswdawwwasw",tts(panel))
        panelVM:setBuyHandler(function(goodsId, afterSuccess, failCall, cancelCall)
            qq.log('buyGoods 0', goodsId)
            self:buyGoods(goodsId, afterSuccess, failCall, cancelCall)
        end)
        panelVM:popout()
    else
        if callback then callback() end
    end
end


--============================================
function ProcessGiftMgr:create(giftKey)
    local mgr = ProcessGiftMgr.new()
    mgr:init(giftKey)
    return mgr
end

function ProcessGiftMgr:init(giftKey)
    giftKey = giftKey or 'processGift'
    self.goodsMap = {}
    self.giftEndTime = 0
    self.payTag = 0

    local ProcessDataRef = require 'amf.feature.localactivity.processgiftautopopup.ProcessDataRef'
    self.io = ProcessDataRef:create("ProcessGiftMgr")

    self.skipKey = giftKey .. "_skip"
    self.boughtKey = giftKey .. "_bought"
    self.poppedKey = giftKey .. "_popped"
    self.passLevelKey = giftKey .. "_today_pass_level"
    self.nonePopupKey = giftKey .. '_today_none_popup'
    self.dcFeature = 'activity'
    self.dcSource = 'act_actId_0'
    -- Notify:register('ProcessGiftMgr_QATools',function(data) self:onTestPanelOpen(data) end)
end

function ProcessGiftMgr:getPayTagMap()
    return {
        ['0'] = {'A'},
        ['1'] = {'A', 'B'},
        ['2'] = {'A', 'B', 'C'},
        ['3'] = {'B', 'C', 'D'},
        ['4'] = {'D', 'E', 'F'},
        ['5'] = {'E', 'F', 'G'},
        ['6'] = {'F', 'G', 'H'},
    }
end

function ProcessGiftMgr:getGoodsTypes(payTag)
    return self:getPayTagMap()[tostring(payTag)]
end

function ProcessGiftMgr:getGoodsNumByPayTag(payTag)
    local goodsTypes = self:getGoodsTypes(payTag)
    if goodsTypes then
        return #goodsTypes
    end
    return 1
end

function ProcessGiftMgr:getGoodsIdsByTag(payTag)
    local gIds = {}
    local goodsTypes = self:getGoodsTypes(payTag)
    if goodsTypes then
        for _, v in ipairs(goodsTypes) do
            local id = self.goodsMap[v]
            if id then
                table.insert(gIds, id)
            end
        end
    end

    return gIds
end

function ProcessGiftMgr:getGoodsLevel(goodsId)
    local levels = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'}
    for i, v in pairs(levels) do
        local gId = self.goodsMap[v]
        if gId == goodsId then
            return i
        end
    end
    return 1
end

function ProcessGiftMgr:createPaymentTracer(goodsId, isClick)
    local PaymentTracer = require 'amf.middleware.purchase.dc.trace.PaymentTracer'
    return PaymentTracer.createRMBPayTracer(
            self.dcFeature,
            self.dcSource,
            goodsId,
            isClick and DCPayProgressPayPanelShowType.kUserClick or DCPayProgressPayPanelShowType.kAutoPopout
    )
end

function ProcessGiftMgr:readFromLocal()
    local data =self.io:getValue("saveData") or {}
    return data
end

function ProcessGiftMgr:writeToLocal()
    self.io:setValue('saveData', self.local_data, true )
end

function ProcessGiftMgr:setLocalData(key, val)
    if not self.local_data then
        self.local_data = self:readFromLocal()
    end
    self.local_data[key] = val
    self:writeToLocal()
end

function ProcessGiftMgr:getLocalData(key, default)
    printx(23, key)
    if not self.local_data then
        self.local_data = self:readFromLocal()
    end
    return self.local_data[key] or default
end

function ProcessGiftMgr:getLocalKey(key, goodId)
    return key..'_'..self.payTag ..'_'..goodId
end

--获取当前阶段结束时间
function ProcessGiftMgr:getActEndTime()
    return math.floor(self.giftEndTime/1000)
end

function ProcessGiftMgr:afterBuyGoods(goodsId)
    self:setBought(goodsId)
    if self.hostMgr and self.hostMgr.setBoughtToday then
        self.hostMgr:setBoughtToday(goodsId)
    end
end

--今日不再弹出
function ProcessGiftMgr:getNonePopupToday()
    local ds = TimeKit:getTodayStart()
    local key = self:getLocalKey(self.nonePopupKey, 1)..'_'..ds
    local ret = self:getLocalData(key, false)
    qq.log('getNonePopupToday', ret)
    return ret
end

function ProcessGiftMgr:setNonePopupToday(checked)
    local ds = TimeKit:getTodayStart()
    local key = self:getLocalKey(self.nonePopupKey, 1)..'_'..ds
    qq.log('setNonePopupToday, checked ', checked)
    self:setLocalData(key, checked)
end


--累计多少次没买这个礼包了
function ProcessGiftMgr:getSkipTimes(goodsId)
    return self:getLocalData(self:getLocalKey(self.skipKey, goodsId), 0)
end

function ProcessGiftMgr:setSkipTimes(goodsId, times)
    self:setLocalData(self:getLocalKey(self.skipKey, goodsId), times)
end

function ProcessGiftMgr:addSkipTimes(goodsId)
    local key = self:getLocalKey(self.skipKey, goodsId)
    local nowTimes = self:getLocalData(key, 0)
    self:setLocalData(key, nowTimes+1)
end

--活动期是否买这个礼包了
function ProcessGiftMgr:isBought(goodsId)
    if self:isBoughtToday(goodsId) then return true end

    local key = self:getLocalKey(self.boughtKey, goodsId)
    local ret = self:getLocalData(key, false)
    qq.log('isBought', goodsId, ret)
    if ret then
        qq.cacheResult('活动期间买过礼包：'..goodsId)
    else
        qq.cacheResult('活动期间没有买过礼包：'..goodsId)
    end
    return ret
end

function ProcessGiftMgr:setBought(goodsId)
    local key = self:getLocalKey(self.boughtKey, goodsId)
    self:setLocalData(key, true)
    self:setSkipTimes(goodsId, 0)
end

--今天是否买这个礼包了
function ProcessGiftMgr:isBoughtToday(goodsId)
    local rtn
    if self.hostMgr and self.hostMgr.isBoughtToday then
        rtn = self.hostMgr:isBoughtToday(goodsId)
    else
        rtn = _G.amfBean("DailyDataManager"):getDailyBoughtGoodsNumById(goodsId)>0
    end

    qq.log('isBoughtToday', goodsId, rtn)
    if rtn then
        qq.cacheResult('今日已经购买过此礼包：'..goodsId)
    else
        qq.cacheResult('今日没有购买过此礼包：'..goodsId)
    end
    return rtn
end

--今日是否弹出这个礼包了
function ProcessGiftMgr:isPoppedToday(goodsId)
    local ds = TimeKit:getTodayStart()
    local key = self:getLocalKey(self.poppedKey, goodsId)
    local ret = self:getLocalData(key, 0) == ds
    qq.log('isPoppedToday', goodsId, ret)
    if ret then
        qq.cacheResult('今日已经弹出过此礼包：'..goodsId)
    else
        qq.cacheResult('今日还未弹出过此礼包：'..goodsId)
    end

    return ret
end

function ProcessGiftMgr:setPopped(goodsId)
    local key = self:getLocalKey(self.poppedKey, goodsId)
    local ds = TimeKit:getTodayStart()
    self:setLocalData(key, ds)
    qq.log('setPopped', goodsId)
    self:addSkipTimes(goodsId) --先默认跳过不买，如果买了，在购买逻辑重置
end

--今日累计过关数
function ProcessGiftMgr:getPassLevelToday()
    local ds = TimeKit:getTodayStart()
    local key = self.passLevelKey..'_'..ds
    local ret = self:getLocalData(key, 0)
    qq.log('getPassLevelToday', ret)
    return ret
end

function ProcessGiftMgr:addPassLevelToday()
    local ds = TimeKit:getTodayStart()
    local key = self.passLevelKey..'_'..ds
    local oldNum = self:getLocalData(key, 0)
    qq.log('addPassLevelToday, oldNum is ', oldNum)
    self:setLocalData(key, oldNum + 1)
end

function ProcessGiftMgr:resetPassLevelToday()
    local ds = TimeKit:getTodayStart()
    local key = self.passLevelKey..'_'..ds
    qq.log('resetPassLevelToday')
    self:setLocalData(key, 0)
end


--是否连续N次弹出但未购买
function ProcessGiftMgr:isSkippedNTime(goodsId, num, expectNot)
    local skipTimes = self:getSkipTimes(goodsId)
    qq.log('isSkippedNTime', goodsId, num, skipTimes)

    if expectNot then
        if skipTimes >= num then
            qq.cacheResult('礼包'..goodsId..'连续'..skipTimes..'次弹出但未购买，超过最大次数：'..num)
        end
    else
        qq.cacheResult('礼包'..goodsId..'连续'..skipTimes..'次弹出但未购买，目标次数：'..num)
    end

    return skipTimes >= num
end

--是否精力不足
function ProcessGiftMgr:isLackEnergy()
    qq.log('isLackEnergy')
    local energyState = _G.amfBean("UserEnergyManager"):getEnergyState()
    if energyState == UserEnergyState.INFINITE then
        return false
    end
    if _G.amfBean("UserEnergyManager"):getEnergy() >= 10 then
        return false
    end
    qq.log('isLackEnergy', true)
    qq.cacheResult("当前处在精力不足状态")
    return true
end

--是否成功过关N次
function ProcessGiftMgr:isPassLevelNTimes(times)
    local localTimes = self:getPassLevelToday()
    qq.cacheResult('当前过关次数'..localTimes..'，目标次数：'..times)
    return localTimes >= times
end

--是否在双倍buff时间内
function ProcessGiftMgr:isInDoubleBuffTime()
    local buffEndTime = self:getDoubleBuffEndTime()
    local ret = buffEndTime>TimeKit:timeInSec()
    qq.log('isInDoubleBuffTime', ret)
    qq.cacheResult('当前'..(ret and '处于' or '不处于')..'收集物双倍buff时间内')

    return ret
end

--双倍buff时间<5min
function ProcessGiftMgr:isLackDoubleBuffTime()
    local buffEndTime = self:getDoubleBuffEndTime()
    local ret = (buffEndTime-TimeKit:timeInSec()) < 300
    qq.log('isLackDoubleBuffTime', ret)
    qq.cacheResult('收集物双倍buff时间'..(ret and '不足5分钟' or '大于5分钟'))

    return ret
end

--获取各个活动期双倍buff结束时间
function ProcessGiftMgr:getDoubleBuffEndTime()
    local buffEndTime = 0
    if self.hostMgr and self.hostMgr.getBuffEndTime then
        buffEndTime = self.hostMgr:getBuffEndTime()
    end
    qq.log('getDoubleBuffEndTime', buffEndTime)
    return TimeUtil:convertSec(buffEndTime)
end


--0 pay 玩家
function ProcessGiftMgr:get_goodsId_pay_0()
    local gIds = self:getGoodsIdsByTag(0)
    qq.log('get_goodsId_pay_0', tts(gIds))
    local goods_1 = gIds[1]
    qq.cacheResult('0 pay 玩家, 检测1元礼包：'..(goods_1 or "空"))

    if goods_1 then
        qq.log('get_goodsId_pay_0', 'goods_1', goods_1)

        --今日是否已经弹过
        --是否连续3次弹出但未购买
        if not self:isPoppedToday(goods_1) and
                not self:isSkippedNTime(goods_1, 3, true) then
            qq.cacheResult('可以弹出1元礼包：'..goods_1)
            return goods_1
        end
    end
    qq.cacheResult('不符合弹出条件')
end

--1di付费玩家
function ProcessGiftMgr:get_goodsId_pay_1()
    local gIds = self:getGoodsIdsByTag(1)
    qq.log('get_goodsId_pay_1', tts(gIds))

    --=============goods_1==============
    local goods_1 = gIds[1]
    if not goods_1 then return end
    qq.log('get_goodsId_pay_1', 'goods_1', goods_1)
    qq.cacheResult('1di 玩家, 检测1元礼包：'..goods_1)

    --今日是否已经弹过
    --是否连续3次弹出但未购买
    if not self:isPoppedToday(goods_1) and
            not self:isSkippedNTime(goods_1, 3, true)  and
            not self:isBoughtToday(goods_1)
    then
        qq.cacheResult('可以弹出1元礼包：'..goods_1)
        return goods_1
    end
    qq.cacheResult('不可以弹出1元礼包：'..goods_1..',开始检测其他礼包')

    --=============goods_3==============
    local goods_3 = gIds[2]
    if not goods_3 then return end
    --买过了就不给买了， 付费能力有限
    if self:isBought(goods_3) then
        qq.cacheResult('活动期间已经买过3元礼包：'..goods_3..',付费能力有限,买过了就不给买了')
        return
    end
    if self:isSkippedNTime(goods_3, 3, true) then
        qq.cacheResult('连续3次跳过3元礼包'..goods_3..'，不再弹出')
        return
    end

    local preconditionOK
    qq.log('get_goodsId_pay_1', 'goods_3', goods_3)
    if self:isSkippedNTime(goods_1, 3) then
        preconditionOK = self:isLackEnergy()
    else
        if self:isBoughtToday(goods_1) then
            preconditionOK = not self:isInDoubleBuffTime()
        else
            preconditionOK = self:isLackEnergy()
        end
    end

    if preconditionOK then
        qq.cacheResult('可以弹出3元礼包：'..goods_3)
        return goods_3
    end
    qq.cacheResult('不可以弹出3元礼包：'..goods_3)
end

--2zh付费玩家
function ProcessGiftMgr:get_goodsId_pay_2()
    local gIds = self:getGoodsIdsByTag(2)
    qq.log('get_goodsId_pay_2', tts(gIds))

    --=============goods_1==============
    local goods_1 = gIds[1]
    if not goods_1 then return end
    qq.log('get_goodsId_pay_2', 'goods_1', goods_1)
    qq.cacheResult('2zh 玩家, 检测1元礼包：'..goods_1)

    --今日是否已经弹过
    --是否连续3次弹出但未购买
    if not self:isPoppedToday(goods_1) and
            not self:isSkippedNTime(goods_1, 4, true)  and
            not self:isBoughtToday(goods_1)
    then
        qq.cacheResult('可以弹出1元礼包：'..goods_1)
        return goods_1
    end
    qq.cacheResult('不可以弹出1元礼包：'..goods_1..',开始检测其他礼包')

    --=============goods_3, goods_6==============
    local preconditionOK
    if self:isSkippedNTime(goods_1, 4) then
        preconditionOK = self:isLackEnergy()
    else
        if self:isBoughtToday(goods_1) then
            preconditionOK = not self:isInDoubleBuffTime()
        else
            preconditionOK = self:isLackEnergy()
        end
    end
    if not preconditionOK then
        qq.cacheResult('3/6元礼包前置条件不满足')
        return
    end

    local goods_6 = gIds[3]
    if goods_6 then
        qq.log('get_goodsId_pay_2', 'goods_6', goods_6)
        qq.cacheResult('2zh 玩家, 检测6元礼包：'..goods_6)
        if self:isSkippedNTime(goods_6, 3) then
            local goods_3 = gIds[2]
            qq.log('get_goodsId_pay_2', 'goods_3', goods_3)
            qq.cacheResult('2zh 玩家, 检测3元礼包：'..goods_3)
            if goods_3 and not self:isSkippedNTime(goods_3, 3, true) and not self:isBoughtToday(goods_3) then
                qq.cacheResult('可以弹出3元礼包：'..goods_3)
                return goods_3
            end
            qq.cacheResult('不可以弹出3元礼包：'..goods_3)
        elseif not self:isBought(goods_6) then
            qq.cacheResult('可以弹出6元礼包：'..goods_6)
            return goods_6
        end
        qq.cacheResult('不可以弹出6元礼包：'..goods_6)
    end
end

--3zh2付费玩家
function ProcessGiftMgr:get_goodsId_pay_3()
    local gIds = self:getGoodsIdsByTag(3)
    qq.log('get_goodsId_pay_3', tts(gIds))

    --=============goods_3==============
    local goods_3 = gIds[1]
    if not goods_3 then return end
    qq.log('get_goodsId_pay_3', 'goods_3', goods_3)
    qq.cacheResult('3zh2 玩家, 检测3元礼包：'..goods_3)

    --今日是否已经弹过
    --是否连续5次弹出但未购买
    if not self:isPoppedToday(goods_3) and
            not self:isSkippedNTime(goods_3, 5, true)  and
            not self:isBoughtToday(goods_3)
    then
        qq.cacheResult('可以弹出3元礼包：'..goods_3)
        return goods_3
    end
    qq.cacheResult('不可以弹出3元礼包：'..goods_3..',开始检测其他礼包')

    --=============goods_6, goods_12==============
    local preconditionOK
    if self:isSkippedNTime(goods_3, 5) then
        preconditionOK = self:isPassLevelNTimes(3)
    else
        if self:isBoughtToday(goods_3) then
            preconditionOK = self:isLackDoubleBuffTime()
        else
            preconditionOK = self:isPassLevelNTimes(3)
        end
    end
    if not preconditionOK then
        qq.cacheResult('6/12元礼包前置条件不满足')
        return
    end

    local goods_12 = gIds[3]
    if goods_12 then
        qq.log('get_goodsId_pay_3', 'goods_12', goods_12)
        qq.cacheResult('3zh2 玩家, 检测12元礼包：'..goods_12)

        if self:isSkippedNTime(goods_12, 3) then
            local goods_6 = gIds[2]
            qq.log('get_goodsId_pay_3', 'goods_6', goods_6)
            qq.cacheResult('3zh2 玩家, 检测6元礼包：'..goods_6)

            if goods_6 and not self:isSkippedNTime(goods_6, 3, true) and not self:isBoughtToday(goods_6) then
                qq.cacheResult('可以弹出6元礼包：'..goods_6)
                return goods_6
            end
            qq.cacheResult('不可以弹出6元礼包：'..goods_6)
        elseif not self:isBoughtToday(goods_12) then
            qq.cacheResult('可以弹出12元礼包：'..goods_12)
            return goods_12
        end
        qq.cacheResult('不可以弹出12元礼包：'..goods_12)
    end
end

--4gao付费玩家
function ProcessGiftMgr:get_goodsId_pay_4()
    local gIds = self:getGoodsIdsByTag(4)
    qq.log('get_goodsId_pay_4', tts(gIds))

    --=============goods_30==============
    local goods_30 = gIds[2]
    if not goods_30 then return end
    qq.log('get_goodsId_pay_4', 'goods_30', goods_30)
    qq.cacheResult('4gao 玩家, 检测30元礼包：'..goods_30)
    --今日是否已经弹过
    --是否连续5次弹出但未购买
    if not self:isPoppedToday(goods_30) and
            not self:isSkippedNTime(goods_30, 5, true)  and
            not self:isBoughtToday(goods_30)
    then
        qq.cacheResult('可以弹出30元礼包：'..goods_30)
        return goods_30
    end
    qq.cacheResult('不可以弹出30元礼包：'..goods_30..',开始检测其他礼包')

    --=============goods_12, goods_68==============
    local preconditionOK
    if self:isSkippedNTime(goods_30, 5) then
        preconditionOK = self:isPassLevelNTimes(3)
    else
        if self:isBoughtToday(goods_30) then
            qq.cacheResult('今天买过30元礼包，只能检测68元礼包了')

            if self:isLackDoubleBuffTime() then
                local goods_68 = gIds[3]
                qq.log('get_goodsId_pay_4', 'goods_68', goods_68)
                qq.cacheResult('4gao 玩家, 检测68元礼包：'..(goods_68 or "空"))

                if goods_68 then
                    if not self:isSkippedNTime(goods_68, 3, true) and not self:isBoughtToday(goods_68) then
                        qq.cacheResult('可以弹出68元礼包：'..goods_68)
                        return goods_68
                    end
                end
                return
            end
            qq.cacheResult('不可以弹出68元礼包')
        else
            preconditionOK = self:isPassLevelNTimes(3)
        end
    end
    if not preconditionOK then
        qq.cacheResult('12元礼包前置条件不满足')
        return
    end

    local goods_12 = gIds[1]
    if goods_12 then
        qq.log('get_goodsId_pay_4', 'goods_12', goods_12)
        qq.cacheResult('4gao 玩家, 检测12元礼包：'..goods_12)

        if not self:isSkippedNTime(goods_12, 3, true) and not self:isBoughtToday(goods_12) then
            qq.cacheResult('可以弹出12元礼包：'..goods_12)
            return goods_12
        end
        qq.cacheResult('不可以弹出12元礼包：'..goods_12)
    end
end

--5gao付费玩家
function ProcessGiftMgr:get_goodsId_pay_5()
    local gIds = self:getGoodsIdsByTag(5)
    qq.log('get_goodsId_pay_5', tts(gIds))

    --=============goods_30==============
    local goods_68 = gIds[2]
    if not goods_68 then return end
    qq.log('get_goodsId_pay_5', 'goods_68', goods_68)
    qq.cacheResult('5gao 玩家, 检测68元礼包：'..goods_68)
    --今日是否已经弹过
    --是否连续5次弹出但未购买
    if not self:isPoppedToday(goods_68) and
            not self:isSkippedNTime(goods_68, 5, true)  and
            not self:isBoughtToday(goods_68)
    then
        qq.cacheResult('可以弹出68元礼包：'..goods_68)
        return goods_68
    end
    qq.cacheResult('不可以弹出68元礼包：'..goods_68..',开始检测其他礼包')

    --=============goods_30, goods_98==============
    local preconditionOK
    if self:isSkippedNTime(goods_68, 5) then
        preconditionOK = self:isPassLevelNTimes(3)
    else
        if self:isBoughtToday(goods_68) then
            qq.cacheResult('今天买过68元礼包，只能检测98元礼包了')

            if self:isLackDoubleBuffTime() then
                local goods_98 = gIds[3]
                qq.log('get_goodsId_pay_5', 'goods_98', goods_98)
                qq.cacheResult('5gao 玩家, 检测98元礼包：'..(goods_98 or "空"))

                if goods_98 then
                    if not self:isSkippedNTime(goods_98, 3, true) and not self:isBoughtToday(goods_98) then
                        qq.cacheResult('可以弹出98元礼包：'..goods_98)

                        return goods_98
                    end
                end
                return
            end
            qq.cacheResult('不可以弹出98元礼包')
        else
            preconditionOK = self:isPassLevelNTimes(3)
        end
    end
    if not preconditionOK then
        qq.cacheResult('30元礼包前置条件不满足')
        return
    end

    local goods_30 = gIds[1]
    if goods_30 then
        qq.log('get_goodsId_pay_3', 'goods_30', goods_30)
        qq.cacheResult('5gao 玩家, 检测30元礼包：'..goods_30)

        if not self:isSkippedNTime(goods_30, 3, true) and not self:isBoughtToday(goods_30) then
            qq.cacheResult('可以弹出30元礼包：'..goods_30)
            return goods_30
        end
        qq.cacheResult('不可以弹出30元礼包:'..goods_30)
    end
end

--6gao付费玩家
function ProcessGiftMgr:get_goodsId_pay_6()
    local gIds = self:getGoodsIdsByTag(6)
    qq.log('get_goodsId_pay_6', tts(gIds))

    --=============goods_30==============
    local goods_98 = gIds[2]
    if not goods_98 then return end
    qq.log('get_goodsId_pay_6', 'goods_98', goods_98)
    qq.cacheResult('6gao 玩家, 检测98元礼包：'..goods_98)

    --今日是否已经弹过
    --是否连续5次弹出但未购买
    if not self:isPoppedToday(goods_98) and
            not self:isSkippedNTime(goods_98, 5, true)  and
            not self:isBoughtToday(goods_98)
    then
        qq.cacheResult('可以弹出98元礼包:'..goods_98)
        return goods_98
    end
    qq.cacheResult('不可以弹出98元礼包:'..goods_98..',开始检测其他礼包')

    --=============goods_30, goods_98==============
    local preconditionOK
    if self:isSkippedNTime(goods_98, 5) then
        preconditionOK = self:isPassLevelNTimes(3)
    else
        if self:isBoughtToday(goods_98) then
            qq.cacheResult('今天买过98元礼包，只能检测128元礼包了')
            if self:isLackDoubleBuffTime() then
                local goods_128 = gIds[3]
                qq.log('get_goodsId_pay_6', 'goods_128', goods_128)
                qq.cacheResult('6gao 玩家, 检测128元礼包：'..(goods_128 or "空"))

                if goods_128 then
                    if not self:isSkippedNTime(goods_128, 3, true) and not self:isBoughtToday(goods_128) then
                        qq.cacheResult('可以弹出128元礼包:'..goods_128)
                        return goods_128
                    end
                end
                return
            end
            qq.cacheResult('不可以弹出128元礼包')
        else
            preconditionOK = self:isPassLevelNTimes(3)
        end
    end
    if not preconditionOK then
        qq.cacheResult('68元礼包前置条件不满足')
        return
    end

    local goods_68 = gIds[1]
    if goods_68 then
        qq.log('get_goodsId_pay_6', 'goods_68', goods_68)
        qq.cacheResult('6gao 玩家, 检测68元礼包：'..goods_68)
        if not self:isSkippedNTime(goods_68, 3, true) and not self:isBoughtToday(goods_68) then
            qq.cacheResult('可以弹出68元礼包:'..goods_68)
            return goods_68
        end
        qq.cacheResult('不可以弹出68元礼包:'..goods_68)
    end
end

function ProcessGiftMgr:buyGoods(goodsId, afterSuccess, failCall, cancelCall)
    local function onSuccess( evt )
        qq.log('buyGoods', goodsId)

        self:afterBuyGoods(goodsId)
        self:addRewardsWhenBought(goodsId)
        if afterSuccess then afterSuccess() end
    end

    local function onFail(evt )
        if failCall then failCall() end
    end

    local function onCancel( evt )
        if cancelCall then cancelCall() end
    end

    self:rmbBuy(goodsId, onSuccess, onFail, onCancel)
end

function ProcessGiftMgr:rmbBuy(goodsId, onSuccess, onFail, onCancel)
     local buyContext = BuyContext.new(goodsId, MoneyType.kRmb)
            :setFeatureAndSource(self.dcFeature, self.dcSource)
            :setCallback(onSuccess, onFail, onCancel)
            if self.useNewPackages then
                local stageType = GiftPackageConst.StageType.ACTIVITY
                buyContext:setUnifiedBuy(true,self.useNewPackages.stageType,self.useNewPackages.moduleName)
            end
        _G.amfTransaction(TransactionEvent.PAY, buyContext)
end

-- 购买专用addRewards
-- 如果没goodsId，别用这个函数
-- 有rewardItems就按rewardItems走，没有就直接取goodsId的items
-- 注意，只有没配items才用rewardItems，否则会有问题
function ProcessGiftMgr:addRewardsWhenBought(goodsId, rewardItems, params)
    if not goodsId then
        if EnvUtil:isDevelopMode() then
            CommonTip:showTip("没传goodsId")
        end
        return
    end

    params = params or {}
    params.fromBought = true

    -- 按约定俗成新规走了，如果配了rmb就是rmb购买，没配就不是
    local goodsObj = GoodsManager:getGoods(goodsId)
    local isRmb = goodsObj:getMoneyType() == MoneyType.kRmb
    local items = goodsObj:getItems()

    --
--
--
--
--


    -- 有 rewardItems，截断
    if rewardItems then
        items = rewardItems
        self:_addRewards(items, isRmb and DcPayType.kRmb or DcPayType.kGold , params)
        return
    end

    local useRewards = {}
    local addRewards = {}
    for _,v in ipairs(items) do
        if self:_checkIsSpecialItem(v) then
            table.insert(addRewards,v)
        else
            table.insert(useRewards,v)
        end
    end
    self:_addRewards(addRewards, isRmb and DcPayType.kRmb or DcPayType.kGold , params)
    self:_useRewards(useRewards, params)
end

-- 普通的addRewards,开宝箱之类的
function ProcessGiftMgr:addRewardsNormal(rewardItems, params)
    self:_addRewards(rewardItems, nil, params)
end

-- 检测是普通的还是特殊的
function ProcessGiftMgr:_checkIsSpecialItem(rewardItem)
    local itemId = rewardItem.itemId
    -- 购买的话，会自动帮你加items里配的普通道具，特殊道具需要自己加（除了10001~19999，2，14都是特殊道具）
    if _G.amfBean("PropManager"):isPropNeedToBeAdd(itemId) then return false end
    if itemId == UPropId.GOLD or itemId == UPropId.COIN then return false end

    return true
end

-- 不要调用，(直接使用道具，不用加)
function ProcessGiftMgr:_useRewards(rewardItems, params)
    -- RewardUtil:afterAddReward(rewardItems, self.dcFeature, self.dcSource)
end

-- 不要调用，但需要修改业务逻辑相关添加
function ProcessGiftMgr:_addRewards(rewardItems, payType, params)
    local fromBought = params and params.fromBought or nil

    for _,v in ipairs(rewardItems) do
        if self:_checkIsSpecialItem(v) then
            self:addActItem(v)
        else
            if EnvUtil:isDevelopMode() then
                if fromBought then
                    CommonTip:showTip("不该进来这，赶快查")
                    printx(22,table.tostring(v))
                end
            end
        end
        -- RewardUtil:addRewardDataWithDC(v, true, self.dcFeature, self.dcSource, nil, nil, payType)
        --特殊道具 打点自己处理，默认buy协议会打
    end
end


function ProcessGiftMgr:isActItem(itemId)
    if self.hostMgr then
        return self.hostMgr.isActItem and self.hostMgr:isActItem(itemId)
    end
end

--增加buff
function ProcessGiftMgr:addActItem(reward)
    if self:isActItem(reward.itemId) then
        if self.hostMgr and self.hostMgr.addActItems then
            self.hostMgr:addActItems(reward)
        end
    end
end

--奖励飞行动画
function ProcessGiftMgr:playRewardAnim(goodsId, startPos)
    qq.log('playRewardAnim', goodsId)
    if not goodsId then return end
    local rewardItems = GoodsManager:getGoods(goodsId):getItems()
    local normalItems = {}
    for _, v in ipairs(rewardItems) do
        if self:isActItem(v.itemId) then
            self:flyItemToActIcon(v, startPos)
        else
            table.insert(normalItems, v)
        end
    end
    if #normalItems>0 then
        local itemResPosInWorld = startPos or ccp(360,640)

        local flyRewards = table.clone(normalItems)
        for i,v in ipairs(flyRewards) do
            v.scale = 1 
        end

        local flyContext = FlyItemContext.new(flyRewards, itemResPosInWorld)
        :setFinishCallback(function( ... ) end)
        _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)
    end
end

--buff 飞活动icon
function ProcessGiftMgr:flyItemToActIcon(reward, wp, callback)
    local actIcon
    if self.hostMgr and self.hostMgr.getActivityIcon then
        actIcon = self.hostMgr:getActivityIcon()
    end
    if not actIcon then return end
    local scene = Director:sharedDirector():getRunningSceneLua()
    if not scene or not scene:isScene("MainScene") then return end
    local endWorldPos = actIcon:getPositionInWorldSpace()
    endWorldPos = ccp(endWorldPos.x, endWorldPos.y)
    local startWorldPos = wp or ccp(360, 640)

    local spriteCreator = function()
        if self.hostMgr and self.hostMgr.createActItemIcon then
            return self.hostMgr:createActItemIcon(reward)
        end
        return Sprite:createEmpty()
    end

    local RewardFlyHelper = require 'amf.feature.localactivity.processgiftautopopup.RewardFlyHelper.lua'
    RewardFlyHelper:rewardFlyFunc(true,nil,startWorldPos,endWorldPos,spriteCreator,callback,nil,nil,1)
end

--刷新购买按钮
function ProcessGiftMgr:updateBuyBtn(buyBtn, goodsId, clickCall)
    local iapConfig = self.iapConfig or  _G.amfBean("StoreManager"):getIosProductInfoByGoodsId(goodsId)
    local goodsObj = GoodsManager:getGoods(goodsId)

    local discount = goodsObj:getDiscount()
    local payPrice = goodsObj:getPrice()
    local originPrice = goodsObj:getOriginPrice()

    if (EnvUtil:isIOS() or EnvUtil:isWindows()) and iapConfig and iapConfig.iapPrice then
        payPrice = iapConfig.iapPrice
        originPrice = payPrice - 0.1 --苹果商店不显示原价
    end

    if discount < 10 then
        self:showDiscount(buyBtn, discount)
        -- if originPrice > payPrice then
        --     buyBtn:setOriginPrice(createDisplayPrice(originPrice))
        -- else
        --     buyBtn:hideOriginPrice()
        -- end
        buyBtn:hideOriginPrice() -- 新规范不显示原价

    else
        buyBtn:hideDiscount()
        buyBtn:hideOriginPrice()
    end

    buyBtn:setRmbPrice(payPrice, iapConfig and iapConfig.priceLocale)
    buyBtn:setCallBack(function()
        if clickCall then
            clickCall()
        end
    end)
end

--限时折扣按钮
function ProcessGiftMgr:showDiscount(btn, discount)
    btn:setDiscount(discount)
    local DiscountPlug = require_debug "amf.middleware.ui.kit.component.button.component.DiscountPlug"
    local discountNode = btn:getComponent(DiscountPlug)
    ActionUtil:getDiscountTagShake(discountNode)
end

function ProcessGiftMgr:setGiftPanelLuaPath(luaPath)
    self.giftPanelLua = luaPath
end

function ProcessGiftMgr:onTestPanelOpen(data)
    if self.giftPanelLua  and self.hostMgr then 
        table.insert(data,{
            name = self.hostMgr.ACT_CH_NAME or self.hostMgr.ACT_ID,
            qaTools = self:QATools(),
        })
    end 
end

function ProcessGiftMgr:QATools()
    return {
        popAllPackages = function(PopupGiftPanelVM)
            if not PopupGiftPanelVM then
                PopupGiftPanelVM = require(self.giftPanelLua)
            end 
            if EnvUtil:isWindows() and not self.disMock then
                self.payTag = 6
            end
            local gIds = self:getGoodsIdsByTag(self.payTag)
            for _, v in reverse_ipair(gIds) do
                local multipleGift = self:getGoodsNumByPayTag(self.payTag)>1
                local panelVM = PopupGiftPanelVM:create(v, multipleGift, self)
                panelVM:setBuyHandler(function(goodsId, afterSuccess, failCall, cancelCall)
                    self:buyGoods(goodsId, afterSuccess, failCall, cancelCall)
                end)
                panelVM:popout()
            end

            CommonTip:showTip('当前付费标签为：'..self.payTag,nil, nil, 3)
        end,
        showCheckResult = function()
            local showStr = table.join(checkDebugMsg, '\n')
            CommonTip:showTip(showStr or 'empty msg', nil, nil, 1000)
        end
    }
end


return ProcessGiftMgr