local UEPropIcon = require "amf.middleware.ui.export.widgets.prop.UEPropIcon"
local UEProgressMilestoneBuilder = require "amf.middleware.ui.export.widgets.progress.UEProgressMilestoneBuilder"

---@class MilestonePropIconPixelConfigDebug
local MilestonePropIconPixelConfigDebug = {}

local CAPTURE_WIDTH = 512
local CAPTURE_HEIGHT = 512
local DEFAULT_NUM = 10
local DEFAULT_CAPTURE_SCALE = 1
local DEFAULT_MILESTONE_SCALE = 0.4

-- 进度条三状态验证的固定参数：长度 1200、最大值 1000、可视区域 500、里程碑值 100。
-- 固定这些参数后，三张截图只随验证值变化，便于对比进度头相对里程碑的停靠位置。
local VERIFICATION_FIXED = {
    maxValue = 1000,
    progressWidth = 1200,
    scrollContainerWidth = 500,
    threshold = 100,
    positionX = 360,
    positionY = 500,
}

-- 三状态对应的验证值：前临界 95、里程碑 100、后临界 105。
local VERIFICATION_STATE_VALUES = {
    before = 95,
    milestone = 100,
    after = 105,
}

local function getCachePath(options)
    if options and options.cachePath then
        return options.cachePath
    end
    return HeResPathUtils:getUserDataPath() .. "/milestone_prop_icon_pixel_cache"
end

local function ensureDirectory(path)
    if HeFileUtils and HeFileUtils.mkdirs then
        HeFileUtils:mkdirs(path)
    end
end

local function removeDirectory(path)
    if path and path ~= "" and HeFileUtils and HeFileUtils.exists(path) then
        HeFileUtils:removeDir(path)
    end
end

local function writeText(path, content)
    local file = io.open(path, "w")
    if not file then
        return false
    end
    file:write(content)
    file:close()
    return true
end

-- 从真实 UEProgressMilestone 布局测量进度条与里程碑的相对 Y 区间。
local function resolveMilestoneProgressRoi(itemId, options)
    local scene = Director:sharedDirector():getRunningSceneLua()
    if not scene then
        return nil, "running scene unavailable"
    end
    local builder = UEProgressMilestoneBuilder.new()
        :setMaxValue(1000)
        :setValue(0)
        :setProgressWidth(options.progressWidth or 493)
        :setScrollContainerWidth(options.scrollContainerWidth or 493)
        :setScrollable(false)
        :setMilestoneConfig({
            autoClaim = true,
            milestonesList = {
                {
                    threshold = 500,
                    rewardConfig = { itemId = itemId, num = options.num or DEFAULT_NUM },
                },
            },
        })
    local success, probeOrError = pcall(function()
        return WidgetManager:createWidgetObj("UEProgressMilestone", builder)
    end)
    if not success or not probeOrError then
        return nil, tostring(probeOrError)
    end

    local probe = probeOrError
    scene:addChild(probe)
    local content = probe:_getContentNode()
    local progress = probe:_getProgressNode()
    local milestoneNode = probe:_getMilestoneNode(1)
    local progressBounds = progress and progress:getGroupBounds(content, true)
    local nodeBounds = milestoneNode and milestoneNode:getGroupBounds(content, true)
    local result
    if progressBounds and nodeBounds and progressBounds.origin and progressBounds.size
        and nodeBounds.origin and nodeBounds.size then
        local progressBottom = progressBounds.origin.y
        local progressTop = progressBounds.origin.y + progressBounds.size.height
        local nodeCenterY = nodeBounds.origin.y + nodeBounds.size.height * 0.5
        local sourceCenterY = CAPTURE_HEIGHT * 0.5
        -- manifest 保存运行时 scale=0.4 的坐标，Python 会映射回 scale=1 截图。
        result = {
            top = sourceCenterY + (progressTop - nodeCenterY),
            bottom = sourceCenterY + (progressBottom - nodeCenterY),
            scale = DEFAULT_MILESTONE_SCALE,
        }
        if result.top > result.bottom then
            result.top, result.bottom = result.bottom, result.top
        end
    end
    probe:removeFromParentAndCleanup(true)
    if not result then
        return nil, "milestone progress ROI unavailable"
    end
    return result
end

