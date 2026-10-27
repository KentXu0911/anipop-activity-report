# 活动逐项推送审计（独立 lane）

扫描 registerPopup/addPopupConfig 调用、插件声明；153条词法记录，42个localactivity模块。现42模块均核注册及直接条件/helper，另核MeMeFox与集卡三选一独立条目，共44条。不是42个模块全部传递依赖均闭合；具体缺口逐项保留。

注册不代表活动上线；客户端条件、框架上限、服务端当前配置必须同时成立。框架caps数字1/2是每日上限，-1不做这层每日限制，仍有业务状态限制。未配置默认值应再结合框架实现。

## 关键反例

- MusicMaster场景3直接false。Gladiator场景4旧头部过滤调用已注释。
- PengPeng实际主面板20、引流10；旧注释50不适用。
- UnderTheSin框架-1，业务主面板1/日与引流3/日独立，不能写总3。
- 集卡三选一阈值来自meta；helper默认30/5/3会被调用者or 0绕过。
- 瀑布进度礼包领奖期场景2/4直接允许，不套普通CD；3阻止。
- 超鸟hasReviveCard判断今日领取记录，背包数量由另一个函数判断。

## 完美演奏家

有效主面板强弹为场景4；注册的场景3返回false。

- 条件：活动有效且资源齐备；头部新关保护过滤；本期未进入且参与度降频时阻止；未置kPopPrePanel才可弹。局内结算另有可领奖路径。
- 次数：kPopPrePanel按期引导标记；场景3 checkPopOnStage3直接false，不能把注册当有效。
- 写入：doPopStage4先setGuideIndex后开面板。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/musicmaster/MusicMasterManager.lua:131`；`amf/feature/localactivity/musicmaster/module/MusicMasterPopMudule.lua:43`；`amf/feature/localactivity/musicmaster/module/MusicMasterPopMudule.lua:191`；`amf/feature/localactivity/musicmaster/config/MusicMasterConfig.lua:15`

框架上限：MUSIC_MASTER=-1（AutoPopupLimit.lua:65）

## 方块消消

场景4首次主面板与收集引流共用检测点。

- 条件：活动支持且有效、不被参与度降频；主面板未展示或收集引流达标。引流首次持有>=30；后两次需持有>=30且上次后收集>=20。
- 次数：引流计数0/1/2可通过，共最多3次；passDayRefreshData清零。主面板按本地日期标记。
- 写入：主面板先置MainPanelShow；引流弹出后yinliuCount=0、yinliuTimes+1。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/block/BlockManager.lua:100`；`amf/feature/localactivity/block/BlockManager.lua:431`；`amf/feature/localactivity/block/model/BlockModel.lua:289`；`amf/feature/localactivity/block/const/BlockConst.lua:5`

框架上限：BLOCK_STAGE4_POP=-1（AutoPopupLimit.lua:126）

## 钓鱼大赢家

场景4主面板和引流各有一个检测点。

- 条件：topLevel>=211；活动支持；参与度降频过滤。引流需局内活动有效、当前parse!=3、普通钩>=50；当日首次之外还要求新增收集>=20。
- 次数：引流dailyCount<3；主面板本业务check没有日次条件，需叠加框架。
- 写入：引流展示后function4DailyCount+1，lastCollectionAddNum=0。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/fishingwinner/FishingWinnerManager.lua:13`；`amf/feature/localactivity/fishingwinner/FishingWinnerManager.lua:488`；`amf/feature/localactivity/fishingwinner/FishingWinnerManager.lua:560`

框架上限：FISHING_WINNER_MAIN_STAGE4=1（AutoPopupLimit.lua:134）；FISHING_WINNER_STAGE4_POP=-1（AutoPopupLimit.lua:133）

## 疯狂对决

场景4邀请参加对决。

- 条件：活动支持、有效、正式期、状态kPrepare；当日未打开主面板/介绍面板；参与度降频过滤。
- 次数：OPEN_MAIN_PANEL_TODAY和OPEN_JOIN_PANEL_TODAY拦截；checkCanOpenJoinPanel中的ignoreTopPlayer调用已注释，不可说此处生效。
- 写入：主面板打开写OPEN_MAIN_PANEL_TODAY；openJoinPanel展示后写OPEN_JOIN_PANEL_TODAY，needTime=true。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/gladiator/GladiatorMgr.lua:821`；`amf/feature/localactivity/gladiator/GladiatorMgr.lua:1056`；`amf/feature/localactivity/gladiator/GladiatorMgr.lua:20`

框架上限：GLADIATOR_STAGE4_POP=-1（AutoPopupLimit.lua:132）

## 魔力冲冲冲

场景4规则分R1、R2、R3，频率不相同。

- 条件：支持+有效+topLevel>=101。magic_1v1_v2 ON2选择R3；否则magic_1v1_pop ON2选择R1，其余R2。R1/R2需prepare且不被参与度降频；R3当日未弹时可过，弹过只允许待结算且胜利。
- 次数：R1每日一次；R2业务不限制次数（仍受框架限制）；R3首次与胜利结算分开。
- 写入：R1在执行pop时先写dailyPopupFlag；R3标记还需顺开面板路径检查。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/magicrush/MagicRushManager.lua:82`；`amf/feature/localactivity/magicrush/const/MagicRushConst.lua:8`

框架上限：MAGIC_RUSH_STAGE4_POP=-1（AutoPopupLimit.lua:140）

## 连胜排行

场景3参与/领奖，场景4日主面板或领奖。

- 条件：topLevel>=75、活动支持有效；距最高已开放关<=30且新关开放后0至<4小时阻止。场景3连胜>0且相应进赛引导未展示，或有小组/其他奖。低价值赛事、本期未参加受参与度降频。
- 次数：场景4普通主面板当日一次；领奖可独立命中OR；场景3不同赛事分别置引导。
- 写入：popStage3先置相应入赛guide，再开主面板。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/winrepeatrank/WinRepeatRankManager.lua:395`；`amf/feature/localactivity/winrepeatrank/WinRepeatRankManager.lua:663`；`amf/feature/localactivity/winrepeatrank/WinRepeatRankManager.lua:705`；`amf/feature/localactivity/winrepeatrank/WinRepeatRankManager.lua:738`

