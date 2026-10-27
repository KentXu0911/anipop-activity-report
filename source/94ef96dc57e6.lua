require "amf.feature.minihub.addmine.config.AddMineConst"
local deferred = require "amf.script.sugar.deferred"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"

local AddMineManager = class("AddMineManager")

function AddMineManager:ctor()
    self._assetsUtil = nil
    self._iconManager = nil
    self._levelAreaManager = nil
    self._propManager = nil
    self._autoPopupMgr = nil
    self._userTagManager = nil

    self._model = nil
    self._cacheUI = {}
    self._isResReady = true
    self._rewardTip = nil
    self._unableFromLevel = false
end

function AddMineManager:setUserTagManager(userTagManager)
    self._userTagManager = userTagManager
end

function AddMineManager:setPropManager(propManager)
    self._propManager = propManager
end

function AddMineManager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
end

function AddMineManager:setLevelAreaManager(mgr)
    self._levelAreaManager = mgr
end

function AddMineManager:setIconManager(iconManager)
    self._iconManager = iconManager
end

function AddMineManager:setAssetsUtil(assetsUtil)
    self._assetsUtil = assetsUtil
end

function AddMineManager:initialize()
    if not self:isLocalEnabled() then return end

    self._model = require("amf.feature.minihub.addmine.model.Model"):create()
    -- 如果活动触发过本地有缓存，并过期，不再无脑发协议
    if self:checkIsCompleteLocal() then return end

    -- self:loadRes()
    self:doAfterLoadInfo()
    self:requestMainInfo():next(function()
        self:doAfterLoadInfo()
    end)
    _G.amfEC:registerFeature(self)
end

---------------------- 业务逻辑 ---------------------

function AddMineManager:checkIsCompleteLocal()
    local collected = self:getDataValue("collected")
    local collectRewardFetchDay = self:getDataValue("collectRewardFetchDay")
    local continueRewardList = self:getDataValue("continueRewardList")
    local canGetDayNum = #continueRewardList
    local curDay = TimeUtil:getDayIdxSince1970()
    local diff = curDay - collectRewardFetchDay
    local hasCanGet = self._model:canGetReward()

    return collected and collectRewardFetchDay > 0 and canGetDayNum > 0 and diff >= canGetDayNum and not hasCanGet
end

function AddMineManager:doAfterLoadInfo()
    if not self:isEnabled() then return end
    -- 刷新右下角iconPool
    local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
    self._iconManager:updatePoolByType(IconMeta.PoolType.kRightCorner)
    -- 刷新红点
    self:updateIcon()
end

function AddMineManager:isEnabled()
    return self:isLocalEnabled() and self._model and self:getDataValue("isFromServer")
end

-- function AddMineManager:loadRes(silence)
--     local d = deferred.new()
--     if silence == nil then
--         silence = true
--     end
--     self._assetsUtil:loadMiniLabels({"add_mine"}, silence):next(function()
--         self._isResReady = true
--         d:resolve()
--     end, function()
--         d:reject()
--     end)
--     return d
-- end

function AddMineManager:isUIEnabled()
    return self._isResReady
end

function AddMineManager:isLocalEnabled()
    if EnvUtil:isWXMiniGame() then
        local Group = require "amf.feature.minihub.addmine.config.Group"
        if Group:isOff() then
            self._unableFromLevel = true
            return false
        end
    elseif EnvUtil:isDYMiniGame() then
        self._unableFromLevel = true
        return false
    elseif EnvUtil:isALIPAYMiniGame() then
        self._unableFromLevel = true
        return false
    elseif EnvUtil:isHuaweiMiniGame() then
        self._unableFromLevel = true
        return false
    elseif EnvUtil:isUnionMiniGame() then
        self._unableFromLevel = true
        return false
    elseif EnvUtil:isKuaiShouMiniGame() then
        self._unableFromLevel = true
        return false
    elseif EnvUtil:isJdMiniGame() then
        self._unableFromLevel = true
        return false
    end

    return true
end

function AddMineManager:isEnterSceneCorrectly(needSync)
    if not needSync and self.enterSceneCorrectly ~= nil then
        return self.enterSceneCorrectly
    end

    -- 每次拉起都会变
    local enterOption = _G.CALL_JS_AYNC("getEnterOptions")
    if enterOption and enterOption ~= "" then
        local enterOpTb = table.deserialize(enterOption)
        local query = enterOpTb.query
        for k,v in pairs(AddMineConst.EnterFromSecne) do
            if tostring(v) == tostring(enterOpTb.scene) then
                self.enterSceneCorrectly = true
                return true
            end
        end
    end

    self.enterSceneCorrectly = false
    return false
