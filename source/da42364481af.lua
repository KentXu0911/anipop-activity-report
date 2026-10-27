require "amf.middleware.notification.submsg.config.SubMessageConst"
local deferred = require "amf.script.sugar.deferred"
local SubMsgUIUtil = require "amf.middleware.notification.submsg.util.SubMsgUIUtil"
local ISubMsg = require "amf.middleware.notification.submsg.ISubMsgNode"
local Res = require "amf.middleware.notification.submsg.config.Res"
local Group = require "amf.middleware.notification.submsg.config.Group"
local SubMsgNode = require "amf.middleware.notification.submsg.view.SubMsgNode"
local SubMsgBase = class("SubMsgBase").implement(ISubMsg)

function SubMsgBase:ctor()
    self.model = nil
    self._assetsUtil = nil
    self._iconManager = nil
    self._optionalDataManager = nil
    self._subMsgUtil = nil
    self._levelAreaManager = nil
    self._sdkLoginManager = nil
    self._propManager = nil
    self._heartBeatManager = nil
    self._autoPopupMgr = nil
    self._markManager = nil
    self._promoteDailyMgr = nil
    self._networkStatusManager = nil
    self._nameMedalManager = nil
end

function SubMsgBase:setNameMedalManager(nameMedalMgr)
    self._nameMedalManager = nameMedalMgr
end

function SubMsgBase:setPromoteDailyMgr(promoteDailyMgr)
    self._promoteDailyMgr = promoteDailyMgr
end

function SubMsgBase:setNetworkStatusManager(networkStatusManager)
    self._networkStatusManager = networkStatusManager
end

function SubMsgBase:setMarkManager(markManager)
    self._markManager = markManager
end

function SubMsgBase:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
end

function SubMsgBase:setHeartBeatManager(mgr)
    self._heartBeatManager = mgr
end

function SubMsgBase:setPropManager(propManager)
    self._propManager = propManager
end

function SubMsgBase:setSdkLoginManager(sdkLoginManager)
    self._sdkLoginManager = sdkLoginManager
end

function SubMsgBase:setLevelAreaManager(mgr)
    self._levelAreaManager = mgr
end

function SubMsgBase:setSubMsgUtil(util)
    self._subMsgUtil = util
end

function SubMsgBase:setOptionalDataManager(optionalDataManager)
    self._optionalDataManager = optionalDataManager
end

function SubMsgBase:setIconManager(iconManager)
    self._iconManager = iconManager
end

function SubMsgBase:setAssetsUtil(assetsUtil)
    self._assetsUtil = assetsUtil
end
-- @override
function SubMsgBase:isUIEnabled()
    return self._isResReady
end

function SubMsgBase:isEnabled()
    return self.model and self:isLocalEnabled() and self:getSubValue("isFromServer")
end

function SubMsgBase:isGroupEnabled()
    return not Group:isOff()
end

function SubMsgBase:isLevelEnabled()
    return _G.getTopLevelId() >= SubMessageConst.OPEN_LEVEL
end

-- @override
function SubMsgBase:isLocalEnabled()
    return self:isGroupEnabled() and self:isLevelEnabled()
end

function SubMsgBase:initialize()
    -- 得先注册，不然事件都收不到
    _G.amfEC:registerFeature(self)
    -- 没开就不走逻辑了
    if not self:isLocalEnabled() then
        self._lastIsNotEnabled = true
        return
    end
    self.model = require("amf.middleware.notification.submsg.model.Model"):create()

    self:loadRes()

    -- 如果有本地数据，直接刷一次右下角的显示
    self:doAfterLoadInfo()
    -- 请求一次主info，虽然不影响显示
    self:requestMainInfo():next(function()
        self:doAfterLoadInfo()
    end)
end

function SubMsgBase:requestMainInfo()
    local d = deferred.new()
    self.model:requestMainInfo():next(function()
        -- 将特殊的id添加进已领取列表,前端自己变,后边不改
        local rewardedList = self:getSubValue("rewardedList")
        local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
        for _, v in ipairs(subscribeMetaList) do
            local reward = self:getRewardById(v.id)
            if table.isEmpty(reward) then
                table.insert(rewardedList, v.id)
            end
        end 
        self:setSubValue("rewardedList", rewardedList)
        d:resolve()
    end, function()
        d:reject()
    end)
    return d
end

