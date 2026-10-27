local Meta = {}
Meta.actId = 9087
Meta.actKey = "9087"

Meta.ClientVersion = 5 --jika
Meta.CustomColorCfg = {
    bgColor = "519bb0ff",
    titleColor = "206384ff",
}

Meta.infoPrefix = "userInfo"
Meta.configPrefix = "localConfig"
Meta.timePrefix = "actTime"
Meta.dcFeature = "collect_card"
Meta.needLoadFiles = {
}

Meta.Guide = {
    ID_1 = 1,
    -- ID_2 = 2,
}

Meta.CardType = {
    SILVER = 1,
    GOLD = 2,
}

Meta.CardDisplayState = {
    SEEK_HELP = 1,
    GIFTABLE = 2,
    COOLDOWN = 3,
    UNGIFTABLE = 4,
}

Meta.FriendSelectMode = {
    ASK = "ask",
    GIVE = "give",
}

Meta.LocalCacheKey = {
    FRIEND_SELECT_EXCHANGE_ENABLED = "friendSelectExchangeEnabled_",
    FRIEND_SELECT_EXCHANGE_TIP_SHOWN = "friendSelectExchangeTipShown_",
    STAR_EXCHANGE_MANUAL_SELECT = "starExchangeManualSelect_",
    SWAP_ACCEPT_DISABLED_MESSAGES = "swapAcceptDisabledMessages",
}

Meta.SwapCreateType = {
    HELP = 1,
    GIFT = 2,
    EXCHANGE = 3,
}

Meta.TransferConfirmMode = {
    GIFT = "gift",
    EXCHANGE_REQUEST = "exchangeRequest",
    EXCHANGE_FINAL = "exchangeFinal",
}

Meta.SwapOperateType = {
    ACCEPT = 1,
    REJECT = 2,
    CANCEL = 3,
    IGNORE = 4,
}

-- 客户端收到的完整错误码，已包含业务错误码前的 73 前缀。
Meta.SwapErrorCode = {
    SEND_LIMIT = 734675,         -- 今日赠送和交换参与次数已用完
    RECEIVE_LIMIT = 734676,      -- 今日对应接收次数已用完
    MESSAGE_NOT_FOUND = 734677, -- 消息不存在
    MESSAGE_EXPIRED = 734678,   -- 消息已失效
    OP_NOT_ALLOWED = 734679,    -- 当前不能执行该操作
    HELP_FINISHED = 734681,     -- 对方已经完成或取消
    EXCHANGE_SELF_LIMIT = 734684, -- 你的交换次数已达上限
    EXCHANGE_TARGET_LIMIT = 734685, -- 对方交换次数已达上限
    MESSAGE_RECALLED = 734686,  -- 对方已撤回
    MESSAGE_REFRESHED = 734687, -- 消息内容已刷新，请重试
}

-- 这些错误表示当前消息的接受类操作暂不可继续，按 messageId 记录本地禁用状态。
Meta.SwapAcceptDisabledErrorCodes = {
    [Meta.SwapErrorCode.SEND_LIMIT] = true,
    [Meta.SwapErrorCode.RECEIVE_LIMIT] = true,
    [Meta.SwapErrorCode.EXCHANGE_SELF_LIMIT] = true,
    [Meta.SwapErrorCode.EXCHANGE_TARGET_LIMIT] = true,
}

-- 这些错误表示消息已无法继续操作，收到后立即从本地消息列表移除。
Meta.SwapTerminalErrorCodes = {
    [Meta.SwapErrorCode.MESSAGE_NOT_FOUND] = true,
    [Meta.SwapErrorCode.MESSAGE_EXPIRED] = true,
    [Meta.SwapErrorCode.HELP_FINISHED] = true,
    [Meta.SwapErrorCode.MESSAGE_RECALLED] = true,
}

-- 这些错误只关闭当前操作面板，不删除本地消息或主动刷新协议。
Meta.SwapClosePanelErrorCodes = {
    [Meta.SwapErrorCode.OP_NOT_ALLOWED] = true,
    [Meta.SwapErrorCode.MESSAGE_REFRESHED] = true,
}

