
local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local ACT_NAME = "Canteen"
local Manager = class("Manager",BaseFeatureManager)
local LOCAL_PATH = 'amf.feature.localactivity.'..string.lower( ACT_NAME )
local Meta = require(LOCAL_PATH .. '.config.Meta.lua')

local GoodsHelper = require (LOCAL_PATH .. '.goodshelper.GoodsHelper')

Manager.ACT_NAME = ACT_NAME
Manager.ACT_OPEN_VERSION = 6 --前后端业务逻辑同时迭代时增加
Manager.ACT_ROUND = Meta.ACT_ROUND --每期迭代更改
Manager.ACT_ID = 3068
-- Manager.DOWN_PART_NAME = "ManagerDownPart"
Manager.GAME_NAME = "chef_god"
Manager.ACT_CH_NAME = "厨神食堂"
Manager.ACT_SOURCE = string.lower( ACT_NAME ).."/Config.lua"
Manager.logChannels = {29, 36}

function Manager:_init()
    self.dcHelper = require 'amf.feature.localactivity.canteen.dc.CanteenDC'
    self.goodsHelper = GoodsHelper:create( {actId=Manager.ACT_ID, feature = Manager.GAME_NAME, source = Manager.ACT_SOURCE } )
    -- self:onPreDownLoadRes()
    self:registerProps()
    self:initModules()
    self:registerEvents()
    self:_checkAndNotifyPassRoundOnInit()
end

-- 获取需要启动的额外功能列表
function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "Download",
        },
        {
            key = "Panel",
        },
        {
            key = "Rewards",
        },
    }
end


function Manager:_checkAndNotifyPassRoundOnInit()
    local lastRound = self:getModel():getValue("actRound")
    local nowRound = Manager.ACT_ROUND
    if lastRound ~= nowRound then
        self:getModel():onPassRound()
        lastRound = nowRound
        self:getModel():setValue("actRound", nowRound)
    end
end


function Manager:passDayRefreshData()
    self:getModel():onPassDay()
end

-- 注册buff道具
function Manager:registerProps()
    local ScoreBuff = require"amf.feature.localactivity.canteen.props.ScoreBuff"
    local AMFProp_52906 = require"amf.feature.localactivity.canteen.props.AMFProp_52906"
    local AMFProp_52907 = require"amf.feature.localactivity.canteen.props.AMFProp_52907"

end

-- 获取model路径
function Manager:_getModelPath()
    return LOCAL_PATH .. '.data.CanteenModel.lua'
end

function Manager:_getConstPath()
    return LOCAL_PATH .. '.config.Meta.lua'
end


-- function Manager:onPreDownLoadRes()
--     _G.amfBean("AssetsUtil"):loadMiniLabels({"canteen"}, false):next(function()
--         self._isResReady = true
--     end, function()
--     end)
-- end

function Manager:registerEvents()
    require('amf.feature.localactivity.canteen.CanteenResponseShareHandler'):create()
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
    PropEventCenter:register(PropEvent.RESOLVE_ICON, self._onResolveIcon, self)
end

function Manager:initModules()
    -- _G.amfEC:registerFeature(self)
    -- _G.amfEC:registerSystem(self)
    self:addEventDispatcher()
    _G.amfEC:registerNormal(NormalEvent.PLAY_LEVEL_END, self.onActPassLevel, self)
    _G.amfEC:registerNormal(NormalEvent.PASS_DAY, self.onActPassDay, self)
    -- _G.amfEC:bindEventObserver(self, "on")
end

function Manager:onActPassLevel(data)
    self:getData():passLevel_normal()
end

-- function Manager:onActPassDay()
--     if not self:isEnabled() then return end
--     self:getData():onPassDay()
--     -- self:getLocalDataServer():passDayRefreshData()
-- end


-- 同步所有数据
function Manager:updateData(data, skipSaveLocal, fromServer)
    if not data then
        return
    end
    self:getModel():fromServer(data, skipSaveLocal)
    if fromServer == true then
        self.hasGetDataFromServer = true
    end
end

function Manager:hasGetRewardsForShow(type)
    return self:getData():getAlreadShow(type)
end

function Manager:setRewardsForShow(b,type)
    self:getData():setAlreadShow(b,type)
end

---------------------------------- 加道具 ----------------------------------
-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    self:callPlug("Rewards", "addRewardsNormal", rewardItems, {
        dcExtra = params,
    })
end


-- -- 检测是普通的还是特殊的
-- function Manager:_checkIsSpecialItem(reward)
--     if table.keyOf(self:getConst().itemIds,reward.itemId) then
--         return true
--     elseif  reward.itemId == self:getConst().scoreBuff20Id then
--         return true
--     end
-- end

function Manager:addActItem(reward)
    if table.keyOf(self:getConst().itemIds,reward.itemId) then
        if self:getConst().itemId2MaterialsId[reward.itemId] then
            self:getData():addMaterial(self:getConst().itemId2MaterialsId[reward.itemId],reward.num)
        end
    end
end



-- -- 不要调用，但需要修改业务逻辑相关添加
-- function Manager:_addRewards(rewardItems, payType, params)
--     local dcFeature, dcSource
--     if params and params.dcFeature and params.dcSource then
--         dcFeature, dcSource = params.dcFeature, params.dcSource
--     end

--     for _,v in ipairs(rewardItems) do
--         if self:_checkIsSpecialItem(v) then
--             self:addActItem(v)
--         end
--     end
--     _G.GainPropData:create()
--         :setFeature(dcFeature)
--         :setSource(dcSource)
--         :setProps(rewardItems)
--         :execute()
-- end

--icon创建
function Manager:createIcon(reward,menuId)
    local icon
    if reward.itemId == self:getConst().collectId then
        icon = UICreateUtil:createSpriteFile("amf/feature/gladiator/materials/collectIcon.png")
    elseif self:isActIcon(reward) then
        icon = self:createActIcon(reward,menuId)
    else
        icon = GameItemCreator:getPropIcon(reward)
    end

    return icon
end



function Manager:createMenuIcon(menuId, unlocked)
    local frameName = self:getConst().preFrameName .. self:getConst().menuRes[tonumber(menuId)]
    local icon = UICreateUtil:createSpriteWithPlist(self:getConst().foodResPath, frameName)
    if icon then
        icon.setUnlock = function(obj, isUnlock, isMainPanel)
            local ShaderUtil = require"amf.middleware.ui.kit.shader.ShaderUtil"
            local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
            if isUnlock then
                ActionUtil:setGroupOpacity(obj, 255)
                -- ShaderUtil:fixColor(obj, nil, false)
            -- elseif isMainPanel then
            --     ActionUtil:setGroupOpacity(obj, 255)
            --     ShaderUtil:fixColor(obj, hex2ccc4("EDC99EB2"), true)
            else
                ActionUtil:setGroupOpacity(obj, 100)
                -- ShaderUtil:fixColor(obj, hex2ccc4("EDC99EB2"), true)
            end
        end
        icon:setUnlock(unlocked)
    else
        UError("createMenuIcon error, frameName = " .. tostring(frameName),menuId)
    end
    return icon
end

function Manager:createInLevelMenuIcon(menuId, unlocked)
    local frameName = self:getConst().menuRes[tonumber(menuId)]
    local icon = UICreateUtil:createSpriteWithPlist(self:getConst().inLevelFoodResPath, frameName)
    if icon then
        icon.setUnlock = function(obj, isUnlock, isMainPanel)
            local ShaderUtil = require"amf.middleware.ui.kit.shader.ShaderUtil"
            local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
            if isUnlock then
                ActionUtil:setGroupOpacity(obj, 255)
                ShaderUtil:fixColor(obj, nil, false)
            -- elseif isMainPanel then
            --     ActionUtil:setGroupOpacity(obj, 255)
            --     ShaderUtil:fixColor(obj, hex2ccc4("EDC99EB2"), true)
            else
                ActionUtil:setGroupOpacity(obj, 255)
                ShaderUtil:fixColor(obj, hex2ccc4("EDC99EB2"), true)
            end
        end
        icon:setUnlock(unlocked)
    else
        UError("createMenuIcon error, frameName = " .. tostring(frameName),menuId)
    end
    return icon
end

function Manager:createMaterialBg(itemId)
    local frameName = self:getConst().preFrameName .. self:getConst().materialBgRes[itemId]
    local icon = UICreateUtil:createSpriteWithPlist(self:getConst().foodResPath, frameName)
    return icon
end

function Manager:createInLevelMaterialBg(itemId)
    local frameName = self:getConst().materialBgRes[itemId]
    local icon = UICreateUtil:createSpriteWithPlist(self:getConst().inLevelFoodResPath, frameName)
    return icon
end


function Manager:createMaterialIcon(reward, menuId)
    local icon
    local itemId = self:getMaterialItemId(tostring(reward.itemId), menuId)
    local frameName = self:getConst().preFrameName .. self:getConst().materialRes[itemId]
    icon = UICreateUtil:createSpriteWithPlist(self:getConst().foodResPath, frameName)
    local ui = Layer:create()
    ui.bgLayer = self:createMaterialBg(itemId)
    ui.bgLayer:setScale(0.9)
    if ui.bgLayer then
        ui:addChild(ui.bgLayer)
    end
    if icon then
        ui:addChild(icon)
        ui.icon = icon
        ui.icon:setScale(0.88)
    end
    return ui

