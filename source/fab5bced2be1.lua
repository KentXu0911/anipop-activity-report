_G.WeeklyRaceConst = {}

_G.WeeklyRaceConst.ENABLE_WEEKLY_RACE_TOP_LEVEL = 180 --开启等级
_G.WeeklyRaceConst.WEEKLY_LABEL_ADJUST_START_TIME = "2025-09-22 00:00:00" --周赛文案调整开始时间
_G.WeeklyRaceConst.WEEKLY_RACE_2020_OFFLINE_END_TIME = "2025-12-31 23:59:59" --周赛彻底结束时间
_G.WeeklyRaceConst.WEEKLY_ADJUST_END_TIME = "2025-09-23 00:00:00" --周赛调整结束时间

_G.WeeklyRaceConst.PageShowNameList = {
    "帽子","上衣","下装","面饰","地板","垫子","墙纸","窗户","玩具", "猫", "特效"
}

--换装页面展示顺序
_G.WeeklyRaceConst.DressTabShowList = { 2,3,4,5,6,7,8,9,10,1,11 }

--反向索引，第i页对应的套装序号
_G.WeeklyRaceConst.HandBookShowList = { 14,13,12,11,10,9,8,7,6,1,2,3,4,5 }

--装扮分类
_G.WeeklyRaceConst.DressType = {
    ANIMAL = 1, --猫皮肤
    HAT = 2, --帽子
    JACKET = 3, --上衣
    PANTS = 4, --下装
    FACE_DRESS = 5, --面饰
    FLOOR = 6, --地板
    BLANKET = 7, --毯子
    WALLPAPER = 8, --墙纸
    WINDOW = 9, --窗户
    TOYS = 10, --玩具
    EFFECTS = 11, --特效
}

--获取装扮类型 0-9999 代表猫皮肤 以此类推
function _G.WeeklyRaceConst:getDressType( dressId )
    local dressIndex = math.floor( dressId/10000 )
    return dressIndex + 1
end

--插槽名
_G.WeeklyRaceConst.PetSlotList = {
    'M', --帽子
    'YB', --右臂
    'ZB', --左臂
    'Y', --衣服
    'K',--裤子
    'YD', --右胳膊上阴影
    'ZD', --左胳膊上阴影
    'HJL', --脸饰
    'YXD', --右胳膊下阴影
    'ZXD', --左胳膊下阴影
    'YL', --衣领
}

_G.WeeklyRaceConst.DressSpineInfo = {}
_G.WeeklyRaceConst.DressSpineInfo[1] = {animType = 2, bSkin = true , skinName = "A", petName = "可爱花猫", group = 0, dressRarityType = 1, priority = 1}
_G.WeeklyRaceConst.DressSpineInfo[2] = {animType = 2, bSkin = true , skinName = "C", petName = "乖巧美短", group = 0, dressRarityType = 1, priority = 2}
_G.WeeklyRaceConst.DressSpineInfo[3] = {animType = 2, bSkin = true , skinName = "B", petName = "聪明暹罗", group = 0, dressRarityType = 1, priority = 3}
_G.WeeklyRaceConst.DressSpineInfo[4] = { animType = 2, bSkin = true , skinName = "D", petName = "可爱橘猫", name = "可爱橘猫", group = 0, dressRarityType = 4, priority = 4, buyable = false, tipGroup = 1 }

--hat
_G.WeeklyRaceConst.DressSpineInfo[10001] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "HJM::", group = 1, dressRarityType = 2, priority = 1 }
_G.WeeklyRaceConst.DressSpineInfo[10002] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "TZM::", group = 2, dressRarityType = 2, priority = 2 }
_G.WeeklyRaceConst.DressSpineInfo[10003] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "PGM::", group = 3, dressRarityType = 1, priority = 3 }
_G.WeeklyRaceConst.DressSpineInfo[10004] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "YZM::", group = 4, dressRarityType = 3, priority = 4 }
_G.WeeklyRaceConst.DressSpineInfo[10005] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "ZFM::", group = 5, dressRarityType = 1, priority = 5 }
_G.WeeklyRaceConst.DressSpineInfo[10006] = {  animType = 2, bSkin = false, name = "宝石皇冠", slotName = "M:M2:M3", attachmentName = "HGM::", group = 0, dressRarityType = 3, priority = 6 }
_G.WeeklyRaceConst.DressSpineInfo[10007] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "YRM::", group = 6, dressRarityType = 2, priority = 7 }
_G.WeeklyRaceConst.DressSpineInfo[10009] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "QEM::", group = 7, dressRarityType = 2, priority = 8 }
_G.WeeklyRaceConst.DressSpineInfo[10010] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "NNM::", group = 8, dressRarityType = 3, priority = 9 }
_G.WeeklyRaceConst.DressSpineInfo[10110] = {  animType = 2, bSkin = false, name = "恭喜发财", slotName = "M:M2:M3", attachmentName = "CSM:CSM2:CSM2", group = 0, dressRarityType = 3, priority = 10 }
_G.WeeklyRaceConst.DressSpineInfo[10011] = {  animType = 2, bSkin = false, name = "太空旅行", slotName = "M:M2:M3", attachmentName = "TKM::", group = 9, dressRarityType = 1, priority = 11 }
_G.WeeklyRaceConst.DressSpineInfo[10012] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "JLM::", group = 10, dressRarityType = 1, priority = 12 }
_G.WeeklyRaceConst.DressSpineInfo[10013] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "GZM::", group = 11, dressRarityType = 2, priority = 13 }
_G.WeeklyRaceConst.DressSpineInfo[10014] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "BXM::", group = 12, dressRarityType = 3, priority = 14 }
_G.WeeklyRaceConst.DressSpineInfo[10015] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "JUM::", group = 13, dressRarityType = 3, priority = 15 }
_G.WeeklyRaceConst.DressSpineInfo[10016] = {  animType = 2, bSkin = false, slotName = "M:M2:M3", attachmentName = "XCM::", group = 14, dressRarityType = 2, priority = 16 }

