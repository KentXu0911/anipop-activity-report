local Meta = {}
Meta.collectItemId = 57260
Meta.score20BuffId = 57262
Meta.score50BuffId = 57263
Meta.doubleBuffId = 57261
local GEM_SPRITE_PREFIX = "GemMining_Activity/GemSprites/"

local function createTapList(width, height)
    local result = {}
    for row = 0, height - 1 do
        for column = 0, width - 1 do
            result[#result + 1] = {
                row = row,
                column = column,
            }
        end
    end
    return result
end

local function createGemConfig(id, width, height)
    local typeName = tostring(id)
    return {
        id = id,
        frameName = GEM_SPRITE_PREFIX .. "gem/" .. typeName,
        boardName = GEM_SPRITE_PREFIX .. "bg/" .. typeName,
        packSize = {
            width = width,
            height = height,
        },
        tapListBase = createTapList(width, height),
    }
end

Meta.gemeConfig = {
    createGemConfig(1, 1, 1),
    createGemConfig(2, 1, 2),
    createGemConfig(3, 2, 1),
    createGemConfig(4, 1, 3),
    createGemConfig(5, 3, 1),
    createGemConfig(6, 2, 2),
    createGemConfig(7, 3, 2),
    createGemConfig(8, 3, 3),
    createGemConfig(9, 4, 4),
    createGemConfig(10, 4, 3),
    createGemConfig(11, 3, 4),
    createGemConfig(12, 4, 1),
    createGemConfig(13, 1, 4),
    createGemConfig(14, 3, 2),
    createGemConfig(15, 2, 3),
    createGemConfig(16, 4, 1),
}

local gemConfigById = {}
for _, config in ipairs(Meta.gemeConfig) do
    gemConfigById[config.id] = config
end

function Meta:getGemConfig(id)
    return gemConfigById[tonumber(id)]
end
return Meta
