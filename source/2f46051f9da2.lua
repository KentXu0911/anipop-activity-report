-- 活动说明通用面板 ViewModel
-- 基于 UeAMFBasePanelVM 体系，采用 Builder 模式构建
-- 支持自定义 UI、标题、"点击任意处继续"功能、多页分页、动画

local ActivityCommonNotesVM = class("ActivityCommonNotesVM", UeAMFBasePanelVM)

------------------------------------------------------------
-- Builder 定义
------------------------------------------------------------

local Builder = newBuilder(ActivityCommonNotesVM)

function Builder:ctor()
    self.uiSource = nil           -- string: 传入的 _UI 文件 require 路径（必填）
                                  -- 示例: "amf.feature.xxx.uisource.XxxPanel_UI"
    self.title = nil              -- string|string[]|nil: 标题文本，数组下标与页码一致
    self.skipText = nil           -- string|bool|nil: "点击任意处继续"配置
                                  --   string: 设置 uESkipText 的文本并显示 clickNode，添加点击任意处关闭功能
                                  --   true:   显示 clickNode（使用默认文本"点击任意处继续"），添加点击任意处关闭功能
                                  --   nil:    不显示 clickNode，不添加点击关闭功能
    self.lockDuringAnim = false   -- bool: 入场动画期间是否锁定 UI（默认不锁，可点击关闭按钮）
    self.ignoreAnim = false       -- bool: 是否忽略入场动画并直接展示 UI（默认播放动画）
    self.bottomRichText = nil     -- string|nil: 底部富文本内容（RichText 格式字符串）
                                  --   设置后显示 bottomRichText 节点，nil 时不显示
    self.startPage = nil          -- number|nil: 入场动画起始页，nil 或非法值时从第 1 页开始
    -- 以下继承自 AMFBasePanelVM.Builder 基类，无需重复定义：
    -- self.closeCallback        -- func: 关闭页面的回调
    -- self.panelReadyCallback   -- func: 面板初始化完成回调
end

-- 设置 _UI 文件路径
function Builder:setUiSource(uiSource)
    self.uiSource = uiSource
    return self
end

-- 设置标题文本：字符串作为公共标题，数组按页码设置标题
---@param title string|string[]|nil
function Builder:setTitle(title)
    self.title = title
    return self
end

-- 设置"点击任意处继续"配置
function Builder:setSkipText(skipText)
    self.skipText = skipText
    return self
end

-- 设置入场动画期间是否锁定 UI（默认 false，不锁定）
function Builder:setLockDuringAnim(lock)
    self.lockDuringAnim = lock
    return self
end

-- 设置是否忽略入场动画并直接展示 UI（默认 false，播放动画）
function Builder:setIgnoreAnim(ignoreAnim)
    self.ignoreAnim = ignoreAnim
    return self
end

-- 设置底部富文本内容（RichText 格式字符串）
function Builder:setBottomRichText(richText)
    self.bottomRichText = richText
    return self
end

-- 设置入场动画起始页，用于跳过前置页并从指定页开始展示和播放动画
function Builder:setStartPage(startPage)
    self.startPage = startPage
    return self
end

------------------------------------------------------------
-- VM 创建面板
------------------------------------------------------------

function ActivityCommonNotesVM:_createPanel(...)
    local panel = require_debug 'amf.middleware.ui.kit.activitescommonnotes.view.ActivityCommonNotesPanel'
    return panel:create(ActivityCommonNotesVM, ...)
end

------------------------------------------------------------
-- VM 生命周期
------------------------------------------------------------

function ActivityCommonNotesVM:init(delegate)
    self.delegate = delegate
end

function ActivityCommonNotesVM:firstLoadCompleted()
    -- 调用 Panel 的初始化方法，传入完整的 delegate 配置
    self:callViewFunc("initUI", self.delegate)
end

------------------------------------------------------------
-- 面板进入时的动画流程
-- 动画逻辑封装在 Panel:_playEnterAnimation 中
------------------------------------------------------------

function ActivityCommonNotesVM:onEnterPanelRun()
    -- 忽略动画时，Panel 已在初始化阶段直接展示 UI，无需再触发入场动画
    if self.delegate.ignoreAnim then return end
    self:callViewFunc("_playEnterAnimation")
end

------------------------------------------------------------
-- 锁 UI 接口（VM 中转发到 Panel）
-- 参考 IllustrationPanelVM 的 lock/unlock/isLocked
------------------------------------------------------------

function ActivityCommonNotesVM:lock()
    self:callViewFunc("lock")
end

function ActivityCommonNotesVM:unlock()
    self:callViewFunc("unlock")
end

function ActivityCommonNotesVM:isLocked()
    self:callViewFunc("isLocked")
end

------------------------------------------------------------
-- 测试方法
-- 测试资源已删除，需要去 assets/TongYongWanfaShuoMing/ui_tech/testPanel 重新导出
------------------------------------------------------------

local MULTI_UI = "amf.feature.localactivity.teamcamping.themes.anniversary.DescPanel_UI"

-- 测试1：多页 + 每页独立标题 + 有skipText（skipText 被多页覆盖）
local function test1()
    printx(43, "=== 测试1: 多页 + skipText ===")
    ActivityCommonNotesVM.Builder.new()
        :setUiSource(MULTI_UI)
        :setTitle({
            "如何玩转活动？",
            "活动奖励说明",
        })
        :setSkipText("点击任意处继续")
        :setCloseCallback(function() printx(43, "测试1 关闭") end)
        :build()
        :popout()
end

-- 测试2：多页 + 锁UI（动画期间不可关闭）
local function test2()
    printx(43, "=== 测试2: 多页 + 锁UI ===")
    ActivityCommonNotesVM.Builder.new()
        :setUiSource(MULTI_UI)
        :setTitle("锁UI多页测试")
        :setLockDuringAnim(true)
        :setCloseCallback(function() printx(43, "测试2 关闭") end)
        :build()
        :popout()
end

-- 每次调用依次轮换测试用例
function ActivityCommonNotesVM:test()
    local testCases = { test1, test2 }
    _G._activityCommonNotesTestIndex = (_G._activityCommonNotesTestIndex or 0) % #testCases + 1
    local index = _G._activityCommonNotesTestIndex
    printx(43, "活动说明通用面板 测试用例 " .. index .. "/" .. #testCases)
    testCases[index]()
end

return ActivityCommonNotesVM
