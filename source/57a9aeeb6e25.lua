-- @ref 集卡三选一礼包 → 强弹注册
-- 集卡三选一礼包（4100）是开心卡册（9087）同期的礼包活动，活动包自身没有 Manager，
-- 所以它的强弹注册与可弹判定都挂在本模块：由 CollectCardManager 的 AutoPop plug 统一注册与注销，
-- 可弹判定（活动状态校验、场景强弹 meta、24 小时 CD、强弹条件）全部收在本模块，
-- 活动包（collectcardthreeforone）只提供活动配置数据与面板打开。
local ThreeForOneGiftModule = class("ThreeForOneGiftModule")

-- 集卡三选一礼包活动 id
ThreeForOneGiftModule.ACT_ID = 4100

-- 活动标识，同时用于活动包路径与强弹本地状态 key
local ACT_KEY = "collectcardthreeforone"

-- 活动包 Config.lua 的运行期路径：活动 launcher 加载后与 ActivityNode 共用同一份缓存
local ACT_CONFIG_PATH = "activity/" .. ACT_KEY .. "/Config.lua"

-- 强弹条件类型：与活动包强弹配置下发的 conditionId 一致
local AUTO_POP_TYPE = {
    WINDCOIN = 1,
    ENERGY = 2,
    LOGIN = 3,
    CONTINUEFAIL = 4,
}

-- 强弹 CD：弹出后 24 小时内不再弹
local STRONG_PUSH_CD_SECONDS = 24 * 3600

-- 上次强弹弹出时间 key：沿用活动包原来的 key 组成（活动标识 + actId + 本期起止时间），换期后自动失效
local KEY_LAST_POPOUT_TIME = "StrongPushLastPopoutTime"

-- 连续失败次数 key：由本模块自持，与活动包旧的 ContinueFailCount 区分，避免迁移期间两边同时计数
local KEY_CONTINUE_FAIL_COUNT = "StrongPushContinueFailCount"

-- 强弹场景：PopupRegistration 会在 check/pop 的入参上补 popStage，用它换算出活动包强弹 meta 的 sceneId
-- （2 = 进入主场景，4 = 关后）。运行时取 _G.AutoPopupConst，避免依赖 require 顺序。
local function _getSceneIdByPopStage(popStage)
    if popStage == AutoPopupConst.PopStage.STAGE_TWO then
        return 2
    end
    if popStage == AutoPopupConst.PopStage.STAGE_FOUR then
        return 4
    end
    return nil
end

function ThreeForOneGiftModule:ctor(manager)
    self._manager = manager
    -- 连续失败次数依赖关卡结算事件，模块与 CollectCardManager 同生命周期，注册一次即可
    _G.amfEC:registerFeature(self)
end

---活动当前是否可用：ActivityMgr:isActSupported 同时覆盖活动包 config 已加载（含 isSupport 校验）与 actInfo 支持
function ThreeForOneGiftModule:isActSupported()
    return self._manager:isActivitySupported(self.ACT_ID) == true
end

function ThreeForOneGiftModule:_getActConfig()
    return require(ACT_CONFIG_PATH)
end

---强弹本地状态 key：活动标识 + actId + 本期起止时间 + key，换期后旧数据不再命中
function ThreeForOneGiftModule:_getLocalKey(key)
    local config = self:_getActConfig()
    return table.concat({
        ACT_KEY,
        tostring(config.actId),
        tostring(config.getBeginTime()),
        tostring(config.getEndTime()),
        tostring(key),
    }, "_")
end

---上次强弹弹出时间（秒）
function ThreeForOneGiftModule:getStrongPushLastPopoutTime()
    return LocalDB:getInt(self:_getLocalKey(KEY_LAST_POPOUT_TIME), 0) or 0
end

---记录本次强弹弹出时间：弹出即写入，之后 24 小时内不再弹
function ThreeForOneGiftModule:setStrongPushLastPopoutTime()
    LocalDB:setInt(self:_getLocalKey(KEY_LAST_POPOUT_TIME), TimeKit:timeInSec(), true)
end

---强弹剩余 CD 秒数，小于等于 0 表示不在 CD 内
function ThreeForOneGiftModule:getStrongPushCdLeftSeconds()
    return self:getStrongPushLastPopoutTime() + STRONG_PUSH_CD_SECONDS - TimeKit:timeInSec()
end

---连续失败次数（由关卡结算事件维护）
function ThreeForOneGiftModule:getContinueFailCount()
    return LocalDB:getInt(self:_getLocalKey(KEY_CONTINUE_FAIL_COUNT), 0) or 0
end

function ThreeForOneGiftModule:setContinueFailCount(failCount)
    LocalDB:setInt(self:_getLocalKey(KEY_CONTINUE_FAIL_COUNT), failCount or 0, true)
end

---关卡结算：胜场清零、败场累加，供「连续失败 N 次」强弹条件使用
function ThreeForOneGiftModule:onActPlayLevelEnd(event)
    if not self:isActSupported() then
        return
    end

    local data = event and event:getData() or {}
    if data.isWin then
        self:setContinueFailCount(0)
    else
        self:setContinueFailCount(self:getContinueFailCount() + 1)
    end
end