end

function Manager:createInLevelMaterialIcon(reward, menuId)
    local icon
    local itemId = self:getMaterialItemId(tostring(reward.itemId), menuId)
    local frameName = self:getConst().materialRes[itemId]
    icon = UICreateUtil:createSpriteWithPlist(self:getConst().inLevelFoodResPath, frameName)
    local ui = Layer:create()
    ui.bgLayer = self:createInLevelMaterialBg(itemId)
    ui.bgLayer:setScale(0.9)
    if ui.bgLayer then
        ui:addChild(ui.bgLayer)
    end
    if icon then
        ui:addChild(icon)
        ui.icon = icon
        ui.icon:setScale(0.88)
    end
    return ui

end


---------------------- 功能函数 -----------------------------

function Manager:getLocalDataServer()
    return self:getModel()
end

function Manager:getData()
    return self:getLocalDataServer()
end

-- 是否是主活动期
function Manager:isInMainTime()
    return self:getModel():isActInMain()
end

-- 是否是领奖期
function Manager:isInRewardTime()
    return self:getModel():isActInReward()
end

-- 记得改造一下
function Manager:isEnabled()
    local isLogicEnabled = self:getModel():isDataEnabled()
    local isResEnabeld = self.downloadPlug:checkDownloadSuccess()
    if isLogicEnabled and not isResEnabeld then
        self:callPlug("Download","startDownload")
    end
    return isLogicEnabled and isResEnabeld
end


function Manager:openActivity(closeCallback, extra, userClick, duanMianData)
    self:callPlug("Act","openActivity",{
            actId = Manager.ACT_ID,
            failCallback = closeCallback,
            endCallback = closeCallback,
            userClick = userClick,
            extra = extra,
            duanMianData = duanMianData
        })
    -- ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY, {
    --     actId = Manager.ACT_ID,
    --     failCallback = closeCallback,
    --     endCallback = closeCallback,
    --     userClick = userClick,
    --     extra = extra,
    --     duanMianData = duanMianData
    -- })
end


-- 奖字
function Manager:updateTipView()
    if not self:isEnabled() then
        return
    end
    local function setIconInfo( source, hasReward, msgNum )
        local actInfo = self:getActInfo()
        if not actInfo then return end
        actInfo.reward = hasReward
        actInfo.msgNum = msgNum
        self:callPlug("Act","setActInfo",actInfo)
    end
    if not self:isEnabled() then return end
    local hasReward = self:hasRewards()
    local msgNum = self:getShowMsgNum()
    setIconInfo(Manager.ACT_SOURCE, hasReward, msgNum)
end

function Manager:hasRewards()
    if not self:isEnabled() then
        return
    end
    local canMakeMenu = self:canMakeMenu()
    if canMakeMenu then return true end
    local hasDailyRewards = self:getData():getDataByKey('canGetNationalDailyRankReward')
    local hasGroupRewards = self:getData():getDataByKey('canGetGroupRankReward')
    return hasDailyRewards or hasGroupRewards
end


function Manager:getShowMsgNum()
    return 0
end

-- 检测引导标记
function Manager:hasGuideIndex(index)
    local hasIndex = self:getLocalDataServer():hasGuide(index)
    return hasIndex
end

-- 设置引导标记
function Manager:addGuideIndex(index)
    self:getLocalDataServer():setGuide(index)
    local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
    ActCommonHttp:setActGuideFlag(Manager.ACT_ID, index,true)
end

function Manager:log(firstStr,...)
    return self:logD(firstStr, ...)
end

function Manager:logD(...)
    local concatLog = function(...)
        local msgs = {}
        local len = select("#", ...)
        for i = 1, len do
            table.insert(msgs, tostring(select(i, ...)))
        end
        return table.concat(msgs, '--')
    end

    for k, id in ipairs(self.logChannels) do
        local msg = concatLog('Manager', ...)
        printx(id,msg)
    end
end

function Manager:logError(...)
    self:logD('ERROR!!!!!!!!!', ...)
end

----------------------业务代码----------------------------
function Manager:canDropMaterial(panelLogic)


    local treeId = '364'
    local runtime = {
        sourceId = Manager.ACT_ID,
        levelId = panelLogic.levelId,
        levelType = panelLogic.levelType,
        startLevelType = panelLogic.startLevelType,
        oldScore = panelLogic.PreContext.levelInfo and panelLogic.PreContext.levelInfo.score or 0,
        oldStar = panelLogic.PreContext.levelInfo and panelLogic.PreContext.levelInfo.star or 0,
    }
    if UBFPlaySwitch:isUBFBoardLevel( panelLogic.levelId ) then
        treeId = 'UBF_364'
        return UBFActHelper:checkActOpenCondition(runtime, treeId)
    else
        -- return UBFActHelper:checkActOpenCondition(runtime, treeId)
        local isCanCollect = ActInLevelManagerHelper:getInstance():checkLevelCollectCondition(Manager.ACT_ID, {levelId = panelLogic.levelId})
        return isCanCollect
    end

end

function Manager:canMakeMenu()
    local menuList = self:getData():getDataByKey('menuList',{})
	for k,v in pairs(menuList) do
        local id = v.menuId
        if self:canMakeMenuById(id) then
            return true
        end
    end
    return false
end

function Manager:canMakeMenuById(menuId,materialMap)
    local menuBean = self:getData():getMenuById(menuId)
    local materialMap = materialMap or self:getData():getDataByKey('materialMap')
    if not menuBean or not materialMap then return false end
    for id,needNum in pairs(menuBean.needMaterialMap) do
        if not materialMap[id] or  materialMap[id] < needNum then
            return false
        end
        if menuBean.menuType == 2 and not self:isInLimitTime() then
            return
        end
    end
    return true
end

function Manager:findCanMakeMenu()
	local canMakeId = nil
    local menuList = self:getData():getDataByKey('menuList',{})
	for k,v in pairs(menuList) do
        if self:canMakeMenuById(v.menuId) then
            if self:isLimitMenu(v.menuId) then
                canMakeId = v.menuId
                break
            end

            if not canMakeId then
                canMakeId = v.menuId
            end
            canMakeId = math.max(canMakeId,v.menuId)
        end
	end
    return canMakeId
end

function Manager:getShowMenuId()
	local showId = nil
    local menuList = self:getData():getDataByKey('menuList',{})
	for k,v in pairs(menuList) do
        if self:isLimitMenu(v.menuId) and self:isInLimitTime()  then
            showId = v.menuId
            break
        end
        if not self:isLimitMenu(v.menuId) then
            if not showId then
                showId = v.menuId
            else
                showId = math.max(showId,v.menuId)
            end
        end
	end
    return showId
end



function Manager:canOpenLimitMenu()
	local time = TimeKit:timeInSec()
    local nextDayStartTime = TimeKit:getDayStartTimeByTS2(time + 24 *60 *60 )
	if  nextDayStartTime - time  <= 5 * 60 then
        return false ,1
	end
    local todayTriggeredTimes = self:getData():getDataByKey('todayTriggeredTimes',0)
    local triggeredTimeLimit = self:getData():getDataByKey('triggeredTimeLimit',1)
    local nowTime = self:getData():getDataByKey('afterLastTimeTrigger',0)
    local needTime = self:getData():getDataByKey('triggerTemporaryNeed',0)
    return todayTriggeredTimes < triggeredTimeLimit ,nowTime,needTime
end

function Manager:isInLimitTime()
    if self:getData():getLimitMenu() then return true else return false end
end

function Manager:isInGiftTime()
    return self:getData():isInGiftTime()
end



function Manager:getLimitTime(menuId)
    local time = tonumber(self:getData():getDataByKey('goodsExpireAtTs',0)) / 1000
    if  menuId then
        local menuBean = self:getData():getMenuById(menuId)
        if menuBean then
            time = tonumber(menuBean.expireAtTs or 0)/ 1000
        end
    end
    return time

end


function Manager:isLimitMenu(menuId)
    if table.keyOf(self:getConst().limitMenus, menuId) then
        return true
    end
    return false
end

function Manager:getMenuTag(menuId)
    if not self:isEnabled() then return end
    local menuMetaList = self:getData():getDataByKey('menuMetaList')
    local menuBean = self:getData():getMenuById(menuId)
    local meddleId =  self:getData():getDataByKey('meddleId')
    for id,v in ipairs(menuMetaList) do
        if v.menuId and v.menuId == menuId then
            local expandMeta = v.expandMeta
            if not expandMeta or not expandMeta.detailMetaList or table.isEmpty(expandMeta.detailMetaList) then
                return nil,0.5
            end
            local expandId = 0
            for k,meta in ipairs(expandMeta.detailMetaList) do
                if menuBean.makeTimes >= meta.needTimes then
                    expandId = k
                end
            end
            if expandId == 0 then
                return '食材',0.5,expandId
            elseif expandId == 1 and meddleId == 2 then
                return '食材',0.67,expandId
            elseif expandId == 1 then
                return '食材',0.75,expandId
            else
                return '口碑值',5,expandId
            end


            break
        end
    end
    return nil
end

