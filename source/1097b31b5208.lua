require "amf.script.tool.xml.LuaXml"
-- require "hecore.utils"  -- 前边require过了

local log = nil
--
--


MaintenanceFeature = class("MaintenanceFeature")

MaintenanceModeType = {
	kDefault = "default",
	kGroup = "group",
	kOrthogonalGroup = "orthogonal_group",
	kOrthogonalGroupV2 = "orthogonal_group_v2"
}

MaintenanceFilterListType = {

	kWhite = "white",
	kBlack = "black",
}

MaintenanceConfigName = {
	kLocalData = "localData" ,
	kMaintenance = "maintenance" ,
	kAI_Maintenance = "ai_maintenance" ,
	kOverseasMaintenance = "maintenance_mobile" ,
	kLevelConfigGroup = "level_config_group" ,
	-- kDP_Maintenance = "dp_maintenance" ,
}

MaintenanceNameHead = {
	[MaintenanceConfigName.kAI_Maintenance] = "Exp_" ,
	-- [MaintenanceConfigName.kDP_Maintenance] = "DP_" ,
}

local levelConfigGroupLindKey = "level_config_group_linked"

function MaintenanceFeature:ctor()
	self.enable = false
end
function MaintenanceFeature:fromXML( src )
	self:fromLua(src)
end

function MaintenanceFeature:encode()
	local ret = {}
	ret.enable = self.enable
	ret.value = self.value
	ret.id = self.id
	ret.name = self.name
	ret.beginDate = self.beginDate
	ret.endDate = self.endDate
	ret.regBeginDate = self.regBeginDate
	ret.regEndDate = self.regEndDate
	ret.extra = self.extra
	ret.mode = self.mode
	ret.review = self.review
	ret.whitelist = self.whitelist
	ret.sourceDataType = self.sourceDataType
	ret.originDataType = self.originDataType
	ret.metaVersion = self.metaVersion

	if self.filterlist and #self.filterlist > 0 then
		ret.filterlist = tostring( self.filterlistMode ) .. ";"
		for i = 1 , #self.filterlist do
			if i == #self.filterlist then
				ret.filterlist = ret.filterlist .. tostring(self.filterlist[i])
			else
				ret.filterlist = ret.filterlist .. tostring(self.filterlist[i]) ..","
			end
		end
	end

	if self.groupChild then
		for k,v in ipairs(self.groupChild) do
			local datastr = ""
			if #v.modules == 1 then
				datastr = v.modules[1] .. ";" .. v.weigh
			else
				for i = 1 , #v.modules do
					if i == #v.modules then
						datastr = datastr .. v.modules[i]
					else
						datastr = datastr .. v.modules[i] .. ","
					end
				end
				datastr = datastr .. ";" .. v.weigh
			end

			if v.algorithmId then
				datastr = datastr .. ";" .. v.algorithmId
			end

			ret["child" .. tostring(k)] = datastr
		end
	end
	return ret
end

function MaintenanceFeature:isInWhitelist()
	local whitelist = self.whitelist
	if whitelist then
		local uid = tonumber(getSafeUid()) or 0
		local uids = whitelist:split(",")

		for _,ud in ipairs(uids) do
			if tonumber(ud) == uid then
				return true
			end
		end
	end
	return false
end

function MaintenanceFeature:isInFilterlist()

	if self.cacheResult then
		return self.cacheResult.result
	end

	self.cacheResult = {}

	local filterlist = self.filterlist
	if filterlist and #filterlist > 0 then
		local uid = getSafeUid()

		for k,v in ipairs( filterlist ) do
			if tostring(v) == tostring(uid) then
				self.cacheResult.result = true
				return true
			end
		end
	end
	self.cacheResult.result = false
	return false
end

function MaintenanceFeature:fromLua(src , configFileName, version)
	if not src then return end
	-- printx( 1 , "MaintenanceFeature:fromLua  1 " , configFileName , src.name)
	if not configFileName then configFileName = MaintenanceConfigName.kMaintenance end

	self.enable = string.lower(tostring(src.enable)) == "true"
	self.value = src.value
	self.id = src.id

	if configFileName == MaintenanceConfigName.kLocalData then
		self.metaVersion = src.metaVersion
		self.originDataType = src.originDataType
	else
		self.metaVersion = version
		self.originDataType = configFileName
	end

	-- if configFileName == MaintenanceConfigName.kAI_Maintenance then
	-- 	self.name = MaintenanceNameHead[MaintenanceConfigName.kAI_Maintenance] .. src.name --增加统一前缀避免重名
	-- -- elseif configFileName == MaintenanceConfigName.kAI_Maintenance then
	-- -- 	self.name = MaintenanceNameHead[MaintenanceConfigName.kAI_Maintenance] .. src.name --增加统一前缀避免重名
	-- else
		self.name = src.name
	-- end

	self.sourceDataType = configFileName

	self.beginDate = src.beginDate
	self.endDate = src.endDate
	self.regBeginDate = src.regBeginDate
	self.regEndDate = src.regEndDate
	self.extra = src.extra
	self.mode = src.mode
	self.review = string.lower(tostring(src.review)) == "true"
	self.groupChild = {}
	self.totalGroupWeigh = 0
	self.whitelist = src.whitelist
	self.groupVersion = "watingForCreate"

	self.filterlist = {}
	self.filterlistMode = MaintenanceFilterListType.kWhite

	if src.filterlist then
		local filterlistArr = src.filterlist:split(";")
		if filterlistArr and #filterlistArr >= 2 then

			if tostring( filterlistArr[1] ) == MaintenanceFilterListType.kWhite then
				self.filterlistMode = MaintenanceFilterListType.kWhite
			elseif tostring( filterlistArr[1] ) == MaintenanceFilterListType.kBlack then
				self.filterlistMode = MaintenanceFilterListType.kBlack
			end

			local uidArr = tostring(filterlistArr[2]):split(",")

			if uidArr then
				for i = 1 , #uidArr do
					table.insert( self.filterlist , tostring(uidArr[i]) )
				end
			end
		end
	end


	if self.extra and type(self.extra) == "string" then
		local _list = string.split( self.extra , ";" )
		if _list[1] == levelConfigGroupLindKey then
			local levelGroupExpId = _list[2]
			if levelGroupExpId and tostring(tonumber(levelGroupExpId)) == levelGroupExpId then
				self.levelGroupExpId = levelGroupExpId
			end
		end
	end


	if not self.mode then self.mode = MaintenanceModeType.kDefault end

	local modeInfo = nil
	if src.mode then
		modeInfo = src.mode:split(";")
	end

	local mode = nil
	local modeData = nil

	if modeInfo then
		mode = modeInfo[1]
		modeData = modeInfo[2]
	end

	self.modeValue = mode

	if self.modeValue then

		if self.modeValue == MaintenanceModeType.kGroup
			or self.modeValue == MaintenanceModeType.kOrthogonalGroup
			or self.modeValue == MaintenanceModeType.kOrthogonalGroupV2 then

			if self.modeValue == MaintenanceModeType.kGroup then
				if not modeData then
					self.groupTail = 4
				else
					self.groupTail = tonumber(modeData)
				end
			else
				self.groupTail = 8 --kOrthogonalGroup模式锁死8位
				self.orthogonalVersion = modeData
			end

			local configChildrens = {}
			for i = 1 , 99 do
				if src["child" .. tostring(i)] then
					table.insert( configChildrens , src["child" .. tostring(i)] )
				end
				if src["c" .. tostring(i)] then
					table.insert( configChildrens , src["c" .. tostring(i)] )
				end
			end

			local totalChildStr = ""
			for k,v in ipairs(configChildrens) do
				totalChildStr = totalChildStr .. v
				local t1 = v:split(";")
				local modules = nil
				local weigh = nil
				local algorithmId = nil

				if t1 then
					if t1[1] then
						modules = t1[1]:split(",")
					end

					if t1[2] then
						weigh = tonumber(t1[2]) or 0
					end

					if t1[3] then
						algorithmId = tostring(t1[3])
					end
				end

				if modules and weigh then

					self.totalGroupWeigh = self.totalGroupWeigh + weigh
						table.insert( self.groupChild , {
															idx = k ,
															modules = modules ,
															weigh = weigh ,
															weighT = self.totalGroupWeigh ,
															algorithmId = algorithmId ,
															enable = self.enable
														}
									)
				end
			end

			if self.modeValue == MaintenanceModeType.kOrthogonalGroup or self.modeValue == MaintenanceModeType.kOrthogonalGroupV2 then

				local arr1 = totalChildStr:split(";")
				local fixStr = nil
				for k1 , v1 in ipairs(arr1) do
					local arr2 = v1:split(",")
					local mstr = nil
					for k2 , v2 in ipairs(arr2) do
						if not mstr then
							mstr = v2
						else
							mstr = mstr .. "+" .. v2
						end
					end
					if not fixStr then
						fixStr = mstr
					else
						fixStr = fixStr .. "_" .. mstr
					end
				end

				self.groupVersion = HeMathUtils:md5( fixStr )
				-- printx( 1 , "kOrthogonalGroup   groupVersion = " , fixStr , self.groupVersion )
			end

			-- self.groupTail = modeData
			--printx(1 , "groupTail  ===========================================   " , self.name ,src.mode, self.groupTail)

		-- elseif self.modeValue == MaintenanceModeType.kOrthogonalGroup then

			-- local flag = self.name


		end
	end