--coat
_G.WeeklyRaceConst.DressSpineInfo[20001] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "HJY:HJB:HJB:HJD:HJD", group = 1, dressRarityType = 2, priority = 1 }
_G.WeeklyRaceConst.DressSpineInfo[20002] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "TZY:TZB:TZB", group = 2, dressRarityType = 1, priority = 2 }
_G.WeeklyRaceConst.DressSpineInfo[20003] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "PGY:PGB:PGB", group = 3, dressRarityType = 1, priority = 3 }
_G.WeeklyRaceConst.DressSpineInfo[20004] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "YZY:YZB:YZB", group = 4, dressRarityType = 3, priority = 4 }
_G.WeeklyRaceConst.DressSpineInfo[20005] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "ZFY:ZFB:ZFB:nil:nil:ZFD:ZFD2", group = 5, dressRarityType = 2, priority = 5 }
_G.WeeklyRaceConst.DressSpineInfo[20007] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "YRY:YRB:YRB2:YRD", group = 6, dressRarityType = 2, priority = 6 }
_G.WeeklyRaceConst.DressSpineInfo[20009] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "QEY:QEB:QEB", group = 7, dressRarityType = 2, priority = 7 }
_G.WeeklyRaceConst.DressSpineInfo[20010] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "NNY:NNB:NNB:nil:nil:NND:NND", group = 8, dressRarityType = 1, priority = 8 }
_G.WeeklyRaceConst.DressSpineInfo[20011] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "TKY:TKB:TKB", group = 9, dressRarityType = 3, priority = 9 }
_G.WeeklyRaceConst.DressSpineInfo[20111] = {  animType = 2, bSkin = false, name = "星际航行",slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "TKY_H:TKB_H:TKB_H2:nil:nil:TKD_H:TKD_H2", group = 0, dressRarityType = 3, priority = 10 }
_G.WeeklyRaceConst.DressSpineInfo[20012] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "JLY:JLB:JLB:nil:nil:JLD:JLD:JLYL", group = 10, dressRarityType = 3, priority = 11 }
_G.WeeklyRaceConst.DressSpineInfo[20013] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "GZY:GZB:GZB:nil:nil:GZD:GZD", group = 11, dressRarityType = 1, priority = 12 }
_G.WeeklyRaceConst.DressSpineInfo[20014] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "nil:BXB:BXB", group = 12, dressRarityType = 2, priority = 13 }
_G.WeeklyRaceConst.DressSpineInfo[20015] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "JUY:JUB:JUB:nil:nil:JUD:JUD:JUYL", group = 13, dressRarityType = 3, priority = 14 }
_G.WeeklyRaceConst.DressSpineInfo[20016] = {  animType = 2, bSkin = false, slotName = "Y:YB:ZB:YD:ZD:YXD:ZXD:YL", attachmentName = "XCY:XCB:XCB1:nil:nil:XCD:XCD:XCYL", group = 14, dressRarityType = 3, priority = 15 }

--bottoms
_G.WeeklyRaceConst.DressSpineInfo[30001] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "HJK", group = 1, dressRarityType = 3, priority = 1 }
_G.WeeklyRaceConst.DressSpineInfo[30002] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "TZK", group = 2, dressRarityType = 1, priority = 2 }
_G.WeeklyRaceConst.DressSpineInfo[30003] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "PGK", group = 3, dressRarityType = 1, priority = 3 }
_G.WeeklyRaceConst.DressSpineInfo[30004] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "YZK", group = 4, dressRarityType = 1, priority = 4 }
_G.WeeklyRaceConst.DressSpineInfo[30005] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "ZFK", group = 5, dressRarityType = 2, priority = 5 }
_G.WeeklyRaceConst.DressSpineInfo[30007] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "YRK", group = 6, dressRarityType = 1, priority = 6 }
_G.WeeklyRaceConst.DressSpineInfo[30009] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "QEK", group = 7, dressRarityType = 3, priority = 7 }
_G.WeeklyRaceConst.DressSpineInfo[30010] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "NNK", group = 8, dressRarityType = 2, priority = 8 }
_G.WeeklyRaceConst.DressSpineInfo[30011] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "TKK", group = 9, dressRarityType = 2, priority = 9 }
_G.WeeklyRaceConst.DressSpineInfo[30111] = {  animType = 2, bSkin = false, name = "遨游太空", slotName = "K", attachmentName = "TKK_H", group = 0, dressRarityType = 3, priority = 10 }
_G.WeeklyRaceConst.DressSpineInfo[30012] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "JLK", group = 10, dressRarityType = 2, priority = 11 }
_G.WeeklyRaceConst.DressSpineInfo[30013] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "GZK", group = 11, dressRarityType = 2, priority = 12 }
_G.WeeklyRaceConst.DressSpineInfo[30014] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "BXK", group = 12, dressRarityType = 3, priority = 13 }
_G.WeeklyRaceConst.DressSpineInfo[30015] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "JUK", group = 13, dressRarityType = 1, priority = 14 }
_G.WeeklyRaceConst.DressSpineInfo[30016] = {  animType = 2, bSkin = false, slotName = "K", attachmentName = "XCK", group = 14, dressRarityType = 2, priority = 15 }

-- face mask
_G.WeeklyRaceConst.DressSpineInfo[40001] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "HJL", group = 1, dressRarityType = 1, priority = 1 }
_G.WeeklyRaceConst.DressSpineInfo[40002] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "TZL", group = 2, dressRarityType = 3, priority = 2 }
_G.WeeklyRaceConst.DressSpineInfo[40003] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "PGL", group = 3, dressRarityType = 2, priority = 3 }
_G.WeeklyRaceConst.DressSpineInfo[40004] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "YZL", group = 4, dressRarityType = 1, priority = 4 }
_G.WeeklyRaceConst.DressSpineInfo[40005] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "ZFL", group = 5, dressRarityType = 2, priority = 5 }
_G.WeeklyRaceConst.DressSpineInfo[40006] = {  animType = 2, bSkin = false, name = "钞能力者", slotName = "HJL", attachmentName = "HGL", group = 0, dressRarityType = 3, priority = 6 }
_G.WeeklyRaceConst.DressSpineInfo[40007] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "YRL", group = 6, dressRarityType = 2, priority = 7 }
_G.WeeklyRaceConst.DressSpineInfo[40009] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "QEL", group = 7, dressRarityType = 1, priority = 7 }
_G.WeeklyRaceConst.DressSpineInfo[40010] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "NNL", group = 8, dressRarityType = 3, priority = 8 }
_G.WeeklyRaceConst.DressSpineInfo[40110] = {  animType = 2, bSkin = false, name = "金色祥云", slotName = "HJL", attachmentName = "XYL", group = 0, dressRarityType = 3, priority = 9 }
_G.WeeklyRaceConst.DressSpineInfo[40011] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "TKL", group = 9, dressRarityType = 1, priority = 10 }
_G.WeeklyRaceConst.DressSpineInfo[40012] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "JLL", group = 10, dressRarityType = 2, priority = 11 }
_G.WeeklyRaceConst.DressSpineInfo[40013] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "GZL", group = 11, dressRarityType = 2, priority = 12 }
_G.WeeklyRaceConst.DressSpineInfo[40014] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "BXL", group = 12, dressRarityType = 1, priority = 13 }
_G.WeeklyRaceConst.DressSpineInfo[40015] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "JUL", group = 13, dressRarityType = 2, priority = 14 }
_G.WeeklyRaceConst.DressSpineInfo[40016] = {  animType = 2, bSkin = false, slotName = "HJL", attachmentName = "XCL", group = 14, dressRarityType = 3, priority = 15 }

