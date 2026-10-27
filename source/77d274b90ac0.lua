local BoardMeta = {}

BoardMeta.Chicken = 59334 --小鸡
BoardMeta.Machine = 59333 --料理机
BoardMeta.GuoLanItemMaker = 59337 --果蔬烂
BoardMeta.ItemLanMei = 59341 --蓝莓
BoardMeta.CaoMei = 59342 --草莓
BoardMeta.NingMeng = 59343 --柠檬
BoardMeta.ZhiBingItemMaker = 59340 --制冰机
BoardMeta.XiangChang = 59358 --香肠
BoardMeta.LengCangItemMaker = 59338 --冷藏箱
BoardMeta.ZhiMianItemMaker = 59339--制面机
BoardMeta.PeiGen = 59359 --培根
BoardMeta.XiaRen = 59360 --虾
BoardMeta.BingKuai = 59367 --冰块
BoardMeta.BingKuaiLv2 = 59368 --冰块2级

BoardMeta.JiaoziLv1_v1 = 59409 --饺子1级
BoardMeta.JiaoziLv2_v1 = 59410 --饺子2级
BoardMeta.JiaoziLv3_v1 = 59411 --饺子3级
BoardMeta.JiaoziLv4_v1 = 59412 --饺子4级

BoardMeta.JiaoziLv1_v2 = 59413 --饺子1级
BoardMeta.JiaoziLv2_v2 = 59414 --饺子2级
BoardMeta.JiaoziLv3_v2 = 59415 --饺子3级
BoardMeta.JiaoziLv4_v2 = 59416 --饺子4级

BoardMeta.JiaoziLv1_v3 = 59417 --饺子1级
BoardMeta.JiaoziLv2_v3 = 59418 --饺子2级
BoardMeta.JiaoziLv3_v3 = 59419 --饺子3级
BoardMeta.JiaoziLv4_v3 = 59420 --饺子4级

BoardMeta.ShiHeLV1 = 59424

BoardMeta.ZaoniGao = 59425 --枣泥
BoardMeta.JuhuaCha = 59433 --菊花茶

BoardMeta.zixuanBox = 59421 --自选宝箱

BoardMeta.EnergyBottleLv1 = 59450 --1级体力瓶
BoardMeta.EnergyBottleLv2 = 59451 --2级体力瓶
BoardMeta.EnergyBottleLv3 = 59452 --3级体力瓶
BoardMeta.EnergyBottleLv4 = 59453 --4级体力瓶
BoardMeta.EnergyBottleLv5 = 59454 --5级体力瓶
BoardMeta.EnergyBottleLv6 = 59455 --6级体力瓶
BoardMeta.LowEnergyBox = 59456 --低级体力宝箱
BoardMeta.HighEnergyBox = 59457 --高级体力宝箱

BoardMeta.EnergyBottleIds = {
	BoardMeta.EnergyBottleLv1,
	BoardMeta.EnergyBottleLv2,
	BoardMeta.EnergyBottleLv3,
	BoardMeta.EnergyBottleLv4,
	BoardMeta.EnergyBottleLv5,
	BoardMeta.EnergyBottleLv6,
}

BoardMeta.EnergyBoxIds = {
	BoardMeta.LowEnergyBox,
	BoardMeta.HighEnergyBox,
}

--棋盘区域 7*8
BoardMeta.BoardWidthNum = 7
BoardMeta.BoardHeightNum = 8

--素材图
BoardMeta.BoardItemsPlistPath = 'amf/activity/merge/materials/mergeItems.plist'

--机器展示类型
BoardMeta.machineShowType = {
	kLock = 0,
	kNormal = 1,
	kMaking = 2,
	kMakeEnd = 3,
}

--特殊区域拖动类型
BoardMeta.specialAreaDragTypes = {
	kChicken = 1,
	kMachine = 2,
}

--订单类型
BoardMeta.orderTypes = {
	kOrder1 = 1, --订单1
	kOrder2 = 2, --订单2
	kOrder3 = 3, --订单3
}

--区域类型
BoardMeta.BoardTypes = {
	kNone = 0, --未知区域
	kMainBoard = 1, --主区域
	kChickenBoard = 2, --小鸡区域
	kMachineBoard = 3, --机器区域
}

--后端道具在棋盘上的状态
BoardMeta.ItemStatus = {
	kLock2 = 0, --盒子
	kLock1 = 1, --胶条
	kUnLock = 2, --解锁
	kSuperBubble = 3, --高级气泡
	kNormalBubble = 4, --普通气泡
	kDoublePowerOpen =5, --双倍能量开启
	kFirstDiscountNormalBubble = 6, --首次折扣气泡
	kDiscountNormalBubble = 7, --折扣气泡
	kFrozen = 8, --冰冻棋子，阶段由 frozenFoodData.phase 区分
}

--气泡类型 前端用
BoardMeta.ItemBubbleTypes = {
	kNone = 0,
	kNormalBubble = 1,
	kSuperBubble = 2,
	kFirstDiscountNormalBubble = 3, --首次折扣气泡
	kDiscountNormalBubble = 4, --折扣气泡

}

--道具类型
BoardMeta.ItemTypes = {
	kNone = 0,
	kGuoShu = 1, --果蔬
	kRouLei = 2, --肉类
	kNaiLei = 3, --奶类
	kBingKuai = 4, --冰块
	kMianShi = 5, --面粉
	kCaiPin1 = 6, --菜品类型1 冰镇蓝莓汁
	kCaiPin2 = 7, --菜品类型2 虾仁茄汁饭
	kCaiPin3 = 8, --菜品类型3 草莓牛奶布丁
	kCaiPin4 = 9, --菜品类型4 泰式芒果饭
	kItemMaker = 10, --生成器
	kMagicItem = 11, --魔法道具
	kJiaoZi = 13, --饺子
	kSpecialItem = 14, --特殊道具 自选等
	kDianXin = 15, --点心
	kCha = 16, --茶
	kCaiPin5 = 17, --菜品类型5 山西菜
}

