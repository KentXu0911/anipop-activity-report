local Const = {}

Const.METHOD = "cloud_music_task"       -- URL 中的业务方法名
Const.REPORT_TYPE_LOGIN = 1              -- 登录事件
Const.REPORT_TYPE_ONLINE = 2             -- 在线时长事件
Const.ONLINE_SECONDS = 10                -- 达到该时长后上报在线事件

return Const