-- 场景2强弹
function SubMsgBase:handleEnterStage2(evt)
    if EnvUtil:isDYMiniGame() or EnvUtil:isALIPAYMiniGame() then
        return
    end

    if EnvUtil:isHuaweiMiniGame() then
        return
    end

    if EnvUtil:isUnionMiniGame() then
        return
    end

    if EnvUtil:isKuaiShouMiniGame() then
        return
    end
    
    if EnvUtil:isJdMiniGame() then
        return
    end

    if not self:isEnabled() then return end
    -- 如果是从订阅进来的，那么打个进入点
    if self._subMsgUtil:isEnterFromTmpl() then
        self:dc("subscription", "enter_game", {
            t1 = self._subMsgUtil:getEnterKeyFromValue()
        })
    end
    if not self:checkTodayCanCardEnterReward() then
        return
    end
    local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.SUB_MSG)
	end

	local function creator()
		self:showDailyRewardPanel():next(function()
			onHandleOver()
		end)
	end
	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.SUB_MSG, creator)
end

-- 场景4强弹
function SubMsgBase:handleEnterStage4(evt)
    if not self:checkStage4CanPop() then return end
    local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.SUB_MSG_STAGE4)
	end
	local function creator()
		self:showMainPanel({
			closeCallback = onHandleOver,
			t1 = 2
		})
	end
	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.SUB_MSG_STAGE4, creator)
end

-- 过关检查是否要开启
function SubMsgBase:handlePassLevelEnd(evt)
    -- 如果一开始不可用就检查
    if not self._lastIsNotEnabled then return end
    -- 如果本来就可用就不检查了
    local data = evt:getData()
    if not data.isWin then return end
    if self:isLocalEnabled() then
        self._lastIsNotEnabled = false
        -- 重新初始化一次
        self:initialize()
    end
end

-- @override
function SubMsgBase:loadRes(silence)
    local d = deferred.new()
    setTimeOut(function()
        self._isResReady = true
        d:resolve()
    end, 0)
    return d
end

function SubMsgBase:doAfterLoadInfo()
    -- 资源判断
    if not self:isEnabled() then return end
    -- 刷新右下角iconPool
    local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
    self._iconManager:updatePoolByType(IconMeta.PoolType.kRightCorner)
    -- 刷新红点
    self:updateIcon()
    -- 开启心跳
    self._heartBeatManager:addSourceType(HeartBeatConst.SourceType.SUB_MSG)
end

-- @override
function SubMsgBase:isCardEnterGame()
    return false
end

function SubMsgBase:showMainPanel(param)
    param = param or {}
    -- 强弹调用的
    if param.t1 == 2 then
        local stage4PopCount = self:getSubValue("stage4PopCount")
        self:setSubValue("stage4PopCount", stage4PopCount + 1)
        self:setSubValue("stage4LastPopTime", TimeKit:timeInSec())
    end
    local function showMain()
        local SubMsgMainPanelVM = require_debug "amf.middleware.notification.submsg.view.SubMsgMainPanelVM"
        local vm = SubMsgMainPanelVM:create(param)
        vm:setLoadResFailCallback(function()
            safeRunCall(param.closeCallback)
        end)
        vm:popout()
    end
    self:requestMainInfo()
    :next(function()
        showMain()
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
    end)
end

-- 根据模板id获得id
function SubMsgBase:getIdByTmplId(tmplId)
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    for _, v in ipairs(subscribeMetaList) do
        if v.tmplId == tmplId then
            return v.id
        end
    end
    return 0
end

function SubMsgBase:getTmplIdById(id)
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    for _, v in ipairs(subscribeMetaList) do
        if v.id == id then
            return v.tmplId
        end
    end
    return 0
end

function SubMsgBase:getIdBySceneType(sceneType)
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    for _, v in ipairs(subscribeMetaList) do
        if v.sceneTypeEnum == sceneType then
            return v.id
        end
    end
    return 0
end

function SubMsgBase:getSceneTypeById(id)
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    for _, v in ipairs(subscribeMetaList) do
        if v.id == id then
            return v.sceneTypeEnum
        end
    end
    return SubMessageConst.SceneType.ENERGY_RECOVER_FULL
end

function SubMsgBase:getTextByTmplId(tmplId)
    local id = self:getIdByTmplId(tmplId)
    return self:getTextById(id)
end

-- 未领奖但是订阅了text
function SubMsgBase:getNoRewardTextById(id)
    return localize("SubMsg.text.noreward."..id)
end

-- 已经订阅了文案
function SubMsgBase:getRegedTextById(id)
    return localize("SubMsg.text.reged."..id)
end

function SubMsgBase:getTextById(id)
    return localize("SubMsg.permisson.text.on1."..id)
end

function SubMsgBase:getMetaInfoById(id)
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    for _, v in ipairs(subscribeMetaList) do
        if v.id == id then
            return v
        end
    end
    return nil
end

function SubMsgBase:getServerMiniGameState()
    local envVersion = MetaInfo.getEnvVersion and MetaInfo:getEnvVersion() or "develop"
    return SubMessageConst.EnvVersionMap[envVersion]
end