--魔法道具
BoardMeta.MagicItemEnergy = 59404 --无限体力
BoardMeta.MagicItemJianDao = 59405 --剪刀
BoardMeta.MagicItemMiaoBiao = 59406 --秒表
BoardMeta.MagicItemShengji = 59407 --升级卡
BoardMeta.PowerMultiplier2RewardId = 59458 --2倍体力奖励
BoardMeta.PowerMultiplier4RewardId = 59459 --4倍体力奖励
BoardMeta.PowerMultiplier8RewardId = 59460 --8倍体力及多倍按钮解锁奖励

--道具数据
BoardMeta.ItemData = {

	--生成器
	[''..BoardMeta.GuoLanItemMaker] = { itemId = BoardMeta.GuoLanItemMaker, itemType = BoardMeta.ItemTypes.kItemMaker, makeItemList = { BoardMeta.ItemLanMei }, makeExtraItem = { id =BoardMeta.JiaoziLv1_v1, percent = 10, pkPercent = 20 }, spName = '040.png', }, --果蔬篮 生成列表
	[''..BoardMeta.LengCangItemMaker] = { itemId = BoardMeta.LengCangItemMaker, itemType = BoardMeta.ItemTypes.kItemMaker, makeItemList = { 59350, BoardMeta.XiangChang } , makeExtraItem = { id =BoardMeta.JiaoziLv1_v1, percent = 10, pkPercent = 20 }, spName = '042.png', }, --冷藏箱 生成列表
	[''..BoardMeta.ZhiMianItemMaker] = { itemId = BoardMeta.ZhiMianItemMaker, itemType = BoardMeta.ItemTypes.kItemMaker, makeItemList = { 59373 }, makeExtraItem = { id =BoardMeta.JiaoziLv1_v1, percent = 10, pkPercent = 20 }, spName = '043.png', }, --制面机 生成列表
	[''..BoardMeta.ZhiBingItemMaker] = { itemId = BoardMeta.ZhiBingItemMaker, itemType = BoardMeta.ItemTypes.kItemMaker, makeItemList = { BoardMeta.BingKuai }, makeExtraItem = { id =BoardMeta.JiaoziLv1_v1, percent = 10, pkPercent = 20 }, spName = '041.png', }, --制冰机 生成列表
	[''..BoardMeta.ShiHeLV1] = { itemId = BoardMeta.ShiHeLV1, itemType = BoardMeta.ItemTypes.kItemMaker, makeItemList = { BoardMeta.ZaoniGao, BoardMeta.JuhuaCha }, makeExtraItem = { id =BoardMeta.JiaoziLv1_v1, percent = 10, pkPercent = 20 }, spName = '102.png', }, --食盒 生成列表

	--果蔬
	[''..BoardMeta.ItemLanMei] = { itemType = BoardMeta.ItemTypes.kGuoShu, level = 1 ,nextId = 59342, spName = '001.png', }, --普通道具
	[''..BoardMeta.CaoMei] = { itemType = BoardMeta.ItemTypes.kGuoShu, level = 2, nextId = 59343, preId = BoardMeta.ItemLanMei, spName = '002.png', }, --普通道具
	[''..BoardMeta.NingMeng] = { itemType = BoardMeta.ItemTypes.kGuoShu, level = 3, nextId = 59344, preId = 59342, spName = '003.png', }, --普通道具
	['59344'] = { itemType = BoardMeta.ItemTypes.kGuoShu, level = 4, nextId = 59345, preId = 59343, spName = '004.png', }, --普通道具
	['59345'] = { itemType = BoardMeta.ItemTypes.kGuoShu, level = 5, nextId = 59346, preId = 59344, spName = '005.png', }, --普通道具
	['59346'] = { itemType = BoardMeta.ItemTypes.kGuoShu, level = 6, nextId = 59347, preId = 59345, spName = '006.png', }, --普通道具
	['59347'] = { itemType = BoardMeta.ItemTypes.kGuoShu, level = 7, nextId = 59348, preId = 59346, spName = '007.png', }, --普通道具
	['59348'] = { itemType = BoardMeta.ItemTypes.kGuoShu, level = 8, nextId = 59349, preId = 59347, spName = '008.png', }, --普通道具
	['59349'] = { itemType = BoardMeta.ItemTypes.kGuoShu, level = 9, nextId = 59445, preId = 59348, spName = '009.png', }, --普通道具
	['59445'] = { itemType = BoardMeta.ItemTypes.kGuoShu, level = 10, preId = 59349, spName = '111.png', }, --普通道具

	--肉类
	[''..BoardMeta.XiangChang] = { itemType = BoardMeta.ItemTypes.kRouLei, level = 1, nextId = BoardMeta.PeiGen, spName = '010.png', }, --普通道具
	[''..BoardMeta.PeiGen] = { itemType = BoardMeta.ItemTypes.kRouLei, level = 2, nextId = BoardMeta.XiaRen, preId = BoardMeta.XiangChang, spName = '011.png', }, --普通道具
	[''..BoardMeta.XiaRen] = { itemType = BoardMeta.ItemTypes.kRouLei, level = 3, nextId = 59361, preId = BoardMeta.PeiGen, spName = '012.png', }, --普通道具
	['59361'] = { itemType = BoardMeta.ItemTypes.kRouLei, level = 4, nextId = 59362, preId = BoardMeta.XiaRen, spName = '013.png', }, --普通道具
	['59362'] = { itemType = BoardMeta.ItemTypes.kRouLei, level = 5, nextId = 59363, preId = 59361, spName = '014.png', }, --普通道具
	['59363'] = { itemType = BoardMeta.ItemTypes.kRouLei, level = 6, nextId = 59364, preId = 59362, spName = '015.png', }, --普通道具
	['59364'] = { itemType = BoardMeta.ItemTypes.kRouLei, level = 7, nextId = 59365, preId = 59363, spName = '016.png', }, --普通道具
	['59365'] = { itemType = BoardMeta.ItemTypes.kRouLei, level = 8, nextId = 59366, preId = 59364, spName = '017.png', }, --普通道具
	['59366'] = { itemType = BoardMeta.ItemTypes.kRouLei, level = 9, preId = 59365, spName = '018.png', }, --普通道具

	--奶类
	['59350'] = { itemType = BoardMeta.ItemTypes.kNaiLei, level = 1, nextId = 59351, spName = '026.png', }, --普通道具
	['59351'] = { itemType = BoardMeta.ItemTypes.kNaiLei, level = 2, nextId = 59352, preId = 59350, spName = '027.png', }, --普通道具
	['59352'] = { itemType = BoardMeta.ItemTypes.kNaiLei, level = 3, nextId = 59353, preId = 59351, spName = '028.png', }, --普通道具
	['59353'] = { itemType = BoardMeta.ItemTypes.kNaiLei, level = 4, nextId = 59354, preId = 59352, spName = '029.png', }, --普通道具
	['59354'] = { itemType = BoardMeta.ItemTypes.kNaiLei, level = 5, nextId = 59355, preId = 59353, spName = '030.png', }, --普通道具
	['59355'] = { itemType = BoardMeta.ItemTypes.kNaiLei, level = 6, nextId = 59356, preId = 59354, spName = '031.png', }, --普通道具
	['59356'] = { itemType = BoardMeta.ItemTypes.kNaiLei, level = 7, nextId = 59357, preId = 59355, spName = '032.png', }, --普通道具
	['59357'] = { itemType = BoardMeta.ItemTypes.kNaiLei, level = 8, nextId = 59446, preId = 59356, spName = '033.png', }, --普通道具
	['59446'] = { itemType = BoardMeta.ItemTypes.kNaiLei, level = 9, preId = 59357, spName = '113.png', }, --普通道具

	--冰块
	[''..BoardMeta.BingKuai] = { itemType = BoardMeta.ItemTypes.kBingKuai, level = 1, nextId = BoardMeta.BingKuaiLv2, spName = '034.png', }, --普通道具
	[''..BoardMeta.BingKuaiLv2] = { itemType = BoardMeta.ItemTypes.kBingKuai, level = 2, nextId = 59369, preId = BoardMeta.BingKuai, spName = '035.png', }, --普通道具
	['59369'] = { itemType = BoardMeta.ItemTypes.kBingKuai, level = 3, nextId = 59370, preId = BoardMeta.BingKuaiLv2, spName = '036.png', }, --普通道具
	['59370'] = { itemType = BoardMeta.ItemTypes.kBingKuai, level = 4, nextId = 59371, preId = 59369, spName = '037.png', }, --普通道具
	['59371'] = { itemType = BoardMeta.ItemTypes.kBingKuai, level = 5, nextId = 59372, preId = 59370, spName = '038.png', }, --普通道具
	['59372'] = { itemType = BoardMeta.ItemTypes.kBingKuai, level = 6, nextId = 59447, preId = 59371, spName = '039.png', }, --普通道具
	['59447'] = { itemType = BoardMeta.ItemTypes.kBingKuai, level = 7, nextId = 59448, preId = 59372, spName = '114.png', }, --普通道具
	['59448'] = { itemType = BoardMeta.ItemTypes.kBingKuai, level = 8, preId = 59447, spName = '115.png', }, --普通道具

	--面粉
	['59373'] = { itemType = BoardMeta.ItemTypes.kMianShi, level = 1, nextId = 59374, spName = '019.png', }, --普通道具
	['59374'] = { itemType = BoardMeta.ItemTypes.kMianShi, level = 2, nextId = 59375, preId = 59373, spName = '020.png', }, --普通道具
	['59375'] = { itemType = BoardMeta.ItemTypes.kMianShi, level = 3, nextId = 59376, preId = 59374, spName = '021.png', }, --普通道具
	['59376'] = { itemType = BoardMeta.ItemTypes.kMianShi, level = 4, nextId = 59377, preId = 59375, spName = '022.png', }, --普通道具
	['59377'] = { itemType = BoardMeta.ItemTypes.kMianShi, level = 5, nextId = 59378, preId = 59376, spName = '023.png', }, --普通道具
	['59378'] = { itemType = BoardMeta.ItemTypes.kMianShi, level = 6, nextId = 59379, preId = 59377, spName = '024.png', }, --普通道具
	['59379'] = { itemType = BoardMeta.ItemTypes.kMianShi, level = 7, nextId = 59449, preId = 59378, spName = '025.png', }, --普通道具
	['59449'] = { itemType = BoardMeta.ItemTypes.kMianShi, level = 8, preId = 59379, spName = '112.png', }, --普通道具

	--菜品1
	['59380'] = { itemType = BoardMeta.ItemTypes.kCaiPin1, level = 1, spName = '044.png', }, --菜品
	['59381'] = { itemType = BoardMeta.ItemTypes.kCaiPin1, level = 2, spName = '045.png', }, --菜品
	['59382'] = { itemType = BoardMeta.ItemTypes.kCaiPin1, level = 3, spName = '046.png', }, --菜品
	['59383'] = { itemType = BoardMeta.ItemTypes.kCaiPin1, level = 4, spName = '047.png', }, --菜品
	['59384'] = { itemType = BoardMeta.ItemTypes.kCaiPin1, level = 5, spName = '048.png', }, --菜品
	['59385'] = { itemType = BoardMeta.ItemTypes.kCaiPin1, level = 6, spName = '049.png', }, --菜品

	--菜品2
	['59386'] = { itemType = BoardMeta.ItemTypes.kCaiPin2, level = 1, spName = '050.png', }, --菜品
	['59387'] = { itemType = BoardMeta.ItemTypes.kCaiPin2, level = 2, spName = '051.png', }, --菜品
	['59388'] = { itemType = BoardMeta.ItemTypes.kCaiPin2, level = 3, spName = '052.png', }, --菜品
	['59389'] = { itemType = BoardMeta.ItemTypes.kCaiPin2, level = 4, spName = '053.png', }, --菜品
	['59390'] = { itemType = BoardMeta.ItemTypes.kCaiPin2, level = 5, spName = '054.png', }, --菜品
	['59391'] = { itemType = BoardMeta.ItemTypes.kCaiPin2, level = 6, spName = '055.png', }, --菜品

	--菜品3
	['59392'] = { itemType = BoardMeta.ItemTypes.kCaiPin3, level = 1, spName = '056.png', }, --菜品
	['59393'] = { itemType = BoardMeta.ItemTypes.kCaiPin3, level = 2, spName = '057.png', }, --菜品
	['59394'] = { itemType = BoardMeta.ItemTypes.kCaiPin3, level = 3, spName = '058.png', }, --菜品
	['59395'] = { itemType = BoardMeta.ItemTypes.kCaiPin3, level = 4, spName = '059.png', }, --菜品
	['59396'] = { itemType = BoardMeta.ItemTypes.kCaiPin3, level = 5, spName = '060.png', }, --菜品
	['59397'] = { itemType = BoardMeta.ItemTypes.kCaiPin3, level = 6, spName = '061.png', }, --菜品

	--菜品4
	['59398'] = { itemType = BoardMeta.ItemTypes.kCaiPin4, level = 1, spName = '062.png', }, --菜品
	['59399'] = { itemType = BoardMeta.ItemTypes.kCaiPin4, level = 2, spName = '063.png', }, --菜品
	['59400'] = { itemType = BoardMeta.ItemTypes.kCaiPin4, level = 3, spName = '064.png', }, --菜品
	['59401'] = { itemType = BoardMeta.ItemTypes.kCaiPin4, level = 4, spName = '065.png', }, --菜品
	['59402'] = { itemType = BoardMeta.ItemTypes.kCaiPin4, level = 5, spName = '066.png', }, --菜品
	['59403'] = { itemType = BoardMeta.ItemTypes.kCaiPin4, level = 6, spName = '067.png', }, --菜品

	--菜品5
	-- 山西菜已经清除了

	--特殊道具
	[''..BoardMeta.MagicItemEnergy] = { itemType = BoardMeta.ItemTypes.kMagicItem, energyTimeSec = 20, spName = '070.png', }, --特殊道具 无限体力
	[''..BoardMeta.MagicItemJianDao]  = { itemType = BoardMeta.ItemTypes.kMagicItem, spName = '069.png', }, --特殊道具 剪刀
	[''..BoardMeta.MagicItemMiaoBiao]  = { itemType = BoardMeta.ItemTypes.kMagicItem, spName = '068.png', }, --特殊道具 秒表
	[''..BoardMeta.MagicItemShengji]  = { itemType = BoardMeta.ItemTypes.kMagicItem, spName = '071.png', }, --特殊道具 升级卡

	--饺子
	[''..BoardMeta.JiaoziLv1_v1] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 1, week=1, nextId = BoardMeta.JiaoziLv2_v1, spName = '116.png', }, --普通道具
	[''..BoardMeta.JiaoziLv2_v1] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 2, week=1, nextId = BoardMeta.JiaoziLv3_v1, preId = BoardMeta.JiaoziLv1_v1, spName = '117.png', }, --普通道具
	[''..BoardMeta.JiaoziLv3_v1] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 3, week=1, nextId = BoardMeta.JiaoziLv4_v1, preId = BoardMeta.JiaoziLv2_v1, spName = '118.png', }, --普通道具
	[''..BoardMeta.JiaoziLv4_v1] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 4, week=1, preId = BoardMeta.JiaoziLv3_v1, spName = '119.png', }, --普通道具

	[''..BoardMeta.JiaoziLv1_v2] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 1, week=2, nextId = BoardMeta.JiaoziLv2_v2, spName = '116.png', }, --普通道具
	[''..BoardMeta.JiaoziLv2_v2] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 2, week=2, nextId = BoardMeta.JiaoziLv3_v2, preId = BoardMeta.JiaoziLv1_v2, spName = '117.png', }, --普通道具
	[''..BoardMeta.JiaoziLv3_v2] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 3, week=2, nextId = BoardMeta.JiaoziLv4_v2, preId = BoardMeta.JiaoziLv2_v2, spName = '118.png', }, --普通道具
	[''..BoardMeta.JiaoziLv4_v2] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 4, week=2, preId = BoardMeta.JiaoziLv3_v2, spName = '119.png', }, --普通道具

	[''..BoardMeta.JiaoziLv1_v3] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 1, week=3, nextId = BoardMeta.JiaoziLv2_v3, spName = '116.png', }, --普通道具
	[''..BoardMeta.JiaoziLv2_v3] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 2, week=3, nextId = BoardMeta.JiaoziLv3_v3, preId = BoardMeta.JiaoziLv1_v3, spName = '117.png', }, --普通道具
	[''..BoardMeta.JiaoziLv3_v3] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 3, week=3, nextId = BoardMeta.JiaoziLv4_v3, preId = BoardMeta.JiaoziLv2_v3, spName ='118.png', }, --普通道具
	[''..BoardMeta.JiaoziLv4_v3] = { itemType = BoardMeta.ItemTypes.kJiaoZi, level = 4, week=3, preId = BoardMeta.JiaoziLv3_v3, spName = '119.png', }, --普通道具

	--自选宝箱
	[''..BoardMeta.zixuanBox ] = { itemType = BoardMeta.ItemTypes.kSpecialItem, level = 4, spName = '092.png', }, --特殊道具

	--体力瓶
	[''..BoardMeta.EnergyBottleLv1] = { itemType = BoardMeta.ItemTypes.kMagicItem, level = 1, nextId = BoardMeta.EnergyBottleLv2, spName = '122.png', }, --特殊道具
	[''..BoardMeta.EnergyBottleLv2] = { itemType = BoardMeta.ItemTypes.kMagicItem, level = 2, nextId = BoardMeta.EnergyBottleLv3, preId = BoardMeta.EnergyBottleLv1, spName = '123.png', }, --特殊道具
	[''..BoardMeta.EnergyBottleLv3] = { itemType = BoardMeta.ItemTypes.kMagicItem, level = 3, nextId = BoardMeta.EnergyBottleLv4, preId = BoardMeta.EnergyBottleLv2, spName = '124.png', }, --特殊道具
	[''..BoardMeta.EnergyBottleLv4] = { itemType = BoardMeta.ItemTypes.kMagicItem, level = 4, nextId = BoardMeta.EnergyBottleLv5, preId = BoardMeta.EnergyBottleLv3, spName = '125.png', }, --特殊道具
	[''..BoardMeta.EnergyBottleLv5] = { itemType = BoardMeta.ItemTypes.kMagicItem, level = 5, nextId = BoardMeta.EnergyBottleLv6, preId = BoardMeta.EnergyBottleLv4, spName = '126.png', }, --特殊道具
	[''..BoardMeta.EnergyBottleLv6] = { itemType = BoardMeta.ItemTypes.kMagicItem, level = 6, preId = BoardMeta.EnergyBottleLv5, spName = '127.png', }, --特殊道具

	--体力宝箱
	[''..BoardMeta.LowEnergyBox] = { itemType = BoardMeta.ItemTypes.kMagicItem, level = 1, nextId = BoardMeta.HighEnergyBox, spName = '120.png', }, --特殊道具
	[''..BoardMeta.HighEnergyBox] = { itemType = BoardMeta.ItemTypes.kMagicItem, level = 2, preId = BoardMeta.LowEnergyBox, spName = '121.png', }, --特殊道具

	--枣泥
	[''..BoardMeta.ZaoniGao] = { itemType = BoardMeta.ItemTypes.kDianXin, level = 1, nextId = 59426, spName = '080.png', }, --普通道具
	['59426'] = { itemType = BoardMeta.ItemTypes.kDianXin, level = 2, nextId = 59427, preId = BoardMeta.ZaoniGao, spName = '081.png', }, --普通道具
	['59427'] = { itemType = BoardMeta.ItemTypes.kDianXin, level = 3, nextId = 59428, preId = 59426, spName = '082.png', }, --普通道具
	['59428'] = { itemType = BoardMeta.ItemTypes.kDianXin, level = 4, nextId = 59429, preId = 59427, spName = '083.png', }, --普通道具
	['59429'] = { itemType = BoardMeta.ItemTypes.kDianXin, level = 5, nextId = 59430, preId = 59428, spName = '084.png', }, --普通道具
	['59430'] = { itemType = BoardMeta.ItemTypes.kDianXin, level = 6, nextId = 59431, preId = 59429, spName = '085.png', }, --普通道具
	['59431'] = { itemType = BoardMeta.ItemTypes.kDianXin, level = 7, nextId = 59432, preId = 59430, spName = '086.png', }, --普通道具
	['59432'] = { itemType = BoardMeta.ItemTypes.kDianXin, level = 8, preId = 59431, spName = '087.png', }, --普通道具

	--茶
	[''..BoardMeta.JuhuaCha] = { itemType = BoardMeta.ItemTypes.kCha, level = 1, nextId = 59434, spName = '097.png', }, --普通道具
	['59434'] = { itemType = BoardMeta.ItemTypes.kCha, level = 2, nextId = 59435, preId = BoardMeta.JuhuaCha, spName = '098.png', }, --普通道具
	['59435'] = { itemType = BoardMeta.ItemTypes.kCha, level = 3, nextId = 59436, preId = 59434, spName = '099.png', }, --普通道具
	['59436'] = { itemType = BoardMeta.ItemTypes.kCha, level = 4, nextId = 59437, preId = 59435, spName = '100.png', }, --普通道具
	['59437'] = { itemType = BoardMeta.ItemTypes.kCha, level = 5, preId = 59436, spName = '101.png', }, --普通道具
}

