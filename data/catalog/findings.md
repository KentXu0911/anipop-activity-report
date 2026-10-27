# 活动目录、注册与配置覆盖审计

取证范围：当前APK解码的11,871个Lua文件，APK SHA-256 `ff321d4a200d6d98107e6c33fa0951f29810cafd88689b46bbec480e6a8d7421`。本目录脚本对全部源文件SHA-256与decoded-index逐个核验，11,871/11,871相同；父任务另从原APK独立解密核验全部字节。未登录、未请求在线活动名单。

## 一、目录数、注册数、线上活动数不是同一个东西

- `amf/feature/localactivity/`有60个目录，其中58个目录在Spring DI直接声明，主界面LocalActivityDI中56个、启动阶段另2个。LocalActivityDI另含`PromoteFullPackageManager`，它位于localactivity以外。因此该文件共57个bean，当前清单61个模块。
- `returngift`没有Spring DI，但由礼包ModuleConfig的四个场景模块接入，且active=true，不能判成死代码。`processgiftautopopup`能确认其RewardFlyHelper被多个活动使用，尚未确认ProcessGiftMgr自己的初始化入口。
- UBF枚举104条，原生App分支明确注册46条，小游戏分支41条。枚举包括历史ID与统计、氛围、关卡库等功能，不等于104个现役活动。
- 包内UBF配置53个Lua文件，49个不同数字ID，另有global/global_mini及平台/框架副本。App与小游戏注册ID均能找到相应包内配置，零缺失。5071“去雨林！朋友”、8015“萌宠周赛”虽有配置，但不在两份当前NeedRegister列表内；只能证明未在此UBF入口登记，不能推导整个游戏彻底取消这两个活动。
- 包内**已注册也不保证开启**：8079超鸟送礼的Manager:isEnabledInLevel在非开发模式直接返回false。开发模式也要debugEnabled=true、未达到每日通过次数限制、超鸟已开启且hasSuperPower。

证据：`amf/script/spring/ioc/animal/mainscene/MainSceneDIConfig.lua:19`；`amf/script/spring/ioc/animal/startup/config/ModuleDI.lua:207`、`LoginDI.lua:177`；`amf/feature/giftpackage/config/ModuleConfig.lua:176`；`ubf/UBFActivity/UBFActRegister.lua:118`、`:164`；`amf/feature/localactivity/supermagicbirdgift/SuperMagicBirdGiftManager.lua:200`。

## 二、配置来自哪里

| 配置层 | 客户端可直接取得 | 本次不能直接取得 |
|---|---|---|
| 身份与接线 | 活动ID、中文显示名、配置源路径、bean/插件、弹窗checkpoint引用 | 是否对当前账号开启 |
| 本地活动常量 | 包内门槛、固定文本、枚举、资源、弹窗规则参数 | 不能把固定展示奖励图标当服务端实际发奖 |
| UBF关内配置 | 53文件的关内掉落/展示/收集物/开启条件树引用等 | 需要的动态状态、线上活动资源是否就绪 |
| 活动维护名单 | ActivityConfigLoader的HTTP请求与XML解析：name、uid、bundleVersion；活动列表与rootUrl的消费代码 | 当前活动名单、实际日期、每账号分流名单 |
| 动态活动包 | 本地Const中如`pengpeng2026/Config.lua`、`merge2025/Config.lua`的定位字符串 | 本APK未附该动态包时，不能取得该包完整内容 |
| 活动接口配置 | fromServer/config/actInfo的消费者和协议字段 | 在线奖励表、商品价格、强弹条件表与实际开关值 |

生产下载见`amf/middleware/activity/loader/ActivityConfigLoader.lua:6`、`:37`、`:56`。`debug/activity_config_local.lua`唯一的gladiator日期样例整块被注释，执行结果为空表。不能使用样例中的时间段填充线上活动日历。

### 已核对消费方向的具体例子

| 活动 | 包内可证实参数 | 远端或待核对部分 |
|---|---|---|
| 飞碟弹弹乐8078 | MainPanel.MIN_LAUNCH_OPPORTUNITY=20；Manager:checkCanPopMainPanelStage4读当前launchOpportunity，至少20才通过该业务条件。引流面板阈值10、主面板重叠后抑制参数3另有Helper消费 | Model:fromServer写入config.config，字符串会反序列化。不能拿本地固定奖励图标ID推算在线奖励数额 |
| 完美演奏家4062 | openPassLevel=210；isLimitEnabled读getTopPassedLevel，小于210拒绝；通过后本地缓存leveIsEnabled | 仍须actInfo等后续门槛，210不是无条件开活动 |
| 瀑布礼包3076 | getAutoPopoutConfig将strongPushCdH映射为小时CD，缺省999；Manager比较now-lastPopTime < CD*3600时拒绝 | strongPushCdH、strongPushConditionIds、strongPushTable来自serverVersionedConfig.config。999是缺失兜底，不是线上统一41.6天CD |
| 超鸟送礼8079 | TestConfig baseCap=6、dailyPassLevelLimit=5，分群收集规则也可读 | 非开发模式明确关闭，不能将这些测试值列为正式策略 |

