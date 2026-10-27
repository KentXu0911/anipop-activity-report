require "amf.feature.localactivity.dailygift.config.DailyGiftShareConst"
local Manager = class("DailyGiftShareManager")

function Manager:ctor()
    self._activityMgr = nil
    self._propManager = nil
end

function Manager:setPropManager(propManager)
    self._propManager = propManager
end

function Manager:setActivityMgr(activityMgr)
    self._activityMgr = activityMgr
end

function Manager:initialize()
    self:registerEvent()
    self.dataModel = require("amf.feature.localactivity.dailygift.model.Model"):create()

    -- 分享
    require ("amf.feature.localactivity.dailygift.share.ResponseDailyShareHandler"):create()
end

function Manager:registerEvent()
    local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
    _G.amfEC:registerFeature(self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
end

function Manager:getDataModel()
    return self.dataModel
end

function Manager:setActEnabled()
    printx(33, "DailyGiftShare:setActEnabled")
    self._actEnabled = true
    if not self.isInited then
        self.isInited = true
    end
end

function Manager:getActInfo()
    return self._activityMgr:getActInfo(DailyGiftShareConst.ACT_ID)
end

function Manager:onActActInfoUpdate()
    local actInfo = self:getActInfo()
    if actInfo then
        self:setActEnabled()
    end
end

function Manager:onActPassDay()
    self:getDataModel():setDataByKey("lucky", {}, true)
end


function Manager:isEnabled()
    local actInfo = self:getActInfo()
    return actInfo and not table.isEmpty(actInfo)
end

-- 打点
function Manager:dc(category, subCategory, extraData)
    local params = {
        game_type = "stage",
        game_name = "2025_festival_redpacket",
        category = category,
        sub_category = subCategory,
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end
    DcUtil:activity(params)
end

function Manager:hasReward()
    if not self:isEnabled() then return false end
    local lucky = self:getDataModel():getDataByKey("lucky", {})
    if not lucky or table.isEmpty(lucky) then return false end
    local myGotIdx = self:getDataModel():getMyGotIndex()
    local hasMyReward = myGotIdx == 0

    local hasProgressReward
    local progressCurNum = self:getDataModel():getProgressCurNum()
    local progressConfig = self:getDataModel():getProgressConfig()
    for i, v in ipairs(progressConfig) do
        if progressCurNum >= v.needNum then
            if not self:getDataModel():getProgressRewardHasGot(i) then
                hasProgressReward = true
                break
            end
        end
    end

    return hasMyReward or hasProgressReward
end

function Manager:createIcon(reward)
    local icon
    if reward.itemId == 54319 then
        icon = Layer:create()
        icon:setContentSize(CCSizeMake(126, 126))
        icon:setAnchorPoint(ccp(0.5, 0.5))
        icon:ignoreAnchorPointForPosition(false)
        local redpakcet = UICreateUtil:createSpriteFile("amf/activity/dailygift/materials/redpacketIcon.png")
        redpakcet:setScale(1.25)
        icon:addChild(redpakcet)
        redpakcet:setPositionXY(63, 63)
        
        local label = TTFLabel:createAnimalYH("次数+1", 26)
        if reward.canGot then
            label:setTextColor(hex2ccc4("DD6A1DFF"))
            label:enableOutline(hex2ccc4("FFFF96FF"), 3)
        else
            label:setTextColor(hex2ccc4("AB6A44FF"))
            label:enableOutline(hex2ccc4("FFF9E6FF"), 3)
        end
        label:setAnchorPoint(ccp(0.5, 0.5))
        label:setPositionXY(63, 20)
        icon:addChild(label)
    else
        icon = GameItemCreator:getPropIcon(reward)
    end
    
    return icon
end

-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    self:_addRewards(rewardItems, nil, params)
end

-- 检测是普通的还是特殊的
function Manager:_checkIsSpecialItem(rewardItem)
    local itemId = rewardItem.itemId
    local propMgr = self._propManager
    -- 购买的话，会自动帮你加items里配的普通道具，特殊道具需要自己加（除了10001~19999，2，14都是特殊道具）
    if propMgr:isPropNeedToBeAdd(itemId) then return false end
    if itemId == UPropId.GOLD or itemId == UPropId.COIN then return false end

    return true
end

function Manager:getDcFeatureAndSource(suffix)
    suffix = suffix or 0
    return "activity", "act_" .. DailyGiftShareConst.ACT_ID .. tostring(suffix)
end

-- 不要调用，但需要修改业务逻辑相关添加
function Manager:_addRewards(rewardItems, payType, params)
    local dcFeature, dcSource
    if params and params.dcFeature and params.dcSource then
        dcFeature, dcSource = params.dcFeature, params.dcSource
    else
        dcFeature, dcSource = self:getDcFeatureAndSource(params and params.DCSourceExt or nil)
    end
    local normalRewards = {}
    for _,v in ipairs(rewardItems) do
        table.insert(normalRewards, v)
    end
    _G.GainPropData:create()
        :setFeature(dcFeature)
        :setSource(dcSource)
        :setProps(normalRewards)
        :execute()
end

function Manager:getTodayRewardConfig()
    local lucky = self:getDataModel():getDataByKey("lucky",{})
    local rewardSlotList = lucky.rewardSlotList or {}
    local ret = {}
    for i, v in ipairs(rewardSlotList) do
        local rewards = v.rewards or {}
        table.insert(ret, rewards[1])
    end
    return ret
end

function Manager:getWXAppShareImg(callback)
    -- TODO 
    local share = SharePicture.new()
    local bg = UIHelper:createSpriteFile("tempFunctionRes/actshare/sharefeed/gift_card.jpg")

    bg:setAnchorPoint(ccp(0, 0))
    local rewardList = Manager:getInstance():getTodayRewardConfig()
    local rewardNode = Layer:create()
    for i, v in ipairs(rewardList) do
        local icon = Manager:createIcon(v)
        local col, row
        if i <= 3 then
            col = i
            row = 1
        else
            col = i - 3
            row = 2
        end
        icon:setPositionXY((col-1)*142, -(row-1)*140)
        rewardNode:addChild(icon)
    end
    bg:addChild(rewardNode)
    rewardNode:setPositionXY(108, 323)

    share:setBackground(bg)
    local path, thumb = share:capture()
    printx(33, "getWXAppShareImg", path, thumb)
    safeRunCall(callback, path, thumb)
end

function Manager:getWXMiniShareImg(callback)
    local bg = UICreateUtil:createSpriteFile("amf/activity/dailygift/sharefeed/gift_card.jpg")
    bg:setAnchorPoint(ccp(0, 1))
    local rewardNode = Layer:create()
    local rewardList = Manager:getInstance():getTodayRewardConfig()
    for i, v in ipairs(rewardList) do
        local icon = Manager:createIcon(v)
        local col, row
        if i <= 3 then
            col = i
            row = 1
        else
            col = i - 3
            row = 2
        end
        icon:setPositionXY((col-1)*142, -(row-1)*140)
        rewardNode:addChild(icon)
    end
    bg:addChild(rewardNode)
    rewardNode:setPositionXY(108, 323)

    local size = bg:getContentSize()
    UICreateUtil:runShareAnim(bg, size, function(imgPath)
        safeRunCall(callback, imgPath, true)
    end)
end

function Manager:getWXMomentShareImg()

end

function Manager:getWBShareImg( callback)
    local share = SharePicture.new()
    local bg = UIHelper:createSpriteFile("tempFunctionRes/actshare/sharefeed/gift.jpg")
    share:setBackground(bg)

    local profileManager = _G.amfBean("ProfileManager")
    local head = HeadImageLoader:createWithFrame(profileManager:getXxlId(), profileManager:getHeadUrl())
    head:setScale(0.5)
    head:setPositionXY(55, 670)
    bg:addChild(head)

    local NameLabel = require "amf.middleware.ui.kit.component.namelabel.NameLabel"
	local name = cutNameByteSensitive(profileManager:getName(), 12, nil, true)
    local nameLabel = NameLabel:create(name, 26, nil, kCCTextAlignmentLeft, kCCVerticalTextAlignmentTop)
    bg:addChild(nameLabel)
    nameLabel:setAnchorPoint(ccp(0, 0.5))
    nameLabel:setPositionXY(95, 666)
    nameLabel:setColor(hex2ccc4("fff54dff"))

    local descLabel
    descLabel = TTFLabel:createAnimalYH("快来点击链接领取我的礼物吧！", 35)
    descLabel:setGradientColors(hex2ccc4("fffca1ff"), hex2ccc4("ffe963ff"))
    descLabel:enableOutline(hex2ccc4("873a2eff"), 3)
    bg:addChild(descLabel)
    descLabel:setAnchorPoint(ccp(0, 0.5))
    descLabel:setPositionXY(25, 590)


    local path, thumb = share:capture()
    printx(33, "getWBShareImg", path, thumb)
    safeRunCall(callback, path, thumb)
end



---------------------- 点回求助 --------------------------



function Manager:commonShowRewards(rewards, callback)
    local ShowRewardsPanelVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelVM"
    local vm = ShowRewardsPanelVM.Builder.new()
    :setRewards(rewards, function(reward)
        return self:createIcon(reward)
    end)
    :setCloseCallback(callback)
    :build()
    vm:popout()
end

function Manager:requestServerData(protocolName, reqParams, onSuccess, onFail, onCancel, noLoading)
    if noLoading == nil then
        noLoading = true
    end
    local AMFRequest = require "amf.middleware.interconnection.remote.core.AMFRequest"
    local Request = class(protocolName, AMFRequest)
    local params = {
        protocol = protocolName,
        loading = not noLoading,
        useMockData = false
    }
    Request:run(params, reqParams):next(onSuccess, function(response)
        if response:isCancel() then
            onCancel(response)
        else
            onFail(response)
        end
    end)
end

function Manager:requestGetProgressReward(index, callback)
    local function onRequestSuccess(response)
        local data = response:getData()

        local code = data.code
        if code > 0 then
            local errStr
            if tonumber(code) == 1 then
                errStr = "活动已结束～"
            elseif tonumber(code) == 2 then
                errStr = "数据错误，请退出活动重试～"
            elseif tonumber(code) == 3 then
                errStr = "数据错误，请退出活动重试～"
            else
                errStr = "数据错误，请退出活动重试～"
            end
            CommonTip:showTip(errStr)
            safeRunCall(callback, code)
            return
        end

        local rewards = data.rewards
        self:addRewardsNormal(rewards, {dcFeature="activity", dcSource="act_5319_node"})--todo
        self:getDataModel():setProgressRewardHasGot(index, true)
        self:commonShowRewards(rewards, callback)
    end
    local function onRequestFail(response)
        CommonTip:showErrorTip(response)
        safeRunCall(callback)
    end
    local function onRequestCancel()
        safeRunCall(callback)
    end
    local shareKey = self:getDataModel():getShareKey()
    local time = self:getDataModel():getProgressTimeByIdx(index)
    self:requestServerData("shareLuckySelect2025GetTimesReward", {timesList = {time}, shareKey = shareKey}, onRequestSuccess, onRequestFail, onRequestCancel, false)
end

function Manager:requestSelectReward(index, shareKey, isMine, successCallback, failCallback)
    local function onRequestSuccess(response)
        local data = response:getData()

        if isMine then
            local lucky = data.lucky
            local shareRecordList = data.shareRecordList
            self:getDataModel():dataFromInfo({lucky = lucky, shareRecordList = shareRecordList})            
        end

        local code = data.code
        if code > 0 then
            local errStr
            if tonumber(code) == 1 then
                errStr = "活动已结束～"
            elseif tonumber(code) == 2 then
                errStr = "链接失效啦，请好友重新分享吧～"
            elseif tonumber(code) == 3 then
                errStr = "当前礼物被好友领走啦，换个礼物吧～"
            elseif tonumber(code) == 4 then
                if isMine then
                    errStr = "已经领取过礼物啦~"
                else
                    errStr = "已经领取过该好友的礼物啦～"
                end
            elseif tonumber(code) == 5 then
                errStr = "今日礼物领取已达上限，明日再来吧～"
            else
                errStr = "领取失败，请稍后再试～"
            end
            CommonTip:showTip(errStr)
            safeRunCall(failCallback, data)
        else
            local rewards = data.rewards
            self:commonShowRewards(rewards, function()
                safeRunCall(successCallback, data)
            end)
            self:addRewardsNormal(rewards, {dcFeature="activity", dcSource=isMine and "act_5319_gift" or "act_5319_friend"})--todo            
        end

    end
    local function onRequestFail(response)
        CommonTip:showErrorTip(response)
        safeRunCall(failCallback, {code = -1})
    end
    local function onRequestCancel()
        safeRunCall(failCallback, {code = -1})
    end
    shareKey = shareKey or self:getDataModel():getShareKey()
    self:requestServerData("shareLuckySelect2025Select", {index = index, shareKey = shareKey}, onRequestSuccess, onRequestFail, onRequestCancel, false)
end

-- 打开礼物分享面板
function Manager:showRequestSharePanel(shareKey, isMine, closeCallback, userClick)
    if not self:isEnabled() or (isMine and not self:getDataModel():isDataEnabled()) then
        if EnvUtil:isDevelopMode() then
            CommonTip:showTip("data is not enabled")
        end
        safeRunCall(closeCallback)
        return
    end
    if not shareKey then
        if EnvUtil:isDevelopMode() then
            CommonTip:showTip("shareKey is nil")
        end
        safeRunCall(closeCallback)
        return
    end
    local function onRequestSuccess(data)
        local code = data.code
        if tonumber(code) > 0 then
            local errStr
            if tonumber(code) == 1 then
                errStr = "活动已结束～"
            elseif tonumber(code) == 2 then
                errStr = "链接失效啦，请好友重新分享吧～"
            elseif tonumber(code) == 3 then
                errStr = "已经领取过该好友的礼物啦～"
            elseif tonumber(code) == 4 then
                errStr = "礼物已经被其他人领走了~"
            elseif tonumber(code) == 5 then
                errStr = "今日领取次数已达上限"
            else
                errStr = "数据错误，请稍后重试～"
            end
            if not isMine then
                self:showResponseFailPanel(errStr, closeCallback)
            else
                safeRunCall(closeCallback)
            end
            return
        end

        if isMine then
            self:openRequestSharePanel(data, closeCallback, userClick)
        else
            self:openResponseSharePanel(data, closeCallback, userClick)
        end
    end
    local function onRequestFail(errorCode)
        if not isMine and errorCode then
            local errMsg = localize("error.tip." .. tostring(errorCode))
            self:showResponseFailPanel(errMsg, closeCallback)
        else
            safeRunCall(closeCallback)
        end
    end
    local function onRequestCancel()
        safeRunCall(closeCallback)
    end
    self:requestOpenInfo(shareKey, isMine, onRequestSuccess, onRequestFail, onRequestCancel, false)
end

function Manager:getExternShareKey()
    return self:getDataModel():getShareKey()
end

function Manager:requestOpenInfo(shareKey, isMine, onRequestSuccess, onRequestFail, onRequestCancel, noLoading)
    local function onSuccess(response)
        local data = response:getData()

        if isMine then
            self:getDataModel():dataFromInfo(data)
        end
        safeRunCall(onRequestSuccess, data)
    end
    local function onFail(response)
        local data = response:getData()
        if isMine and not noLoading then
            CommonTip:showErrorTip(data)
        end
        safeRunCall(onRequestFail, data)
    end
    local function onCancel()
        safeRunCall(onRequestCancel)
    end
    self:requestServerData("shareLuckySelect2025Open", {shareKey = shareKey}, onSuccess, onFail, onCancel, noLoading)
end

function Manager:openRequestSharePanel(data, closeCallback, userClick)
    local CommonShareActPanelVM = require("amf.feature.localactivity.dailygift.view.vm.CommonShareActPanelVM")
    local vm
    local endTime = getDayStartTimeByTS(TimeKit:timeInSec()) + 86400

    local delegate = {
        userClick = userClick,
        title = "每日礼物",
        subTitle = "选1个奖励领取，剩下的分享给好友",
        todayShareLimitCount = 5,
        endTimeSec = endTime,
        getHelpRecordListFunc = function ()
            return self:getDataModel():getHelpRecordList()
        end,
        progressConfig = self:getDataModel():getProgressConfig(),
        rewardConfig = self:getDataModel():getRewardConfig(),
        createIconFunc = function(reward)
            reward.needNum = true
            return self:createIcon(reward)
        end,
        progressCurNumFunc = function(index)
            return self:getDataModel():getProgressCurNum()
        end,
        progressRewardHasGotFunc = function(index)
            return self:getDataModel():getProgressRewardHasGot(index)
        end,
        getProgressRewardFunc = function(index, node, done)
            self:requestGetProgressReward(index, done)
        end,
        getMyGotIndexFunc = function()
            return self:getDataModel():getMyGotIndex()
        end,
        getRewardFunc = function(index, node, done)
            -- 点自己的礼物 info返回数据存本地
            self:requestSelectReward(index, nil, true, function(data)
                local code = data.code
                safeRunCall(done, code)
            end, function(data)
                local code = data.code
                safeRunCall(done, code)
            end)
        end,
        shareWXFunc = function(index, node, successCallback, failCallback)
            local texts = {
                "sharekey复制w口令进入开心消消乐y，f领取好友送来的奖励c！",
                "sharekey复制w口令进入开心消消乐y，f领取奖励c！"
            }
            local text = texts[math.random(1, #texts)]
            local shareKey = self:getDataModel():getShareKey()
            local context = OpenShareContext.new(OpenShareConst.ShareType.DAILY_GIFT, OpenShareConst.ShareTarget.WXToken)
                :setActId(DailyGiftShareConst.ACT_ID)
                :setTextParams("", text)
                :setAskHelpParams(shareKey, {}, DailyGiftShareConst.SHARE_ID)
                :setShareCallback(successCallback, failCallback)
            _G.amfTransaction(TransactionEvent.SHARE, context)
        end,
        shareWXLinkFunc = function(index, node, successCallback, failCallback)
            local texts =  {
                "您有一份好友送来的新春礼物，请查收",
                "狮来运转迎新年，愿你岁岁都欢颜！点击收下礼物吧",
                "快快点击链接领取我送你的礼物吧！"
            }
            local text = texts[math.random(1, #texts)]
            local shareKey = self:getDataModel():getShareKey()
            local context = OpenShareContext.new(OpenShareConst.ShareType.DAILY_GIFT, OpenShareConst.ShareTarget.MINI)
                :setActId(DailyGiftShareConst.ACT_ID)
                :setTextParams(text)
                :setAskHelpParams(shareKey, {}, DailyGiftShareConst.SHARE_ID)
                :setShareCallback(successCallback, failCallback)
            if EnvUtil:isMiniGame() then
                self:getWXMiniShareImg(function(path)
                    context:setMiniParams({
                        imageUrl = path,
                    })
                end)
            else
                self:getWXAppShareImg(function(path, thumb)
                    context:setMiniParams({
                        imageUrl = path
                    })
                end)
            end
            _G.amfTransaction(TransactionEvent.SHARE, context)
        end,
        shareWBFunc = function (index, node, successCallback, failCallback)
            local texts =  {
                "快来开心消消乐领取我送你的新年礼物吧！",
                "This is bonus time！！！",
                "您有一份开心村寄来的礼物，请查收"
            }
            local text = texts[math.random(1, #texts)]
            local shareKey = self:getDataModel():getShareKey()
            local context = OpenShareContext.new(OpenShareConst.ShareType.DAILY_GIFT, OpenShareConst.ShareTarget.WB)
                :setActId(DailyGiftShareConst.ACT_ID)
                :setTextParams("", text)
                :setAskHelpParams(shareKey, {}, DailyGiftShareConst.SHARE_ID)
                :setWbUrlParam(Meta.WBShareUrl, {})
                :setShareCallback(successCallback, failCallback)
            self:getWBShareImg(function(path, thumb)
                context:setImgParams(thumb, path)
                _G.amfTransaction(TransactionEvent.SHARE, context)
            end)
        end,
        closeCallback = closeCallback,
    }

    vm = CommonShareActPanelVM:create(delegate)
    vm:setLoadResFailCallback(function()
        if EnvUtil:isDevelopMode() then
            CommonTip:showTip("打开失败了~")
        end
        safeRunCall(closeCallback)
    end)
    vm:popout()
end

function Manager:openResponseSharePanel(data, closeCallback, userClick)
    if not data or table.isEmpty(data) then
        safeRunCall(closeCallback)
        return
    end

    local lucky = data.lucky
    -- local shareRecordList = data.shareRecordList
    local masterProfile = lucky.profile
    local masterName = masterProfile.name
    local masterHeadUrl = masterProfile.headUrl
    local shareKey = lucky.shareKey
    local uid = lucky.profile.uid
    local extra = lucky.extra
    extra = table.deserialize(extra or "{}")
    local todayCanGetOtherTimes = extra.todayCanGetOtherTimes or 0
    local CommonReceiveActPanelVM = require("amf.feature.localactivity.dailygift.view.vm.CommonReceiveActPanelVM")
    local vm
    local delegate = {
        userClick = userClick,
        uid = uid,
        title = "收到好友礼物",
        subTitle = "好友送来礼物，快选1个领取吧",
        shareHeadUrl = masterHeadUrl,
        shareNickName = masterName,
        getCurNumFunc = function()
            return todayCanGetOtherTimes
        end,
        getRewardConfigFunc = function()
            local rewardSlotList = lucky.rewardSlotList or {}
            local rewardConfig = {}
            for i, v in ipairs(rewardSlotList) do
                local rewardTs = tonumber(v.rewardTs) or 0
                local headUrl = ""
                if rewardTs > 0 and v.profile then
                    headUrl = v.profile.headUrl
                end
                local rewards = v.rewards or {}
                table.insert(rewardConfig, {
                    headUrl = headUrl,
                    reward = rewards[1],
                })
            end
            return rewardConfig
        end,
        createIconFunc = function(reward)
            reward.needNum = true
            return self:createIcon(reward)
        end,
        getMyGotIndexFunc = function()
            return 0
        end,
        getRewardFunc = function(index, node, done)
            -- 点别人的礼物 info返回数据不存本地，存在local变量
            local function onFinish(newData, code)
                if newData.lucky then
                    lucky = newData.lucky
                end
                if newData.shareRecordList then
                    shareRecordList = newData.shareRecordList
                end

                extra = lucky.extra
                extra = table.deserialize(extra or "{}")
                todayCanGetOtherTimes = extra.todayCanGetOtherTimes or 0                

                local code = newData.code
                safeRunCall(done, code)
            end

            self:requestSelectReward(index, shareKey, false, function(newData)
                onFinish(newData)
            end, function(newData)
                onFinish(newData)
            end)
        end,
        closeCallback = closeCallback,
    }
    vm = CommonReceiveActPanelVM:create(delegate)
    vm:setLoadResFailCallback(function()
        if EnvUtil:isDevelopMode() then
            CommonTip:showTip("打开失败了~")
        end
        safeRunCall(closeCallback)
    end)
    vm:popout()
end

function Manager:showResponseFailPanel(errMsg, closeCallback)
    local FourthPanelAVM = require "amf.middleware.ui.kit.panel.fourth.FourthPanelAVM"
    local vm
    vm = FourthPanelAVM.Builder.new()
    :setText(errMsg)
    :setButtonsConfig({
        {
            str = "知道了",
            widthMode = UIButtonConfig.Widths.kShort,
            colorMode = UIButtonConfig.ColorMode.green,
            touchFunc = function()
                if vm and not vm.isDisposed then
                    vm:close()
                end
            end
        }
    })
    :setCloseCallback(closeCallback)
    :setColorType("springfestivalshare2025")
    :build()
    vm:popout(nil, true, SceneLayerShowKey.TOP_LAYER)
end

return Manager