end

local instance = nil
MaintenanceManager = {}
MaintenanceManager.resultCache = {}
MaintenanceManager.dcCache = {}

local function hasRegTimeLimit(config)
	return config and (config.regBeginDate ~= nil or config.regEndDate ~= nil)
end

local majorBundleVersion = _G.bundleVersion or "1.54"
local ver = string.split(majorBundleVersion, '.')
if #ver > 1 then
	majorBundleVersion = ver[1].."."..ver[2]
end

function MaintenanceManager:getInstance()
	if not instance then
		instance = MaintenanceManager
		instance:init()
	end
	return instance
end

function MaintenanceManager:init()
	self.data = {}
	self:readFromStorage()
	self.configAppName = {}
	self:registerEvent()
end

function MaintenanceManager:registerEvent()
	_G.amfEC:registerNormal(NormalEvent.USER_LOGIN, function (evt)
		if not evt.data then return end
		if not evt.data.isOffline then
			self:loadMaintenanceDummyResultFromTestInfo(_G.amfBean("AccountManager"):getTestInfo())
			self:resolveMaintenanceCandidatesAfterLogin()
		end
	end)
end

-- 写入当前生效开关。Id2NameMap 只维护当前生效 id 到 name 的映射，候选开关不写入这里。
function MaintenanceManager:setMaintenanceFeature(feature)
	if not feature or not feature.name then return end
	if not self.data then self.data = {} end
	if not self.Id2NameMap then self.Id2NameMap = {} end

	for id, name in pairs(self.Id2NameMap) do
		if name == feature.name then
			self.Id2NameMap[id] = nil
		end
	end

	self.data[feature.name] = feature
	self.Id2NameMap[tostring(feature.id)] = feature.name
end

-- 线上同一数据源重新加载时，先移除旧候选，避免旧配置继续参与登录后重选。
function MaintenanceManager:removeMaintenanceCandidatesBySource(configFileName)
	if not self.maintenanceCandidateById then return end

	for id, feature in pairs(self.maintenanceCandidateById) do
		if feature.sourceDataType == configFileName then
			self.maintenanceCandidateById[id] = nil
		end
	end

	self.maintenanceCandidatesByName = {}
	for _, feature in pairs(self.maintenanceCandidateById) do
		if feature.name then
			self.maintenanceCandidatesByName[feature.name] = self.maintenanceCandidatesByName[feature.name] or {}
			table.insert(self.maintenanceCandidatesByName[feature.name], feature)
		end
	end
end

-- 保存所有通过平台和版本判断的线上候选；登录前后再从同名候选里选当前生效项。
function MaintenanceManager:addMaintenanceCandidate(feature)
	if not feature or not feature.id or not feature.name then return end
	self.maintenanceCandidateById = self.maintenanceCandidateById or {}
	self.maintenanceCandidatesByName = self.maintenanceCandidatesByName or {}

	local id = tostring(feature.id)
	self.maintenanceCandidateById[id] = feature
	self.maintenanceCandidatesByName[feature.name] = self.maintenanceCandidatesByName[feature.name] or {}
	table.insert(self.maintenanceCandidatesByName[feature.name], feature)
end

-- 登录前可能拿不到账号创建时间；拿不到时注册时间限制配置不会进入 self.data 生效。
function MaintenanceManager:getUserRegTime()
	local accountManager = _G.amfBean("AccountManager")
	local userCreateTime = accountManager and tonumber(accountManager:getUserCreateTimeDetail())
	if not userCreateTime or userCreateTime <= 0 then return nil end
	return userCreateTime / 1000
end

-- 同名候选的选择优先级：登录后注册时间命中 > 精确版本 > default > 线上来源。
function MaintenanceManager:getMaintenanceFeaturePriority(feature, regTimeAvailable)
	local priority = 0
	if regTimeAvailable and hasRegTimeLimit(feature) then
		priority = priority + 100
	end
	if feature.hasCurVersion then
		priority = priority + 10
	elseif feature.isDefaultVersion then
		priority = priority + 1
	end
	if feature.sourceDataType ~= MaintenanceConfigName.kLocalData then
		priority = priority + 1
	end
	return priority
end

-- 从同名候选中选当前阶段生效项；登录前会跳过需要注册时间但无法判断的候选。
function MaintenanceManager:selectMaintenanceFeature(features)
	if not features then return nil end

	local regTimeAvailable = self:getUserRegTime() ~= nil
	local selected = nil
	local selectedPriority = nil

	for _, feature in ipairs(features) do
		local regTimeOk = true
		if hasRegTimeLimit(feature) then
			regTimeOk = regTimeAvailable and self:checkRegTime(feature)
		end

		if regTimeOk then
			local priority = self:getMaintenanceFeaturePriority(feature, regTimeAvailable)
			if not selected or priority > selectedPriority or (priority == selectedPriority and tostring(feature.id) > tostring(selected.id)) then
				selected = feature
				selectedPriority = priority
			end
		end
	end

	return selected
end

-- 登录后账号注册时间可用，重新选择候选并同步到 self.data。
function MaintenanceManager:resolveMaintenanceCandidatesAfterLogin()
	if not self.maintenanceCandidatesByName then return end

	local hasChanged = false
	for name, features in pairs(self.maintenanceCandidatesByName) do
		local selected = self:selectMaintenanceFeature(features)
		local current = self:getMaintenanceByKey(name)

		if selected then
			if not current or tostring(current.id) ~= tostring(selected.id) then
				self:setMaintenanceFeature(selected)
				hasChanged = true
			end
		elseif current and current.sourceDataType ~= MaintenanceConfigName.kLocalData then
			self:clearSingleFeature(name)
			hasChanged = true
		end
	end

	if hasChanged then
		self:writeToStorage()
		self:onMaintenanceUpdated(MaintenanceConfigName.kMaintenance)
		self.resultCache = {}
		self.dcCache = {}
		self.groupChildRangeMap = {}
		if _G.amfEC then
			_G.amfEC:notifyFeature(FeatureEvent.MAINTENANCE_LOADED)
		end
	end
end

function MaintenanceManager:dcAllMaintenanceGroupDatas()
	local uid = tonumber(getSafeUid()) or 0
	if uid == 0 or uid == 12345 then
		return
	end
	-- 进入游戏时主动调用一次
	-- for i, v in ipairs({MaintenanceConfigName.kMaintenance, MaintenanceConfigName.kAI_Maintenance, MaintenanceConfigName.kLevelConfigGroup}) do
	for i, v in ipairs({MaintenanceConfigName.kMaintenance}) do
		setTimeOut(function()
			self:dcMaintenanceGroupData(v, uid)
		end, 0.1*i, "dcAllMaintenanceGroupDatas")
	end
end

-- function MaintenanceManager:setMetaInitCompleted()
-- 	self.metaInitCompleted = true

-- 	self:finishLoad()
-- end

function MaintenanceManager:isFinishedAllLoad( ... )
	return 	self.initFinished == self.initTotalCount and self.allfinished
end

function MaintenanceManager:finishLoad()
	if EnvUtil:isDevelopMode() then
		printx(0, "--------MaintenanceManager:finishLoad", self.initFinished, self.initTotalCount, self.metaInitCompleted, self.initOnFinishCallback)
	end
	if self.initFinished == self.initTotalCount then
		if self.allfinished then
			local needFlush = false
			for k,v in pairs(self.data) do
				-- printx( 1 , "MaintenanceManager:initialize  _onFinish" , v.name , v.sourceDataType )
				if v.sourceDataType == MaintenanceConfigName.kLocalData then
					needFlush = true
					self:clearSingleFeature( k )--数据源的某个key已经被删除，所以内存里的数据也要删除
					-- printx( 1 , "Delete !!!!!!!!!!!!!!!!" , k )
				end
			end

			if needFlush then
				--删除本地platform和version已经不符合的开关
				self:writeToStorage()
			end
			if self:isEnabled("DoNotChangeHost") then
				_G.DO_NOT_CHANGE_HOST = true
			end

			if _G.requestUseHttps or self:isEnabled("ForceHttps") then
				if EnvUtil:isDevelopMode() then
			    	_G.netDebugInfo = {}
				 --    local socket = require("socket.core")
				 --    local hostSP = string.split(NetworkConfig.dynamicHost, "/")
				 --    local host = hostSP[2]
				 --    local hostname, info = socket.dns.tohostname(host)
				 --    table.insert(_G.netDebugInfo, "host:"..tostring(hostname))
					-- table.insert(_G.netDebugInfo, table.tostring(info))
				end
				changeToHttpOrHttps(true)
			end

			self:_updateUseLowQualitySwitch()
            if EnvUtil:isMiniGameIOS() then
                if self:isEnabledInGroup("MinigameObeyMuteSwitch", "OFF") then
                    CALL_EASY_JS("globalThis.animalPlugin.appDelegate.setObeyMuteSwitch", "false")
                end
            end
		end

		if self.initOnFinishCallback then self.initOnFinishCallback() end

		if _G.amfEC then
			_G.amfEC:notifyFeature(FeatureEvent.MAINTENANCE_LOADED)
		end
	end
