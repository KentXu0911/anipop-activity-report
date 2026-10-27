# 开心消消乐：活动投放、玩家分层、关卡推荐静态拆解

取证对象：本次 APK 解密后的 Lua。下文 `amf/...`、`ubf/...`、`zoo/...` 均相对于 `analysis/native_decode/decoded/`，行号为解密文件真实行号。**这是客户端可执行规则与包内数据，不是线上某账号的活动名单、预测分数、实验比例或服务端算法训练代码。** 未启动游戏登录，未请求游戏业务服务，未取得在线响应。本文件只分析投放/分层，不替代动态难度主报告。

## 1. 可成立的结论

1. 活动不是一个简单全局开关：资源/启动器、活动自身 `config.isSupport()`、服务端 `actInfo.see`、配置化时间/付费/活跃/实验门槛、业务阶段条件、次数预算、静态优先级与可选 AI 排序叠加。配置式旧入口与声明式新入口并存，同活动优先保留声明式入口。
2. 包内存在真实接线的 AI 活动强弹排序：从 `aiAutoPopInfo` 读取每日每活动分数，场景 3、4 在已定义候选上重排。它不生成新活动，不保证低分活动被彻底移除，也不能由这些文件反推出推荐模型训练特征或目标函数。
3. 活动参与分层独立于全局活跃/付费标签：`activityParticipationTags` 是每活动 L1–L4，L4 才允许附参与深度 0–1。`active_low_intent` 实验按 L2 或 L2+L3 对首次触达降频，已参与当前期的用户通常豁免。
4. 玩家分层包括：六类业务标签、DP 离线标签、近 60 天消费本地阈值、进度/星级五分群、UID/哈希实验分桶。分层维度并非同一个枚举。
5. “关卡推送”至少有三种不同实现：结束面板下一关/补星推荐、低等级自动进关、系统通知新关发布。活动主界面强弹与 OS 通知也有分离的调度器和上限。

## 2. 活动投放完整路径

### 2.1 服务端信息和资源资格

`ActivityModel:updateConfig` 通过生产 `ActivityConfigLoader` 拉活动配置，成功记录 activities/rootUrl，本次登录一般不重复拉；开发机/Unity/小游戏开发入口可走本地配置，不能拿本地调试配置当线上投放事实（`amf/middleware/activity/model/ActivityModel.lua:30`、`:37`、`:42`、`:53`）。过滤 `isEmptyActivity=true`（`:65`）。

`getActInfos2024` 响应成功后把 `actInfos[]` 转为 actId map，并广播 `activityParticipationTags` 和 `fromServer=true`（`amf/middleware/activity/model/ActInfosModel.lua:54`）。请求包内的 `getMockData()` 是测试示例，配置明确 `useMockData=false`（`amf/middleware/activity/http/RequestActInfos.lua:4`）。不要把示例 `4062_L4_0.732;6074_L2_;9084_L3_` 当真实用户数据。

活动节点 before/condition/after：

| Before | Condition | After | 代码锚点 |
|---|---|---|---|
| 收到活动配置/信息 | icon 系统就绪、启动器加载成功、可 require 活动 config | 才允许后续启动 | `amf/middleware/activity/node/ActivityNode.lua:75` |
| 启动器已加载 | `config.isSupport()` 返回 true；若有 actInfo，`see` 必须真 | 加载代码与 icon，然后创建强弹处理器 | 同文件 `:100`、`:367` |
| 当前时间到边界 | beginTime/mainBeginTime/mainEndTime/endTime | BEFORE_BEGIN→PREHEAT→MAIN→AWARD→END | 同文件 `:176` |
| 发现配置式强弹 | 时间、R1/R2/R3 次数、付费类型、活跃类型、实验开关都通过 | 创建本次活动 AP 配置 | `amf/middleware/activity/processor/AutoPopupProcessor.lua:108` |
| 当前阶段检测 | 场景匹配、关卡/星/精力/无限精力、自定义业务条件通过 | 给出 main/customize 候选 | `amf/middleware/activity/config/APMetaConfigRef.lua:527` |
| 配置候选准备入队 | 同活动已有声明式注册 | 拒绝配置式重复入口 | `amf/middleware/autopop/AutoPopupMgr.lua:844` |

