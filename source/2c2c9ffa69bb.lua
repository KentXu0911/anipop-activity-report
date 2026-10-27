local ActivityCenterBannerModule = class("ActivityCenterBannerModule")

-- 单个活动 banner 的已弹记录 key 后缀，前缀为该活动的新字 unique key。
ActivityCenterBannerModule.BANNER_RECORD_SUFFIX = "_activity_center_banner"
-- 所有资讯福利站 banner 已弹记录统一收敛到 model 的这张本地表里。
ActivityCenterBannerModule.BANNER_RECORD_CACHE_KEY = "ActivityCenterBannerShownMap"
ActivityCenterBannerModule.UPDATE_CANDIDATE_DELAY = 5

-- 创建模块实例，并把 ActivityCenterManager 作为数据和资源入口注入。
function ActivityCenterBannerModule:create(manager)
    local module = ActivityCenterBannerModule.new()
    module:init(manager)
    return module
end

-- 绑定 manager，后续通过它读取 visibleDatas、活动资源状态和本地缓存。
function ActivityCenterBannerModule:init(manager)
    self.manager = manager
    self.loadedCandidateActIdMap = {}
end

-- 场景 2 强弹检查点，尝试把当前 banner 候选加入强弹队列。
function ActivityCenterBannerModule:onActEnterStage2()
    self:tryAddAutoPop()
end

-- 场景 4 强弹检查点，复用与场景 2 相同的候选和已弹记录。
function ActivityCenterBannerModule:onActEnterStage4()
    self:tryAddAutoPop()
end

-- 判断当前缓存候选是否满足自动弹出条件，并输出具体卡点日志。
function ActivityCenterBannerModule:canShowAutoPop()
    -- 新关期间头部玩家屏蔽自动强弹，保持与资讯福利站入口迁移引导一致。
    if _G.amfBean("AutoPopupMgr"):ignoreForTopLevelPlayer() then
        return false
    end

    local actId = self.bannerCandidateActId
    if not actId then
        return false
    end
    if not self.bannerCandidateNewActKey then
        return false
    end
    if not self:canShowNewActFlagByKey(self.bannerCandidateNewActKey, actId) then
        return false
    end
    if not self:isCandidateResReady(actId) then
        return false
    end
    if not self:getBannerData() then
        return false
    end
    if self:hasShownBanner() then
        return false
    end
    return true
end

-- 条件满足时注册 AutoPopup creator；真正弹出由强弹框架调度。
function ActivityCenterBannerModule:tryAddAutoPop()
    --检测强弹banner
    if not self:canShowAutoPop() then return false end

    local function creator()
        self:showAutoPop(function()
            AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.ACTIVITY_CENTER_BANNER)
        end)
    end
    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.ACTIVITY_CENTER_BANNER, creator)
    return true
end

-- 强弹执行入口：重新取 banner 数据，加载 UI 资源后交给左下角入口池展示。
function ActivityCenterBannerModule:showAutoPop(onFinish)
    if not self:canShowAutoPop() then
        safeRunCall(onFinish)
        return
    end

    local bannerData = self:getBannerData()
    if not bannerData then
        safeRunCall(onFinish)
        return
    end

    self:loadBannerUIRes(function()
        self:showAutoPopAfterResLoaded(bannerData, onFinish)
    end, onFinish)
end

-- banner UI 资源加载完成后进入实际展示流程。
function ActivityCenterBannerModule:showAutoPopAfterResLoaded(bannerData, onFinish)
    self:showBannerInLeftPool(bannerData, onFinish)
end

-- 本地测试按钮入口：没有真实候选时使用测试图兜底，只用于看样式。
function ActivityCenterBannerModule:testShowAutoPop()
    local bannerData = self:getBannerData() or self:getTestBannerData()
    self:loadBannerUIRes(function()
        self:showBannerInLeftPool(bannerData)
    end, function()
        CommonTip:showTip("资讯福利站banner资源下载失败")
    end)
end

-- 构造测试数据；优先复用真实 banner 配置，没有配置时使用 testBanner。
function ActivityCenterBannerModule:getTestBannerData()
    for _, data in pairs(self.manager:getVisibleDatas() or {}) do
        local bannerData = data and data.activityCenterBanner
        if bannerData and bannerData.image and bannerData.image ~= "" then
            -- 测试按钮不传 recordKey，避免本地预览消耗正式 banner 的已弹记录。
            return self:buildBannerData(data, bannerData, nil)
        end
    end

    return {
        image = "amf/activity/activitycenter/texture/testBanner.png",
        name = "测试标题1111",
        actId = 30062,
        hasReward = self.manager:hasRewardByActId(30062),
    }
end