end

function MaintenanceManager:initializeLoadComplete(err)
	if not self.initFinished then
		self.initFinished = 0
	end

	if not self.initTotalCount then
		self.initTotalCount = 1
	end

	if self.allfinished == nil then
		self.allfinished = true
	end

	if err then
		self.allfinished = false
	end

	self.initFinished = self.initFinished + 1

	if self.initFinished == self.initTotalCount then
		self:finishLoad()
	end
end

function MaintenanceManager:initialize(onFinish)
	if EnvUtil:isAndroidNoNetworkMode() or _G.AI_PLAY_GAME_MODE then
		self.initFinished = 0
		if onFinish then onFinish() end
		return
	end

	self.initOnFinishCallback = onFinish

	local function _onFinish(err)
		self:initializeLoadComplete(err)
	end

	self.initFinished = 0
	self.initTotalCount = 1


	-- if __IOS_FB then
	-- 	self:onlineLoad( MaintenanceConfigName.kOverseasMaintenance , _onFinish )
  	-- else
  		self:onlineLoad( MaintenanceConfigName.kMaintenance , _onFinish )
  	-- end

	-- self:onlineLoad( MaintenanceConfigName.kAI_Maintenance , _onFinish )
end

function MaintenanceManager:readFromStorage()
	local data = LocalFile:readLocalFile("Maintenance.ds")

	-- printx( 1 , "MaintenanceManager:readFromStorage  ----------------------- \n\n " )

	-- for k,v in pairs(data) do
	-- 	printx( 1 , "MaintenanceManager:readFromStorage   " , v.name ,"\n" ,v.sourceDataType )
	-- end

	self:fromLua( data , MaintenanceConfigName.kLocalData )
end

function MaintenanceManager:writeToStorage()
	local data = {}
	for k,v in pairs(self.data) do
		table.insert(data, v:encode())
	end
	LocalFile:writeToStorage(data, "Maintenance.ds")

	-- printx( 1 , "MaintenanceManager:writeToStorage  ----------------------- \n\n " )

	-- for k,v in pairs(data) do
	-- 	printx( 1 , "MaintenanceManager:writeToStorage   " , v.name ,"\n" , v.sourceDataType )
	-- end

end

--maybe without local serialize
function MaintenanceManager:addFeatureOutside(feature)
	if not feature or not feature:is(MaintenanceFeature) then 
		assert(false, 'wrong feature!') 
	end

	-- if not self.ignoreClearFeatures then self.ignoreClearFeatures = {} end
	-- self.ignoreClearFeatures[feature.name] = true

	self:setMaintenanceFeature(feature)
end

function MaintenanceManager:clearFeatureDataWithoutIgnore()
	-- local data = {}
	-- if self.ignoreClearFeatures then
	-- 	for k,_ in pairs(self.ignoreClearFeatures) do
	-- 		data[k] = self.data[k]
	-- 	end
	-- end
	-- self.data = data
end

function MaintenanceManager:clearSingleFeature(featureName)
	if self.data then self.data[featureName] = nil end
	if self.Id2NameMap then
		for k,v in pairs(self.Id2NameMap) do
			if v == featureName then
				self.Id2NameMap[k] = nil
				break
			end
		end
	end
end

function MaintenanceManager:getMaintenanceNameById(maintenanceId)
	if self.Id2NameMap then
		return self.Id2NameMap[tostring(maintenanceId)]
	end
end

function MaintenanceManager:onlineLoad( configFileName , onFinish)

	if AIPlayRunMode and (_G.AI_PLAY_GAME_MODE == AIPlayRunMode.kCheckReplay) then
		if onFinish then onFinish() end
		return
	end

	local url = _G.AMFNetworkConfig:getMaintenanceURL()

	if _G.launchCmds and _G.launchCmds.ingame then
        if _G.launchCmds.mcts then
            if not _G.launchCmds.mock and _G.launchCmds.domain then
            	url = "http://10.2.0.8/"
            end
        end
    end

	local uid
	local userManager = _G.amfBean("UserManager")
	if userManager and userManager:hasInit() then
		uid = getSafeUid()
	else
		uid = _G.amfBean("CacheAccountLogic"):readLastLoginUid() or "12345"
	end

	local params = string.format("?name=" .. configFileName .. "&uid=%s&_v=%s&pkgmode=%s", uid, majorBundleVersion, _G.packageMode)
	if EnvUtil:isDevelopMode() then
	    params = string.format("?name=" .. configFileName .. "&uid=%s&_v=%s&pkgmode=%s&deviceid=%s", uid, majorBundleVersion, _G.packageMode, MetaInfo.getInstance():getUdid())
  	end

	url = url .. params

	local function onResponse(response)
    	if response.httpCode ~= 200 then
    		if EnvUtil:isDevelopMode() then printx(0, "get maintenance config error") end
    		if onFinish then onFinish(response.httpCode) end
    	else
    		local isFormatSuccess = false
    		local function doFormatData()
	    		local message = response.body
	    		local metaXML = xml.eval(message)
	    		local confList = xml.find(metaXML, configFileName)
	    		if confList then
	    			self.configAppName[configFileName] = confList.appName
		    		self:fromXML(confList , configFileName)
		    		self:writeToStorage()
		    		self:onMaintenanceUpdated( configFileName )
			    	isFormatSuccess = true
			    	self.resultCache = {}
			    	self.dcCache = {}
		    	end
		    end

			PerformanceMonitor:traceBegin("Maintenance doFormatData")

		    local success, err = pcall(doFormatData)

			PerformanceMonitor:traceEnd()
		    if success then
		    	if onFinish then onFinish() end
		    else
		    	if onFinish then onFinish(err) end
		    end
		    assert(isFormatSuccess,"MaintenanceManager:onlineLoad() data error! configFile: ".. tostring(configFileName))
    	end
	end
    AMFSimpleRequest.new(url, onResponse)
        :setTimeoutMs(10000)
        :setConnectionTimeoutMs(2000)
        :setGet(true)
        :execute()
end

function MaintenanceManager:clearCacheByName(maintenanceName)
	-- print("MaintenanceManager:clearCacheByName()", maintenanceName)
	if self.resultCache then
		for k,v in pairs(self.resultCache) do
			if v.maintenanceName == maintenanceName then
				self.resultCache[k] = nil
			end
		end
	end
end

function MaintenanceManager:onMaintenanceUpdated( configFileName )
	if configFileName == MaintenanceConfigName.kMaintenance then
		_G.httpsTestGroup = nil
		local md5Str = HeMathUtils:md5(MetaInfo:getInstance():getUdid())
		local remainder = tonumber(string.sub( md5Str , -8 ), 16) % 100
		local feature = self:getMaintenanceByKey("HttpsTestGroup")
		if feature and feature.enable then
			if feature.extra then
				for _, v in ipairs(string.split(feature.extra, ";")) do
					local pers = string.split(v, ",")
					if pers then
						local httpsWithLogStrs = string.split(pers[1] or "0", '-')
						local httpsWithLogMin = 0
						local httpsWithLogMax = 0
						if httpsWithLogStrs[2] then
							httpsWithLogMin = tonumber(httpsWithLogStrs[1]) or 0
							httpsWithLogMax = tonumber(httpsWithLogStrs[2]) or httpsWithLogMin
						else
							httpsWithLogMax = tonumber(httpsWithLogStrs[1]) or httpsWithLogMin
						end

						local withLogStrs = string.split(pers[2] or "0", '-')
						local withLogMin = 0
						local withLogMax = 0
						if withLogStrs[2] then
							withLogMin = tonumber(withLogStrs[1]) or 0
							withLogMax = tonumber(withLogStrs[2]) or withLogMin
						else
							withLogMax = tonumber(withLogStrs[1]) or withLogMin
						end

						if remainder >= httpsWithLogMin and remainder < httpsWithLogMax then
							_G.httpsTestGroup = 2
							break
						elseif remainder >= withLogMin and remainder < withLogMax then
							_G.httpsTestGroup = 1
							break
						end
					end
				end
			end
		end
		-- if EnvUtil:isDevelopMode() then
		-- 	RemoteDebug:uploadLogWithTag("HttpsTestGroup", "算出尾号：", remainder, ",分组：", _G.httpsTestGroup, ",开关：", table.tostring(feature))
		-- end
		if _G.httpsTestGroup == 2 then
			changeToHttpOrHttps(true)
		end

		_G.__HttpErrorLogUpload = MaintenanceManager:getInstance():isEnabled('HttpErrorLogUpload',  false)

		--loading图片轮播开关
	    local value = MaintenanceManager:getInstance():isEnabled('introAutoPlay',  false)
	    CCUserDefault:sharedUserDefault():setIntegerForKey("logo.isAutoPlay", value and 1 or 0)
	end
end