local function getItemIds(explicitItemIds)
    if type(explicitItemIds) == "table" then
        local ids = {}
        local seen = {}
        for _, itemId in ipairs(explicitItemIds) do
            itemId = tonumber(itemId)
            if itemId and itemId > 0 and not seen[itemId] then
                ids[#ids + 1] = itemId
                seen[itemId] = true
            end
        end
        return ids
    end

    -- 直接使用 items_config 数组顺序，保证批量配置输出可追溯。
    local itemConfig = require "zoo.config.meta.items_config"
    local ids = {}
    for _, row in ipairs(itemConfig or {}) do
        local itemId = row and tonumber(row.itemId)
        if itemId and itemId > 0 then
            ids[#ids + 1] = itemId
        end
    end
    return ids
end

local function getSceneRoot()
    local scene = Director:sharedDirector():getRunningSceneLua()
    if not scene then
        return nil, "running scene unavailable"
    end
    local root = Layer:create()
    if not root then
        return nil, "capture root creation failed"
    end
    scene:addChild(root)
    return root
end

-- 活动仓库目录名（各人本地路径不同，需动态查找；找不到则上报询问用户）
local ACTIVITY_REPO_DIR_NAME = "minigame-activity-development-cocos"
local g_activityRepoRoot = nil
local g_activityRepoResolved = false

local function pathIsDir(path)
    return path and path ~= "" and HeFileUtils and HeFileUtils.exists and HeFileUtils:exists(path)
end

-- 定位活动仓库根目录：优先用显式传入；否则从已知资源绝对路径逐级向上查找同级同名目录。
-- 找不到返回 nil，由上层记录 "activity repo not found, ask user"。
-- @param explicit string|nil 显式指定的活动仓库路径
-- @return string|nil 活动仓库根目录
local function resolveActivityRepoRoot(explicit)
    if explicit and explicit ~= "" and pathIsDir(explicit) then
        g_activityRepoRoot = explicit
        g_activityRepoResolved = true
        return g_activityRepoRoot
    end
    if g_activityRepoResolved then
        return g_activityRepoRoot
    end
    g_activityRepoResolved = true
    local probe = CCFileUtils:sharedFileUtils():fullPathForFilename("amf/uikit/image/base/common_item_icon256.plist")
    if probe and probe:sub(1, 1) == "/" then
        local dir = probe:gsub("/[^/]+$", "")
        for _ = 1, 12 do
            local parent = dir:gsub("/[^/]+$", "")
            if parent == dir or parent == "" then
                break
            end
            dir = parent
            local candidate = dir .. "/" .. ACTIVITY_REPO_DIR_NAME
            if pathIsDir(candidate) then
                g_activityRepoRoot = candidate
                return candidate
            end
        end
    end
    return nil
end

-- 确保 imageInfo 对应的纹理可用：图集未加载时先加载 plist，独立 png 则按路径加载。
-- 散图（png）不在运行时搜索路径时，回退到活动仓库查找；找不到则报错，交由上层询问用户。
-- 避免 setFrame 未命中时精灵保留空白纹理、渲染成 256x256 空白色块却仍被当成成功。
-- @param imageInfo table {Atlas, Frame, IsPropPng}
-- @return boolean ok 帧/纹理是否可用
-- @return string|nil reason 失败原因
local function ensureImageLoaded(imageInfo)
    if not imageInfo or not imageInfo.Frame or imageInfo.Frame == "" then
        return false, "empty image frame"
    end
    local frameCache = CCSpriteFrameCache:sharedSpriteFrameCache()
    if frameCache:spriteFrameByName(imageInfo.Frame) then
        return true
    end
    -- fullPathForFilename 命中真实文件时返回绝对路径，缺失时原样返回入参
    local fileUtils = CCFileUtils:sharedFileUtils()
    local function resolvedPath(path)
        local full = fileUtils:fullPathForFilename(path)
        if full and full ~= "" and full:sub(1, 1) == "/" then
            return full
        end
        return nil
    end
    local atlas = imageInfo.Atlas
    if atlas and atlas ~= "" and imageInfo.IsPropPng ~= true then
        -- 图集未加载：先确认真实存在，再加载 plist 并校验帧命中
        if not resolvedPath(atlas) then
            return false, "atlas file not found: " .. tostring(atlas)
        end
        frameCache:addSpriteFramesWithFile(atlas)
        if frameCache:spriteFrameByName(imageInfo.Frame) then
            return true
        end
        return false, "atlas loaded but frame not found: " .. tostring(imageInfo.Frame)
    end
    -- 独立 png：缺失时 addImage 会返回 32x32 占位图，必须先定位真实文件
    local pngPath = resolvedPath(imageInfo.Frame)
    if not pngPath then
        -- 回退活动仓库：activity/<act>/... 或 amf/activity/<act>/... -> <repo>/<act>/...
        local rel = tostring(imageInfo.Frame):gsub("^amf/activity/", ""):gsub("^activity/", "")
        local repoRoot = resolveActivityRepoRoot()
        local candidate = repoRoot and (repoRoot .. "/" .. rel) or nil
        if not pathIsDir(candidate) then
            if not repoRoot then
                return false, "activity repo not found, ask user (dir: " .. ACTIVITY_REPO_DIR_NAME .. ")"
            end
            return false, "loose png not found (runtime & activity repo): " .. tostring(imageInfo.Frame)
        end
        pngPath = candidate
        -- 渲染时必须用绝对路径，否则 Image:setFrame 仍按相对路径找不到文件
        imageInfo.Frame = candidate
        imageInfo.__renderDirect = true
    end
    local texture = CCTextureCache:sharedTextureCache():addImage(pngPath)
    if not texture then
        return false, "addImage failed: " .. tostring(pngPath)
    end
    return true
end

-- 复用 PropManager:getItemAttr 的 isSupported 语义判断图标是否异常。
-- getItemAttr 在普通道具找不到图片时会走 getUnknownItemImage 兜底并置 isSupported=false，
-- 此时 UEPropIcon 仍能成功创建但渲染的是“错误道具”占位图，像素补偿无意义，应记为失败项。
-- @param itemId integer 道具 ID
-- @return boolean ok 图标是否可正常解析
-- @return string|nil reason 异常原因
-- @return table|nil imageInfo 命中后的图片信息 {Atlas, Frame, IsPropPng}
local function checkItemSupported(itemId)
    -- 与 UEItemConvertor:setItemId 保持一致：先加载通用道具图集，避免 plist 帧查找遗漏
    local commonDefine = _G.CommonDefine
    if commonDefine and commonDefine.loadItemCommonPlist then
        commonDefine.loadItemCommonPlist()
    end
    local propMgr = _G.amfBean and _G.amfBean("PropManager")
    if not propMgr then
        return false, "PropManager unavailable"
    end
    local ok, attr = pcall(function()
        return propMgr:getItemAttr(itemId)
    end)
    if not ok then
        return false, "getItemAttr error: " .. tostring(attr)
    end
    if not attr then
        return false, "getItemAttr returned nil"
    end
    if attr.isSupported == false then
        return false, "icon unsupported (getUnknownItemImage fallback), itemId=" .. tostring(itemId)
    end
    -- 新增：确认纹理/图集已加载并命中帧，未命中视为异常，避免采集到空白色块
    local imageInfo = attr.image
    if imageInfo then
        local loaded, loadReason = ensureImageLoaded(imageInfo)
        if not loaded then
            return false, "image frame not resolved: " .. tostring(imageInfo.Frame) .. " (" .. tostring(loadReason) .. ")"
        end
    end
    return true, nil, imageInfo
end

---判断道具是否需要传递 num：只有无限道具和限时道具需要。
---无限道具用数量换算剩余时间，限时道具展示限时标签；普通道具传 num 会多出数量角标，
---污染图标像素边界，因此不传。
---@param itemId integer 道具 ID
---@return boolean needNum 是否需要数量
local function shouldPassNum(itemId)
    local propMgr = _G.amfBean and _G.amfBean("PropManager")
    if not propMgr then
        return true
    end
    if propMgr:isInfiniteProp(itemId) or propMgr:isInfiniteTodayProp(itemId) then
        return true
    end
    return propMgr:isTimeLimitProp(itemId) == true
end

-- 动态图标兜底（RESOLVE_ICON 类）：部分道具 icon 由活动监听提供，但监听在活动未初始化时会抛错
-- （如 MergeManager 里 self:getData():getCurWeek()）。这里按监听同源配表直接取图，绕开 getData()。
-- @param itemId integer 道具 ID
-- @return table|nil imageInfo {Atlas, Frame, IsPropPng}
local function resolveDynamicImage(itemId)
    local BoardMeta = require "amf.feature.localactivity.merge.config.BoardMeta"
    if not table.exist(BoardMeta:getAllItemList(), itemId) then
        return nil
    end
    local atlas = BoardMeta.BoardItemsPlistPath
    local frame = BoardMeta:getMergeItemSpName(itemId)
    if not frame or frame == "" then
        return nil
    end
    -- 图集可能尚未加载，先保证 frame 命中
    local frameCache = CCSpriteFrameCache:sharedSpriteFrameCache()
    if atlas and atlas ~= "" and not frameCache:spriteFrameByName(frame) then
        frameCache:addSpriteFramesWithFile(atlas)
    end
    return { Atlas = atlas or "", Frame = frame, IsPropPng = false }
end

local function captureIcon(itemId, options, cachePath)
    -- 图标异常（走 getUnknownItemImage 兜底）直接记为失败，避免产出占位图的无意义补偿
    local supported, reason, imageInfo = checkItemSupported(itemId)
    local customImage = nil
    if not supported then
        -- RESOLVE_ICON 类动态图标失败时，按同源配表直接取图（方案 B），仍无法取到才记失败
        local dynamicImage = resolveDynamicImage(itemId)
        if not dynamicImage then
            return nil, reason
        end
        local loaded, loadReason = ensureImageLoaded(dynamicImage)
        if not loaded then
            return nil, "dynamic image frame not resolved: " .. tostring(dynamicImage.Frame) .. " (" .. tostring(loadReason) .. ")"
        end
        customImage = dynamicImage
    elseif imageInfo and imageInfo.__renderDirect then
        -- 散图定位到活动仓库等非运行时路径时，直接按绝对路径设图
        customImage = imageInfo
    end

    local root, rootError = getSceneRoot()
    if not root then
        return nil, rootError
    end

    local icon
    local success, result = xpcall(function()
        icon = UEPropIcon.create()
        if not icon then
            error("UEPropIcon.create returned nil")
        end

        -- 截图不设置外层 scale；UEPropIcon 内部资源适配逻辑仍按正常流程执行。
        if customImage then
            -- 动态图标 / 散图：直接设图，绕开 itemId → getItemAttr → RESOLVE_ICON 链路
            icon:setItemImage(customImage)
        else
            -- 只有无限/限时道具才传 num，普通道具不传数量角标，避免影响像素边界测量。
            local itemData = { itemId = itemId }
            if shouldPassNum(itemId) then
                itemData.num = options.num or DEFAULT_NUM
            end
            icon:setItem(itemData)
        end
        -- 采集图标统一使用已领取(Claimed)状态，与里程碑图标的展示状态保持一致。
        if icon.setRewardState and _G.UEPropIcon_RewardState then
            icon:setRewardState(_G.UEPropIcon_RewardState.Claimed)
        end
        root:addChild(icon)

        local bounds = icon:getGroupBounds(root, true)
        if not bounds or not bounds.origin or not bounds.size
            or bounds.size.width <= 0 or bounds.size.height <= 0 then
            error("icon bounds unavailable")
        end

        local boundsCenterX = bounds.origin.x + bounds.size.width * 0.5
        local boundsCenterY = bounds.origin.y + bounds.size.height * 0.5
        icon:setPositionXY(
            icon:getPositionX() + CAPTURE_WIDTH * 0.5 - boundsCenterX,
            icon:getPositionY() + CAPTURE_HEIGHT * 0.5 - boundsCenterY
        )

        local renderTexture = CCRenderTexture:create(
            CAPTURE_WIDTH,
            CAPTURE_HEIGHT,
            kCCTexture2DPixelFormat_RGBA8888
        )
        if not renderTexture then
            error("CCRenderTexture:create returned nil")
        end
        renderTexture:beginWithClear(0, 0, 0, 0, 0)
        icon:visit()
        renderTexture:endToLua()

        local imagePath = cachePath .. "/item_" .. tostring(itemId) .. ".png"
        if not renderTexture:saveToFile(imagePath) then
            error("saveToFile failed: " .. imagePath)
        end
        if renderTexture.dispose then
            renderTexture:dispose()
        end

        return {
            itemId = itemId,
            imagePath = imagePath,
            captureScale = DEFAULT_CAPTURE_SCALE,
            centerX = CAPTURE_WIDTH * 0.5,
            centerY = CAPTURE_HEIGHT * 0.5,
            progressTop = options.progressTop,
            progressBottom = options.progressBottom,
        }
    end, function(errorMessage)
        return debug.traceback(tostring(errorMessage))
    end)

    if icon and not icon.isDisposed then
        icon:removeFromParentAndCleanup(true)
    end
    if root and not root.isDisposed then
        root:removeFromParentAndCleanup(true)
    end

    if not success then
        return nil, result
    end
    return result
end

-- 用 CCRenderTexture 只渲染进度条可视区域（ScrollContainer），不包含整屏背景。
-- @param progress UEProgressMilestone 验证组件
-- @param cachePath string 输出目录
-- @param itemId integer 道具 ID
-- @param state string 验证状态
-- @return string|nil imagePath 截图路径
-- @return string|nil errorMessage 错误信息
local function captureProgressBar(progress, cachePath, itemId, state)
    local scrollContainer = progress and progress:_getScrollContainer()
    if not scrollContainer then
        return nil, "scroll container unavailable"
    end
    local parent = progress:getParent()
    if not parent then
        return nil, "progress parent unavailable"
    end

    local size = scrollContainer:getContentSize()
    if size.width <= 0 or size.height <= 0 then
        return nil, "invalid scroll container size"
    end

    -- 让 ScrollContainer 可视区域左下角对齐渲染纹理原点，保证只截进度条区域。
    local scWorld = scrollContainer:convertToWorldSpace(ccp(0, 0))
    local scInParent = parent:convertToNodeSpace(scWorld)
    local parentOrigin = parent:convertToNodeSpace(ccp(0, 0))
    local offsetX = scInParent.x - parentOrigin.x
    local offsetY = scInParent.y - parentOrigin.y
    local originalX, originalY = progress:getPositionX(), progress:getPositionY()
    progress:setPositionXY(originalX - offsetX, originalY - offsetY)

    local renderTexture
    local success, result = xpcall(function()
        -- 进度条内部可能包含裁剪节点，使用带模板缓冲的渲染纹理避免裁剪失效。
        renderTexture = CCRenderTexture:create(
            size.width,
            size.height,
            kCCTexture2DPixelFormat_RGBA8888,
            0x88F0
        )
        if not renderTexture then
            error("CCRenderTexture:create returned nil")
        end
        renderTexture:beginWithClear(0, 0, 0, 0, 0)
        progress:visit()
        renderTexture:endToLua()

        local imagePath = cachePath .. "/progress_" .. tostring(itemId)
            .. "_" .. tostring(state) .. ".png"
        if not renderTexture:saveToFile(imagePath) then
            error("saveToFile failed: " .. imagePath)
        end
        return imagePath
    end, function(errorMessage)
        return debug.traceback(tostring(errorMessage))
    end)

    if renderTexture and renderTexture.dispose then
        renderTexture:dispose()
    end
    progress:setPositionXY(originalX, originalY)

    if not success then
        return nil, result
    end
    return result
end

local function serializeManifestRow(row)
    return table.concat({
        tostring(row.itemId),
        tostring(row.imagePath),
        tostring(row.captureScale),
        tostring(row.centerX),
        tostring(row.centerY),
        tostring(row.progressTop or ""),
        tostring(row.progressBottom or ""),
    }, "\t")
end

---检测指定 ItemId 的图标是否可正常解析（复用 PropManager:getItemAttr 的 isSupported 语义）。
---走到 getUnknownItemImage 兜底即视为异常（未注册/资源缺失/动态解析失败）。
---@param itemId integer 道具 ID
---@return boolean ok 图标是否可正常解析
---@return string|nil reason 异常原因
function MilestonePropIconPixelConfigDebug:checkItemSupported(itemId)
    itemId = tonumber(itemId)
    if not itemId or itemId <= 0 then
        return false, "invalid itemId"
    end
    return checkItemSupported(itemId)
end

---创建指定 ItemId 的完整 UEPropIcon 截图。
---@param itemId integer 道具 ID
---@param options table|nil num、cachePath 等参数
---@return table|nil result 截图结果
---@return string|nil errorMessage 错误信息
function MilestonePropIconPixelConfigDebug:createByItemId(itemId, options)
    options = options or {}
    resolveActivityRepoRoot(options.activityRepoPath)
    itemId = tonumber(itemId)
    if not itemId or itemId <= 0 then
        return nil, "invalid itemId"
    end

    local cachePath = getCachePath(options)
    removeDirectory(cachePath)
    ensureDirectory(cachePath)
    return captureIcon(itemId, options, cachePath)
end

---按输入顺序分帧创建全部 ItemId，成功项和失败项分别记录。
---@param options table|nil itemIds、num、cachePath 等参数
---@return table task 任务启动状态
function MilestonePropIconPixelConfigDebug:createAll(options)
    options = options or {}
    resolveActivityRepoRoot(options.activityRepoPath)
    local cachePath = getCachePath(options)
    removeDirectory(cachePath)
    ensureDirectory(cachePath)

    local itemIds = getItemIds(options.itemIds)
    if options.roiMode == "milestone" and options.progressTop == nil
        and options.progressBottom == nil and itemIds[1] then
        local roi = resolveMilestoneProgressRoi(itemIds[1], options)
        if roi then
            options.progressTop = roi.top
            options.progressBottom = roi.bottom
            options.progressScale = roi.scale
        end
    end
    local task = {
        running = true,
        index = 1,
        total = #itemIds,
        itemIds = itemIds,
        successes = {},
        failures = {},
        cachePath = cachePath,
        options = options,
    }
    _G.__MilestonePropIconPixelConfigTask = task

    local function step()
        if not task.running then
            return
        end
        local itemId = task.itemIds[task.index]
        if itemId == nil then
            task.running = false
            local lines = {
                "itemId\timagePath\tcaptureScale\tcenterX\tcenterY\tprogressTop\tprogressBottom",
            }
            for _, row in ipairs(task.successes) do
                lines[#lines + 1] = serializeManifestRow(row)
            end
            writeText(cachePath .. "/manifest.tsv", table.concat(lines, "\n") .. "\n")
            writeText(cachePath .. "/failures.lua", table.serialize(task.failures))
            return
        end

        local result, errorMessage = captureIcon(itemId, task.options, cachePath)
        if result then
            task.successes[#task.successes + 1] = result
        else
            task.failures[#task.failures + 1] = {
                itemId = itemId,
                errorMessage = errorMessage,
                inputIndex = task.index,
            }
        end
        task.index = task.index + 1
        setTimeOut(step, 0)
    end
    setTimeOut(step, 0)

    return {
        started = true,
        total = task.total,
        cachePath = task.cachePath,
    }
end

---读取截图任务的轻量状态。
---@return table|nil status 任务状态
function MilestonePropIconPixelConfigDebug:getTask()
    local task = _G.__MilestonePropIconPixelConfigTask
    if not task then
        return nil
    end
    return {
        running = task.running,
        index = task.index,
        total = task.total,
        successCount = #task.successes,
        failureCount = #task.failures,
        cachePath = task.cachePath,
    }
end

---清理截图缓存。
---@param options table|nil cachePath
function MilestonePropIconPixelConfigDebug:clearCache(options)
    removeDirectory(getCachePath(options or {}))
end

---创建用于截图验证的真实 UEProgressMilestone。
---@param itemId integer 道具 ID
---@param beforePx number scale=1 的左侧补偿
---@param afterPx number scale=1 的右侧补偿
---@param value number 当前进度值
---@param options table|nil maxValue、threshold、scale、position 等参数
---@return table|nil result 验证组件信息
---@return string|nil errorMessage 错误信息
function MilestonePropIconPixelConfigDebug:createVerificationProgress(
    itemId,
    beforePx,
    afterPx,
    value,
    options
)
    options = options or {}
    local scene = Director:sharedDirector():getRunningSceneLua()
    if not scene then
        return nil, "running scene unavailable"
    end
    local oldProgress = _G.__MilestonePropIconPixelVerificationProgress
    if oldProgress and not oldProgress.isDisposed then
        oldProgress:removeFromParentAndCleanup(true)
    end

    local threshold = tonumber(options.threshold) or 500
    local maxValue = tonumber(options.maxValue) or 1000
    local milestoneScale = tonumber(options.milestoneScale) or DEFAULT_MILESTONE_SCALE
    local builder = UEProgressMilestoneBuilder.new()
        :setMaxValue(maxValue)
        :setValue(tonumber(value) or 0)
        :setProgressWidth(tonumber(options.progressWidth) or 900)
        :setScrollContainerWidth(tonumber(options.scrollContainerWidth) or 520)
        :setScrollable(false)
        :setMilestoneConfig({
            autoClaim = true,
            showMilestoneLabels = true,
            milestonesList = {
                {
                    threshold = threshold,
                    rewardConfig = {
                        itemId = itemId,
                        num = tonumber(options.num) or DEFAULT_NUM,
                    },
                    pixelCompensation = {
                        beforePx = (tonumber(beforePx) or 0) * milestoneScale,
                        afterPx = (tonumber(afterPx) or 0) * milestoneScale,
                    },
                },
            },
        })

    local success, progressOrError = pcall(function()
        return WidgetManager:createWidgetObj("UEProgressMilestone", builder)
    end)
    if not success or not progressOrError then
        return nil, tostring(progressOrError)
    end

    local progress = progressOrError
    -- 截图验证时关闭进度条描边图片透明度，避免描边干扰可视区域判断（默认 0）。
    if progress.setOutlineImageOpacity then
        progress:setOutlineImageOpacity(tonumber(options.outlineImageOpacity) or 0)
    end
    progress:setName("MilestonePropIconPixelVerification")
    progress:setPositionXY(
        tonumber(options.positionX) or 360,
        tonumber(options.positionY) or 500
    )
    scene:addChild(progress)
    _G.__MilestonePropIconPixelVerificationProgress = progress
    return {
        itemId = itemId,
        threshold = threshold,
        value = tonumber(value) or 0,
        beforePx = tonumber(beforePx) or 0,
        afterPx = tonumber(afterPx) or 0,
    }
end

---创建固定参数的里程碑进度条并按三状态截取进度条可视区域。
---固定进度条长度 1000、最大值 1000、可视区域 500、里程碑值 100；
---state 对应验证值：before=99、milestone=100、after=101。
---截图使用 CCRenderTexture 只渲染进度条可视区域，不包含整屏。
---@param itemId integer 道具 ID
---@param beforePx number scale=1 的左侧补偿
---@param afterPx number scale=1 的右侧补偿
---@param state string 验证状态："before"|"milestone"|"after"
---@param options table|nil cachePath 等参数
---@return table|nil result 验证结果，含 state、value、imagePath
---@return string|nil errorMessage 错误信息
function MilestonePropIconPixelConfigDebug:createVerificationProgressShot(
    itemId,
    beforePx,
    afterPx,
    state,
    options
)
    options = options or {}
    local value = VERIFICATION_STATE_VALUES[state]
    if not value then
        return nil, "invalid verification state: " .. tostring(state)
    end

    local result, errorMessage = self:createVerificationProgress(itemId, beforePx, afterPx, value, {
        threshold = VERIFICATION_FIXED.threshold,
        maxValue = VERIFICATION_FIXED.maxValue,
        progressWidth = VERIFICATION_FIXED.progressWidth,
        scrollContainerWidth = VERIFICATION_FIXED.scrollContainerWidth,
        positionX = VERIFICATION_FIXED.positionX,
        positionY = VERIFICATION_FIXED.positionY,
    })
    if not result then
        return nil, errorMessage
    end

    local cachePath = getCachePath(options)
    ensureDirectory(cachePath)
    local imagePath, shotError = captureProgressBar(
        _G.__MilestonePropIconPixelVerificationProgress,
        cachePath,
        itemId,
        state
    )
    if not imagePath then
        return nil, shotError
    end

    result.state = state
    result.value = value
    result.imagePath = imagePath
    return result
end

---销毁验证用里程碑进度条。
function MilestonePropIconPixelConfigDebug:clearVerificationProgress()
    local progress = _G.__MilestonePropIconPixelVerificationProgress
    if progress and not progress.isDisposed then
        progress:removeFromParentAndCleanup(true)
    end
    _G.__MilestonePropIconPixelVerificationProgress = nil
end

_G.MilestonePropIconPixelConfigDebug = MilestonePropIconPixelConfigDebug

return MilestonePropIconPixelConfigDebug