具体源：`pengpeng2026/config/PengPeng2026Config.lua:23`、`:32`；`pengpeng2026/PengPeng2026Manager.lua:166`；`pengpeng2026/module/PengPeng2026AttractPanelHelper.lua:54`、`:78`；`pengpeng2026/model/PengPeng2026Model.lua:85`；`musicmaster/config/MusicMasterConfig.lua:10`、`musicmaster/MusicMasterManager.lua:289`；`waterfallgift/model/WaterfallGiftModel.lua:57`、`:144`与`waterfallgift/WaterfallGiftManager.lua:528`。上述相对模块路径前缀均为`amf/feature/localactivity/`。

### 名称与ID的注意事项

中文显示名优先保留实际常量，不从英文目录猜译。UBF枚举注释与当前显示文本可能不同：battlepass显示“缤纷回馈”，UBF注释为“大滕蔓通行证”；exploremapgame显示“秋日拾忆”，UBF注释为“丛林寻宝”。同ID3076有waterfallgift和waterfallgiftprogress两个模块；teamcamping本地actId为5321，不能按英文目录名误配为UBF旧kTeamCamping=5071。

## 三、完整本地模块清单

“弹窗证据行”是词法索引数量，包含配置、checkpoint、stage、register引用，不是弹窗数或已审完分支数。具体启动和触发规则需连同函数调用链审计。

