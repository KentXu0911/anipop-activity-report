--- PropDebugPanel: 道具系统调试入口面板
--- 通过 PropDebugPanel.register(label, action) 注册按钮，popout() 弹出面板展示所有已注册按钮。
local VerticalScrollable = require "amf.middleware.ui.kit.component.old.VerticalScrollable"

local PropDebugPanel = class("PropDebugPanel", Layer)

local BTN_WIDTH = 400
local BTN_HEIGHT = 80
local BTN_GAP = 20
local LIST_TOP_MARGIN = 90
local LIST_BOTTOM_MARGIN = 40

-- 已注册的调试按钮列表，外部通过 PropDebugPanel.register() 添加
local _buttons = {}

local YYB_DEFAULT_REWARD_TEXT = "14:10,10001:1,10004:1"

local function formatNumber(value)
    if value == nil then
        return "-"
    end
    if math.floor(value) == value then
        return tostring(math.floor(value))
    end
    return tostring(value)
end

local function isDevelopMode()
    return EnvUtil and EnvUtil.isDevelopMode and EnvUtil:isDevelopMode()
end

local function parseYYBRewardText(text)
    local rewards = {}
    text = text or ""
    for itemIdText, numText in string.gmatch(text, "(%d+)%s*[:=,xX*]%s*(%d+)") do
        table.insert(rewards, {
            itemId = tonumber(itemIdText),
            num = tonumber(numText),
        })
    end
    return rewards
end

local function withYYBPanelTestRewards(downRewards, callback)
    local versionUpdateMgr = _G.amfBean("VersionUpdateManager")
    local oldAMFBean = _G.amfBean
    local oldGetUpdateInfo = versionUpdateMgr and versionUpdateMgr.getUpdateInfo
    local patched = true
    local mockUpdateInfo = { rewards = downRewards }

    local function restore()
        if not patched then return end
        if versionUpdateMgr then
            versionUpdateMgr.getUpdateInfo = oldGetUpdateInfo
        else
            _G.amfBean = oldAMFBean
        end
        patched = false
    end

    if versionUpdateMgr then
        versionUpdateMgr.getUpdateInfo = function()
            return mockUpdateInfo
        end
    else
        _G.amfBean = function(beanName, ...)
            if beanName == "VersionUpdateManager" then
                return {
                    getUpdateInfo = function()
                        return mockUpdateInfo
                    end,
                    getUpdateVersion = function()
                        return _G.bundleVersion or ""
                    end,
                    canPackageUpdate = function()
                        return false
                    end,
                    isVipDynamicUpdateReady = function()
                        return false
                    end,
                    isPackageReady = function()
                        return false
                    end,
                    openUpdatePanel = function()
                    end,
                    openDynamicUpdatePanel = function()
                    end,
                }
            end
            return oldAMFBean(beanName, ...)
        end
    end

    callback(restore, mockUpdateInfo)
end

local function popoutYYBUpdatePanelTest(downRewards)
    local mgr = _G.amfBean("YYBWashingPackageManager")
    local oldActInfo = mgr:getActInfo()
    local now = TimeKit:timeInSec()
    local mockActInfo = {
        actId = 9076,
        beginTime = tostring((now - 3600) * 1000),
        clickNum = "0",
        extra = table.serialize({
            actEndTime = (now + 86400) * 1000,
            heVersion = "1.151",
            endTime = 0,
            heUpdateUrl = "http://downloadapkmanimal.happyelements.cn/apk/154b5cd356f6e532db0a46ff4cc9c412.apk",
        }),
        maxProgress = 0,
        msgNum = 0,
        progress = 0,
        rank = 0,
        reward = false,
        rewardFlag = 0,
        see = true,
        specialBanActivity = false,
    }

    mgr:saveActInfo(mockActInfo)
    withYYBPanelTestRewards(downRewards, function(restore, mockUpdateInfo)
        local YYBUpdatePanelVM = force_require("amf.feature.localactivity.yybwashingpackage.view.YYBUpdatePanelVM")
        local panel = YYBUpdatePanelVM:create({
            userClick = true,
            closeCallBack = function()
                mgr:saveActInfo(oldActInfo)
                restore()
            end,
            extra = {
                mockUpdateInfo = mockUpdateInfo,
            },
        })
        panel:popout()

        local endTime = mgr:getEndTime()
        if endTime > 0 then
            panel:setActEndTime(endTime * 1000, function()
                CommonTip:showTip('活动已结束')
            end)
        end

        if panel.isDisposed then
            mgr:saveActInfo(oldActInfo)
            restore()
        end
    end)