重要缺口：活动自己的动态 `activity/<source>` 包和在线配置不等于 APK 固有内容。这里能证明通用投放框架，但不能凭包内空/调试活动列表声称当前用户获得全部活动。

### 2.2 配置化受众门槛

主要字段可直接用于复刻配置表（声明/加载见 `amf/middleware/activity/config/APMetaConfigRef.lua:9`、`:49`）：

| 字段 | 确认的消费语义 |
|---|---|
| `metaId`, `actId`, `beginTime`, `endTime` | 活动强弹唯一配置身份和有效期；当前时间在闭区间内才有效（`:291`） |
| `autoPopScene` | 映射强弹场景，当前场景必须在列表（`:104`、`:538`） |
| `autoPopPayType` | 对 `getUserPaymentTag()` 映射的 0–4 做列表包含判断；不是 v2 七档（`:313`） |
| `autoPopActiveType` | `biLivenessTag` 的新/回流/低/中低/中/中高/高映射 1–7，未知 0；使用原始系列读取，不执行 `getUserTag` 的有效期检查（`:344`、`:360`） |
| `autoPopMinLevel`, `autoPopMaxLevel` | topLevel 包含边界区间；两者 -1 的分支意图为满级用户，但代码调用 `UserStateManager:getUserState()`，本次静态类未定义该方法，需要运行时确认，不能直接当无条件可靠规则（`:407`） |
| `autoPopMinStar`, `autoPopMaxStar` | 主线+隐藏星总数闭区间；两者 -1 则须 TOP_STAR（`:434`） |
| `autoPopMinEnergy` | **实际比较 `curEnergy <= configured`，字段虽叫 Min，消费方向是低精力上界**；缺省精力取 30（`:462`） |
| `autoPopUnlimitedEnergy` | 空/缺省不限制；字符串 `"true"` 要求 INFINITE，否则要求非 INFINITE（`:478`） |
| `groupSwitch` | `switch|group;...` 多条任一命中；无值/无法解析时放行；不存在开关返回 src=5 时也放行（`:377`）；不应理解为所有开关 AND |
| `autoPopRelativePriority` | 内部优先级为 `10100 - configured`（`:158`） |
| `autoPopRule`, `autoPopRuleParam1` | R1 每天，R2 活动配置生命周期，R3 每次；R1/R2 参数默认次数 1（`:186`、`:205`） |
| `autoPopCustomizedCheck`, `autoPopCustomizedCreator` | 活动 config 的函数名；只接受真实函数，进一步做业务判断和展示（`AutoPopupProcessor.lua:130`） |
| `autoPopRuleParam2` | 注释和代码均为保留参数，未见消费（`APMetaConfigRef.lua:35`） |

主面板候选还要求剩余有效期 **严格大于 60 秒**（`APMetaConfigRef.lua:308`、`:564`）。

R1 key 为 `R1_actId_metaId_todayStart`；R2 key 为 `R2_actId_metaId_endTime`。因此所谓“终身一次”实际绑定结束时间，换期可重新计数。R3 不限次。弹完 R1/R2 同步计数，再判断是否移出本次配置集合（`APMetaConfigRef.lua:186`、`:205`、`:246`、`:264`；`AutoPopupProcessor.lua:25`）。

### 2.3 场景、优先级和预算

- 场景 1：登录场景；默认各类额度为 0。
- 场景 2：外部/首次进主界面、前台唤回等；政策→闪退恢复/自动进关→外部链接→系统→活动→礼包→临时活动→召回→条件→功能。
- 场景 3：出关后第一阶段；通关后处理返回、下一关开始面板、加五步/活动等。默认列表只有政策→条件。
- 场景 4：场景 3 完成或下一关开始面板关闭后，再触发政策→条件→系统→活动→礼包→临时活动→召回→功能→引导。

