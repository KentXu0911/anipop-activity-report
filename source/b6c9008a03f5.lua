local CommonFunc = require("amf.feature.fulllevel.starwandbuff.module.CommonFunc")
local IStarBuffWandModule = require("amf.feature.fulllevel.starwandbuff.module.IStarBuffWandModule")
local Const = require("amf.feature.localactivity.luckyfarmstar.const.Const")
local Module = class("LuckyFarmStarWandModule").implement(IStarBuffWandModule)

local FARM_LEVEL_PANEL_BG_WIDTH = 474
local FARM_LEVEL_PANEL_BG_HEIGHT = 290.2

local otherPartBuilder

local function getOtherPartBuilder()
    if not otherPartBuilder then
        local UIBuilder = require "amf.middleware.ui.export.UIBuilder"
        local uiData = require "amf.feature.localactivity.luckyfarmstar.view.uisource.OtherPartNode_UI"
        otherPartBuilder = UIBuilder.new(uiData)
    end
    return otherPartBuilder
end

local function countRecommendLevels(recommendLevels)
    local count = 0
    for _, levelIds in pairs(recommendLevels or {}) do
        count = count + #levelIds
    end
    return count
end

function Module:isOpen()
    return _G.amfBean("LuckyFarmStarManager"):isStarWandBonusEnabled()
end

function Module:getKey()
    return Const.ACTIVITY_KEY
end

function Module:getPriority()
    local Priority = require("amf.feature.fulllevel.starwandbuff.model.Priority")
    return Priority[self:getKey()] or 0
end

function Module:getRecommendMaxNum()
    -- TODO(lucky_farm_star_ui): UI 资源交付后按活动配置数量补充未推荐状态展示。
    local manager = _G.amfBean("StarWandBuffManager")
    local recommendLevels = manager and manager:getModel():getRecommendLevelsByKey(self:getKey()) or {}
    return countRecommendLevels(recommendLevels)
end

function Module:getRecommendNum()
    return _G.amfBean("LuckyFarmStarManager"):getScepterNum()
end

function Module:getPerLevelTime()
    return 3
end

function Module:doRecommendLevels(excludeLevels, silent, successCallback, failCallback)
    CommonFunc:recommendAdditionLevelsProcess(self, excludeLevels, silent, successCallback, failCallback)
end

function Module:onBeforeStartLevel(config)
end

function Module:onStarWandBuffReady()
    if not self:isOpen() then return end
    _G.amfBean("StarWandBuffManager"):tryRecommendLevelByKey(self:getKey(), true)
end

function Module:getOpenActivityFunc()
    -- TODO(lucky_farm_star_ui): UI 资源交付后补充活动跳转。
    return nil
end

function Module:getReachIndex()
    -- TODO(lucky_farm_star_ui): UI 资源交付后补充未领取和未解锁状态。
    return 0
end

function Module:decorateFarmStarPanelFlowerNode(node)
    if not node then return end
    local present = getOtherPartBuilder():createChild("present")
    if present then
        present:addToParent(node)
        present:setPositionXY(11, 93)
    end
end

function Module:createFarmStarPanelTip(onCountDownStop)
    if not self:isOpen() then return nil end

    local content = getOtherPartBuilder():createChild("contentText")
    if not content then return nil end

    local manager = _G.amfBean("LuckyFarmStarManager")
    content:setString(string.format(
        "活动期间\n权杖每日幸运增加 <color=#E96B33FF>%d</color><color=#7CFF21FF> </color>关",
        manager:getScepterNum()
    ))

    local countDown = getOtherPartBuilder():createChild("countDown")
    if countDown then
        countDown:setOnStopCallback(function()
            safeRunCall(onCountDownStop)
        end)
        countDown:setLeftTime(math.max(0, manager:getEndTimeInSec() - TimeKit:timeInSec()))
    end
    local tip = UITip.Builder.new()
        :setContent(content, true)
        :setSkin(UITip.SkinType.NPC)
        :setAutoCloseTime(0)
        :setDirection(UITip.Direction.RIGHT)
        :buildSingleTip()
    tip:addChild(countDown)
    countDown:setPositionXY(185, 60)
    return tip
end

function Module:getFarmLevelPanelParams()
    return {
        assetList = {},
        bgCreator = function()
            local bg = Layer:create()
            bg:changeWidthAndHeight(FARM_LEVEL_PANEL_BG_WIDTH, FARM_LEVEL_PANEL_BG_HEIGHT)
            return bg
        end,
        farmStarPanelFlowerNodeDecorator = function(node)
            self:decorateFarmStarPanelFlowerNode(node)
        end,
        farmPanelTipCreator = function(onCountDownStop)
            return self:createFarmStarPanelTip(onCountDownStop)
        end,
    }
end

return Module