end

function AddMineManager:isCollectAndReward()
    if not self:isEnabled() then return end

    local collected = self:getDataValue("collected")
    local collectRewardFetchDay = self:getDataValue("collectRewardFetchDay")

    return collected and collectRewardFetchDay > 0
end

function AddMineManager:getMainReward()
    return self:getDataValue("collectRewardList")
end

function AddMineManager:canGetMainReward()
    return self._model:canGetMainReward()
end

function AddMineManager:checkStage2CanPop()
    if not self:isEnabled() then return false end
    if not self:isUserTagCanPop() then return false end
    if _G.getTopLevelId() < 21 then return false end

    if not self._model:canGetReward() then return false end
    if not self:isEnterSceneCorrectly(true) and not self._model:canGetMainReward() then return false end
    if not self:isUIEnabled() and self._model:canGetMainReward() then return false end

    return true
end

function AddMineManager:checkStage4CanPop()
    if not self:isEnabled() then return false end
    if not self:isUIEnabled() then return false end
    if not self:isUserTagCanPop() then return false end
    if _G.getTopLevelId() < 21 then return false end

    -- 奖励领取过不弹
    local collectRewardFetchDay = self:getDataValue("collectRewardFetchDay")
    if collectRewardFetchDay > 0 then return false end

    -- 弹了超过3次不弹
    local stage4PopCount = self:getDataValue("stage4PopCount")
    if stage4PopCount >= 3 then return false end

    -- 上次弹出时间是今天不弹
    local stage4LastPopTime = self:getDataValue("stage4LastPopTime")
    local timeStart = TimeKit:getDayStartTimeByTS(stage4LastPopTime)
    if timeStart == TimeKit:getTodayStart() then
        return false
    end

    return true
end

----------------------- 协议 --------------------------

-- 检查是否被添加到我的小程序
function AddMineManager:requestCheckIsAddedToMyMiniProgram()
    local d = deferred.new()
    if EnvUtil:isWXMiniGame() then
        WeChatAPI.CheckIsAddedToMyMiniProgram({
            success = function(ret, res)
                local resTb = table.deserialize(res)
                local added = resTb.added
                d:resolve(added)
            end,
            fail = function(ret)
                d:reject()
            end,
            complete = function(ret)
                -- do nothing
            end
        })
    end

    return d
end

function AddMineManager:requestMainInfo()
    return self._model:requestMainInfo()
end

function AddMineManager:requestNotifyServer()
    local d = deferred.new()
    self._model:requestNotifyServer():next(function(response)
        self:updateIcon()
        self:updateMainPanel()
        d:resolve()
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject(response)
    end)
    return d
end

function AddMineManager:requestGetRewardFirst()
    local d = deferred.new()
    self._model:requestGetRewardFirst():next(function(response)
        self:updateIcon()
        local data = response:getData()
        d:resolve(data.userData.collectRewardList)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject(response)
    end)
    return d
end

function AddMineManager:requestGetRewardNormal()
    local d = deferred.new()
    self._model:requestGetRewardNormal():next(function(response)
        self:updateIcon()
        local data = response:getData()
        d:resolve(data.rewardList)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject(response)
    end)
    return d
end

function AddMineManager:isUserTagCanPop()
    local activationTag = UserTagManager:getUserTag(UserTagNameKeyFullMap.kLiveness)
    if not activationTag then return false end

    local activationTagValue = UserTagValueMap[UserTagNameKeyFullMap.kLiveness]
    if activationTag == activationTagValue.kNewUser then return false end

    local serverUserTag, serverUserTagUpdateTime = self._model:getLivenessInfo()
    if serverUserTag ~= activationTagValue.kReturnUser then return true end

    local beginDay = TimeUtil:getDayIdxSince1970(math.floor(serverUserTagUpdateTime/1000))
    local endDay = beginDay + 7 - 1
    local curDay = TimeUtil:getDayIdxSince1970()

    if curDay >= beginDay and curDay <= endDay then return false end

    return true
end