精确入口：`amf/middleware/autopop/config/AutoPopupConst.lua:5`；`module/popstage/Stage2EnterSceneHandler.lua:21`；`Stage3Handler.lua:38`；`Stage4Handler.lua:27`；`AutoPopupMgr.lua:511`、`:529`。上述相对路径前缀均为 `amf/middleware/autopop/`。

| 默认同轮 PopType 额度 | 场景 2 | 场景 3 | 场景 4 |
|---|---:|---:|---:|
| policy | 2 | 2 | 2 |
| outside | 99 | 0 | 0 |
| system | 1 | 0 | 1 |
| activity | 3 | 0 | 2 |
| recall | 1 | 0 | 1 |
| condition | 2 | 99 | 99 |
| function | 1 | 0 | 3 |
| crash_resume | 1 | 0 | 0 |
| guide | 0 | 0 | 99 |
| gift_pack | 2 | 1 | 2 |
| temp_act_panel | 1 | 0 | 1 |

来源 `amf/middleware/autopop/config/ServerConfigDefault.lua:4`；**额度不等于一定可弹出的数量**：场景列表、业务 check 和以下预算还会继续筛。在线 `popupInfoV2SceneMap` 可以覆盖每场景各类额度、完整优先序和部分队列优先序。后端 `-1` 转成本地 99；未配置类型为 0（`config/ServerConfigMgr.lua:18`）。

场景预算 `AutoPopupLimit.StagePopupNum`：场景 2 为 4、场景 4 为 1；场景 2 相邻触发间隔为 **300 秒**。实现不是“300 秒内全部禁止”：300 秒内扣减上轮弹数和本轮弹数，超过 300 秒仅扣本轮；政策/闪退恢复/外部属于默认豁免部分队列。3→4 的政策/条件/礼包默认豁免阶段总量限制（`AutoPopupMgr.lua:601`、`:628`；`config/AutoPopupLimit.lua:213`；`config/ServerConfigDefault.lua:91`）。

每日 checkpoint 未配置默认 1；显式 -1 跳过框架的每日限制，但活动可另做本地期数/24h CD/引导标记限制。完整 **133 条包内显式配置**见 `popup_checkpoint_caps.csv`，比如集卡日礼包=2，多个场景 4 主面板=1。不能把 -1 翻译成“整个系统无限次”。手点打开也会消耗 checkpoint 日额度（`AutoPopupMgr.lua:648`、`:905`）。开发模式 `_isNumLimitEnabled=false`，线上普通模式 true（`:84`），调试观察不能代表正常预算。

新关首发窗口还存在场景 4 保护：主线新头部关、并非 TOP_STAR、在新关开启窗口内且没有弹下一关开始面板，则跳过场景 4（`AutoPopupMgr.lua:529`、`:556`）。实际窗口来自 `amf/middleware/levelarea/unlock/module/UnlockConfigCheck.lua:44` 默认 **14400 秒**，已追到代码，非仅引用“暂定 4 小时”的注释。

## 3. AI 排序：精确范围与数据结构

真实接线位置为 `amf/script/spring/ioc/animal/mainscene/config/LocalActivityDI.lua:253`，不是一个孤立文件。`AIPopupManager:_init` 注册登录、前台/主界面和强弹曝光事件，安装到 AutoPopupMgr 的 schedule resolver（`amf/feature/localactivity/aipopup/AIPopupManager.lua:24`、`:38`、`:47`）。

```text
USER_LOGIN / foreground / reenter main
  → popup_rec_on1 / ON1 命中 && 当天未成功拉取 && 无请求在飞
  → ONLINE aiAutoPopInfo，timeout=10，useMockData=false
  → aiAutoPopInfo[自然天编号] = JSON payload
  → 按归属天 merge（已有同日数据不覆盖），保留最近 3 天
  → 使 PopupSchedule 缓存失效
  → 场景 3/4 候选中带 actId 且有分数的候选降序稳定重排
```