框架上限：WIN_REPEAT_RANK_STAGE3_POP=-1（AutoPopupLimit.lua:130）；WIN_REPEAT_RANK_STAGE4_POP=-1（AutoPopupLimit.lua:131）

## 缤纷回馈

首次触发、未买全完成、已买全完成、领奖结算4条。

- 条件：有效；未买/已买分支按VIP；完成判定value>=配置battlePass各档need最大值，配置空则不通过；结算需领奖期且isEnabled2。
- 次数：每条getPermanentShowNum(checkpoint)<1；不要自行改写为每日一次或每期一次。
- 写入：每条creator先sendPermanentData，再开活动。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/battlepass/BattlePassManager.lua:258`；`amf/feature/localactivity/battlepass/BattlePassManager.lua:333`；`amf/feature/localactivity/battlepass/const/BattlePassConst.lua:3`

框架上限：BATTLE_PASS_BUY_COMPLETE=-1（AutoPopupLimit.lua:99）；BATTLE_PASS_REWARD_SETTLE=-1（AutoPopupLimit.lua:100）；BATTLE_PASS_TRIGGER=-1（AutoPopupLimit.lua:97）；BATTLE_PASS_UNBUY_COMPLETE=-1（AutoPopupLimit.lua:98）

## 冲顶夺宝

场景2/4正式期和领奖期分别触发。

- 条件：活动有效、票券>0；正式期/领奖期对应分支。
- 次数：periodId拼接两套跨日持久key，每期正式期和领奖期各1次。
- 写入：creator按当前时间段先置对应key=1。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/climbtower/ClimbTowerManager.lua:273`；`amf/feature/localactivity/climbtower/const/ClimbTowerConst.lua:5`

框架上限：CLIMB_TOWER_TRIGGER=-1（AutoPopupLimit.lua:80）

## 集卡三选一礼包

场景2/4用活动包给出的不同条件列表；任一满足即可。

- 条件：支持+活动包getStrongPushSupportFailReason无错误+metaList非空+24小时CD。conditionId 1风车币<值，2非无限体力且体力<值，3进入即满足，4连败>=值。值实际来自meta.conditionValue。
- 次数：24小时滚动CD；按活动id+本期起止时间隔离。helper默认30/5/3不能当线上阈值：调用者tonumber(conditionValue) or 0，缺值传0而非nil。
- 写入：进入pop前写时间；失败/中途退出也计CD。结算胜清零/其他分支失败数+1。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/collectcard/ThreeForOneGiftModule.lua:26`；`amf/feature/localactivity/collectcard/ThreeForOneGiftModule.lua:144`；`amf/feature/localactivity/collectcard/ThreeForOneGiftModule.lua:165`；`amf/feature/localactivity/collectcard/ThreeForOneGiftModule.lua:209`

## ReturnGift回归礼包

场景2/4有packageData且未弹过时入队；礼包数据到达可补触发。

- 条件：STORE类型排除；领奖阶段rewardEndTime<=0或>当前时间。启用/商品来源依赖Mixin和返回数据。
- 次数：本地key为Buy/Reward+packageType，所读函数不含日期/期次；不能声称每日一次。
- 写入：tryAutoPopup creator先_markAutoPopuped再创建面板；doCreateGiftView也标记。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/returngift/giftmodule/ReturnGiftModule_Vine.lua:231`；`amf/feature/localactivity/returngift/giftmodule/ReturnGiftModule_Vine.lua:250`；`amf/feature/localactivity/returngift/giftmodule/ReturnGiftModule_Vine.lua:287`

## WaterfallGift礼包

场景2数据补到、场景3、场景4按配置条件触发。

- 条件：活动数据有效且hasGifts；距上次弹出>=autoPopoutCd*3600；conditionList查conditionMetaList，同sceneId条件函数返回非false就通过。场景2补偿要求主场景且首次入主场景后<3000毫秒（或未记录时间）。 主场景4普通强弹不满足时可走抖音offer：Windows直接允许；Android需数据营销开关且支付方式含DOUYIN_ANDROID；PAY_END_4引导未有，异步查询限1.5秒。不是所有人都有抖音营销。
- 次数：CD由配置给出，不固定24小时；源含时间<1769356740时强插条件3的历史兼容分支。
- 写入：doAutoPopout成功pullOnce后先setLastPopoutTime；model保存TimeKit:timeInSec，普通CD据此计算。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/waterfallgift/WaterfallGiftManager.lua:528`；`amf/feature/localactivity/waterfallgift/WaterfallGiftManager.lua:575`；`amf/feature/localactivity/waterfallgift/WaterfallGiftManager.lua:618`；`amf/feature/localactivity/waterfallgift/WaterfallGiftManager.lua:709`；`amf/feature/localactivity/waterfallgift/WaterfallGiftManager.lua:847`；`amf/feature/localactivity/waterfallgift/model/WaterfallGiftModel.lua:144`

框架上限：WATERFALL_GIFT=-1（AutoPopupLimit.lua:46）

## ShopReward

每期首次主面板；活动正式开始24小时后另一次提醒。

- 条件：活动有效、periodId>0、商品ready；排队时和执行时都检查；首次优先。
- 次数：firstMainPopup_periodId与remindAfter24hPopup_periodId独立标记；24h从mainBeginTime算，不是上次弹窗算。
- 写入：创建面板之前markMainPopuped并flush。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/shopreward/logic/ShopRewardMainPopupLogic.lua:48`；`amf/feature/localactivity/shopreward/logic/ShopRewardMainPopupLogic.lua:58`；`amf/feature/localactivity/shopreward/logic/ShopRewardMainPopupLogic.lua:104`

