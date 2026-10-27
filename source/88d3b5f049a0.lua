
local MusicMasterConfig = {}

MusicMasterConfig.autoDownload = false
MusicMasterConfig.downloadLabels = {"musicmaster_downpart"}


MusicMasterConfig.cliendVersion = 1 --客户端版本
MusicMasterConfig.openLevel = 210
MusicMasterConfig.openPassLevel = 210
-- 主线
MusicMasterConfig.ACT_ID = 4062
MusicMasterConfig.DCFeature = "happy_merge"
MusicMasterConfig.DCSource = "act_"..MusicMasterConfig.ACT_ID
MusicMasterConfig.ACT_CH_NAME = "完美演奏家"

MusicMasterConfig.ACT_NAME = "musicmaster"
MusicMasterConfig.LOCAL_PATH = 'amf.feature.localactivity.'..string.lower( MusicMasterConfig.ACT_NAME )
MusicMasterConfig.MUSIC_PATH = 'amf/activity/musicmaster/music/'

MusicMasterConfig.ActivitySoundEffectFileName = {
    kVictory = 'MusicMaster_Victory',
    kLose = 'MusicMaster_Lose',
    kShowAward = 'Common_ShowAward01',
    kFlySouLong = 'Common_FlysouLong',
    kYellowBanner = 'Common_YellowBanner',
}

function MusicMasterConfig:getMusicFilePath(fileName, extension)
    return self.MUSIC_PATH..fileName..(extension or '.mp3')
end


MusicMasterConfig.CollectId = 56022
MusicMasterConfig.TicketId = 56023


MusicMasterConfig.dailyDcJoinKey = "musicMasterJoinKey"


MusicMasterConfig.GuideIds =
{
	kPreGuide = 1,
	kHandGuide= 2,
	-- kGroupWinNumGuide = 3,
	kPopPrePanel = 4,
	kPopGuidePanel = 5,		-- 选拔赛弹窗引导
	kPopGuidePanel2 = 6,	-- 小组赛弹窗引导

	kGroupWinNumGuide = 30, --占用30-35
	kGroupRewardGuide = 40, --占用40-45

}

--开始面板状态，选拔赛，小组赛
MusicMasterConfig.MainPanelShowType = {
	kNone = 0,
	kPre = 1,
	kGroup = 2,
}

MusicMasterConfig.GroupPanelShowType = {
	kNone = 0,
	kWaitJoin= 1,
	kInGroup = 2,
}

local startPosX = 250
local offsetLength = 85
local startPosY = 187
MusicMasterConfig.PreRewardPosList = {
	{x=startPosX-offsetLength*2, y=startPosY}, {x=startPosX-offsetLength, y=startPosY}, {x=startPosX, y=startPosY}, {x=startPosX+offsetLength, y=startPosY}, {x=startPosX+offsetLength*2, y=startPosY},
	{x=startPosX-offsetLength*2, y=97}, {x=startPosX-offsetLength, y=97}, {x=startPosX, y=97}, {x=startPosX+offsetLength*1, y=97}, {x=startPosX+offsetLength*2, y=97}
}

MusicMasterConfig.ProgressPreview = {
	-- 节点位置
    ItemPos = {
        { x = 10, y = -56 },
        { x = 6,  y = 128 },
        { x = 16, y = 312 },
        { x = 11, y = 496 },
    },

	RewardOffset = {
		{ x = 110, y = 0},
		{ x = 115, y = 0},
		{ x = 105, y = 0},
		{ x = 110, y = 0},
	}
}

MusicMasterConfig.GroupNameList = { "初级海选赛", "中级晋级赛", "高级资格赛", "大师对决赛", "王者加冕赛" }
function MusicMasterConfig:getGroupName( duan )
	local safeDuan = self:getSafeDuan(duan)
	local arrayIndex = safeDuan + 1
	return MusicMasterConfig.GroupNameList[arrayIndex]
end

function MusicMasterConfig:getSafeDuan( duan )
	if duan == nil then duan = 0 end
	if duan > #MusicMasterConfig.GroupNameList -1 then duan = #MusicMasterConfig.GroupNameList -1 end
	return duan
end

function MusicMasterConfig:getSafeAnimLevel( score, maxScore )
	--根据分数 最大连胜数， 获取帘子打开的等级
	local level = 0

	local level1Num = math.ceil( maxScore * 1/3 )
	local level2Num = math.ceil( maxScore * 2/3 )
	local level3Num = maxScore

	if score >= level3Num then
		level = 3
	elseif score >= level2Num then
		level = 2
	elseif score >= level1Num then
		level = 1
	else
		level = 0
	end

	return level
end

MusicMasterConfig.needLoadFiles = {
	"amf/activity/musicmaster/texture/RankDownPart.plist",
	"amf/activity/musicmaster/texture/ProgressDownPart.plist",
	"amf/activity/musicmaster/spine/up_down_fx.skel",
	"amf/activity/musicmaster/spine/up_fx2.skel",
	"amf/activity/musicmaster/spine/txt_45.skel",
	"amf/activity/musicmaster/spine/txt_123.skel",
}

--声效
MusicMasterConfig.BGMSoundEffectTypes = {
    kDuan1 = 1, --背景
    kDuan2 = 2, --背景
    kDuan3 = 3, --背景
    kDuan4 = 4, --背景
    kDuan5 = 5, --背景
}

MusicMasterConfig.BMGSoundEffectInfo = {
    { SoundEffectType = MusicMasterConfig.BGMSoundEffectTypes.kDuan1, filePath = 'backgroundMusicNewBGM', areaDuan = 0 },
    { SoundEffectType = MusicMasterConfig.BGMSoundEffectTypes.kDuan2, filePath = 'backgroundMusicNewBGM', areaDuan = 1 },
    { SoundEffectType = MusicMasterConfig.BGMSoundEffectTypes.kDuan3, filePath = 'backgroundMusicNewBGM', areaDuan = 2 },
    { SoundEffectType = MusicMasterConfig.BGMSoundEffectTypes.kDuan4, filePath = 'backgroundMusicNewBGM', areaDuan = 3 },
    { SoundEffectType = MusicMasterConfig.BGMSoundEffectTypes.kDuan5, filePath = 'backgroundMusicNewBGM', areaDuan = 4 },
}

function MusicMasterConfig:getBMGSoundFileNameByAreaDuan( areaDuan )
    --获取生效
    for i,v in ipairs(MusicMasterConfig.BMGSoundEffectInfo) do
        if v.areaDuan == areaDuan then
            return true, v.filePath
        end
    end
    return false, ''
end

MusicMasterConfig.bShowLog = true
function MusicMasterConfig:showLog( ... )
	if _G.isLocalDevelopMode and MusicMasterConfig.bShowLog then
		printx(12,"***完美演奏家***", ...)
	end
end

return MusicMasterConfig