--maskType 冷暖色  1为冷色 2为暖色
--floor
_G.WeeklyRaceConst.DressSpineInfo[50001] = {  animType = 1, offset = {x=-1874.55/2,y=175- 206}, maskType = 1, resPath = "ShuiShouDress_UI", resName = "FloorUI", group = 1, dressRarityType = 3, priority = 1 }
_G.WeeklyRaceConst.DressSpineInfo[50002] = {  animType = 1, offset = {x=-1948.55/2,y=0}, maskType = 1, resPath = "TuziDress_UI", resName = "FloorUI", group = 2, dressRarityType = 2, priority = 2 }
_G.WeeklyRaceConst.DressSpineInfo[50003] = {  animType = 1, offset = {x=-2405.55/2,y=175}, maskType = 2, resPath = "AppleDress_UI", resName = "FloorUI", group = 3, dressRarityType = 2, priority = 3 }
_G.WeeklyRaceConst.DressSpineInfo[50004] = {  animType = 1, offset = {x=-1467.55/2,y=175}, maskType = 2, resPath = "HaiTanDress_UI", resName = "FloorUI", group = 4, dressRarityType = 1, priority = 4 }
_G.WeeklyRaceConst.DressSpineInfo[50005] = {  animType = 1, offset = {x=-2240.5/2,y=175- 206}, maskType = 1, resPath = "ZhifuDress_UI", resName = "FloorUI", group = 5, dressRarityType = 1, priority = 5 }
_G.WeeklyRaceConst.DressSpineInfo[50006] = {  animType = 1, offset = {x=-1874.55/2,y=175 - 206}, maskType = 1, name = "默认", resPath = "BaseDress_UI", resName = "FloorUI", group = 0, dressRarityType = 1, priority = 6 }
_G.WeeklyRaceConst.DressSpineInfo[50007] = {  animType = 1, offset = {x=-1803/2,y=175}, maskType = 2, resPath = "YuanShiDress_UI", resName = "FloorUI", group = 6, dressRarityType = 1, priority = 7 }
_G.WeeklyRaceConst.DressSpineInfo[50009] = {  animType = 1, offset = {x=-787.5,y=155}, maskType = 1, resPath = "PenguinDress_UI", resName = "FloorUI", group = 7, dressRarityType = 3, priority = 8 }
_G.WeeklyRaceConst.DressSpineInfo[50010] = {  animType = 1, offset = {x=-787.5,y=165}, maskType = 2, resPath = "HappySpringDress_UI", resName = "FloorUI", group = 8, dressRarityType = 2, priority = 9 }
_G.WeeklyRaceConst.DressSpineInfo[50011] = {  animType = 1, offset = {x=-786,y=-30}, maskType = 1, resPath = "SpaceDress_UI", resName = "FloorUI", group = 9, dressRarityType = 2, priority = 10 }
_G.WeeklyRaceConst.DressSpineInfo[50012] = {  animType = 1, offset = {x=-870.5,y=156.5}, maskType = 1, resPath = "FairyDress_UI", resName = "FloorUI", group = 10, dressRarityType = 1, priority = 11 }
_G.WeeklyRaceConst.DressSpineInfo[50112] = {  animType = 1, offset = {x=-870.5,y=156.5}, name = "绿意盎然", maskType = 2, resPath = "FairyDress_UI", resName = "FloorSpUI", group = 0, dressRarityType = 3, priority = 12 }
_G.WeeklyRaceConst.DressSpineInfo[50013] = {  animType = 1, offset = {x=-1332.5,y=159.5}, maskType = 0, resPath = "MidAutumnDress_UI", resName = "FloorUI", group = 11, dressRarityType = 1, priority = 13 }
_G.WeeklyRaceConst.DressSpineInfo[50014] = {  animType = 1, offset = {x=-970,y=90}, maskType = 0, resPath = "whiteBear_UI", resName = "floorNormal", group = 12, dressRarityType = 1, priority = 14 }
_G.WeeklyRaceConst.DressSpineInfo[50114] = {  animType = 1, offset = {x=-830,y=90}, name = "金色暖冬", resPath = "whiteBear_UI", resName = "floorUI", group = 0, dressRarityType = 3, priority = 15 }
_G.WeeklyRaceConst.DressSpineInfo[50015] = {  animType = 1, offset = {x=-830,y=90}, maskType = 0, resPath = "JingJuDress_UI", resName = "floorNormal", group = 13, dressRarityType = 1, priority = 16 }
_G.WeeklyRaceConst.DressSpineInfo[50016] = {  animType = 1, offset = {x=-720,y=90}, maskType = 0, resPath = "MaXiDress_UI", resName = "floorNormal", group = 14, dressRarityType = 2, priority = 17,scale = 0.75 }