服务端 payload 合同：`target_date`、`prediction_id`、`strategy`、`predictions:{ actId: score }`；外层 key 是真正使用的归属天，payload 日期可能是昨日而挂在今日，客户端仍按外层今日使用，不修改原 payload（`amf/feature/localactivity/aipopup/model/AIPopupModel.lua:5`、`:64`、`:75`、`:186`）。

- 分数合法区间为 **[0,1]**，数值/可转数字均接受；越界或非数值兜底 **0.12**，不是剔除（`:44`）。未返回 actId 为无分数。
- 自然天成功响应后记录 lastFetchTime；失败允许后续事件重试；同日已缓存记录不覆盖，模型每日快照而非每次出关实时预测（`AIPopupManager.lua:93`；`AIPopupModel.lua:121`）。空表响应也满足 assign=true，可使当天不再请求，不能将每日 fetch 成功等同有当日有效预测。
- 仅场景 **3 和 4**、至少两名有分候选才重排；场景 2 原样返回；无 actId/无分候选保持原位置；分数相同按原 index 稳定排序（`AIPopupManager.lua:195`）。
- 例：静态 `[A(0.1), 系统无分, B(0.8)]` 变为 `[B, 系统无分, A]`；候选的限次和资格继续存在。
- resolver 不能增删/重复/返回未知候选，异常整体退回静态顺序（`amf/middleware/autopop/module/schedule/PopupSchedule.lua:93`）。候选基线含当轮未通过 check 的声明式定义，所以有排序位置不等于必展示（`:137`）。
- 只有实际移动且展示的候选产生 `ai_recommend/main_panel_show_intervene`，字段 `ai_popuprec_info` 为原 payload 序列化后 base64，`t1` 新活动，`t2` 被挤出原位置的活动（`AIPopupManager.lua:165`）；可为后续线上实验审计提供曝光证据。
- 拉取使用维护开关；排序 `isEnabled()` 只检查本地 predictions 非空，**不再直接复核维护开关**（`:58`、`:62`、`:196`）。因此不要武断声称“关开关即立即停止已缓存数据排序”。

包里有 mock 分数样例，但 `useMockData=false`。报告不会把 mock 中 0.82 等值列为真实推荐权重。当前线上开关是否开启、活动模型产出、覆盖率、收益/留存目标函数均未取得。

## 4. 每活动参与分层和降频实验

`amf/middleware/activityparticipation/ActivityParticipationMgr.lua:59` 实际解析：`actId_L[1-4]_depth`，多活动分号分隔；L1–L3 必须 depth 为空；L4 depth 必须数值且在 [0,1]；重复 actId 保留首条，坏条丢弃。nil 表示数据未就绪，空字符串表示已就绪但零条，二者会导致卡片行为不同。

| 参与状态 | 客户端语义与结果 | 锚点 |
|---|---|---|
| L1 | 具资格（hasTag/isEligible=true），未满足 exposed；卡片不显示 | `:186`、`:190`、`:194`、`:110` |
| L2 | 已曝光；ON1 或 ON2 对首次触达主面板降频 | `:119`、`:139` |
| L3 | 可显示关内卡片；仅 ON2 对首次触达主面板降频 | 同上 |
| L4 | realParticipation=true，可读取 depth；不受这个降频实验阻挡 | `:181`、`:199` |
| 未准备好 | 卡片默认允许；自动强弹不降频 | `:110`、`:119` |
| 已准备好但该活动缺标签 | 卡片不显示；自动强弹不因本实验降频 | `:110`、`:125` |

活动降频开关：`active_low_intent/ON1` 只屏蔽 L2；`ON2` 屏蔽 L2+L3；两者不命中则不降频。**L1 不是普遍封禁规则**。L4 的 depth 是参与深度数据，不是 AI 分数；二者来自独立协议，不应混用。

实际业务消费者：

