# 开心消消乐活动推送通用引擎：独立审计

范围：已解密 Lua 的通用活动、强弹、AI 和参与分层。以下为静态代码结论，不代表线上已启用、当前活动全集或实际送达。原 delivery-segments/findings.md 的主要链路与本次复核一致；本次明确初筛/场景复查/真正执行的差异。

## E01 活动开放与加载

reloadAll 最高关<20返回；iOS审核关闭此活动框架。正式远程配置按name、uid、bundleVersion请求；一般同次登录成功后缓存，不等于每次回前台重新下载活动名单。

来源：`analysis/native_decode/decoded/amf/middleware/activity/ActivityMgr.lua:73`；`analysis/native_decode/decoded/amf/middleware/activity/ActivityMgr.lua:25`；`analysis/native_decode/decoded/amf/middleware/activity/loader/ActivityConfigLoader.lua:15`；`analysis/native_decode/decoded/amf/middleware/activity/model/ActivityModel.lua:30`

## E02 运行信息更新

在线登录、非首次进入主界面、已登录后回前台会请求活动信息并reload。getActInfos2024返回actInfos和activityParticipationTags。

来源：`analysis/native_decode/decoded/amf/middleware/activity/ActivityMgr.lua:165`；`analysis/native_decode/decoded/amf/middleware/activity/ActivityMgr.lua:180`；`analysis/native_decode/decoded/amf/middleware/activity/ActivityMgr.lua:202`；`analysis/native_decode/decoded/amf/middleware/activity/model/ActInfosModel.lua:54`

## E03 活动时间边界

活动节点：now<begin为未开始；begin≤now<mainBegin预热；mainBegin≤now<mainEnd正式；mainEnd≤now<end领奖；now≥end结束。与强弹配置独立有效期不要混淆。

来源：`analysis/native_decode/decoded/amf/middleware/activity/node/ActivityNode.lua:176`

## E04 活动资格

图标系统/启动器/config就绪，config.isSupport()严格true；只有存在actInfo时才检查see，缺actInfo并非此函数直接拒绝。完整资源就绪才向调度返回配置候选。

来源：`analysis/native_decode/decoded/amf/middleware/activity/node/ActivityNode.lua:75`；`analysis/native_decode/decoded/amf/middleware/activity/node/ActivityNode.lua:100`；`analysis/native_decode/decoded/amf/middleware/activity/node/ActivityNode.lua:235`

## E05 初次配置筛选

genActAutoPopupConfig检查时间、规则次数、付费、活跃、实验；时间是闭区间begin≤now≤end。场景检测未再次调用这五项。不能称所有条件在弹前重新校验。

来源：`analysis/native_decode/decoded/amf/middleware/activity/processor/AutoPopupProcessor.lua:108`；`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:291`；`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:527`

## E06 场景候选筛选

场景匹配，关卡/星/低精力/无限精力/自定义规则重查；普通主面板还要end-now>60秒；自定义3/4没有这条统一60秒门槛。

来源：`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:527`；`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:308`

## E07 活跃付费过滤

autoPopPayType映射无/低/中低/中高/高为0..4；autoPopActiveType新/回流/低/中低/中/中高/高为1..7。配置数组包含匹配；不是越付费越多的固定方向。

来源：`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:330`；`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:360`

## E08 精力与区间

autoPopMinEnergy实际energy<=值，缺精力按30；关卡和主线+隐藏星按闭区间；无限精力字符串true要求无限，其余非空要求非无限。

来源：`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:462`；`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:407`；`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:434`；`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:478`

## E09 实验开关并非全部AND

groupSwitch以分号分隔，任一匹配即通过；无值、格式不全放行；开关查询src=5也放行。

来源：`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:378`

## E10 R1/R2/R3频次

R1每日次数，key含当天零点；R2次数key含活动endTime，并非账号终身；两者默认1，可参数覆盖；R3不在此层限次，仍受其他规则。

来源：`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:186`；`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:205`

## E11 计数分两层

框架checkpoint计数、同轮类型计数在调用creator之前增加；不等价屏幕已成功显示。配置R1/R2由ACTIVITY_POPUP_OVER处理同步，也可由手动开活动通知；PopupModel本地先+1再异步同步服务器。

来源：`analysis/native_decode/decoded/amf/middleware/autopop/fsm/PopupDoPopState.lua:16`；`analysis/native_decode/decoded/amf/middleware/activity/processor/AutoPopupProcessor.lua:25`；`analysis/native_decode/decoded/amf/middleware/autopop/model/PopupModel.lua:81`；`analysis/native_decode/decoded/amf/middleware/autopop/model/PopupModel.lua:91`；`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:905`

## E12 场景1/2/3/4

1登录占位默认无类型序列且额度0；2首次主界面/外部回前台等；3带主线/隐藏/满星关信息的出关回主界面流程；4接3，下一关开始面板关闭或未弹开始面板后。失败也可进入3，不能只称通关。