框架上限：SHOP_REWARD_MAIN_POP=-1（AutoPopupLimit.lua:96）

## 秋日拾忆

场景4三种：未毕业主面板、收集引流、礼包。

- 条件：主面板有效且未毕业；引流有效且popTimes<3，首次累计收集>=50，之后剩余>=50且新增>=30。礼包细项未闭合。
- 次数：引流counter具名；具体日重置见model待进一步闭合，不只根据注释承诺每日。
- 写入：doShowYinliuStage4之后调用model:onYinliuPopout。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/exploremapgame/ExploreMapGameManager.lua:360`；`amf/feature/localactivity/exploremapgame/ExploreMapGameManager.lua:423`；`amf/feature/localactivity/exploremapgame/ExploreMapGameManager.lua:490`

框架上限：EXPLORE_MAP_GAME_DAILY_GIFT_POP=-1（AutoPopupLimit.lua:79）；EXPLORE_MAP_GAME_YINLIU_STAGE4_POP=-1（AutoPopupLimit.lua:78）

## DailyLevel

场景2首次引导；场景4消息/奖励。

- 条件：活动有效且网络有效；场景2periodId非0且未有STAGE2_MAIN_PANEL guide；场景4领奖期hasReward，正式期msgNum>0。
- 次数：业务check未直接给统一次数；依赖guide/框架；开面板回调还会重检。
- 写入：_markStage4PopupRecord在首次checkpoint计数<=0时sendDailyData；实际调用位置需联查。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/dailylevel/DailyLevelMgr.lua:442`；`amf/feature/localactivity/dailylevel/DailyLevelMgr.lua:513`；`amf/feature/localactivity/dailylevel/DailyLevelMgr.lua:521`

框架上限：DAILY_LEVEL_STAGE2=-1（AutoPopupLimit.lua:119）；DAILY_LEVEL_STAGE4=1（AutoPopupLimit.lua:121）

## 2026消除节联动漫画

场景2/4共用一次展示标记。

- 条件：通过关卡>=30；本地时间2026-07-13 10:00:00至2026-08-08 23:59:59（os.time无显式时区）；未展示；isIgnoredForTopLevelPlayer实际仅isInNewLevelTime检查，topLevel/userState过滤已注释；所以当前新关时间全体被该predicate挡。
- 次数：共用GuideFlag；DEBUG_FORCE_STAGE2_POPUP虽true，但isDebugForceStage2Popup实际直接false。
- 写入：面板打开前_markDisplayed，崩溃也计。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/eliminatefestival2026comic/EliminateFestival2026ComicManager.lua:67`；`amf/feature/localactivity/eliminatefestival2026comic/EliminateFestival2026ComicManager.lua:100`；`amf/feature/localactivity/eliminatefestival2026comic/config/EliminateFestival2026ComicMeta.lua:6`

框架上限：ELIMINATE_FESTIVAL_2026_COMIC_STAGE2=-1（AutoPopupLimit.lua:110）；ELIMINATE_FESTIVAL_2026_COMIC_STAGE4=-1（AutoPopupLimit.lua:111）

## MeMeFox（名称不在此 lane 推断）

注册场景3和局内流程共用stage3OrInLevelCanPop，但主场景对部分状态会提前false。

- 条件：活动有效、主面板不存在、当前时间允许、网络有效、dontPop不拦截；本期未进入且参与度降频则false。失败状态需淘汰列表非空，并按是否胜利/特殊失败分支；主场景除此之外提前false。局内等待入组：本局胜利、正式期、roundInit同日；初次可弹；后续超鸟激活且未超鸟弹且距首次关卡计数>2。运行中胜利且淘汰列表非空，或成功未领奖且本局胜利，可弹。
- 次数：不是简单每天N次；firstEnterGroupPopFlag、superBirdPopFlag、状态与进度控制。活跃tag3且1di_Fox_2026 ON2且运行未完成可阻止；另有openStrongBombStrategy+距顶关>60+无可得帮助奖+活跃tag3组合。
- 写入：cleanPopReason及具体原因标记；全部状态写入未闭合。
- 范围：已核注册及关键predicate；不是整个MeMeFox状态机审计
- 证据：`amf/feature/winningstreak/module/memefox/MeMeFoxManager.lua:765`；`amf/feature/winningstreak/module/memefox/MeMeFoxManager.lua:870`

## 加五步升级领奖

场景3主线胜利后可补弹。

- 条件：levelID存在且isWin；主线；不在头部新关保护；本地currBuffData存在且领奖有效；非长离线；_wantPopBuffRewardPanel可领奖；manager还需panelParams。
- 次数：框架ADD_FIVE_STEP=-1；具体奖励是否已领依赖buff本地数据，不是固定日次数。
- 写入：doAddFiveStepPopup仅封装领奖面板；奖励消费标记仍在BuffUtil/面板链。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/addfivestepupgrade/AddFiveUpgradeManager.lua:1445`；`amf/feature/localactivity/addfivestepupgrade/AddFiveUpgradeManager.lua:1481`；`ubf/UBFGamePlayScene/logics/sceneModules/addStepPanel/fiveStepUpgrade/UBFAddFiveUpgradeBuffUtil.lua:791`

