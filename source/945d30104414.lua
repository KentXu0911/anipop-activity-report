local PetConfig = {}

PetConfig.autoDownload = true
PetConfig.downloadLabels = {
    "pet_in_package"
}

-- TODO: 补充宠物活动客户端版本
PetConfig.clientVersion = 5

PetConfig.openLevel = nil
PetConfig.openPassLevel = nil

PetConfig.ACT_ID = 22009
PetConfig.actId = PetConfig.ACT_ID
PetConfig.DCFeature = "pet"
PetConfig.dcFeature = PetConfig.DCFeature
PetConfig.ACT_CH_NAME = "小小萌伴"
PetConfig.actChName = PetConfig.ACT_CH_NAME
PetConfig.infoPrefix = "userInfo"
PetConfig.configPrefix = "localConfig"
PetConfig.timePrefix = "timeInfo"
PetConfig.ACT_NAME = "pet"
PetConfig.LOCAL_PATH = "amf.feature.localactivity." .. string.lower(PetConfig.ACT_NAME)
PetConfig.ACT_SOURCE = "pet/Config.lua"
PetConfig.actSource = PetConfig.ACT_SOURCE

PetConfig.IconMode = {
    VineCorner = "vineCorner",
    LeftSidePool = "leftSidePool",
}



PetConfig.DecoPartType = {
    Image = 1,
    Accessory = 2,
    Eye = 3,
    Wing = 4,
}
PetConfig.petDecoProp = require "amf.feature.localactivity.pet.config.PetDecoPropConfig"

PetConfig.needLoadFiles = {
    PetConfig.petDecoProp.atlas
}

PetConfig.ServerPayloadSource = {
    PET_ACTIVITY_INFO = "petActivityInfo",
    GET_ACT_INFO = "getActInfo",
}

PetConfig.DeprecatedDataKey = {
    WEARING_DECOS = "wearingDecos",
}

PetConfig.WingAutoPopCandidate = {
    FIRST_ACTIVATION_GUIDE = "first_activation_guide",
    ACTIVATION_TRANSITION = "activation_transition",
    PENDING_ACTIVATION = "pending_activation",
}

PetConfig.WingDisplayMode = {
    FIRST_ACTIVATION_GUIDE = "first_activation_guide",
    ACTIVATION_TRANSITION = "activation_transition",
    PENDING_ACTIVATION = "pending_activation",
}

PetConfig.WingAutoPop = {
    GUIDE_ID = 6,
    MAIN_PANEL_SHOWN_DAY_KEY = "mainPanelShownServerDay",
    PANEL_SHOWN_DAY_KEY = "wingActivationTransitionServerDay",
    DAILY_PROGRESS_ANIMATION_DAY_KEY = "wingDailyProgressAnimationServerDay",
    TARGET_PANEL = "wing",
    OPEN_REASON = "auto_pop",
}

PetConfig.WingSwitch = {
    NAME = "pet_wings_switch",
    CLOSED_GROUP = "OFF",
}

PetConfig.defaultFeedMultipleList = {1, 5, 10}
PetConfig.defaultFeedItemId = 187
PetConfig.defaultPetId = 1
PetConfig.defaultPetName = "小小萌伴"
PetConfig.syncRequests = {}
PetConfig.actSendRequestConfig = {}

PetConfig.bShowLog = true


function PetConfig:showLog(...)
    if _G.isLocalDevelopMode and PetConfig.bShowLog then
        printx(44, "***宠物活动***", ...)
    end
end

return PetConfig