--不计入图鉴的道具
BoardMeta.noJoinTuJianItemIds = {
	BoardMeta.JiaoziLv1_v1,
	BoardMeta.JiaoziLv2_v1,
	BoardMeta.JiaoziLv3_v1,
	BoardMeta.JiaoziLv4_v1,

	BoardMeta.JiaoziLv1_v2,
	BoardMeta.JiaoziLv2_v2,
	BoardMeta.JiaoziLv3_v2,
	BoardMeta.JiaoziLv4_v2,

	BoardMeta.JiaoziLv1_v3,
	BoardMeta.JiaoziLv2_v3,
	BoardMeta.JiaoziLv3_v3,
	BoardMeta.JiaoziLv4_v3,

	BoardMeta.zixuanBox,
	BoardMeta.EnergyBottleLv1,
	BoardMeta.EnergyBottleLv2,
	BoardMeta.EnergyBottleLv3,
	BoardMeta.EnergyBottleLv4,
	BoardMeta.EnergyBottleLv5,
	BoardMeta.EnergyBottleLv6,
	BoardMeta.LowEnergyBox,
	BoardMeta.HighEnergyBox,
}

BoardMeta.allJiaoziIdList = {
	BoardMeta.JiaoziLv1_v1,
	BoardMeta.JiaoziLv2_v1,
	BoardMeta.JiaoziLv3_v1,
	BoardMeta.JiaoziLv4_v1,

	BoardMeta.JiaoziLv1_v2,
	BoardMeta.JiaoziLv2_v2,
	BoardMeta.JiaoziLv3_v2,
	BoardMeta.JiaoziLv4_v2,

	BoardMeta.JiaoziLv1_v3,
	BoardMeta.JiaoziLv2_v3,
	BoardMeta.JiaoziLv3_v3,
	BoardMeta.JiaoziLv4_v3,
}