Meta.SwapMessageState = {
    WAIT_RECEIVER = 1,
    WAIT_CREATOR_CONFIRM = 2,
    REJECTED = 4,
    IGNORED = 6,
}

Meta.SwapMessageDirection = {
    SENT = "sent",
    RECEIVED = "received",
}

Meta.ShareImageMode = {
    DYNAMIC = "dynamic",
    FIXED_CDN = "fixed_cdn",
}

Meta.CommunityKind = {
    APP = "app",
    WECHAT = "wechat",
    ALIPAY = "alipay",
}

Meta.PlatformShare = {
    SHARE_TYPE = "collect_card_ask",
    TEMPLATE_PATH = "amf/activity/collectcard/materials/share/AskHelpShareTemplate.png",
    FIXED_IMAGE = "collectcard/askHelpShare.png",
    APP_COMMUNITY_URL = "https://ff.happyelements.com/mobile/page/subject.html?app=1001&subject=%E5%BC%80%E5%BF%83%E6%8D%A2%E5%8D%A1%E4%BA%92%E5%8A%A9",
    WECHAT_GAME_CLUB_LINK = "iejxAOapMZip81wzejfkBfrzZqfEV3vYR1BscWm6QTHDQ6RuMWtPenZHAbUYud3rAZhHI03qXGiTYqT41hBaeh0wTi6V08MW8CmmdQPGFpNHPjLcxbxZH3UajbpXqsd7uFno5fTvwLImarhyOABg-vXUp0-1WSxoett93BZ_dM4VQmzSD2EFLeAVBPzNAIv2nm_rfCKLR7Hw8JeFa9WkpyiIj_YD2ghwgbY349zO17thsuS54LU8yzAYuTm6JdiL75jJ6xBj5yHJmxYySuZegy584flZDOmCfT5LwxS93CD5JToz0_8MDh-OK3C2--PS2cmwceNU7UbHIjcBcelGPzHUVrpnssq1IWf6DRNXwdI",
    ALIPAY_TOPIC_ID = "20260814TP22835154_0001",
}

Meta.Sound = {
    CLICK_COMMON_01 = 1,    -- 通用点击1
    TURN_PAGE = 2,          -- 翻页
    GIFT_BANNER = 3,
    GIFT_TWEEN_BIG = 4,
    GIFT_TXT_COMP = 5,
    FIREWORKS = 6,          -- 礼花
    CARDPACK_APPEAR = 7,          -- 卡包出现
    CARDPACK_TOGETHER = 8,          -- 卡包聚拢
    CARDPACK_MOVEDOWN = 9,          -- 卡包落下
    CARDPACK_SLICE = 10,          -- 卡包滑动
    MOVE_NEW_CARD_1 = 11,          -- 新卡移动1
    MOVE_NEW_CARD_2 = 12,          -- 新卡移动2
    MOVE_NEW_CARD_3 = 13,          -- 新卡移动3
    MOVE_NEW_CARD_4 = 14,          -- 新卡移动4
    MOVE_NEW_CARD_5 = 15,          -- 新卡移动5
    MOVE_NEW_CARD_6 = 16,          -- 新卡移动6
    MOVE_REPEAT_CARD = 17,          -- 重复卡移动
    CARD_CONVERT = 18,          -- 卡片转换
    STAR_TO_BAG = 19,          -- 星星飞向背包
    STAR_IN_BAG = 20,          -- 星星入背包
    SKIP_SHOW_CARD = 21,          -- 跳过展示卡片
    ALBUM_FINISH = 22,          -- 卡册完成
    ALBUM_FINISH_SHOW = 23,          -- 卡册完成展示
    ALBUM_TITLE_DOWN = 24,          -- 卡册完成标题落下
    ALBUM_NODE_SHOW = 25,          -- 卡册出现
    ALBUM_PROGRESS_UP = 26,          -- 卡册进度提升
    ALBUM_NODE_SHOW_CHECK = 27,          -- 卡册完成打勾
    ALBUM_SHOW_REWARD = 28,          -- 卡册展示奖励
    ROUND_FINISH = 29,          -- 轮次完成
    ROUND_FINISH_SHOW = 30,          -- 轮次完成展示
    ROUND_FINISH_TITLE_DOWN = 31,          -- 轮次完成标题落下
    ROUND_FINISH_SHOW_HEAD = 32,          -- 轮次完成展示头像
    ROUND_FINISH_OPEN_BOX = 33,          -- 轮次完成开箱子
    ROUND_FINISH_NICKNAME = 34,          -- 轮次完成展示昵称
    ROUND_FINISH_SHOW_GOLD = 35,          -- 轮次完成展示金币
    ROUND_FINISH_SHOW_REWARD = 36,          -- 轮次完成展示奖励
    NEXT_ROUND_PROGRESS = 37,          -- 下一轮进度
    NEXT_ROUND_PROGRESS_BLINK = 38,          -- 下一轮进度闪烁
    NEXT_ROUND_SHOW_TITLE = 39,          -- 下一轮展示标题
    NEXT_ROUND_SHOW_REWARD = 40,          -- 下一轮展示奖励
}