- 配置式主面板仅对 actId **6077 / FishingWinnerManager** 接入，并要求 `hasEnteredCurrentPeriod()` 为 false（`ActivityParticipationMgr.lua:8`、`:158`；`APMetaConfigRef.lua:542`）。不要宣称所有老活动配置都自动受实验影响。
- Block：未进入当期才调用降频，场景 4 check 同时要求 isActivitySupported、isEnabled、首次 MainPanelShow 或 checkCanPop，展示时先写 MainPanelShow（`amf/feature/localactivity/block/BlockManager.lua:5`、`:100`）。
- MusicMaster：当期未参与才降频，仍须资源/有效期/新关保护通过；guide 标记保证主面板每期一次；可领奖的关内进度面板另有规则（`amf/feature/localactivity/musicmaster/module/MusicMasterPopMudule.lua:43`、`:76`）。
- 另有 FishingWinner、Gladiator、MagicRush、WinRepeatRank、MeMeFox 的具体调用点，完整源码检索可复查；并非仅按名称推测。
- 通用关内卡片须 `InLevelBridgeManager:checkBottomSwitchON3()` 才启用参与分层过滤，已经参与的用户直接放行（`amf/middleware/activity/base/plug/ActPlug.lua:20`）；ON3 的取得位于 `amf/middleware/activity/base/inlevelbridge/InLevelBridgeManager.lua:435`。

L2/L3/L4 的服务端生成标准、统计窗、深度分子分母、实验分桶比例不在这里，不能把客户端判定函数误当标签生产模型。

## 5. 玩家分层、阈值和标签有效期

### 5.1 legacy 目录仍是当前生产依赖

`AMFUserTagManager.lua:13` 明确 require 旧 `UserTagManager`，`:81` 同步后更新旧标签。新 `model/UserTag.lua:onSyncData` 是空方法。因此 `ubf/old/gamePlay/userTags` **不能因为 old 路径就判为死代码**；反过来新 AMF UserTag 数据壳也不能据字段声明当成已实现。

六类标签及主要维度见 `ubf/old/gamePlay/userTags/UserTagModel.lua:17`、`:48`：userTag（活跃、工作/周末、日内时段、登录频次、biLiveness）、difficultyTag（最高关难度/分位/连续 5 关、逻辑失败）、payTag（周/月/历史/60 日/上次登录消费）、socialTag（好友数/互动）、levelTag（进度、升级速度、星占比、关卡偏好）、propTag（道具使用频率）。`tag_config.csv` 导出 22 条寿命配置；`protocol_fields.csv` 导出 schema 字段，不包含在线玩家值。

全局 activationTag：0 none、1 WillLose、2 ReturnBack、3 NewAdd、4 NormalActive、5 HighlyActive（`UserTagModel.lua:157`）。biLiveness：0 none，1 新，2 回流，3 低，4 中低，5 中，6 中高，7 高（`:196`）。标签名指向分群语义，但包内不包含 BI 生产阈值；不可从 1–7 反推出活跃天数界限。

标准 `getUserTag` 检查 topLevel 在 `[tagTopLevelId, tagTopLevelId+length−1]` 且未过期；过期/关卡越界数值返回 0，表返回 nil 并给出原因（`UserTagModel.lua:992`）。`getUserTagBySeries` 返回原始值和关联范围/过期时间，不执行这一过滤（`:1052`），消费者选择不同会影响实际决策。

包内寿命数据：activation 各 1 天，对应关卡跨度为 WillLose=10、ReturnBack=12、NewAdd=1、NormalActive=999、HighlyActive=999；常见业务标签 1 天；usePropFrequency 7 天、跨度 9999；liveness/累计付费/60 日付费等 30 天、跨度 9999（`zoo/config/meta/user_tag_config.lua:3`）。注意本次枚举中的 biLiveness 与配置中的 liveness 字段存在沿革，不应武断认为二者具有同一生命周期。

### 5.2 可证明的消费金额分层

| 近 60 日消费额 x（源码金额单位） | 原 5 档 `getUserPaymentTag` | v2 `getUserPaymentTag2` |
|---|---|---|
| x≤0 | None | None |
| 0<x<13 | Low | Low |
| 13≤x<47 | MidLow | MidLow |
| 47≤x<240 | MidHigh | MidHigh |
| 240≤x<1000 | High | High4 |
| 1000≤x<3000 | High | High5 |
| x≥3000 | High | High6 |