-- 尝试展示权限引导
function SubMsgBase:tryShowPermissionGuide(tmplIds)
    if not self._subMsgUtil:isMainSwitchOn() then
        return
    end
    self._guideTimer = setTimeOut(function()
        self._guideTimer = nil
        local popList = {}
        for i, v in ipairs(tmplIds) do
            -- 都没有选这永久同意/拒绝，才能弹
            if not self._subMsgUtil:isAlwaysAccept(v) and not self._subMsgUtil:isAlwaysReject(v) then
                table.insert(popList, v)
            end
        end
        if table.isEmpty(popList) then
            return
        end
        local PermissionGuidePanelVM = require "amf.middleware.notification.submsg.view.PermissionGuidePanelVM"
        self.permisionVm = PermissionGuidePanelVM:create({
            text = #popList > 1 and "消息提醒" or self:getTextByTmplId(popList[1])
        })
        self.permisionVm:setLoadResFailCallback(function()
            self.permisionVm = nil
        end)
        if self.permisionVm then
            self.permisionVm:popout()
        end
    end)

end

function SubMsgBase:tryClosePermissionGuide()
    if self._guideTimer then
        cancelTimeOut(self._guideTimer)
        self._guideTimer = nil
    end
    if self.permisionVm then
        self.permisionVm:close()
        self.permisionVm = nil
    end
end

-- 注册并且检查领奖
function SubMsgBase:registerSubMsgAndGetRewards(tmpInfoList, param)
    local d = deferred.new()
    local tmplIds = {}
    for _, v in ipairs(tmpInfoList) do
        table.insert(tmplIds, v.tmplId)
    end

    -- unity编辑器不弹， 直接失败
    if EnvUtil:isUnityEditor() then
        return d:reject(SubMessageConst.RegErrCode.PERMISSION)
    end

    self:tryShowPermissionGuide(tmplIds)

    self._subMsgUtil:requestSubMsg(tmplIds):next(function(resTb)
        self:tryClosePermissionGuide()
        local failList = {}
        local succList = {}
        for _, v in ipairs(tmplIds) do
            if resTb[v] == SubMessageConst.TmplState.ACCEPT then
                table.insert(succList, v)
            else
                table.insert(failList, v)
            end
        end

        -- 先检查一次状态,标记之前有没有选过总是保持
        local lastMap = {}
        for _, v in ipairs(failList) do
            lastMap[v] = self._subMsgUtil:isAlwaysReject(v) or self._subMsgUtil:isAlwaysAccept(v)
        end
        -- 请求setting去对比检查
        self._subMsgUtil:autoUpdateSettingInfo():next(function()
            if #succList == 0 then
                local isAlwaysReject = true
                for _, v in ipairs(failList) do
                    if not self._subMsgUtil:isAlwaysReject(v) or not lastMap[v] then
                        isAlwaysReject = false
                        break
                    end
                end
                -- 转换成定义的id
                local idList = {}
                for _, tmplId in ipairs(failList) do
                    table.insert(idList, self:getIdByTmplId(tmplId))
                end
                -- 打点
                self:dc("subscription", "main_panel_refuse", {
                    panel_id = param.panelId,
                    t1 = table.concat(idList, "_")
                })
                -- 全部拒绝了，但是有不是永久拒绝的
                d:reject(isAlwaysReject and SubMessageConst.RegErrCode.PERMISSION or SubMessageConst.RegErrCode.NONE)
            else
                self:doAfterReged(succList, failList, param)
                self:checkGetRewards(d)
            end
        end)
    end, function(errCode)
        self:tryClosePermissionGuide()
        d:reject(errCode)
    end)
    return d
end