local function formatSpecial( num, divisor, decimalPlaces )
    decimalPlaces = decimalPlaces or 2
    -- string.format("%.2f",num/10000)的写法会进位... 999999990000
    local text = tostring(num/divisor)
    local dotIndex = string.find(text, "%.")
    if dotIndex then
        text = string.sub(text, 1, dotIndex+decimalPlaces)
        -- 补足后导零
        if string.len(text) < dotIndex+decimalPlaces then
            text = text..string.rep("0", dotIndex+decimalPlaces-string.len(text))
        elseif decimalPlaces == 0 then
            text = string.sub(text, 1, dotIndex-1)
        end
    end
    local text1  = string.sub(text, string.len(text)-decimalPlaces)
    if text1 == "."..string.rep("0", decimalPlaces) then
        text = string.sub(text, 1, string.len(text)-decimalPlaces-1)
    end
    return text
end

function Manager:formatNumSpecial(num )
    num = tonumber(num)
    if not num then return "" end
    local str, scientific = tostring(num), false
    if num >= 100000000 then
        str = formatSpecial(num, 100000000).."亿"
        scientific = true
    elseif num >= 10000 then
        str = formatSpecial(num, 10000,1).."万"
        scientific = true
    end
    return str, scientific

end


function Manager:getMaterialItemId(itemId, menuId)
    if menuId and self:isLimitMenu(menuId) and self:getConst().spMenuNeedMaterials[menuId] then
        if itemId == self:getConst().materialIds.kSpA then
            itemId = self:getConst().spMenuNeedMaterials[menuId].A
        elseif itemId == self:getConst().materialIds.kSpB then
            itemId = self:getConst().spMenuNeedMaterials[menuId].B
        end
    end
    return itemId
end

function Manager:isActIcon(reward)

    if table.keyOf(self:getConst().materialIds, reward.itemId) then
        return true
    elseif reward.itemId == self:getConst().zanId then
        return true
    elseif reward.itemId == self:getConst().scoreBuff20Id then
        return true
    end
    return false

end


function Manager:createActIcon(reward, menuId)
    local icon
    if table.keyOf(self:getConst().materialIds, reward.itemId) then
        icon = self:createMaterialIcon(reward, menuId)
    elseif self.shopMgr and self.shopMgr:isCard({
        cardId = reward.itemId,
        includeRandomCard = true
    }) then
        icon = self.shopMgr:createCard({
            cardId = reward.itemId
        })
    elseif reward.itemId == self:getConst().zanId then
        icon = self:createZanIcon()
    elseif reward.itemId == self:getConst().scoreBuff20Id then
        icon = self:createScoreBuffId(reward)
    end
    return icon
end

function Manager:setNotFly(rewards)
    for _, reward in ipairs(rewards) do
        reward.doNotFly = true
    end
end


function Manager:setFlyFunc(rewards)
    --商城自适应了
end


function Manager:createWeakFlyAnim(ui, rewardsData, offset, done)
    -- 执行弱领奖
    if ui.isDisposed then
        return
    end
    local function commonCreateIcon(reward, needNum, scale)
        -- 通用创建icon
        local icon = self:createIcon(reward, needNum, scale)
        icon:setScale(1)
        return icon
    end

    local rewards = {}
    if rewardsData.rewardList then
        local rewardList = table.mergeRewards(rewardsData.rewardList)
        local yuanBaoList = table.mergeRewards(rewardsData.yuanBaoList)
        local rewardDirectList = table.mergeRewards(rewardsData.rewardDirectList)
        rewards = table.union(rewards, rewardDirectList)
        rewards = table.union(rewards, rewardList)
        rewards = table.union(rewards, yuanBaoList)
    else
        rewards = rewardsData
    end


    for k,v in pairs(rewards) do
        if v.itemId == self:getConst().scoreBuff20Id then
            v.isSingleShowNum = true
        end
    end

    local worldPos = ui:getPositionInWorldSpace()
    local flyContext = FlyItemContext.new(rewards, worldPos)
    flyContext:setFinishCallback(done)
    _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)

    -- self:setNotFly(rewards)
    -- local UICreateUtils = require 'UICreateUtils'
    -- UICreateUtils:createWeakFlyAnim(ui, rewards, commonCreateIcon, 0.9, offset, done, {
    --     stayTime = 0.3
    -- })
end

function Manager:showShopRewardsPanel(rewardsInfo, closeCall, mainPanel, panelType, skinType, boxType,
    bottomLabelData)
    -- 展示商城奖励界面
    -- 使用商城统一界面

    local downTip = ''

    for i, reward in ipairs(rewardsInfo.rewardDirectList) do
        reward.createIconFunc = function(reward)
            return self:createIcon(reward)
        end
        if reward.itemId == self:getConst().scoreBuff20Id then
            reward.isSingleShowNum = true
        end
    end

    local delegate = {}

    delegate.rewardList = rewardsInfo.rewardList
    delegate.rewardDirectList = rewardsInfo.rewardDirectList
    delegate.repeatList = rewardsInfo.repeatList
    delegate.yuanBaoList = rewardsInfo.yuanBaoList
    delegate.panelType = panelType or 1 -- ： 1 没箱子的 2 有箱子的 3 特殊箱子
    delegate.skinType = skinType or 0 -- ：panelType为2时生效
    delegate.boxType = boxType or 0 -- ：panelType为2时生效
    delegate.subTitle =  bottomLabelData
    delegate.closeCallback = closeCall

    delegate.managePanelFunc = function(vm)
        self:managePanelVM(vm)
    end
    ULog("EXCHANGE_SHOP_SHOW_REWARD")
    if _G.AMFEventConst.TransactionType.EXCHANGE_SHOP_TASK then
        _G.amfTransaction(_G.AMFEventConst.TransactionType.EXCHANGE_SHOP_TASK, {
            subCmd = "showReward",
            subData = delegate,
        })
    else
        _G.amfTransaction(_G.AMFEventConst.TransactionType.EXCHANGE_SHOP_SHOW_REWARD, delegate)
    end
end



function Manager:updatePassLevelData(levelContext, mainCollectionCount, collectionMap, passLevelData)
    -- todo：过关，更新本地数据
    self.canShowDownPart = true
    self.logs = {}

	self.pass_playId = levelContext.playId

    local isPassLevel = false
    -- self:getData():addMaterial(collectionMap)
    if collectionMap then
        local materialsMap = {
            [self:getConst().materialIds.material_N_1_1] = collectionMap["52"],
            [self:getConst().materialIds.material_N_1_2] = collectionMap["53"],
            [self:getConst().materialIds.material_N_1_3] = collectionMap["54"],
            [self:getConst().materialIds.material_N_1_4] = collectionMap["55"],
            [self:getConst().materialIds.material_N_2_1] = collectionMap["56"],
            [self:getConst().materialIds.material_N_2_2] = collectionMap["57"],
            [self:getConst().materialIds.material_N_3_1] = collectionMap["58"],
            [self:getConst().materialIds.material_N_3_2] = collectionMap["59"],
            [self:getConst().materialIds.kSpA] = collectionMap["60"],
            [self:getConst().materialIds.kSpB] = collectionMap["61"],
        }
        for id,num in pairs(materialsMap) do
            self:getData():addMaterial( id,num)
            isPassLevel = isPassLevel or  num > 0
        end
    end

    if isPassLevel then
        self:getData():passLevel()
    end

    if levelContext.sectionData then
        printx(15,"levelContext.sectionData",tts(levelContext.sectionData))
        printx(15,"passLevelData",tts(passLevelData))
        -- 旧棋盘的结构
        if levelContext.sectionData.reachFuuu then
            self:getData():setDataByKey("reachFuuuTimes", self:getData():getDataByKey("reachFuuuTimes",0) + 1, true, true)
        end

        if levelContext.sectionData.dropRare then
            self:getData():setDataByKey("notDropRare", 0, true, true)
        else
            self:getData():setDataByKey("notDropRare", self:getData():getDataByKey("notDropRare",0) + 1, true, true)
        end

        if passLevelData.star >= 1 and collectionMap["55"] > 0 then
            self:getData():setDataByKey("firstTryDone1", true, true, true)
        end

        if passLevelData.star >= 3 and collectionMap["57"] > 0 then
            self:getData():setDataByKey("firstTryDone2", true, true, true)
        end

        printx(15,"111111111111",self:getData():getDataByKey("reachFuuuTimes",0))
        printx(15,"222222222222",self:getData():getDataByKey("notDropRare",0))
    else
        printx(15,"levelContext",tts(levelContext))
        if levelContext.reachFuuu then
            self:getData():setDataByKey("reachFuuuTimes", self:getData():getDataByKey("reachFuuuTimes",0) + 1, true, true)
        end

        if levelContext.dropRare then
            self:getData():setDataByKey("notDropRare", 0, true, true)
        else
            self:getData():setDataByKey("notDropRare", self:getData():getDataByKey("notDropRare",0) + 1, true, true)
        end

        printx(15,"aaaaa111111111111",self:getData():getDataByKey("reachFuuuTimes",0))
        printx(15,"aaaaaa222222222222",self:getData():getDataByKey("notDropRare",0))

        if ( levelContext.curStar >= 1 or levelContext.modEnvData.isFullLevelLibrary ) and collectionMap["55"] > 0 then
            self:getData():setDataByKey("firstTryDone1", true, true, true)
        end

        if ( levelContext.curStar >= 3 or levelContext.modEnvData.isFullLevelLibrary ) and collectionMap["57"] > 0 then
            self:getData():setDataByKey("firstTryDone2", true, true, true)
        end
    end