锚点 `ubf/old/gamePlay/userTags/UserTagManager.lua:728`、`:743`。Timely v2 加本次会话 `getRmbPurchaseThisSession()`；普通版只使用缓存 last60DayPayAmount（`:762`、`:768`）。前后端枚举映射不同，serverVersion 低档需 +1（`:773`）。强弹配置 `autoPopPayType` 具体用旧五档，不能套 v2 七档。

### 5.3 DP 标签

114 条包内表见 `dp_tag_config.csv`（`zoo/config/meta/dp_user_tag_config.lua`），包括活跃、流失风险、过关能力、补黄/彩星能力、分平台优惠券等。`DpUserTagBean` 字段为 tagName、tagId、tagSource、tagMappedValue、version（schema `amf/middleware/data/userdata/user/http/pb/DpUserTagBean_proto_.lua:3`）。

`DpUserTagModel:updateTags` 仅 source=kLaunch 时写入响应 dpTags 并记录 localUpdateTime；未返回不清旧。读取 `getTagValue` 若更新时间距现在严格少于 **7 天**返回 tagMappedValue，否则 `LocalTagOutOfTime`（`ubf/old/gamePlay/userTags/DpUserTagModel.lua:156`、`:191`）。

枚举注释提供的部分后端合同：active_type_tag 156：7 天内新注册=new；昨日活跃且 t−8..t−2 未活跃=return；昨日及前窗均活跃=7days；其余=other。active_in_28_days 157：1–10/11–20/21–25/26–27/28 天分别低/中低/中/中高/高（同文件 `:47`）。这些是**代码中的标签释义**，本次没有取得生产端聚合代码以再次验证。

流失实验 `taskForWillLose` 的 GA/GB 按 Android/应用宝/iOS 选 G137/G140/G139，GC 选 G52，对照选 G141/G143/G142；仅所选标签映射值=pass 时为 true（同文件 `:237`）。这是消费离线规则结果，不能把 pass 当客户端自己计算的流失概率。

### 5.4 本地行为统计与进度人群

`UserTagManager:updateLevelLogData` 保留最多 300 次记录、最多 30 天日志，从最近活跃日推 C1/C2 和 D0–D3。C1=近 3 活跃日有效闯关次数/3，C2=更早最多 12 活跃日有效闯关次数/12；有效次数包含成功或逻辑失败。D0=最近 10 次尝试数/成功数，D1/D2 分别近 3 日/更早窗尝试数/成功数，D3=第 61–300 次尝试数/成功数；无成功用 1000000（`UserTagManager.lua:343`、`:377`、`:488`、`:511`）。注释称“难度”，实际公式是尝试/成功比，不是直接关卡难度分。具体不足样本、当天已有活跃分支存在窗口实现细节，应按源码复现而不是只按注释。

本地进度分群：FMJ=1 非满级，FMH=2 满级未满黄星，FMC=3 满黄未满彩，FMZ=4 满黄满彩未满紫，MHZC=5 全满；由当前本地开关上限与玩家主线/隐藏/彩星总量、最高通关比较生成，结束关卡/最高关变化会刷新（`amf/middleware/data/userdata/levelarea/UserStateManager.lua:29`、`:80`、`:139`；`config/UserStateConst.lua:5`）。不是服务端付费分层。

### 5.5 实验分桶

MaintenanceManager 实际是远程开关/分桶框架：平台、版本、注册时间过滤；白名单/黑名单；`group` UID 尾数取模；orthogonal 使用 `MD5(orthogonalVersion+uid)` 或 `MD5(maintenanceName+groupVersion+uid)` 取末尾默认 8 hex，再按配置权重区间分组（`amf/testtrack/abtest/MaintenanceManager.lua:927`、`:947`、`:1388`、`:1433`）。`isEnabledInGroup` 检查该组 modules 和 feature.enable，输出 result、algorithmId、src；线上比例必须拿对应远程维护配置，客户端函数本身不包含固定 50/50（`:1609`）。dummyUid/dummyGroup/testInfo 仅测试覆盖入口，不当作自然用户分群数据。