function SubMsgBase:doAfterReged(succList, failList, param)
    -- 只要有成功的就刷新一次icon
    self:updateIcon()
    self:tryClosePermissionGuide()

    if self:getSubTempValue("canRecordRegTag") then
        -- 记录有订阅成功的
        self:setSubTempValue("hasRegSuccess", not table.isEmpty(succList))
    end
    -- 订阅完成后通知后端我订阅了
    local notiIdList = {}
    local historyList = self:getSubValue("historyRegList") or {}
    for _, v in ipairs(succList) do
        local id = self:getIdByTmplId(v)
        table.insert(notiIdList, id)
        -- 添加到订阅过列表中
        if not table.exist(historyList, id) then
            table.insert(historyList, id)
            self:setSubValue("historyRegList", historyList)

            -- 增加每日领奖的结束时间, 只有微信会变，但是微信没开，其他都不变
            if self:hasDailyReward() then
                local dailyRewardEndTime = self:getSubValue("dailyRewardEndTime")
                local oneRegAddDay = self:getSubValue("oneRegAddDay")
                if dailyRewardEndTime <= TimeKit:timeInSec() then
                    dailyRewardEndTime = TimeKit:getTodayStart()
                end
                dailyRewardEndTime = dailyRewardEndTime + 24 * 3600 * oneRegAddDay
                self:setSubValue("dailyRewardEndTime", dailyRewardEndTime)
            end
        end

        -- 添加到当前订阅列表中
        local regList = self:getSubValue("regList") or {}
        if not table.exist(regList, id) then
            table.insert(regList, id)
            self:setSubValue("regList", regList)
        end
    end
    -- print("historyList ---", tts(self:getSubValue("historyRegList")))
    -- print("regList ---", tts(self:getSubValue("regList")))
    local tb = {}
    if not table.isEmpty(notiIdList) then
        for _, id in ipairs(notiIdList) do
            local sceneType = self:getSceneTypeById(id)
            if sceneType == SubMessageConst.SceneType.PROMOTEDAILY then
                local medalCfg = self._promoteDailyMgr:getCurMonthNearestKeyMedal()
                local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
                if medalCfg then
                    table.insert(tb, {
                        id = id, 
                        data = table.serialize({
                            holiday = medalCfg.des,   -- 节日
                            reward = self._nameMedalManager:getNameMedalName(medalCfg.medalId), -- 勋章名
                            day = TimeUtil:getDayCountByYMD(medalCfg.year, medalCfg.month, medalCfg.day)
                        })
                    })
                end
            end
        end
        self.model:requestNotifyServer({
            idList = notiIdList,
            miniprogram_state = self:getServerMiniGameState(),
            openId = self._sdkLoginManager:getOpenId(),
            extra = table.serialize(tb)
        })
        -- 打点
        self:dc("subscription", "main_panel_success", {
            panel_id = param.panelId,
            t1 = table.concat(notiIdList, "_")
        })
    end
end

-- 是否有每日奖励 TODO  增加每日领奖的结束时间, 只有微信会变，但是微信没开，其他都不变
function SubMsgBase:hasDailyReward()
    if EnvUtil:isWXMiniGame() then
        return true
    end
    return false
end

-- 检查领奖
function SubMsgBase:checkGetRewards(d)
    -- 领取所有可领取的奖励
    local needRewardList = {}
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    for _, v in ipairs(subscribeMetaList) do
        if self:isRegCanReward(v.id) then
            table.insert(needRewardList, v.id)
        end
    end
    if #needRewardList == 0 then
        d:resolve()
    else
        self:requestGetReward({
            idList = needRewardList
        }):next(function(rewardList)
            d:resolve(rewardList)
        end, function(response)
            d:resolve()
        end)
    end
end

-- 每日奖励领取
function SubMsgBase:requestCardEnterReward(param)
    local d = deferred.new()
    self.model:requestCardEnterReward(param):next(function(response)
        local data = response:getData()
        if not table.isEmpty(data.rewardList) then
            GainPropData:create()
                :setFeature("subscription")
                :setSource("everyday_reward")

                :setProps(data.rewardList)
                :execute()
        end
        d:resolve()
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject(response)
    end)
    return d
end

-- 订阅奖励领取
function SubMsgBase:requestGetReward(param)
    local d = deferred.new()
    self.model:requestGetReward(param):next(function(response)
        local data = response:getData()
        if not table.isEmpty(data.rewardList) then
            -- 领取成功之后也刷新一次icon红点
            self:updateIcon()
            GainPropData:create()
                :setFeature("subscription")
                :setSource("main_panel_success")

                :setProps(data.rewardList)
                :execute()
        end
        d:resolve(data.rewardList)
    end, function(response)
        if not response:isCancel() then
            self:setSubTempValue("isHttpError", true)
            CommonTip:showErrorTip(response)
        end
        d:reject(response)
    end)
    return d
end

-- 获得订阅进入游戏可以领哪个奖励
function SubMsgBase:getDailyRewardPool()
    local loginRewardPoolMetaList = self:getSubValue("loginRewardPoolMetaList")
    local passLevelId = self._levelAreaManager:getTopPassedLevel()
    for _, v in ipairs(loginRewardPoolMetaList) do
        if passLevelId >= v.openPassLevelRangeTuple.left and (passLevelId <= v.openPassLevelRangeTuple.right or v.openPassLevelRangeTuple.right == -1) then
            return v.rewardPool
        end
    end
    return nil
end

-- 根据奖池获得无限精力
function SubMsgBase:getDailyRewardEnergy(rewardList)
    for _, v in ipairs(rewardList) do
        if v.itemId == AMFPropId.INFINITE_ENERGY_BOTTLE_ONE_MINUTE then
            return {itemId = v.itemId, num = v.num}
        end
    end
    return nil
end