框架上限：ADD_FIVE_STEP=-1（AutoPopupLimit.lua:44）

## BigGiveAway

场景4打开活动。

- 条件：isActivitySupported(actId)且isEnabled。
- 次数：BIG_GIVEAWAY_STAGE4_POP框架1/日。
- 写入：本业务pop无另写曝光标记，交框架计数。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/biggiveaway/BigGiveAwayManager.lua:12`；`amf/feature/localactivity/biggiveaway/BigGiveAwayManager.lua:34`

框架上限：BIG_GIVEAWAY_STAGE4_POP=1（AutoPopupLimit.lua:127）

## 大藤蔓皮肤活动

首次/第5、8、12天/试戴到期/领奖/拥有皮肤引导5类。

- 条件：首次check只检有效且guide103未有，不能凭注释断言严格第1天；定时天按mainBeginTime自然日差+1，命中5/8/12；到期需trialState.expireTime<=当前毫秒；卡提示实际checkCanReward即maxCanRewardTaskId>0；拥有引导要求非默认皮肤。
- 次数：首次、指定日框架1/日；到期和领奖框架-1，业务状态控制；拥有引导PermanentShowNum<=0。
- 写入：到期面板关闭处理恢复默认并clearTrialUsingSkinState；拥有引导成功sendPermanentData；首次guide103实际写端未在本lane闭合。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/bigvineskinact/BigVineSkinActManager.lua:145`；`amf/feature/localactivity/bigvineskinact/BigVineSkinActManager.lua:666`；`amf/feature/localactivity/bigvineskinact/BigVineSkinActManager.lua:433`；`amf/feature/localactivity/bigvineskinact/BigVineSkinActManager.lua:1406`；`amf/feature/localactivity/bigvineskinact/const/BigVineSkinActConst.lua:39`

框架上限：BIG_VINE_SKIN_OWNED_GUIDE=-1（AutoPopupLimit.lua:85）；BIG_VINE_SKIN_SCHEDULED_DAY=1（AutoPopupLimit.lua:82）；BIG_VINE_SKIN_TRIAL_CARD=-1（AutoPopupLimit.lua:84）；BIG_VINE_SKIN_TRIAL_EXPIRED=-1（AutoPopupLimit.lua:83）；BIG_VINE_SKIN_TRIGGER_DAY1=1（AutoPopupLimit.lua:81）

## CoinPromotions

服务端紧急活动事件给出资格后，在场景3补打开。

- 条件：onActReceiveEmergency必须ACT_EVENT、data.actId匹配；置canPopMainPanelInStage3。执行等0.5秒，actInfo.see且主面板尚未显示才打开。
- 次数：COIN_PROMOTIONS_POP框架-1；本地布尔一次性。
- 写入：creator先清canPopMainPanelInStage3，之后才延迟判断/展示，因此失败也消耗本次事件。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/coinpromotions/CoinPromotionsMgr.lua:603`；`amf/feature/localactivity/coinpromotions/CoinPromotionsMgr.lua:614`

框架上限：COIN_PROMOTIONS_POP=-1（AutoPopupLimit.lua:64）

## 开心卡册

补开卡包、每日礼包、接近集齐进度提示、功能解锁，以及另挂4100三选一。

- 条件：补开需数据有效且haveCardDoneReward或pendingPacksNum非0；场景2仅本次启动首次主场景。礼包需giftTime且未购买成功，首次日标记false；第二次需套餐卡能补完小卡册且首次之后计数>3。进度：每册>=7张计入近满数，且至少一册近满未满；12册档阈值3/5/7/10，15册3/5/9/13，高档优先。 解锁动画另需useUIBottomBarTest、icon有效未销毁、topLevelSupport、活动时间内且icon锁定；不等于礼包弹窗。
- 次数：礼包框架2/日且两本地日标记；进度按tier本地非日标记各次；补包由剩余包/奖状态。
- 写入：每日礼包closePanelCallback调用setAutoPopup，下载失败也调用；进度tip实际shown才记tier；礼包计数在onActPlayLevelEnd累计（不是仅胜利）。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/collectcard/CollectCardManager.lua:332`；`amf/feature/localactivity/collectcard/CollectCardManager.lua:1216`；`amf/feature/localactivity/collectcard/CollectCardManager.lua:1249`；`amf/feature/localactivity/collectcard/model/CollectCardGiftModel.lua:342`；`amf/feature/localactivity/collectcard/model/CollectCardGiftModel.lua:390`；`amf/feature/localactivity/collectcard/icon/IconModule.lua:483`

框架上限：COLLECT_CARD_DAILY_GIFT_POP=2（AutoPopupLimit.lua:89）；COLLECT_CARD_FLOW_POP_STAGE2=-1（AutoPopupLimit.lua:86）；COLLECT_CARD_FLOW_POP_STAGE4=-1（AutoPopupLimit.lua:87）；COLLECT_CARD_PROGRESS_TIP=-1（AutoPopupLimit.lua:90）；COLLECT_CARD_THREE_FOR_ONE_MAIN_POP=-1（AutoPopupLimit.lua:91）；FEATURE_UNLOCK_GUIDE=-1（AutoPopupLimit.lua:71）