来源：`analysis/native_decode/decoded/amf/middleware/autopop/config/AutoPopupConst.lua:5`；`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:1485`；`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:511`；`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:529`；`analysis/native_decode/decoded/amf/middleware/autopop/config/ServerConfigDefault.lua:59`

## E13 场景执行屏障

FSM非待机或进关流程中不启动；场景2在图标点击冷却、屏上引导、面板未关闭时会推迟/跳过；doPopup要求在主界面。

来源：`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:931`；`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:975`

## E14 分组与日上限

服务端popupInfoV2SceneMap覆盖每场景类型额度、类型优先序和预算豁免组；该场景下省略某类额度取0，-1转99。checkpoint上限本地表；未列默认1/日，-1仅跳过此层限制；每日类型总量表当前为空。

来源：`analysis/native_decode/decoded/amf/middleware/autopop/config/ServerConfigMgr.lua:18`；`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:661`；`analysis/native_decode/decoded/amf/middleware/autopop/config/AutoPopupLimit.lua:147`

## E15 300秒不是禁止弹窗

场景2普通预算4：now-last>300只减本轮数，否则减本轮+上一轮数；豁免组不受该预算。3→4普通预算1只扣当前4轮次，代码未减lastStagePopSum；政策/条件/礼包默认豁免。

来源：`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:628`；`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:601`；`analysis/native_decode/decoded/amf/middleware/autopop/config/AutoPopupLimit.lua:213`；`analysis/native_decode/decoded/amf/middleware/autopop/config/ServerConfigDefault.lua:91`

## E16 两种入口与去重

配置式和注册式并存；同活动有注册式时先从配置候选移除再截断。注册check在场景进入运行；creator并未统一重跑check。队列key=checkpoint，重复写同key覆盖前项。

来源：`analysis/native_decode/decoded/amf/middleware/activity/ActivityMgr.lua:442`；`analysis/native_decode/decoded/amf/middleware/autopop/module/registration/PopupRegistration.lua:227`；`analysis/native_decode/decoded/amf/middleware/autopop/module/registration/PopupRegistration.lua:289`；`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:794`

## E17 优先顺序分两层

配置候选priority=10100-relative值，升序选前limitNum（所以relative越大越靠前）；全队列先按场景类型序、组内checkpoint静态序，再可AI重排。候选排序名次不等于展示。

来源：`analysis/native_decode/decoded/amf/middleware/activity/config/APMetaConfigRef.lua:158`；`analysis/native_decode/decoded/amf/middleware/activity/ActivityMgr.lua:442`；`analysis/native_decode/decoded/amf/middleware/autopop/module/schedule/PopupSchedule.lua:331`；`analysis/native_decode/decoded/amf/middleware/autopop/module/schedule/PopupSchedule.lua:138`

## E18 实际取出前仍检查

取候选复核类型轮次/日/场景预算、限定场景和checkpoint动态屏蔽；未见统一在这里重查注册业务check或AP完整条件。

来源：`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:172`

## E19 AI每日数据与资格

拉取需要popup_rec_on1/ON1开关、当天未成功拉取、无在飞请求；登录/回前台/非首次主界面触发。空表响应也可能记录当天已请求。缓存同一天不覆盖，保留3天。

来源：`analysis/native_decode/decoded/amf/feature/localactivity/aipopup/AIPopupManager.lua:99`；`analysis/native_decode/decoded/amf/feature/localactivity/aipopup/AIPopupManager.lua:38`；`analysis/native_decode/decoded/amf/feature/localactivity/aipopup/model/AIPopupModel.lua:122`；`analysis/native_decode/decoded/amf/feature/localactivity/aipopup/model/AIPopupModel.lua:13`

## E20 AI改变谁先弹

仅场景3/4，两名以上有actId和当天分数候选降序稳定排序；无分数候选位置保留。分数必须0..1，非法按0.12。resolver必须返回同一候选集合，错误回退静态。

来源：`analysis/native_decode/decoded/amf/feature/localactivity/aipopup/AIPopupManager.lua:195`；`analysis/native_decode/decoded/amf/feature/localactivity/aipopup/model/AIPopupModel.lua:44`；`analysis/native_decode/decoded/amf/middleware/autopop/module/schedule/PopupSchedule.lua:94`

## E21 AI开关的限定

请求检查维护开关；排序isEnabled仅缓存predictions非空，实际逐活动再查当日。不能说关开关立即停止已有缓存排序。外层自然天key决定归属，不以payload.target_date覆盖。

来源：`analysis/native_decode/decoded/amf/feature/localactivity/aipopup/AIPopupManager.lua:58`；`analysis/native_decode/decoded/amf/feature/localactivity/aipopup/AIPopupManager.lua:62`；`analysis/native_decode/decoded/amf/feature/localactivity/aipopup/model/AIPopupModel.lua:65`

