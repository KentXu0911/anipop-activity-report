# 本地与远程通知审计

范围：全11,871 Lua检索TransactionEvent.LOCALPUSH，共18文件：15业务生产者、1登录清理、1调度、1测试；未将TimerUtil.addAlarm的游戏定时器当系统通知。系统通知规则表17行（同业务可分正式/领奖两条），包内notification_v2共72行：65 client、7 server，全部activate=true。不能推成全部有效/全部实际发送。

主要证据：
- `amf/middleware/notification/localpush/LocalPushManager.lua:17`：开关、鸿蒙禁用、事件注册。
- `amf/middleware/notification/localpush/LocalPushManager.lua:113`：只保留activate且pusher=client。
- `amf/middleware/notification/localpush/LocalPushManager.lua:233`：前台恢复并取消；243后台/退出注册。
- `amf/middleware/notification/localpush/LocalPushManager.lua:261`：受限型08:00/20:30，priority小优先，groupLimit，距现在≤3600秒不排。
- `amf/middleware/notification/localpush/LocalPushManager.lua:314`：时效型按日+groupKey/type去重，priority后time；豁免表为空。
- `amf/middleware/notification/localpush/util/LocalPushUtil.lua:84`：<07:00与>22:00改时，恰22不改。
- `amf/middleware/notification/localpush/system/android/LocalPush.lua:7`：pcall Android addLocalNotification2，静态调用不证明送达。
- `amf/middleware/notification/remotepush/PushProxy.lua:61`：SDK初始化；162 token发送。只证明接收通道，不证明服务端投放算法。

修正早期记录：幸运/开心快递scheduleDay2Push参数名loginTimeStamp，但调用者在后台事件执行TimeKit:timeInSec，正确为首次符合条件的后台排程时刻+23.5小时，不应写真实登录时刻+23.5小时。幸运快递需isEnabled且当天任务未完成（Manager:190），开心快递需核其对应后台分支。每日标记在调用排程前写入。

业务请求时间要和公共调度连接：妙音合合三个时间同日同组通常只剩一个；冲顶夺宝10/20点同组亦然。PromoteDaily提交type42的12:00/20:30，包内配置却是groupId2/groupLimit2，最终走08:00候选；过了/近一小时可能不排当天。不能把源业务请求时刻当最终通知时刻。

日签29把早于18点候选的hour/min改为18/0，但未重置秒；不要声称每次精确18:00:00。配置字段dailyLimit在已审Lua调度未消费；原生SDK内部实现未全部审计。

远端pusher=server的7行只是合同/文案，不提供远程营销算法。小游戏订阅消息独立，共同非小游戏SubMsgManager.isUIEnabled/isLocalEnabled均false，不能用小游戏代码推断AndroidApp通知行为。