function MaintenanceManager:_updateUseLowQualitySwitch()
	if not EnvUtil:isIOS() then return end

	local mKey = "ios.use.low.quality.enable"
    local config = CCUserDefault:sharedUserDefault()
	local maintenance = self:getMaintenanceByKey("UseLowQualityEnable")
	if maintenance and maintenance.enable and type(maintenance.extra) == "string" then
		local udidList = string.split(maintenance.extra, ",")
		local inTestList = false
		local udid = MetaInfo:getInstance():getUdid()
		for _, v in pairs(udidList) do
			if v == udid then
				inTestList = true
				break
			end
		end
		if inTestList then
	        config:setBoolForKey(mKey, true)
        	config:flush()
	    else
	        if config:getBoolForKey(mKey, false) == true then
		        config:setBoolForKey(mKey, false)
	        	config:flush()
	    	end
		end
    else
    	if config:getBoolForKey(mKey, false) == true then
	        config:setBoolForKey(mKey, false)
        	config:flush()
    	end
	end
end

function MaintenanceManager:fromXML( src , configFileName )
	-- if EnvUtil:isDevelopMode() then printx(0, "MaintenanceManager:fromXML") end
	if src then self.version = src.version end
	self:fromLua(src , configFileName)
	if src and (not configFileName or configFileName == MaintenanceConfigName.kMaintenance) then
		local bundleVersion = _G.fullBundleVersion or majorBundleVersion
		CCUserDefault:sharedUserDefault():setStringForKey("maintenance_game_ver", bundleVersion)
		CCUserDefault:sharedUserDefault():flush()
	end
end

function MaintenanceManager:_isPfOkForInclude(platforms)
	if EnvUtil:isWinMacSimulator() or EnvUtil:isUnityEditor() then return true end
	return self:_isPfOk(platforms)
end

function MaintenanceManager:_isPfOkForExclude(platforms)
	return self:_isPfOk(platforms)
end

function MaintenanceManager:_isPfOk( platforms )
	local curPlatform = _G._PLATFORM_NAME
	local isCurPlatform = false
	
	if platforms then
		if EnvUtil:isAndroid() and table.indexOf(platforms, "android_all") then
			isCurPlatform = true
        elseif EnvUtil:isMiniGame() and table.indexOf(platforms, "minigame_all") then
            isCurPlatform = true
		elseif EnvUtil:isWXMiniGame() and table.indexOf(platforms, "minigame_wechat_all") then
			isCurPlatform = true
        elseif EnvUtil:isDYMiniGame() and table.indexOf(platforms, "minigame_tiktok_all") then
            isCurPlatform = true
        elseif EnvUtil:isALIPAYMiniGame() and table.indexOf(platforms, "minigame_alipay_all") then
            isCurPlatform = true
        elseif EnvUtil:isHuaweiMiniGame() and table.indexOf(platforms, "minigame_huawei_all") then
            isCurPlatform = true
        elseif EnvUtil:isUnionMiniGame() and table.indexOf(platforms, "minigame_union_all") then
            isCurPlatform = true
        elseif EnvUtil:isUnionOppoMiniGame() and table.indexOf(platforms, "minigame_oppo_all") then
            isCurPlatform = true
        elseif EnvUtil:isUnionMiMiniGame() and table.indexOf(platforms, "minigame_mi_all") then
            isCurPlatform = true			
        elseif EnvUtil:isKuaiShouMiniGame() and table.indexOf(platforms, "minigame_ks_all") then
            isCurPlatform = true
        elseif EnvUtil:isJdMiniGame() and table.indexOf(platforms, "minigame_jd_all") then
            isCurPlatform = true
		elseif EnvUtil:isAndroid() and PlatformConfig:isQQPlatform() and table.indexOf(platforms, "yingyongbao_all") then
			isCurPlatform = true
		elseif (table.indexOf(platforms, "default") ~= nil) or (table.indexOf(platforms, curPlatform) ~= nil) then
			isCurPlatform = true
		end
	end

	return isCurPlatform
end

function MaintenanceManager:checkRegTime(config)
	if config.regBeginDate == nil and config.regEndDate == nil then return true end

	local regTime = self:getUserRegTime()
	if not regTime then return false end

	if config.regBeginDate then
		local regBeginDate = parseDateStringToTimestamp(config.regBeginDate)
		if regTime < regBeginDate then return false end
	end

	if config.regEndDate then
		local regEndDate = parseDateStringToTimestamp(config.regEndDate)
		if regTime >= regEndDate then return false end
	end

	return true
end

-- 这里只判断平台和版本，注册时间在候选选择阶段处理。
function MaintenanceManager:checkPlatformAndVersion( config )	
	local platforms = nil
	local curPlatform = _G._PLATFORM_NAME
	local curVersion = majorBundleVersion

	--临时方案，感觉maintenance这里需要优化一下
	if config.name == 'oppo_phone' and EnvUtil:isAndroidPlatform(PlatformNameEnum.kOppo) then
		PlatformConfig:setOppoPhoneVersion( config.version )
	end

    if type(config.exclude_platforms) == "string" then
    	local excludePlatforms = config.exclude_platforms:split(",")
    	if self:_isPfOkForExclude(excludePlatforms) then
    		return false, false, false
    	end
    end

	if config.platform == nil or config.version == nil then return true, true, false end

	if type(config.platform) ~= "table" then
		platforms = config.platform:split(",")
	else
		platforms = config.platform
	end

	local versions = nil
	if type(config.version) ~= "table" then
		versions = config.version:split(",")
	else
		versions = config.version
	end

	local isCurPlatform = platforms and self:_isPfOkForInclude(platforms)

	--最小版本支持
	local minVersion = nil
	local delVersion = {}

	for _,v in ipairs(versions) do
		local mins, mine = string.find(v, "min:")
		if mins then
			minVersion = string.sub(v, mine+1)
		end

		local dels, dele = string.find(v, "del:")
		if dels then
			table.insert(delVersion, tonumber(string.split(string.sub(v, dele+1), '.')[2]))
		end
	end

	if minVersion then
		versions = {}
		local e = curVersion
		e = tonumber(string.split(tostring(e), '.')[2])
		for ver=tonumber(string.split(tostring(minVersion), '.')[2]) , e + 1 do
			if not table.indexOf(delVersion, ver) then
				table.insert(versions, string.format("1.%d", ver))
			end
		end
	end

	--有确切的版本号优先, fullBundleVersion 带小版本的版本号，不只是testflight包
	local hasCurVersion = versions and (table.indexOf(versions, curVersion) ~= nil or
		(EnvUtil:isAndroid() and _G.androidFullBundleVersion and table.indexOf(versions, _G.androidFullBundleVersion) ~= nil) or
		(EnvUtil:isOhos() and _G.fullBundleVersion and table.indexOf(versions, _G.fullBundleVersion) ~= nil) or
		(EnvUtil:isIOS() and _G.fullBundleVersion and table.indexOf(versions, _G.fullBundleVersion) ~= nil)) or
		(_G.fullBundleVersion and table.indexOf(versions, _G.fullBundleVersion))

	local isDefaultVersion = versions and versions[1] == "default"

	return isCurPlatform and (hasCurVersion or isDefaultVersion), hasCurVersion, isDefaultVersion
end

function MaintenanceManager:fromLua(src , configFileName)
	-- if EnvUtil:isDevelopMode() then printx(0, "MaintenanceManager:fromLua") end
	if not src then return end

	-- 本轮加载先按 name 收集，再统一选择，避免同名配置依赖 pairs 遍历顺序互相覆盖。
	local featuresByName = {}
	if configFileName ~= MaintenanceConfigName.kLocalData then
		self:removeMaintenanceCandidatesBySource(configFileName)
	end

	for k,config in pairs(src) do
		if type(config) == "table" then
			local platformVersionOk, hasCurVersion, isDefaultVersion = self:checkPlatformAndVersion(config)
			if platformVersionOk then
				local feature = MaintenanceFeature.new()
				feature:fromLua(config , configFileName, src.version)
				feature.hasCurVersion = hasCurVersion
				feature.isDefaultVersion = isDefaultVersion
				if feature ~= nil and feature.name ~= nil then
					featuresByName[feature.name] = featuresByName[feature.name] or {}
					table.insert(featuresByName[feature.name], feature)
					if configFileName ~= MaintenanceConfigName.kLocalData then
						self:addMaintenanceCandidate(feature)
					end
					-- printx(  1 , "ADD NEW feature:" , table.tostring(feature))
				end
			end
		end		
	end

	for _, features in pairs(featuresByName) do
		local feature = self:selectMaintenanceFeature(features)
		if feature then
			self:setMaintenanceFeature(feature)
		end
	end
	if configFileName ~= MaintenanceConfigName.kLocalData then
		self.maintenanceVersion = self.maintenanceVersion or {}
		self.maintenanceVersion[configFileName] = src.version
		-- if UserManager:hadInited() then
		-- 	self:dcMaintenanceGroupData(configFileName)
		-- end
	end

	self.dummyMaintenanceGroup = LocalFile:readDataByFileNameAndKey("DummyMaintenanceGroup", "saveData", {}, true)
end