--carpet
_G.WeeklyRaceConst.DressSpineInfo[60001] = {  animType = 1, offset = {x=0,y=-255}, resPath = "ShuiShouDress_UI", resName = "tanziUI", group = 1, dressRarityType = 1, priority = 1 }
_G.WeeklyRaceConst.DressSpineInfo[60002] = {  animType = 1, offset = {x=0,y=-200}, resPath = "TuziDress_UI", resName = "tanziUI", group = 2, dressRarityType = 3, priority = 2 }
_G.WeeklyRaceConst.DressSpineInfo[60003] = {  animType = 1, offset = {x=-8,y=-200}, resPath = "AppleDress_UI", resName = "tanziUI", group = 3, dressRarityType = 2, priority = 3 }
_G.WeeklyRaceConst.DressSpineInfo[60004] = {  animType = 1, offset = {x=-20,y=-180}, resPath = "HaiTanDress_UI", resName = "tanziUI", group = 4, dressRarityType = 2, priority = 4 }
_G.WeeklyRaceConst.DressSpineInfo[60005] = {  animType = 1, offset = {x=-20,y=-180}, resPath = "ZhifuDress_UI", resName = "tanziUI", group = 5, dressRarityType = 3, priority = 5 }
_G.WeeklyRaceConst.DressSpineInfo[60006] = {  animType = 1, offset = {x=15,y=-180}, name = "金边沙发", resPath = "SpecialDress_UI", resName = "tanziUI", group = 0, dressRarityType = 3, priority = 6 }
_G.WeeklyRaceConst.DressSpineInfo[60007] = {  animType = 1, offset = {x=6,y=-180}, resPath = "YuanShiDress_UI", resName = "tanziUI", group = 6, dressRarityType = 3, priority = 6 }
_G.WeeklyRaceConst.DressSpineInfo[60009] = {  animType = 1, offset = {x=6,y=-200}, resPath = "PenguinDress_UI", resName = "tanziUI", group = 7, dressRarityType = 1, priority = 7 }
_G.WeeklyRaceConst.DressSpineInfo[60010] = {  animType = 1, offset = {x=0,y=-200}, resPath = "HappySpringDress_UI", resName = "tanziUI", group = 8, dressRarityType = 1, priority = 8 }
_G.WeeklyRaceConst.DressSpineInfo[60011] = {  animType = 1, offset = {x=0,y=-245}, resPath = "SpaceDress_UI", resName = "tanziUI", group = 9, dressRarityType = 2, priority = 9 }
_G.WeeklyRaceConst.DressSpineInfo[60012] = {  animType = 1, offset = {x=0, y=-255}, resPath = "FairyDress_UI", resName = "tanziUI", group = 10, dressRarityType = 3, priority = 10 }
_G.WeeklyRaceConst.DressSpineInfo[60013] = {  animType = 1, offset = {x=0,y=-255}, resPath = "MidAutumnDress_UI", resName = "CarpetUI", group = 11, dressRarityType = 1, priority = 11 }
_G.WeeklyRaceConst.DressSpineInfo[60113] = {  animType = 1, offset = {x=0,y=-200}, name = "宫苑卧榻", resPath = "MidAutumnDress_UI", resName = "CarpetSpUI", group = 0, dressRarityType = 3, priority = 12 }
_G.WeeklyRaceConst.DressSpineInfo[60014] = {  animType = 1, offset = {x=0,y=-220},resPath = "whiteBear_UI", resName = "carpetUI", group = 12, dressRarityType = 1, priority = 13 }
_G.WeeklyRaceConst.DressSpineInfo[60015] = {  animType = 1, offset = {x=0,y=-180},resPath = "JingJuDress_UI", resName = "carpetUI", group = 13, dressRarityType = 1, priority = 14 }
_G.WeeklyRaceConst.DressSpineInfo[60016] = {  animType = 1, offset = {x=0,y=-200},resPath = "MaXiDress_UI", resName = "carpetUI", group = 14, dressRarityType = 1, priority = 15,scale = 0.82}

--wallpaper 这里的offset中的y是不生效的,应当在flash文件中对于单个墙纸的位置设定在0,0点，如果不想改，可以用trueOffsetY进行偏移
_G.WeeklyRaceConst.DressSpineInfo[70001] = {  animType = 1, offset = {x=-2199.1/2,y=0}, maskType = 1, resPath = "ShuiShouDress_UI", resName = "WallpaperUI", group = 1, dressRarityType = 2, priority = 1 }
_G.WeeklyRaceConst.DressSpineInfo[70002] = {  animType = 1, offset = {x=-1678/2,y=-100}, maskType = 2, maskOffset = {x=0,y=70}, resPath = "TuziDress_UI", resName = "WallpaperUI", group = 2, dressRarityType = 1, priority = 2 }
_G.WeeklyRaceConst.DressSpineInfo[70003] = {  animType = 1, offset = {x=-2409/2,y=0}, maskType = 1, resPath = "AppleDress_UI", resName = "WallpaperUI", group = 3, dressRarityType = 3, priority = 3 }
_G.WeeklyRaceConst.DressSpineInfo[70004] = {  animType = 1, offset = {x=-1545/2,y=0}, maskType = 1, resPath = "HaiTanDress_UI", resName = "WallpaperUI", group = 4, dressRarityType = 2, priority = 4 }
_G.WeeklyRaceConst.DressSpineInfo[70005] = {  animType = 1, offset = {x=-1808.35/2,y=0}, maskType = 2, resPath = "ZhifuDress_UI", resName = "WallpaperUI", group = 5, dressRarityType = 3, priority = 5 }
_G.WeeklyRaceConst.DressSpineInfo[70006] = {  animType = 1, offset = {x=-1438.5/2,y=0}, maskType = 2, name = "默认", resPath = "BaseDress_UI", resName = "WallpaperUI", group = 0, dressRarityType = 1, priority = 6 }
_G.WeeklyRaceConst.DressSpineInfo[70007] = {  animType = 1, offset = {x=-1558.5/2,y=0}, maskType = 1, resPath = "YuanShiDress_UI", resName = "WallpaperUI", group = 6, dressRarityType = 1, priority = 7 }
_G.WeeklyRaceConst.DressSpineInfo[70009] = {  animType = 1, offset = {x=-734.25,y=0}, maskType = 1, resPath = "PenguinDress_UI", resName = "WallpaperUI", group = 7, dressRarityType = 1, priority = 8 }
_G.WeeklyRaceConst.DressSpineInfo[70101] = {  animType = 1, offset = {x=-747,y=0}, maskType = 1, name ="高贵典雅", resPath = "specialWall70101_UI", resName = "wallUI", group = 0, dressRarityType = 3, priority = 9 }
_G.WeeklyRaceConst.DressSpineInfo[70010] = {  animType = 1, offset = {x=-800,y=0}, maskOffset = {x=0,y=6}, maskType = 2, resPath = "HappySpringDress_UI", resName = "WallpaperUI", group = 8, dressRarityType = 1, priority = 10 }
_G.WeeklyRaceConst.DressSpineInfo[70011] = {  animType = 1, offset = {x=-800,y=0}, maskType = 1, resPath = "SpaceDress_UI", resName = "WallpaperUI", group = 9, dressRarityType = 3, priority = 11 }
_G.WeeklyRaceConst.DressSpineInfo[70012] = {  animType = 1, offset = {x=-996,y=0}, maskType = 1, resPath = "FairyDress_UI", resName = "WallpaperUI", group = 10, dressRarityType = 2, priority = 12 }
_G.WeeklyRaceConst.DressSpineInfo[70013] = {  animType = 1, offset = {x=-1013,y=0}, maskType = 0, resPath = "MidAutumnDress_UI", resName = "WallpaperUI", group = 11, dressRarityType = 3, priority = 13 }
_G.WeeklyRaceConst.DressSpineInfo[70014] = {  animType = 1, offset = {x=-1013,y=0}, maskType = 0, resPath = "whiteBear_UI", resName = "wallperUI", group = 12, dressRarityType = 2, priority = 14 }
_G.WeeklyRaceConst.DressSpineInfo[70015] = {  animType = 1, offset = {x=-600,y=0}, maskType = 0, resPath = "JingJuDress_UI", resName = "wallperUI", group = 13, dressRarityType = 2, priority = 15 ,scale = 1.3, trueOffsetY = 255}
_G.WeeklyRaceConst.DressSpineInfo[70115] = {  animType = 1, offset = {x=-600,y=0}, maskType = 0, name ="吉祥如意",resPath = "JingJuDress_UI", resName = "wallperSPUI", group = 0, dressRarityType = 3,scale = 1.3,priority = 16 , trueOffsetY = 155 }
_G.WeeklyRaceConst.DressSpineInfo[70016] = {  animType = 1, offset = {x=-996,y=0}, maskType = 0,resPath = "MaXiDress_UI", resName = "wallperUI", group = 14, dressRarityType = 1,scale = 1.3,priority = 17 , trueOffsetY = 260 }

