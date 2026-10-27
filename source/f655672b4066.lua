local TeamCampingConst = require "amf.feature.localactivity.teamcamping.const.TeamCampingConst"

local ResConfig = {}

local DEFAULT_THEME = "Default"
local currentTheme = TeamCampingConst.themeKey or DEFAULT_THEME

local function normalizeTheme(theme)
    if not theme or theme == "" then
        return DEFAULT_THEME
    end
    return theme
end

local function cloneTable(source)
    local result = {}
    for k, v in pairs(source or {}) do
        if type(v) == "table" then
            result[k] = cloneTable(v)
        else
            result[k] = v
        end
    end
    return result
end

local function normalizeResKey(name)
    if not name then
        return name
    end
    return string.gsub(name, "%.plist$", "")
end

function ResConfig.setTheme(theme)
    currentTheme = normalizeTheme(theme)
end

function ResConfig.getTheme()
    return normalizeTheme(currentTheme)
end

ResConfig.Plist = {
    DescPanel = "amf/activity/teamcamping/texture/DescPanel.plist",
    PreheatPanel = "amf/activity/teamcamping/texture/PreheatPanel.plist",
    RewardTip = "amf/activity/teamcamping/texture/RewardTip.plist",
}

ResConfig.ThemePlist = {
    Default = {},
    Anniversary = {
        DescPanel = "amf/activity/teamcamping/themes/Anniversary/texture/DescPanel.plist",
        PreheatPanel = "amf/activity/teamcamping/themes/Anniversary/texture/PreheatPanel.plist",
    },
}

ResConfig.UI = {
    DescPanel = "amf.feature.localactivity.teamcamping.views.uisource.DescPanel_UI",
    PreheatPanel = "amf.feature.localactivity.teamcamping.views.uisource.PreheatPanel_UI",
}

ResConfig.ThemeUI = {
    Default = {},
    Anniversary = {
        DescPanel = "amf.feature.localactivity.teamcamping.themes.anniversary.DescPanel_UI",
        PreheatPanel = "amf.feature.localactivity.teamcamping.themes.anniversary.PreheatPanel_UI",
    },
}

ResConfig.Layout = {
    PreheatPanel = {
        NowScoreOffset = { x = -86, y = -19 },
    },
}

ResConfig.ThemeLayout = {
    Default = {},
    Anniversary = {
        PreheatPanel = {
            NowScoreOffset = { x = 7, y = -12 },
        },
    },
}

function ResConfig:getLayoutConfig()
    local layoutConfig = cloneTable(self.Layout)
    local theme = self.getTheme()
    local themeConfig = self.ThemeLayout[theme]
    if themeConfig then
        for k, v in pairs(themeConfig) do
            if type(v) == "table" then
                layoutConfig[k] = layoutConfig[k] or {}
                for key, value in pairs(v) do
                    if value ~= nil then
                        layoutConfig[k][key] = value
                    end
                end
            elseif v ~= nil then
                layoutConfig[k] = v
            end
        end
    end
    return layoutConfig
end

function ResConfig:getPanelLayout(panelName)
    local layoutConfig = self:getLayoutConfig()
    return layoutConfig[panelName] or {}
end

ResConfig.Text = {
    Common = {
        MainTitle = "露营吧！朋友",
    },
    Reward = {
        TipTopCash = "最多可得        <<x>>%d，\n更有露营专属限定头像框等你来拿！",
    },
}

ResConfig.ThemeText = {
    Default = {},
    Anniversary = {
        Common = {
            MainTitle = "演奏吧！朋友",
        },
        PowerBuff = {
            RewardTimeSettleHint = "领奖期啦，\n领奖完成后指挥棒会结算成资源~",
            NotEnough = "指挥棒不足",
        },
        Reward = {
            TipTopCash = "最多可得        <<x>>%d，\n更有周年专属限定头像框等你来拿！",
        },
    },
}

function ResConfig:getTextConfig()
    local textConfig = cloneTable(self.Text)
    local theme = self.getTheme()
    local themeConfig = self.ThemeText[theme]
    if themeConfig then
        for k, v in pairs(themeConfig) do
            if type(v) == "table" then
                textConfig[k] = textConfig[k] or {}
                for key, value in pairs(v) do
                    if value and value ~= "" then
                        textConfig[k][key] = value
                    end
                end
            elseif v and v ~= "" then
                textConfig[k] = v
            end
        end
    end
    return textConfig
end

function ResConfig:getUIConfig()
    local uiConfig = cloneTable(self.UI)
    local theme = self.getTheme()
    local themeConfig = self.ThemeUI[theme]
    if themeConfig then
        for k, v in pairs(themeConfig) do
            if v and v ~= "" then
                uiConfig[k] = v
            end
        end
    end
    return uiConfig
end

function ResConfig:getUIPath(uiName)
    local uiConfig = self:getUIConfig()
    return uiConfig[uiName]
end

function ResConfig:getPlistConfig()
    local plistConfig = cloneTable(self.Plist)
    local theme = self.getTheme()
    local themeConfig = self.ThemePlist[theme]
    if themeConfig then
        for k, v in pairs(themeConfig) do
            if v and v ~= "" then
                plistConfig[k] = v
            end
        end
    end
    return plistConfig
end

function ResConfig:getPlist(plistName)
    local plistConfig = self:getPlistConfig()
    return plistConfig[normalizeResKey(plistName)]
end

function ResConfig:getDescPanelAssetsList()
    return {
        self:getPlist("DescPanel"),
    }
end

function ResConfig:getPreheatPanelAssetsList()
    return {
        self:getPlist("PreheatPanel"),
        self:getPlist("RewardTip"),
    }
end

return ResConfig