function MaintenanceManager:dcMaintenanceGroupData(configFileName, uid)
	uid = tonumber(uid or getSafeUid()) or 0
	if uid == 0 or uid == 12345 then
		return
	end

	self.dcMaintenanceGroupCache = self.dcMaintenanceGroupCache or {}
	local date = os.date2( TimeKit:timeInSec() )
	local cacheKey = configFileName..tostring(uid).."_"..tostring(date.yday)
	if self.dcMaintenanceGroupCache[cacheKey] then
		return
	end

	self.dcMaintenanceGroupCache[cacheKey] = true

	local versionNum = self.maintenanceVersion and self.maintenanceVersion[configFileName]
	local groupData = {}
	for k,v in pairs(self.data) do
		if v.originDataType == configFileName and v.enable
				and (v.modeValue == MaintenanceModeType.kGroup or v.modeValue == MaintenanceModeType.kOrthogonalGroup or v.modeValue == MaintenanceModeType.kOrthogonalGroupV2) then
			local childIndex, algorithmId, onlyOneGroupLeft = self:getChildIndexAndalgorithmId( v , uid )
			if childIndex and not onlyOneGroupLeft then
				table.insert(groupData, string.format("%s,%s", v.id, childIndex))
			end
			if not versionNum then
				versionNum = v.metaVersion
			end
		end
	end
	if #groupData < 1 then return end

	local groups = table.join(groupData, ";")
	local dcData = {
		category = 'shiyan_exp',
		sub_category = configFileName,
		msg = mime.b64(groups),
		xml_version = versionNum,
		env_name = self.configAppName[configFileName] or _G.amfBean("AccountManager"):getAppName(),
	}
	DcUtil:UserTrack(dcData)
end

function MaintenanceManager:getMaintenanceByKey(key)

	local feature = nil
	if self.data then

		local head1= MaintenanceNameHead[ MaintenanceConfigName.kAI_Maintenance ]

		if self.data[key] and self.data[ head1 .. key ]then
			--
--
--
--

		end

		feature = self.data[key]
		if feature then
			return feature
		end

		feature = self.data[head1 .. key]
		if feature then
			return feature
		end

	end
	return feature
end

function MaintenanceManager:isInWhitelist( key )
	local maintenance = self:getMaintenanceByKey(key)
	if maintenance then
		return maintenance:isInWhitelist()
	end
	return false
end

function MaintenanceManager:isInFilterlist( key )
	local maintenance = self:getMaintenanceByKey(key)
	if maintenance then
		return maintenance:isInFilterlist()
	end
	return false
end

--defaultEnable有值时，默认返回defaultEnable
function MaintenanceManager:isEnabled(key, defaultEnable)
	local maintenance = self:getMaintenanceByKey(key)
	if _G.testFlightMode and key == "reviewVersion" then
		maintenance = self:getMaintenanceByKey("reviewVersionTF")
	end
	local flag = false
	local _useDefault = false
	if maintenance then
		flag = maintenance.enable
		if not maintenance.review and maintenance:isInFilterlist() then
			if maintenance.filterlistMode == MaintenanceFilterListType.kWhite then
				flag = true
			elseif maintenance.filterlistMode == MaintenanceFilterListType.kBlack then
				flag = false
			end
		end
	elseif defaultEnable ~= nil then
		flag = defaultEnable
		_useDefault = true
	end
	if key == "reviewVersion" then
		if _G.testFlightMode then
			return not maintenance or _G.fullBundleVersion == maintenance.extra
		end
		if EnvUtil:isAndroid() then
			local insideVersion = EnvUtil:getInsideVersion()
			if insideVersion:starts("testgray") then
				return false
			end
		end
        return flag, _useDefault
	end
	if maintenance and maintenance.review and self:isEnabled("reviewVersion") then
		flag = not flag
	end
	return flag, _useDefault
end

function MaintenanceManager:isEnabledWithLog(key, defaultEnable)
	local maintenance = self:getMaintenanceByKey(key)
	if _G.testFlightMode and key == "reviewVersion" then
		maintenance = self:getMaintenanceByKey("reviewVersionTF")
	end
	local flag = false

	local logFlagStr = "0"
	local function addLogStr(str)
		logFlagStr = logFlagStr .. "_" .. str
	end

	local function sendLogStr()
		local time = tostring(os.time())
		local uid = getSafeUid()
		local log = string.format("%s_%s__uid_%s__t_%s", key, logFlagStr, uid, time)
		he_log_error(log)
	end

	if maintenance then
		flag = maintenance.enable
		if flag then
			addLogStr("1")
		else
			addLogStr("2")
		end
		if not maintenance.review and maintenance:isInFilterlist() then
			if maintenance.filterlistMode == MaintenanceFilterListType.kWhite then
				addLogStr("3")
				flag = true
			elseif maintenance.filterlistMode == MaintenanceFilterListType.kBlack then
				addLogStr("4")
				flag = false
			end
		end
	elseif defaultEnable ~= nil then
		addLogStr("5")
		flag = defaultEnable
	end
	if key == "reviewVersion" then
		if _G.testFlightMode then
			return _G.fullBundleVersion == maintenance.extra
		end
        addLogStr("6")
        if flag then sendLogStr() end
        return flag
	end
	if maintenance and maintenance.review and self:isEnabled("reviewVersion") then
		flag = not flag
		addLogStr("7")
		if flag then sendLogStr() end
	end
	addLogStr("8")
	if flag then sendLogStr() end
	return flag
end

function MaintenanceManager:isEnabledConsiderBeginAndEndDate(key, defaultEnable)
	local flag = false
	if self:isEnabled(key, defaultEnable) then
		local activityBeginTime = -1
		local activityEndTime = -1
		local maintenance = self:getMaintenanceByKey(key)
		if maintenance then
			if maintenance.beginDate then
				activityBeginTime = parseDateStringToTimestamp(maintenance.beginDate)
			end
			if maintenance.endDate then
				activityEndTime = parseDateStringToTimestamp(maintenance.endDate)
			end
		end
		-- activityBeginTime = parseDateStringToTimestamp("2019-02-20 02:59:59")	--test
		-- activityEndTime = parseDateStringToTimestamp("2019-03-28 18:59:59")	--test
		local nowTime = TimeKit:timeInSec()
		if activityBeginTime and activityEndTime
			and activityBeginTime <= nowTime
			and activityEndTime >= nowTime
			then
			-- 时间符合
			flag = true
		end
	end
	return flag
end

--判断时间，beginTime和endTime分开判断,如果产品不配则默认满足
function MaintenanceManager:isEnabledConsiderBeginAndEndDate2(key, defaultEnable)
	local flag = false
	if self:isEnabled(key, defaultEnable) then
		local activityBeginTime
		local activityEndTime
		local maintenance = self:getMaintenanceByKey(key)
		if maintenance then
			if maintenance.beginDate then
				activityBeginTime = parseDateStringToTimestamp(maintenance.beginDate)
			end
			if maintenance.endDate then
				activityEndTime = parseDateStringToTimestamp(maintenance.endDate)
			end
		end
		-- activityBeginTime = parseDateStringToTimestamp("2019-02-20 02:59:59")	--test
		-- activityEndTime = parseDateStringToTimestamp("2019-03-28 18:59:59")	--test
		local nowTime = TimeKit:timeInSec()
        local flag1,flag2
		if activityBeginTime then
            flag1 = activityBeginTime <= nowTime
        else
            flag1 = true
        end

        if activityEndTime then
            flag2 = activityEndTime >= nowTime
        else
            flag2 = true
        end

        flag = flag1 and flag2
	end
	return flag
end

function MaintenanceManager:getUserGroupModules( maintenanceName , uid)
	--注意，该方法已停止维护，可能并不支持最新的分组算法

	local function getModules(feature)

		local rangeMap = self:getGroupChildRangeMap( maintenanceName )

		if rangeMap then

			local blockNum = 10000
			local groupTail = feature.groupTail

			if groupTail and type(groupTail) == "number" then
				local str = "1"
				for i = 1 , groupTail do
					str = str .. "0"
				end

				blockNum = tonumber(str)
			end

			local _uid = tonumber(uid) or 0
			local userWeighValue = _uid % blockNum

			local testInfo = _G.amfBean("AccountManager"):getTestInfo()
			if testInfo then

				local pars = string.split( testInfo , ";" )

				for k,v in ipairs(pars) do

					local arr = string.split( v , "_" )

					if arr[1] == "dummyUid" then
						_uid = tonumber(arr[2]) or 0
						userWeighValue = _uid % blockNum
					end
				end
			end

			for k,v in ipairs(rangeMap) do
				if userWeighValue >= v.startId and userWeighValue <= v.endId then
					return v.modules
				end
			end
		end

		return {}
	end

	local maintenanceFeature = self:getMaintenanceByKey( maintenanceName )

	if maintenanceFeature then

		if not maintenanceFeature.review and maintenanceFeature:isInFilterlist() then
			if maintenanceFeature.filterlistMode == MaintenanceFilterListType.kWhite then
				--TO DO
				return {}
			elseif maintenanceFeature.filterlistMode == MaintenanceFilterListType.kBlack then
				return {}
			end
		end

		local result = getModules( maintenanceFeature )
		return result
	else
		return {}
	end
end

function MaintenanceManager:getMaintenanceFeature(maintenanceName)
	return self:getMaintenanceByKey(maintenanceName)
end