---强弹条件：风车币少于阈值
function ThreeForOneGiftModule:_checkRemainWindCoin(checkCount)
    checkCount = checkCount or 30
    local userManager = _G.amfBean("UserManager")
    local coinNumber = userManager and userManager:getCash() or 0
    return coinNumber < checkCount
end

---强弹条件：体力少于阈值（无限体力不弹）
function ThreeForOneGiftModule:_checkRemainEnergy(checkCount)
    checkCount = checkCount or 5
    local energyManager = _G.amfBean("UserEnergyManager")
    if not energyManager then
        return false
    end
    if energyManager:getEnergyState() == UserEnergyState.INFINITE then
        return false
    end
    return energyManager:getEnergy() < checkCount
end

---强弹条件：进入场景即弹
function ThreeForOneGiftModule:_checkOnEnterAutoPop()
    return true
end

---强弹条件：连续失败次数达到阈值
function ThreeForOneGiftModule:_checkContinueFailCount(checkCount)
    checkCount = checkCount or 3
    return self:getContinueFailCount() >= checkCount
end

---单条强弹 meta 是否满足条件，conditionId / conditionValue 由服务端强弹配置下发
function ThreeForOneGiftModule:checkStrongPushCondition(meta)
    if not meta then
        return false
    end

    local conditionId = tonumber(meta.conditionId) or 0
    local conditionValue = tonumber(meta.conditionValue) or 0
    if conditionId == AUTO_POP_TYPE.WINDCOIN then
        return self:_checkRemainWindCoin(conditionValue)
    elseif conditionId == AUTO_POP_TYPE.ENERGY then
        return self:_checkRemainEnergy(conditionValue)
    elseif conditionId == AUTO_POP_TYPE.LOGIN then
        return self:_checkOnEnterAutoPop()
    elseif conditionId == AUTO_POP_TYPE.CONTINUEFAIL then
        return self:_checkContinueFailCount(conditionValue)
    end
    return false
end

---该场景的强弹 meta 是否可弹：24 小时 CD + 命中任意一条强弹条件
---不通过时把原因作为第二个返回值透出，框架会记进强弹场景日志
function ThreeForOneGiftModule:checkStrongPushConditions(metaList)
    if table.isEmpty(metaList or {}) then
        return false, "strong push meta list empty"
    end

    local leftSeconds = self:getStrongPushCdLeftSeconds()
    if leftSeconds > 0 then
        return false, "strong push in cd, leftSeconds=" .. tostring(leftSeconds)
    end

    for _, meta in ipairs(metaList) do
        if self:checkStrongPushCondition(meta) then
            return true
        end
    end
    return false, "all strong push conditions failed"
end

---场景强弹是否可弹：按当前强弹场景取该场景的强弹 meta，再走本模块的可弹判断
function ThreeForOneGiftModule:checkStrongPush(stageParams)
    if not self:isActSupported() then
        return false
    end

    local sceneId = _getSceneIdByPopStage(stageParams and stageParams.popStage)
    if not sceneId then
        return false
    end

    return self:checkPopMainFunction(self:_getActConfig().getStrongPushMetaListByScene(sceneId))
end

---场景强弹是否可弹：活动强弹基础校验 + 24 小时 CD + 强弹条件
---原实现在活动包（collectcardthreeforone）的 config.checkPopMainFunction 与 src/model/Model.lua，现都收在本模块
function ThreeForOneGiftModule:checkPopMainFunction(strongPushMeta)
    local supportFailReason = self:_getActConfig().getStrongPushSupportFailReason()
    if supportFailReason then
        return false, supportFailReason
    end

    return self:checkStrongPushConditions(strongPushMeta)
end

---场景强弹弹出：记录 24 小时 CD 后交给活动包开面板；不弹的每个分支都必须回调 onPopOver，否则强弹 FSM 会卡住
function ThreeForOneGiftModule:popStrongPush(onPopOver)
    if not self:isActSupported() then
        safeRunCall(onPopOver)
        return
    end

    -- 先记 CD 再开面板：面板打开失败或玩家中途退出也算弹过，与活动包原逻辑一致
    self:setStrongPushLastPopoutTime()
    self:_getActConfig().popMainFunction(onPopOver)
end

---注册式强弹声明，由 CollectCardManager:_getAutoPopConfigList 合并后统一注册
function ThreeForOneGiftModule:getAutoPopConfigList()
    -- 集卡三选一礼包主面板强弹：场景2/场景4 共用一个检测点，由 popStage 决定用哪个场景的强弹条件；
    -- 次数由本模块的 24 小时 CD 控制，因此框架侧不再叠加每日次数限制。
    return {
        {
            checkPoint = PopupCheckPoint.COLLECT_CARD_THREE_FOR_ONE_MAIN_POP,
            stages = {AutoPopupConst.PopStage.STAGE_TWO, AutoPopupConst.PopStage.STAGE_FOUR},
            actId = self.ACT_ID,
            check = function(stageParams)
                return self:checkStrongPush(stageParams)
            end,
            pop = function(_, onPopOver)
                return function()
                    self:popStrongPush(onPopOver)
                end
            end,
        },
    }
end

return ThreeForOneGiftModule
