local Meta = require "amf.feature.localactivity.pengpeng2026.config.PengPeng2026Config"

local Helper = {}

local function log(mgr, ...)
    if not mgr or not mgr.printLog then
        return
    end
    local modules = mgr.getLogModule and mgr:getLogModule()
    if not modules or not modules.PANEL then
        return
    end
    mgr:printLog(modules.PANEL, false, ...)
end

local function getConfig()
    return Meta.AttractPanel or {}
end

-- 三关延后状态统一经活动 Model 的 local flag 接口读写。
local function getLocalFlag(mgr, key, needTime)
    local model = mgr and mgr.getModel and mgr:getModel()
    if not model or not model.getFlagFromLocalByKey then
        return nil
    end
    return model:getFlagFromLocalByKey(key, needTime)
end

local function saveLocalFlag(mgr, key, needTime, value)
    local model = mgr and mgr.getModel and mgr:getModel()
    if not model or not model.saveFlagToLocalByKey then
        log(mgr, "PengPeng2026 save local flag failed", key, "hasModel", model ~= nil)
        return
    end
    model:saveFlagToLocalByKey(key, needTime, value)
end

local function getLocalIntFlag(mgr, key, needTime)
    local value = tonumber(getLocalFlag(mgr, key, needTime)) or 0
    if value < 0 then
        return 0
    end
    return math.floor(value)
end

local function saveLocalIntFlag(mgr, key, needTime, value)
    saveLocalFlag(mgr, key, needTime, math.max(0, math.floor(tonumber(value) or 0)))
end

-- 主面板同轮强弹后调用；只写三次过关抑制计数，不写每日已弹，避免误消耗引流曝光机会。
function Helper.markSuppressedByMainPanelAutoPop(mgr)
    local panelConfig = getConfig()
    -- updatePassLevelData 早于场景4强弹检测触发，所以本地计数多存一次，保证后续三次过关都被跳过。
    saveLocalIntFlag(mgr, panelConfig.SUPPRESS_COUNT_KEY, true, panelConfig.SUPPRESS_PASS_COUNT + 1)
    log(mgr, "PengPeng2026 attract panel suppress by main auto pop", panelConfig.SUPPRESS_PASS_COUNT)
end

-- 每次玩家过关后消耗一次抑制计数；返回 true 表示本次确实扣减了一次。
function Helper.consumeSuppressPassCount(mgr)
    local panelConfig = getConfig()
    local count = getLocalIntFlag(mgr, panelConfig.SUPPRESS_COUNT_KEY, true)
    if count <= 0 then
        return false
    end

    saveLocalIntFlag(mgr, panelConfig.SUPPRESS_COUNT_KEY, true, count - 1)
    log(mgr, "PengPeng2026 attract panel suppressed", "left", count - 1)
    return true
end

-- 检测当前是否允许弹引流面板；场景和每日次数由强弹框架保证。
function Helper.checkCanPop(mgr)
    local panelConfig = getConfig()
    if not mgr:isEnabled() then
        log(mgr, "PengPeng2026 attract panel check false", "not_main_time")
        return false
    end
    local suppressCount = getLocalIntFlag(mgr, panelConfig.SUPPRESS_COUNT_KEY, true)
    if suppressCount > 0 then
        log(mgr, "PengPeng2026 attract panel check false", "suppressedPassLeft", suppressCount)
        return false
    end
    local launchOpportunity = tonumber(mgr:getModel():getLaunchOpportunity()) or 0
    if launchOpportunity < panelConfig.MIN_LAUNCH_OPPORTUNITY then
        log(mgr, "PengPeng2026 attract panel check false", "launchOpportunity", launchOpportunity)
        return false
    end

    log(mgr, "PengPeng2026 attract panel check true", "launchOpportunity", launchOpportunity)
    return true
end

-- 构造引流面板描述富文本；收集物图标使用活动自定义静态图标配置。
function Helper.buildRichText(mgr)
    local launchOpportunity = tonumber(mgr:getModel():getLaunchOpportunity()) or 0
    return string.format(
        "<color=#B2714A>还有%s</color><itemId=%s><color=#B2714A>，快来参与吧~</color>",
        tostring(launchOpportunity),
        tostring(Meta.collectId)
    )
end

local function createRewardTouchHandler(reward)
    return function(event, param)
        local target = param and param.obj
        local propManager = _G.amfBean and _G.amfBean("PropManager")
        local name = propManager and propManager.getPropName and propManager:getPropName(reward)
        local UETip = require "amf.middleware.ui.kit.templates.uetip.UETip"
        if UETip and UETip.Builder and target then
            UETip.Builder.new()
                :setTarget(target)
                :setSkin(UETip.SkinType.NORMAL)
                :setOrdered()
                :setTitle(name and name ~= "" and name or tostring(reward.itemId))
                :setAutoCloseTime(3)
                :build()
        end
    end
end

-- 构造固定奖励展示，并给奖励图标绑定点击展示道具名。
function Helper.getRewards()
    local panelConfig = getConfig()
    local rewards = {
        { itemId = panelConfig.REWARD_SCORE_BUFF_20, num = 20, },
        { itemId = panelConfig.REWARD_TIMELIMIT_BRUSH_24H, num = 1 },
        { itemId = panelConfig.REWARD_INFINITE_ENERGY_ONE_HOUR, num = 20 },
    }
    for _, reward in ipairs(rewards) do
        reward.touchHandler = createRewardTouchHandler(reward)
    end
    return rewards
end

-- 弹出引流面板；确认按钮无网时只给提示不跳转。
function Helper.pop(mgr, closeCallback)
    if mgr.attractPanelVM and not mgr.attractPanelVM.isDisposed then
        safeRunCall(closeCallback)
        return false
    end

    local CommonPanelSecondCreator = require "amf.middleware.ui.kit.commonpanel.CommonPanelSecondCreator"
    local vm
    local function clearAndCallback()
        mgr.attractPanelVM = nil
        safeRunCall(closeCallback)
    end
    vm = CommonPanelSecondCreator:createSecondRewardPanel({
        title = "飞碟弹弹乐",
        richText = {
            string = Helper.buildRichText(mgr),
        },
        rewards = Helper.getRewards(),
        closeCallback = clearAndCallback,
        sureBtn = {
            string = "弹弹领奖",
            touchHandler = function()
                if vm.isDisposed then return end
                if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
                    CommonTip:showTip("网络异常，请检查网络设置~")
                    return
                end

                local originCloseCallback = closeCallback
                vm:setCloseCallback(function()
                    mgr.attractPanelVM = nil
                    mgr:openActivity(originCloseCallback, { from = "yinliu" }, true)
                end)
                vm:onCloseBtnTapped()
            end,
        },
    })
    if not vm then
        safeRunCall(closeCallback)
        return false
    end

    mgr.attractPanelVM = vm

    DcUtil:UserTrack({
        category = "colorful_bump",
        sub_category = "attract_panel",
    })
    log(mgr, "PengPeng2026 attract panel pop", "launchOpportunity", mgr:getModel():getLaunchOpportunity())
    return true
end

return Helper