function MaintenanceManager:getUserWeighValue( maintenanceName , uid )
	-- printx( 1 , "MaintenanceManager:getUserWeighValue  " , maintenanceName , uid )
	local _uid = tonumber(uid) or 0
	local groupVersion = "unknowVersion"

	local userWeighValue = -9999

	if _uid ~= 12345 and _uid ~= 0 and _uid <= 99999999999 then

		local feature = self:getMaintenanceFeature(maintenanceName)
		local orthogonalVersion = nil
		local tail = 8

		if feature then

			if not feature.groupVersion then
				feature.groupVersion = "unknowVersion"
			end
			groupVersion = feature.groupVersion
			if feature.groupTail and type(feature.groupTail) == "number" then
				tail = feature.groupTail
			end

			orthogonalVersion = feature.orthogonalVersion
		end

		local md5Str = nil
		if orthogonalVersion then
			md5Str = HeMathUtils:md5( tostring( orthogonalVersion ) .. tostring( _uid ) )
		else
			md5Str = HeMathUtils:md5( tostring( maintenanceName ) .. tostring( groupVersion ) .. tostring( _uid ) )
		end

		local md5StrTail = string.sub( md5Str , tail * -1 )

		if ( groupVersion == "unknowVersion" or groupVersion == "watingForCreate" ) and (not orthogonalVersion) then
			return userWeighValue , groupVersion
		end

		userWeighValue = tonumber(md5StrTail, 16) or 0
	end

	return userWeighValue , groupVersion
end

function MaintenanceManager:getChildIndexAndalgorithmId( feature , uid )

	local blockNum = 10000
	local groupTail = feature.groupTail

	local _uid = tonumber(uid) or 0
	local myUID = tonumber(getSafeUid())
	local userWeighValue = -9999

	if feature.modeValue == MaintenanceModeType.kGroup then
		if type(groupTail) == "number" then
			blockNum = math.pow(10, groupTail)
		end
		userWeighValue = _uid % blockNum
	elseif feature.modeValue == MaintenanceModeType.kOrthogonalGroup or feature.modeValue == MaintenanceModeType.kOrthogonalGroupV2 then
		userWeighValue = self:getUserWeighValue( feature.name , _uid )
	end

	local accountManager = _G.amfBean("AccountManager")
	local testInfo = accountManager and accountManager:getTestInfo() or nil
	local dummyGroupList = {}

	if testInfo and _uid == myUID then
		testInfo = tostring(testInfo)
		local pars = string.split( testInfo , ";" )

		for k,v in ipairs(pars) do

			local arr = string.split( v , "~" )

			if arr[1] == "dummyUid" then
				_uid = tonumber(arr[2]) or 0
				if feature.modeValue == MaintenanceModeType.kGroup then
					userWeighValue = _uid % blockNum
				end
			elseif arr[1] == "dummyGroup" then
				local dg = { switchName = tostring(arr[2]) , groupIndex = tonumber(arr[3]) }
				table.insert( dummyGroupList , dg )
			end
		end
	end

	if dummyGroupList and #dummyGroupList > 0 then
		for k , v in ipairs(dummyGroupList) do
			local headStr = MaintenanceNameHead[MaintenanceConfigName.kAI_Maintenance]
			if (v.switchName == feature.name or tostring(headStr .. v.switchName) == feature.name) and v.groupIndex then
				return v.groupIndex , feature.algorithmId
			end
		end
	end

	local groupsHasWeight = 0 -- 权重大于0的分组数量
	if feature.groupChild then
		for k1,v1 in ipairs(feature.groupChild) do
			if v1.weigh > 0 then
				groupsHasWeight = groupsHasWeight + 1
			end
		end
	end
	local onlyOneGroupLeft = groupsHasWeight < 2

	if feature.modeValue == MaintenanceModeType.kGroup then
		local rangeMap = self:getGroupChildRangeMap( feature.name )
		if rangeMap then
			for k,v in ipairs(rangeMap) do
				--userWeighValue
				if userWeighValue >= v.startId and userWeighValue <= v.endId then
					return k , v.algorithmId, onlyOneGroupLeft
				end
			end
		end
	elseif feature.modeValue == MaintenanceModeType.kOrthogonalGroup then
		if userWeighValue < 0 then
			return nil
		end

		local totalGroupWeigh = feature.totalGroupWeigh
		local currWeigh = userWeighValue % totalGroupWeigh + 1

		for k1,v1 in ipairs(feature.groupChild) do
			if currWeigh > v1.weighT - v1.weigh and currWeigh <= v1.weighT then
				return k1 , v1.algorithmId, onlyOneGroupLeft
			end
		end
	elseif feature.modeValue == MaintenanceModeType.kOrthogonalGroupV2 then
		if userWeighValue < 0 then
			return nil
		end

		local currWeigh = userWeighValue % 10000

		local rangeMap = self:getGroupChildRangeMap( feature.name )
		if rangeMap then
			for k,v in ipairs(rangeMap) do
				if currWeigh >= v.startId and currWeigh <= v.endId then
					return k , v.algorithmId, onlyOneGroupLeft
				end
			end
		end
	end

	return nil
end

function MaintenanceManager:convertGroupName2AlgorithmId(maintenanceName, groupName)
	local maintenanceFeature = self:getMaintenanceByKey( maintenanceName )
	if not maintenanceFeature then return end

	for k, v in ipairs(maintenanceFeature.groupChild or {}) do
		if table.includes(v.modules or {}, groupName) then
			return v.algorithmId
		end
	end
end

function MaintenanceManager:getMaintenanceTestResult(maintenanceName , moduleKey , uid)
	-- 在这定一个空方法，真正的方法在WCCommand_GlobalDebug
	return false, false
end

--获取开关的模拟结果
function MaintenanceManager:getMaintenanceDummyResult(maintenanceName , moduleKey , uid)

	local testResultEnable, testResult = self:getMaintenanceTestResult(maintenanceName , moduleKey , uid)
	if testResultEnable then
		-- printx(15,"被指定得开关：",maintenanceName, moduleKey, testResult)
		return true, testResult
	end

	if not self._dummyMaintenanceMaps then return false end
	local myUID = getSafeUid()
	if myUID ~= uid and not _G.AI_PLAY_GAME_MODE then return end

	local function checkMaintenanceResult( data )
		for _ , v in ipairs( data ) do
			if type(v) == "string" then
				if moduleKey == v then return true end
			end
		end
		return false
	end

	if self._dummyMaintenanceMaps[maintenanceName] then
		return true, checkMaintenanceResult( self._dummyMaintenanceMaps[maintenanceName] )
	end

	return false, false
end

function MaintenanceManager:clearMaintenanceDummyResult()
	self._dummyMaintenanceMaps = nil
end

function MaintenanceManager:loadMaintenanceDummyResult( dummyMaintenanceMode )
	if type( dummyMaintenanceMode ) ~= "table" then return end
	self._dummyMaintenanceMaps = dummyMaintenanceMode
end

function MaintenanceManager:loadMaintenanceDummyResultFromTestInfo( testInfo )
	pcall(function()
		if not testInfo then return end
		testInfo = tostring(testInfo)
		local pars = string.split( testInfo , ";" )
		for k,v in ipairs(pars) do
			local arr = string.split( v , "~" )
			if arr[1] == "dummyMaintenanceMode" then
				if arr[2] then self:loadMaintenanceDummyResult(table.deserialize(arr[2])) end
			elseif EnvUtil:isDevelopMode() and arr[1] == "location" then
				-- testInfo = "location~{\"province\":\"北京\",\"city\":\"北京\",\"country\":\"中国\"}"
				_G.amfBean("LocationService"):setIPLocationData(table.deserialize(arr[2]))
			end
		end
	end)
end

