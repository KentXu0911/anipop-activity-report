local LocalPushUtil = {}

function LocalPushUtil:getUserUidLastNumber()
    --获取自己的尾号 后一个12345 是防止离线情况注册账号 uid为设备ID 无法转换数字的情况
	local uid = tonumber(_G.getSafeUid())
	local lastNumber = uid%100
	return lastNumber
end

local function formatStr(str, params)
    if not str then
        return nil
    end
	if params == nil then return str end
	local newStr = str
	--字符串 参数 替换
	for k, v in pairs(params) do
		local param1 = '{'..k..'}'
		local param2 = v
		newStr = string.gsub( newStr, param1, param2 )
	end

	return newStr
end

-- 修改文案规则
function LocalPushUtil:makeStructRandomMessage(structAddAlarm, metaCfg, data)
    -- 文本参数
    local params = data.params or {}
    params["0"] = formatNameForShow(_G.amfBean("ProfileManager"):getName(), 6)
    if data.title and data.message then
        structAddAlarm:setTitle(formatStr(data.title, params))
        structAddAlarm:setMessage(formatStr(data.message, params))
        return structAddAlarm
    end
    if structAddAlarm.labelType ~= 0 then
        local title = metaCfg["title"..structAddAlarm.labelType]
        local message = metaCfg["text"..structAddAlarm.labelType]
        -- TODO pic 貌似没有用
        -- local pic = metaCfg["pic"..structAddAlarm.labelType]
        structAddAlarm:setTitle(formatStr(data.title, params) or formatStr(title, params))
        structAddAlarm:setMessage(formatStr(data.message, params) or formatStr(message, params))
    else
        local selfUidLastNumber = self:getUserUidLastNumber()
        for i= 1, 4 do
			if not metaCfg['uidTail'..i] then
				break
			end

			local parts = string.split(metaCfg['uidTail'..i], '~')
			if #parts == 2 then
				--说明是区间段
				if selfUidLastNumber >= tonumber(parts[1]) and selfUidLastNumber <= tonumber(parts[2]) then
                    local title = metaCfg['title'..i]
                    local message = metaCfg['text'..i]
                    local pic = metaCfg['pic'..i]
                    structAddAlarm:setTitle(title)
                        :setTitle(formatStr(data.title, params) or formatStr(title, params))
                        :setMessage(formatStr(data.message, params) or formatStr(message, params))
                        -- :setPicId(pic)
                        :setLabelType(i)
					break
				end
			else
				--说明是单个尾号
				if selfUidLastNumber == tonumber(parts[1]) then
                    local title = metaCfg['title'..i]
                    local message = metaCfg['text'..i]
                    local pic = metaCfg['pic'..i]
					structAddAlarm:setTitle(title)
                        :setTitle(formatStr(data.title, params) or formatStr(title, params))
                        :setMessage(formatStr(data.message, params) or formatStr(message, params))
                        -- :setPicId(pic)
                        :setLabelType(i)
					break
				end
			end
		end
    end
    return structAddAlarm
end

-- 修改即时推送时间
function LocalPushUtil:makeStructChangePushTime(structAddAlarm, metaCfg)
    -- 不是即时推送不处理
    if metaCfg.groupId ~= LocalPushConst.AlarmType.NO_LIMIT then
        return structAddAlarm
    end
    -- 修改推送时间, 即时推送
    local dayStartTime = TimeKit:getDayStartTimeByTS(structAddAlarm.timeStamp)
    if structAddAlarm.timeStamp < dayStartTime + 7 * 3600 then
        structAddAlarm:setTimeStamp(dayStartTime + 7 * 3600) --7点前 改到7点推送
    elseif structAddAlarm.timeStamp > dayStartTime + 22 * 3600 then
        structAddAlarm:setTimeStamp(dayStartTime + 24*3600 + 7 * 3600) --如果22点后 次日7点推送
    end
    return structAddAlarm
end

-- 检查添加的闹钟是否已经过期
function LocalPushUtil:checkAddAlarmTimeValid(timeStamp)
    return timeStamp > os.time()
end

--根据天数 找出每天优先级最高的 如果当前时间距离推送时间不足1小时不推送
function LocalPushUtil:isNearOneHour( timeStamp )
    if timeStamp - os.time() >= 0 and timeStamp - os.time() <= 3600 then
        return true
    end
    return false
end


return LocalPushUtil