# -*- coding: utf-8 -*-
from pathlib import Path
import json,re,hashlib,collections
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[2];SRC=ROOT/'analysis/native_decode/decoded'
inv=json.loads((OUT.parent/'triggers/trigger-inventory.json').read_text())
# Audited consumer predicates; global budgets deliberately remain separate.
D={
'TR006':('签到','首次进主界面场景2；topLevel>=201、Group非OFF、今天未签到；重要事件签到feed入口排除。App Group固定ON，小游戏维护开关minigame_sign_in决定。','todayIsMark由optionalData/签到响应维护，领取成功写true；不是入队即已签到。','MarkManager.lua:98,159,336,564; mark/Group.lua:6','展示所需数据/窗口检查仍在showMainPanel中；未声称领取条件全部审完'),
'TR007':('每日一关：连过重燃介绍','场景2或MAIN_INFO_LOAD_SUCCESS/PUB_RES_READAY补检查；功能/数据/资源就绪、groupType非0、修复活动在时间内且progress<target、progress==0、本期未弹。补触发须在主界面，通知链内不抢跑。','repairStage2PopPeriod=repairPeriodId，缺失用endTime；creator再次check通过后、showRepairPanel前写入。','PromoteDailyAutoPopoutLogic.lua:21,50,75,85; PromoteDailyMgr.lua:428,454,666','重燃任务目标数与实际周期来自活动数据，不能固定为几关几天'),
'TR008':('每日一关：可领奖/满签','场景4功能启用后四条件任一：月/纪念章可领奖，满签且本月没弹，7日奖励可领，目标任务当前进度>=target且reward未置位。','满签popFullSignDate_year_month在MainPanelVM展示满签分支前写true；普通领奖是否再次弹取决于未领状态。','PromoteDailyAutoPopoutLogic.lua:111,132; PromoteDailyModelLogic.lua:19,678,699,1098; MainPanelVM.lua:805','全套任务/勋章合法性不是本次全部语义覆盖'),
'TR009':('桌面挂件奖励','场景4；平台支持、有actInfo、模型可用、活动期内且主面板未存在。首次未trigger可弹；未安装且今日未开面板时按天差1或2；或从挂件进入且当日有未领奖励。','creator先addGuideIndex(canPop)再openActivity。注意代码 delta==1 or delta==2 and not hasGuideIndex(...)，Lua AND优先：delta1不受最后guide检查。','DesktopWidgetManager.lua:217,229,404,469','平台delegate内部支持清单未逐平台展开；不把注释的第二三天规则写成完全对称'),
'TR012':('果树集字活动','场景4；功能开关/平台（OHOS排除）/果树可用、actInfo和model启用。todayCount<3；成熟且完成GUIDE1→领奖引流；否则今日未弹引流且尚未activate→普通引流。成熟=originRipeTime-helpSpeedTime<=now毫秒。','资源load成功且再确认enabled后才todayPopPanelCount+1；普通引流另写hasPopout_flowPanel=true。框架仍可施加更小日额度。','CollectWordManager.lua:154,215,233,530,561,1450,1503,1575','actInfo:isEnabled、model:isEnabled内部仍是依赖，不称活动完整运营配置已得'),
'TR016':('每日特惠AI礼包','场景4且packageData存在；非支付宝需last60Pay>0；代码实际拒绝endTime<now-60；endTime必须大于LocalDB最后弹礼包endTime。creator只重查packageData存在。','vm:popout后写last_popped_gift_endTime=endTime，以结束时间去重，并非每日一次。','DailySpecialAIModule.lua:155,169','注意非“至少剩余60秒”；packageData上游失效管理可另挡过期，不推断实际必弹过期礼包。无客户端推荐模型证据'),
'TR017':('破冰礼包','packageData存在，STORE场景排除；未打开过：场景2 userTopLevel>6，场景4>5；giftTriggerTimes==2走T2 checkpoint；creator再次检查未打开。','IceBreakingOpened+periodId+giftTriggerTimes持久标记；ViewVM:onEnter初始化调用setUserOpened。tryAutoPopup在框架空闲时触发stage2队列。','IceBreakingGiftModule.lua:246,251,264,278,291; view/IceBreakingGiftViewVM.lua:25','>5是代码实际判断，不能照注释写仅第6关。礼包价格奖励来自packageData，不是此函数固定值'),
'TR018':('荣誉排行奖励','取巅峰奖励接口成功后入队；展示时getWaitingRewardData必须有非空rewards，资源加载成功才展示。','展示调用后clearWaitingRewardData；无奖回调结束，入队不代表必出现领奖窗口。','HonorRankManager.lua:140,162,224','接口奖励生成和上游榜单资格不在此审计闭合范围'),
'TR114':('晋级赛奖励卡包','待处理_pendingPromotionCardPackList非空才入队，属于既得奖励开包，不是活动招募。','事务完成或失败均清空待处理列表；展示时跳过CollectCard本轮普通开包避免重复。','PromotionEvent2025Manager.lua:888,899','事务失败后服务端补偿不在本次审计范围'),
'TR115':('晋级赛历史排名奖励','场景4 isEnabled；先处理奖励卡包，再按popup210/300实验挡低等级；taskIndex>=1、本期LastRankFlag未置、有needGetHistoryRankReward且lastPeriod>0；新关开放时若当前头部新关则不弹。','LastPeriodRankPanelVM:161写本期showLastRankFlags[period]，对应已显示历史榜；并非入队就写。','PromotionEvent2025Manager.lua:2423; PromotionEvent2025Model.lua:463,483,1237; LastPeriodRankPanelVM.lua:161','isEnabled还含base/data/resource/open检查；对应在线实验值未知'),
'TR116':('回流权益失败挽留','场景4；非小游戏、数据可用且主活动期；今天bonusDays已含今日、+20步buff已过期；_lastFailed且stage4_fail_pop未置；creator另检查图标网络/今日免费解锁未用。','入队后立即setLocalCache(stage4_fail_pop,true)，然后_lastFailed=false；Manager:setLocalCache只有2形参，传入第3个true被丢弃，不能据调用写“每天一次”。','Recall2025Manager.lua:46,175,182,314; Recall2025Model.lua:92,134,168','_localCache重置边界除初始化之外未闭合；不报告每日/每期精确频次'),
}
D['TR005']=('比赛海选外部入口','收到launch/open-share参数，经normalizeLaunchEntryParams成功且entryType=AUDITIONS才排队；非小游戏App可用，或明确允许的本地赛事包。已填海选资料则直接开关卡，否则弹资料面板。','处理成功会清除launchQuery；markAuditionsInfoFilled保存会话标记，不是按天限次。没有队列/无checkpoint则直接打开。','CompetitionTransferManager.lua:107,260,492,515,536','外部链接参数完整校验与赛事服务器报名资格不在此范围；这属于用户外链唤起，不是主动营销推荐')
D['TR145']=('回流权益首次领取','场景2回流handler：新关开启时间排除；topPassedLevel>=100且AMFRecallManager命中COMMON_FOURTEEN_DAY；creator检查isEnabled且今天未领、总权益未领完，失败等待1秒再查一次。','领取状态使用bonusDays今日编号和maxBonusCount；不使用本地固定离线天数重算，回流标记由AMFRecallManager消费。','RecallHandler.lua:28,44,57; Recall2025Manager.lua:292,298; Recall2025Model.lua:128,134','COMMON_FOURTEEN_DAY名称不能替代上游判定的完整定义；本条未声称已审完回流资格生产端')
activity={5,6,7,8,9,12,16,17,18,114,115,116,145};feature={10,11,13,14,15,97,98,99,100,101,102,112,113,120};platform=set(range(103,112));account={1,2,3,139,140,141,142,143,144,146,147,148,151,152,153}
rows=[]
for r in inv['rows']:
 if '/localactivity/' in r['source']:continue
 n=int(r['id'][2:]);cat='shared_queue_or_navigation'
 if n in activity:cat='activity_or_reward_or_offer'
 elif n in feature:cat='feature_entry_or_social_guide'
 elif n in platform:cat='platform_growth_or_subscription'
 elif n in account:cat='account_system_or_policy'
 elif n==4:cat='rewarded_ad_guide'
 elif n in [117,118,119]:cat='winningstreak_reviewed_by_other_lane'
 x={k:r[k] for k in ['id','source','line','sha256','function','checkpoint','stages','context']};x['classification']=cat
 x['review']='classified_entry_context_only';x['necessary_conditions_at_entry']=[l.strip() for l in r['context'].splitlines() if re.search(r'\bif\b|\breturn\b',l) and not l.strip().startswith('--')]
 if r['id'] in D:
  a=D[r['id']];x.update(name=a[0],conditions=a[1],state_writes_and_limits=a[2],evidence=a[3],remaining_dependency=a[4],review='consumer_and_named_direct_helpers_reviewed')
 rows.append(x)