-- 根据奖池获得随机奖励
function SubMsgBase:getDailyRewardRandom(rewardList)
    local tmpList = {}
    for _, v in ipairs(rewardList) do
        local weight = math.floor(tonumber(v.priority)/10)
        for i = 1, weight, 1 do
            table.insert(tmpList, {itemId = v.itemId, num = v.num})
        end
    end
    tmpList = table.shuffle(tmpList)
    return tmpList[1]
end

-- 弹出每日登录奖励
function SubMsgBase:showDailyRewardPanel()
    local d = deferred.new()
    local str = self._subMsgUtil:getEnterKeyFromValue()
    if not str then
        return d:resolve()
    end
    local dailyRewardPool = self:getDailyRewardPool()
    local reward
    if str == SubMessageConst.EnterKeyFrom.ENERGY_RECOVER_FULL then
        reward = self:getDailyRewardEnergy(dailyRewardPool)
    else
        reward = self:getDailyRewardRandom(dailyRewardPool)
    end
    if not reward then
        return d:resolve()
    end
    local SecondPanelAVM = require "amf.middleware.ui.kit.panel.second.SecondPanelAVM"
    local endTime = self:getSubValue("dailyRewardEndTime")
    local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
    local diffDay = TimeUtil:getDiffDays(endTime, TimeKit:timeInSec())
    local des = ""
    -- 最后一天
    if diffDay - 1 <= 0 then
        des = "这是今日首次通过【服务通知】内的消息登录游戏获得的奖励，已全部领取了哦"
    else
        des = {
            "这是今日首次通过【服务通知】内的消息登录游戏获得的奖励，还可领取",
            "<<c=e96b33>"..(diffDay - 1).."天>",
            "哦"
        }
    end
    -- 点击事件
    reward.clickCall = function(del, sp)
        self:showItemTip(reward, sp)
    end
    -- 延迟一帧再弹，不然home的时候不知道加哪去了
    setTimeOut(function()
        local titleStr = "每日登录奖励"
        local vm
        vm = SecondPanelAVM.Builder.new()
            :setTitle(titleStr)
            :setText(des)
            :setFly(false)
            :setRewards({ reward })
            :setButtonsConfig({
                {
                    str = "领取",
                    widthMode = UIButtonConfig.Widths.kShort,
                    colorMode = UIButtonConfig.ColorMode.green,
                    touchFunc = function ()
                        self:requestCardEnterReward({
                            itemId = reward.itemId,
                            num = reward.num
                        }):next(function()
                            -- 打点
                            self:dc("subscription", "everyday_reward", {
                                t1 = str
                            })
                            -- 设置要飞
                            vm:getUpdater():setFly(true):update()
                            vm:close()
                        end, function(resp)
                            if not resp:isCancel() then
                                vm:close()
                            end
                        end)
                    end
                },
            })
            :setCloseCallback(function()
                self:tryRemoveRewardTip()
                d:resolve()
            end)
            :build()
        vm:popout()
        SubMsgUIUtil:registerPassDay(vm)
    end, 0)

    return d
end

function SubMsgBase:onActEnterMainScene()
    -- 进入主场景再刷新才有效
    if self._needInitOnce then
        self._needInitOnce = false
        self:initialize()
    end
end

function SubMsgBase:onActPassDay()
    SubMsgUIUtil:onPassDay()
end

-- 是否已经领过将了
function SubMsgBase:isRegRewarded(id)
    local rewardedList = self:getSubValue("rewardedList") or {}
    return table.exist(rewardedList, id)
end

-- 是否可以领奖
function SubMsgBase:isRegCanReward(id)
    if self:isRegRewarded(id) then
        return false
    end
    -- 订阅过
    return self:isHistoryReged(id)
end

-- 历史是否订阅过
function SubMsgBase:isHistoryReged(id)
    local historyRegList = self:getSubValue("historyRegList") or {}
    return table.exist(historyRegList, id)
end

-- 是否领取了全部奖励
function SubMsgBase:isAllRegRewarded()
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    for _, v in ipairs(subscribeMetaList) do
        if not self:isRegRewarded(v.id) then
            return false
        end
    end
    return true
end

-- 是否订阅了
function SubMsgBase:isReged(id)
    local regList = self:getSubValue("regList") or {}
    return table.exist(regList, id)
end

-- 获得订阅了但是没领奖的数量
function SubMsgBase:getRegNotRewardCount()
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    local rewardedList = self:getSubValue("rewardedList") or {}
    return #subscribeMetaList - #rewardedList
end

-- 获得未订阅列表
function SubMsgBase:getNotRegList()
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    local regList = self:getSubValue("regList") or {}
    local list = {}
    for _, v in ipairs(subscribeMetaList) do
        if not table.exist(regList, v.id) then
            table.insert(list, v)
        end
    end
    return list