end

local function showYYBRewardSelectPanel()
    local DebugInputPanel = force_require("amf.debug.testbtn.view.testview.DebugInputPanel")
    DebugInputPanel(
        "应用宝更新面板测试",
        "itemId:num,itemId:num",
        YYB_DEFAULT_REWARD_TEXT,
        function(text)
            local downRewards = parseYYBRewardText(text)
            if #downRewards == 0 then
                CommonTip:showTip("格式错误，例如 14:10,10001:1", 1)
                return
            end
            popoutYYBUpdatePanelTest(downRewards)
        end
    )
end

local function mergeGoodsItems(items)
    local result = {}
    local orderedIds = {}
    for _, item in ipairs(items or {}) do
        local itemId = tonumber(item.itemId)
        local num = tonumber(item.num) or 0
        if itemId then
            if result[itemId] == nil then
                result[itemId] = 0
                table.insert(orderedIds, itemId)
            end
            result[itemId] = result[itemId] + num
        end
    end
    table.sort(orderedIds)
    return result, orderedIds
end

local function getGoodsSellPrice(goodsObj)
    if not goodsObj or not goodsObj.getPrice then
        return nil
    end
    local ok, price = pcall(function()
        return goodsObj:getPrice()
    end)
    if ok then
        return tonumber(price)
    end
    return nil
end

local function buildGoodsPriceResult(goodsId)
    local goodsObj = _G.GoodsManager and _G.GoodsManager:getGoods(goodsId)
    if not goodsObj then
        return nil, "GoodsId不存在->" .. tostring(goodsId)
    end

    local propManager = _G.amfBean("PropManager")
    local PriceCalculator = force_require("amf.middleware.purchase.model.PriceCalculator")
    local sellPrice = getGoodsSellPrice(goodsObj)
    local calculator = sellPrice and PriceCalculator:create(goodsId, sellPrice) or nil
    local mergedItems, orderedIds = mergeGoodsItems(goodsObj:getItems())
    if #orderedIds == 0 then
        return nil, "商品没有配置道具->" .. tostring(goodsId)
    end

    local itemRows = {}
    local totalBasePrice = 0
    for _, itemId in ipairs(orderedIds) do
        local num = mergedItems[itemId]
        local basePrice = propManager:getPropTotalPriceBase(itemId, num)
        totalBasePrice = totalBasePrice + basePrice
        table.insert(itemRows, {
            itemId = itemId,
            num = num,
            basePrice = basePrice,
        })
    end

    for _, row in ipairs(itemRows) do
        local ratio = 0
        if totalBasePrice > 0 then
            ratio = row.basePrice / totalBasePrice * 100
        end
        row.ratio = ratio
        row.sellPrice = calculator and calculator:getItemSellPrice(row.itemId) or nil
    end
    return {
        goodsId = goodsId,
        goodsName = goodsObj.getName and goodsObj:getName() or "",
        sellPrice = sellPrice,
        totalBasePrice = totalBasePrice,
        rows = itemRows,
        hasCalculator = calculator ~= nil,
    }
end

local function createGoodsPriceLabel(text, fontSize, color)
    local label = TextField:create(tostring(text or ""), nil, fontSize or 22)
    label:setColor(hex2ccc3(color or "FFFFFFFF"))
    label:setAnchorPoint(ccp(0, 1))
    return label