| 模块 | 代码声明ID | 中文常量 | 接线状态 | 本地配置文件数 | 弹窗证据行 |
|---|---|---|---|---:|---:|
| addfivestepupgrade | 5311 | 未提取到中文常量 | Spring声明 | 1 | 4 |
| aipopup | 未提取到字面ID | 未提取到中文常量 | Spring声明 | 1 | 2 |
| battlepass | 3081 | 缤纷回馈 | Spring声明 | 1 | 7 |
| biggiveaway | 3078 | 未提取到中文常量 | Spring声明 | 1 | 6 |
| bigvineskinact | 9504 | 藤蔓焕新 | Spring声明 | 1 | 14 |
| block | 6076 | 方块消消 | Spring声明 | 1 | 4 |
| canteen | 3068 | 厨神食堂 | Spring声明 | 1 | 2 |
| climbtower | 5073 | 冲顶夺宝 | Spring声明 | 1 | 6 |
| cloudmusictask | 未提取到字面ID | 未提取到中文常量 | Spring声明 | 1 | 1 |
| coinpromotions | 5066 | 金币狂欢日 | Spring声明 | 1 | 3 |
| collectcard | 9087 | 开心卡册 | Spring声明 | 12 | 47 |
| dailygift | 5320 | 未提取到中文常量 | Spring声明 | 1 | 1 |
| dailylevel | 8077 | 未提取到中文常量 | Spring声明 | 4 | 10 |
| douyindown | 21001 | 未提取到中文常量 | Spring声明 | 1 | 0 |
| eliminatefestival2026comic | 未提取到字面ID | 未提取到中文常量 | Spring声明 | 1 | 3 |
| energyactv2 | 7026 | 未提取到中文常量 | Spring声明 | 2 | 1 |
| energyfund | 8072 | 未提取到中文常量 | Spring声明 | 1 | 2 |
| exploremapgame | 8075 | 秋日拾忆 | Spring声明 | 2 | 9 |
| fishingwinner | 6077 | 钓鱼大赢家 | Spring声明 | 1 | 7 |
| fixbirdnest | 5053 | 未提取到中文常量 | Spring声明 | 1 | 2 |
| gemmining | 6057 | 挖宝石! | Spring声明 | 1 | 12 |
| gladiator | 9079 | 疯狂对决 | Spring声明 | 1 | 4 |
| happydelivery | 4101 | 开心快递 | Spring声明 | 1 | 3 |
| happymatch | 6079 | 开心对对碰 | Spring声明 | 1 | 5 |
| layeredtilematch | 4105 | 开心农家乐 | Spring声明 | 1 | 6 |
| luckybagparty | 6038 | 福袋派对 | Spring声明 | 1 | 1 |
| luckydelivery | 4104 | 未提取到中文常量 | Spring声明 | 1 | 7 |
| luckydeliverypass | 9503 | 未提取到中文常量 | Spring声明 | 1 | 5 |
| luckyfarmstar | 9505 | 未提取到中文常量 | Spring声明 | 1 | 4 |
| magicrush | 9084 | 魔力冲冲冲 | Spring声明 | 1 | 4 |
| merge | 6074 | 美味合合 | Spring声明 | 4 | 14 |
| mergeevolution | 3077 | 春田合合 | Spring声明 | 1 | 5 |
| midautumnnationalday2026 | 4107 | 双节签到 | Spring声明 | 1 | 3 |
| musicmaster | 4062 | 完美演奏家 | Spring声明 | 4 | 8 |
| musicmerge | 3080 | 妙音合合 | Spring声明 | 1 | 2 |
| newbiegiftoptimize | 4056 | 未提取到中文常量 | Spring声明 | 2 | 7 |
| pengpeng2026 | 8078 | 飞碟弹弹乐 | Spring声明 | 2 | 7 |
| pet | 22009 | 小小萌伴 | Spring声明 | 3 | 4 |
| processgiftautopopup | 未提取到字面ID | 未提取到中文常量 | 仅目录/其他调用 | 0 | 0 |
| promotelow | 5061,5067 | 未提取到中文常量 | Spring声明 | 2 | 3 |
| recruithighpay | 6062 | 未提取到中文常量 | Spring声明 | 1 | 3 |
| returngift | 未提取到字面ID | 未提取到中文常量 | 礼包模块注册 | 1 | 5 |
| sh01 | 6073 | 假日乐消消 | Spring声明 | 1 | 7 |
| shopreward | 8076 | 回馈狂欢商店促销券 | Spring声明 | 2 | 7 |
| sprintgiftpackage | 8074 | 冲关回馈 | Spring声明 | 1 | 4 |
| sprintrealprize | 4102 | 未提取到中文常量 | Spring声明 | 2 | 1 |
| sprintrealprize2 | 4103 | 未提取到中文常量 | Spring声明 | 2 | 1 |
| stellarconvergence | 6051 | 未提取到中文常量 | Spring声明 | 11 | 2 |
| superbirdshare | 8080 | 鸟卡接力 | Spring声明 | 1 | 6 |
| supermagicbird | 8068 | 超级魔力鸟 | Spring声明 | 2 | 8 |
| supermagicbirdgift | 未提取到字面ID | 未提取到中文常量 | Spring声明 | 0 | 0 |
| supermagicbirdmoney2025 | 8069 | 未提取到中文常量 | Spring声明 | 1 | 1 |
| supermagicbirdrealgift | 4106 | 未提取到中文常量 | Spring声明 | 1 | 3 |
| teamcamping | 5321 | 未提取到中文常量 | Spring声明 | 2 | 3 |
| underthesin | 22003 | 拾光成歌 | Spring声明 | 1 | 5 |
| waterfallgift | 3076 | 未提取到中文常量 | Spring声明 | 3 | 9 |
| waterfallgiftprogress | 3076 | 未提取到中文常量 | Spring声明 | 3 | 9 |
| weektask | 3079 | 开心任务站 | Spring声明 | 2 | 8 |
| winrepeatrank | 4046 | 连胜排行 | Spring声明 | 1 | 7 |
| yybwashingpackage | 9076 | 未提取到中文常量 | Spring声明 | 1 | 1 |
| promotefullpackage | 未提取到字面ID | 未提取到中文常量 | Spring声明 | 0 | 0 |

## 四、原生App的46条UBF注册

以下为关内系统登记，不等于46个独立营销活动。平台分支、配置路径和原始中文名均在机器清单中保留。

