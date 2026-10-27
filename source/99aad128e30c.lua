local AddFiveStepConfig = {}

AddFiveStepConfig.ShowPanelType = {
	kStart = 1,
	kWin = 2,
	kEnd = 3,
}

AddFiveStepConfig.RewardGroupType = {
	kNone = 0,
	kGroupType1 = 1,
	kGroupType2 = 2,
	kGroupType3 = 3,
	kGroupType4 = 4, --满精力新奖励
	kGroupType5 = 5, --未满精力新奖励
}

AddFiveStepConfig.passLevelType = {
	kNone = 0,
	kPassLevel = 1,
	kFailLevel = 2,
}

AddFiveStepConfig.saveStartPanelShowInfoKey = "saveStartPanelShowInfoKey" --用来保存是否这关已经随到了奖励 进关清空此数据
AddFiveStepConfig.saveStartPanelParamKey = "saveStartPanelParamKey" --保存进关之后是否触发了活动， 为过关面板展示提供需求。 闪退恢复取消、成功失败面板触发清空
AddFiveStepConfig.saveStartPanelProbabilityKey = "saveStartPanelProbabilityKey" --保存触发概率信息、 计算概率的时候存储，不会清空，但是超过一定数量会清理一些。
AddFiveStepConfig.saveStartPanelShowHistoryKey = "saveStartPanelShowHistoryKey" --保存历史触发信息 只存最后一次触发的信息，进关记录，不会清空。
AddFiveStepConfig.saveGiftParamKey = "saveGiftParamKey" --保存触发的礼包信息  触发礼包保存信息，在购买完成后记录购买完成词条。
AddFiveStepConfig.saveStartPanelInGameInfoKey = "saveStartPanelInGameInfoKey" --记录带着buff进关的时间信息  用来判断24小时能出几次。 不会清空，但是超过数量会清除一些。

--废弃使用下面新的key
-- AddFiveStepConfig.saveActiveInfoForInLevelKey = "saveActiveInfoForInLevel" --进关记录触发的信息，用来成功过关，+5步内容。 在开始面板检测的时候清空，闪退恢复成功失败等情况清空

AddFiveStepConfig.saveActiveInfoForPopRewardPanel = 'saveActiveInfoForPopRewardPanel' --记录激活信息，为了场景3补弹领奖面板。 触发的时候重新赋值，成功过关失败过关的时候设置结果，领奖的时候设置领奖结果

AddFiveStepConfig.add150SoreBuffID = 54306
AddFiveStepConfig.add150ScoreAddNum = 150

return AddFiveStepConfig