## 挖宝石（框架注释命名）

场景4正式期主面板。

- 条件：isEnabled且data:isActInMain；creator再次检查。
- 次数：GEM_MINING_MAIN_POP_STAGE_4框架1/日，manualOpen=ACT_ID可同步消耗。
- 写入：业务无另行写入；交框架。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/gemmining/GemMiningManager.lua:656`；`amf/feature/localactivity/gemmining/GemMiningManager.lua:634`

框架上限：GEM_MINING_MAIN_POP_STAGE_4=1（AutoPopupLimit.lua:117）

## HappyDelivery

场景4当天未完成时提示。

- 条件：isEnabled且非isDayCompleted；未hasTipExposedToday才入队；展示资源与按钮位置仍需就绪。
- 次数：HAPPY_DELIVERY_TIP_STAGE4框架1/日；另本地曝光日标记。
- 写入：showHappyDeliveryTip资源成功路径写setTipExposedToday(true)；跨日重置进度。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/happydelivery/HappyDeliveryManager.lua:149`；`amf/feature/localactivity/happydelivery/HappyDeliveryManager.lua:189`；`amf/feature/localactivity/happydelivery/HappyDeliveryManager.lua:229`

框架上限：HAPPY_DELIVERY_TIP_STAGE4=1（AutoPopupLimit.lua:94）

## 开心对对碰

场景4仲裁顺序：主面板 > 可领奖引流2 > 抽奖引流1。

- 条件：必须主线成功过关且未被头部新关过滤；主面板当日未展示。引流需配置任务数据且当天<3；引流1需抽奖券>=10且没有可领奖，2有可领奖不要求券；距离上次topPassedLevel>=3或本次登录豁免尚未用。
- 次数：主面板日一次；两种引流共享3/日；登录豁免不是额外次数，只跳过关卡间隔。
- 写入：主面板先日标记；引流成功计数+1、记关卡ID、_yinLiuLoginExemptUsed=true。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/happymatch/HappyMatchManager.lua:42`；`amf/feature/localactivity/happymatch/HappyMatchManager.lua:789`；`amf/feature/localactivity/happymatch/HappyMatchManager.lua:963`；`amf/feature/localactivity/happymatch/HappyMatchManager.lua:1093`

## 开心农家乐（框架注释命名）

场景4主面板及流程礼包两个检测点。

- 条件：有效且正式期；礼包还需giftPart存在且battlePassValue>20（本期累计消耗挑战代币数）；礼包拉取后再校验并按商品推荐选出可售包。
- 次数：两个checkpoint各1/日；主面板manualOpen绑定actId。
- 写入：本业务主要交框架，礼包无商品/请求失败结束本次流程，未证明线上礼包价格。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/layeredtilematch/LayeredTileMatchManager.lua:428`；`amf/feature/localactivity/layeredtilematch/LayeredTileMatchManager.lua:491`；`amf/feature/localactivity/layeredtilematch/module/LayeredTileMatchGiftModule.lua:197`

框架上限：LAYERED_TILE_MATCH_DAILY_GIFT_POP=1（AutoPopupLimit.lua:118）；LAYERED_TILE_MATCH_MAIN_POP_STAGE_4=1（AutoPopupLimit.lua:116）

## 幸运快递

场景2/4日提示；场景3补领奖动画。

- 条件：日提示需资源ready、数据enabled、集卡enabled、正式期且当天未完成；场景3资源ready且hasRewardableTask或服务器canSupplementReward，并非新关开放保护时间。
- 次数：LUCKY_DELIVERY_TIP框架1/日；STAGE3=-1，由可领奖状态。
- 写入：资源加载后setTipExposedToday；补奖请求/领奖消费在相应结果链；OS通知排程不属于本表。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/luckydelivery/LuckyDeliveryManager.lua:92`；`amf/feature/localactivity/luckydelivery/LuckyDeliveryManager.lua:109`；`amf/feature/localactivity/luckydelivery/LuckyDeliveryManager.lua:327`；`amf/feature/localactivity/luckydelivery/LuckyDeliveryManager.lua:453`

框架上限：LUCKY_DELIVERY_STAGE3=-1（AutoPopupLimit.lua:109）；LUCKY_DELIVERY_TIP=1（AutoPopupLimit.lua:95）

## LuckyDeliveryPass

场景2/4补偿奖励或通行证面板。

- 条件：幸运快递资源ready；领奖期hasReward可直接命中；正式期需hasReward、有效、对应VIP/非VIP当日key未记。
- 次数：框架-1；正式期VIP/非VIP分别日key<1；领奖期不做本地日次，但领完奖励应改业务状态。
- 写入：正式期creator先置对应dailyKey=1；openMainPanel优先receiveCompensateReward，领奖期成功后结束而非再开主面板。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/luckydeliverypass/LuckyDeliveryPassManager.lua:136`；`amf/feature/localactivity/luckydeliverypass/LuckyDeliveryPassManager.lua:184`；`amf/feature/localactivity/luckydeliverypass/LuckyDeliveryPassManager.lua:193`

框架上限：LUCKY_DELIVERY_PASS_COMPENSATE=-1（AutoPopupLimit.lua:101）

## LuckyFarmStar

场景2通知；另在达到全关时流程可直接提示。

