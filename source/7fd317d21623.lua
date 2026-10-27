local Meta = {}

require "amf.middleware.data.userdata.servercache.config.GuideFlagConst"

-- 需求基础条件：活动时间、开放等级和一次性展示标记。
Meta.OPEN_LEVEL = 30
Meta.START_TIME = os.time({ year = 2026, month = 7, day = 13, hour = 10, min = 0, sec = 0 })
Meta.END_TIME = os.time({ year = 2026, month = 8, day = 8, hour = 23, min = 59, sec = 59 })
Meta.GUIDE_FLAG = GuideFlagConst.ELIMINATE_FESTIVAL_2026_COMIC
Meta.DEBUG_FORCE_STAGE2_POPUP = true

Meta.CLICK_LOCK_TIME = 2
Meta.PANEL_WIDTH = 720
Meta.PANEL_HEIGHT = 1280
Meta.DARK_OPACITY = 255

Meta.SPINE_PATH = "amf/activity/eliminatefestival2026comic/spine/comics_xiaochujie/comics_xiaochujie.skel"
Meta.SPINE_ANIM = "idle2"
Meta.SPINE_SCALE = 1

-- UI 导出只保留挂载节点，实际位置统一在这里配置，方便后续跟随美术调参。
Meta.SPINE_POS_X = 360
Meta.SPINE_POS_Y = 640
Meta.CONTINUE_POS_X = 360
Meta.CONTINUE_POS_Y = 50

return Meta
