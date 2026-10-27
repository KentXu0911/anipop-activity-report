local deferred = require "amf.script.sugar.deferred"
local MusicMasterConfig = require 'amf.feature.localactivity.musicmaster.config.MusicMasterConfig'

local PropRegister = {}

local bHadRegister = false
function PropRegister:register(mgr)

	if bHadRegister then return end
	bHadRegister = true

	local registerItemIds = { MusicMasterConfig.CollectId, MusicMasterConfig.TicketId }

    local count = table.count(registerItemIds)
    for i = 1, count, 1 do
        local itemId = registerItemIds[i]

        local propBuilder = AMFPropBuilder.create(itemId)
    	propBuilder:setCategory(AMFPropConst.Category.ACTIVITY)

        -- icon
        propBuilder:startComponent(AMFPropConst.ComponentId.ICON)
        :setCreator(function()
            if mgr then
                return mgr:commonCreateIconForPropRegister( itemId )
            else
            	return Sprite:createEmpty()
            end
        end)
        :endComponent()

        -- PropChangeLogic
        propBuilder:startComponent(AMFPropConst.ComponentId.PROPCHANGE_LOGIC)
        :setPropGainFunction(function(reward)
            -- 获得逻辑,加到自己manager
            if mgr then
                if reward.itemId == MusicMasterConfig.CollectId then
		            --收集物
		            mgr:getData():addCollectItem( reward.num )
	            end
            end

            return deferred.success()
        end)
        :setNeedUsePropHttp(false)
        :endComponent()

        propBuilder:buildAndRegister()
    end

end


return PropRegister