- 条件：StarBuffBonus或StarWandBonus有效、该endTime尚未展示、UIReady（实现true）。直接通关分支要求主线firstPass、passedLevel==globalMaxLevel、用户满关状态。
- 次数：noticeDisplayedEndTime==当前endTime判断每期；框架-1。
- 写入：成功创建notice VM后保存endTime再popout；无VM不写。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/luckyfarmstar/LuckyFarmStarManager.lua:271`；`amf/feature/localactivity/luckyfarmstar/LuckyFarmStarManager.lua:262`；`amf/feature/localactivity/luckyfarmstar/LuckyFarmStarManager.lua:307`；`amf/feature/localactivity/luckyfarmstar/LuckyFarmStarManager.lua:324`

框架上限：LUCKY_FARM_STAR_NOTICE=-1（AutoPopupLimit.lua:105）

## Merge

4路：场景4流程礼包、2/4主面板、3日奖、4引流。

- 条件：礼包非小游戏、未头部保护、有效；giftPart：当日pop<3且未忽略，payTag有效；零付费当日未买且成功关>=7；其他付费按体力/现金/通过数配置OR，已买排除通过数分支。引流：energy>100且已使用对应图鉴项且日计数<2。日奖由canGetSurpriseDailyReward。 付费阈值实际表：Low体力<5/现金<29/成功>=6；MidLow和MidHigh<5/<39/>=5；High4和High5<5/<59/>=4；High6<5/<100/>=3。零付费使用函数硬编码7，不使用表里的passTime=6。
- 次数：主面板框架1/日；引流业务2/日；礼包业务3/日；其他checkpoint -1。
- 写入：礼包拉到goodsId后计数+1、保存今日商品、清过关累计；引流执行前日计数+1。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/merge/MergeManager.lua:82`；`amf/feature/localactivity/merge/MergeManager.lua:1241`；`amf/feature/localactivity/merge/MergeManager.lua:1250`；`amf/feature/localactivity/merge/module/MergeGiftModule.lua:102`；`amf/feature/localactivity/merge/gift/GiftMeta.lua:213`

框架上限：MERGE_DAILY_REWARD=-1（AutoPopupLimit.lua:137）；MERGE_MAIN_STAGE2=1（AutoPopupLimit.lua:136）；MERGE_STAGE4_MAIN=-1（AutoPopupLimit.lua:135）；MERGE_STAGE4_SECONDARY=-1（AutoPopupLimit.lua:138）

## MergeEvolution

场景4优先日主面板，其次流程礼包，再引流。

- 条件：有效且最终奖未领取；主面板dailyOpenMain未记；礼包有FLOW商品且今日消耗>30、未勾今日不显示、该giftId当日未弹；引流guide2已有、未完成、收集>=50。
- 次数：引流2/日；礼包按日每goodsId；主面板日标记；框架-1。
- 写入：引流先日数+1；礼包先记录dayPopGift；dailyOpenMain写入活动端链本lane未闭合。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/mergeevolution/MergeEvolutionManager.lua:488`；`amf/feature/localactivity/mergeevolution/MergeEvolutionManager.lua:503`；`amf/feature/localactivity/mergeevolution/MergeEvolutionManager.lua:669`；`amf/feature/localactivity/mergeevolution/const/MergeEvolutionConst.lua:118`

框架上限：MERGE_EVOLUTION_STAGE4_POP=-1（AutoPopupLimit.lua:139）

## 2026中秋国庆

场景2主面板。

- 条件：isEnabled且不是预热期；creator重检。不能仅凭框架注释日期证明在线活动日历。
- 次数：MID_AUTUMN_NATIONAL_DAY_2026_MAIN_POP_STAGE_2框架1/日，manualOpen绑定actId。
- 写入：业务直接openActivity，无另曝光日标记。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/midautumnnationalday2026/MidAutumnNationalDay2026Manager.lua:46`；`amf/feature/localactivity/midautumnnationalday2026/MidAutumnNationalDay2026Manager.lua:69`

框架上限：MID_AUTUMN_NATIONAL_DAY_2026_MAIN_POP_STAGE_2=1（AutoPopupLimit.lua:30）

## 新手礼包优化

首次进入主场景及场景3/4对每种giftType独立检查。

- 条件：checkTypeEnabled；strongPushTable/strongPushConditionList给条件；距lastPop>=strongPushCdH小时，同sceneId条件任一返回非false；条件类型读取Meta.AutoPopDefinition。 AutoPopDefinition数组的conditionId是1风车币、2体力、3进入、4连败；不要与返回AUTOPOPTYPE枚举（1体力2连败3登录4币）混为一谈。值来自conditionValue or 0。五类礼包：最佳助力、无限过关、挑选一个、越买越香、敢买敢送。
- 次数：CD每openIdx+giftType保存；无配置Cd默认999小时；框架-1；默认值非线上策略。
- 写入：doAutoPopout调用openActivity后立即setOnPopout；服务端actInfo.extra同步LocalDataServer配置。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/newbiegiftoptimize/NewbieGiftOptimizeMgr.lua:899`；`amf/feature/localactivity/newbiegiftoptimize/NewbieGiftOptimizeMgr.lua:944`；`amf/feature/localactivity/newbiegiftoptimize/NewbieGiftOptimizeMgr.lua:939`；`amf/feature/localactivity/newbiegiftoptimize/config/NewbieGiftOptimizeMeta.lua:107`

框架上限：NEWBIEOPTIMIZE_STAGE=-1（AutoPopupLimit.lua:45）

## 飞碟弹弹乐

场景4主面板和引流两个检测点。

- 条件：主面板有效且launchOpportunity>=20；引流需资源下载完成、有效、抑制计数0、launchOpportunity>=10；旧注册注释50错误，实际配置10。
- 次数：两个检测点各1/日；主面板弹后抑制后续3次过关引流（存3+1，因扣减在检测前）。
- 写入：主面板调用markSuppressedByMainPanelAutoPop；过关consumeSuppressPassCount逐次-1；引流日次数由框架。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/pengpeng2026/PengPeng2026Manager.lua:166`；`amf/feature/localactivity/pengpeng2026/module/PengPeng2026AttractPanelHelper.lua:51`；`amf/feature/localactivity/pengpeng2026/module/PengPeng2026AttractPanelHelper.lua:72`；`amf/feature/localactivity/pengpeng2026/config/PengPeng2026Config.lua:24`

