-- 计算关卡进度
LevelProgressLogic = {}
local LEVEL_GAP = 500
local GROUP_NAMES = {"mean","median"}

-- linspace 函数，用于生成等间隔的数值
local function linspace(start, stop, num)
    local t = {}
    if num <= 0 then
        return t
    end
    local step = (stop - start) / (num - 1)
    t[0] = 0
    t[1] = 0
    for i = 1, num - 1 do
        -- table.insert(t, start + i * step)
        t[i+1] = start + i * step
    end
    return t
end

-- 根据配置，输入收集物数量，计算权重，返回当前进度百分比
local function make_predict_v1(meta)
    -- print("make_predict meta:",tts(meta))
    local model, weights = meta.model, meta.weights
    if not meta.weights then
        return function() return end
    end
    if not meta._initV1 then
        meta._initV1 = true
        -- print("model",tts(model),"weights",tts(weights))
        local total_weight = 0
        for _, w in pairs(weights) do
            total_weight = total_weight + w
        end
        -- print("meta",table.serialize(meta))
        local maxStep = 0
        for k,v in pairs(model) do
            local keys = {}
            local map = {}
            for kk, vv in pairs(v) do
                map[tonumber(kk)] = vv
                table.insert(keys,tonumber(kk))
            end
            table.sort(keys)
            maxStep = math.max(maxStep,keys[#keys])
            map._keys = keys
            model[k] = map
        end
        meta.maxStep = maxStep
        meta.linspace = linspace(0, 1, meta.maxStep + 1)
    end
    -- 创建一个预测函数，基于给定的模型和权重。

    -- 获取模型的行数（假设所有列的长度相同）
    local index_normalized =  meta.linspace
    -- print('meta.maxStep',meta.maxStep,"index_normalized",tts(index_normalized))
    local scaler = meta['scaler'] or 1

    return function(x, step , static_step)
        -- 根据输入值和步长计算进度值。
        local progress = 0
        local tMap = {}
        for target_id, value in pairs(x) do
            -- 按照步数增加 target_value 值, step 是 [0, 1] 之间的值
            value = math.max(value + 1 + step / static_step, 0) * scaler
            -- print("value",value)

            -- 获取对应目标 ID 的列名
            local column_name = tostring(target_id)

            if not model[column_name] then
                error("Target ID " .. target_id .. " not in model")
            end

            -- 获取目标列的值
            local column_values = model[column_name]
            -- print("column_values",target_id,tts(column_values))
            local keys = column_values._keys
            -- print("keys",tts(keys))
            -- 找到给定值所在的区间，并计算归一化后的索引值
            for i = 1,  #keys-1 do
                if column_values[keys[i]] <= value and value <= column_values[keys[i + 1]] then
                    -- 线性插值计算归一化索引值
                    local t = (value - column_values[keys[i]]) / (column_values[keys[i + 1]] - column_values[keys[i]])
                    -- print("t",t,i,"keys?:",keys[i],keys[i+1],"in:",index_normalized[keys[i]],index_normalized[keys[i+1]])
                    local target_progress = index_normalized[keys[i]] + t * (index_normalized[keys[i+1]] - index_normalized[keys[i]])
                    progress = progress + target_progress * weights[column_name]
                    tMap[target_id] = "v:" .. value .. " in:(" .. column_values[keys[i]] .. "/" .. column_values[keys[i+1]] .. ") t:" .. target_progress .. " w:" .. weights[column_name] .. " p:" .. progress 
                    break
                end
            end
            -- 如果值超出范围，使用最近的端点
            -- print("value < column_values[1]",value , column_values[1],column_name,tts(column_values))
            if value < column_values[keys[1]] then
                progress = progress + index_normalized[1] * weights[column_name]
            elseif value > column_values[keys[#keys]] then
                progress = progress + index_normalized[#index_normalized] * weights[column_name]
            end
        end

        -- print("make_predict_v1 tMap",progress,tts(tMap))
        return progress
    end
end

--根据配置，输入收集物数量，返回每个收集物折算的步数
local function make_predict_v2(config,errorlog)
    local model = config['model']
    local level_id = config['level_id'] or 0
    local scaler = config['scaler'] or 1

    local function predict(x, current_step, static_step)
        if current_step > static_step then
            if errorlog then
                errorlog(string.format("Level %d Current step %d is greater than static step %d", level_id, current_step, static_step))
            end
            current_step = static_step
        end
        if current_step < 0 then
            if errorlog then
                errorlog(string.format("Level %d Current step %d is less than 0", level_id, current_step))
            end
            current_step = 0
        end
        if static_step < 0 then
            if errorlog then
                errorlog(string.format("Level %d Static step %d is less than 0", level_id, static_step))
            end
            static_step = math.min(current_step, 20)
        end
        if static_step == 0 then
            if errorlog then
                errorlog(string.format("Level %d Static step %d is 0 and cannot be used as divisor", level_id, static_step))
            end
            static_step = 20
        end
        if config['steps'] and config['steps'] ~= static_step then
            if errorlog then
                errorlog(string.format("Level %d Static step %d is not equal to config step %d", level_id, static_step, config['steps']))
            end
            static_step = config['steps']
        end

        local step_adjust = current_step / static_step
        local result = {}
        -- local tMap = {}

        for target_id, target_values in pairs(model) do
            local sorted_items = {}
            for k, v in pairs(target_values) do
                if tonumber(k) then
                table.insert(sorted_items, {tonumber(k), math.max(v, 0)})
                end
            end
            table.sort(sorted_items, function(a, b) return a[1] < b[1] end)

            local indices = {}
            local values = {}

            for _, item in ipairs(sorted_items) do
                table.insert(indices, item[1])
                table.insert(values, item[2])
            end

            -- 将 target value 已经达到最大值的情况, 直接返回最大值的索引
            -- print("x[tonumber(target_id)?",tts(x),target_id,scaler,tts(values))
            if (x[tonumber(target_id)] + 1) * scaler >= values[#values] then
                result[target_id] = indices[#indices]
            else

                if indices[1] ~= 0 then
                    table.insert(indices, 1, 0)
                    table.insert(values, 1, 0)
                end

                local value = math.max(x[tonumber(target_id)] + step_adjust, 0) * scaler

                for i = 1, #values - 1 do
                    if values[i] <= value and value <= values[i + 1] then
                        if values[i] == values[i + 1] then
                            result[target_id] = indices[i]
                            break
                        end
                        local t = (value - values[i]) / (values[i + 1] - values[i])
                        local target_progress = indices[i] + t * (indices[i + 1] - indices[i])
                        result[target_id] = target_progress
                        -- tMap[target_id] = "v:" .. value .. " in:(" .. values[i] .. "/" .. values[i+1] .. ") t:" .. target_progress 
                        break
                    end
                end

                if not result[target_id] then
                    if value < values[1] then
                        result[target_id] = indices[1]
                    elseif value > values[#values] then
                        result[target_id] = indices[#indices]
                    end
                end
            end
        end
        -- print("tMap",tts(tMap))

        return result
    end

    return predict
end


-- 返回num，当前进度百分比
function LevelProgressLogic:getProgressV1(levelId,curTargetMap,step,staticMove,meta)
    if not levelId and self._lastInfo then
        levelId = self._lastInfo.levelId
        curTargetMap = self._lastInfo.curTargetMap
        step = self._lastInfo.step
        staticMove = self._lastInfo.staticMove
        meta = self._lastInfo.meta
    end
    local fn = make_predict_v1(meta)
    local progress = fn(curTargetMap,step,staticMove)
    return progress
end

function LevelProgressLogic:getProgressByProgressData(levelId,progressData,step,staticMove,meta)
    local progress = {}
    local errLogs = {}
    local targetIds = {}
    local targetValues = {}
    local curTargetMap = {}

    if meta.autoData then
        for k,v in pairs( meta.progressData ) do
            if v.tv and v.tv > 0 then
                progress[tostring(v.id)] = step * v.cv / v.tv
            end
        end
    else
        -- do return 0 end
        -- local meta = self:getMetaData(levelId)
        -- if not meta then
        --     return
        -- end
    
        -- print("progressData",tts(progressData))
        
        
        for i, id in ipairs(meta.targets) do
            id = tonumber(id)
            for _ , vv in ipairs( progressData ) do
                if vv.id == id then
                    curTargetMap[id] = vv.cv
                end
            end
            table.insert(targetIds,id)
            table.insert(targetValues,curTargetMap[id] or 0)

            -- print("i-",i, id,curTargetMap[id],curTargetMap[1])

            if not curTargetMap[id] then
                local curIds = {}
                for _ , vv in pairs( progressData ) do
                    table.insert(curIds,vv.id)
                end
                curTargetMap[id] = 0
                local str = "progressPredict not find target id "..id .. " in "..table.serialize(curIds)
                print(str)
                -- he_log_error(curTargetMap[i],str)
            end
            -- print("i+",i, id,curTargetMap[id],curTargetMap[1])
        end
        -- print("curTargetMap",tts(curTargetMap),tts(meta.targets),step)
        local function errorLogHandler(msg)
            local fullMsg = msg .. ".level:"..levelId .. " step:"..step .. "/"..staticMove 
            table.insert(errLogs,fullMsg)
        end
        local fn = make_predict_v2(meta,errorLogHandler)
        -- local stepPercent = math.min(step/staticMove,1)
        progress = fn(curTargetMap,step,staticMove)
        -- print("getProgressByProgressData",progress,levelId)
    end
    
    local result = {}
    result.progress = progress
    result.errLogs = errLogs
    result.debugData = {targetIds = targetIds, targetValues = targetValues}
    self._lastInfo = {
        levelId = levelId,
        progressData = progressData,
        curTargetMap = curTargetMap,
        step = step,
        staticMove = staticMove,
        meta = meta
    }
    return result
end

function LevelProgressLogic:getPackPath(key)
    if _G.UBF_NO_REQUIRE_LUA_GAME_CORE then 
        local function read(path)
            return UBFLVResourceManager:loadJsonResource(path)
        end
        if not self._infoData then
            self._infoData = read("ubf/rust/level_pack/level_fuuu_info.json")
            local updateData = read("ubf/rust/level_pack/level_fuuu_info_update.json")
            for key, config in pairs(updateData) do self._infoData[key] = config end
        end
        local metaInfo = self._infoData[key]
        if not metaInfo then
            return nil
        end
        local path = string.format("ubf/fuuuChart/%s.fuuuV3Pack", metaInfo[1])
        return path
    end

    if not self._infoData then
        self._infoData = require("ubf.UBFPlay.logics.progress.offset.UBFuuuV3Info")
        local updateData = require("ubf.UBFPlay.logics.progress.offset.UBFuuuV3Info_update")
        for key, config in pairs(updateData) do self._infoData[key] = config end
    end
    local metaInfo = self._infoData[key]
    if not metaInfo then
        return nil
    end
    local path = string.format("ubf/fuuuChart/%s.fuuuV3Pack", metaInfo[1])
    return path
end

function LevelProgressLogic:getPackPathByLevelId(levelId, levelScene)
    local levelKeyData = UBFLevelIdUtil:createLevelKeyDataWithAutoLevelGroup(levelId, levelScene)
    local ret, meetGroup, uuid = levelKeyData:fallback()
    local rule = UBFLevelConfigManager:getLevelGroupRuleByGroupName(meetGroup, levelScene)
    local tag = rule and rule.fuuuGraphV3
    local key = string.format("%s,%s", uuid, tag)
    local result = LevelProgressLogic:getPackPath(key)
    -- UWarning("LevelProgressLogic:getPackPathByLevelId",result,levelId,levelGroup,uuid,meetGroup,tts(rule))
    return result
end

function LevelProgressLogic:_getMetaDataFromPackByKey(uuid,tag)
    self._metaMap = self._metaMap or {}
    local key = string.format("%s,%s", uuid, tag)
    -- print("LevelProgressLogic:getMetaDataFromPack",key,self._metaMap[key])
    if self._metaMap[key] then
        return self._metaMap[key]
    end
    local path = LevelProgressLogic:getPackPath(key)
    if not path then
        return nil
    end
    local metaInfo = self._infoData[key]
    local rawData = UBFLuaHelper:loadConfigFromLevelpack(path, metaInfo[2])
    local metaData = table.deserialize(rawData)
    self:_formatMetaData(metaData)
    self._metaMap[key] = metaData
    return metaData
end

function LevelProgressLogic:_getMetaInfoFromPackByKey(uuid,tag)
    local key = string.format("%s,%s", uuid, tag)
    if not self._infoData then self:getPackPath(key) end
    return self._infoData[key]
end

function LevelProgressLogic:ui_getMetaDataFromPackTest(levelId,levelExp,levelGroup, levelScene)
    levelGroup = levelGroup or  UBFPlaySwitch:getLevelGroup(levelId, levelScene)
    local levelKeyData = UBFLevelIdUtil:createLevelKeyData(levelId, levelScene, levelExp, levelGroup)
    local ret, meetGroup, uuid = levelKeyData:fallback()
    
    local rule = UBFLevelConfigManager:getLevelGroupRuleByGroupName(meetGroup, levelScene)
    local tag = rule and rule.fuuuGraphV3
    -- UWarning("LevelProgressLogic:ui_getMetaDataFromPackTest",levelId,levelExp,levelGroup,uuid,meetGroup,tts(rule))
    return LevelProgressLogic:_getMetaDataFromPackByKey(uuid,tag)
end

function LevelProgressLogic:getMetaDataFromPack(gEnv)
    local uuid,tag = gEnv.levelUUID,gEnv.fuuuGraphV3
    if _G.AutoPlayEnv and _G.AutoPlayEnv.mode == "AIAdjust" then
        tag = "fl3_weight"
    end
    return LevelProgressLogic:_getMetaDataFromPackByKey(uuid,tag)
end

-- local d = LevelProgressLogic:getMetaDataFromPack(501)
-- print("LevelProgressLogic:getMetaDataFromPack",d,type(d))
-- local d = LevelProgressLogic:getMetaDataFromPack(504)
-- print("LevelProgressLogic:getMetaDataFromPack",d,tts(table.keys(d)))

function LevelProgressLogic:getMetaData(groupIndex, gEnv, fuuuGraphCtx)
    if fuuuGraphCtx then
        if fuuuGraphCtx.autoData then
            return fuuuGraphCtx
        end
        local meta = fuuuGraphCtx.fuuuChartV3
        if meta then
            -- print("LevelProgressLogic:getMetaData found mock data:",tts(meta))
            self:_formatMetaData(meta)
            return meta
        end
    end
    local first = self:getMetaDataFromPack(gEnv)
    if first then
        return first
    end
end
function LevelProgressLogic:_formatMetaData(meta)
    if meta.targets then return end
    local targets = {}
    for k, v in pairs(meta.model) do
        table.insert(targets,k)
    end
    -- print("targets",tts(targets))
    meta.targets = targets
end
-- print(3499,LevelProgressLogic:getMetaData(3499,1))
-- print(6499,LevelProgressLogic:getMetaData(6499,1))
-- print(8925,LevelProgressLogic:getMetaData(8925,1))
-- print(8925,LevelProgressLogic:getMetaData(8925,2))
-- do return end

local targetCHName = {
    [101] = '嘟嘟河马',
    [102] = '爱豆蛙',
    [103] = '栗熊',
    [104] = '紫咪',
    [105] = '么么狐',
    [106] = '莱蒙鸡',
    [601] = '横线',
    [602] = '竖线',
    [603] = '魔力鸟',
    [701] = '直线与直线交换',
    [702] = '爆炸与直线交换',
    [703] = '魔力鸟与直线交换',
    [704] = '爆炸与爆炸交换',
    [705] = '魔力鸟与爆炸交换',
    [706] = '魔力鸟与魔力鸟交换',
    [200] = '雪块',
    [300] = '银币',
    [500] = '毒液',
    [800] = '蜗牛',
    [1100] = '灰毛球',
    [1200] = '棕毛球',
    [1600] = '精灵萌豆',
    [1500] = '气球',
    [400] = '黑毛球',
    [900] = '蜂蜜',
    [1000] = '流沙',
    [1400] = '魔法石',
    [1700] = '气鼓鱼',
    [1900] = '小木桩',
    [1800] = '小叶堆',
    [2000] = '星星瓶子',
    [2100] = '变色龙',
    [2200] = '吃豆人',
    [2300] = '幽灵',
    [2600] = '果酱',
    [2400] = '鱿鱼',
    [2500] = '夹心饼干的奶油',
    [2501] = '夹心饼干',
    [2700] = '陀螺',
    [2800] = '水滴，给水桶冲能用的',
    [2900] = '水桶',
    [3000] = '飞机',
    [3100] = '小鱼干',
    [3700] = '引水挖地目标',
    [3200] = '爆米花',
    [3300] = '扫地机器人',
    [3400] = '吃豆人联动的大幽灵',
    [3500] = '魔法雕像',
    [3600] = '蝴蝶',
    [4000] = '蝴蝶罩子',
    [3800] = '牛奶瓶',
    [3900] = '牛奶',
    [4100] = '鳐鱼',
    [4200] = '巧克力',
    [4300] = '雷云',
    [4400] = '草垛',
    [4500] = '棉花糖',
    [4600] = '魔术兔',
    [4700] = '雪糕盒子',
    [4800] = '雪糕',
    [4900] = '特效盒',
    [5000] = '八音盒',
    [5100] = '橱柜',
    [5200] = '太阳罐',
    [5300] = '冰封导弹',
    [5400] = '牢笼',
    [5500] = '百变牌',
    [5700] = '萝卜',
    [5800] = '花圃',
    [5900] = '爱情鸟',
    [6000] = '神灯',
    [6100] = '糖果罐',
    [6101] = '攻城小木桩',
    [6102] = '攻城蜜蜂',
    [6200] = '荧光花',
    [6300] = '糖果炮的小车',
    [6400] = '边缘魔法云',
    [6301] = '24消除节糖果小车',
    [1301] = '企鹅',
    [1302] = '海豹',
    [1303] = '熊',
    [1304] = '活动海洋生物 1 * 1',
    [1305] = '废弃',
    [1306] = '活动海洋生物 2 * 2',
    [1307] = '活动海洋生物 3 * 3',
    [1308] = '活动海洋生物 1 * 2',
    [1309] = '活动海洋生物 1 * 2',
    [1310] = '废弃',
    [1311] = '废弃',
    [1312] = '李白',
    [30000] = '测试（荷塘）',
    [30001] = '蝴蝶罐子',
    [30002] = '引水种花泥土',
    [30003] = '染色宝宝',
    [30004] = '冰',
    [30005] = '饼干盒',
    [30006] = '百变牌',
    [30007] = '花圃',
    [30008] = '草垛猪',
    [30009] = '蜂蜜',
    [30010] = '雪糕',
    [30011] = '雪糕盒子',
    [30012] = '小叶堆',
    [30014] = '爱情鸟',
    [30015] = '魔法雕像',
    [30016] = '棉花糖',
    [30017] = '小鱼干',
    [30018] = '汽水',
    [30019] = '冰封导弹',
    [30020] = '音乐盒/八音盒',
    [30021] = '配对钥匙',
    [30022] = '萝卜',
    [30023] = '海洋生物的上的冰',
    [30024] = '绵羊',
    [30025] = '蜗牛路径',
    [30026] = '雪的层数',
    [30027] = '特效盒层级',
    [30028] = '鱿鱼充能',
    [30029] = '星星瓶充能',
    [30030] = '阳光罐',
    [30031] = '魔法兔',
    [30032] = '魔法罐的水',
    [30033] = '闪电鸟',
    [30034] = '挖云',
    [30035] = '万生（荷花包）',
    [30036] = '雪怪',
    [30037] = '大眼仔',
    [30040] = '蜂蜜罐子',
    [30041] = '水晶球',
    [30042] = '水母宝宝',
    [30043] = '染色蛋（迷之蛋）',
    [30044] = '花藤',
    [30045] = '风洞开关',
    [30046] = '猫窝',
    [30047] = '鞭炮（樱桃炸弹）',
    [30048] = '蓄电器',
    [30049] = '小恐龙',
    [30050] = '松鼠',
    [30051] = '飞毯',
    [30052] = '鼹鼠（紫鼠）',
    [30053] = '小木桩',
    [30054] = '过滤器',
    [30055] = '布谷鸟',
    [30056] = '魔法石',
    [30057] = '萌豆',
    [30058] = '陀螺',
    [30059] = '蝴蝶',
    [30060] = '云/宝石云',
    [30061] = '沙子/流沙',
    [30062] = '牛仔裤',
    [30063] = '巧克力块',
    [30064] = '毒液',
    [30065] = '气鼓鱼',
    [30066] = '银币',
    [30067] = '鳐鱼',
    [30068] = '雷云',
    [30069] = '夹心饼干',
    [30070] = '牢笼',
    [30071] = '黑毛球',
    [30072] = '棕毛球',
    [30073] = '灰毛球',
    [30074] = '小幽灵',
    [30075] = '气球',
    [30076] = '飞机',
    [30077] = '吃豆人',
    [30078] = '扫地机器人',
    [30079] = '水桶',
    [30080] = '神灯',
    [30081] = '冰柱',
    [30082] = '礼盒',
    [30083] = '荷塘',
    [30084] = '汽水罐',
    [30085] = '攻城',
    [30086] = '糖果车',
    [30087] = '24消除节小车',
    [30088] = '边缘魔法云',
}

function LevelProgressLogic:getDebugTitle(titles,_predictInfo)
    
    for i, v in ipairs(_predictInfo.targetIds) do
        table.insert(titles,"t-" .. v .. tostring(targetCHName[v]))
    end
    return titles
end

function LevelProgressLogic:getTargetNameById(targetId)
    if targetCHName[tonumber(targetId)] then
        return tostring( targetCHName[tonumber(targetId)] )
    else
        return tostring( targetId )
    end
end


--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--