end

local function createGoodsPriceCloseBtn(closeFunc)
    local btn = LayerColor:createWithColor(hex2ccc3("8B3A3AFF"))
    btn:setContentSize(CCSizeMake(90, 42))
    btn:setOpacity(240)

    local label = TTFLabel:createAnimalYH("关闭", 24)
    label:setAnchorPoint(ccp(0.5, 0.5))
    label:setTextColor(hex2ccc4("FFFFFFFF"))
    label:setPositionXY(45, 21)
    btn:addChild(label)

    btn:setTouchHandler(function()
        if closeFunc then closeFunc() end
    end)
    return btn
end

local function showGoodsPriceResultPanel(result)
    local size = CCSizeMake(620, 520)
    local layerColor = LayerColor:createWithColor(hex2ccc3("253041"))
    layerColor:setContentSize(size)
    layerColor:setOpacity(230)

    local y = size.height - 78
    local function addLabel(text, x, labelY, fontSize, color)
        local label = createGoodsPriceLabel(text, fontSize, color)
        label:setPositionXY(x, labelY)
        layerColor:addChild(label)
        return label
    end

    addLabel("goodsId:", 24, y, 24, "FFFFFFFF")
    addLabel(result.goodsId, 112, y, 24, "FFFFFFFF")
    addLabel("GoodsManager价格:", 250, y, 24, "FFFFFFFF")
    addLabel(formatNumber(result.sellPrice), 445, y, 24, "FFFFFFFF")
    y = y - 34
    addLabel("商品名: " .. tostring(result.goodsName), 24, y, 22, "FFFFFFFF")
    y = y - 42

    local colItemId = 24
    local colNum = 120
    local colBase = 210
    local colRatio = 330
    local colSell = 455
    addLabel("itemId", colItemId, y, 22, "FFE08AFF")
    addLabel("num", colNum, y, 22, "FFE08AFF")
    addLabel("基准价值", colBase, y, 22, "FFE08AFF")
    addLabel("价值占比", colRatio, y, 22, "FFE08AFF")
    if result.hasCalculator then
        addLabel("分摊结果", colSell, y, 22, "FFE08AFF")
    end
    y = y - 32

    for _, row in ipairs(result.rows or {}) do
        addLabel(row.itemId, colItemId, y, 22, "FFFFFFFF")
        addLabel(formatNumber(row.num), colNum, y, 22, "FFFFFFFF")
        addLabel(formatNumber(row.basePrice), colBase, y, 22, "FFFFFFFF")
        addLabel(string.format("%.2f%%", row.ratio or 0), colRatio, y, 22, "FFFFFFFF")
        if result.hasCalculator then
            addLabel(formatNumber(row.sellPrice), colSell, y, 22, "FFFFFFFF")
        end
        y = y - 28
        if y < 96 then
            addLabel("...", colItemId, y, 22, "FFFFFFFF")
            break
        end
    end

    addLabel("总基准价值", 24, 68, 26, "FFE08AFF")
    addLabel(formatNumber(result.totalBasePrice), colBase, 68, 26, "FFE08AFF")

    local ThirdPanelAVM = require "amf.middleware.ui.kit.panel.third.ThirdPanelAVM"
    local vm
    vm = ThirdPanelAVM.Builder.new()
    :setTitle("商品价值计算测试")
    :build()
    vm:popout()
    vm.view:addChild(layerColor)
    layerColor:setPositionXY(50, 430)

    local closeBtn = createGoodsPriceCloseBtn(function()
        vm:close()
    end)
    closeBtn:setPositionXY(size.width - 110, size.height - 56)
    layerColor:addChild(closeBtn, 10)
end