-- 注意，分组开关uid为0或12345时，结果永远返回false
function MaintenanceManager:isEnabledInGroup( maintenanceName , moduleKey , uid )

	local _debug = false
	-- if maintenanceName == "ubfuuu2025_app_V8" then
	-- 	_debug = true
	-- end

	-- if _debug then printx(1, "MaintenanceManager:isEnabledInGroup   +++++++++++++ " , maintenanceName,moduleKey,uid) end

	if _G.REPLAY_STAGE then 
		-- printx(1, "MaintenanceManager:isEnabledInGroup   return 000 "  )
		return end
	-- if _G.editorMode then return end

	if uid == nil then
		uid = getSafeUid()
	end

	local dummyResultEnable, dummyResult = self:getMaintenanceDummyResult(maintenanceName , moduleKey , uid)
	if dummyResultEnable then 
		if _debug then printx(1, "MaintenanceManager:isEnabledInGroup   return 111 dummyResult:" , dummyResult ) end
		return dummyResult , nil , -1 
	end

	if maintenanceName then

		local cacheKey = tostring(maintenanceName) .. "_" .. tostring(moduleKey) .. "_" .. tostring(uid)
		if self.resultCache[cacheKey] then
			
			-- if _debug then printx(1, "MaintenanceManager:isEnabledInGroup   return 222  cacheKey:" , cacheKey,  tts(self.resultCache[cacheKey]) ) end

			return self.resultCache[cacheKey].result, nil, self.resultCache[cacheKey].src
		end

		local maintenanceFeature = self:getMaintenanceByKey( maintenanceName )

		if maintenanceFeature then

			local _levelGroupExpkey = nil

			if not maintenanceFeature.review and maintenanceFeature:isInFilterlist() then
				if maintenanceFeature.filterlistMode == MaintenanceFilterListType.kWhite then
					-- DiffAdjustQAToolManager:print( 1 , "MaintenanceManager:isEnabledInGroup 111" , maintenanceName , "true" )
					self.resultCache[cacheKey] = { result = true, src = 1 , maintenanceName = maintenanceName }
					-- if _debug then printx(1, "MaintenanceManager:isEnabledInGroup   return 333  cacheKey:" , cacheKey,  tts(self.resultCache[cacheKey]) ) end
					return self.resultCache[cacheKey].result, nil, self.resultCache[cacheKey].src
				elseif maintenanceFeature.filterlistMode == MaintenanceFilterListType.kBlack then
					-- DiffAdjustQAToolManager:print( 1 , "MaintenanceManager:isEnabledInGroup 222" , maintenanceName , "false" )
					self.resultCache[cacheKey] = { result = false, src = 2 , maintenanceName = maintenanceName }
					-- if _debug then printx(1, "MaintenanceManager:isEnabledInGroup   return 444  cacheKey:" , cacheKey,  tts(self.resultCache[cacheKey]) ) end
					return self.resultCache[cacheKey].result, nil, self.resultCache[cacheKey].src
				end
			end

			-- local result = checkModuleEnable( maintenanceFeature )

			local childIndex , algorithmId, onlyOneGroupLeft = self:getChildIndexAndalgorithmId( maintenanceFeature , uid )

			if childIndex then
				local child = maintenanceFeature.groupChild[childIndex]
				if child then
					if not onlyOneGroupLeft and maintenanceFeature.originDataType and maintenanceFeature.enable then
						local dcCacheKey = tostring(maintenanceFeature.id) .. "_"  .. tostring(uid)
						if not self.dcCache[dcCacheKey] then
							self.dcCache[dcCacheKey] = true
							local env_name = maintenanceFeature.originDataType and self.configAppName[maintenanceFeature.originDataType] or _G.amfBean("AccountManager"):getAppName()
							self:_dc_shiyan_exp_trigger(maintenanceFeature,childIndex,env_name)
						end
					end

					local moduleKeyArr = string.split( moduleKey , ",")

					local _totalResult = true

					for _idx ,  _mkey in ipairs(moduleKeyArr) do

						local _result = false

						if _levelGroupExpkey then

							if string.sub( _mkey , 1 , 1 ) == "G" then
								local _idstr =  string.sub( _mkey , 2 , -1 )
								local _idnum =  tonumber(_idstr)
								if tostring(_idnum) == _idstr then
									--G后面真的是数字

									_result = self:isEnabledInGroup( _levelGroupExpkey , _mkey , tostring(uid))

									if not _result then
										_totalResult = false
										break
									end
								end
							end
						end

						for k2,v2 in ipairs( child.modules ) do

							if v2 == _mkey then
								_result = maintenanceFeature.enable
								break
							end
						end

						if not _result then
							_totalResult = false
							break
						end

					end

					self.resultCache[cacheKey] = { result = _totalResult, src = 3 , maintenanceName = maintenanceName}

					-- if _debug then printx(1, "MaintenanceManager:isEnabledInGroup   return 555  cacheKey:" , cacheKey,  tts(self.resultCache[cacheKey]) ) end

					return self.resultCache[cacheKey].result, algorithmId, self.resultCache[cacheKey].src
				end
			end

			-- DiffAdjustQAToolManager:print( 1 , "MaintenanceManager:isEnabledInGroup 333" , maintenanceName , result )
			self.resultCache[cacheKey] = { result = false, src = 4 , maintenanceName = maintenanceName }

			-- if _debug then printx(1, "MaintenanceManager:isEnabledInGroup   return 666  cacheKey:" , cacheKey,  tts(self.resultCache[cacheKey]) ) end

			return self.resultCache[cacheKey].result, nil, self.resultCache[cacheKey].src
		else
			--RemoteDebug:uploadLog( "MaintenanceManager:isEnabledInGroup  maintenanceName " .. tostring(maintenanceName) .. "  has not exist !!" )
			-- DiffAdjustQAToolManager:print( 1 , "MaintenanceManager:isEnabledInGroup 444" , maintenanceName , "false" )
			self.resultCache[cacheKey] = { result = false, src = 5 , maintenanceName = maintenanceName }

			-- if _debug then printx(1, "MaintenanceManager:isEnabledInGroup   return 777  cacheKey:" , cacheKey,  tts(self.resultCache[cacheKey]) ) end

			return self.resultCache[cacheKey].result, nil, self.resultCache[cacheKey].src
		end
	else
		-- 为了保证正交，不再支持这种方法，以前使用此特性的老开关已经迁移
		-- for k,v in pairs(self.data) do
		-- 	local r = checkModuleEnable( v )
		-- 	if r then return true end
		-- end
	end

	return false, nil, 6
end

--- 先判断是否有开关，无开关或者关闭了 返回defaultEnable，在判断组
---@param maintenanceName string
---@param defaultEnable boolean
---@param moduleKey string
---@param uid string|nil 可选
function MaintenanceManager:isEnabledAndInGroup(maintenanceName, defaultEnable, moduleKey, uid)
	local maintenanceFeature = self:getMaintenanceByKey(maintenanceName)
	if not maintenanceFeature or not maintenanceFeature.enable then return defaultEnable end
	return self:isEnabledInGroup(maintenanceName, moduleKey, uid)
end