local SoundRoot = "amf/activity/collectcard/sound/"
Meta.SoundPath = {
    [Meta.Sound.CLICK_COMMON_01] = SoundRoot .. "click_common_01.mp3",
    [Meta.Sound.TURN_PAGE] = SoundRoot .. "turn_page.mp3",
    [Meta.Sound.GIFT_BANNER] = SoundRoot .. "gift_banner.mp3",
    [Meta.Sound.GIFT_TWEEN_BIG] = SoundRoot .. "gift_tween_big.mp3",
    [Meta.Sound.GIFT_TXT_COMP] = SoundRoot .. "gift_txt_comp.mp3",
    [Meta.Sound.FIREWORKS] = SoundRoot .. "fireworks.mp3",
    [Meta.Sound.CARDPACK_APPEAR] = SoundRoot .. "cardpackappear.mp3",
    [Meta.Sound.CARDPACK_TOGETHER] = SoundRoot .. "cardpacktogether.mp3",
    [Meta.Sound.CARDPACK_MOVEDOWN] = SoundRoot .. "cardpackmovedown.mp3",
    [Meta.Sound.CARDPACK_SLICE] = SoundRoot .. "cardpackslice.mp3",
    [Meta.Sound.MOVE_NEW_CARD_1] = SoundRoot .. "movenewcard_1.mp3",
    [Meta.Sound.MOVE_NEW_CARD_2] = SoundRoot .. "movenewcard_2.mp3",
    [Meta.Sound.MOVE_NEW_CARD_3] = SoundRoot .. "movenewcard_3.mp3",
    [Meta.Sound.MOVE_NEW_CARD_4] = SoundRoot .. "movenewcard_4.mp3",
    [Meta.Sound.MOVE_NEW_CARD_5] = SoundRoot .. "movenewcard_5.mp3",
    [Meta.Sound.MOVE_NEW_CARD_6] = SoundRoot .. "movenewcard_6.mp3",
    [Meta.Sound.MOVE_REPEAT_CARD] = SoundRoot .. "moverepeatcard.mp3",
    [Meta.Sound.CARD_CONVERT] = SoundRoot .. "cardconvert.mp3",
    [Meta.Sound.STAR_TO_BAG] = SoundRoot .. "startobag.mp3",
    [Meta.Sound.STAR_IN_BAG] = SoundRoot .. "starinbag.mp3",
    [Meta.Sound.SKIP_SHOW_CARD] = SoundRoot .. "skipshowcard.mp3",
    [Meta.Sound.ALBUM_FINISH] = SoundRoot .. "albumfinish.mp3",
    [Meta.Sound.ALBUM_FINISH_SHOW] = SoundRoot .. "albumfinishshow.mp3",
    [Meta.Sound.ALBUM_TITLE_DOWN] = SoundRoot .. "albumtitledown.mp3",
    [Meta.Sound.ALBUM_NODE_SHOW] = SoundRoot .. "albumnodeshow.mp3",
    [Meta.Sound.ALBUM_PROGRESS_UP] = SoundRoot .. "albumprogressup.mp3",
    [Meta.Sound.ALBUM_NODE_SHOW_CHECK] = SoundRoot .. "albumnodeshowcheck.mp3",
    [Meta.Sound.ALBUM_SHOW_REWARD] = SoundRoot .. "albumshowreward.mp3",
    [Meta.Sound.ROUND_FINISH] = SoundRoot .. "roundfinish.mp3",
    [Meta.Sound.ROUND_FINISH_SHOW] = SoundRoot .. "roundfinishshow.mp3",
    [Meta.Sound.ROUND_FINISH_TITLE_DOWN] = SoundRoot .. "roundfinishtitledown.mp3",
    [Meta.Sound.ROUND_FINISH_SHOW_HEAD] = SoundRoot .. "roundfinishshowhead.mp3",
    [Meta.Sound.ROUND_FINISH_OPEN_BOX] = SoundRoot .. "roundfinishopenbox.mp3",
    [Meta.Sound.ROUND_FINISH_NICKNAME] = SoundRoot .. "roundfinishnickname.mp3",
    [Meta.Sound.ROUND_FINISH_SHOW_GOLD] = SoundRoot .. "roundfinishshowgold.mp3",
    [Meta.Sound.ROUND_FINISH_SHOW_REWARD] = SoundRoot .. "roundfinishshowreward.mp3",
    [Meta.Sound.NEXT_ROUND_PROGRESS] = SoundRoot .. "nextroundprogress.mp3",
    [Meta.Sound.NEXT_ROUND_PROGRESS_BLINK] = SoundRoot .. "nextroundprogressblink.mp3",
    [Meta.Sound.NEXT_ROUND_SHOW_TITLE] = SoundRoot .. "nextroundshowtitle.mp3",
    [Meta.Sound.NEXT_ROUND_SHOW_REWARD] = SoundRoot .. "nextroundshowreward.mp3",
}

