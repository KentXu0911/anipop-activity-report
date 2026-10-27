
local ServerConfigDefault = {}

ServerConfigDefault.PopTypeNumLimit = {
	[AutoPopupConst.PopStage.STAGE_ONE] = {
		[AutoPopupConst.PopType.POLICY] 		= 0,
		[AutoPopupConst.PopType.OUTSIDE] 		= 0,
		[AutoPopupConst.PopType.SYSTEM] 		= 0,
		[AutoPopupConst.PopType.ACTIVITY] 		= 0,
		[AutoPopupConst.PopType.RECALL] 		= 0,
		[AutoPopupConst.PopType.CONDITION] 		= 0,
		[AutoPopupConst.PopType.FUNCTION] 		= 0,
		[AutoPopupConst.PopType.CRASH_RESUME] 	= 0,
		[AutoPopupConst.PopType.GUIDE] 			= 0,
		[AutoPopupConst.PopType.GIFT_PACK] 		= 0,
		[AutoPopupConst.PopType.TMP_ACT_PANEL] 	= 0,
	},
	[AutoPopupConst.PopStage.STAGE_TWO] = {
		[AutoPopupConst.PopType.POLICY] 		= 2,
		[AutoPopupConst.PopType.OUTSIDE] 		= 99,
		[AutoPopupConst.PopType.SYSTEM] 		= 1,
		[AutoPopupConst.PopType.ACTIVITY] 		= 3,
		[AutoPopupConst.PopType.RECALL] 		= 1,
		[AutoPopupConst.PopType.CONDITION] 		= 2,
		[AutoPopupConst.PopType.FUNCTION] 		= 1,
		[AutoPopupConst.PopType.CRASH_RESUME] 	= 1,
		[AutoPopupConst.PopType.GUIDE] 			= 0,
		[AutoPopupConst.PopType.GIFT_PACK] 		= 2,
		[AutoPopupConst.PopType.TMP_ACT_PANEL] 	= 1,
	},
	[AutoPopupConst.PopStage.STAGE_THREE] = {
		[AutoPopupConst.PopType.POLICY] 		= 2,
		[AutoPopupConst.PopType.OUTSIDE] 		= 0,
		[AutoPopupConst.PopType.SYSTEM] 		= 0,
		[AutoPopupConst.PopType.ACTIVITY] 		= 0,
		[AutoPopupConst.PopType.RECALL] 		= 0,
		[AutoPopupConst.PopType.CONDITION] 		= 99,
		[AutoPopupConst.PopType.FUNCTION] 		= 0,
		[AutoPopupConst.PopType.CRASH_RESUME] 	= 0,
		[AutoPopupConst.PopType.GUIDE] 			= 0,
		[AutoPopupConst.PopType.GIFT_PACK] 		= 1,
		[AutoPopupConst.PopType.TMP_ACT_PANEL] 	= 0,
	},
	[AutoPopupConst.PopStage.STAGE_FOUR] = {
		[AutoPopupConst.PopType.POLICY] 		= 2,
		[AutoPopupConst.PopType.OUTSIDE] 		= 0,
		[AutoPopupConst.PopType.SYSTEM] 		= 1,
		[AutoPopupConst.PopType.ACTIVITY] 		= 2,
		[AutoPopupConst.PopType.RECALL] 		= 1,
		[AutoPopupConst.PopType.CONDITION] 		= 99,
		[AutoPopupConst.PopType.FUNCTION] 		= 3,
		[AutoPopupConst.PopType.CRASH_RESUME] 	= 0,
		[AutoPopupConst.PopType.GUIDE] 			= 99,
		[AutoPopupConst.PopType.GIFT_PACK] 		= 2,
		[AutoPopupConst.PopType.TMP_ACT_PANEL] 	= 1,
	},
}

ServerConfigDefault.PopTypeFullPriority = {
	[AutoPopupConst.PopStage.STAGE_ONE] = {},
	[AutoPopupConst.PopStage.STAGE_TWO] =  {
		AutoPopupConst.PopType.POLICY, 
		AutoPopupConst.PopType.CRASH_RESUME,
		AutoPopupConst.PopType.OUTSIDE,
		AutoPopupConst.PopType.SYSTEM,
		AutoPopupConst.PopType.ACTIVITY,
		AutoPopupConst.PopType.GIFT_PACK,
		AutoPopupConst.PopType.TMP_ACT_PANEL,
		AutoPopupConst.PopType.RECALL,
		AutoPopupConst.PopType.CONDITION, 								
		AutoPopupConst.PopType.FUNCTION,
	},
	[AutoPopupConst.PopStage.STAGE_THREE] = {
		AutoPopupConst.PopType.POLICY,
		AutoPopupConst.PopType.CONDITION,
	},
	[AutoPopupConst.PopStage.STAGE_FOUR] = {	
		AutoPopupConst.PopType.POLICY, 
		AutoPopupConst.PopType.CONDITION, 
		AutoPopupConst.PopType.SYSTEM,
		AutoPopupConst.PopType.ACTIVITY,
		AutoPopupConst.PopType.GIFT_PACK,
		AutoPopupConst.PopType.TMP_ACT_PANEL,
		AutoPopupConst.PopType.RECALL,
		AutoPopupConst.PopType.FUNCTION,
		AutoPopupConst.PopType.GUIDE,
	},
}

-- 强弹场景切换时(2->2,3->4)，不受限制的poptype，即产品文档里所谓的“部分强弹队列”
ServerConfigDefault.PopTypeSubPriority = {
	[AutoPopupConst.PopStage.STAGE_ONE] = {},
	[AutoPopupConst.PopStage.STAGE_TWO] =  {
		AutoPopupConst.PopType.POLICY, 
		AutoPopupConst.PopType.CRASH_RESUME,
		AutoPopupConst.PopType.OUTSIDE,
	},
	[AutoPopupConst.PopStage.STAGE_THREE] = {},
	[AutoPopupConst.PopStage.STAGE_FOUR] = {
		AutoPopupConst.PopType.POLICY,
		AutoPopupConst.PopType.CONDITION,
		AutoPopupConst.PopType.GIFT_PACK
	},
}

return ServerConfigDefault