BoardMeta.jiaoziLevelList = {
	[1] = { BoardMeta.JiaoziLv1_v1, BoardMeta.JiaoziLv1_v2, BoardMeta.JiaoziLv1_v3 },
	[2] = { BoardMeta.JiaoziLv2_v1, BoardMeta.JiaoziLv2_v2, BoardMeta.JiaoziLv2_v3 },
	[3] = { BoardMeta.JiaoziLv3_v1, BoardMeta.JiaoziLv3_v2, BoardMeta.JiaoziLv3_v3 },
	[4] = { BoardMeta.JiaoziLv4_v1, BoardMeta.JiaoziLv4_v2, BoardMeta.JiaoziLv4_v3 },
}

--拖动类型
BoardMeta.TouchType = {
	kNone = 0,
	kDrag = 1,
	kClick = 2,
}

function BoardMeta:getItemMakerCanMakeItem( itemId )
	--检测发射器是否可以发射道具
	local cantMakeItemIds = { }

	if table.exist( cantMakeItemIds, itemId ) then
		return false
	end
	return true
end

function BoardMeta:getItemCanMove( itemId )
	--检测道具是否可以被拖动
	local cantMakeItemIds = { }

	if table.exist( cantMakeItemIds, itemId ) then
		return false
	end
	return true