--window
_G.WeeklyRaceConst.DressSpineInfo[80001] = {  animType = 1, offset = {x=0,y=550}, resPath = "ShuiShouDress_UI", resName = "WindowUI", group = 1, dressRarityType = 1, priority = 1 }
_G.WeeklyRaceConst.DressSpineInfo[80002] = {  animType = 1, offset = {x=20, y=300}, resPath = "TuziDress_UI", resName = "WindowUI", group = 2, dressRarityType = 2, priority = 2 }
_G.WeeklyRaceConst.DressSpineInfo[80003] = {  animType = 1, offset = {x=4,y=300}, resPath = "AppleDress_UI", resName = "WindowUI", group = 3, dressRarityType = 3, priority = 3 }
_G.WeeklyRaceConst.DressSpineInfo[80004] = {  animType = 1, offset = {x=-9,y=300}, resPath = "HaiTanDress_UI", resName = "WindowUI", group = 4, dressRarityType = 2, priority = 4 }
_G.WeeklyRaceConst.DressSpineInfo[80005] = {  animType = 1, offset = {x=0,y=300}, resPath = "ZhifuDress_UI", resName = "WindowUI", group = 5, dressRarityType = 1, priority = 5 }
_G.WeeklyRaceConst.DressSpineInfo[80006] = {  animType = 1, offset = {x=0,y=550}, name = "默认", resPath = "BaseDress_UI", resName = "WindowUI", group = 0, dressRarityType = 1, priority = 6 }
_G.WeeklyRaceConst.DressSpineInfo[80007] = {  animType = 1, offset = {x=0,y=300}, resPath = "YuanShiDress_UI", resName = "WindowUI", group = 6, dressRarityType = 3, priority = 7 }
_G.WeeklyRaceConst.DressSpineInfo[80008] = {  animType = 1, offset = {x=0,y=300}, name = "豪气金窗", resPath = "SpecialDress_UI", resName = "WindowUI", group = 0, dressRarityType = 3, priority = 8 }
_G.WeeklyRaceConst.DressSpineInfo[80009] = {  animType = 1, offset = {x=0,y=320}, resPath = "PenguinDress_UI", resName = "WindowUI", group = 7, dressRarityType = 2, priority = 9 }
_G.WeeklyRaceConst.DressSpineInfo[80010] = {  animType = 1, offset = {x=0,y=320}, resPath = "HappySpringDress_UI", resName = "WindowUI", group = 8, dressRarityType = 1, priority = 10 }
_G.WeeklyRaceConst.DressSpineInfo[80011] = {  animType = 1, offset = {x=0,y=380}, resPath = "SpaceDress_UI", resName = "WindowUI", group = 9, dressRarityType = 1, priority = 11 }
_G.WeeklyRaceConst.DressSpineInfo[80012] = {  animType = 1, offset = {x=0,y=522}, resPath = "FairyDress_UI", resName = "WindowUI", group = 10, dressRarityType = 1, priority = 12 }
_G.WeeklyRaceConst.DressSpineInfo[80112] = {  animType = 1, offset = {x=0,y=370}, name = "花花世界", resPath = "FairyDress_UI", resName = "WindowSpUI", group = 0, dressRarityType = 3, priority = 13 }
_G.WeeklyRaceConst.DressSpineInfo[80013] = {  animType = 1, offset = {x=0,y=330}, resPath = "MidAutumnDress_UI", resName = "WindowUI", group = 11, dressRarityType = 3, priority = 14 }
_G.WeeklyRaceConst.DressSpineInfo[80014] = {  animType = 1, offset = {x=0,y=270}, resPath = "whiteBear_UI", resName = "windowsUI",relevance = {990001} ,group = 12, dressRarityType = 2, priority = 15 }
_G.WeeklyRaceConst.DressSpineInfo[80015] = {  animType = 1, offset = {x=0,y=290}, resPath = "JingJuDress_UI", resName = "windowsUI",group = 13, dressRarityType = 2, priority = 16 }
_G.WeeklyRaceConst.DressSpineInfo[80016] = {  animType = 1, offset = {x=0,y=330}, resPath = "MaXiDress_UI", resName = "windowsUI",group = 14, dressRarityType = 1, priority = 17}
_G.WeeklyRaceConst.DressSpineInfo[80116] = {  animType = 1, offset = {x=0,y=330}, name = "繁星奇妙窗",resPath = "MaXiDress_UI", resName = "windowSpUI",group = 0, dressRarityType = 3, priority = 18  }