# Extra entry missed by auto-popup lexical inventory: icon/manual entry is not a force popup.
rows.append({'id':'EX_WEEKLY_RACE','source':'amf/feature/weeklyrace/WeeklyRaceManager.lua','line':63,'sha256':hashlib.sha256((SRC/'amf/feature/weeklyrace/WeeklyRaceManager.lua').read_bytes()).hexdigest(),'name':'萌宠周赛图标/手动入口','classification':'manual_activity_entry_no_autopopup_found','review':'consumer_and_named_direct_helpers_reviewed','conditions':'tryUpdateIcon要求FeatureSwitch.WEEKLY_RACE、topLevel>=180、主界面、图标未存在；接口iconInfo.petSkinId非0才创建图标。onTouchIcon要求网络并再次关卡检查，下载meta/Weeklyrace.xml与请求weekMatch2020Info后打开。','state_writes_and_limits':'图标已存在则不重复创建；本文件未发现自动弹窗注册。isActEnd调用被注释，不能据2025-12-31的常量声称入口关闭。','evidence':'WeeklyRaceManager.lua:63,112,118,182; config/WeeklyRaceConst.lua:3,5','remaining_dependency':'动态模块资源、线上FeatureSwitch及接口回应未知。没有全树证明其他旧周赛自动弹窗路径绝不存在。'})
result={'scope':'Non-localactivity lexical trigger consumers classified individually; 13 consumer families plus weekly icon entry hand-reviewed. Shared queue behavior belongs engine lane. Pure system windows not counted as activities.','counts':dict(collections.Counter(x['classification'] for x in rows)),'rows':rows}
(OUT/'external-triggers.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
md='''# localactivity之外的活动与系统窗口审查

活动不能只查localactivity目录；同一自动弹窗队列也承载实名认证、版本更新、好友引导与奖励结算。对trigger-inventory中的75条非localactivity入口逐条分类，另补1条周赛手动入口。**分类覆盖不等于75条所有依赖语义审完**；下表13条业务消费者及周赛入口完成主体与所列直接helper核验，其余保留源函数上下文与明确状态。

## 已补查的业务规则

| 业务 | 必要条件 | 次数/状态写入 | 尚未闭合 |
|---|---|---|---|
'''
for x in rows:
 if x['review']!='consumer_and_named_direct_helpers_reviewed':continue
 md+='| '+x['name']+' | '+x['conditions']+' | '+x['state_writes_and_limits']+' | '+x['remaining_dependency']+' |\n'
md+='\n## 证据索引\n\n'
for x in rows:
 if 'evidence' in x:md+='- '+x['name']+'：`'+x['source']+'`；'+x['evidence']+'。\n'
md+='''
## 防止误读的重点

1. 萌宠周赛8015未进入当前UBF注册，但仍存在图标与手动打开接线；不能据UBF清单证明整个活动入口消失。
2. 每日特惠AI礼包的60秒比较是`endTime < now - 60`。不能改写成`endTime - now > 60`。有无在线礼包仍由packageData上游管控。
3. 回流挽留`setLocalCache(...,true,true)`第三实参没有被Manager接收，当前链条没有日key，故不能凭调用形状认定每天一次。
4. 挂件奖励`delta == 1 or delta == 2 and not flag`按Lua优先级是`delta==1 or (delta==2 and not flag)`，不是两日都检查同一flag。
5. 果树业务次数上限3不是实际一定能弹3次，统一checkpoint和场景预算会继续限制。
6. 签到、晋级赛领奖、奖励卡包开包属于不同触达目的，不能全写成活动招募。

`external-triggers.json`保留每条来源、行号、SHA、入口上下文、分类与review状态。生成命令：`python3 analysis/activity-push-2026-10-21/catalog/build_external.py`。没有在线响应，奖励/价格/实验当前分桶不补造数值。
'''
(OUT/'external-findings.md').write_text(md)
print(json.dumps(result['counts'],ensure_ascii=False))