end

-- 根据菜品类型得到菜品/饮品/甜品文案
function BoardMeta:getCaiPinNameByType( itemType )
	local itemTypeName = "菜品"
	if BoardMeta.ItemTypes.kCaiPin1 == itemType then
		itemTypeName = "果酱"
	elseif BoardMeta.ItemTypes.kCaiPin2 == itemType or BoardMeta.ItemTypes.kCaiPin4 == itemType then
		itemTypeName = "菜品"
	elseif BoardMeta.ItemTypes.kCaiPin3 == itemType then
		itemTypeName = "冷饮"
	elseif BoardMeta.ItemTypes.kCaiPin5 == itemType then
		itemTypeName = "菜品"
	end
	return itemTypeName
end

function BoardMeta:checkItemTypeIsNormalItem( itemType )
	--判断是不是普通道具，菜品不是普通道具
	local normalItemTypeList = { BoardMeta.ItemTypes.kGuoShu, BoardMeta.ItemTypes.kRouLei,
		BoardMeta.ItemTypes.kNaiLei, BoardMeta.ItemTypes.kMianShi, BoardMeta.ItemTypes.kBingKuai, BoardMeta.ItemTypes.kJiaoZi, BoardMeta.ItemTypes.kDianXin, BoardMeta.ItemTypes.kCha  }
	local bNormalItem = table.exist( normalItemTypeList, itemType )
	return bNormalItem
