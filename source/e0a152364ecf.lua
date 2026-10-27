local baseConfig = require "ubf.UBFActivity.actFolder.PetitPet.PetDecoInLevelSkinConfig"

local parts = {}
for partName, partType in pairs(baseConfig.parts) do
    parts[partName] = partType
end
parts.wing = "4"

local decoMetas = {}
for itemId, meta in pairs(baseConfig.decoMetas) do
    decoMetas[itemId] = meta
end

local outsideLevelDecos = {
    itemMetas = {
        [53733] = { part = "2" },
        [53737] = { part = "4" },
    },
}
for itemId, meta in pairs(outsideLevelDecos.itemMetas) do
    decoMetas[itemId] = meta
end

local config = {
    parts = parts,
    decoMetas = decoMetas,
    outsideLevelDecos = outsideLevelDecos,
    defaultWearingDecos = {
        ["1"] = 53701,
        ["3"] = 53710,
        ["2"] = 53733,
    },
    emptyDecos = {
        [53733] = true,
    },
}

function config.getDecoMeta(itemId)
    itemId = tonumber(itemId) or itemId
    return config.decoMetas[itemId]
end

function config.isDecoSupported(itemId)
    return config.getDecoMeta(itemId) ~= nil
end

function config.isEmptyDeco(itemId)
    itemId = tonumber(itemId) or itemId
    return config.emptyDecos[itemId] == true
end

function config.getDefaultWearingDecos()
    local result = {}
    for partType, itemId in pairs(config.defaultWearingDecos) do
        result[partType] = itemId
    end
    return result
end

function config.resolveWearingDecos(wearingDecos)
    if type(wearingDecos) ~= "table" then
        return config.getDefaultWearingDecos(), true
    end

    for _, itemId in pairs(wearingDecos) do
        if itemId ~= nil and tonumber(itemId) ~= 0 and not config.isDecoSupported(itemId) then
            return config.getDefaultWearingDecos(), true
        end
    end

    local result = config.getDefaultWearingDecos()
    for partType, itemId in pairs(wearingDecos) do
        local meta = config.getDecoMeta(itemId)
        if meta then
            result[tostring(meta.part or partType)] = tonumber(itemId) or itemId
        end
    end
    return result, false
end

function config.resolveWearingDecosForLevel(wearingDecos)
    local result, didFallback = config.resolveWearingDecos(wearingDecos)
    for partType, itemId in pairs(result) do
        itemId = tonumber(itemId) or itemId
        if config.isEmptyDeco(itemId) or baseConfig.decoMetas[itemId] == nil then
            result[partType] = nil
        end
    end
    return result, didFallback
end

return config
