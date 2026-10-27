require "amf.feature.weeklyrace.config.WeeklyRaceConst"
local WeeklyRaceModel = require "amf.feature.weeklyrace.model.WeeklyRaceModel"
local WeeklyRaceDC  = require "amf.feature.weeklyrace.dc.WeeklyRaceDC"
local WeeklyRaceLog = require "amf.feature.weeklyrace.WeeklyRaceLog"
local WeeklyRaceHttp = require "amf.feature.weeklyrace.http.WeeklyRaceHttp"
local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local WeeklyRaceIcon = require "amf.feature.mainscene.module.icon.view.iconbutton.WeeklyRaceIcon"

local WeeklyRaceManager = class("WeeklyRaceManager")

function WeeklyRaceManager.getWeeklyLabelAdjustStartTime()
    return os.time2(parseTime(_G.WeeklyRaceConst.WEEKLY_LABEL_ADJUST_START_TIME))
end

function WeeklyRaceManager.getWeeklyRace2020OfflineEndTime()
    return os.time2(parseTime(_G.WeeklyRaceConst.WEEKLY_RACE_2020_OFFLINE_END_TIME))
end

function WeeklyRaceManager.getWeeklyAdjustEndTime()
    return os.time2(parseTime(_G.WeeklyRaceConst.WEEKLY_ADJUST_END_TIME))
end

function WeeklyRaceManager.isActEnd()
    local curTime = TimeKit:timeInSec()
    if curTime > WeeklyRaceManager.getWeeklyRace2020OfflineEndTime() then
        return true
    end
    return false
end

function WeeklyRaceManager:ctor()
    self.icon = nil
end

function WeeklyRaceManager:initialize()
    self:registerEvent()
    self.model = WeeklyRaceModel:create()
    self.dc = WeeklyRaceDC.new()
    self.dc:setMgr(self)
end

function WeeklyRaceManager:registerEvent()
    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, self.onIconSystemReady, self)
    _G.amfEC:registerFeature(self)
end

function WeeklyRaceManager:onIconSystemReady()
    self:tryUpdateIcon()
end

function WeeklyRaceManager:isInHomeScene()
    local scene = Director:sharedDirector():getRunningSceneLua()
    return scene:isScene("MainScene")
end

function WeeklyRaceManager:isIconExist()
    return isSafeCocosObj(self.icon)
end

function WeeklyRaceManager:tryUpdateIcon()
    if not FeatureSwitch:isOpen(FeatureSwitch.Type.WEEKLY_RACE) then return end
    if not self:isEnabledForTopLevel() then
        return
    end
    --if WeeklyRaceManager.isActEnd() then return end
    if not self:isInHomeScene() then return end
    if self:isIconExist() then return end
    local asyncRunner = AsyncRunner:create()
    asyncRunner:add(function (done)
        if self:isIconExist() then asyncRunner:clean() return end
        WeeklyRaceHttp:sendGetIconInfoHttp({
                                               loading = false,
                                               successCallback = function (data)
                                                   if data and data.petSkinId and tonumber(data.petSkinId) ~= 0 then
                                                       safeRunCall(done)
                                                   else
                                                       asyncRunner:clean()
                                                   end
                                               end,
                                               failCallback = function ()
                                                   asyncRunner:clean()
                                               end,
                                               cancelCallback = function ()
                                                   asyncRunner:clean()
                                               end,
                                           })
    end)

    asyncRunner:add(function (done)
        if self:isIconExist() then asyncRunner:clean() return end
        self.icon = WeeklyRaceIcon:create()
        IconEventCenter:addIconEvent(self.icon)
        safeRunCall(done)
    end)
    asyncRunner:run()
end

function WeeklyRaceManager:preloadModuleRes(successCallback, errorCallback , cancelCallback, needTip)
    if needTip == nil then
        needTip = true
    end
    local function onLoadSuccess()
        safeRunCall(successCallback)
    end
    local function onLoadError()
        if needTip then
            CommonTip:showTip("该功能需要联网,请检查网络状态")
        end
        safeRunCall(errorCallback)
    end

    AssetsUtil:loadDynamicModule('meta/Weeklyrace.xml', onLoadSuccess, onLoadError, cancelCallback, needTip)
end