end

-- 刷新icon上的红点
function SubMsgBase:updateIcon()
    local icon = self._iconManager:getIconByIconKey(IconKey.kSubMsg)
    if icon then
        icon:updateState()
    end
end

-- 是否有可领取的订阅奖励
function SubMsgBase:hasSubMsgRewards()
    if not self:isEnabled() then return end
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    for _, v in ipairs(subscribeMetaList) do
        if self:isReged(v.id) and not self:isRegRewarded(v.id) then
            return true
        end
    end
    return false
end

-- 获得可以订阅的数量&&没有领取奖励
function SubMsgBase:getCanSubMsgCount()
    if not self:isEnabled() then return 0 end
    local count = 0
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    for _, v in ipairs(subscribeMetaList) do
        if not self:isHistoryReged(v.id) then
            count = count + 1
        end
    end
    return count
    -- if self:isAllRegRewarded() then return 0 end
    -- return self:getRegNotRewardCount()
end

function SubMsgBase:isSubmsgTypeEnabled(sceneType)
    if sceneType == SubMessageConst.SceneType.ENERGY_RECOVER_FULL 
        or sceneType == SubMessageConst.SceneType.LEVEL_AREA_UNLOCK 
    then
        return true
    end
    if sceneType == SubMessageConst.SceneType.MARK then
        return self._markManager:isEnabled()
    end
    if sceneType == SubMessageConst.SceneType.PROMOTEDAILY then
        return self._promoteDailyMgr:isEnabled() and self._promoteDailyMgr:getCurMonthNearestKeyMedal()
    end
    return false
end

-- 获得主界面需要展示的数据
function SubMsgBase:getMainShowDataList()
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    local dataList = {}
    for i, v in ipairs(subscribeMetaList) do
        local d = table.clone(v)
        d.hasReg = self:isReged(v.id)
        d.canReward = self:isRegCanReward(v.id)
        d.rewarded = self:isRegRewarded(v.id)
        d.reward = self:getRewardById(v.id)
        d.text = self:getTextById(v.id)
        d.hasReg = self:isReged(v.id) or self._subMsgUtil:isAlwaysAccept(v.tmplId)
        d.regedText = self:getRegedTextById(v.id)
        table.insert(dataList, d)
    end
    return dataList
end

-- 根据id获取订阅奖励
function SubMsgBase:getRewardById(id)
    local subscribeRewardMetaList = self:getSubValue("subscribeRewardMetaList") or {}
    local passLevelId = self._levelAreaManager:getTopPassedLevel()
    for _, v in ipairs(subscribeRewardMetaList) do
        if v.id == id and passLevelId >= v.openPassLevelRangeTuple.left and (passLevelId <= v.openPassLevelRangeTuple.right or v.openPassLevelRangeTuple.right == -1) then
            return v.rewardList and v.rewardList[1] or {}
        end
    end
    return {}
end

function SubMsgBase:checkStage4CanPop()
    return false
    -- if not self:isEnabled() then return end
    -- if not self:isUIEnabled() then return end
    -- -- 限制等级强弹
    -- if _G.getTopLevelId() < SubMessageConst.POP_STAGE4_LEVEL then
    --     return false
    -- end
    -- -- 有订阅的不弹
    -- local historyRegList = self:getSubValue("historyRegList") or {}
    -- if #historyRegList > 0 then return false end
    -- -- 弹了超过3次，不弹
    -- local stage4PopCount = self:getSubValue("stage4PopCount")
    -- if stage4PopCount >= 3 then return false end
    -- -- 上次弹出时间是今天不弹
    -- local stage4LastPopTime = self:getSubValue("stage4LastPopTime")
    -- local timeStart = TimeKit:getDayStartTimeByTS(stage4LastPopTime)
    -- if timeStart == TimeKit:getTodayStart() then
    --     return false
    -- end
    -- return true
end

-- 是否可以创建订阅的节点，精力、区域解锁...
function SubMsgBase:canShowSubMsgNode(sceneType)
    if not self:isEnabled() then return false end
    if not self:isUIEnabled() then return false end
    local id = self:getIdBySceneType(sceneType)
    if sceneType == SubMessageConst.SceneType.MARK then
        if id == 0 or self:isHistoryReged(id) then
            return false
        end
    elseif sceneType == SubMessageConst.SceneType.PROMOTEDAILY and not self._promoteDailyMgr:isEnabled() then
        return false
    end
    return true
end

