local Meta = {}
Meta.themeKey = ""
Meta.actChNameMap = {
    Default = "露营吧！朋友",
    Anniversary = "演奏吧！朋友",
}
Meta.actId = 5321
Meta.actKey = "5321"
Meta.timePrefix = "actTime"
Meta.actChName = Meta.actChNameMap[Meta.themeKey] or Meta.actChNameMap.Default
-- Meta.infoPrefix = ""
Meta.configPrefix = "serverVersionedConfig.config"
Meta.collectionPath = ""
Meta.bannerPath = ""
Meta.disableAfterGetReward = true
if not Meta.themeKey or Meta.themeKey == "" then
    Meta.collectionPath = "amf/activity/teamcamping/materials/collection.png"
    Meta.bannerPath = "amf/activity/teamcamping/materials/banner.png"
else
    Meta.collectionPath = "amf/activity/teamcamping/themes/" .. Meta.themeKey .. "/materials/collection.png"
    Meta.bannerPath = "amf/activity/teamcamping/themes/" .. Meta.themeKey .. "/materials/banner.png"
    Meta.disableAfterGetReward = false
end

Meta.needLoadFiles = {
    Meta.collectionPath,
    Meta.bannerPath,
}
Meta.downloadLabels = { "teamcamping"}
-- if  Meta.themeKey and Meta.themeKey ~= "" then
--     Meta.downloadLabels = { "teamcamping_pack","teamcamping_" .. Meta.themeKey}
-- end
Meta.autoDownload = true

Meta.dcFeature = "camping"

Meta.headFrameTypeId = _G.HeadFrameType.kTeamCamping_0801
Meta.collectionId = 54316
Meta.GroupState = {
    Empty = 1,
    GroupNotSee = 2,
    GroupHasSee = 3,
    Over = 4,
 }
Meta.State = {
    kFMJ = "fmj",
    kMHZC = "mx",
    kFMZ = "fmz",
    kOther = "mj",
 }
Meta.powerBuffId1 = 54317
Meta.powerBuffId2 = 54318
Meta.scoreBuff20 = 54322
Meta.buffTimesMap = {
    [Meta.powerBuffId1] = 5,
    [Meta.powerBuffId2] = 2,
 }

Meta.Haptics = {
    BUILD_BTN_TAP = "build_btn_tap",
    MULTIPLIER_BTN_TAP = "multiplier_btn_tap",
    BUILD_ON_HIT = "build_on_hit",
 }

Meta.HapticsMini = {
    [Meta.Haptics.BUILD_BTN_TAP] = {
        MainType = "vibrateShort",
        SubType = "medium",
     },
    [Meta.Haptics.MULTIPLIER_BTN_TAP] = {
        MainType = "vibrateShort",
        SubType = "light",
     },
    [Meta.Haptics.BUILD_ON_HIT] = {
        MainType = "vibrateShort",
        SubType = "heavy",
     },
 }

Meta.TipEnum = {
    FriendGo = 3,
    Upgrade = 4,
    FindFriend = 5,
    GetNewInvitation = 1,
    GetFriendInvitation = 2,
 }

return Meta
