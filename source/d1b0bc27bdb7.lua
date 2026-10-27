local BaseIcon = require "amf.feature.mainscene.module.icon.view.BaseIcon"

local ShopRewardIcon = class("ShopRewardIcon", BaseIcon)
local Res = require "amf.feature.localactivity.shopreward.const.Res"
function ShopRewardIcon:create(module)
    local icon = ShopRewardIcon.new()
    icon:init(module)
    return icon
end

function ShopRewardIcon:init(module)
    self.module = module
    BaseIcon.init(self, IconKey.kShopReward)
    self:setPayMode()
end

function ShopRewardIcon:buildIcon()
    local layer = Layer:create()
    layer:setContentSize(CCSizeMake(112, 112))
    local iconSpine = UICreateUtil:createSpine(Res.Spine.ICON)
    iconSpine:playLoop("idle")
    LayoutUtil:centerAdd(layer, iconSpine)
    return layer
end

function ShopRewardIcon:onTouch()
    BaseIcon.onTouch(self)
    if self.module and self.module.onIconTapped then
        self.module:onIconTapped(function()
            if self.module and self.module.removeIcon then
                self.module:removeIcon()
            end
        end)
    end
end

function ShopRewardIcon:handleTouchEventBefore()
    self:cancelNewActState()
end

function ShopRewardIcon:cancelNewActState()
    if not self:isNewAct() then return end

    self:stopHasNewFlagAni()
    if self.module and self.module.consumeIconNewAct then
        self.module:consumeIconNewAct()
    end
end

function ShopRewardIcon:hasHint()
    if not self.module or not self.module.shouldShowIconHint then return false end
    return self.module:shouldShowIconHint()
end

return ShopRewardIcon
