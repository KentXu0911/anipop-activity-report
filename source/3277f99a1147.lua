local Meta = {}

Meta.collectId = -1

Meta.IconState = {
    kIdle = 1,
    kWin = 2,
    kLose = 3,
    kIdle2 = 4
}

Meta.MatchState = {
    kInvalid = 1,
    kWin = 2,
    kLose = 3
}

Meta.MainPanelFrom = {
    kIcon = 1,
    kPop = 2,
    kInvited = 3,
    kStartMatching = 4,
}

Meta.PKState = {
    --非法状态，lightStart没拉到时候可能会有
    kInvalid = -1,
    kPrepare = 0,
    kInGame = 1,
    kToBeSettled = 2,
}

Meta.ActType = {
    kLong = 1,
    kShort = 2,
}

Meta.Key = {
    OPEN_MAIN_PANEL_TODAY = "openMainPanelTodayKey",
    OPEN_JOIN_PANEL_TODAY = "openJoinPanelTodayKey",
}

Meta.TipDesc = {
    PROMPT_ATTEND = "快来继续对决吧！",
    MATCH_SUCCESS = "对手已就位！",
    SUPER_LUCKY = "本局获胜，奖励数量暴增",
}

return Meta