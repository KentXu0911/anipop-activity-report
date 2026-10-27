--- 新版礼包系统增加 2025年12月16日 星期二
local deferred = require "amf.script.sugar.deferred"
local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"

---只针对新三选一礼包
---@class NewbieGiftNewGiftpackage
local NewbieGiftNewGiftpackage = class("NewbieGiftNewGiftpackage")

--3076新活动id，4056老活动 2025年12月15日 星期一
NewbieGiftNewGiftpackage.ACT_ID_NEW = 3076
NewbieGiftNewGiftpackage.ACT_DC_ID_NEW = "22006"
NewbieGiftNewGiftpackage.ACT_ID_OLD = 4056
NewbieGiftNewGiftpackage.ACT_DC_ID_OLD = "4056"

function NewbieGiftNewGiftpackage:ctor()
    self.curActId = nil
end

function NewbieGiftNewGiftpackage:isOpen()
    -- do return false end
    local now = TimeKit:timeInSec()
    -- 新礼包上线到第一期开放前（2026.2.2）中间还有几期旧礼包
    if now < 1769961600 then
        return false
    end

    return true
end


function NewbieGiftNewGiftpackage:isOpenAndSetActId(mgr)

    local dcActId = ""
    if self:isOpen() then
        self.curActId = NewbieGiftNewGiftpackage.ACT_ID_NEW
        dcActId = NewbieGiftNewGiftpackage.ACT_DC_ID_NEW
    else
        self.curActId = NewbieGiftNewGiftpackage.ACT_ID_OLD
        dcActId = NewbieGiftNewGiftpackage.ACT_DC_ID_OLD
    end

    local NewbieGiftOptimizeMgr = require "amf.feature.localactivity.newbiegiftoptimize.NewbieGiftOptimizeMgr"
    if NewbieGiftOptimizeMgr then 
        NewbieGiftOptimizeMgr.ACT_ID = self.curActId 
        NewbieGiftOptimizeMgr.DC_ACT_ID = dcActId
    end

    if EnvUtil:isDevelopMode() then
        printx(48, "[gk] NewbieGiftNewGiftpackage chooseOne actId=", self.curActId)
    end
end



function NewbieGiftNewGiftpackage:_requestNewGiftData(actId, clientMd5, clientUserDataMd5, callback)

    local callbackPromise = deferred.new()
    callbackPromise:next(function (packages)
        local newData = {}
        if packages then
            -- 3选一 todo:根据moudlename 判断
            local giftType = 3
            local  _newbieGiftOptimizeMgr = _G.amfBean("NewbieGiftOptimizeMgr")
            local actInfo = _newbieGiftOptimizeMgr:getActInfo()
            local actInfoExtra = table.deserialize(actInfo.extra or {})
            if actInfoExtra.subInfos and #actInfoExtra.subInfos > 0 then
                actInfoExtra = actInfoExtra.subInfos[1]
            end

            local moduleExtraMap = packages and #packages > 0 and packages[1]:getExtraValue("moduleExtra") or nil
            local extraConfig = (moduleExtraMap) and table.deserialize(moduleExtraMap) or {}

            local gotGiftPackTimesMap = {}
            local giftPackMetaBeanList = (((extraConfig or {}).serverVersionedConfig or {}).config or {}).packageArr or {}
            if giftPackMetaBeanList and #giftPackMetaBeanList > 0 then
                for key, value in pairs(packages) do
                    local obj = table.find(giftPackMetaBeanList,function ( t )
                        return t.packageId == value:getGoodsId()
                    end)
                    if obj then
                        local packageId = value:getGoodsId()
                        obj.goodsId = packageId
                        obj.limitBuyTimes = value.totalCanBuyTimes
                        obj.permanentLimitBuyTimes = value.alreadyBuyTimes

                        gotGiftPackTimesMap[tostring(packageId)] = value.totalCanBuyTimes
                    end
                end
            end
            if table.isEmpty(giftPackMetaBeanList) then
                giftPackMetaBeanList =  _newbieGiftOptimizeMgr:getLocalDataServer():getDataByKey(giftType, "giftPackMetaBeanList")
                --clear serverUserDataMd5
                if table.isEmpty(giftPackMetaBeanList) then
                    LocalDB:setString("NewbieGiftNew_serverUserDataMd5", "")
                end
            end
            local strongPushConditionList = (((extraConfig or {}).serverVersionedConfig or {}).config or {}).strongPushConditionIds or {}
            if table.isEmpty(strongPushConditionList) then
                strongPushConditionList = _newbieGiftOptimizeMgr:getLocalDataServer():getDataByKey(giftType, "strongPushConditionList", {})
            end

            local giftInfo = {}
            giftInfo.beginTime = actInfoExtra.roundBeginTime
            giftInfo.buyEndTime = actInfoExtra.buyEndTime
            giftInfo.canBuyRookieGoods = false
            giftInfo.cdEndTime = actInfoExtra.cdEndTime
            --check
            giftInfo.clientControlVersion = 4
            giftInfo.endTime = actInfoExtra.roundEndTime
            giftInfo.giftPackMetaBeanList = giftPackMetaBeanList
            giftInfo.gotGiftPackTimesMap = gotGiftPackTimesMap
            giftInfo.gotRewardNodeIndex = 0
            giftInfo.id = giftType
            giftInfo.periodBeginTime = actInfoExtra.periodBeginTime
            giftInfo.periodEndTime = actInfoExtra.periodEndTime
            giftInfo.periodId = actInfoExtra.periodId
            giftInfo.showRookieGoods = false
            giftInfo.strongPushCdH = (((extraConfig or {}).serverVersionedConfig or {}).config or {}).strongPushCdH or 0
            if giftInfo.strongPushCdH <= 0 then
                giftInfo.strongPushCdH = _newbieGiftOptimizeMgr:getLocalDataServer():getDataByKey(giftType, "strongPushCdH", 999)
            end
            giftInfo.strongPushConditionList = strongPushConditionList
            giftInfo.reward = actInfoExtra.reward

            local giftInfoList = {giftInfo}
            newData["giftPackActivityInfoList"] = giftInfoList

            if moduleExtraMap then
                newData["guideSet"] = (((extraConfig or {}).serverUserData or {}).userData or {}).finishedGuideIds or {}
                if table.isEmpty(newData["guideSet"]) then
                    newData["guideSet"] = _newbieGiftOptimizeMgr:getLocalDataServer():getDataByKey(giftType, "guideSet", {})
                end
                --获取礼包购买次数
                newData["permanentGotGiftPackTimesMap"] = {}

                --检查具体字段
                local serverVersionedConfig = nil
                local serverMd5 = ((extraConfig or {}).serverVersionedConfig or {}).serverMd5 or nil
                if serverMd5 then
                    serverVersionedConfig = { serverMd5 = serverMd5 }
                    --json
                    serverVersionedConfig.config = table.decodeToJson( ((extraConfig or {}).serverVersionedConfig or {}).config or {} )
                end
                --todo:多个礼包config合并数据
                newData["serverVersionedConfig"] = serverVersionedConfig or {}

                local serverUserDataMd5  = ((extraConfig or {}).serverUserData or {}).serverUserDataMd5 or ""
                LocalDB:setString("NewbieGiftNew_serverUserDataMd5", serverUserDataMd5)
            end
            newData["errorCode"] = 0
            newData["retCode"] = 200
        end

        safeRunCall(callback, newData)
    end, function ()
        CommonTip:showTip("网络异常，请稍后重试~")
        safeRunCall(callback, false)
    end)

    if (clientMd5 and clientMd5 ~= "") and (not clientUserDataMd5 or clientUserDataMd5 == "") then
        clientUserDataMd5 = LocalDB:getString("NewbieGiftNew_serverUserDataMd5", "")
    end

    -- clientMd5 = ""
    -- clientUserDataMd5 = ""
    GiftEventCenter:dispatch(GiftEvent.PULL_ACTIVITY_PACKAGE, {
        actId = actId,
        moduleName = "chooseOneFromThree2025",
        callbackPromise = callbackPromise,
        params = {
            clientMd5 = clientMd5,
            clientUserDataMd5 = clientUserDataMd5,
        },
    })