-- 通过 IconManager 间接展示 banner，避免 activitycenter middleware 依赖 icon feature 实现。
function ActivityCenterBannerModule:showBannerInLeftPool(bannerData, onFinish)
    local iconManager = _G.amfBean("IconManager")
    if not iconManager or not iconManager.showActivityCenterBanner then
        safeRunCall(onFinish)
        return false
    end

    local function finishOnce()
        if self._autoPopFinishCalled then return end
        self._autoPopFinishCalled = true
        safeRunCall(onFinish)
    end

    self._autoPopFinishCalled = false
    return iconManager:showActivityCenterBanner({
        bannerData = bannerData,
        onShown = function()
            self:recordBannerShown(bannerData and bannerData.recordKey)
        end,
        onClose = finishOnce,
        onClick = function()
            self.manager:showActivityCenterPanel(finishOnce)
        end,
    })
end

-- 加载 banner UI plist；当前只有一个资源文件，但保留列表结构便于扩展。
function ActivityCenterBannerModule:loadBannerUIRes(successCallback, failCallback)
    local files = { "amf/activity/activitycenter/texture/IPActBanner.plist" }
    if table.isEmpty(files) then
        safeRunCall(successCallback)
        return
    end

    _G.amfBean("AssetsUtil"):loadMiniFiles(files, true):next(function()
        safeRunCall(successCallback)
    end, function()
        safeRunCall(failCallback)
    end)
end

-- 判断活动新字是否未被永久记录过；只有未展示过的新活动才参与 banner 候选。
function ActivityCenterBannerModule:canShowNewActFlag(info)
    if not info or not info.hasNew or not info.newActKey then return false end
    return self:canShowNewActFlagByKey(info.newActKey, info.data and info.data.actId)
end

function ActivityCenterBannerModule:canShowNewActFlagByKey(newActKey, actId)
    if not newActKey then return false end
    local showNum = _G.amfBean("AutoPopupMgr"):getPermanentShowNum(newActKey)
    return showNum < 1
end

-- 判断活动配置里是否有可用于 banner 展示的图片。
function ActivityCenterBannerModule:hasBannerConfig(data)
    local bannerData = data and data.activityCenterBanner
    return bannerData and bannerData.image and bannerData.image ~= ""
end

-- 获取活动开始时间作为候选排序依据；缺失时兜底 0，避免 nil 比较。
function ActivityCenterBannerModule:getDataBeginTime(data)
    if data and data.getBeginTime then
        return data.getBeginTime() or 0
    end
    return 0
end

-- 将活动数据包装为 banner 候选需要的新活动 info。
function ActivityCenterBannerModule:buildNewActInfo(data)
    if not data or not data.actId then return nil end
    return {
        hasNew = true,
        data = data,
        newActKey = tostring(data.actId),
    }
end

-- 从当前可见福利站活动中挑最新的、带 banner 图且新字未展示过的候选。
function ActivityCenterBannerModule:getAutoPopCandidateInfo()
    local candidateInfo
    for _, data in pairs(self.manager:getVisibleDatas() or {}) do
        if self:hasBannerConfig(data) then
            local info = self:buildNewActInfo(data)
            if self:canShowNewActFlag(info) then
                if not candidateInfo or self:getDataBeginTime(data) > self:getDataBeginTime(candidateInfo.data) then
                    candidateInfo = info
                end
            end
        end
    end
    return candidateInfo
end

-- 刷新 banner 候选；主动从缓存挑选，避免已展示过的新活动覆盖可弹候选。
function ActivityCenterBannerModule:scheduleUpdateCandidate()
    local candidateInfo = self:getAutoPopCandidateInfo()
    if not candidateInfo then
        self._updateCandidateSeq = (self._updateCandidateSeq or 0) + 1
        self:updateCandidate(nil, false)
        return
    end

    self._updateCandidateSeq = (self._updateCandidateSeq or 0) + 1

    local seq = self._updateCandidateSeq
    local pendingInfo = self:cloneNewActInfo(candidateInfo)

    setTimeOut(function()
        if seq ~= self._updateCandidateSeq then return end
        self:updateCandidate(pendingInfo, true)
    end, ActivityCenterBannerModule.UPDATE_CANDIDATE_DELAY)
end

-- 复制候选关键字段，防止延迟期间原 info 被外部复用或改写。
function ActivityCenterBannerModule:cloneNewActInfo(info)
    if not info then return nil end
    return {
        hasNew = info.hasNew,
        data = info.data,
        newActKey = info.newActKey,
    }
end

