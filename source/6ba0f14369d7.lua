local PetDecoPropConfig = {}

PetDecoPropConfig.atlas = "amf/activity/pet/texture/LinkageDeco.plist"
PetDecoPropConfig.frame = {
    [53736] = "LinkageDeco/53736.png",
    [53742] = "LinkageDeco/53742.png",
}

function PetDecoPropConfig.enumerateValid()
    local result = {}
    for itemId, iconKey in pairs(PetDecoPropConfig.frame) do
        if type(itemId) == "number" and itemId > 0 and type(iconKey) == "string" and iconKey ~= "" then
            result[#result + 1] = {
                itemId = itemId,
                iconKey = iconKey,
                atlas = PetDecoPropConfig.atlas,
            }
        end
    end
    table.sort(result, function(a, b)
        return a.itemId < b.itemId
    end)
    return result
end

function PetDecoPropConfig.isValid(itemId)
    return PetDecoPropConfig.frame[tonumber(itemId)] ~= nil
end

function PetDecoPropConfig.getStaticIcon(itemId)
    local iconKey = PetDecoPropConfig.frame[tonumber(itemId)]
    if not iconKey then return nil end
    return {
        iconKey = iconKey,
        atlas = PetDecoPropConfig.atlas,
    }
end

return PetDecoPropConfig