--toy
_G.WeeklyRaceConst.DressSpineInfo[90001] = {  animType = 1, offset = {x=220,y=-390}, resPath = "ShuiShouDress_UI", resName = "toyUI", group = 1, dressRarityType = 1, priority = 1 }
_G.WeeklyRaceConst.DressSpineInfo[90002] = {  animType = 1, offset = {x=220,y=-240}, resPath = "TuziDress_UI", resName = "toyUI", group = 2, dressRarityType = 1, priority = 2 }
_G.WeeklyRaceConst.DressSpineInfo[90003] = {  animType = 1, offset = {x=217,y=-330}, resPath = "AppleDress_UI", resName = "toyUI", group = 3, dressRarityType = 1, priority = 3 }
_G.WeeklyRaceConst.DressSpineInfo[90004] = {  animType = 1, offset = {x=217,y=-220}, resPath = "HaiTanDress_UI", resName = "toyUI", group = 4, dressRarityType = 1, priority = 4 }
_G.WeeklyRaceConst.DressSpineInfo[90005] = {  animType = 1, offset = {x=217,y=-360}, resPath = "ZhifuDress_UI", resName = "toyUI", group = 5, dressRarityType = 1, priority = 5 }
_G.WeeklyRaceConst.DressSpineInfo[90007] = {  animType = 1, offset = {x=217,y=-240}, resPath = "YuanShiDress_UI", resName = "toyUI", group = 6, dressRarityType = 1, priority = 7 }
_G.WeeklyRaceConst.DressSpineInfo[90009] = {  animType = 1, offset = {x=-183,y=-380}, resPath = "PenguinDress_UI", resName = "toyUI", group = 7, dressRarityType = 1, priority = 8 }
_G.WeeklyRaceConst.DressSpineInfo[90101] = {  animType = 1, offset = {x=214,y=-390}, name ="嘟嘟海豹",resPath = "PenguinDress_UI", resName = "toyUI2", group = 0, dressRarityType = 3, priority = 9 }
_G.WeeklyRaceConst.DressSpineInfo[90010] = {  animType = 1, offset = {x=214,y=-360}, resPath = "HappySpringDress_UI", resName = "toyUI", group = 8, dressRarityType = 1, priority = 10 }
_G.WeeklyRaceConst.DressSpineInfo[90011] = {  animType = 1, offset = {x=217,y=-320}, resPath = "SpaceDress_UI", resName = "toyUI", group = 9, dressRarityType = 1, priority = 11 }
_G.WeeklyRaceConst.DressSpineInfo[91001] = {  animType = 1, offset = {x=214,y=-320}, name = "粽子船", plist = "weeklyRace2020_dressUI.plist", frameName = "weeklyRace2020_dressUI/zongziBoat", group = 0, dressRarityType = 4, priority = 12, tipGroup = 1 }
_G.WeeklyRaceConst.DressSpineInfo[90012] = {  animType = 1, offset = {x=214,y=-320}, resPath = "FairyDress_UI", resName = "toyUI", group = 10, dressRarityType = 1, priority = 13 }
_G.WeeklyRaceConst.DressSpineInfo[90013] = {  animType = 1, offset = {x=214,y=-320}, resPath = "MidAutumnDress_UI", resName = "toyUI", group = 11, dressRarityType = 1, priority = 14 }
_G.WeeklyRaceConst.DressSpineInfo[90014] = {  animType = 1, offset = {x=214,y=-300}, name = "礼物小熊",resPath = "whiteBear_UI", resName = "giftUI", group = 12, dressRarityType = 1, priority = 15 }
_G.WeeklyRaceConst.DressSpineInfo[90015] = {  animType = 1, offset = {x=220,y=-350}, name = "虎虎生威",resPath = "JingJuDress_UI", resName = "giftUI", group = 13, dressRarityType = 1, priority = 16  }
_G.WeeklyRaceConst.DressSpineInfo[90016] = {  animType = 1, offset = {x=150,y=-200}, name = "魔力兔兔",resPath = "MaXiDress_UI", resName = "giftUI", group = 14, dressRarityType = 1, priority = 17,scale = 1.0  }

--effect
_G.WeeklyRaceConst.DressSpineInfo[101001] = {  animType = 4, offset = {x=300,y=300}, name = "蒲公英之梦", spinePath = "amf/weeklyrace/spine/pugongying.skel", animBack = "idle_houceng",animFront = "idle_qianceng", group = 0, dressRarityType = 4, priority = 1, tipGroup = 1 }
_G.WeeklyRaceConst.DressSpineInfo[100113] = {  animType = 4, offset = {x=0,y=130}, name = "祈愿华灯", spinePath = "amf/weeklyrace/spine/denglong.skel", animBack = "idle_hou",animFront = "idle_qian", group = 0, dressRarityType = 3, priority = 2 }
_G.WeeklyRaceConst.DressSpineInfo[100114] = {  animType = 4, offset = {x=0,y=130}, name = "雪花飘飘", spinePath = "amf/weeklyrace/spine/beijing_xue.skel",relevance = {990001}, animBack = "idle_hou",animFront = "idle_qian", group = 0, dressRarityType = 3, priority = 3 }
_G.WeeklyRaceConst.DressSpineInfo[100115] = {  animType = 4, offset = {x=0,y=540},offset2 ={x=0,y=540},delayTime = 0, name = "除旧迎新", spinePath = "amf/weeklyrace/spine/bianpao.skel", animBack = nil,animFront = "in2", group = 0, dressRarityType = 3, priority = 4 }
_G.WeeklyRaceConst.DressSpineInfo[100116] = {  animType = 4, offset = {x=0,y=130}, name = "缤纷气球", spinePath = "amf/weeklyrace/spine/qiqiu.skel", animBack = "idle_hou",animFront = "idle_qian", group = 0, dressRarityType = 3, priority = 5 }

