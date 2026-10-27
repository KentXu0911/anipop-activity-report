require "ubf.old.gamePlay.userTags.UserTagModel"

local debugLog = false

--这个枚举的数字和后端发来的不见得一致，只是个前端用的魔法数，需要自行mapping
UserPaymentTag = {
	kNone = 0,
	kLow = 1,
	kMidLow = 2,
	kMidHigh = 3,
	kHigh = 4,

	kHigh4 = 5,
	kHigh5 = 6,
	kHigh6 = 7,
}

-- 服务器定义
UsetPaymentTagServer = {
	kNone = 1,   -- 0付费
	kLow = 2, 	 -- 低付费1di
	kMidLow = 3, -- 中低2zh
	kMidHigh = 4,  -- 中高(3zh2)
	kHigh_4 = 5, 	  -- 高付费（4gao）
	kHigh_5 = 6, 	  -- 高付费（5gao）
	kHigh_6 = 7,      -- 告负非（6gao)
}
UserPaymentTag2Index = {
	[UserPaymentTag.kNone] = 0,
	[UserPaymentTag.kLow] = 1,
	[UserPaymentTag.kMidLow] = 2,
	[UserPaymentTag.kMidHigh] = 3,
	[UserPaymentTag.kHigh4] = 4,
	[UserPaymentTag.kHigh5] = 5,
	[UserPaymentTag.kHigh6] = 6,
}
UserPaymentTagName = {}
for key, value in pairs(UserPaymentTag) do
	UserPaymentTagName[value] = key
end

function __test_UserTagManager_debugLog_switch( value )
	debugLog = value
end

UserTagManager = {}

local DpUserTagModel = require("ubf/old/gamePlay/userTags/DpUserTagModel.lua")

local function getCurrUid()
	return UserManager:getInstance():getUID() or "12345"
end

-- local function getLocalFilePath()
-- 	return localDataKey .. "_" .. tostring(getCurrUid()) .. ".ds"
-- end

-- local function getLocalLevelDataFilePath()
-- 	return localLevelDataKey .. "_" .. tostring(getCurrUid()) .. ".ds"
-- end

function UserTagManager:init()

end