框架上限：PENGPENG2026_ATTRACT_PANEL_STAGE4=1（AutoPopupLimit.lua:115）；PENGPENG2026_MAIN_PANEL_STAGE4=1（AutoPopupLimit.lua:114）

## Pet翅膀

场景2注册；另业务场景4接口选翅膀或回退主面板。

- 条件：dataEnabled/open/versionMatch/wingFeatureEnabled；frequencyContext有效，serverDay未展示；未激活或当天false→true转变。已同步且非激活转变还需连续登录进度动画资格；场景4回退要求距结束>60秒、当日主面板未看、配置降频不拦截。
- 次数：按serverDay展示；不是本机自然日简单计数；框架-1。
- 写入：openWingAutoPop等待mainInfo并超时可失败，确认展示走回调；模型展示日标记写入及外部场景4调用链尚需传递闭合。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/pet/PetManager.lua:111`；`amf/feature/localactivity/pet/PetManager.lua:149`；`amf/feature/localactivity/pet/PetManager.lua:228`；`amf/feature/localactivity/pet/PetManager.lua:311`

## SH01

场景2/4同活动期首次主面板。

- 条件：数据enabled+正式期；actInfo存在；extra.livenessTag==2阻止（代码注释回流）；本地mainBeginTime对应标记未有。
- 次数：框架-1；本地key sh01PopMain_以mainBeginTime隔离期。
- 写入：仅活动endCallback setPopMainFinish；failCallback不写。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/sh01/SH01Manager.lua:70`；`amf/feature/localactivity/sh01/SH01Manager.lua:105`；`amf/feature/localactivity/sh01/SH01Manager.lua:284`

框架上限：SH01_MAIN_POP=-1（AutoPopupLimit.lua:62）

## SprintGiftPackage

仅场景2按四种原因优先选择。

- 条件：isEnabled2且未头部保护；正式期未进主面板→1，否则任务全完成且popTip2未记→2；领奖期全完成且popTip3未记→3，否则有可领奖且popTip4未记→4。
- 次数：四个业务标记；框架-1且OnlyStage2限制。
- 写入：openActivity先savePopFlag(saveIndex)再派发活动打开；具体标记按model键口径。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/sprintgiftpackage/SprintGiftPackageManager.lua:1215`；`amf/feature/localactivity/sprintgiftpackage/SprintGiftPackageManager.lua:925`；`amf/feature/localactivity/sprintgiftpackage/SprintGiftPackageManager.lua:1172`

框架上限：SPRINT_GIFT_CHECK_STAGE_2=-1（AutoPopupLimit.lua:76）

## SprintRealPrize（ID 4102）

场景2活动ready且活动包主面板未打开时弹。

- 条件：_actReady；_isUserNotOpened委托活动包_actConfig._isMainPanelOpened；creator再次检查。
- 次数：两个版本代码使用相同SPRINT_REAL_PRIZE_T2 checkpoint；默认框架次数要看命名解析，不猜两版可同时开。
- 写入：调用openActivity，未打开标记写在活动包函数，当前包外Config具体运行数据缺口保留。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/sprintrealprize/SprintRealPrizeManager.lua:441`；`amf/feature/localactivity/sprintrealprize/SprintRealPrizeManager.lua:450`；`amf/feature/localactivity/sprintrealprize/SprintRealPrizeManager.lua:459`

## SprintRealPrize（ID 4103）

场景2活动ready且活动包主面板未打开时弹。

- 条件：_actReady；_isUserNotOpened委托活动包_actConfig._isMainPanelOpened；creator再次检查。
- 次数：两个版本代码使用相同SPRINT_REAL_PRIZE_T2 checkpoint；默认框架次数要看命名解析，不猜两版可同时开。
- 写入：调用openActivity，未打开标记写在活动包函数，当前包外Config具体运行数据缺口保留。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/sprintrealprize2/SprintRealPrizeManagerV2.lua:441`；`amf/feature/localactivity/sprintrealprize2/SprintRealPrizeManagerV2.lua:450`；`amf/feature/localactivity/sprintrealprize2/SprintRealPrizeManagerV2.lua:459`

## 超级魔力鸟分享活动

场景4首次参与主面板；2/4可领奖提示。

- 条件：平台支持且有效且正式期；首次MainPanelOpened未置；奖励需服务器canReceiveReward严格true。
- 次数：首次本地非日key；奖励场景2日一次、4业务不限；两个框架-1。
- 写入：首次pop先MainPanelOpened；奖励仅场景2写RewardMainPanelPoppedToday；手动打开也可影响首次标记。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/superbirdshare/superbirdshareManager.lua:99`；`amf/feature/localactivity/superbirdshare/superbirdshareManager.lua:108`；`amf/feature/localactivity/superbirdshare/superbirdshareManager.lua:132`；`amf/feature/localactivity/superbirdshare/superbirdshareManager.lua:153`