end

function BoardMeta:checkItemTypeIsCaiPinItem( itemType )
	--是否是菜品道具
	local caiPinItemTypeList = { BoardMeta.ItemTypes.kCaiPin1, BoardMeta.ItemTypes.kCaiPin2, BoardMeta.ItemTypes.kCaiPin3, BoardMeta.ItemTypes.kCaiPin4, BoardMeta.ItemTypes.kCaiPin5 }
	local bCaiPinItem = table.exist( caiPinItemTypeList, itemType )
	return bCaiPinItem
end

function BoardMeta:checkItemTypeIsMagicItem( itemType )
	--是否是特殊道具
	local caiPinItemTypeList = { BoardMeta.ItemTypes.kMagicItem }
	local bCaiPinItem = table.exist( caiPinItemTypeList, itemType )
	return bCaiPinItem
end

function BoardMeta:checkItemIsEnergyBottle( itemId )
	return table.exist(BoardMeta.EnergyBottleIds, tonumber(itemId))
end

function BoardMeta:checkItemIsEnergyBox( itemId )
	return table.exist(BoardMeta.EnergyBoxIds, tonumber(itemId))
end

function BoardMeta:checkItemIsEnergyProp( itemId )
	return BoardMeta:checkItemIsEnergyBottle(itemId) or BoardMeta:checkItemIsEnergyBox(itemId)
end

function BoardMeta:checkItemTypeIsItemMaker( itemType )
	--是否是发射器
	local caiPinItemTypeList = { BoardMeta.ItemTypes.kItemMaker }
	local bCaiPinItem = table.exist( caiPinItemTypeList, itemType )
	return bCaiPinItem