--从后端返回更新本地标签系统，后端返回什么就更新什么，不返回的保持原有值不变
function UserTagManager:updateTagsByResp( resp , source )
	UserTagModel:getInstance():updateTags( resp , source )

	if resp.areaPaymentTag then
	    self.areaPaymentTag = resp.areaPaymentTag
	end

	if resp.recentPassLevelData then
		if resp.recentPassLevelData.dailyRecords then
			if debugLog then 
				printx( 1 , "UserTagManager:updateTagsByResp ~~~~~~~~~  recentPassLevelData.dailyRecords = " , table.serialize(resp.recentPassLevelData.dailyRecords)  )
			end

			local originList = {}

			for k , v in pairs( resp.recentPassLevelData.dailyRecords ) do

				-- local dailyData = {levelId = data.levelId , strategyID = data.strategyID , result = result}
				if #v > 0 then
					local dData = { dayIdx = tonumber(k) , list = v }
					table.insert( originList , dData )
				end
			end

			if #originList == 0 then
				return
			end

			table.sort( 
				originList , 
				function(a, b)
					return a.dayIdx < b.dayIdx
				end
			)

			if debugLog then 
				printx( 1 , "UserTagManager:updateTagsByResp ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ \n  originList = " , table.serialize(originList) , "\n\n" )
			end
			-- local endLevelDailyList = UserTagModel:getInstance():getLocalEndLevelDailyDataList( nowtimeDay , true )
			local localLevelData = UserTagModel:getInstance():getLocalLevelData()
			local endLevelTotalLog = localLevelData.endLevelTotalLog
			local endLevelDailyLog = localLevelData.endLevelDailyLog
			local activityDays = localLevelData.activityDays

			if debugLog then 
				printx( 1 , "UserTagManager:updateTagsByResp  oringin endLevelTotalLog = " , table.serialize( endLevelTotalLog ) , "\n\n" ) 
				printx( 1 , "UserTagManager:updateTagsByResp  oringin endLevelDailyLog = " , table.serialize( endLevelDailyLog ) , "\n\n" ) 
				printx( 1 , "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ \n\n\n")
			end

			local localMaxDay = 0

			if #endLevelTotalLog > 0 then
				localMaxDay = endLevelTotalLog[#endLevelTotalLog].nowtimeDay
			end
			

			local minI = 1
			if #originList > 15 then
				minI = #originList - 15
			end

			for i = #originList , minI , -1 do

				local _dData = originList[i]

				local function addToEndLevelLog( targetList )
					for k2 , v2 in ipairs( _dData.list ) do

						local _lf = v2 == 0

						local _d = self:__createOneLevelPlayDailyData( 
											_dData.dayIdx , 0 , 0 , v2 , _lf )

						table.insert( targetList , _d )

					end
				end

				if not endLevelDailyLog["d" .. tostring(_dData.dayIdx)] then

					local dayList = {}
					endLevelDailyLog["d" .. tostring(_dData.dayIdx)] = dayList

					addToEndLevelLog( dayList )
					addToEndLevelLog( endLevelTotalLog )

					if debugLog then printx( 1 , "UserTagManager:updateTagsByResp  add by server  = " , _dData.dayIdx , table.serialize( _dData )  ) end

					self:__addLevelPlayActivityDays( _dData.dayIdx , true )
				end
			end
			

			if #endLevelTotalLog > 0 then
				table.sort( 
					endLevelTotalLog , 
					function(a, b)
						return a.nowtimeDay < b.nowtimeDay
					end
				)

				while #endLevelTotalLog > 300 do
					table.remove( endLevelTotalLog , 1 )
				end
			end

			

			local nowtime = Localhost:timeInSec()
			local nowtimeDay = time2day()
			--应该确保只保留最近30天的数据
			UserTagModel:getInstance():clearLocalEndLevelDailyDataBeforDay( nowtimeDay - 30 )

			if debugLog then printx( 1 , "UserTagManager:updateTagsByResp  endLevelTotalLog  sort >>>>"  , table.serialize( endLevelTotalLog )  )  end

			self:updateLevelLogData()
		end

	end

end



-- 获取用户区域付费标签
function UserTagManager:getAreaPaymentTag()
	return self.areaPaymentTag
end

--获取用户当前的某个标签,自动校验过期时间和topLevel
--nameKey in global table : UserTagNameKey 或 UserTagNameKeyFullMap
function UserTagManager:getUserTag( nameKey )
	return UserTagModel:getInstance():getUserTag( nameKey )
end

--获取用户当前标签的值，以及其附加参数，且不做任何本地校验（即返回原始后端的值）
--将根据nameKey，同时返回nameKey，nameKey+topLevelIdSuffix，nameKey+topLevelIdLengthSuffix，nameKey+endTimeSuffix
--nameKey in global table : UserTagNameKey 或 UserTagNameKeyFullMap
function UserTagManager:getUserTagBySeries( nameKey )
	return UserTagModel:getInstance():getUserTagBySeries( nameKey )
end

--主动请求后端刷新一次DifficultyTag
function UserTagManager:refreshDifficultyTag( levelId , callback , source , notSyncLoad)
	UserTagModel:getInstance():refreshDifficultyTag( levelId , callback , source , notSyncLoad )
end

function UserTagManager:getTopLevelFailCounts()
	return UserTagModel:getInstance():getTopLevelFailCounts()
end

function UserTagManager:updateTopLevelFailCounts( failCounts )
	UserTagModel:getInstance():updateTopLevelFailCounts( failCounts )
end

function UserTagManager:getTopLevelLogicalFailCounts()
	return UserTagModel:getInstance():getTopLevelLogicalFailCounts()
end

function UserTagManager:updateTopLevelLogicalFailCounts( failCounts )
	UserTagModel:getInstance():updateTopLevelLogicalFailCounts( failCounts )
end

function UserTagManager:getNoBuffLogicalFailCounts()
	return UserTagModel:getInstance():getNoBuffLogicalFailCounts()
end

function UserTagManager:updateNoBuffLogicalFailCounts( failCounts )
	UserTagModel:getInstance():updateNoBuffLogicalFailCounts( failCounts )
end


function UserTagManager:getTopLevelPropUsedCount()
	return UserTagModel:getInstance():getTopLevelPropUsedCount()
end

function UserTagManager:updateTopLevelPropUsedCount( count )
	UserTagModel:getInstance():updateTopLevelPropUsedCount( count )
end

-- function UserTagManager:setLast60DayPayAmount( count )
-- 	UserTagModel:getInstance():setLast60DayPayAmount( count )
-- end

--近60天付费
function UserTagManager:getLast60DayPayAmount()
	return UserTagModel:getInstance():getLast60DayPayAmount()
end

--近28天付费
function UserTagManager:getLast28DayPayAmount()
	return UserTagModel:getInstance():getLast28DayPayAmount()
end

--历史总付费
function UserTagManager:getTotalPayAmount()
	return UserTagModel:getInstance():getTotalPayAmount()
end


function UserTagManager:getTagLocalUpdateTime(tagGroup)
	return UserTagModel:getInstance():getTagLocalUpdateTime( tagGroup )
end

function UserTagManager:getUserTagStaticConfig( nameKey )
	return UserTagModel:getInstance():getUserTagStaticConfig( nameKey )
end

--任何原因导致的topLevel变化都算，包括过关且有星级，解锁区域，召回，跳关，好友帮忙打关等
function UserTagManager:onTopLevelChanged()
	UserTagManager:updateTopLevelFailCounts( 0 )
	UserTagManager:updateTopLevelLogicalFailCounts( 0 )
	UserTagManager:updateTopLevelPropUsedCount( 0 )
	UserTagManager:updateNoBuffLogicalFailCounts( 0 )

	if UserTagAutomationManager then
		UserTagAutomationManager:getInstance():checkTagHasChanged( UserTagDCSource.kPassLevel )
	end
end

function UserTagManager:isReturnBackUser()
	local tag =self:getUserTag( UserTagNameKeyFullMap.kActivation )
	return tag == UserTagValueMap[UserTagNameKeyFullMap.kActivation].kReturnBack
end



-----------------------------------------------------

if _G.AI_PLAY_GAME_MODE then 
	DpUserTagModel:init()
elseif Notify then
	Notify:register( Notify.EVENT.kUserDataInitByLocal , function (datas)
		DpUserTagModel:init()
	end )
end


--从后端返回更新本地标签系统，后端返回什么就更新什么，不返回的保持原有值不变
function UserTagManager:updateDpTagsByResp( resp , source )
	DpUserTagModel:updateTags( resp , source )
end

function UserTagManager:getDpTagValue( tagId )
	return DpUserTagModel:getTagValue( tagId )
end

function UserTagManager:getDpTagOriginValue( tagId )
	return DpUserTagModel:getTagOriginValue( tagId )
end

function UserTagManager:checkWillLoseByDpTag()
	return DpUserTagModel:checkDpWillLoseTag()
end

function UserTagManager:checkHasDpTag(tagId)
    return DpUserTagModel:checkHasDpTag(tagId)
end
-----------------------------------------------------

function UserTagManager:getLocalLevelData()
	local localLevelData = UserTagModel:getInstance():getLocalLevelData()
	return localLevelData
end

function UserTagManager:getSceneLiftLevelTagData()
	local localLevelData = UserTagModel:getInstance():getLocalLevelData()

	if localLevelData then
		return localLevelData.levelTagInfo
	end

	return nil
end

function UserTagManager:updateLevelLogData()

	local localLevelData = UserTagModel:getInstance():getLocalLevelData()
	local endLevelTotalLog = localLevelData.endLevelTotalLog

	local nowtime = Localhost:timeInSec()
	local nowtimeDay = time2day()

	if debugLog then printx( 1 ,"UserTagManager:updateLevelLogData nowtimeDay = " , nowtimeDay) end

	local levelTagInfo = {
		C1 = 0,
		C2 = 0,
		D0 = 0,
		D1 = 0,
		D2 = 0,
		D3 = 0,
	}

	local cacheNums = {
		_C1 = 0,
		_C2 = 0,

		_D0 = 0,
		_D1 = 0,
		_D2 = 0,
		_D3 = 0,

		_TD0 = 0,
		_TD1 = 0,
		_TD2 = 0,
		_TD3 = 0,
	}

	local function checkDailyLevelPlayFrequency(day , isLastThreeDay)
		local endLevelDailyList = UserTagModel:getInstance():getLocalEndLevelDailyDataList( day , false )

		-- printx( 1 , "checkDailyLevelPlayFrequency ~~~ " , day , isLastThreeDay )

		if endLevelDailyList then
			for idx , dailyData in ipairs(endLevelDailyList) do
				if dailyData.result == 1 or dailyData.isLogicalFail then
					if isLastThreeDay then
						cacheNums._C1 = cacheNums._C1 + 1
					else
						cacheNums._C2 = cacheNums._C2 + 1
					end
				end
			end
		end

		-- printx( 1 , "checkDailyLevelPlayFrequency cacheNums >>>> " , table.serialize(cacheNums))
	end

	local function checkDailyLevelPass(day , isLastThreeDay)
		local endLevelDailyList = UserTagModel:getInstance():getLocalEndLevelDailyDataList( day , false )

		-- printx( 1 , "checkDailyLevelPass ~~~ " , day , isLastThreeDay )

		if endLevelDailyList then
			for idx , dailyData in ipairs(endLevelDailyList) do

				if isLastThreeDay then

					if dailyData.result == 1 then
						cacheNums._D1 = cacheNums._D1 + 1
					end

					cacheNums._TD1 = cacheNums._TD1 + 1
				else

					if dailyData.result == 1 then
						cacheNums._D2 = cacheNums._D2 + 1
					end

					cacheNums._TD2 = cacheNums._TD2 + 1
					
				end
			end
		end

		-- printx( 1 , "checkDailyLevelPass cacheNums >>>> " , table.serialize(cacheNums))
	end

	--[[
	3、用户闯关频率（衡量闯关次数）的标签
	记录用户最近15个活跃日（不含当天的有过闯关）的主线闯关数据
	计算：最近3活跃日的平均闯关次数  C1、其余12个活跃日的平均闯关次数 C2

	4、用户过关能力（衡量闯关成功的能力）的标签
	记录用户最近300次以及15个活跃日（有过闯关）闯关的结果数据
	计算：最近10次的闯关难度D0；最近3个活跃日的闯关难度D1、  其余12个活跃日的闯关难度D2，最近61-300的闯关难度为D3
	]]

	local activityDays = localLevelData.activityDays

	if debugLog then printx( 1 , "activityDays = " , table.serialize(activityDays) ) end

	local totalDayCount = #activityDays

	local minDayCount = 1
	if #activityDays < 16 then 
		minDayCount = 1
	else
		minDayCount = #activityDays - 16
	end

	-- printx( 1 , "totalDayCount = " , totalDayCount , "nowtimeDay = " , nowtimeDay )


	-- nowtimeDay
	local lastestActDay = activityDays[#activityDays] or 0
	local passToday = nowtimeDay <= lastestActDay  

	for idx = totalDayCount , minDayCount , -1 do

		local dayIdx = activityDays[idx]
		-- printx( 1 , "idx:" , idx , "dayIdx:" , dayIdx , "totalDayCount:" , totalDayCount)

		

		if passToday then

			if idx ~= totalDayCount then

				if idx > totalDayCount - 4 then
					checkDailyLevelPass(dayIdx , true)
					checkDailyLevelPlayFrequency(dayIdx , true)
				else
					checkDailyLevelPass(dayIdx , false)
					checkDailyLevelPlayFrequency(dayIdx , false)
				end
			end
		else

			if idx > totalDayCount - 3 then
				checkDailyLevelPass(dayIdx , true)
				checkDailyLevelPlayFrequency(dayIdx , true)
			elseif idx > totalDayCount - 15 then
				checkDailyLevelPass(dayIdx , false)
				checkDailyLevelPlayFrequency(dayIdx , false)
			end
		end
	end

	local totalCount = 300
	if #endLevelTotalLog < totalCount then
		totalCount = #endLevelTotalLog
	end

	for ia = totalCount , 1 , -1 do

		local playData = endLevelTotalLog[ia]

		if ia <= totalCount - 60 then
			if playData.result == 1 then
				cacheNums._D3 = cacheNums._D3 + 1
			end
			cacheNums._TD3 = cacheNums._TD3 + 1
		elseif ia > totalCount - 10 then
			if playData.result == 1 then
				cacheNums._D0 = cacheNums._D0 + 1
			end
			cacheNums._TD0 = cacheNums._TD0 + 1
		end
	end


	levelTagInfo.C1 = cacheNums._C1 / 3
	levelTagInfo.C2 = cacheNums._C2 / 12

	for ib = 0 , 3 do
		if cacheNums["_D" .. tostring(ib)] == 0 then
			levelTagInfo["D" .. tostring(ib)] = 1000000
		else
			levelTagInfo["D" .. tostring(ib)] = cacheNums["_TD" .. tostring(ib)] / cacheNums["_D" .. tostring(ib)]
		end
	end

	localLevelData.levelTagInfo = levelTagInfo
	localLevelData.levelTagInfoCache = cacheNums

	if debugLog then 
		printx( 1 , "levelTagInfo~~~~~~~~~~~~~~~~~~~~~~~~~   " , table.serialize(localLevelData) )
		-- -- printx( 1 , "levelTagInf222222 o~~~~~~~~~~~~~~~~~~~~~~~~~   " , table.tostring(localLevelData.endLevelDailyLog) )
		-- printx( 1 , "levelTagInf2333333 o~~~~~~~~~~~~~~~~~~~~~~~~~   " , table.serialize(localLevelData.endLevelDailyLog["d18557"]) )
	end

	UserTagModel:getInstance():flushLocalLevelData()
end

function UserTagManager:onGameLaunch()
	if debugLog then printx( 1 , "UserTagManager:onGameLaunch" ) end

	-- UserTagModel:getInstance():getLocalendLevelDailyLog()
	-- UserTagModel:getInstance():getLocalEndLevelDailyLog()

end

function UserTagManager:onActStartLevel( startLevelData )
	if debugLog then printx( 1 , "UserTagManager:onActStartLevel" ) end

	
end

function UserTagManager:__createOneLevelPlayDailyData( nowtimeDay , levelId , strategyID , result , isLogicalFail )
	local dailyData = { nowtimeDay = nowtimeDay , levelId = levelId , strategyID = strategyID , result = result , isLogicalFail = isLogicalFail }
	return dailyData
end

function UserTagManager:onEndLevel( result , data )
	if debugLog then printx( 1 , "UserTagManager:onEndLevel  ================================ " , result , data, debug.traceback()) end

	local function addPlayLog()

		local nowtime = Localhost:timeInSec()
		local nowtimeDay = time2day()

		local endLevelDailyList = UserTagModel:getInstance():getLocalEndLevelDailyDataList( nowtimeDay , true )
		local localLevelData = UserTagModel:getInstance():getLocalLevelData()
		
		local endLevelTotalLog = localLevelData.endLevelTotalLog
		if not endLevelTotalLog then
			endLevelTotalLog = {}
			localLevelData.endLevelTotalLog = endLevelTotalLog
		end

		local levelPlayCountMap = localLevelData.levelPlayCountMap
		if not levelPlayCountMap then
			levelPlayCountMap = {}
			localLevelData.levelPlayCountMap = levelPlayCountMap
		end

		local dailyData = self:__createOneLevelPlayDailyData( nowtimeDay , data.levelId , data.strategyID , result , false )
		if result == 3 or result == 4 then
			local realCostMove = data.realCostMove or 0
			local staticLevelMoves = data.staticLevelMoves or 0

			local mainLogic = GameBoardLogic:getCurrentLogic()
			if mainLogic and mainLogic:getBoardModel() then
				local debugDeltaMoves = mainLogic:getBoardModel().debugDeltaMoves or 0
				staticLevelMoves = staticLevelMoves + debugDeltaMoves	-- 在计算时要支持通过工具修改的步数的情况
			end

			if realCostMove > 0 and staticLevelMoves > 0 and realCostMove / staticLevelMoves >= 0.5 then
				dailyData.isLogicalFail = true
			end
		elseif result == 2 then
			dailyData.isLogicalFail = true
		end

		table.insert( endLevelTotalLog , dailyData )
		while #endLevelTotalLog > 300 do
			table.remove( endLevelTotalLog , 1 )
		end

		table.insert( endLevelDailyList , dailyData )


		if not levelPlayCountMap[ tostring( dailyData.levelId ) ] then
			levelPlayCountMap[ tostring( dailyData.levelId ) ] = 0
		end

		levelPlayCountMap[ tostring( dailyData.levelId ) ] = levelPlayCountMap[ tostring( dailyData.levelId ) ] + 1


		-- printx( 1 , "levelPlayCountTodayMap ============ " , table.tostring(levelPlayCountTodayMap) )
		-- debug.debug()

		local levelPlayCountTodayMap = localLevelData.levelPlayCountTodayMap
		if not levelPlayCountTodayMap then
			levelPlayCountTodayMap = {}
			localLevelData.levelPlayCountTodayMap = levelPlayCountTodayMap
		end

		if not levelPlayCountTodayMap.nowtimeDay then
			levelPlayCountTodayMap.nowtimeDay = nowtimeDay
		end

		if levelPlayCountTodayMap.nowtimeDay ~= nowtimeDay then
			levelPlayCountTodayMap.nowtimeDay = nowtimeDay
			levelPlayCountTodayMap.todayPlayCount = 0
		end

		if not levelPlayCountTodayMap.todayPlayCount then levelPlayCountTodayMap.todayPlayCount = 0 end
		levelPlayCountTodayMap.todayPlayCount = levelPlayCountTodayMap.todayPlayCount + 1

		self:__addLevelPlayActivityDays( nowtimeDay )
		
		--应该确保只保留最近30天的数据
		UserTagModel:getInstance():clearLocalEndLevelDailyDataBeforDay( nowtimeDay - 30 )
	end



	local contextTopLevelId = GamePlayContext:getInstance().levelInfo.currTopLevelId

	if debugLog then printx( 1 , "UserTagManager:onEndLevel  data.levelId , contextTopLevelId " , data.levelId , contextTopLevelId ) end
	if data.levelId == contextTopLevelId then
		addPlayLog()
		self:updateLevelLogData()
	end
end

function UserTagManager:__addLevelPlayActivityDays( nowDayIndex , fourceAdd )

	local localLevelData = UserTagModel:getInstance():getLocalLevelData()

	if #localLevelData.activityDays == 0 then
		table.insert( localLevelData.activityDays , nowDayIndex )
	else

		if fourceAdd then

			for k , v in ipairs(localLevelData.activityDays) do
				if v == nowDayIndex then
					return
				end
			end
			table.insert( localLevelData.activityDays , nowDayIndex )
			table.sort( 
				localLevelData.activityDays , 
				function(a, b)
					return a < b
				end
			)
		else
			if localLevelData.activityDays[#localLevelData.activityDays] < nowDayIndex then
				table.insert( localLevelData.activityDays , nowDayIndex )
			end
		end
		
	end

	if #localLevelData.activityDays > 30 then
		table.remove( localLevelData.activityDays  , 1 )
	end

end

function UserTagManager:onActPassLevel( passLevelData )
	if debugLog then printx( 1 , "UserTagManager:onActPassLevel" ) end

	self:onEndLevel( 1 , passLevelData )
end

function UserTagManager:onActFailLevel( failLevelData )
	if debugLog then printx( 1 , "UserTagManager:onActFailLevel" ) end

	self:onEndLevel( 2 , failLevelData )
end

function UserTagManager:onActQuitLevel( failLevelData )
	if debugLog then printx( 1 , "UserTagManager:onActQuitLevel" ) end

	self:onEndLevel( 3 , failLevelData )
end

function UserTagManager:onActPlayAgainQuitLevel( failLevelData )
	if debugLog then printx( 1 , "UserTagManager:onActPlayAgainQuitLevel" ) end
	self:onEndLevel( 4 , failLevelData )
end

function UserTagManager:onActPassDay()
	if debugLog then printx( 1 , "UserTagManager:onActPassDay") end

	local nowtime = Localhost:timeInSec()
	local nowtimeDay = time2day()

	local localLevelData = UserTagModel:getInstance():getLocalLevelData()

	local levelPlayCountTodayMap = localLevelData.levelPlayCountTodayMap
	if not levelPlayCountTodayMap then
		levelPlayCountTodayMap = {}
		localLevelData.levelPlayCountTodayMap = levelPlayCountTodayMap
	end

	levelPlayCountTodayMap.nowtimeDay = nowtimeDay
	levelPlayCountTodayMap.todayPlayCount = 0

	self:updateLevelLogData()

end

--获取用户付费标签
function UserTagManager:getUserPaymentTag( ... )
	local userPayAmount = self:getLast60DayPayAmount() or 0
	if userPayAmount >= 240 then
		return UserPaymentTag.kHigh
	elseif userPayAmount >= 47 then
		return UserPaymentTag.kMidHigh
	elseif userPayAmount >= 13 then
		return UserPaymentTag.kMidLow
	elseif userPayAmount > 0 then
		return UserPaymentTag.kLow
	else
		return UserPaymentTag.kNone
	end
end

local function _getPaymentTagByAmount(amount)
	amount = amount or 0
	if amount >= 3000 then
		return UserPaymentTag.kHigh6
	elseif amount >= 1000 then
		return UserPaymentTag.kHigh5
	elseif amount >= 240 then
		return UserPaymentTag.kHigh4
	elseif amount >= 47 then
		return UserPaymentTag.kMidHigh
	elseif amount >= 13 then
		return UserPaymentTag.kMidLow
	elseif amount > 0 then
		return UserPaymentTag.kLow
	else
		return UserPaymentTag.kNone
	end
end

function UserTagManager:getUserPaymentTag2()
	local userPayAmount = self:getLast60DayPayAmount()
	return _getPaymentTagByAmount(userPayAmount)
end

-- 获取用户付费标签，包含本次登录时新增的支付额度
function UserTagManager:getUserPaymentTag2Timely()
	local userPayAmount = self:getLast60DayPayAmount() + UserManager:getInstance():getUserExtendRef():getRmbPurchaseThisSession()
	return _getPaymentTagByAmount(userPayAmount)
end

function UserTagManager:getUserPaymentTag2ServerVersion( ... )
	-- 前端版本：	 				无0 低1 中低2 中高3 四高5 五高6 六高7
	-- 后端版本：空0（前端无对应值）  无1 低2 中低3 中高4 四高5 五高6 六高7
	local clientVersionPaymentTag = self:getUserPaymentTag2()
	if clientVersionPaymentTag < 4 then
		return clientVersionPaymentTag + 1
	else
		return clientVersionPaymentTag
	end
end

--获取某个功能标签
function UserTagModel:getBoolTagRet(featureName)

	return DpUserTagModel:getBoolTagRet(featureName)
end