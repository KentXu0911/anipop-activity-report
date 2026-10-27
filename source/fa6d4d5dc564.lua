local Meta = {}

Meta.SheQuLink = 'https://ff.happyelements.com/mobile/page/topic.html?tid=5099750&app=1001&ct=1562664000&gohome=1'

Meta.ACT_ID = 4046
Meta.actKey = "4046"

-- 引导标记
Meta.GuideIds = {
    kGuide1 = 1, -- 说明引导
    kFirstPop = 2, -- 首次弹出
    kPopRewardPanel = 3, -- 赛事预览弹出
    kFirstPopWinNumPanel = 4, -- 首次弹出连胜面板

    kHadPopJoinFirstRank = 5, -- 是否弹出加入一期tip
    kHadPopJoinSecondRank = 6 -- 是否弹出加入二期tip
}

Meta.mainPanelShowType = {
    kMainPanel0 = 0, -- 代表未入组，不能打开主面板
    kMainPanel1 = 4046,
    kMainPanel2 = 4047,
    kMainPanel3 = 4048
}

Meta.rankNameList = {'预选赛', '新星赛', '精英赛'}

Meta.actIdOffset = 4045

Meta.mainPanelShowTypeToConfigStr = {{
    raceType = Meta.mainPanelShowType.kMainPanel1,
    configStr = 'PRESELECTION_RACE'
}, {
    raceType = Meta.mainPanelShowType.kMainPanel2,
    configStr = 'RISING_STARS_RACE'
}, {
    raceType = Meta.mainPanelShowType.kMainPanel3,
    configStr = 'ELITE_RACE'
}}

Meta.collectId = 9999 -- 假收集物id
Meta.addScoreId = 56017 -- 加分buff

Meta.SpecialWinNums = {2, 6, 36, 66, 88, 99}
Meta.SavePopCongraKey = 'savePopCongraKey'

Meta.SavePopMainPanelKey = 'savePopMainPanelKey'
Meta.AutoPopReduceEnteredEndTimeKey = 'autoPopReduceEnteredEndTime'

Meta.SaveOldScoreDataKey = 'saveOldScoreDataKey' -- {mainPanelShowType=1, score=2}

Meta.SaveOldRankScoreKey = 'saveOldRankScoreKey'

Meta.SaveOldRankKey = 'saveOldRankKey'

Meta.actIconProgressFullAnim = 'actIconProgressFullAnim' -- 一辈子一次的icon动画必须看完

Meta.scoreBuffRate = 0.2

function Meta:isSpecialWinNum(winNum)
    if table.exist(Meta.SpecialWinNums, winNum) or winNum % 5 == 0 then
        return true
    end
    return false
end

function Meta:getConfigStrByMainPanelShowType(mainPanelShowType)
    for i, v in ipairs(Meta.mainPanelShowTypeToConfigStr) do
        if v.raceType == mainPanelShowType then
            return v.configStr
        end
    end
    return ""
end

Meta.iconProgressType = {
    kNone = 1, -- 全绿色
    kLeftLight = 2, -- 左边高亮
    kRightLight = 3 -- 右边高亮
}

return Meta