end



---------------------- 关卡内 -----------------------------
function Manager:getTimeLimitRecipeType()
    local levelKey = {
        [112] = 1,
        [113] = 2,
        [120] = 3,
        [121] = 4,
        [122] = 5,
        [123] = 6,
    }
    local menuBean = self:getData():getLimitMenu()
    if not menuBean then return 0 end
    return levelKey[menuBean.menuId] or 0
end

function Manager:getInLevelActData(levelId, isFullLevelLibrary)
    local serverTopLevel = UBFLevelRangeUtil:getUserMaxLevelId()
	local isTop15Level = false
	if (serverTopLevel - 15) < levelId then
		isTop15Level = true
	end
    self.canShowDownPart = false

    local actDatas = {
        timeLimitRecipeType = self:getTimeLimitRecipeType(),
        isTop15Level = isTop15Level,
        fuuuChangeDrop = false,
    }

    printx(15,"111111111111",self:getData():getDataByKey("reachFuuuTimes",0))
    printx(15,"222222222222",self:getData():getDataByKey("notDropRare",0))

    -- 连续7关不掉扇贝，第八关必出
    local mustDropShanbei = self:getData():getDataByKey("notDropRare",0) >= 7
    -- 无视fuuu状态
    local ignoreFuuu = self:getData():getDataByKey("reachFuuuTimes",0) % 3 ~= 0
    -- printx(15,"mustDropShanbei,ignoreFuuu",mustDropShanbei,ignoreFuuu)
    if actDatas.timeLimitRecipeType > 0 then
        -- 有限时食谱
        local rand1 = math.random(1, 100)
        if rand1 <= 13 then
            actDatas.hang1 = "52"
        elseif rand1 <= 23 then
            actDatas.hang1 = "53"
        elseif rand1 <= 38 then
            actDatas.hang1 = "54"
        elseif rand1 <= 50 then
            actDatas.hang1 = "55"
        else
            actDatas.hang1 = "60"
        end

        local rand2 = math.random(1, 100)
        if rand2 <= 25 then
            actDatas.hang3 = "56"
        elseif rand2 <= 50 then
            actDatas.hang3 = "57"
        else
            actDatas.hang3 = "61"
        end

        local rand3 = math.random(1, 200)
        if rand3 <= 100 then
            actDatas.hang4 = "61"
        else
            if mustDropShanbei then
                actDatas.hang4 = "59"
            else
                if rand3 <= 113 then
                    actDatas.hang4 = "59"
                else
                    actDatas.hang4 = "58"
                    if not ignoreFuuu then
                        if rand3 <= 180 then
                            actDatas.fuuuChangeDrop = true
                        end
                    end
                end
            end
        end
    else
        -- 没有限时食谱
        local rand1 = math.random(1, 100)
        if rand1 <= 26 then
            actDatas.hang1 = "52"
        elseif rand1 <= 46 then
            actDatas.hang1 = "53"
        elseif rand1 <= 76 then
            actDatas.hang1 = "54"
        else
            actDatas.hang1 = "55"
        end

        local rand2 = math.random(1, 100)
        if rand2 <= 50 then
            actDatas.hang3 = "56"
        else
            actDatas.hang3 = "57"
        end

        local rand3 = math.random(1, 100)
        printx(15,"rand3",rand3)
        if mustDropShanbei then
            actDatas.hang4 = "59"
        else
            if rand3 <= 13 then
                actDatas.hang4 = "59"
            else
                actDatas.hang4 = "58"
                if not ignoreFuuu then
                    if rand3 <= 80 then
                        actDatas.fuuuChangeDrop = true
                    end
                end
            end
        end
    end

    -- 插入一个测试功能，指定掉落
    --
--
--
--
--
--
--
--
--
--
--
--
--
--
--


    local replaceId = 0
    replaceId = self:getReplaceId()
    printx(15,"replaceId",replaceId)
    replaceId = tonumber(replaceId)
    local replaceOn = false
    if ( replaceId >= 52 and replaceId <= 55 ) or replaceId == 60 then
        -- 50%概率替换
        if math.random(0, 1) > 0 then
            printx(15,"替换1星")
            replaceOn = true
            actDatas.hang1 = tostring(replaceId)
        else
            printx(15,"概率替换未命中1")
        end
    elseif replaceId == 56 or replaceId == 57 then
        if math.random(0, 1) > 0 then
            printx(15,"替换3星")
            replaceOn = true
            actDatas.hang3 = tostring(replaceId)
        else
            printx(15,"概率替换未命中2")
        end
    elseif replaceId == 58 or replaceId == 59 then
        if math.random(0, 1) > 0 then
            printx(15,"替换4星")
            replaceOn = true
            actDatas.hang4 = tostring(replaceId)
        else
            printx(15,"概率替换未命中3")
        end
    elseif replaceId == 61 then
        if math.random(0, 1) > 0 then
            printx(15,"替换3or4星")
            replaceOn = true
            actDatas["hang"..math.random(3, 4)] = tostring(replaceId)
        else
            printx(15,"概率替换未命中4")
        end
    end

    -- if EnvUtil:isDevelopMode() then
    --     --
--
--
--
--
--

    -- end

    -- 新手奖励覆盖保底
    if self:getData():getDataByKey("firstTryDone1", false) == false then
        -- 新手奖励1
        printx(15,"first try111")
        actDatas.drop1 = 4
        actDatas.hang1 = "55"
    end

    if self:getData():getDataByKey("firstTryDone2", false) == false then
        -- 新手奖励2
        printx(15,"first try222")
        actDatas.drop3 = 4
        actDatas.hang3 = "57"
    end

    if not actDatas.drop1 then
        actDatas.drop1 = self:__getDropNum(1, actDatas.hang1)
    end

    if not actDatas.drop3 then
        actDatas.drop3 = self:__getDropNum(3, actDatas.hang3)
    end

    if not actDatas.drop4 then
        actDatas.drop4 = self:__getDropNum(4, actDatas.hang4)
    end

    local secondConfirmInfo = {}
    local needConfirm = false
    -- hang的有可能是一样的！！！
    local collectMap = {
        [actDatas.hang1] = actDatas.drop1
    }
    local menuId = self:getCanMakeIdWhenGet(collectMap)

    if menuId then
        needConfirm = true
        table.insert(secondConfirmInfo, {
            star = 1,
            menuId = Meta.menuCollectionIdMapping[menuId],
        })
    end

    collectMap[actDatas.hang3] = ( collectMap[actDatas.hang3] or 0 ) + actDatas.drop3

    local menuId2 = self:getCanMakeIdWhenGet(collectMap)

    if menuId2 then
        needConfirm = true
        table.insert(secondConfirmInfo, {
            star = 3,
            menuId = Meta.menuCollectionIdMapping[menuId2],
        })
    end

    collectMap[actDatas.hang4] = ( collectMap[actDatas.hang4] or 0 ) + actDatas.drop4

    local menuId3 = self:getCanMakeIdWhenGet(collectMap)

    if menuId3 then
        needConfirm = true
        table.insert(secondConfirmInfo, {
            star = 4,
            menuId = Meta.menuCollectionIdMapping[menuId3],
        })
    end

    printx(15,"secondConfirmInfo",tts(secondConfirmInfo))
    -- test
    -- needConfirm = true
    -- secondConfirmInfo = {
    --     [1] = {
    --         star = 1,
    --         menuId = Meta.menuCollectionIdMapping[1],
    --     },
    --     [2] = {
    --         star = 4,
    --         menuId = Meta.menuCollectionIdMapping[112],
    --     },
    -- }

    if needConfirm then
        actDatas.secondConfirmInfo = table.clone(secondConfirmInfo)
    end

    actDatas.isFullLevelLibrary = isFullLevelLibrary
    if isFullLevelLibrary then
        actDatas["106"] = actDatas.drop1 + actDatas.drop3 + actDatas.drop4
    end

    printx(15,"actDatas",tts(actDatas))

    return actDatas
end

function Manager:__getDropNum(star, id)
    local tag1 = self:getData():getDataByKey('tag372')
    local dropNum
    if star == 1 then
        if id ~= "60" then
            if id == "53" then
                dropNum = math.random(1,2) > 1 and 1 or 2
            else
                dropNum = 2
            end
        else
            if tag1 < 0.2 then
                dropNum = math.random(1,10) > 2 and 2 or 3
            elseif tag1 < 0.5 then
                dropNum = math.random(1,10) > 2 and 2 or 3
            elseif tag1 < 0.7 then
                dropNum = math.random(1,10) > 4 and 2 or 3
            elseif tag1 < 0.8 then
                dropNum = math.random(1,10) > 6 and 2 or 3
            elseif tag1 < 0.9 then
                dropNum = math.random(1,10) > 8 and 2 or 3
            else
                dropNum = 3
            end
        end
    elseif star == 3 then
        if id ~= "61" then
            dropNum = math.random(1,2) > 1 and 1 or 2
        else
            if tag1 < 0.2 then
                dropNum = math.random(1,10) > 6 and 1 or 2
            elseif tag1 < 0.5 then
                dropNum = math.random(1,10) > 2 and 1 or 2
            elseif tag1 < 0.7 then
                dropNum = 1
            elseif tag1 < 0.8 then
                dropNum = 1
            elseif tag1 < 0.9 then
                dropNum = 1
            else
                dropNum = 1
            end
        end
    elseif star == 4 then
        if id == "61" then
            dropNum = 2
        else
            dropNum = 1
        end
    end

    return dropNum