function SubMsgBase:getSubNodeTextStruct(subMsgId)
    -- 已经领过奖
    local textStruct = LabelStruct.new()
    local text = self:getTextById(subMsgId)
    local reward = self:getRewardById(subMsgId)
    if table.isEmpty(reward) then
        reward = {itemId = 2, num = 1}
    end
    local state = SubMsgNode.State.NONE
    local sceneType = self:getSceneTypeById(subMsgId)
    local textCfg = SubMessageConst.SubMsgNodeText[sceneType]
    if self:isReged(subMsgId) or self._subMsgUtil:isAlwaysAccept(self:getTmplIdById(subMsgId))
    then
        local str = self:getRegedTextById(subMsgId)
        textStruct:setText({
            "<<c="..textCfg.color..">"..str..">",
        })
        state = SubMsgNode.State.REWARDED_REG
    elseif self:isRegRewarded(subMsgId) then
        local str = self:getNoRewardTextById(subMsgId)
        textStruct:setText({
            "<<c="..textCfg.color..">"..str..">",
        })
        state = SubMsgNode.State.REWAREDED_NOREG
    else
        local icon = GameItemCreator:getPropIcon({itemId = reward.itemId, num = reward.num, needNum = false})
        local NumberUtil = require "amf.middleware.ui.util.NumberUtil"
        local extStr = NumberUtil:formatRewardNum(reward)
        local txt = icon:getLeftTopText()
        if txt and txt ~= "" then
            icon:setLeftTopText("")
            extStr = txt
            icon:setItemType(_G.UEPropIcon_ItemType.None)
        end
        local firstActName = "开启"
        textStruct:setText({
            "<<c="..textCfg.color..">"..firstActName..text.."，"..(sceneType == SubMessageConst.SceneType.MARK and "得 >" or "\n得>"),
            "<<node>>",
            "<<c="..textCfg.color..">"..extStr .. ">",
            nodes = {
                icon
            }
        })
        state = SubMsgNode.State.NONE
    end
    textStruct:setHorizontalAlignment(kCCTextAlignmentLeft)
    if textCfg.outlineSize and textCfg.outlineColor then
        textStruct:setOutline(textCfg.outlineColor, textCfg.outlineSize)
    end
    if textCfg.fontSize then
        textStruct:setFontSize(textCfg.fontSize)
    end
    return textStruct, state
end

-- 自动注册
function SubMsgBase:autoRegSubMsg(mustId, param)
    param = param or {}
    local subscribeMetaList = self:getSubValue("subscribeMetaList") or {}
    local list = {}
    local mustData = nil
    for i, v in ipairs(subscribeMetaList) do
        if self._subMsgUtil:isAlwaysAccept(v.tmplId) and not self:isReged(v.id) then
            if mustId == v.id then
                mustData = v
            else
                table.insert(list, v)
            end
        end
    end
    if mustData then
        table.insert(list, 1, mustData)
    end
    list = table.headn(list, SubMessageConst.OneTimeRegCount)
    if table.isEmpty(list) then return end
    self:registerSubMsgAndGetRewards(list, {panelId = param.panelId})
end

-- 创建订阅节点
function SubMsgBase:createSubMsgNode(sceneType, basePanelVM, param)
    local d = deferred.new()
    local node
    local subMsgId = self:getIdBySceneType(sceneType)
    local textStruct, state = self:getSubNodeTextStruct(subMsgId)
    local params = {
        state = state,
        textStruct = textStruct,
        disposeCall = function()
            -- 自动注册
            self:autoRegSubMsg(subMsgId, param)
        end,
        clickCallback = function()
            local info = self:getMetaInfoById(subMsgId)
            if not info then return end
            -- if not self._networkStatusManager:isNetworkEnabled() then
            --     CommonTip:showErrorTip(-2)
            --     return
            -- end
            if basePanelVM then basePanelVM:lock() end
            -- 打点
            self:dc("subscription", "main_panel_click", {
                panel_id = param.panelId,
                t1 = 2,
                t2 = info.id
            })
            -- 标记可以记录有订阅成功
            self:setSubTempValue("canRecordRegTag", true)
            self:registerSubMsgAndGetRewards({info}, param):next(function(rewardList)
                if basePanelVM then basePanelVM:unlock() end
                self:showRewardPanel(rewardList, function()
                    if node and not node.isDisposed then
                        local textSt, state = self:getSubNodeTextStruct(subMsgId)
                        node:setTextStruct(textSt)
                        node:setState(state)
                        node:update()
                    end

                    -- 弹出每日登录奖励提醒界面
                    if self:getSubTempValue("hasRegSuccess") then
                        self:setSubTempValue("hasRegSuccess", false)
                        self:showDailyRewardNoticePanel()
                    end
                end)
            end, function(errCode)
                if basePanelVM then basePanelVM:unlock() end
                self:tryShowPermissionPanel(errCode)
            end)
        end
    }
    if param.nodeCreator then
        node = param.nodeCreator:create(params)
        d:resolve(node)
    else
        local files = Res.Files.EXTNODE
        self._assetsUtil:loadMiniFiles(files):next(function()
            node = SubMsgNode:create(params)
            d:resolve(node)
        end)
    end
    return d