end

function BoardMeta:checkMagicItemCanMerge( itemId )
	--检测魔法道具是否可以合成
	local magicItemId = tonumber(itemId)
	local canMergeMagicItemIds = { BoardMeta.MagicItemJianDao, BoardMeta.MagicItemMiaoBiao, BoardMeta.MagicItemShengji }
	local itemData = BoardMeta:getItemDataByItemId(magicItemId)
	local energyPropCanMerge = BoardMeta:checkItemIsEnergyProp(magicItemId) and itemData.nextId ~= nil
	local bCanMergeItem = table.exist( canMergeMagicItemIds, magicItemId ) or energyPropCanMerge
	return bCanMergeItem
end

function BoardMeta:checkItemTypeIsJiaoZi( itemType )
	--检测检测是否是饺子类型
	local jiaoziItemTypeList = { BoardMeta.ItemTypes.kJiaoZi }
	local bJiaoZi = table.exist( jiaoziItemTypeList, itemType )
	return bJiaoZi
end

-- itemId是否是无限体力
function BoardMeta:checkItemIsInfinitePower(itemId)
	local mItemId = tonumber(itemId)
	return mItemId == BoardMeta.MagicItemEnergy
end

-- itemId是否是秒表
function BoardMeta:checkItemIsClock(itemId)
	local mItemId = tonumber(itemId)
	return mItemId == BoardMeta.MagicItemMiaoBiao
end

function BoardMeta:checkItemIsShiHeLV1( itemId )
	--检测检测是否是1级食盒
	return BoardMeta.ShiHeLV1 == itemId
end

-- 根据道具id获取他这个对应等级的id
function BoardMeta:getItemLevelIdByItemId(itemId, level)
	local itemData = BoardMeta:getItemDataByItemId(itemId)
	local itemInfoList = BoardMeta:getItemInfoListByType(itemData.itemType)
	local itemInfo = itemInfoList[level]
	if not itemInfo then
		return nil
	end
	return itemInfo.itemId
end

-- 根据生成物itemId获取发射器itemid
function BoardMeta:getMakerIdByItemId(itemId)
    local itemData = BoardMeta:getItemDataByItemId(itemId)
    local itemList = BoardMeta:getItemListByType(itemData.itemType)
    local firstItemId = table.find(itemList, function(v)
        return BoardMeta:getItemDataByItemId(v).level == 1
    end)

    local makerList = BoardMeta:getItemListByType(BoardMeta.ItemTypes.kItemMaker)

    local makerIds = {}
    for i,v in ipairs(makerList) do
    	if table.exist(BoardMeta:getItemDataByItemId(v).makeItemList, tonumber(firstItemId)) then
    		table.insert( makerIds, v )
    	end

    	if table.exist(BoardMeta:getItemDataByItemId(v).makeExtraItem, tonumber(firstItemId)) then
    		table.insert( makerIds, v )
    	end
    end


    return makerIds
end

function BoardMeta:getItemTypeListBy( itemId )
	--根据id获取他对应类型的所有道具
	--如果是生成器，找出生成器生成的列表
	local itemData = BoardMeta:getItemDataByItemId(itemId)
	local itemType = itemData.itemType

	local itemInfoList = {}
	if itemType == BoardMeta.ItemTypes.kItemMaker then
		--生成器，要把他生成的几样物品列表都找出
		local makeItemList = itemData.makeItemList

		for i,v in ipairs(makeItemList) do
			local makeItemData = BoardMeta:getItemDataByItemId(v)
			local makeItemType = makeItemData.itemType

			local itemList = BoardMeta:getItemListByType(makeItemType)
			local typeInfoList = { itemType = makeItemType, itemList = itemList }
			table.insert( itemInfoList, typeInfoList )
		end
	else
		local itemList = BoardMeta:getItemListByType(itemType)
		local typeInfoList = { itemType = itemType, itemList = itemList }
		table.insert( itemInfoList, typeInfoList )
	end

	return itemInfoList
end

function BoardMeta:getItemMakerList(  )
	--获取生成器列表
	local itemList = BoardMeta:getItemListByType( BoardMeta.ItemTypes.kItemMaker)
	return itemList
end

function BoardMeta:getItemInfoListByType( itemType )
	--根据类型找出所有符合的道具
	local itemInfoList = {}
	for i,v in pairs(BoardMeta.ItemData) do
		if v.itemType == itemType then
			local info = table.clone(v)
			info.itemId = tonumber(i)
			table.insert( itemInfoList, info )
		end
	end

	local function sortFunc(a,b)
		return a.level < b.level
	end
	table.sort(itemInfoList, sortFunc)

	return itemInfoList
end

function BoardMeta:getItemListByType( itemType )
	--根据类型找出所有符合的道具
	local itemList = {}
	for i,v in pairs(BoardMeta.ItemData) do
		if v.itemType == itemType then
			table.insert( itemList, tonumber(i) )
		end
	end

	return itemList
end

function BoardMeta:getItemDataByItemId( itemId )
	--根据id找出数据
	if BoardMeta.ItemData[''..itemId] then
		return BoardMeta.ItemData[''..itemId]
	end

	if EnvUtil:isDevelopMode() then
		--理论本地配置必找到
		-- printx(12, '找不到这个id的配置啊 id=',itemId)
	end
	return {}
end


local allItemList = {}
function BoardMeta:getAllItemList(  )
	--获取所有的道具列表
	if table.isEmpty(allItemList) then
		for i,v in pairs(BoardMeta.ItemData) do
			local itemId = tonumber(i)
			table.insert(allItemList, itemId)
		end
	end

	return allItemList