end

function Manager:setFixedResult(star1Drop, star3Drop, star4Drop)
    self.fixedStar1Drop = nil
    self.fixedStar3Drop = nil
    self.fixedStar4Drop = nil

    if star1Drop and tonumber(star1Drop) > 0 then
        self.fixedStar1Drop = star1Drop
    end

    if star1Drop and tonumber(star3Drop) > 0 then
        self.fixedStar3Drop = star3Drop
    end

    if star1Drop and tonumber(star4Drop) > 0 then
        self.fixedStar4Drop = star4Drop
    end
end

function Manager:getCurAvailableBuffAndEndTime()
    if self:canUse20Buff() then
        return 0.2, self:get20BuffEndTime()
    end

    return 0, 0
end

function Manager:hasAvailableBuff(data)
    return self:canUse20Buff()
end

function Manager:getScoreBuffTypeList()
    return { 20 }
end

function Manager:get20BuffEndTime()
    local buffEndTime = self:getLocalDataServer():getDataByKey('buffEndTs')
    if buffEndTime then
        return math.floor(tonumber(buffEndTime)/1000)
    end
    return 0
end

function Manager:canUse20Buff()
    return TimeKit:timeInSec() < self:get20BuffEndTime()
end

--------------------- 关卡内over --------------------------
function Manager:getActInfo()
    return _G.amfBean("ActivityMgr"):getActInfo(Manager.ACT_ID)
end

function Manager:getPayTag()
    local payTag = self:getData():getDataByKey('payTagId')
    local actInfo = self:getActInfo()
    if actInfo then
        local extra = table.deserialize(actInfo.extra or '' ) or {}
        if extra and extra.payTagId then
            payTag = extra.payTagId
        end
    end
    local PAYTAG_KEY = {
        [0] = 'NONE',
        [1] = 'ZERO',
        [2] = 'LOW',
        [3] = 'MIDDLE_LOW',
        [4] = 'MIDDLE_HIGH',
        [5] = 'HIGH_4',
        [6] = 'HIGH_5',
        [7] = 'HIGH_6'
    }
    return payTag,PAYTAG_KEY[payTag]
end


-- 在新关开启的指定时间内（暂定4小时），玩家主线关满星前，闯头部新关不触发关卡内结算面板点叉的场景3\4强弹
function Manager:ignoreForTopLevelPlayer()
    local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    if userState == _G.UserStateConst.UserSegmentState.MHZC  then
        return false
    end

    if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then
        return false
    end

    return true
end
-- 强弹检查，场景3
function Manager:checkPopFunctionStage3()
    if not self:isEnabled() then
        return
    end


    if not self:canOpenLimitMenu() then
        self:logD('场景 3 不能开启限时菜谱')
        return false
    end

    if self:getData():canTriger() and not self:isInLimitTime() then
        return true
    end

    return false
end