local function showGoodsPriceTestInputPanel()
    local size = CCSizeMake(500, 200)
    local layerColor = LayerColor:createWithColor(hex2ccc3("ba8944"))
    layerColor:setContentSize(size)
    layerColor:setOpacity(100)
    local inputStr = ""

    local function queryGoodsPrice(text)
        local goodsId = tonumber(text)
        if not goodsId then
            CommonTip:showTip("GoodsId不合法->" .. tostring(text), 1)
            return
        end
        local result, err = buildGoodsPriceResult(goodsId)
        if not result then
            CommonTip:showTip(err or "商品价值计算失败", 1)
            return
        end
        showGoodsPriceResultPanel(result)
    end

    local ThirdPanelAVM = require "amf.middleware.ui.kit.panel.third.ThirdPanelAVM"
    local vm
    local keyboardInput
    if EnvUtil:isStandalone() then
        local DesktopKeyboardInput = require "amf.middleware.ui.kit.component.DesktopKeyboardInput"

        local tipLabel = TextField:create("输入goodsId:", nil, 24)
        tipLabel:setColor(hex2ccc3("F2418AFF"))
        tipLabel:setAnchorPoint(ccp(0, 1))
        tipLabel:setPositionXY(10, size.height - 10)
        layerColor:addChild(tipLabel)

        local hintLabel = TextField:create("查询结果弹窗关闭后，输入框会继续保留", nil, 18)
        hintLabel:setColor(hex2ccc3("FFFFFFFF"))
        hintLabel:setAnchorPoint(ccp(0, 1))
        hintLabel:setPositionXY(10, size.height - 42)
        layerColor:addChild(hintLabel)

        local inputLabel = TextField:create(inputStr, nil, 28)
        inputLabel:setColor(hex2ccc3("F2418AFF"))
        inputLabel:setAnchorPoint(ccp(0, 1))
        inputLabel:setPositionXY(10, size.height - 86)
        layerColor:addChild(inputLabel)

        keyboardInput = DesktopKeyboardInput:create({
            text = inputStr,
            onChange = function(text)
                inputStr = text
                inputLabel:setString(text)
            end,
        })
        keyboardInput:activate("GoodsPriceTestInputPanel", 1200)
    else
        local EditBox = force_require "amf.middleware.ui.kit.component.EditBox"
        local editText
        editText = EditBox.Builder.new()
                                :setDimensions(size)
                                :setHAlignment(kCCTextAlignmentCenter)
                                :setVAlignment(kCCVerticalTextAlignmentCenter)
                                :setFontSize(24)
                                :setMaxLength(20)
                                :setFontColor(hex2ccc4('F2418AFF'))
                                :setCustomTextChangeCallback(function(text)
                                    inputStr = text
                                    editText:setShowText("输入goodsId:\n" .. inputStr)
                                end)
                                :setUseSystemFont(false)
                                :setIsAutoUpdate(true)
                                :build()

        editText:setShowText("输入goodsId:\n")
        editText:setAnchorPoint(ccp(0, 1))
        editText:setPositionXY(0, size.height)
        layerColor:addChild(editText)
    end

    vm = ThirdPanelAVM.Builder.new()
    :setTitle("商品价值计算测试")
    :setButtonsConfig({
        {
            str = "查询",
            touchFunc = function()
                queryGoodsPrice(inputStr)
            end,
        },
        {
            str = "关闭",
            touchFunc = function()
                if keyboardInput then
                    keyboardInput:deactivate()
                end
                vm:close()
            end,
        },
    })
    :build()
    vm:popout()
    vm.view:addChild(layerColor)
    layerColor:setPositionXY(108, 590)

    local originalClose = vm.close
    vm.close = function(self, ...)
        if keyboardInput then
            keyboardInput:deactivate()
            keyboardInput = nil
        end
        return originalClose(self, ...)
    end
end

--- 注册一个调试按钮
--- @param label string 按钮文本
--- @param action function 点击回调
function PropDebugPanel.register(label, action)
    table.insert(_buttons, { label = label, action = action })
