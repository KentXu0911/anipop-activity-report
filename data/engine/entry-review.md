# 入口、共同基类及新关保护补审

只核查解密客户端的生产可达路径；调试强制入口不作为线上启用证据。图标、关内卡片、活动中心和强弹分别处理。

## N01 四小时是真正的数值规则

isInNewLevelTime不传delta时取14400秒；当前可打最高主线关定位区域，拿开放时间；open<=now<=open+14400有效，两端包含。不是登录后4小时，也没有在此函数硬编码周五19点。

来源：`analysis/native_decode/decoded/amf/middleware/levelarea/unlock/module/UnlockConfigCheck.lua:44`；`analysis/native_decode/decoded/amf/middleware/levelarea/levelconfig/LevelUnlockConfigParser.lua:346`

## N02 最新新关不是固定30关

isTopNewMainOrHideLevel取当前最高主线区域对应解锁配置areaIDs，主线判断关卡所属区域是否在列表；隐藏分支匹配隐藏区域startNormalLevel与主线区域minLevel。因此新关批次数量来自配置，不固定Top30。

来源：`analysis/native_decode/decoded/amf/middleware/levelarea/unlock/module/UnlockConfigCheck.lua:71`；`analysis/native_decode/decoded/amf/middleware/levelarea/levelconfig/LevelUnlockConfigParser.lua:333`；`analysis/native_decode/decoded/amf/middleware/levelarea/levelconfig/LevelAreaConfigParser.lua:67`

## N03 当前最高关计算

getLocalTopLevel(false)：当前倒计时区域未结束时取前一区maxLevel；否则取已解析最大主线关，false不做后续在线解锁NEED检查。保护窗口使用的是客户端当前可打关卡上限，而非玩家个人最高进度。

来源：`analysis/native_decode/decoded/amf/middleware/levelarea/unlock/module/TopAreaInfoLogic.lua:296`；`analysis/native_decode/decoded/amf/middleware/levelarea/unlock/module/TopAreaInfoLogic.lua:284`

## N04 新关保护适用范围

AutoPopupMgr:ignoreForTopLevelPlayer须非TOP_STAR、isMainLevel(scene)通过、刚打的关卡属于最新发布区域、处于4小时窗口。isMainLevel(nil)也返回真；Stage3实际写状态未传scene，因此主线正常命中，但不能假定所有传入场景都保留原类型。handleStage4AfterStartGameNoPop才执行该保护；不能说所有场景4/所有活动统一屏蔽。

来源：`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:557`；`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:529`；`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:511`

## N05 Top30/周五是注释不是硬规则

MainSceneButtonManager.canPlayStarWandAutoPop的周五19-23/Top30注释落地调用ignoreForTopLevelPlayer，实际按前述开放配置而非数字30；其他isInNewLevelTime消费者有各自门槛，不由这条注释统一概括。

来源：`analysis/native_decode/decoded/amf/feature/mainscenebutton/MainSceneButtonManager.lua:256`

## B01 共同Manager没有默认开启判定

BaseFeatureManager:isEnabled函数为空，是子类覆写点。不能凭继承关系补出统一维护/平台/时间门槛。isActivitySupported(actId)实际上返回ActivityMgr:isActReady(actId)==true，活动ID从const.actId/ACT_ID兜底。

来源：`analysis/native_decode/decoded/amf/middleware/activity/base/BaseFeatureManager.lua:240`；`analysis/native_decode/decoded/amf/middleware/activity/base/BaseFeatureManager.lua:184`；`analysis/native_decode/decoded/amf/middleware/activity/ActivityMgr.lua:389`

## B02 共同Model时间是左开右闭

BaseFeatureModel预热begin<now<=mainBegin；正式mainBegin<now<=mainEnd；领奖mainEnd<now<=end，先tryConvertMsToSec。与ActivityNode的左闭右开分期存在边界差异，报告应按调用模块写条件；默认时间字段读不到为0。

来源：`analysis/native_decode/decoded/amf/middleware/activity/base/BaseFeatureModel.lua:189`；`analysis/native_decode/decoded/amf/middleware/activity/base/BaseFeatureModel.lua:194`；`analysis/native_decode/decoded/amf/middleware/activity/base/BaseFeatureModel.lua:199`；`analysis/native_decode/decoded/amf/middleware/activity/node/ActivityNode.lua:176`