----------------------- 流程处理 ---------------------
-- 场景2强弹
function AddMineManager:handleEnterStage2(evt)
    if not self:checkStage2CanPop() then return end

    local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.ADD_MINE)
	end

	local function creator()
        UWarning("AddMineManager:handleEnterStage2 creator")
        if self._model:canGetMainReward() then
            self:popMainPanel(2):next(onHandleOver, onHandleOver)
        else
            UWarning("AddMineManager:handleEnterStage2 popRewardPanel")
            self:popRewardPanel():next(onHandleOver, onHandleOver)
        end
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.ADD_MINE, creator)
end

-- 场景4强弹
function AddMineManager:handleEnterStage4(evt)
    if not self:checkStage4CanPop() then return end

    local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.ADD_MINE_STAGE4)
	end
	local function creator()
		self:popMainPanel(2):next(onHandleOver, onHandleOver)
	end
	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.ADD_MINE_STAGE4, creator)
end

-- 过关检查是否要开启
function AddMineManager:handlePassLevelEnd(evt)
    -- 如果一开始不可用就检查
    if not self._unableFromLevel then return end
    if self:checkIsCompleteLocal() then return end

    -- 如果本来就可用就不检查了
    local data = evt:getData()
    if not data.isWin then return end
    if self:isLocalEnabled() then
        self._unableFromLevel = false
        -- 重新初始化一次
        self:initialize()
    end
end

function AddMineManager:handleIconTouch()
    local d = deferred.new()

    d:next(function()
        self:requestMainInfo():next(function()
            if not self:isCollectAndReward() then
                self:popMainPanel(1)
            elseif self:isEnterSceneCorrectly() and self._model:getTodayNormalReward() and not self._model:isGetTodayNormalReward() then
                self:popRewardPanel()
            else
                self:popDescPanel()
            end
        end, function(response)
            if not response:isCancel() then
                CommonTip:showErrorTip(response)
            end
        end)
    end)

    local collected = self:getDataValue("collected")
    if not collected then
        self:requestCheckIsAddedToMyMiniProgram():next(function(added)
            if added then
                self:requestNotifyServer():next(function()
                    self:updateMainPanel()
                    self:updateIcon()
                    d:resolve()
                end)
            else
                d:resolve()
            end
        end, function()
            d:resolve()
        end)
    else
        d:resolve()
    end
end

----------------------- 面板/UI ------------------------

function AddMineManager:showMainSceneTip()
    local d = deferred.new()

    self:dc("guide_addition", "main_tip_pop")

    -- local buttonJson = WeChatAPI.GetMenuButtonBoundingClientRect()
    -- local buttonInfo = table.deserialize(buttonJson)
    -- local winJson = WeChatAPI.GetWindowInfo()
    -- local winInfo = table.deserialize(winJson)
    local buttonInfo = _G.GetMenuButtonBoundingClientRect()
    local winInfo = _G.GetWindowInfo()
    if not buttonInfo or not winInfo then
        d:reject()
        return d
    end

    self._assetsUtil:loadMiniFiles({"amf/addmine/materials/dot.png"}, true)
        :next(function()
            local tip = UITip.Builder.new()
                        :setTitle("点击          选择“添加到我\n的小程序”，登录更方便哦")
                        :setAutoCloseTime(10)
                        :setCloseCallback(function()
                            self:dc("guide_addition", "main_tip_close")
                            d:resolve()
                        end)
                        :setDirection("down")
                        :build()

            local content = tip:getMainContent()
            local dot = UICreateUtil:createSpriteFile("amf/addmine/materials/dot.png")
            dot:setPositionXY(103, 70)
            content:addChild(dot)

            -- 定位
            local safeArea = _G.fullScreenSizeManager:getSafeArea()
            local visibleSize = safeArea.size
            local originPos = safeArea.origin
            local ratio = visibleSize.width / winInfo.safeArea.width

            local baseX = originPos.x + (buttonInfo.left + buttonInfo.width/4) * ratio
            local baseY = originPos.y + visibleSize.height

            tip:setPositionXY(baseX, baseY)

            -- 适配
            local bounds = content:getGroupBounds()
            local wpos = content:getPositionInWorldSpace()
            local cur = wpos.x + bounds.size.width/2
            local max = originPos.x + visibleSize.width

            local diff = cur - max
            if diff > 0 then
                tip:moveMainContent(-diff - 5)
            end

            -- 动画
            tip:runAction(CCRepeatForever:create(ActionUtil:sequence{
                CCMoveBy:create(0.5, ccp(0, 10)),
                CCMoveBy:create(0.5, ccp(0, -10))
            }))
        end, function()
            d:reject()
        end)

    return d