-- 写入或清空当前 banner 候选，并在活动资源未加载时触发加载。
function ActivityCenterBannerModule:updateCandidate(info, canShowNewActFlag)
    if not canShowNewActFlag or not info or not info.hasNew or not info.data then
        self.bannerCandidateActId = nil
        self.bannerCandidateNewActKey = nil
        self.bannerCandidateData = nil
        self.loadingCandidateActId = nil
        return
    end

    local oldActId = self.bannerCandidateActId
    self.bannerCandidateActId = info.data.actId
    self.bannerCandidateNewActKey = info.newActKey
    self.bannerCandidateData = info.data
    if oldActId ~= self.bannerCandidateActId then
        self.loadingCandidateActId = nil
    end

    self:loadCandidateResIfNeeded()
    self:tryAddAutoPop()
end

-- 候选活动资源缺失时发起加载；若本轮场景检查已过，则等待下一次强弹检查。
function ActivityCenterBannerModule:loadCandidateResIfNeeded()
    local actId = self.bannerCandidateActId
    if not actId then return end
    if self:isCandidateResReady(actId) then
        self.loadingCandidateActId = nil
        return
    end
    if self.loadingCandidateActId == actId then
        return
    end

    self.loadingCandidateActId = actId
    self.manager:loadActivityRes(actId, function()
        self.loadedCandidateActIdMap[tostring(actId)] = true
        if self.loadingCandidateActId == actId then
            self.loadingCandidateActId = nil
        end
    end, function()
        if self.loadingCandidateActId == actId then
            self.loadingCandidateActId = nil
        end
    end)
end

-- 判断候选资源是否已可用；福利站加载成功不会回写 ActivityNode 状态，这里用本模块缓存兜底。
function ActivityCenterBannerModule:isCandidateResReady(actId)
    if not actId then return false end
    if self.manager._activityMgr:isActResLoaded(actId) then
        return true
    end

    local data = self:getCandidateData()
    if data and data.panelCls then
        return true
    end

    return self.loadedCandidateActIdMap[tostring(actId)] == true
end

-- 按候选 actId 读取最新活动数据；找不到时使用延迟前缓存的数据。
function ActivityCenterBannerModule:getCandidateData()
    local actId = self.bannerCandidateActId
    if not actId then return nil end

    local datas = self.manager:getVisibleDatas()
    return datas and datas[tostring(actId)] or self.bannerCandidateData
end

-- 组装 banner 展示数据，并过滤缺少图片的活动。
function ActivityCenterBannerModule:getBannerData()
    local data = self:getCandidateData()
    local bannerData = data and data.activityCenterBanner
    if not bannerData or not bannerData.image or bannerData.image == "" then return nil end
    return self:buildBannerData(data, bannerData, self:getBannerRecordKey())
end

-- 统一组装 banner 展示数据；recordKey 固化本次展示记录，避免异步期间候选切换后记错活动。
function ActivityCenterBannerModule:buildBannerData(data, bannerData, recordKey)
    return {
        image = self:normalizeBannerImagePath(bannerData.image),
        name = bannerData.name or "",
        actId = data.actId,
        hasReward = self.manager:hasRewardByActId(data.actId),
        recordKey = recordKey,
    }
end

-- 兼容配置里省略 activity/ 前缀的图片路径。
function ActivityCenterBannerModule:normalizeBannerImagePath(image)
    if string.starts(image, "activity/") then return image end
    return "activity/" .. image
end

-- 生成单活动 banner 已弹记录 key，默认使用当前候选的新字 key。
function ActivityCenterBannerModule:getBannerRecordKey(newActKey)
    local key = newActKey or self.bannerCandidateNewActKey
    if not key then return nil end
    return tostring(key) .. ActivityCenterBannerModule.BANNER_RECORD_SUFFIX
end

-- 判断当前候选 banner 是否已经真实展示过。
function ActivityCenterBannerModule:hasShownBanner()
    local key = self:getBannerRecordKey()
    if not key then return true end
    local shownMap = self:getShownBannerMap()
    return shownMap[key] == true
end

-- 记录本次 banner 已展示；recordKey 来自展示前冻结的 bannerData，不能再回读当前候选。
function ActivityCenterBannerModule:recordBannerShown(recordKey)
    if recordKey then
        local shownMap = self:getShownBannerMap()
        shownMap[recordKey] = true
        self.manager:setLocalCache(ActivityCenterBannerModule.BANNER_RECORD_CACHE_KEY, shownMap)
    end
end

-- 读取本地已弹记录表，缓存异常时兜底为空表。
function ActivityCenterBannerModule:getShownBannerMap()
    local shownMap = self.manager:getLocalCache(ActivityCenterBannerModule.BANNER_RECORD_CACHE_KEY)
    if type(shownMap) ~= "table" then
        shownMap = {}
    end
    return shownMap
end

return ActivityCenterBannerModule