end

function BoardMeta:checkIsMergeItem( itemId )
	local allBoardItemList = BoardMeta:getAllItemList()
	if table.exist(allBoardItemList, itemId) then
		return true
	end
	return false
end

local allHandBookItemList = {}
function BoardMeta:getAllHandBookItemList(  )
	--获取所有的图鉴道具列表
	if table.isEmpty(allHandBookItemList) then
		for i,v in pairs(BoardMeta.ItemData) do
			local itemId = tonumber(i)

			if not table.exist( BoardMeta.noJoinTuJianItemIds,itemId ) then
				table.insert(allHandBookItemList, itemId)
			end
		end
	end

	return allHandBookItemList
end

function BoardMeta:getMergeItemSpName( itemId, extra )
	--根据id获取素材 frameName
	if extra == nil then extra = {} end

	local weekIndex = 1
	if extra.weekIndex then
		weekIndex = extra.weekIndex
	end

	local endTime = 0
	if extra.endTime then
		endTime = extra.endTime
	end

	local itemData = BoardMeta:getItemDataByItemId(itemId)
	if not table.isEmpty(itemData) then
		local spName = itemData.spName
		return 'mergeItems/'..spName
	else
		--默认给一个
		return 'mergeItems/001.png'
	end
end

function BoardMeta:getMergeItemSpNameByScale(itemId, bUseScale60, weekIndex)
    local name = self:getMergeItemSpName(itemId,{ weekIndex = weekIndex })

    --废弃了，使用一套图
    -- local newItemList = {72,73,74,75}
    -- if not bUseScale60 then
    --     local id = string.match(name, '/(%d+)%.png')
    --     if id and not table.exist(newItemList, tonumber(id))  then
    --         name = string.gsub(name, '%.png$', '_s.png')
    --     end
    -- end
    return name
end

function BoardMeta:getLockSpName( lockLv )
	--获取道具锁的素材，汉堡合或者一个条
	if lockLv == 1 then
		return 'mergeItems/073.png'
	else
		return 'mergeItems/072.png'
	end
end


function BoardMeta:posTurnToRowCol( pos )
	--位置转换行列
	local col = pos%BoardMeta.BoardWidthNum
	if col == 0 then col = BoardMeta.BoardWidthNum end

	local row = math.floor( (pos-1)/BoardMeta.BoardWidthNum ) + 1

	return row, col
end

function BoardMeta:rowColTurnToPos( row, col )
	--行列转换 pos
	if row <= 0 or col <= 0 then
		return -1
	end
	if row > BoardMeta.BoardHeightNum or col > BoardMeta.BoardWidthNum then
		return -1
	end

	local pos = (row-1)*BoardMeta.BoardWidthNum + col
	return pos
end

function BoardMeta:trunToServerXY( row, col )
	--转换成后端需要的坐标
	return IntCoord:create( row-1, col-1 )
end

function BoardMeta:trunToServerPos( row, col )
	--转换成后端需要的位置
	return row*10+col
end
--

-- 是否是顶级食材
function BoardMeta:isTopItem(itemId)
	if itemId == nil then return false end
	local itemData = self:getItemDataByItemId(itemId)
	local isNormalItem = self:checkItemTypeIsNormalItem(itemData.itemType)
	if isNormalItem then
		return itemData.nextId == nil
	end
	return false
end

function BoardMeta:getJiaoziIdByWeek( week, jiaoziv1Id )

	local weekLv1List = self.jiaoziLevelList[1]--{ BoardMeta.JiaoziLv1_v1, BoardMeta.JiaoziLv1_v2, BoardMeta.JiaoziLv1_v3 }
	local weekLv2List = self.jiaoziLevelList[2]--{ BoardMeta.JiaoziLv2_v1, BoardMeta.JiaoziLv2_v2, BoardMeta.JiaoziLv2_v3 }
	local weekLv3List = self.jiaoziLevelList[3]--{ BoardMeta.JiaoziLv3_v1, BoardMeta.JiaoziLv3_v2, BoardMeta.JiaoziLv3_v3 }
	local weekLv4List = self.jiaoziLevelList[4]--{ BoardMeta.JiaoziLv4_v1, BoardMeta.JiaoziLv4_v2, BoardMeta.JiaoziLv4_v3 }

	if table.exist( weekLv1List, jiaoziv1Id ) then
		return weekLv1List[week] or weekLv1List[1]
	elseif table.exist( weekLv2List, jiaoziv1Id ) then
		return weekLv2List[week] or weekLv2List[1]
	elseif table.exist( weekLv3List, jiaoziv1Id ) then
		return weekLv3List[week] or weekLv3List[1]
	elseif table.exist( weekLv4List, jiaoziv1Id ) then
		return weekLv4List[week] or weekLv3List[1]
	end
end

function BoardMeta:getYuanBaoConfigIdByDumplingId(id)
    if table.exist(self.jiaoziLevelList[1], id) then
        return 1
    elseif table.exist(self.jiaoziLevelList[2], id) then
        return 2
    elseif table.exist(self.jiaoziLevelList[3], id) then
        return 3
    elseif table.exist(self.jiaoziLevelList[4], id) then
        return 4
    else
        return 0
    end
end

function BoardMeta:fixSpecialItemScale( itemId, srcScale )
	-- local specialItemIdList = { BoardMeta.MagicItemEnergy, BoardMeta.MagicItemJianDao, BoardMeta.MagicItemMiaoBiao, BoardMeta.MagicItemShengji }
	
	-- if table.exist( specialItemIdList, itemId ) then
	-- 	return srcScale*0.9
	-- end
	return srcScale
end

return BoardMeta