function Manager:popFunctionStage3(onHandleOver2,testNum)
    if not self:isEnabled() then
        safeRunCall(onHandleOver2)
        return
    end
    local onHandleOver = function()
        safeRunCall(onHandleOver2)
    end
    local meta = self:getData():getDataByKey("temporaryMenuList",{})

    local isFestival = self:getData():getDataByKey("festival")
    if isFestival then
        local finishMenu = self:getData():getFinishedMenu()
        local newMeta = {}
        for k,v in pairs(meta) do
            local hasDoMenu = false
            for _,menuId in pairs(finishMenu)do
                if menuId == v.menuId then
                    hasDoMenu = true
                end
            end
            if not hasDoMenu then
                table.insert(newMeta,v)
            end
        end

        if not testNum and not table.isEmpty(newMeta) then
            meta = newMeta
        end
    end
    local num = testNum or math.random(1,#meta)
    local menuId = meta[num].menuId
    local payTag,payKey = self:getPayTag()
    local temporaryGoodsMetaList = self:getData():getDataByKey("temporaryGoodsMetaList",{})
    local goodsId = 0
    for k,v in ipairs(temporaryGoodsMetaList) do
        if v.userTagPayV2 == payKey then
            goodsId = v.lastGoodsId
        end
    end
    if goodsId == 0 then safeRunCall(onHandleOver) return end

    self:canteenTrigger(menuId,goodsId,function()
        if not self:isEnabled() then
            safeRunCall(onHandleOver2)
            return
        end
        if self:ignoreForTopLevelPlayer() then
            self:logD('场景 3 周五新关不弹出')
            safeRunCall(onHandleOver)
            return
        end
        self:showYinliu(function()
            safeRunCall(onHandleOver)
        end)
    end,function()
        safeRunCall(onHandleOver)
    end,function()
        safeRunCall(onHandleOver)
    end)


end

function Manager:canShowSharePanel3()
    local isFestival = self:getData():getDataByKey("festival")
    local hasGot = self:getData():getDataByKey("gotTemporaryMenuShowReward")
    if not isFestival or hasGot then return false end
    local meta = self:getData():getDataByKey("temporaryMenuList",{})
    local hasDoAllMenu = true
    for k,v in pairs(meta) do
        local finishMenu = self:getData():getFinishedMenu()
        local hasDoMenu = false
        for _,menuId in pairs(finishMenu)do
            if menuId == v.menuId then
                hasDoMenu = true
            end
        end
        hasDoAllMenu = hasDoAllMenu and hasDoMenu
    end
    return hasDoAllMenu
end


function Manager:showYinliu(done)
    local panel = require_debug("amf.feature.localactivity.canteen.view.YinliuPanelVM")
    local vm = panel:create(done)
    vm:popout()
    self:managePanelVM(vm)
end




function Manager:checkPopFunctionStage4()
    local canPopYinliu = self:canPopYinliu()
    local canPopGiftPanel = self:canPopGiftPanel()
    return canPopYinliu or canPopGiftPanel
end

function Manager:canPopGiftPanel()
    if self:getData():getDailyCache(self:getConst().popGiftStage4Key,false) then
        self:logD('场景 4 礼包 今日弹出过')
        return false
    end

    if not self:isInLimitTime() then
        self:logD('场景 4 礼包 不在开启时间')
        return false
    end

	local passLevelTime = self:getData():getDailyCache(self:getConst().limitTimePassLevelKey,0)
    if passLevelTime < self:getConst().giftPopoutLimit then
        self:logD('场景 4 礼包 过关次数不足',passLevelTime)
        return false
    end
    return true
end

function Manager:canPopYinliu()
    if self:getData():getDailyCache(self:getConst().popYinLiuStage4Key,false) then
        self:logD('场景 4 引流 今日弹出过')
        return false
    end


    if not  self:canMakeMenu() then
        self:logD('场景 4 引流 没法制作')
        return false
    end
    return true
end

function Manager:popFunctionStage4(onHandleOver2)
    if not self:isEnabled() then
        safeRunCall(onHandleOver2)
        return
    end
    local canPopYinliu = self:canPopYinliu()
    local canPopGiftPanel = self:canPopGiftPanel()

    if canPopYinliu and canPopGiftPanel then
        self:popGiftPanelStage4(function()
            self:popYinliuStage4(onHandleOver2)
        end)
    elseif canPopYinliu then
        self:popYinliuStage4(onHandleOver2)
    else
        self:popGiftPanelStage4(onHandleOver2)
    end
end

function Manager:popGiftPanelStage4(done)
    if not self:isEnabled() then
        safeRunCall(done)
        return
    end
    self:getData():setDailyCache(self:getConst().popGiftStage4Key,true)
    return self:popGiftPanel(done)
end



function Manager:popYinliuStage4(done)
    if not self:isEnabled() then
        safeRunCall(done)
        return
    end
    self:getData():setDailyCache(self:getConst().popYinLiuStage4Key,true)
    -- self.dcHelper:sendDC("chef_god",'attract_panel_show')
    self:showYinliuStage4(done)

end
function Manager:loadRes(delegate)
    delegate = delegate or {}
    if not delegate.resList then
        safeRunCall(delegate.failCallback)
        return
    end
    self:callDownloadFunc("getAssetsUtil"):loadMiniFiles(delegate.resList)
        :next(delegate.successCallback, delegate.failCallback)
end


function Manager:showYinliuStage4(done)
    self:loadRes({
        resList = {
            "amf/activity/canteen/texture/YinliuPanel2.plist"
        },
        successCallback = function()
            self:doShowYinliuStage4(done)
        end,
        failCallback = function()
            printx(29,"downloadfails")
            safeRunCall(done)
        end
    })
end

function Manager:doShowYinliuStage4(done)
    local path = 'amf.feature.localactivity.canteen.view.uisource.YinliuPanel2_UI.lua'
    local uiData = require(path)
    local bgChilds = {}
    UICreateUtil:loadPlist("amf/activity/canteen/texture/YinliuPanel2.plist")
    local commonBg, _ = UIBuilder:buildUI(uiData, bgChilds, 'bg')
    bgChilds.title:setString('厨神食堂')
    -- LayoutUtil:move(bgChilds.closeBtn,-5,-25)
    local DrainagePanelVM = require 'amf.middleware.ui.kit.panel.second.DrainagePanelVM'
    local panel
    local goCall = function()
        self:openActivity(nil, {
            fromYinliu = true
        }, true)
    end

    local showRewards = {{
        itemId = 14,
        num = 0,
        iconCreator = function()
            return GameItemCreator:createRandomIcon(RandomIconType.kSuperiorProp,
                CustomWidgetType.kRandom)
        end
    }, {
        itemId = 14,
        num = 0,
        needNum = false
    }, {
        itemId = self:getConst().headFrameTypeId,
        num = 0
    }}

    panel = DrainagePanelVM.Builder:new()
    :setRewardButton('去领奖', goCall)
    :pushDesc('你已经积累了很多食材啦，快去\n完成菜品领取奖励吧~')
    :pushBlock(showRewards,'海量好礼')
    :setCloseCallback(done)
    :setBg(commonBg)
    :setCloseBtnPos(ccp(560,-50))
    :build()
    self.dcHelper:sendDC("chef_god", "attract_panel_show")
    self:managePanelVM(panel, 'YinliuPanel2')
    panel:popout()

end


----------------------------一期优化 to 关卡外-------------------------------------
--替换的掉落物A ，可能为空不替换
function Manager:getReplaceId()
    local materials2LevelIdMap = {
        [self:getConst().materialIds.material_N_1_1] = "52",
        [self:getConst().materialIds.material_N_1_2] = "53",
        [self:getConst().materialIds.material_N_1_3] = "54",
        [self:getConst().materialIds.material_N_1_4] = "55",
        [self:getConst().materialIds.material_N_2_1] = "56",
        [self:getConst().materialIds.material_N_2_2] = "57",
        [self:getConst().materialIds.material_N_3_1] = "58",
        [self:getConst().materialIds.material_N_3_2] = "59",
        [self:getConst().materialIds.kSpA] = "60",
        [self:getConst().materialIds.kSpB] = "61",
    }

    local material = self:getData():getA() or 0
    return materials2LevelIdMap[material] or "0"
end

-- 挽留面板UI
function Manager:createRetentionUI(collectionMap) --todo 是不是关卡内全部接入了
    -- local menuId,newCompleteList = self:getCanMakeIdWhenGet(collectionMap)
    -- local InLevelShow = require"localActivity.CanTeen.views.InLevelShow"
    -- local layer = Layer:create()
    -- local content = InLevelShow:create({
    --     menuId = menuId,
    --     newCompleteIdList = newCompleteList
    -- })
    -- content:setPositionXY(-234,51)
    -- layer:addChild(content)

    -- return layer
end
-- 获取如果获得食材可以制作的菜品ID，可能为空，前端ID
-- Meta.menuName = {
--     [0] = "",
--     [1] = "煎蛋拉面",
--     [2] = "小鸡炖蘑菇",
--     [3] = "四喜丸子",
--     [4] = "糖醋鲤鱼",
--     [5] = "佛跳墙",
--     [112] = "蒜蓉虾球",
--     [113] = "北京烤鸭",
--     [120] = "肥牛火锅",
-- }

function Manager:getCanMakeMenuNum(menuBean,materialMap,addMap)
    local map = table.clone(materialMap)
    if addMap then
        for k,v in pairs(addMap) do
            map[k] = map[k] or 0
            map[k] = map[k] + addMap[k]
        end
    end
    local nowMap = map


    local multipleMap = function(materialMultiple,defaultMaterialArr)
        local map = {}
        for k,v in pairs(defaultMaterialArr) do
            if type(v) == "table" and v.baseNeedCount then
                map[tostring(v.materialId)] = math.ceil(tonumber(v.baseNeedCount) * materialMultiple)
            else
                map[k]  = math.ceil(v * materialMultiple)
            end
        end
        return map
    end

    local decMap = function(map1,map2)
        for k,v in pairs(map2) do
            if map1[k] then
                map1[k] = map1[k] - map2[k]
            end
        end
        return map1
    end
    local getCanMakeTimes = function(needMap,haveMap)
        local canMakeNum = 999999
		for id,needNum in pairs(needMap) do
            local numFromData = haveMap[id] or 0
            local oldMakeNum = math.floor(numFromData / needNum)
            canMakeNum = math.min(oldMakeNum,canMakeNum)
		end
        return canMakeNum
    end

    local menuMetaList = self:getData():getDataByKey('menuMetaList')
    local menuId = menuBean.menuId
    local nowMakeTime = menuBean.makeTimes
    local allCanMakeTime = 0
    for id,v in ipairs(menuMetaList) do
        if v.menuId and v.menuId == menuId then
            local expandMeta = v.expandMeta
            local defaultMaterialArr = v.defaultMaterialArr
            local multiple = expandMeta and expandMeta.defaultMaterialMultiple or 1
            if not expandMeta or not expandMeta.detailMetaList or table.isEmpty(expandMeta.detailMetaList) then
                return getCanMakeTimes(menuBean.needMaterialMap,nowMap)
            end

            local useMetalist = table.union(
                {
                    {
                        needTimes = 0 ,
                        materialMultiple = multiple
                    },
                },
                table.clone(expandMeta.detailMetaList)
            )

            for k,meta in ipairs(useMetalist) do
                local nextNeedTimes = useMetalist[k+1] and useMetalist[k+1].needTimes
                local canMakeThisExpand = false
                if nowMakeTime >= meta.needTimes and (not nextNeedTimes or nextNeedTimes > nowMakeTime ) then
                    canMakeThisExpand = true
                    multiple = meta.materialMultiple
                end
                if canMakeThisExpand then
                    local needMap = multipleMap(multiple,defaultMaterialArr)
                    printx(29,"当前的食材需求应该是",tts(needMap),"当前的数据显示",tts(menuBean.needMaterialMap ),v.menuId)
                    local canMakeTime = getCanMakeTimes(needMap,nowMap)
                    if nextNeedTimes and canMakeTime > (nextNeedTimes - nowMakeTime) then
                        allCanMakeTime = allCanMakeTime + nextNeedTimes - nowMakeTime
                        nowMap = decMap(nowMap,multipleMap(nextNeedTimes - nowMakeTime,needMap))
                        printx(29,'增加了A',allCanMakeTime,nextNeedTimes,nowMakeTime)
                        nowMakeTime = nextNeedTimes
                    else
                        allCanMakeTime  = allCanMakeTime + canMakeTime
                        printx(29,'增加了B',allCanMakeTime,canMakeTime)
                    end
                end
            end
            break
        end
    end
    return allCanMakeTime
end

function Manager:getCanMakeIdWhenGet(collectionMap)
    local materialsMapFromLevel = {
        [self:getConst().materialIds.material_N_1_1] = collectionMap["52"],
        [self:getConst().materialIds.material_N_1_2] = collectionMap["53"],
        [self:getConst().materialIds.material_N_1_3] = collectionMap["54"],
        [self:getConst().materialIds.material_N_1_4] = collectionMap["55"],
        [self:getConst().materialIds.material_N_2_1] = collectionMap["56"],
        [self:getConst().materialIds.material_N_2_2] = collectionMap["57"],
        [self:getConst().materialIds.material_N_3_1] = collectionMap["58"],
        [self:getConst().materialIds.material_N_3_2] = collectionMap["59"],
        [self:getConst().materialIds.kSpA] = collectionMap["60"],
        [self:getConst().materialIds.kSpB] = collectionMap["61"],
    }
    printx(229,'\n\n开始检测能否挽留，关卡内参数',tts(materialsMapFromLevel))
    if not self.logs then self.logs = { } end
    table.insert(self.logs,"过关获得以下道具时" .. tts(materialsMapFromLevel))
	local menuList2 = table.clone(self:getData():getDataByKey('menuList',{}))

	local menuList = {}
    for k,v in ipairs(menuList2) do
        if v then table.insert(menuList,v) end
    end

    table.sort(menuList,function(a,b)
        if not a then return false end
        if not b then return true end
        return a.menuId > b.menuId
    end )
	local materialMap = table.clone( self:getData():getDataByKey('materialMap',{},false))
    local newCompleteList = {}
    for k,v in ipairs(menuList) do
        if not v then
            break
        end
        -- local canMakeNum1 = 999999
        -- local canMakeNum2 = 999999
		-- for id,needNum in pairs(v.needMaterialMap) do
        --     local numFromData = materialMap[id] or 0
        --     local numFromLevel = materialsMapFromLevel[id] or 0
        --     local oldMakeNum = math.floor(numFromData / needNum)
        --     local newMakeNum = math.floor((numFromData + numFromLevel)/ needNum)
        --     canMakeNum1 = math.min(oldMakeNum,canMakeNum1)
        --     canMakeNum2 = math.min(newMakeNum,canMakeNum2)
        --     if newMakeNum > oldMakeNum and oldMakeNum == 0 then
        --         table.insert(newCompleteList,id)
        --     end
		-- end
        -- --待优化
        local canMakeNum1 = self:getCanMakeMenuNum(v,materialMap)
        local canMakeNum2 = self:getCanMakeMenuNum(v,materialMap,materialsMapFromLevel)
        printx(29,'菜谱'..v.menuId.."可制作次数前后区别"..canMakeNum1 .. ":".. canMakeNum2)
        table.insert(self.logs,'菜谱'..v.menuId.."可制作次数前后区别"..canMakeNum1 .. ":".. canMakeNum2)
        if canMakeNum2 > canMakeNum1 then
            if canMakeNum1 == 0 then
                for id,needNum in pairs(v.needMaterialMap) do
                    local numFromData = materialMap[id] or 0
                    local oldMakeNum = math.floor(numFromData / needNum)
                    if oldMakeNum == 0 then
                        table.insert(newCompleteList,id)
                    end
                end
            end
            printx(229,'厨神食堂，可制作的菜谱', v.menuId,tts(newCompleteList))
            table.insert(self.logs,'厨神食堂，新增可制作的菜谱'.. v.menuId .. "过关后可制作" .. canMakeNum2 .. "次，之前可制作" .. canMakeNum1 .. "次")
            table.insert(self.logs,"刚刚完成的食材需求"..tts(newCompleteList).."\n")

            return v.menuId,newCompleteList
        end
    end
    printx(229,'厨神食堂，可制作的菜谱','无',tts(newCompleteList))
    table.insert(self.logs,'厨神食堂没有新增可制作的菜谱\n')
    return nil ,{}
end

function Manager:getLogs()
    if not self.logs then
        return "未找到活动信息"
    end
    local str = ''
    for k,v in ipairs(self.logs) do
        str = str .. v .. '\n'
    end
    return str
end

---rewards
function Manager:addRewardsWhenBought(goodsId, rewardItems, params)
    self:callPlug("Rewards","addRewardsWhenBought",goodsId, rewardItems, {
        dcExtra = params
    })
end

-- function Manager:getDcFeatureAndSource( suffix )
--     suffix = suffix or 0
--     local dcFeature, dcSource = self.GAME_NAME,suffix
--     return dcFeature, dcSource
-- end

-- 商城加奖励
function Manager:addRewardsForShop( rewardBean, params ,dateAddEndCall, evt )
    self:callPlug("Rewards","addRewardsForShop",rewardBean, {
        dcExtra = params
    },dateAddEndCall,evt)
--     local dcFeature, dcSource = self:getDcFeatureAndSource(params.dcSource)

--    local param = {
--         rewardList = rewardBean.rewardList,
--         repeatList = rewardBean.repeatList,
--         rewardDirectList = rewardBean.rewardDirectList,
--         yuanBaoList = rewardBean.yuanBaoList,
--         feature = dcFeature,
--         source = dcSource,
--         endCall = function (notCardMap, cardMap)
--             notCardMap = notCardMap or {}
--             if not table.isEmpty(notCardMap) then
--                 self:addRewardsNormal(notCardMap, {dcSource = dcSource})
--             end
--             -- _G.amfTransaction(TransactionEvent.EXCHANGE_SHOP_SHOW_REWARD, delegate)
--         end
--     }
--     _G.amfTransaction(TransactionEvent.EXCHANGE_SHOP_ADD_REWARD, param)
end

------------------------------------
------------------志刚
------------------

function Manager:managePanelVM(vm)
    self:callPlug("Panel","managePanelVM",vm)
    -- if not vm or vm.isDisposed then
    --     return
    -- end
    -- panelName = panelName or "UnknownPanel" .. TimeKit:timeInMillis()
    -- vm.panelName = panelName

    -- local this = self

    -- local oriFunc = vm.recycle
    -- vm.recycle = function(obj)
    --     this:removeObserver(obj)
    --     safeRunCall(oriFunc, obj)
    -- end

    -- local oriFunc = vm.onActCloseAllPanel
    -- vm.onActCloseAllPanel = function(obj)
    --     safeRunCall(oriFunc, obj)
    --     if obj.isDisposed then
    --         return
    --     end
    --     if obj.close then
    --         obj:close(true)
    --     else
    --         obj:_close()
    --     end
    -- end

    -- vm.getPanelName = function(obj)
    --     return obj.panelName
    -- end

    -- self:addObserver(vm)
end

function Manager:popGiftPanel(done)
    local GiftPanelVM = require 'amf.feature.localactivity.canteen.view.GiftPanelVM'
    local panel = GiftPanelVM:create({
        goodsId = self:getData():getDataByKey('goodsId'),
        closeCallback = done,
        endTime = self:getData():getDataByKey('goodsExpireAtTs', 0) / 1000,
        userClick = false,
    })
    panel:popout()
    self:managePanelVM(panel)
end

function Manager:getTodayOfAct()
    local time = TimeKit:timeInSec()
    local actTime = self:getData():getActMainBeginTime()
    local stTime = TimeKit:getDayStartTimeByTS2(actTime)
    local dt = math.ceil((time - stTime) / (3600 * 24))
    return dt
end

function Manager:getMenuGuideId(menuId)
    return self:getConst().guideIds['MENU_'..menuId]
end

-- 做完菜添加引导,从小到大
function Manager:addHandBook(menuId)
    local guideId = self:getMenuGuideId(menuId)
    if self:hasGuideIndex(guideId, true) then return end
    local handBook = self:getHandBook()
    if not table.includes(handBook, menuId) then
        handBook[#handBook + 1] = menuId
        table.sort(handBook, function(a, b)
            return a < b
        end)
    end
end

function Manager:getHandBook()
    if not self.handBook then
        self.handBook = {}
        local finishMenu = self:getData():getFinishedMenu()
        for _,v in pairs(finishMenu)do
            self:addHandBook(v)
        end
    end
    return self.handBook
end

-- 清空仍未弹出的引导，加标记不再弹出
function Manager:clearHandBook()
    local handBook = self:getHandBook()
    for _,v in pairs(handBook)do

        local guideId = self:getMenuGuideId(v )
        self:addGuideIndex(guideId, true)
    end
    self.handBook = nil
end

--从图鉴取出id最大的，删除并加引导
function Manager:getLastHandBookIdAndClean()
    local handBook = self:getHandBook()
    if #handBook == 0 then return end
    local id = handBook[#handBook]
    handBook[#handBook] = nil
    local guideId = self:getMenuGuideId(id)
    self:addGuideIndex(guideId, true)
    return id
end

function Manager:createZanIcon()
    local res = self:getConst().dianzanRes
    return Sprite:create(res)
end


function Manager:createScoreBuffId(reward)

    local addPercent = 0
    if reward.itemId == self:getConst().scoreBuff20Id then
        addPercent = 120
    end

    local item = Sprite:createWithSpriteFrameName("other/iconV2/ui_icon_star_02_v2")

    local scoreTitleLabel = TTFLabel:createAnimalYH('分数', 18)
    scoreTitleLabel:setTextColor(hex2ccc4('e6830cff'))
    scoreTitleLabel:setPositionXY(45, 85)
    item:addChild(scoreTitleLabel)

    local scoreLabel = TTFLabel:createAnimalYH('x' .. addPercent .. '%', 18)
    scoreLabel:setAnchorPoint(ccp(0.5, 0.5))
    scoreLabel:setPositionXY(63, 54)
    scoreLabel:setTextColor(hex2ccc4('e6830cff'))
    scoreLabel:enableOutline(hex2ccc4('ffffffff'), 2)
    item:addChild(scoreLabel)

    local p = AMFCompHelper:createInfiniteTimeLimitWidget(reward,false,true)
    item:addChild(p)
    item.timeFlag = p

    return item
end
--领排行榜奖励
function Manager:canteenRankReward(successCallback, failCallback)
    local function onSuccess(evt)
        local data = evt.data or {}
        if data.groupRankReward then
            self:addRewardsForShop(data.groupRankReward.reward.rewardDirectList, {
                dcSource = "rank_reward",
            },function()
            end,evt)
        end
        local nationalRankRewardList = {}
        local minRank = 9999
        local lastDay = 0
        if data.nationalDailyRankRewardMap then
            for k,v in pairs(data.nationalDailyRankRewardMap) do
                table.merge(nationalRankRewardList,v.reward.rewardDirectList)
                -- v.dayOfIndex = tonumber(k)
                if v.rank > 0 then minRank = math.min(v.rank,minRank) end
                lastDay = math.max(lastDay,tonumber(k))
            end
            self:addRewardsForShop(nationalRankRewardList, {
                dcSource = "rank_reward",
            },function(callData)
                safeRunCall(successCallback, callData ,data.groupRankReward,minRank,lastDay)
            end,evt)

        end
        self:getData():setDataByKey('canGetNationalDailyRankReward',false)
        self:getData():setDataByKey('canGetGroupRankReward',false)
    end

    local function onFail(evt)
        CommonTip:showErrorTip(evt)
        safeRunCall(failCallback)
    end

    local function onCancel()
        safeRunCall(failCallback)
    end

    local canteenRankReward = require 'amf.feature.localactivity.canteen.http.canteenRankReward'
    canteenRankReward:post({},false):next(onSuccess, function(response)
        if response:isCancel() then
            safeRunCall(onCancel, response)
        else
            safeRunCall(onFail, response)
        end
    end)
end
------------------------------------


----------本地key缓存
function Manager:setCache()

end

function Manager:getCache()

end


-- -- 本地缓存
-- function Manager:setLocalValueByKey(key, needTime, value, needActStartTimeCheck)
--     if not key then return end
--     if bSkip == nil then bSkip = true end

--     local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
--     local actBeginTime = self:getData():getActMainBeginTime() or 0

--     local saveValue = {
--         time = nowTime,
--         value = value,
--         actBeginTime = actBeginTime,
--     }
--     local saveStr = table.serialize(saveValue)

--     self:getData():setValue(key, saveStr, true)
-- end

-- function Manager:getLocalValueByKey(key, needTime, needActStartTimeCheck)
--     if not key then return end
--     local saveJsonStr = self:getData():getValue(key)
--     if saveJsonStr == nil then return end
--     if type(saveJsonStr) ~= "string" then return end

--     local saveTable = table.deserialize(saveJsonStr)

--     local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
--     local actBeginTime = self:getData():getActMainBeginTime() or 0

--     local bTimeIsOk = true
--     if needTime then
--         if saveTable.time ~= nowTime then
--             bTimeIsOk = false
--         end
--     end

--     local versionIsOk = true
--     if needActStartTimeCheck then
--         if saveTable.actBeginTime ~= actBeginTime then
--             versionIsOk = false
--         end
--     end

--     if bTimeIsOk and versionIsOk then
--         return saveTable.value
--     end
-- end

-- -- 本地缓存 bool
-- function Manager:saveFlagToLocalByKey(key, needTime, value, needActStartTimeCheck)
--     if value == nil then value = true end
--     self:setLocalValueByKey( key, needTime, value, needActStartTimeCheck )
-- end

-- function Manager:getFlagFromLocalByKey(key, needTime, needActStartTimeCheck)
--     local defaultValue = false
--     local result = self:getLocalValueByKey(key, needTime, needActStartTimeCheck)
--     if result == nil then
--         return defaultValue
--     else
--         return result
--     end
-- end


-- -- 本地缓存int
-- function Manager:saveFlagToLocalByKeyInt(key, needTime, value, needActStartTimeCheck)
--     if value == nil then value = 0 end
--     self:setLocalValueByKey( key, needTime, value, needActStartTimeCheck )
-- end

-- function Manager:getFlagFromLocalByKeyInt(key, needTime, needActStartTimeCheck, defaultValue)
--     if defaultValue == nil then defaultValue = 0 end

--     local result = self:getLocalValueByKey(key, needTime, needActStartTimeCheck)
--     if result == nil then
--         return defaultValue
--     else
--         return result
--     end
-- end

-- -- 本地缓存str
-- function Manager:saveFlagToLocalByKeyStr(key, needTime, value, needActStartTimeCheck)
--     if value == nil then value = "" end
--     self:setLocalValueByKey( key, needTime, value, needActStartTimeCheck )
-- end

-- function Manager:getFlagFromLocalByKeyStr(key, needTime, needActStartTimeCheck)
--     local defaultValue = ""

--     local result = self:getLocalValueByKey(key, needTime, needActStartTimeCheck)
--     if result == nil then
--         return defaultValue
--     else
--         return result
--     end
-- end



function Manager:needBlockPassLevelBlank()
    return true --App上用的，暂时保留下。
end

function Manager:needBlockGetAllBtn()
    return false
end


function Manager:canteenMake(menuId,fromMainPanel, sucessCall, failCall, cancelCall)
    local function onSuccess(evt)
        self:getData():onMenuMake(menuId)
        local data = evt.data
        self:getData():setDataByKey('score', data.score)
        self:getData():setDataByKey('groupRank', data.groupRank)
        self:addHandBook(menuId)
        self:getData():setNewMenu(menuId, data.nextMenu)
        if data.materialMap then
            self:getData():setDataByKey("materialMap",data.materialMap)
        end
        self:updateTipView()
        self:addRewardsForShop(data.rewardBean.rewardDirectList ,{
            dcSource = fromMainPanel and 'main_panel_reward' or 'pass_click'
        },function(callData)
            safeRunCall(sucessCall,callData ,data.transBeanList)
            -- sucessCall(callData ,data.transBeanList)
        end,evt)
    end

    local function onFail(evt)

        CommonTip:showErrorTip(evt)
        safeRunCall(failCall)
    end

    local function onCancel()
        safeRunCall(cancelCall)
    end

    local canteenMakeV2 = require 'amf.feature.localactivity.canteen.http.canteenMake'
    canteenMakeV2:post({
        menuId = menuId
    },false):next(onSuccess, function(response)
        if response:isCancel() then
            safeRunCall(onCancel, response)
        else
            safeRunCall(onFail, response)
        end
    end)

end

function Manager:canteenTrans(menuId, sucessCall, failCall, cancelCall)
    local function onSuccess(evt)

        local lowNum = self:getData():getSpANum()
        local highNum = self:getData():getSpBNum()
        self.dcHelper:sendDC("chef_god","exchange_reward",{
            t1 = lowNum or 0 ,
            t2 = highNum or 0
        })

        self:getData():setLimitTimeMenuOver(menuId)
        self:getData():setNewMenu(menuId, nil)
        local data = evt.data
        for k, v in ipairs(data.transBeanList) do
            self:addRewardsNormal(v.rewardBeanList,{
                dcSource = 'exchange_reward'
            })
        end
        safeRunCall(sucessCall, data.transBeanList)
    end

    local function onFail(evt)

        CommonTip:showErrorTip(evt)
        safeRunCall(failCall)
    end

    local function onCancel()
        safeRunCall(cancelCall)
    end

    local canteenTrans = require 'amf.feature.localactivity.canteen.http.canteenTrans'
    canteenTrans:post({
        menuId = menuId
    },false):next(onSuccess, function(response)
        if response:isCancel() then
            safeRunCall(onCancel, response)
        else
            safeRunCall(onFail, response)
        end
    end)
end


function Manager:canteenMakeAll(sucessCall, failCall, cancelCall)
    local function onSuccess(evt)
        local data = evt.data
        for k,v in pairs(data.makeResultList) do
            local menuId = v.menuId
            self:getData():setMenuMakeOver(menuId)
            self:addHandBook(menuId)
            local menuBean = self:getData():getMenuById(menuId)
            v.addNum = v.nextMenu.makeTimes - menuBean.makeTimes
            self:getData():setNewMenu(menuId, v.nextMenu)

        end
        local data = evt.data
        data.rewardBean.rewardDirectList = table.mergeRewards(data.rewardBean.rewardDirectList)
        self:getData():setDataByKey("materialMap",data.materialMap)
        self:getData():setDataByKey('score', data.score)
        self:getData():setDataByKey('groupRank', data.groupRank)
        self:addRewardsForShop(data.rewardBean.rewardDirectList ,{
            dcSource = 'main_panel_reward'
        },function(callData)
            safeRunCall(sucessCall, data.makeResultList ,callData)
        end,evt)
        self:updateTipView()
    end

    local function onFail(evt)
        CommonTip:showErrorTip(evt)
        safeRunCall(failCall)
    end

    local function onCancel()
        safeRunCall(cancelCall)
    end


    local canteenMakeV2 = require 'amf.feature.localactivity.canteen.http.canteenMakeV2'
    canteenMakeV2:post({},false):next(onSuccess, function(response)
        if response:isCancel() then
            safeRunCall(onCancel, response)
        else
            safeRunCall(onFail, response)
        end
    end)
end


function Manager:canGetRewardsForShow()
    -- printx(36,"can get share rewards")
    -- return true

    if self:hasGetRewardsForShow(1) then return false end
    local cfg = self:getData():getNormalMenuCfg()
    local finishMenu = self:getData():getFinishedMenu()
    for _, v in pairs(cfg) do
        local id = v.menuId
        if not table.includes(finishMenu, id) then return false end
    end
    return true
end


function Manager:canteenTrigger(menuId, goodsId, sucessCall, failCall)
    self:getData():setLimitMenuAndGift(menuId, goodsId)
    self:getData():onTriger()
    local function onSuccess(evt)
        -- local data = evt.data
        -- if data and data.result == 1 then
        --     self:getData():setLimitMenuAndGift(menuId, data.goodsId, data.goodsExpireAtTs)
        -- else
        --     -- safeRunCall(failCall)
        -- end
    end

    local function onFail(evt)
        -- safeRunCall(failCall)
    end

    local function onCancel()
        -- safeRunCall(failCall)
    end



    local canteenMakeV2 = require 'amf.feature.localactivity.canteen.http.canteenTrigger'
    canteenMakeV2:post({
        menuId = menuId,
        goodsId = goodsId
    },false):next(onSuccess, function(response)
        if response:isCancel() then
            safeRunCall(onCancel, response)
        else
            safeRunCall(onFail, response)
        end
    end)
    safeRunCall(sucessCall)

end


---

---------------------------------- CUSTOM_GAIN ----------------------------------

function Manager:_onCustomGain(event)
    local reward = event:getData()
    local itemId = reward.itemId
    if itemId == Meta.itemIds.kSpA or itemId == Meta.itemIds.kSpB then
        self:addActItem(reward)
    elseif itemId == Meta.scoreBuff20Id then
        self:getData():addScoreBuff(reward.num)
    end
end

function Manager:_onResolveIcon(event)
    local data = event:getData()
    local itemId = data.itemId
    if itemId ~= Meta.itemIds.kSpA and itemId ~= Meta.itemIds.kSpB then
        return
    end
    -- 万能食材默认 icon：ingredient_rand.png（无 menuId 上下文时的兜底）
    local frameName = Meta.preFrameName .. Meta.materialRes[Meta.itemId2MaterialsId[itemId]]
    data.callback({
        Atlas = Meta.foodResPath,
        Frame = frameName,
        IsPropPng = false,
    })
end

return Manager