end

-- ======================== 内置按钮（模块加载时自动注册） ========================

PropDebugPanel.register("道具图标总览", function()
    force_require("amf.middleware.propfeature.debug.PropIconBrowser"):popout()
end)

PropDebugPanel.register("道具配置校验", function()
    force_require("amf.middleware.propfeature.debug.PropConfigChecker").run()
end)

PropDebugPanel.register("道具单元测试", function()
    local ok, err = pcall(function()
        force_require("amf.middleware.propfeature.test.Test"):runAll()
    end)
    if ok then
        CommonTip:showTip("道具单元测试全部通过", 1)
    else
        CommonTip:showTip("测试失败，详见日志", 1)
        print("[PropDebugPanel] test error: " .. tostring(err))
    end
end)

PropDebugPanel.register("商品价值计算测试", function()
    showGoodsPriceTestInputPanel()
end)

PropDebugPanel.register("decoDaily写入验证", function()
    local Test = force_require("amf.middleware.prop.propchange.test.Test")
    Test:testDecoDailyGain()
    CommonTip:showTip("已发放，日志搜 [decoDaily]", 1)
end)

PropDebugPanel.register("限时/无限道具写入验证", function()
    local Test = force_require("amf.middleware.prop.propchange.test.Test")
    Test:testTimeLimitInfiniteGain()
    CommonTip:showTip("已发放，日志搜 [testTimeLimitGain]", 1)
end)

PropDebugPanel.register("补星瓶剩余面板", function()
    local ShowStarBuffRemainPanelVM = force_require("amf.feature.localactivity.stellarconvergence.view.vm.ShowStarBuffRemainPanelVM")
    ShowStarBuffRemainPanelVM:test()
end)

if isDevelopMode() then
    PropDebugPanel.register("每日免费补星瓶", function()
        local GetStarBuffPanelVM = force_require("amf.feature.level.starbuff.view.GetStarBuffPanelVM")
        GetStarBuffPanelVM.Builder.new()
        :setTitle("每日免费补星瓶")
        :setNormalNum(3)
        :setKeepFullLevelNum(0)
        :setNotNeedBox(true)
        :setPopoutSourceTypeId(StarBuffConst.PopoutSourceType.kMainPanel)
        :setCloseCallback(function(clickCloseBtn, hasGetSuccess)
            printx(22, "GetStarBuffPanel closed", clickCloseBtn, hasGetSuccess)
        end)
        :build()
        :popout()
    end)
end

PropDebugPanel.register("应用宝更新面板测试", function()
    showYYBRewardSelectPanel()
end)

PropDebugPanel.register("关卡Bubble偏移测试", function()
    force_require("amf.middleware.propfeature.debug.BubbleOffsetTester").popoutUBF()
end)

PropDebugPanel.register("奖励Bubble偏移测试", function()
    force_require("amf.middleware.propfeature.debug.BubbleOffsetTester").popoutBubble()
end)

PropDebugPanel.register("装饰groupId测试", function()
    local DecoGroupIdTest = force_require("amf.middleware.propfeature.test.DecoGroupIdRuntimeTest")
    local result, allPassed = DecoGroupIdTest:run()
    if allPassed then
        CommonTip:showTip("装饰groupId测试全部通过", 1)
    else
        CommonTip:showTip("装饰groupId测试有失败，查看控制台", 1)
    end
end)

-- ======================== 弹出面板 ========================

function PropDebugPanel:popout()
    local panel = PropDebugPanel.new()
    panel:initLayer()
    panel:_init()

    local scene = Scene:create()
    scene:addChild(panel)
    Director:sharedDirector():pushScene(scene)

    scene.onKeyBackClicked = function()
        Director:sharedDirector():popScene()
    end
end

-- ======================== 初始化 ========================

