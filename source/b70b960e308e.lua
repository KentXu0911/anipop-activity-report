local deferred = require "amf.script.sugar.deferred"
local AddFiveStepConfig = require 'amf.feature.localactivity.addfivestepupgrade.config.AddFiveStepConfig'
local PropRegister = {}

function PropRegister:register()

    local itemId = AddFiveStepConfig.add150SoreBuffID
    AMFPropBuilder.create(itemId)
        :setCategory(AMFPropConst.Category.ACTIVITY)
        -- icon
        :startComponent(AMFPropConst.ComponentId.ICON)
        :setCreator(function()

            local item = Sprite:createWithSpriteFrameName("other/iconV2/ui_icon_star_02_v2")

            local scoreTitleLabel = TTFLabel:createAnimalYH( '分数', 18 )
            scoreTitleLabel:setTextColor(hex2ccc4('e6830cff'))
            scoreTitleLabel:setPositionXY(45,85)
            item:addChild(scoreTitleLabel)

            local scoreLabel = TTFLabel:createAnimalYH( 'x150%', 18 )
            scoreLabel:setAnchorPoint(ccp(0.5,0.5))
            scoreLabel:setPositionXY(63,54)
            scoreLabel:setTextColor(hex2ccc4('e6830cff'))
            scoreLabel:enableOutline(hex2ccc4('ffffffff'),2)
            item:addChild(scoreLabel)

            return item
        end)
        :endComponent()

        -- 无限道具
        :startComponent(AMFPropConst.ComponentId.INFINITE_PROPLOGIC)
        :endComponent()

        -- 分数加成
        :startComponent(AMFPropConst.ComponentId.SCOREBUFF)
        :setRate(1.5)
        :endComponent()

        :buildAndRegister()
end


return PropRegister