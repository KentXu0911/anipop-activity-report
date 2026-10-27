local Meta = require "amf.feature.localactivity.sprintrealprize2.config.SprintRealPrizeConst"

return AMFPropBuilder.create(Meta.REAL_PROP_ID)
    :setCategory(AMFPropConst.Category.ACTIVITY)
    :setMergable(false)

    -- icon
    :startComponent(AMFPropConst.ComponentId.ICON)
    :setCreator(function()
        local icon = UICreateUtil:createSpriteFile("activity/sprintrealprize2/res/materials/shiwu.png")
        local flag = Sprite:createWithSpriteFrameName("other/commonV2/other_Z_commonV2_Z_Label_grade4_v2")
        flag:setPositionXY(175, 90)
        icon:addChild(flag)
        return icon
    end)
    :endComponent()
    :buildAndRegister()