function MaintenanceManager:_dc_shiyan_exp_trigger(maintenanceFeature,childIndex,env_name)
	if "maintenance" ~= maintenanceFeature.originDataType then
		local dcData = {
			category = 'shiyan_exp_trigger',
			sub_category = maintenanceFeature.originDataType,
			exp_id = maintenanceFeature.id,
			exp_group = childIndex,
			xml_version = maintenanceFeature.metaVersion,
			env_name = env_name,
		}
		DcUtil:UserTrack(dcData)
		return
	end
	local data = {maintenanceFeature,childIndex,env_name}
    self._dcCache = self._dcCache or {}
    table.insert(self._dcCache,data)
    if self._dcTrigger then
        cancelTimeOut(self._dcTrigger)
    end
    local function doDC()
        local list = self._dcCache
        self._dcCache = nil
		if not list or #list<=0 then return end

		local result = {}
		for k, v in ipairs(list) do
			local maintenanceFeature,childIndex,env_name = unpack(v)
			table.insert(result,{
				exp_id = maintenanceFeature.id,
				xml_version = maintenanceFeature.metaVersion,
				exp_group = childIndex,
				env_name = env_name,
			})
		end

		-- print(#list,ttsd(result))

		local dcData = {
			category = 'shiyan_exp_trigger',
			sub_category = maintenanceFeature.originDataType,
			switch_info = mime.b64(table.serialize(result))
		}
		DcUtil:UserTrack(dcData)
    end
	if _G.mainSceneInitialized then
		self._dcTrigger = setTimeOut(doDC,5)
	end
end

function MaintenanceManager:getGroupChildRangeMap( maintenanceName )

	if not maintenanceName then return nil end

	if not self.groupChildRangeMap then
		self.groupChildRangeMap = {}
	end

	if self.groupChildRangeMap[maintenanceName] then
		return self.groupChildRangeMap[maintenanceName]
	end

	local feature = self:getMaintenanceByKey( maintenanceName )
	local rangeMap = nil

	if feature and feature.modeValue then

		rangeMap = {}

		local totalWeigh = feature.totalGroupWeigh
		local blockNum = 10000

		if feature.modeValue == MaintenanceModeType.kGroup and feature.groupTail and type(feature.groupTail) == "number" then
			blockNum = math.pow(10, feature.groupTail)
		end
		-- printx( 1 , "----------------------------~~~~!!!!!!")
		for k1,v1 in ipairs(feature.groupChild) do

			local currWeighValue = tonumber(   ( (v1.weighT - v1.weigh) / totalWeigh * blockNum )   )
			local nextWeighValue = tonumber(   ( v1.weighT / totalWeigh * blockNum ) - 1  )

			-- printx( 1 , "currWeighValue =" , currWeighValue , "nextWeighValue" , nextWeighValue )

			local moduleStr = ""

			for k2,v2 in ipairs( v1.modules ) do
				moduleStr = moduleStr .. tostring(v2) .. " "
			end

			if nextWeighValue < currWeighValue then
				rangeMap[k1] = { startId = -1 , endId = -1 , modules = v1.modules , str = moduleStr , algorithmId = v1.algorithmId }
			elseif currWeighValue < 0 then
				if nextWeighValue < 0 then
					rangeMap[k1] = { startId = -1 , endId = -1 , modules = v1.modules , str = moduleStr , algorithmId = v1.algorithmId }
				else
					rangeMap[k1] = { startId = 0 , endId = math.floor(nextWeighValue) , modules = v1.modules , str = moduleStr , algorithmId = v1.algorithmId }
				end
			elseif currWeighValue >= (blockNum - 1) then
				rangeMap[k1] = { startId = -1 , endId = -1 , modules = v1.modules , str = moduleStr , algorithmId = v1.algorithmId }
			else
				rangeMap[k1] = { startId = math.floor(currWeighValue) , endId = math.floor(nextWeighValue) , modules = v1.modules , str = moduleStr , algorithmId = v1.algorithmId }
			end

			if rangeMap[k1].startId >= 0 and rangeMap[k1].endId >=0 then
				rangeMap[k1].weighLength = rangeMap[k1].endId - rangeMap[k1].startId + 1
			else
				rangeMap[k1].weighLength = 0
			end
		end

	end
	self.groupChildRangeMap[maintenanceName] = rangeMap

	return rangeMap
end



function MaintenanceManager:printGroupRange( maintenanceName )
	local feature = self:getMaintenanceByKey( maintenanceName )
	local rangeMap = self:getGroupChildRangeMap( maintenanceName )

	if rangeMap then
		printx( -6 , "  maintenanceName = " , maintenanceName)
		if feature.modeValue == MaintenanceModeType.kGroup then
			printx( -6 , "  按uid尾号后" .. tostring(feature.groupTail) .. "位分组")
		elseif feature.modeValue == MaintenanceModeType.kOrthogonalGroup or feature.modeValue == MaintenanceModeType.kOrthogonalGroupV2 then
			printx( -6 , "  按MD5后" .. tostring(feature.groupTail) .. "位分组")
		end

		for k3,v3 in ipairs( rangeMap ) do
			printx( -6 , "  group" .. tostring(k3) .. "   " ..  tostring(v3.startId) .. " ~ " .. tostring(v3.endId) .. "  weighLength: " .. tostring(v3.weighLength) .. "    modules: " .. v3.str )
		end
	end

	return rangeMap
end

function MaintenanceManager:getValue(key)
	local maintenance = self:getMaintenanceByKey(key)
	if maintenance then
		return maintenance.value
	else
		return nil
	end
end

-- since version 1.30, value = [0, 10000]
function MaintenanceManager:isAvailbleForUid(key, uid, threshold)
	local maintenance = self:getMaintenanceByKey(key)
	if maintenance and maintenance.enable then -- 开关已打开
		local uidEndWith = nil
		if maintenance.value ~= nil then
			uidEndWith = tonumber(maintenance.value)
		end

		if uidEndWith == nil then -- uid无限制
			return true
		else -- 在灰度范围内
			uid = tonumber(uid) or 0
			threshold = tonumber(threshold) or 100
			return (uid % threshold) < uidEndWith
		end
	end
	return false
end

function MaintenanceManager:getExtra(key)
	local maintenance = self:getMaintenanceByKey(key)
	if maintenance then
		return maintenance.extra
	else
		return nil
	end
end

function MaintenanceManager:getLevelRangesByExtra(key)

	local cacheKey = tostring("LevelRangesByExtra") .. "_" .. tostring(key)
	if self.resultCache[cacheKey] then
		return table.clone( self.resultCache[cacheKey] )
	end

	local extra = self:getExtra(key)

	local resultList = nil

	if extra then
		resultList = {}
		local ranges = string.split(extra, ",")
		local values = nil
		local startLevel, endLevel = 0, 0
		for i, range in ipairs(ranges) do
			values = string.split(range, "-")
			if #values == 1 then
				startLevel = tonumber(values[1]) or 0
				table.insert(resultList, {startLevel=startLevel, endLevel = startLevel})
			elseif #values == 2 then
				startLevel = tonumber(values[1]) or 0
				endLevel = tonumber(values[2]) or 0
				if startLevel > endLevel then startLevel, endLevel = endLevel, startLevel end
				table.insert(resultList, {startLevel=startLevel, endLevel = endLevel})
			end
		end
	end

	self.resultCache[cacheKey] = resultList
	return resultList
end

function MaintenanceManager:isNoMaintenanceBeforeRelease()
    local bundleVersion = _G.fullBundleVersion or majorBundleVersion
    local mVer = CCUserDefault:sharedUserDefault():getStringForKey("maintenance_game_ver")
    -- 已经拉取到本版本的maintenance配置，那么不是提审模式
    if mVer == bundleVersion then
        return false
    else
        local publishDate = os.time2({year = 2021, month = 02, day = 01, hour = 10})
        if StartupConfig.getInstance().getStringForKey then
            local dateStr = StartupConfig.getInstance():getStringForKey("PublishDate", "")
            local dateArr = string.split(dateStr, "-")
            if dateArr and #dateArr >= 3 then
                publishDate = os.time2({year = tonumber(dateArr[1]), month = tonumber(dateArr[2]), day = tonumber(dateArr[3]), hour = 10})
            end
        end
        if (os.time() < publishDate) then
            -- 没拉取到maintenance，发版前记为提审模式
            return true
        end
    end
    return false
end

function MaintenanceManager:isMiniGameInReview()
	if EnvUtil:isDYMiniGame() then
		return MaintenanceManager:getInstance():isEnabled("DYMiniGameInReview", false)
	end

	if EnvUtil:isALIPAYMiniGame() then
		return MaintenanceManager:getInstance():isEnabled("AlipayMiniGameInReview", false)
	end

	if EnvUtil:isUnionMiniGame() then
		return MaintenanceManager:getInstance():isEnabled("UnionMiniGameInReview", false)
	end

	if EnvUtil:isKuaiShouMiniGame() then
		return MaintenanceManager:getInstance():isEnabled("KuaiShouMiniGameInReview", false)
	end

	if EnvUtil:isJdMiniGame() then
		return MaintenanceManager:getInstance():isEnabled("JdMiniGameInReview", false)
	end
	return MaintenanceManager:getInstance():isEnabled("MiniGameInReview", false)
end

function MaintenanceManager:isInReview(includeMini)
	if EnvUtil:isAndroid() then
		local platformFlag = PlatformConfig:isPlatform(PlatformNameEnum.kHuaWei) or PlatformConfig:isPlatform(PlatformNameEnum.kHonor)
		local isCdnVersion = platformFlag and  require("amf.middleware.multiplatform.system.android.PackageUtil").isCDNOnly()
        if isCdnVersion then
            -- cdn
            return false
        end
        if MaintenanceManager:getInstance():isEnabled("AndroidInReview", false) then
			return true
		else
            if table.includes({"huawei","oppo","bbk","honor","mi"}, _G._PLATFORM_NAME) then
                return MaintenanceManager:isNoMaintenanceBeforeRelease()
            end
            return false
        end
	elseif EnvUtil:isIOS() then
        if MaintenanceManager:getInstance():isEnabled("reviewVersion", false) then
			return true
		else
			return MaintenanceManager:isNoMaintenanceBeforeRelease()
		end
	elseif EnvUtil:isOhos() then
        if MaintenanceManager:getInstance():isEnabled("OhosInReview", false) then
            return true
        else
            return MaintenanceManager:isNoMaintenanceBeforeRelease()
        end
	elseif EnvUtil:isMiniGame() and includeMini then
		return self:isMiniGameInReview()
	end
	return false
end

-- notice: is't a static function, no 'self' in it
function MaintenanceManager.isInCertainPlatformReview(pf)
	if not pf then return false end
	if not EnvUtil:isAndroidPlatform(pf) then return false end
	-- if pf == PlatformNameEnum.kBilibili then
	-- 	return not MaintenanceManager:getInstance():isEnabledInGroup( "bilibili_turn","ON" )
	-- end

	return false
end

function MaintenanceManager:getCurrentGroupData(maintenanceName,checkTime)
	local maintenanceFeature = self:getMaintenanceByKey(maintenanceName)
	if not maintenanceFeature then
		-- 无开关
		if log then log("getCurrentGroupName r NO DATA",maintenanceName) end
		return
	end
	if not maintenanceFeature.enable then
		-- 已关闭
		if log then log("getCurrentGroupName r not enable",maintenanceName) end
		return
	end
	-- 过期判断。注意大部分业务场景中，时间判断可能需要实时检测，不能使用一直缓存的结果
	if checkTime then
		local bInOpenTime = self:isEnabledConsiderBeginAndEndDate(maintenanceName, false)
		if not bInOpenTime then
			-- 已过期
			if log then log("getCurrentGroupName r not inOpenTime",maintenanceName,self:isEnabled(maintenanceName, false),maintenanceFeature.beginDate,maintenanceFeature.endDate) end
			return
		end
	end
	local dummyData = self._dummyMaintenanceMaps and self._dummyMaintenanceMaps[maintenanceName]
	if dummyData then
		-- 测试数据
		for _ , key in ipairs( dummyData ) do
			if type(key) == "string" then
				return key
			end
		end
		-- 测试数据 未命中
		if log then log("getCurrentGroupName r not in dummyData",maintenanceName,ttsd(dummyData)) end
		return
	end
    local uid = getSafeUid()
	local childIndex , algorithmId, onlyOneGroupLeft = self:getChildIndexAndalgorithmId( maintenanceFeature , uid )
	if not childIndex then
		-- 分组未命中
		if log then log("getCurrentGroupName r NO childIndex",maintenanceName,ttsd(maintenanceFeature)) end
		return
	end
	local groupData = maintenanceFeature.groupChild[childIndex]
	if not groupData then
		if log then log("getCurrentGroupName r NO groupData",maintenanceName,childIndex) end
		return
	end
	if log then log("getCurrentGroupName result",maintenanceName,childIndex,ttsd(groupData)) end
	return groupData
end

-- 关卡外关闭按钮测试新ui分组
function MaintenanceManager:isCloseBtnTestNewUI()
	return true
end
