local Meta = require "amf.feature.localactivity.eliminatefestival2026comic.config.EliminateFestival2026ComicMeta"

local EliminateFestival2026ComicDC = require"amf.feature.localactivity.eliminatefestival2026comic.dc.EliminateFestival2026ComicDC"

-- 2026消除节联动漫画包内管理器。
-- 不走活动工程动态活动链路，只负责主工程强弹注册、一次性标记和打开漫画面板。
local Manager = class("EliminateFestival2026ComicManager")

function Manager:initialize()
    self.dc = EliminateFestival2026ComicDC.new()
end

function Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
    self:_registerAutoPopup()
end

function Manager:setServerCacheManager(serverCacheManager)
    self.serverCacheManager = serverCacheManager
end

function Manager:_registerAutoPopup()
    if not self.autoPopupMgr then return end

    require "amf.middleware.autopop.config.AutoPopupConst"
    local popStage = AutoPopupConst.PopStage

    -- 场景2放在 Activity 类型第一，场景4放在 Condition 类型第一；
    -- 两个 checkPoint 共用同一个 GuideFlag，确保任一场景成功展示后另一场景不再弹。
    self.autoPopupMgr:registerPopup({
        checkPoint = PopupCheckPoint.ELIMINATE_FESTIVAL_2026_COMIC_STAGE2,
        stages = { popStage.STAGE_TWO },
        check = function()
            if self:isDebugForceStage2Popup() then
                return true
            end
            return self:canAutoPopup()
        end,
        creator = function(_, onPopOver)
            return function()
                -- 需求口径：展示过程中闪退也算成功展示，因此面板打开前立即写标记。
                self:_markDisplayed()
                self:openComicPanel(onPopOver)
            end
        end,
    })

    self.autoPopupMgr:registerPopup({
        checkPoint = PopupCheckPoint.ELIMINATE_FESTIVAL_2026_COMIC_STAGE4,
        stages = { popStage.STAGE_FOUR },
        check = function()
            if self:isDebugForceStage2Popup() then
                return true
            end
            return self:canAutoPopup()
        end,
        creator = function(_, onPopOver)
            return function()
                -- 需求口径：展示过程中闪退也算成功展示，因此面板打开前立即写标记。
                self:_markDisplayed()
                self:openComicPanel(onPopOver)
            end
        end,
    })
end

function Manager:canAutoPopup()
    local inTime = self:isInActivityTime()
    
    local passLevel = _G.amfBean("LevelAreaManager"):getTopPassedLevel()
    local levelEnough = not (passLevel < Meta.OPEN_LEVEL)
    local displayed = self:hasDisplayed()
    local ignoredForTopLevelPlayer = self:isIgnoredForTopLevelPlayer()

    if not inTime then return false end
    if not levelEnough then return false end
    if displayed then return false end
    if ignoredForTopLevelPlayer then return false end
    return true
end

function Manager:isIgnoredForTopLevelPlayer()
    -- local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    -- if userState == _G.UserStateConst.UserLevelState.MHZC then
    --     return false
    -- end

    -- local topLevelId = _G.getTopLevelId()
    -- if not _G.amfBean("LevelUnLockManager"):isTopNewMainLevel(topLevelId) then
    --     return false
    -- end

    if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then
        return false
    end

    return true
end

function Manager:isDebugForceStage2Popup()
    if not Meta.DEBUG_FORCE_STAGE2_POPUP then return false end
    if not EnvUtil or not EnvUtil.isDevelopMode then return false end
    -- return EnvUtil:isDevelopMode()
    return false
end

function Manager:isInActivityTime()
    local now = TimeKit:timeInSec()
    return now >= Meta.START_TIME and now <= Meta.END_TIME
end

function Manager:hasDisplayed()
    if not self.serverCacheManager then
        self.serverCacheManager = _G.amfBean("ServerCacheManager")
    end
    if not self.serverCacheManager then return false end
    return self.serverCacheManager:hasGuideFlag(Meta.GUIDE_FLAG)
end

function Manager:_markDisplayed()
    if not self.serverCacheManager then
        self.serverCacheManager = _G.amfBean("ServerCacheManager")
    end
    if self.serverCacheManager and not self:hasDisplayed() then
        self.serverCacheManager:setGuideFlag(Meta.GUIDE_FLAG)
    end
end

function Manager:openComicPanel(onClose)

    if EnvUtil:isDevelopMode() then
        CCDirector:sharedDirector():setDisplayStats(false)
    end

    local PanelVM = require "amf.feature.localactivity.eliminatefestival2026comic.view.EliminateFestival2026ComicPanelVM"
    local vm = PanelVM:create({
        closeCallback = onClose,
    })
    vm:popout(nil, nil, nil, Meta.DARK_OPACITY)
end

return Manager