## B03 日/期标记只是可选校验

setLocalValueByKey保存当天零点、值、mainBeginTime；读时只有needTime为真才要求同日，只有needActStartTimeCheck真才要求同一期。不传参数不能称日限/期限；具体子类调用决定。

来源：`analysis/native_decode/decoded/amf/middleware/activity/base/BaseFeatureModel.lua:87`；`analysis/native_decode/decoded/amf/middleware/activity/base/BaseFeatureModel.lua:104`

## B04 关内卡片与参与标签

ActPlug.shouldShowInLevelCard：bottomSwitch ON3没开直接允许，已参与直接允许，否则才调用参与标签卡片判定。它是关内卡片，不是活动中心列表或所有图标的统一门槛。

来源：`analysis/native_decode/decoded/amf/middleware/activity/base/plug/ActPlug.lua:20`

## I01 图标与活动资格

ActivityNode启动后IconProcessor还需图标系统就绪、config.icon存在、config.isSupport返回真。没有icon不代表活动不存在或不能强弹。Node仅预热/正式期启用发现新活动通知标志，领奖期不能据此推成图标一律隐藏。

来源：`analysis/native_decode/decoded/amf/middleware/activity/processor/IconProcessor.lua:109`；`analysis/native_decode/decoded/amf/middleware/activity/processor/IconProcessor.lua:206`；`analysis/native_decode/decoded/amf/middleware/activity/node/ActivityNode.lua:455`

## I02 V2采用条件与旧版回退

配置icon.mode=dataDriven、dataProvider为非空字符串、NewVineicon_v2/ON实验开启、可选useDataDrivenWhen返回boolean真才走V2。实验按有效UID缓存快照。V2初始化失败可回退旧图标；provider not_present是明确不展示，释放owner，不应当作错误回退重建旧入口。

来源：`analysis/native_decode/decoded/amf/middleware/activity/processor/IconProcessor.lua:469`；`analysis/native_decode/decoded/amf/middleware/activity/processor/IconProcessor.lua:344`；`analysis/native_decode/decoded/amf/middleware/activity/processor/IconProcessor.lua:369`；`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/experiment/IconV2Experiment.lua:16`

## I03 红点可来自服务端也可本地业务

IconProcessor转发actInfo.reward/msgNum/rank/progress/maxProgress；ActInfoStateOverride先允许provider接管reward/msgNum，否则reward严格true显示奖励，msgNum转换非负整数作为数字红点。本地ActPlug.updateTipView也能从业务hasReward/getMsgNum覆盖actInfo并发送SET_ACT_INFO。不能说所有红点服务器独占。

来源：`analysis/native_decode/decoded/amf/middleware/activity/processor/IconProcessor.lua:550`；`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/provider/ActInfoStateOverride.lua:31`；`analysis/native_decode/decoded/amf/middleware/activity/base/plug/ActPlug.lua:93`；`analysis/native_decode/decoded/amf/middleware/activity/base/plug/ActPlug.lua:82`

## I04 右上角竞争规则

V2默认角标优先奖励→感叹号→NEW→数字→红点；自定义优先序验证后可覆盖，漏项补全。可见折扣<10且有bubbleRenderer时折扣优先占右上角，角标隐藏；奖励动画被明确关闭。不是多个提醒同时堆叠。

来源：`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/resolver/RightTopSlotResolver.lua:4`；`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/resolver/RightTopSlotResolver.lua:66`；`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/resolver/RightTopSlotResolver.lua:334`；`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/resolver/RightTopSlotResolver.lua:107`

## I05 图标优先级不是AI强弹分数

IconPriorityController.DYNAMIC_PRIORITY_ENABLED=false：创建时首次解析业务getDynamicPriority，以后冻结；只允许右侧pool且不得跨pool/越界，否则回退基础优先级。这不等于全站所有图标永不排序，也不影响独立AI强弹排序。

来源：`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/runtime/IconPriorityController.lua:8`；`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/runtime/IconPriorityController.lua:137`；`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/runtime/IconPriorityController.lua:84`