## 6. 关卡推荐/自动进关与系统推送

### 6.1 关内“下一关”推荐

`RecommendLevelManager` 按来源选择 Default 或 FarmPanel strategy；来源 FLOWER=1、FARM_STAR_PANEL=2、FARM_SCORE_PANEL=3（`amf/feature/recommendlevel/RecommendLevelManager.lua:23`；`config/RecommendLevelConst.lua:3`）。

默认主线策略（`recommendstrategy/strategy/DefaultNextLevelCalc.lua:6`）：

- 正常打关：推荐当前 topLevel，若就是正在打的 curLevel 则 +1；最终目标超过可玩 topLevel 时 ExitLevelJump 不打开（`ExitLevelJumpManager.lua:11`）。
- 补星：若距 topLevel **<15 关**且能解锁新区，先推荐最高通关+1；否则先找当前关之后最低已过但未 3 星，找不到回绕前面，再找未 4 星并回绕。
- 刷分：只有 userSegment>FMC（FMZ/MHZC）且 cur+1≤topLevel 时推荐下一主线关。
- 隐藏刷分不推荐下一关；隐藏补星优先后面已过的 1/2 星关，正常隐藏打关找下一可玩未过，再回绕。

辅助最小关搜索由 `RecommendLevelUtil.lua:19`、`:33`、`:47`、`:62`、`:75` 明确星阈值。满级不同分群分别引向未满黄/彩/紫的最低关（`:95`）。从补星面板进入则优先使用同 tab/blockIndex 的候选，当前已是首个取第二个，无同类才回退另一黄/彩 tab；刷分取列表中首个非当前且未过项（`recommendstrategy/strategy/FarmPanelNextLevelCalc.lua:6`、`:40`、`:59`）。这是确定性本地路由，未见这一模块调用 AI 预测关卡。

### 6.2 自动进关

`amf/middleware/autopop/module/popstage/Stage2EnterSceneHandler.lua:130`：topLevel 1–5，精力至少 5，App 默认允许或小游戏 keepinlevel/ON；派发 AUTO_START_LEVEL、needAlert=false。虽然注释写“5 级以下”，实际包含 5。注意这条分支先判断精力≥5，不能把无限精力自动当成豁免。

同文件 `:176`：1–100 级，非 7 日回流、有无限精力或≥5 精力且不在 `2026AutoInLevelTest/ON5` 才自动进关。调用 `:224` 先让 Recall2025 召回面板/Feed 模式处理，不是所有 100 级以下登录都无条件进关。其他回流走 RecallAutoStartLevelManager 的独立业务规则（`:235`）。这些是已有最高关的自动进入，不是凭空选择任意一关。

### 6.3 OS 本地通知：单独一套调度器

`amf/middleware/notification/localpush/LocalPushManager.lua:17` 要求 LOCAL_PUSH feature，鸿蒙分支直接关；只接收 activate=true 且 pusher=client 的 notification_v2 配置（`:113`）。后台/确认退出时统一向 SDK 注册，回前台还原待发送列表并撤销已注册闹钟（`:233`、`:243`）。**系统远程推送服务端决策不在此模块**。