--关联配置relevance
-- layerId根据展示位置天，例如在窗户层展示，窗户前缀是8,那么layerID为8
_G.WeeklyRaceConst.DressSpineInfo[990001] = { layerId = 8, needIdList = {100114,80014},animType = 4, scale = 0.7 ,offset = {x=-30,y=380}, spinePath = "amf/weeklyrace/spine/chuanwai_xue.skel", anim= "idle"}


--装扮图鉴
_G.WeeklyRaceConst.DressGroupInfo = {}
_G.WeeklyRaceConst.DressGroupInfo[1] = { name = "水手之家", introduce = "昨天在海上捞到了一只漂流的猫···", dressRarityType = 1, priority = 7 }
_G.WeeklyRaceConst.DressGroupInfo[2] = { name = "小兔子乖乖", introduce = "小兔子乖乖，把门开开~", dressRarityType = 1, priority = 8 }
_G.WeeklyRaceConst.DressGroupInfo[3] = { name = "红苹果乐园", introduce = "放心，我才不会吃掉自己的帽子~", dressRarityType = 1, priority = 9 }
_G.WeeklyRaceConst.DressGroupInfo[4] = { name = "夏日海滩", introduce = "我给大家表演一个少年猫的奇幻漂流~", dressRarityType = 1, priority = 10 }
_G.WeeklyRaceConst.DressGroupInfo[5] = { name = "异域风情", introduce = "听说集齐这一套装扮后可以获得神灯！", dressRarityType = 1, priority = 11 }
_G.WeeklyRaceConst.DressGroupInfo[6] = { name = "远古时代", introduce = "外面的大恐龙为什么一直盯着我？", dressRarityType = 1, priority = 6 }
_G.WeeklyRaceConst.DressGroupInfo[7] = { name = "企鹅绅士", introduce = "鹅鹅鹅，曲脖儿向天歌~", dressRarityType = 1, priority = 5 }
_G.WeeklyRaceConst.DressGroupInfo[8] = { name = "喜迎新春", introduce = "新的一年祝大家牛气冲天！", dressRarityType = 1, priority = 4 }
_G.WeeklyRaceConst.DressGroupInfo[9] = { name = "太空旅行", introduce = "穿上太空服，飞进你充满星星的眼睛里", dressRarityType = 1, priority = 3 }
_G.WeeklyRaceConst.DressGroupInfo[10] = { name = "梦幻精灵", introduce = "如光之精灵在清晨的柔光下轻歌曼舞", dressRarityType = 1, priority = 2 }
_G.WeeklyRaceConst.DressGroupInfo[11] = { name = "月满中秋", introduce = "丹桂飘香贺中秋，月影清浅庆团圆", dressRarityType = 1, priority = 1 }
_G.WeeklyRaceConst.DressGroupInfo[12] = { name = "可爱熊熊", introduce = "可爱熊熊，不怕困难~", dressRarityType = 1, priority = 12}
_G.WeeklyRaceConst.DressGroupInfo[13] = { name = "国粹迎春", introduce = "国粹京剧，喜迎新春~", dressRarityType = 1, priority = 13}
_G.WeeklyRaceConst.DressGroupInfo[14] = { name = "奇幻马戏团", introduce = "一起来奇幻马戏团探险吧~", dressRarityType = 1, priority = 14}

--稀有度
_G.WeeklyRaceConst.DressRarityType = {
    NORMAL = 1, --普通
    XIYOU = 2, --稀有
    HAOHUA = 3, --豪华
    LIMIT = 4, --限定
}

function _G.WeeklyRaceConst:getDressSlotNamesAndAttachmentsName( dressId )
    if not _G.WeeklyRaceConst.DressSpineInfo[dressId]  then return {}, {} end
    local slotNames = string.split( _G.WeeklyRaceConst.DressSpineInfo[dressId].slotName, ":")
    local attachmentsNames = string.split( _G.WeeklyRaceConst.DressSpineInfo[dressId].attachmentName, ":")
    return slotNames, attachmentsNames
end

function _G.WeeklyRaceConst:isBuyable( dressId )
    if _G.WeeklyRaceConst.DressSpineInfo[dressId] then
        return _G.WeeklyRaceConst.DressSpineInfo[dressId].buyable == nil or
                _G.WeeklyRaceConst.DressSpineInfo[dressId].buyable == true
    end
    return false
end

_G.WeeklyRaceConst.DressTipInfo = {}
_G.WeeklyRaceConst.DressTipInfo[1] = { tip = "倾心粽夏夜活动中获取~" }

--点击商店图标时的Tip分组
function _G.WeeklyRaceConst:getDressTips(id)
    local tipGroup = _G.WeeklyRaceConst.DressSpineInfo[id] and _G.WeeklyRaceConst.DressSpineInfo[id].tipGroup
    if tipGroup and _G.WeeklyRaceConst.DressTipInfo[tipGroup] then
        return _G.WeeklyRaceConst.DressTipInfo[tipGroup].tip
    end
end