end

function AddMineManager:updateMainPanel()
    for vm, __ in pairs(self._cacheUI) do
        if vm and vm.panelKey == "AddMineMainPanel" and not vm.isDisposed then
            vm:updatePanel()
        end
    end
end

function AddMineManager:popMainPanel(from)
    local d = deferred.new()

    -- 强弹调用的
    if from == 2 then
        local stage4PopCount = self:getDataValue("stage4PopCount")
        self:setDataValue("stage4PopCount", stage4PopCount + 1)
        self:setDataValue("stage4LastPopTime", TimeKit:timeInSec())
    end

    -- local function showMain()
    local AddMineMainPanelVM = require "amf.feature.minihub.addmine.view.AddMineMainPanelVM"
    local vm
    vm = AddMineMainPanelVM:create({
        closeCall = function()
            self:cancelCachePanelUI(vm)
            -- 没有奖大藤蔓弹tip, 有奖弹desc
            local collected = self:getDataValue("collected")
            if not collected then
                self:showMainSceneTip():next(function()
                    d:resolve()
                end, function()
                    d:reject()
                end)
            elseif self:isCollectAndReward() then
                self:popDescPanel():next(function()
                    d:resolve()
                end, function()
                    d:reject()
                end)
            else
                d:resolve()
            end
        end,
        from = from,
    })

    vm:setLoadResFailCallback(function()
        self:cancelCachePanelUI(vm)
        d:reject()
    end)

    vm:popout()
    vm.panelKey = "AddMineMainPanel"
    self:cachePanelUI(vm)
    -- end

    -- self:loadRes(false):next(function()
    --     showMain()
    -- end, function()
    --     d:reject()
    -- end)

    return d
end

function AddMineManager:popRewardPanel()
    local d = deferred.new()

    local curScene = Director:sharedDirector():getRunningSceneLua()
    UWarning(curScene:getCurrentSceneName())

    UWarning(1)
    local todayReward, day = self._model:getTodayNormalReward()
    if not todayReward or #todayReward == 0 then
        d:reject()
        return d
    end

    UWarning(2)
    local diffDay = self._model:getLeftDayReward()
    local des
    -- 最后一天
    if diffDay <= 0 then
        des = "这是今日首次通过【我的小程序】登录游戏获得的奖励，已经全部领取了哦"
    else
        des = {
            "这是今日首次通过【我的小程序】登录游戏获得的奖励，还可以领取",
            "<<c=e96b33>"..diffDay.."天>",
            "哦"
        }
    end

    local textStruct = LabelStruct.new()
        :setText(des)
        :setHorizontalAlignment(kCCTextAlignmentLeft)
        :setFontSize(28)
        :setLineSpace(14)

    -- 点击事件
    for _, reward in ipairs(todayReward) do
        reward.clickCall = function(del, sp)
            self:showItemTip(reward, sp)
        end
    end

    local vm
    local function tryGetReward()
        if vm.isDisposed then return end
        if vm:isLocked() then return end

        vm:lock()
        self:requestGetRewardNormal():next(function()
            self:dc("guide_addition", "everyday_reward",{
                t1 = day,
            })
            vm:update({ isFly = true })
            self:doAfterLoadInfo()
            vm:close()
        end, function(resp)
            vm:unlock()
        end)
    end

    local SecondPanelAVM = require "amf.middleware.ui.kit.panel.second.SecondPanelAVM"
    vm = SecondPanelAVM.Builder.new()
        :setTitle("每日奖励")
        :setTextStruct(textStruct)
        :setFly(false)
        :setRewards(todayReward)
        :setButtonsConfig({
            {
                str = "领取",
                widthMode = UIButtonConfig.Widths.kShort,
                colorMode = UIButtonConfig.ColorMode.green,
                touchFunc = tryGetReward
            },
        })
        -- :setCloseBtnCall(tryGetReward)
        :setCloseCallback(function()
            UWarning(5)
            self:tryRemoveRewardTip()
            self:cancelCachePanelUI(vm)
            d:resolve()
        end)
        :build()

    vm:setLoadResFailCallback(function()
        self:cancelCachePanelUI(vm)
        UWarning(6)
        d:reject()
    end)

    UWarning(3)
    vm:popout()
    self:cachePanelUI(vm)

    UWarning(4)

    return d