框架上限：SUPER_BIRD_SHARE_FIRST_STAGE4=-1（AutoPopupLimit.lua:122）；SUPER_BIRD_SHARE_REWARD=-1（AutoPopupLimit.lua:123）

## 超级魔力鸟复活卡

2/4日发卡通知；4断鸟后的激活确认。

- 条件：日通知hasReviveCard表示rewardMs含今天领取时间（不等同背包有卡），或功能有效且今天未领取；确认pending且背包卡>0且鸟不可用且passTopNums<needWinNum。
- 次数：日通知框架1/日；确认-1且一次性pending；不将领取时间与背包库存混淆。
- 写入：确认先pending=false，再打开；markReviveCardDeliveryAutoPopConsumed可增加框架计数。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/supermagicbird/SuperMagicBird2024Manager.lua:110`；`amf/feature/localactivity/supermagicbird/SuperMagicBird2024Manager.lua:629`；`amf/feature/localactivity/supermagicbird/SuperMagicBird2024Manager.lua:668`

框架上限：SUPER_MAGIC_BIRD_REVIVE=1（AutoPopupLimit.lua:106）；SUPER_MAGIC_BIRD_REVIVE_CONFIRM=-1（AutoPopupLimit.lua:107）

## SuperMagicBirdRealGift

场景2活动有效且未弹过的主面板。

- 条件：isEnabled且Stage2AutoPop本地非日flag未有。
- 次数：框架-1；业务非日标记，按期键继承口径需结合model。
- 写入：creator重检后先置Stage2AutoPop再openActivity，打开失败也已置。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/supermagicbirdrealgift/SuperMagicBirdRealGiftManager.lua:89`；`amf/feature/localactivity/supermagicbirdrealgift/SuperMagicBirdRealGiftManager.lua:94`

框架上限：SUPER_MAGIC_BIRD_REAL_GIFT_STAGE2=-1（AutoPopupLimit.lua:120）

## 拾光成歌（框架注释命名）

场景4优先引流1 > 引流2 > 主面板。

- 条件：有效；引流1今日免费奖未领；引流2extra.beHelpShowLens非0；主面板已开放handbook中仍有gotClueIds<7。
- 次数：主面板1/日；引流共享3/日；框架实际-1，注册注释称框架3次不正确，不能写合计3次。
- 写入：主面板pop前MainPanelPanelPopCount+1；两引流分别YinLiuPanelPopCount+1；freeRewardDays服务器给领取天。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/underthesin/UnderTheSinMgr.lua:331`；`amf/feature/localactivity/underthesin/UnderTheSinMgr.lua:352`；`amf/feature/localactivity/underthesin/UnderTheSinMgr.lua:382`；`amf/feature/localactivity/underthesin/UnderTheSinMgr.lua:406`

框架上限：UNDERTHESIN_STAGE4_POP=-1（AutoPopupLimit.lua:124）

## WaterfallGiftProgress

2/3/4配置触发，但领奖期2/4绕过普通条件CD。

- 条件：有效。非领奖期按autoPopoutCd小时+sceneId+条件表；领奖期场景2同步补偿和场景4直接checkRes=true；场景3领奖期return。场景2仍需主场景且进入后<3秒或无记录。 DY offer代码虽存在，isDouyinMarketing第一行do return false end，当前样本不可达，不应列为有效推送。
- 次数：框架-1；普通阶段配置CD，不能将其套用领奖阶段；DY offer为独立检测点。
- 写入：doAutoPopout成功pullOnce分支setLastPopoutTime；领奖展示后的服务器业务状态另控。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/waterfallgiftprogress/WaterfallGiftProgressManager.lua:718`；`amf/feature/localactivity/waterfallgiftprogress/WaterfallGiftProgressManager.lua:762`；`amf/feature/localactivity/waterfallgiftprogress/WaterfallGiftProgressManager.lua:811`；`amf/feature/localactivity/waterfallgiftprogress/WaterfallGiftProgressManager.lua:834`；`amf/feature/localactivity/waterfallgiftprogress/WaterfallGiftProgressManager.lua:916`

框架上限：WATERFALL_PROGRESS=-1（AutoPopupLimit.lua:47）

## WeekTask

仅开发模式或小游戏安装本注册；场景4主面板，3/4任务完成播报。

- 条件：主面板支持且有效；播报支持且有效且不被新关保护且completeTaskInfos非空。注意addActCompleteInfos在小游戏直接return，所以不能因注册存在就说正常小游戏必有播报。
- 次数：主面板框架1/日；播报-1，按待处理队列；>2项合并播报，否则逐条。
- 写入：doPopBanner派发后completeTaskInfos={}；加入时去重。
- 范围：业务注册及所列条件已逐行核对；不代表全部上下游已闭合
- 证据：`amf/feature/localactivity/weektask/WeekTaskManager.lua:63`；`amf/feature/localactivity/weektask/WeekTaskManager.lua:431`；`amf/feature/localactivity/weektask/module/WeekTaskBanner.lua:16`；`amf/feature/localactivity/weektask/module/WeekTaskBanner.lua:44`

框架上限：WEEK_TASK_STAGE3_POP=-1（AutoPopupLimit.lua:129）；WEEK_TASK_STAGE4_MAIN=1（AutoPopupLimit.lua:128）

## 复现与缺口

运行scan_triggers.py生成词法证据，再运行extend_findings.py生成已读条件汇总。JSON保留源路径、行号和SHA256。缺口：部分活动包Config运行时数据、在线开关/奖励/真实日历、模型标记全量清零传递、平台特殊路径。词法扫描不是运行时调用证明；框架转发/debug行不能算新活动。