local RecallHandler = class2("RecallHandler")

function RecallHandler:create(autoPopupMgr)
    local handler = RecallHandler.new()
    handler:init(autoPopupMgr)
    return handler
end

function RecallHandler:init(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
    AutoPopEventCenter:register(AutoPopEvent.RECALL, self.onHandlePopup, self)
end

function RecallHandler:onHandlePopup(event)
    local data = event:getData()
    local popupCheckPoint = data.popupCheckPoint
    local params = data.params

    lua_switch(popupCheckPoint) {
        [PopupCheckPoint.RECALL_2025_STAGE2] = function() self:handleReflow2025(params) end,
        default = function()
            assert(false, "RecallHandler invalid popupCheckPoint : " .. tostring(popupCheckPoint))
        end
    }
end

function RecallHandler:handleReflow2025(params)
    if _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then
       return
    end
    
    local Manager = _G.amfBean("Recall2025Manager")
    
    if not Manager or not Manager:checkInRecallState() then
        return
    end
    
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.RECALL_2025_STAGE2)
    end

    local function checkFunc()
        if not Manager or not Manager:checkCanGetRightsToday() then
            return
        end
        return true
    end

    local function openFunc()
        Manager:tryOpenMainPanel(false, onHandleOver, {
            stage = AutoPopupConst.PopStage.STAGE_TWO,
            canEnter = params and params.canEnter,
        })
    end
    
    local function creator()
        if checkFunc() then
            safeRunCall(openFunc)
        else
            setTimeOut(function()
                if checkFunc() then
                    safeRunCall(openFunc)
                else
                    safeRunCall(onHandleOver)
                end            
            end, 1)
        end
    end
    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.RECALL_2025_STAGE2, creator)
end

return RecallHandler
