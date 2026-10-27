local Model = class("ActivityCenterModel", AMFDataRef)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "activity_center_data",
    }):as("db")
end

function Model:__declare()
    self.visibleDatas = {} -- 存储可见的活动数据
    self._localCache = {}

    -- 资讯福利站 banner 已弹出记录表，key 由 ActivityCenterBannerModule 生成。
    self.ActivityCenterBannerShownMap = nil
end

function Model:getVisibleDatas()
    return self:getTempData("visibleDatas") or {}
end

function Model:getVisibleData(actId)
    local visibleDatas = self:getVisibleDatas()
    return visibleDatas[tostring(actId)]
end

function Model:setVisibleData(actId, data)
    local visibleDatas = self:getVisibleDatas()
    visibleDatas[tostring(actId)] = data
    self:setTempData("visibleDatas", visibleDatas)
end

function Model:cleanupInvalidData()
    local visibleDatas = self:getVisibleDatas()
    local validDatas = {}
    local hasChanges = false

    for id, data in pairs(visibleDatas) do
        if data and data:isSupport() then
            validDatas[id] = data
        else
            hasChanges = true
        end
    end

    if hasChanges then
        self:setTempData("visibleDatas", validDatas)
    end

    return hasChanges
end

-- =================== 本地标志存储工具 ===================
function Model:setLocalCache(key, value)
    self:setValue("_localCache." .. key, value)
end

function Model:getLocalCache(key)
    return self:getValue("_localCache." .. key)
end

return Model