function WeeklyRaceManager:onTouchIcon()
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        CommonTip:showTip("网络连接失败，请联网重试！")
        return
    end

    local asyncRunner = AsyncRunner:create()

    asyncRunner:add(function (done)
        if not self:isEnabledForTopLevel() then
            CommonTip:showTip("到达" ..
                                      _G.WeeklyRaceConst.ENABLE_WEEKLY_RACE_TOP_LEVEL ..
                                      "级即可开启萌宠周赛哦~","positive")
            asyncRunner:clean()
        else
            WeeklyRaceHttp:sendGetIconInfoHttp({
                                                   loading = true,
                                                   successCallback = function (data)
                                                       safeRunCall(done)
                                                   end,
                                                   failCallback = function ()
                                                       asyncRunner:clean()
                                                   end,
                                                   cancelCallback = function ()
                                                       asyncRunner:clean()
                                                   end,
                                               })
        end
    end)

    asyncRunner:add(function (done)
        self:preloadModuleRes(function()
            safeRunCall(done)
        end, function()
            asyncRunner:clean()
        end, function()
            asyncRunner:clean()
        end)
    end)

    asyncRunner:add(function (done)
        WeeklyRaceHttp:sendWeekMatch2020InfoHttp({
                                               loading = true,
                                               successCallback = function (data)
                                                   safeRunCall(done)
                                               end,
                                               failCallback = function ()
                                                   asyncRunner:clean()
                                               end,
                                               cancelCallback = function ()
                                                   asyncRunner:clean()
                                               end,
                                           })
    end)

    asyncRunner:add(function (done)
        self:openMainPanel()
        safeRunCall(done)
    end)

    asyncRunner:run()
end

function WeeklyRaceManager:isEnabledForTopLevel()
    local topLevel = _G.getTopLevelId()
    if topLevel >= _G.WeeklyRaceConst.ENABLE_WEEKLY_RACE_TOP_LEVEL then
        return true
    end
    return false
end

function WeeklyRaceManager:openMainPanel(delegate)
    delegate = delegate or {}
    local MainPanelVM = require "amf.feature.weeklyrace.view.MainPanelVM"
    local vm = MainPanelVM:create()
    vm:popout(nil, true)
end

function WeeklyRaceManager:setMainPanel(mainPanel)
    self.mainPanel = mainPanel
end

function WeeklyRaceManager:getMainPanel()
    return self.mainPanel
end

--获取装扮素材
function WeeklyRaceManager:getDressItemResPath( dressId )
    return 'weeklyRace2020_dressItem/item'..dressId..'.png'
end

--创建通用的装扮
function WeeklyRaceManager:createCommonDressItem( dressId )
    local uiData = require "amf.feature.weeklyrace.view.uisource.PetItemCommon_UI"
    local builder = UIBuilder.new(uiData)
    local itemUI = builder:createChild("itemUI")
    itemUI.itemId = dressId
    local itemHolder = itemUI:getChildByName('itemHolder')
    local plistPath = "amf/weeklyrace/texture/weeklyRace2020_dressItem.plist"
    local spfName = self:getDressItemResPath(dressId)
    local itemSprite = UICreateUtil:createSpriteWithPlist(plistPath, spfName)
    if itemSprite then
        itemSprite:setAnchorPoint(ccp(0.5,0.5))
        --itemSprite:setPosition(ccp(0,0))
        LayoutUtil:centerAdd(itemHolder, itemSprite)
        --itemHolder:addChild(itemSprite)
        itemSprite:setName( "itemSprite" )
    end
    self:updateDressItemShow(itemUI)
    return itemUI
end

function WeeklyRaceManager:updateDressItemShow( itemUI )
    --刷新展示
    local selectIcon = itemUI:getChildByName('select')
    local limit = itemUI:getChildByName('xianding')
    local haohua = itemUI:getChildByName('haohua')
    local xiyou = itemUI:getChildByName('xiyou')
    local noSee = itemUI:getChildByName('noSee')
    local buyBtn = itemUI:getChildByName('buyBtn')

    if limit then
        limit:setVisible(false)
    end
    selectIcon:setVisible(false)
    haohua:setVisible(false)
    xiyou:setVisible(false)
    noSee:setVisible(false)
    buyBtn:setVisible(false)

    if itemUI.itemId then
        if _G.WeeklyRaceConst.DressSpineInfo[itemUI.itemId] then
            if _G.WeeklyRaceConst.DressSpineInfo[itemUI.itemId].dressRarityType == _G.WeeklyRaceConst.DressRarityType.XIYOU then
                xiyou:setVisible(true)
            elseif _G.WeeklyRaceConst.DressSpineInfo[itemUI.itemId].dressRarityType == _G.WeeklyRaceConst.DressRarityType.HAOHUA then
                haohua:setVisible(true)
            elseif _G.WeeklyRaceConst.DressSpineInfo[itemUI.itemId].dressRarityType == _G.WeeklyRaceConst.DressRarityType.LIMIT then
                limit:setVisible(true)
            end
        else
            noSee:setVisible(true)
        end
    end
end

function WeeklyRaceManager:updateDressItemSelectShow( itemUI, bSelect )
    local selectIcon = itemUI:getChildByName('select')
    selectIcon:setVisible( bSelect )
end

function WeeklyRaceManager:updateDressItemHaveShow( itemUI, forceHave  )
    if forceHave == nil then forceHave = false end
    local bHaveDress = self:getCurIsHaveDress(itemUI.itemId)
    local noSee = itemUI:getChildByName('noSee')
    local itemHolder = itemUI:getChildByName('itemHolder')
    if bHaveDress or forceHave then
        itemHolder:setVisible( true )
        noSee:setVisible(false)
    else
        itemHolder:setVisible( false )
        noSee:setVisible(true)
    end