end

-- 尝试展示权限界面
function SubMsgBase:tryShowPermissionPanel(errCode)
    if EnvUtil:isDYMiniGame() or EnvUtil:isALIPAYMiniGame() then
        return
    end
    if EnvUtil:isHuaweiMiniGame() then
        return
    end
    if EnvUtil:isUnionMiniGame() then
        return
    end
    if EnvUtil:isKuaiShouMiniGame() then
        return
    end
    if EnvUtil:isJdMiniGame() then
        return
    end

    if errCode == SubMessageConst.RegErrCode.PERMISSION then
        local SubMsgHelpPanelVM = require "amf.middleware.notification.submsg.view.SubMsgHelpPanelVM"
        local vm = SubMsgHelpPanelVM:create()
        vm:setLoadResFailCallback(function()
            -- do nothing
        end)
        vm:popout()
    end
end

-- 订阅领奖提醒界面
function SubMsgBase:showDailyRewardNoticePanel(callback)
    if not self:hasDailyReward() then
        safeRunCall(callback)
        return
    end

    if EnvUtil:isUnionOppoMiniGame() then
        safeRunCall(callback)
        return
    end

    local SubMsgDailyRewardNoticePanelVM = require_debug "amf.middleware.notification.submsg.view.SubMsgDailyRewardNoticePanelVM"
    local vm = SubMsgDailyRewardNoticePanelVM:create(callback)
    vm:setLoadResFailCallback(function()
        safeRunCall(callback)
    end)
    vm:popout()
end

-- 恭喜获得界面
function SubMsgBase:showRewardPanel(rewardList, callback)
    if table.isEmpty(rewardList) then
        safeRunCall(callback)
        return
    end
    for _, v in ipairs(rewardList) do
        v.clickCall = function(del, sp)
            self:showItemTip(v, sp)
        end
    end
    local ShowRewardsPanelVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelVM"
    local vm
    vm = ShowRewardsPanelVM.Builder.new()
        :setRewards(rewardList)
        :setTitle("恭喜获得")
        :setButtonText("领取")
        :setCloseCallback(function()
            self:tryRemoveRewardTip()
            safeRunCall(callback)
        end)
        :build()
    vm:popout()
end

function SubMsgBase:showItemTip(reward, target)
    local builder = UITip.Builder.new()
    builder:setTitle(self._propManager:getPropName(reward))
    builder:setTarget(target)
    if self._propManager:isFlowerSkin(reward.itemId) then
        builder:setFlowerId(reward.itemId)
    elseif self._propManager:isNameCardBg(reward.itemId) then
        builder:setFlowerId(reward.itemId)
    elseif self._propManager:isHeadFrame(reward.itemId) then
        builder:setHeadFrameId(reward.itemId)
    elseif self._propManager:isHeadImage(reward.itemId) then
        builder:setHeadImageId(reward.itemId)
    elseif self._propManager:isPlayerStatusProp(reward.itemId) then
        builder:setPlayerStatusId(reward.itemId)
    end
    self._rewardTip = builder:build()
end

function SubMsgBase:tryRemoveRewardTip()
    if self._rewardTip and not self._rewardTip.isDisposed then
        self._rewardTip:close()
        self._rewardTip = nil
    end
end

-- @override 今日是否可以领取从订阅进入的奖励
function SubMsgBase:checkTodayCanCardEnterReward()
    if not self._subMsgUtil:isEnterFromTmpl() then
        return false
    end
    -- 今天是否还能领
    if not self.model:canGetTodayCardEnterReward() then
        return false
    end
    return true
end

function SubMsgBase:dc(category, subCategory, extraData)
    local params = {
        category = category,
        sub_category = subCategory,
    }
    for k,v in pairs(extraData or {}) do
        params[k] = v
    end
    -- UError("SubMsg dc:", tts(params))
    DcUtil:UserTrack(params)
end

function SubMsgBase:setSubValue(key, value)
    self.model:setValue(key, value)
end

function SubMsgBase:getSubValue(key)
    if key == "subscribeMetaList" then
        local list = {}
        for i, v in ipairs(self.model:getValue(key) or {}) do
            if self:isSubmsgTypeEnabled(v.sceneTypeEnum) then
                table.insert(list, v)
            end
        end
        return list
    end
    return self.model:getValue(key)
end

function SubMsgBase:setSubTempValue(key, value)
    self.model:setTempData(key, value)
end

function SubMsgBase:getSubTempValue(key)
    return self.model:getTempData(key)
end

return SubMsgBase