_G.WeeklyRaceConst.DressResTable = {
    [1] = {"amf/weeklyrace/spine/maomao.skel"},
    [2] = {"amf/weeklyrace/spine/maomao.skel"},
    [3] = {"amf/weeklyrace/spine/maomao.skel"},
    [4] = {"amf/weeklyrace/spine/maomao.skel"},

    [50003] = {"amf/weeklyrace/texture/AppleDress.skel"},
    [60003] = {"amf/weeklyrace/texture/AppleDress.skel"},
    [70003] = {"amf/weeklyrace/texture/AppleDress.skel"},
    [80003] = {"amf/weeklyrace/texture/AppleDress.skel"},
    [90003] = {"amf/weeklyrace/texture/AppleDress.skel"},

    [50006] = {"amf/weeklyrace/texture/BaseDress.plist"},
    [70006] = {"amf/weeklyrace/texture/BaseDress.plist"},
    [80006] = {"amf/weeklyrace/texture/BaseDress.plist"},

    [50012] = {"amf/weeklyrace/texture/FairyDress.plist"},
    [50112] = {"amf/weeklyrace/texture/FairyDress.plist"},
    [60012] = {"amf/weeklyrace/texture/FairyDress.plist"},
    [70012] = {"amf/weeklyrace/texture/FairyDress.plist"},
    [80012] = {"amf/weeklyrace/texture/FairyDress.plist"},
    [80112] = {"amf/weeklyrace/texture/FairyDress.plist"},
    [90012] = {"amf/weeklyrace/texture/FairyDress.plist"},

    [50004] = {"amf/weeklyrace/texture/HaiTanDress.plist"},
    [60004] = {"amf/weeklyrace/texture/HaiTanDress.plist"},
    [70004] = {"amf/weeklyrace/texture/HaiTanDress.plist"},
    [80004] = {"amf/weeklyrace/texture/HaiTanDress.plist"},
    [90004] = {"amf/weeklyrace/texture/HaiTanDress.plist"},

    [50010] = {"amf/weeklyrace/texture/HappySpringDress.plist"},
    [60010] = {"amf/weeklyrace/texture/HappySpringDress.plist"},
    [70010] = {"amf/weeklyrace/texture/HappySpringDress.plist"},
    [80010] = {"amf/weeklyrace/texture/HappySpringDress.plist"},
    [90010] = {"amf/weeklyrace/texture/HappySpringDress.plist"},

    [50015] = {"amf/weeklyrace/texture/JingJuDress.plist"},
    [60015] = {"amf/weeklyrace/texture/JingJuDress.plist"},
    [70015] = {"amf/weeklyrace/texture/JingJuDress.plist"},
    [70115] = {"amf/weeklyrace/texture/JingJuDress.plist"},
    [80015] = {"amf/weeklyrace/texture/JingJuDress.plist"},
    [90015] = {"amf/weeklyrace/texture/JingJuDress.plist"},

    [50016] = {"amf/weeklyrace/texture/MaXiDress.plist"},
    [60016] = {"amf/weeklyrace/texture/MaXiDress.plist"},
    [70016] = {"amf/weeklyrace/texture/MaXiDress.plist"},
    [80016] = {"amf/weeklyrace/texture/MaXiDress.plist"},
    [80116] = {"amf/weeklyrace/texture/MaXiDress.plist"},
    [90016] = {"amf/weeklyrace/texture/MaXiDress.plist"},

    [50013] = {"amf/weeklyrace/texture/MidAutumnDress.plist"},
    [60013] = {"amf/weeklyrace/texture/MidAutumnDress.plist"},
    [60113] = {"amf/weeklyrace/texture/MidAutumnDress.plist"},
    [70013] = {"amf/weeklyrace/texture/MidAutumnDress.plist"},
    [80013] = {"amf/weeklyrace/texture/MidAutumnDress.plist"},
    [90013] = {"amf/weeklyrace/texture/MidAutumnDress.plist"},

    [50009] = {"amf/weeklyrace/texture/PenguinDress.plist"},
    [60009] = {"amf/weeklyrace/texture/PenguinDress.plist"},
    [70009] = {"amf/weeklyrace/texture/PenguinDress.plist"},
    [80009] = {"amf/weeklyrace/texture/PenguinDress.plist"},
    [90009] = {"amf/weeklyrace/texture/PenguinDress.plist"},
    [90101] = {"amf/weeklyrace/texture/PenguinDress.plist"},

    [50001] = {"amf/weeklyrace/texture/ShuiShouDress.plist"},
    [60001] = {"amf/weeklyrace/texture/ShuiShouDress.plist"},
    [70001] = {"amf/weeklyrace/texture/ShuiShouDress.plist"},
    [80001] = {"amf/weeklyrace/texture/ShuiShouDress.plist"},
    [90001] = {"amf/weeklyrace/texture/ShuiShouDress.plist"},

    [50011] = {"amf/weeklyrace/texture/SpaceDress.plist"},
    [60011] = {"amf/weeklyrace/texture/SpaceDress.plist"},
    [70011] = {"amf/weeklyrace/texture/SpaceDress.plist"},
    [80011] = {"amf/weeklyrace/texture/SpaceDress.plist"},
    [90011] = {"amf/weeklyrace/texture/SpaceDress.plist"},

    [60006] = {"amf/weeklyrace/texture/SpecialDress.plist"},
    [80008] = {"amf/weeklyrace/texture/SpecialDress.plist"},

    [70101] = {"amf/weeklyrace/texture/specialWall70101.plist"},

    [50002] = {"amf/weeklyrace/texture/TuziDress.plist"},
    [60002] = {"amf/weeklyrace/texture/TuziDress.plist"},
    [70002] = {"amf/weeklyrace/texture/TuziDress.plist"},
    [80002] = {"amf/weeklyrace/texture/TuziDress.plist"},
    [90002] = {"amf/weeklyrace/texture/TuziDress.plist"},

    [50014] = {"amf/weeklyrace/texture/whiteBear.plist"},
    [50114] = {"amf/weeklyrace/texture/whiteBear.plist"},
    [60014] = {"amf/weeklyrace/texture/whiteBear.plist"},
    [70014] = {"amf/weeklyrace/texture/whiteBear.plist"},
    [80014] = {"amf/weeklyrace/texture/whiteBear.plist"},
    [90014] = {"amf/weeklyrace/texture/whiteBear.plist"},

    [50007] = {"amf/weeklyrace/texture/YuanShiDress.plist"},
    [60007] = {"amf/weeklyrace/texture/YuanShiDress.plist"},
    [70007] = {"amf/weeklyrace/texture/YuanShiDress.plist"},
    [80007] = {"amf/weeklyrace/texture/YuanShiDress.plist"},
    [90007] = {"amf/weeklyrace/texture/YuanShiDress.plist"},

    [50005] = {"amf/weeklyrace/texture/ZhifuDress.plist"},
    [60005] = {"amf/weeklyrace/texture/ZhifuDress.plist"},
    [70005] = {"amf/weeklyrace/texture/ZhifuDress.plist"},
    [80005] = {"amf/weeklyrace/texture/ZhifuDress.plist"},
    [90005] = {"amf/weeklyrace/texture/ZhifuDress.plist"},
}
function _G.WeeklyRaceConst:getDressResList(dressId)
    local resList = _G.WeeklyRaceConst.DressResTable[dressId] or {}
    table.insert(resList, "amf/weeklyrace/material/leng.png")
    table.insert(resList, "amf/weeklyrace/material/nuan.png")
    return resList
end