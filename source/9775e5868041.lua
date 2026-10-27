local BaseIcon = require "amf.feature.mainscene.module.icon.view.BaseIcon"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local NativeGameClubButton = require "amf.middleware.multiplatform.minigameadaptor.NativeGameClubButton"

local GameClubIcon = class("GameClubIcon", BaseIcon)

function GameClubIcon:create()
    local icon = GameClubIcon.new()
    icon:init()
    return icon
end

function GameClubIcon:dispose()
    IconEventCenter:unregister(IconEvent.ICON_POOL_EXPAND, self.showGameClubEntrance)
    IconEventCenter:unregister(IconEvent.ICON_POOL_SHRINK, self.hideGameClubEntrance)
    IconEventCenter:unregisterFeature(self)

    BaseIcon.dispose(self)
end

function GameClubIcon:init()
    BaseIcon.init(self, IconKey.kGameClub)
    self._serverCacheManager = _G.amfBean("ServerCacheManager")

    self:updateState()
    IconEventCenter:register(IconEvent.ICON_POOL_EXPAND, self.showGameClubEntrance, self)
    IconEventCenter:register(IconEvent.ICON_POOL_SHRINK, self.hideGameClubEntrance, self)
    IconEventCenter:registerFeature(self)
    self.needShowGuide = (_G.getTopLevelId() > 99) and not self._serverCacheManager:hasGuideFlag(GuideFlagConst.GameClubGuide)
end

function GameClubIcon:getIconSpriteFrameName()
    return "gamecircle"
end

function GameClubIcon:showGuide()
    self.needShowGuide = false
    self._serverCacheManager:setGuideFlag(GuideFlagConst.GameClubGuide)

    local HeGuide = require 'amf.middleware.ui.kit.component.HeGuide'
    local heGuide = HeGuide:create(nil, true, nil, nil, true)
    heGuide:addAccurateGuide(self.icon, { self })
    heGuide:setEndCall(function()
        self.heGuide = nil
        if self.cancelAutoPopup then
            self.cancelAutoPopup()
        end
    end)
    local contentList = {
        {ttf = "参与游戏圈讨论，超多福利等着你"},
    }
    heGuide:showNpc2(contentList, 80, nil, 0)
    self.heGuide = heGuide
end

function GameClubIcon:hideGameClubEntrance(event)
    if EnvUtil:isWindows() then return end
    if event:getData().poolType ~= IconMeta.PoolType.kLeftCorner then return end
    self:removeNativeButton()
end

function GameClubIcon:removeNativeButton()
    if self.nativeButton then
        self.nativeButton:destroy()
        self.nativeButton = nil
    end
end

function GameClubIcon:showGameClubEntrance(event)
    if EnvUtil:isWindows() then return end
    if event:getData().poolType ~= IconMeta.PoolType.kLeftCorner then return end
    if self.needShowGuide then
        self:showGuide()
    end
    
    self:removeNativeButton()
    
    self.nativeButton = NativeGameClubButton:create(self.icon, function()
        self:onTouch()
    end)
end

function GameClubIcon:onTouch()
    if self.isDisposed then return end

    MainSceneDC:onGameClubIconTapped()
    if self.heGuide and not self.heGuide.isDisposed then
        self.heGuide:removeGuide()
        self.heGuide = nil
    end
    IconEventCenter:dispatch(IconEvent.CLOSE_ICON_POOL, IconMeta.PoolType.kLeftCorner)

    local dayIdx = TimeUtil:getDayIdxSince1970()
    LocalDB:setInt("game_club_tapped", dayIdx)
    self:updateState()
end

function GameClubIcon:hasHint()
    if self.isDisposed then return end
    local dayIdx = TimeUtil:getDayIdxSince1970()
    local triggerTime = LocalDB:getInt("game_club_trigger_day", 0)

    if triggerTime == 0 then
        LocalDB:setInt("game_club_trigger_day", dayIdx)
        triggerTime = dayIdx
    end

    if triggerTime > 0 and (dayIdx - triggerTime) < 3 then
        local tappedTime = LocalDB:getInt("game_club_tapped", 0)
        return tappedTime < dayIdx
    end
end

function GameClubIcon:onActEnterStage2()
    if not self.needShowGuide then return end

    local function creator()
        self.cancelAutoPopup = _G.convert2ThrowawayFunction(function()
            AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.GAME_CLUB_GUIDE)

            if self.heGuide and not self.heGuide.isDisposed then
                self.heGuide:removeGuide()
                self.heGuide = nil
            end

        end, 5)

        IconEventCenter:dispatch(IconEvent.OPEN_ICON_POOL, IconMeta.PoolType.kLeftCorner)
    end
    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.GAME_CLUB_GUIDE, creator)
end

return GameClubIcon
