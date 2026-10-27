local UBFSLResumeStartProcess = class2("UBFSLResumeStartProcess", UBFProcessNode)

function UBFSLResumeStartProcess:doProcess()
    local runtime = self:get("runtime")
    local sectionData = runtime:getResumeData()
    local isDevSectionResume = sectionData and sectionData.devSectionResume == true

    -- 再次更新断面数据
    local sceneData = sectionData.section and sectionData.section.sceneData
    if sceneData then
        sceneData.resumeCount = (sceneData.resumeCount or 0) + 1
    end
	local levelInfo = sectionData.levelInfo
	if levelInfo then 
        levelInfo.resumeCount = (levelInfo.resumeCount or 0) + 1
	end
    if not isDevSectionResume then
        UBFSectionResumeHelper:syncClientSection(sectionData)
    end

	-- 根据replay重置mod素材
	local modMgr = runtime:getModMgr()
	if modMgr:resumeGamePlayModList(levelInfo.modList) == false then
		return self:abort()
	end

	-- 开始恢复
    self:dispatchModEvent(UBFGameModEventEnum.START_RESUME)

    local sceneData = sectionData.sceneData or {}
	local playId = runtime:getPlayId()
	local levelType = runtime:getLevelType()
	local levelScene = runtime:getLevelScene()

    local dcRequest = {
		actType = AcType.kExpire90Days,
		dcDatas = {
			category = "crash_resume",
		    sub_category = "crash_resume_end",
			meta_level_id = runtime:getLevelId(),
            t1 = 200,
            t2 = runtime:getLevelId(),
		    t3 = sectionData.currMoveCount or 0,
            t4 = runtime:getUid(), --UserManager:getInstance():getUID(),
            t5 = runtime:getUdid(), --MetaInfo:getInstance():getUdid() or "hasNoUdid",
            t6 = runtime:getUid(),
            t7 = runtime:getUdid(),
            t8 = HeMathUtils:md5(tostring(playId)),
            t9 = nil,
		},
	}

    if not isDevSectionResume then
        local dcMgr = runtime:getDCMgr()
        dcMgr:dispatch(dcRequest):send(dcRequest)
    end

    -- TODO @tao.chen 看看还要不要，app上面有处理
    --mod预加载资源
	-- local modMgr = runtime:getModMgr()
	-- local modlist = levelInfo and levelInfo.modList or {}
	-- for k, modData in pairs(modlist) do
	-- 	local modClazz = modMgr.modClazzMap[modData.sourceId]
	-- 	local prepare = modClazz and modClazz:createModResPrepare(runtime)
	-- 	if prepare then
	-- 		local sceneReource = runtime:getSceneResourceMgr()
	-- 		sceneReource:setModPrepare(modData.sourceId, prepare)
	-- 	end
	-- end
    
	-- DcUtil:crashResumeEnd( 
	-- 200 , 
	-- levelId ,
	-- curStep , 
	-- uid , 
	-- udid , 
	-- ubfResumeData:getUid() , 
	-- ubfResumeData:getUdid(), 
	-- md5str )

    -- send(AcType.kExpire90Days, {
	-- 	category = "crash_resume",
	-- 	sub_category = "crash_resume_end",
	-- 	meta_level_id = LevelMapNoCompatible.getInstance():getMetaLevelId(levelId),
	-- 	t1 = result,
	-- 	t2 = levelId,
	-- 	t3 = finSteps,
	-- 	t4 = selfUid,
	-- 	t5 = selfUdid,
	-- 	t6 = dataUid,
	-- 	t7 = dataUdid,
	-- 	t8 = md5,
	-- 	t9 = totalSteps,
	-- 	})

    self:success()
end

function UBFSLResumeStartProcess:doRevert()
end

return UBFSLResumeStartProcess