end

function WeeklyRaceManager:createCommonTipIcon( dressId )
    local plistPath = "amf/weeklyrace/texture/weeklyRace2020_dressItem.plist"
    local spfName = self:getDressItemResPath(dressId)
    local itemSprite = UICreateUtil:createSpriteWithPlist(plistPath, spfName)
    if itemSprite then
        itemSprite:setAnchorPoint(ccp(0.5,0.5))
    end
    return itemSprite
end

function WeeklyRaceManager:isActItem(itemId)
    local actItemIds = {
        50112,
    }
    return table.includes(actItemIds, itemId)
end

function WeeklyRaceManager:addRewards(rewardItems,notActReward)
    local rewards = {}
    local actRewards = {}
    for k,v in pairs(rewardItems or {}) do
        if not self:isActItem(v.itemId) then
            table.insert(rewards, v)
        else
            table.insert(actRewards, v)
        end
    end

    _G.GainPropData:create()
      :setFeature(DcFeatureType.kWeeklyRace2020)
      :setSource(DcSourceType.kWeeklyRace2020Reward)
      :setProps(rewards)
      :setActId(8015)
      :execute()
end

-- 本地缓存
function WeeklyRaceManager:saveFlagToLocalByKeyInt(key, needTime, popNum)
    if not key then return end
    if popNum == nil then popNum = 0 end
    local keyStr = 'CommonMgrBaseV2_Int_'.."WeeklyRace2020"..'_'.. key
    keyStr = keyStr..'_v'
    if needTime then
        local curTime = TimeKit:timeInSec()
        local dayStartTime = getDayStartTimeByTS(curTime)
        keyStr = keyStr .. ':' .. dayStartTime
    end
    LocalDB:setInt(keyStr, popNum)
end

function WeeklyRaceManager:getFlagFromLocalByKeyInt(key, needTime, defaultValue)
    if defaultValue == nil then
        defaultValue = 0
    end
    local keyStr = 'CommonMgrBaseV2_Int_'.."WeeklyRace2020"..'_'.. key
    keyStr = keyStr..'_v'
    if needTime then
        local curTime = TimeKit:timeInSec()
        local dayStartTime = getDayStartTimeByTS(curTime)
        keyStr = keyStr .. ':' .. dayStartTime
    end
    return LocalDB:getInt(keyStr, defaultValue)
end

function WeeklyRaceManager:getCanRewardHandBook()
    return self.model:getCanRewardHandBook()
end

function WeeklyRaceManager:getCanGetOfflineRewardInfo()
    return self.model:getCanGetOfflineRewardInfo()
end

function WeeklyRaceManager:isActDataValid()
    return self.model:isActDataValid()
end

function WeeklyRaceManager:getPetName()
    return self.model:getPetName()
end

function WeeklyRaceManager:getPageItemsByPageIndex(pageIndex)
    return self.model:getPageItemsByPageIndex(pageIndex)
end

function WeeklyRaceManager:getPageHavePieceItems(pageIndex)
    return self.model:getPageHavePieceItems(pageIndex)
end

function WeeklyRaceManager:getCurIsHaveDress(dressId)
    return self.model:getCurIsHaveDress(dressId)
end

function WeeklyRaceManager:getDecorationIds()
    return self.model:getDecorationIds()
end

function WeeklyRaceManager:setNewDressList(dressList)
    self.model:setNewDressList(dressList)
end

function WeeklyRaceManager:getDecorationBag()
    return self.model:getDecorationBag()
end

function WeeklyRaceManager:checkCurIsHaveDressAnimal()
    return self.model:checkCurIsHaveDressAnimal()
end

function WeeklyRaceManager:getHandBookMetaInfoByPageIndex(curShowPageIndex)
    return self.model:getHandBookMetaInfoByPageIndex(curShowPageIndex)
end

function WeeklyRaceManager:getHandBookDataInfoByPageIndex(curShowPageIndex)
    return self.model:getHandBookDataInfoByPageIndex(curShowPageIndex)
end

function WeeklyRaceManager:getCurHaveDressNum(handBookDataInfo)
    return self.model:getCurHaveDressNum(handBookDataInfo)
end

function WeeklyRaceManager:checkCanRewardForHandBook(curShowPageIndex)
    return self.model:checkCanRewardForHandBook(curShowPageIndex)
end

function WeeklyRaceManager:getCompleteHandBookNum()
    return self.model:getCompleteHandBookNum()
end

function WeeklyRaceManager:getHandBooks()
    return self.model:getHandBooks()
end

function WeeklyRaceManager:getOfflineRewardStatus()
    return self.model:getOfflineRewardStatus()
end

function WeeklyRaceManager:getPetCreateTime()
    return self.model:getPetCreateTime()
end

function WeeklyRaceManager:getPetCharacter()
    return self.model:getPetCharacter()
end

return WeeklyRaceManager