Meta.Haptics = {
    BUTTON_NORMAL = require "amf.feature.localactivity.collectcard.haptics.ButtonNormal",
    TEAR_OPEN = require "amf.feature.localactivity.collectcard.haptics.TearOpen",        -- 撕开
    NEW_CARD_DROP = require "amf.feature.localactivity.collectcard.haptics.NewCardDrop", -- 新卡掉落
    CARD_DROP = require "amf.feature.localactivity.collectcard.haptics.CardDrop",        -- 普卡掉落
    STAR_DROP = require "amf.feature.localactivity.collectcard.haptics.StarDrop",        -- 星星掉落
}

-- Meta.ResourceVersion = 1 -- 前端资源版本号，按period区分，添加资源后需要新增PeriodMeta_xx.lua
Meta.MinTopPassedLevel = 210 -- 活动最低开启等级

Meta.CardPack_1_itemId = 53286
Meta.CardPack_2_itemId = 53287
Meta.CardPack_3_itemId = 53288
Meta.CardPack_4_itemId = 53289
Meta.CardPack_5_itemId = 53290

Meta.RareDecoId = 53281 -- 绝版装饰

Meta.CardPackLevel = {
    [Meta.CardPack_1_itemId] = 1,
    [Meta.CardPack_2_itemId] = 2,
    [Meta.CardPack_3_itemId] = 3,
    [Meta.CardPack_4_itemId] = 4,
    [Meta.CardPack_5_itemId] = 5,
}

-- 素材相关配置 key:periodId value:PeriodMeta
Meta.periodMeta = {
    [1] = require "amf.feature.localactivity.collectcard.config.PeriodMeta_1",
    [2] = require "amf.feature.localactivity.collectcard.config.PeriodMeta_1",
    [3] = require "amf.feature.localactivity.collectcard.config.PeriodMeta_2",
    [4] = require "amf.feature.localactivity.collectcard.config.PeriodMeta_1",
    [5] = require "amf.feature.localactivity.collectcard.config.PeriodMeta_2",
    [6] = require "amf.feature.localactivity.collectcard.config.PeriodMeta_1",
}
Meta.getPeriodMeta = function(periodId)
    return Meta.periodMeta[periodId] or Meta.periodMeta[1]
end

Meta.hasPeriodMeta = function(periodId)
    return Meta.periodMeta[periodId] ~= nil
end



return Meta