## I06 发现新活动A/B/C

V2 newActivityType A=红点，B=NEW，C=NEW并具通知资格，none不提醒；未合法配置类型退A。必须有cycleKey且未清除，notice/legacyPanel未记录；B可配置首次临时C，需featureKey且首次记录未消费。有NEW不等于一定强弹通知。

来源：`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/newactivity/NewActivityPolicy.lua:74`；`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/newactivity/NewActivityPolicy.lua:131`

## I07 发现通知顺序与计数

NotificationCoordinator按poolIdx升序、同位cycleKey升序聚合，场景2优先，场景4需等待2或兜底；notice记录在onVisible时写，与普通强弹creator前计数不同。展示前取消可不消耗。maxBatchSize仅可选参数，此审计不编造固定显示数量。

来源：`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/newactivity/NotificationCoordinator.lua:200`；`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/newactivity/NotificationCoordinator.lua:429`；`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/newactivity/NotificationCoordinator.lua:273`；`analysis/native_decode/decoded/amf/feature/mainscene/module/icon/v2/newactivity/NotificationCoordinator.lua:474`

## C01 活动中心入口79关

活动中心须FeatureSwitch.ACT_CENTER、ActivityMgr开启、最高关>=79。活动启动成功且config.miniGameCenterAct真才收入活动中心；展示前清理isSupport=false条目。不是全部活动自动进中心。

来源：`analysis/native_decode/decoded/amf/middleware/activity/activitycenter/ActivityCenterManager.lua:120`；`analysis/native_decode/decoded/amf/middleware/activity/activitycenter/ActivityCenterManager.lua:134`；`analysis/native_decode/decoded/amf/middleware/activity/activitycenter/ActivityCenterManager.lua:193`；`analysis/native_decode/decoded/amf/middleware/activity/activitycenter/model/ActivityCenterModel.lua:32`

## C02 中心列表排序与红标

列表needTop=true优先，再beginTime越新越前，再actId越大越前；最新活动的redTag按beginTime/actId选出。中心奖励提醒需buttonText非空、hasReward真、HasReward+actId本地标志尚未设置；消息数汇总actInfo.msgNum。这个红标不等于AI分数，也不是参与L3门槛。

来源：`analysis/native_decode/decoded/amf/middleware/activity/activitycenter/view/ActivityCenterPanelVM.lua:54`；`analysis/native_decode/decoded/amf/middleware/activity/activitycenter/ActivityCenterManager.lua:79`；`analysis/native_decode/decoded/amf/middleware/activity/activitycenter/ActivityCenterManager.lua:102`

## N06 缺省场景按主线处理

Stage3Handler的两条setStage3PopupState调用只传state和levelId，AutoPopupMgr保存scene=nil；UBFLevelSceneFunc:isMainLevel(nil)返回true。这是缺省语义，不应误报缺scene导致保护必失效；隐藏/满星关仍取决于其levelId能否映射到最新主线区域。

来源：`analysis/native_decode/decoded/amf/middleware/autopop/module/popstage/Stage3Handler.lua:60`；`analysis/native_decode/decoded/amf/middleware/autopop/AutoPopupMgr.lua:500`；`analysis/native_decode/decoded/ubf/UBFPlay/utils/UBFLevelIdUtil.lua:30`

## 精确剩余缺口

- Icon V2 的通用provider生命周期、每活动provider业务值、布局池完整重排/动画所有分支未全覆盖；这里只确认采用门槛、状态覆写、角标竞争、冻结优先级及发现通知。
- 活动中心banner是独立ActivityCenterBannerModule；本补审未将其候选/日限规则纳入已审核列表，不能和列表排序合并。
- 最新开放时间来自LevelUnlockConfigParser已解析解锁配置；客户端消费链已闭合，但本次未取得线上区域开放配置。
- BaseFeatureManager不提供统一平台/维护门槛，各子类isEnabled和动态活动config.isSupport仍须各自查看。
- Stage3写状态未传levelScene，而UBFLevelSceneFunc.isMainLevel(nil)=true，不能把缺scene当成自动不生效。实际隐藏/满星关路径需结合levelId区域映射，不能仅凭上层方法名断言所有场景资格。