| ID | 枚举注释名称 | 配置中文名 | 源登记行 |
|---|---|---|---:|
| 3052 | 晋级赛22 | 闯关晋级赛 | 165 |
| 10168 | 紫咪回流 | 紫咪回流 | 166 |
| 4042 | 拯救么么狐(连胜目标) | 拯救么么狐 | 167 |
| 6038 | 福袋派对 | 福袋派对 | 168 |
| 5305 | 补星权杖 | 补星权杖 | 169 |
| 5301 | 彩星竞赛 | 彩星竞赛 | 170 |
| 5312 | 满星关卡库 | 满星关卡库 | 171 |
| 9064 | 连胜加分瓶 | 连胜加分瓶 | 172 |
| 8055 | 彩星连胜 | 彩星连胜 | 173 |
| 5053 | 修鸟窝 | 修鸟窝 | 174 |
| 5311 | 长尾步数升级 | 长尾步数升级 | 175 |
| 5315 | 连胜步数升级 | 连胜步数升级 | 176 |
| 4046 | 连胜排行榜 | 连胜排行榜 | 177 |
| 5065 | 促满级补星 | 促满级补星 | 178 |
| 6057 | 轻策略挖宝活动 | 挖宝石! | 179 |
| 4055 | 爆破冠军赛 | 爆破冠军赛 | 180 |
| 10175 | 促满级补星瓶 | 促满级补星加分瓶 | 181 |
| 10178 | 游戏行为统计打点 | 游戏统计打点 | 182 |
| 10179 | 头部冲新关氛围设计 | 头部冲新关氛围 | 183 |
| 5066 | 促风车币消耗活动 | 金币狂欢日 | 184 |
| 8068 | 2024超鸟活动 | 超级魔力鸟 | 185 |
| 9088 | 回流特效助力 | 回流特效助力 | 186 |
| 22009 | 宠物模块 | 宠物模块 | 187 |
| 6074 | 美味合合 | 美味合合 | 188 |
| 5321 | 团建活动 | 露营吧！朋友 | 189 |
| 6051 | 星光之域 | 星光之域 | 190 |
| 9084 | 魔力冲冲冲(新版1v1) | 魔力冲冲冲 | 191 |
| 6076 | 方块消消 | 方块消消 | 192 |
| 4062 | 完美演奏家-强连胜活动 | 完美演奏家 | 193 |
| 6077 | 钓鱼大赢家 | 钓鱼大赢家 | 194 |
| 8074 | 冲关回馈礼包 | 冲关回馈礼包 | 195 |
| 3077 | 春田合合 | 迷你合合 | 196 |
| 3080 | 妙音合合 | 妙音合合 | 197 |
| 3078 | 礼物大放送 | 礼物大放送 | 198 |
| 3079 | 周任务 | 开心任务站 | 199 |
| 8075 | 丛林寻宝 | 秋日拾忆 | 200 |
| 8078 | 飞碟弹弹乐 | 飞碟弹弹乐 | 201 |
| 4102 | 过关得实物 | 过关得实物 | 202 |
| 4103 | 过关得雪糕 | 过关得雪糕 | 203 |
| 4105 | 开心农家乐 | 开心农家乐 | 204 |
| 9502 | 回流加步数Buff | 回流加步buff | 205 |
| 9504 | 藤蔓焕新 | 藤蔓焕新 | 206 |
| 3081 | 大滕蔓通行证 | 大滕蔓通行证 | 207 |
| 3083 | 自建赛 | 自建赛 | 208 |
| 8077 | 每日夺宝副本 | 每日夺宝 | 209 |
| 8079 | 超鸟送礼 | 超鸟送礼 | 210 |

## 五、可复现与边界

运行 `python3 analysis/activity-push-2026-10-21/catalog/build_catalog.py`（研究目录下）。只读源文件，不执行游戏Lua，不发业务请求。

- catalog.json/csv：61模块，身份、名称、DI证据、全部本地配置路径、弹窗和外部引用证据。JSON另有动态配置读写线索与UBF候选关联。
- registrations.csv：59个Spring bean（58个localactivity加1个外部promotefullpackage）。这是声明证据，运行初始化仍由Spring/宿主生命周期控制。
- ubf-register.csv：App46 + Mini41条；ubf-enum.csv：104个枚举；ubf-configs.csv：53配置完整路径、顶层字段、名称、SHA。
- config-literals.csv：3,248条包内字面常量，含类型、原文、源行；仅为字段索引，包含美术/坐标/枚举等，不应作为3,248条运营策略。动态表达式、内联多字段表、表构建与函数生成的值不保证由该词法脚本完整列出；配置原文件路径全部保留。
- popup-evidence.csv：325条候选证据行。dynamic-config-evidence.csv记录各模块配置/状态接口线索；其中fromServer也可能只有状态，不能自动当作配置来源证明。
- source-hashes.json：全部11,871源文件哈希；summary.json：覆盖计数。

**覆盖结论仅限目录、声明注册、UBF配置存在性与上述手工核对案例。没有声称所有业务函数语义已逐分支审完。**尤其不能由空字段推断没有远端活动；动态资源下载可使在线活动集合超过本地目录，历史目录也可能不再开启。没有在线响应，不给出当前活动日历、奖品金额和每账号真实名单。