| 通知政策 | 确认的实际规则与锚点 |
|---|---|
| 时效型安静时段 | <07:00 改当日07:00；严格 >22:00 改次日07:00；恰好22:00保持原时间。`util/LocalPushUtil.lua:84` |
| 普通受限型 | 每自然日排序 priority 越小越优先；上午08:00最多一条、晚上20:30最多一条，离现在≤1h 不排；按 groupLimit 1/2/3 限双时段/仅上午/仅晚间。`LocalPushManager.lua:261` |
| 时效型去重 | 按自然日+groupKey（有 key 时）或 type 去重；默认每组合保留优先最高一条。NO_LIMIT_RULE 两个豁免表实际为空。`LocalPushManager.lua:314`，`config/LocalPushConst.lua:43` |
| 文案分桶 | uid%100，匹配配置 uidTail1..4（00–25、26–50、51–75、76–99）；这是稳定尾号文案版本，函数虽叫 random 并非随机分配。`util/LocalPushUtil.lua:3`、`:27` |
| 本地配置 dailyLimit | 包内列出，72 条多数=10，type20=2；在此 Lua Manager 调度路径未见读取 dailyLimit，**不据配置列名断言实际日上限已落实**；SDK/原生层可能另消费，未验证。 |

具体投放案例：

1. **新关发布**：通知 type17，只有 `userTopLevel >= localConfigTopLevel−5` 且存在当前/下一倒计时区域，endTime>now，才在倒计时结束（扣 UTC diff）添加；入口为 `amf/middleware/data/userdata/levelarea/localpush/LocalPush.lua:11`，`AMFLevelAreaManager.lua:174` 调用。并非只等满级标志，也不是向所有玩家广播。
2. **流失召回**：type30/31/32，分别今日零点+7/8/9天，groupKey=userLose；每次先 remove 再重新排。`amf/middleware/data/userdata/user/localpush/LocalPush.lua:16`。这条是客户端预排定时召回，不能当成云端流失风险模型结果。
3. **精力回满**：enablePush=true 且 computeFullEnergyTime()>0，在 now+offset 排 type20；`amf/feature/mainscene/module/assetsbar/energy/localpush/LocalPush.lua:13`。
4. **超级魔力鸟**：请求排 now+1h、now+24h 的未结束关卡保鸟提醒，type54、groupKey=suppermagicbird；`amf/feature/localactivity/supermagicbird/localpush/LocalPush.lua:13`。最终仍受公共时段及同日组去重规则，因此两次请求不保证两次送达。
5. **幸运快递**：登录时间+23.5h，从4条文案里 math.random 选一条，type21/groupKey=lucky_delivery；`amf/feature/localactivity/luckydelivery/localpush/LocalPush.lua:30`。这条文案才是显式随机，与 UID 稳定桶不同。

通知配置 72 行导出在 `notification_config.csv`，含完整四版 title/text、uidTail、activate、pusher、priority、group、dailyLimit，适合进一步比较文案和触达政策。OS 权限/厂商限制/SDK排程成功、用户实际点击和送达率未取证，静态添加意图不等于用户已收到。

## 7. 已交付数据与复查

- `tag_config.csv`：22 条标签寿命与关卡跨度配置。
- `dp_tag_config.csv`：114 条离线/平台规则标签映射与 fallback。
- `notification_config.csv`：72 条完整通知配置及文案版本。
- `popup_checkpoint_caps.csv`：133 条框架显式日限次，包含包内注释但不将注释当运行证明。
- `protocol_fields.csv`：57 条用户/付费/社交/关卡/难度/DP/弹窗相关 protobuf 字段编号和类型。
- `numeric_policies.csv`：23 条人工核对的阈值、频率和适用条件。
- `server_consumers.csv`：17 条在线字段到客户端消费者的映射，明确本次未获得线上值。
- `source_provenance.json`：本文 scope 的解密逻辑路径、SHA-256 与行数。
- `summary.json`：提取计数。

可复现命令：`python3 scripts/delivery_segments_extract.py`（在研究目录运行）。脚本只读解密结果，不执行游戏 Lua、不访问业务服务。来源逻辑路径和 line 列可直接定位数据行；代码细则另以上文锚点复查。

后续若要从“代码能力”升级为“当前线上真实策略”，最有价值的数据是：同账号登录/前台/出关 `getActInfos2024`、`aiAutoPopInfo`、popupInfoV2SceneMap、维护配置快照，连同最终曝光及被挡原因日志。没有这些，不报告虚构的当前分桶比例、真实玩家标签、当前活动分数或模型增益。