function PropDebugPanel:_init()
    self:ignoreAnchorPointForPosition(false)
    self:setAnchorPoint(ccp(0, 0))

    local vs = Director:sharedDirector():getVisibleSize()
    local vo = Director:sharedDirector():getVisibleOrigin()
    self:changeWidthAndHeight(vs.width, vs.height)
    self:setPosition(vo)

    -- 背景
    local bg = LayerColor:createWithColor(ccc3(40, 40, 50))
    bg:setContentSize(CCSizeMake(vs.width, vs.height))
    self:addChild(bg)

    -- 返回按钮
    local backBtn = self:_createTextBtn("< 返回", 28, function()
        Director:sharedDirector():popScene()
    end, "FF6666")
    backBtn:setPositionXY(10, vs.height - 50)
    self:addChild(backBtn, 10)

    -- 标题
    local title = TTFLabel:createAnimalYH("道具系统调试", 36)
    title:setAnchorPoint(ccp(0.5, 0.5))
    title:setTextColor(hex2ccc4("FFFFFFFF"))
    title:setPositionXY(vs.width / 2, vs.height - 30)
    self:addChild(title, 10)

    -- 按钮列表
    local buttons = _buttons
    local count = #buttons
    local contentTop = vs.height - LIST_TOP_MARGIN
    local listH = math.max(0, contentTop - LIST_BOTTOM_MARGIN)
    local totalH = count > 0 and (count * BTN_HEIGHT + (count - 1) * BTN_GAP) or 0
    local scroll = VerticalScrollable:create(vs.width, listH, true, false)
    scroll:setPositionXY(0, contentTop)
    self:addChild(scroll)

    local contentH = math.max(totalH, listH)
    local content = Layer:create()
    content:changeWidthAndHeight(vs.width, contentH)
    content.getHeight = function() return contentH end

    for i, cfg in ipairs(buttons) do
        local btn = self:_createActionBtn(cfg.label, cfg.action)
        btn:setPositionXY(vs.width / 2, -(i - 1) * (BTN_HEIGHT + BTN_GAP) - BTN_HEIGHT / 2)
        content:addChild(btn)
    end
    scroll:setContent(content)
end

-- ======================== UI 工厂 ========================

function PropDebugPanel:_createActionBtn(text, callback)
    local btn = Layer:create()
    btn:setAnchorPoint(ccp(0.5, 0.5))
    btn:ignoreAnchorPointForPosition(false)
    btn:changeWidthAndHeight(BTN_WIDTH, BTN_HEIGHT)

    local bg = LayerColor:create()
    bg:setContentSize(CCSizeMake(BTN_WIDTH, BTN_HEIGHT))
    bg:setColor(ccc3(60, 120, 200))
    bg:setOpacity(220)
    btn:addChild(bg)

    local label = TTFLabel:createAnimalYH(text, 30)
    label:setAnchorPoint(ccp(0.5, 0.5))
    label:setTextColor(hex2ccc4("FFFFFFFF"))
    label:setPositionXY(BTN_WIDTH / 2, BTN_HEIGHT / 2)
    btn:addChild(label)

    btn:setTouchHandler(function()
        if callback then callback() end
    end)

    return btn
end

function PropDebugPanel:_createTextBtn(text, fontSize, callback, colorHex)
    local label = TTFLabel:createAnimalYH(text, fontSize)
    label:setAnchorPoint(ccp(0, 0.5))
    label:setTextColor(hex2ccc4((colorHex or "FFFFFF") .. "FF"))

    local size = label:getContentSize()
    local btn = Layer:create()
    btn:setAnchorPoint(ccp(0, 0.5))
    btn:ignoreAnchorPointForPosition(false)
    btn:changeWidthAndHeight(size.width + 20, size.height + 10)
    btn:addChild(label)
    label:setPositionXY(0, (size.height + 10) / 2)

    btn:setTouchHandler(function()
        if callback then callback() end
    end)

    return btn
end

return PropDebugPanel
