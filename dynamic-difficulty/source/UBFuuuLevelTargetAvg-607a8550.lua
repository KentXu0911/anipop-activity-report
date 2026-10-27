local UBFuuuLevelTargetAvg = {}


function UBFuuuLevelTargetAvg:initByMetaConfig()

    if not self.dataMap then

        PerformanceMonitor:traceBegin("load config: ubfuuu_ds_avg_map_config")

        self.metaConfig = require "ubf.metaConfig.ubfuuu_ds_avg_map_config"

        PerformanceMonitor:traceEnd()

        self.dataMap = {}
        
        for k,v in ipairs(self.metaConfig) do
            if v.levelId then
                if not self.dataMap[v.levelId] then
                    self.dataMap[v.levelId] = {}
                end

                local levelData = self.dataMap[v.levelId]
                local _expgroup = (v.levelExp or "default") .. "_" .. (v.levelGroup or "default")
                if not levelData[_expgroup] then
                    levelData[_expgroup] = {}
                end

                local groupData = levelData[_expgroup]
                
                if v.avg then groupData.avg = tonumber(v.avg) end
                if v.avg_Top then groupData.avg_Top = tonumber(v.avg_Top) end
                if v.avg_1 then groupData.avg_1 = tonumber(v.avg_1) end
                if v.avg_Top_1 then groupData.avg_Top_1 = tonumber(v.avg_Top_1) end
                if v.avg_2 then groupData.avg_2 = tonumber(v.avg_2) end
                if v.avg_Top_2 then groupData.avg_Top_2 = tonumber(v.avg_Top_2) end

                if v.add3StepAvg then groupData.add3StepAvg = tonumber(v.add3StepAvg) end
                
            end
        end
    end
    
end

function UBFuuuLevelTargetAvg:getTargetDiffAvg(levelId, levelScene)
    if not UBFLevelSceneFunc:isMainLevel(levelScene) then return end

    if self.dataMap and self.dataMap[levelId] then

        -- local levelGroup = UBFPlaySwitch:getLevelGroup(levelId)
        -- local ret, meetGroup, uuid = UBFLevelConfigManager:traversalDefault(levelGroup, levelId, function(group)
            
        --     local _arr = string.split(group, ":")
        --     local levelGroupKey = string.format("%s_%s", _arr[1], _arr[2] or "default")
        --     return self.dataMap[levelId][levelGroupKey]

        -- end )

        local levelKeyData = UBFLevelIdUtil:createLevelKeyDataWithAutoLevelGroup(levelId, levelScene)
        local ret, meetGroup, uuid = levelKeyData:fallback(function(group, levelId, levelScene)
            local _arr = string.split(group, ":")
            local levelGroupKey = string.format("%s_%s", _arr[1], _arr[2] or "default")
            return self.dataMap[levelId][levelGroupKey]
        end)
        
        return ret
    end
    return nil
end

return UBFuuuLevelTargetAvg