end

function AddMineManager:popDescPanel()
    local d = deferred.new()

    local delegate = {
        closeCall = function()
            d:resolve()
        end,
        leftDay = self._model:getLeftDayReward(),
        isFirst = self._model:isFirstDay(),
        isEnd = self._model:isLastDay(),
        isGet = self._model:isGetTodayNormalReward(),
    }

    local AddMineHelpPanelVM = require "amf.feature.minihub.addmine.view.AddMineHelpPanelVM"
    local vm = AddMineHelpPanelVM:create(delegate)

    vm:setLoadResFailCallback(function()
        self:cancelCachePanelUI(vm)
        d:reject()
    end)

    vm:popout()
    self:cachePanelUI(vm)

    return d
end

function AddMineManager:cachePanelUI(vm)
    self._cacheUI[vm] = true
end

function AddMineManager:cancelCachePanelUI(vm)
    self._cacheUI[vm] = nil
end

function AddMineManager:showItemTip(reward, target)
    local builder = UITip.Builder.new()

    local unlock = self._propManager:getPropUnlockLevel(reward.itemId)
    local levelId = _G.getTopLevelId()
    local propName = self._propManager:getPropName(reward)
    if levelId < unlock then
        propName = propName.."，第"..unlock.."关解锁"
    end

    builder:setTitle(propName)
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

function AddMineManager:tryRemoveRewardTip()
    if self._rewardTip and not self._rewardTip.isDisposed then
        self._rewardTip:close()
        self._rewardTip = nil
    end
end

----------------------- 事件/强弹 ---------------------

-- 过关事件
function AddMineManager:onActPlayLevelEnd(evt)
    if not self:isLocalEnabled() then return end

    local collected = self:getDataValue("collected")
    if not collected then
        self:requestCheckIsAddedToMyMiniProgram():next(function(added)
            if added then
                self:requestNotifyServer():next(function()
                    self:updateMainPanel()
                    self:updateIcon()
                end)
            end
        end)
    end

    self:handlePassLevelEnd(evt)
end

-- 场景2强弹
function AddMineManager:onActEnterStage2(evt)
    if not self:isLocalEnabled() then return end

    local collected = self:getDataValue("collected")
    if not collected then
        self:requestCheckIsAddedToMyMiniProgram():next(function(added)
            if added then
                self:requestNotifyServer():next(function()
                    self:updateMainPanel()
                    self:updateIcon()
                end)
            end
        end)
    end

    self:handleEnterStage2(evt)
end

-- 场景4强弹
function AddMineManager:onActEnterStage4(evt)
    self:handleEnterStage4(evt)
end

-- 跨天
function AddMineManager:onPassDay()
    for vm, __ in pairs(self._cacheUI) do
        if vm and not vm.isDisposed then
            vm:close()
        end
    end
    self._cacheUI = {}
    self:updateIcon()
end

----------------------- 通用 ---------------------

function AddMineManager:dc(category, subCategory, extraData)
    local params = {
        category = category,
        sub_category = subCategory,
    }
    for k,v in pairs(extraData or {}) do
        params[k] = v
    end

    DcUtil:UserTrack(params)
end

function AddMineManager:setDataValue(key, value)
    self._model:setValue(key, value)
end

function AddMineManager:getDataValue(key)
    return self._model:getValue(key)
end

function AddMineManager:setDataTempValue(key, value)
    self._model:setTempData(key, value)
end

function AddMineManager:getDataTempValue(key)
    return self._model:getTempData(key)
end

----------------------- icon ---------------------
function AddMineManager:updateIcon()
    local icon = self._iconManager:getIconByIconKey(IconKey.kAddMine)
    if icon then
        icon:updateState()
    end
end

function AddMineManager:hasAddMineRewards()
    if not self:isEnabled() then return false end
    if self:canGetMainReward() then return true end

    return self._model:canGetReward() and self:isEnterSceneCorrectly()
end


function AddMineManager:isIconCanShow()
    return self:isEnabled() and not self:checkIsCompleteLocal()
end

function AddMineManager:hasAddMineHint()
    if not self:isEnabled() then return false end
    local collected = self:getDataValue("collected")
    if not collected then return true end

    return self:isCollectAndReward() and not self._model:isGetTodayNormalReward() and not self._model:isFirstDay() and not self:isEnterSceneCorrectly()
end

return AddMineManager