end



function NewbieGiftNewGiftpackage:requestMainInfo(giftType, onSuccessCallback, onFailCallback, onCancelCallback, bFromLightStart, userClick)
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        CommonTip:showTip("网络异常，请检查网络~")
        return
    end


    local function onSuccess(evt)
        local data = evt.data or {}
        _G.amfBean("NewbieGiftOptimizeMgr"):updateData(data)
        -- _G.amfBean("NewbieGiftOptimizeMgr"):updateTipView()
        -- printx(48, "[gk] request 3or1 onSuccess=", tts(data))
        safeRunCall(onSuccessCallback)
    end
    local function onFail(evt)
        if (not bFromLightStart) and userClick then
            self:showErrorTip(evt)
        end
        local errCode = evt and evt.data or nil
        if errCode and tonumber(errCode) == 733220 then
            _G.amfBean("NewbieGiftOptimizeMgr"):clearActInfoAndUpdateIcon(giftType)
        end
        safeRunCall(onFailCallback)
    end
    local function onCancel()
        safeRunCall(onCancelCallback)
    end
    local noLoading = bFromLightStart or (not userClick)

    local needActivityInfoIdList = {}
    if bFromLightStart then
        for i, type in pairs(_G.amfBean("NewbieGiftOptimizeMgr").GIFT_TYPE) do
            if _G.amfBean("NewbieGiftOptimizeMgr"):getLocalDataServer():checkTypeDataEnabled(type) then
                table.insert(needActivityInfoIdList, type)
            end
        end
    else
        table.insert(needActivityInfoIdList, giftType)
    end
    if table.isEmpty(needActivityInfoIdList) then
        safeRunCall(onFail)
        return
    end
    local serverMd5 = giftType and _G.amfBean("NewbieGiftOptimizeMgr"):getLocalDataServer():getDataByKey(nil, "serverMd5", "") or ""

    -- local clientVersionedConfig = {
    --     clientMd5 = serverMd5
    -- }
    -- self:requestServerData("giftPackSystemInfo", {needActivityInfoIdList = needActivityInfoIdList, light = bFromLightStart, ios = EnvUtil:isIOS(), clientVersionedConfig = clientVersionedConfig}, onSuccess, onFail, onCancel, noLoading)

    self:_requestNewGiftData(self.curActId, serverMd5, "", function (serverData)
        if serverData then
            local evt = {data=serverData}
            onSuccess(evt)
        else
            safeRunCall(onFail)
        end

    end)

    -- printx(48, "[gk] 新三选一 礼包请求", ";bFromLightStart=",bFromLightStart, ";userClick=",userClick)

end


function NewbieGiftNewGiftpackage:showErrorTip(evt)
    local errCode = evt and evt.data or nil
    if not errCode then errCode = -4 end
    if errCode then
        CommonTip:showTip(localize("error.tip."..tostring(errCode)))
    end
end

return NewbieGiftNewGiftpackage