
require "amf.middleware.data.userdata.levelarea.config.UserStateConst"
local UserStateManager = class("UserStateManager")

function UserStateManager:ctor()
    self.userLevelState = _G.UserStateConst.UserLevelState.NONE
    self.mainStarFull = false
    self.hideStarFull = false
    self.colorfulStarFull = false

    self.hasInit = false
    self._userManager = nil
    self._levelAreaManager = nil
    self._fullStarLevelLibManager = nil
end

function UserStateManager:setLevelAreaManager(levelAreaManager)
    self._levelAreaManager = levelAreaManager
end

function UserStateManager:setFullStarLevelLibManager(fullStarLevelLibManager)
    self._fullStarLevelLibManager = fullStarLevelLibManager
end

function UserStateManager:setUserManager(userManager)
    self._userManager = userManager
end

function UserStateManager:initialize()
    -- TODO @xiaomeng.wang 成就的
    -- Notify:register("AchiEventUserDataUpdate", self.updateUserState, self)
    self:updateUserState()
    _G.amfEC:registerNormal(NormalEvent.USER_TOP_LEVEL_CHANGED, self.updateUserState, self)
    _G.amfEC:registerNormal(NormalEvent.PLAY_LEVEL_END, self.updateUserState, self)
end

-- TODO 以下事件需要刷新状态
-- function UserStateManager:onActBackFromFAQ()
--     ClipBoardUtil:reset()
-- end

-- function UserStateManager:onActPassLevel(data)
-- 	self:updateUserState()
-- end

-- function UserStateManager:onActAFHSuccess(data)
-- 	self:updateUserState()
-- end

-- function UserStateManager:onActAIHelpSuccess(data)
--     self:updateUserState()
-- end

-- function UserStateManager:onActJumpLevelSuccess(data)
-- 	self:updateUserState()
-- end

-- function UserStateManager:onActFixLevelStar(data)
--     self:updateUserState()
-- end

-- function UserStateManager:onActOnlineUnlockOver(data)
--     self:updateUserState()
-- end

--这里的状态 是本地的满级满星状态 （有没有更新到新关是不同的）
function UserStateManager:updateUserState()
    local oldUserState = self.userLevelState
	self.userLevelState, self.mainStarFull, self.hideStarFull, self.colorfulStarFull = self:getUserLevelInfo()

    if oldUserState ~= _G.UserStateConst.UserLevelState.NONE and oldUserState ~= self.userLevelState then
        _G.amfEC:notifyFeature(FeatureEvent.USER_LEVEL_STATE_CHANGED, {
            oldUserState = oldUserState,
            newState = self.userLevelState,
            segmentState = self:getUserSegmentState(),
        })
    end
end

function UserStateManager:getUserLevelInfo(specifiedFullStar, specifiedFullLevel)
	local userState = _G.UserStateConst.UserLevelState.NONE
    local _levelUnLockManager = _G.amfBean("LevelUnLockManager")
    local configTopLevel = _levelUnLockManager:getLocalTopLevel(true)
    local totalHiddenStar = _levelUnLockManager:getFullStarInHiddenRegion(true)
    local totalTopStar = LevelConfigBridge:getTotalStar(configTopLevel)

    local userStarMain = self._userManager:getStar()

    local mainStarFull = false
    local hideStarFull = false
    local colorfulStarFull = false
    if userStarMain >= totalTopStar then
        mainStarFull = true
    end

    local userStarHide = self._userManager:getHiddenStar()
    if userStarHide >= totalHiddenStar then
        hideStarFull = true
    end

    local userColorfulStar = self._userManager:getColorfulStar()
    local serverTopLevel = specifiedFullLevel or configTopLevel
    local totalColorfulStar = LevelConfigBridge:getTotalMainColorStar(serverTopLevel)

    if userColorfulStar >= totalColorfulStar then
        colorfulStarFull = true
    end

    local topPassedLevelId = self._levelAreaManager:getTopPassedMainLevelId()
    local configFullStar = specifiedFullStar or (totalTopStar + totalHiddenStar)
    local userFullStar = userStarMain + userStarHide

    if topPassedLevelId >= serverTopLevel then --满级
        if userFullStar >= configFullStar and colorfulStarFull then
	        userState = _G.UserStateConst.UserLevelState.TOP_STAR
        else
            userState = _G.UserStateConst.UserLevelState.TOP_LEVEL
        end
    else
    	userState = _G.UserStateConst.UserLevelState.NORMAL
    end

    return userState, mainStarFull, hideStarFull, colorfulStarFull
end

function UserStateManager:tryInit()
    if self.hasInit then return end
    self.hasInit = true
    self:updateUserState()
end

-- levelState
function UserStateManager:getUserLevelState()
    self:tryInit()
    return self.userLevelState
end

-- 细分状态，关卡外一般用这个
function UserStateManager:getUserSegmentState()
    self:tryInit()
    local state
    if self:isFMJ() then
        state = _G.UserStateConst.UserSegmentState.FMJ
    elseif not self:isMainStarFull() then
        state = _G.UserStateConst.UserSegmentState.FMH
    elseif not self:isColorfulStarFull() then
        state = _G.UserStateConst.UserSegmentState.FMC
    elseif not self:isHideStarFull() then
        state = _G.UserStateConst.UserSegmentState.FMZ
    else
        state = _G.UserStateConst.UserSegmentState.MHZC
    end
	return state
end

--黄星满
function UserStateManager:isMainStarFull()
    self:tryInit()
    return self.mainStarFull
end

--紫星满
function UserStateManager:isHideStarFull()
    self:tryInit()
    return self.hideStarFull
end

--彩星满
function UserStateManager:isColorfulStarFull()
    self:tryInit()
    return self.colorfulStarFull
end

--非满级
function UserStateManager:isFMJ()
    self:tryInit()
    return self.userLevelState == _G.UserStateConst.UserLevelState.NORMAL
end

function UserStateManager:getGoToLevelStr(mainStr, fullLevelStr)
    local mainLevelStr
    local userState = self:getUserSegmentState()
    if userState == _G.UserStateConst.UserSegmentState.FMJ then
        mainLevelStr = mainStr or "去主线关"
    elseif userState == _G.UserStateConst.UserSegmentState.MHZC then
        if self._fullStarLevelLibManager:canPlay() then
            mainLevelStr = "去闯关"
        else
            mainLevelStr = "去刷分"
        end
    else
        if self._fullStarLevelLibManager:canPlay() then
            mainLevelStr = "去闯关"
        else
            mainLevelStr = fullLevelStr or "去补星"
        end
    end
    return mainLevelStr
end

return UserStateManager