## E22 活动参与标签

服务器字符串actId_L1..L4_depth；L1-3深度空；L4需0..1；nil未就绪，空字符串已就绪零活动；坏条丢弃，重复ID保留首条。

来源：`analysis/native_decode/decoded/amf/middleware/activityparticipation/ActivityParticipationMgr.lua:59`；`analysis/native_decode/decoded/amf/middleware/activity/model/ActInfosModel.lua:54`

## E23 参与层级不等于活跃

L1有资格，L2已曝光，L3可显示卡片，L4实际参与。卡片：未就绪放行，已就绪无标签不显示；此逻辑不能推成所有强弹的通用资格。

来源：`analysis/native_decode/decoded/amf/middleware/activityparticipation/ActivityParticipationMgr.lua:110`；`analysis/native_decode/decoded/amf/middleware/activityparticipation/ActivityParticipationMgr.lua:190`；`analysis/native_decode/decoded/amf/middleware/activityparticipation/ActivityParticipationMgr.lua:194`；`analysis/native_decode/decoded/amf/middleware/activityparticipation/ActivityParticipationMgr.lua:199`

## E24 参与降频

active_low_intent ON1拦L2；ON2拦L2/L3；缺标签或未就绪不拦；配置主面板适配表只有6077钓鱼赢家，已进入当期不降频。其他活动需要看各自消费者，不可全量套用。

来源：`analysis/native_decode/decoded/amf/middleware/activityparticipation/ActivityParticipationMgr.lua:119`；`analysis/native_decode/decoded/amf/middleware/activityparticipation/ActivityParticipationMgr.lua:8`；`analysis/native_decode/decoded/amf/middleware/activityparticipation/ActivityParticipationMgr.lua:158`

## E25 活动名单不能从框架推线上

客户端可读加载算法、字段合同、默认预算、调用逻辑；线上活动名单/时段/资源版本/see、维护分组、AI分数、真实计数需服务端响应。没有服务端生成/训练代码，不能解释其分层算法或线上命中比例。

来源：`analysis/native_decode/decoded/amf/middleware/activity/loader/ActivityConfigLoader.lua:6`；`analysis/native_decode/decoded/amf/middleware/activity/model/ActInfosModel.lua:54`；`analysis/native_decode/decoded/amf/middleware/autopop/model/PopupModel.lua:35`

## E26 主面板提前入队与候选名额

进入主界面/前台处理同时收集场景2和4主面板，普通主面板每场景只选1；3/4自定义各选3。不能以场景4实际展示时状态反推其条件刚刚重查。结果按stage+isMetaPop缓存，活动移除/弹出通知/活动周期事件清缓存。

来源：`analysis/native_decode/decoded/amf/middleware/autopop/module/activity/PopupNewActMgr.lua:434`；`analysis/native_decode/decoded/amf/middleware/activity/config/ActivityConst.lua:48`；`analysis/native_decode/decoded/amf/middleware/activity/ActivityMgr.lua:442`；`analysis/native_decode/decoded/amf/middleware/activity/ActivityMgr.lua:551`

## E27 配置主面板并非关闭后才记数

TempActPanelHandler creator仅确认metaId仍存在；派发OPEN_ACTIVITY后立即重置强弹并发ACTIVITY_POPUP_OVER，不等待面板成功打开或关闭。自定义3/4在pcall(customizedCreator)调用未抛错后就发ACTIVITY_POPUP_OVER，不要求返回true或实际显示；完成回调只通知SINGLE_POP_OVER继续队列。

来源：`analysis/native_decode/decoded/amf/middleware/autopop/module/poptype/TempActPanelHandler.lua:39`；`analysis/native_decode/decoded/amf/middleware/autopop/module/poptype/ConditionHandler.lua:103`；`analysis/native_decode/decoded/amf/middleware/autopop/module/poptype/ConditionHandler.lua:142`

## 未闭环与反例边界

- autoPopMinLevel/MaxLevel均为-1分支调用getUserState，旧报告指出本地类未定义；本次未扩展运行时注入确认。不可把该特例写成已运行验证。
- 框架允许每个活动自定义check/creator，并可动态下载activity包。全框架复核不等于所有历史/线上活动包已取得。
- 注册式check只在场景进入调用；单个creator可能再校验，也可能不校验，要逐活动确认。
- 场景4新关保护的4小时窗口由另一模块定义，本次仅复核AutoPopupMgr调用，不重报全链复核。
- 配置R1/R2由ACTIVITY_POPUP_OVER驱动；主面板在请求打开后、自定义在pcall未抛错后派发，不等关闭。手动活动路径仍需逐活动追踪。框架checkpoint明确在creator前消耗。
- 客户端AI分数与L4参与深度是独立数据；无证据表明同一数值或统一训练目标。
- 此审计不将图标展示、活动中心卡片、强弹和OS通知统称同一种推送。
