local AMFRequest = require "amf.middleware.interconnection.remote.core.AMFRequest"

local Request = class("RequestCollectCardMainInfo", AMFRequest)

local config = {
    protocol = "cardCollection2026Info",
    loading = true,
    useMockData = false,
    timeOut = 10,
}

local AUTO_POPOUT_TIMEOUT = 3

function Request:post(reqParams, hostObj, loading)
    return Request:run(config, reqParams, hostObj, loading)
end

function Request:postOnLightStart(reqParams, hostObj)
    local cfg = table.merge(table.simpleClone(config), {
        loading = false,
    })
    return Request:run(cfg, reqParams, hostObj)
end

function Request:postOnAutoPopout(reqParams, hostObj)
    local cfg = table.merge(table.simpleClone(config), {
        loading = true,
        timeOut = AUTO_POPOUT_TIMEOUT,
    })
    return Request:run(cfg, reqParams, hostObj)
end

function Request:getMockData()
    local mockData = {
        periodId = 1,
        round = 1,
        shareRewardFlag = false,
        starNum = 0,
        historyRoundStarNum = 0,
        pendingPacks = {1,2,3,4,5},
        cardAlbumMap = {
            ["1"] = {
                cardMap = {
                    ["1"] = 10,
                    ["2"] = 10,
                    ["3"] = 10,
                    ["4"] = 10,
                    ["5"] = 10,
                    ["6"] = 10,
                },
                allAlbumReward = false,
            },
            ["2"] = {
                cardMap = {
                    ["7"] = 10,
                    ["8"] = 10,
                    ["9"] = 10,
                    ["10"] = 10,
                    ["11"] = 10,
                    ["12"] = 10,
                },
                allAlbumReward = false,
            },
        },
        guideSet = {},
        newRoundGiftPacks = 0,
        haveCardDoneReward = false,
        preHeatShowRewards = {
            {itemId = 2, num = 100},
            {itemId = 14, num = 100},
        },

        serverVersionedConfig = {
            serverMd5 = "mockmd5",
            config = table.serialize{
                openVersion = "1.154",
                overProcessTipPopLimit = 1,
                sendDailyLimit = 1,
                guideReward = {

                },
                newRoundReward = {

                },
                shareReward = {
                    {itemId = 10098, num = 10},
                },
                rareDecoPoolConfig = {

                },
                cardConfigList = {
                    {
                        cardId = 1,
                        itemId = 50001,
                        cardLevel = 1,
                    },
                    {
                        cardId = 2,
                        itemId = 50002,
                        cardLevel = 2,
                    },
                    {
                        cardId = 3,
                        itemId = 50003,
                        cardLevel = 3,
                    },
                    {
                        cardId = 4,
                        itemId = 50004,
                        cardLevel = 4,
                    },
                    {
                        cardId = 5,
                        itemId = 50005,
                        cardLevel = 5,
                    },
                    {
                        cardId = 6,
                        itemId = 50006,
                        cardLevel = 6,
                    },
                    {
                        cardId = 7,
                        itemId = 50007,
                        cardLevel = 1,
                    },
                    {
                        cardId = 8,
                        itemId = 50008,
                        cardLevel = 2,
                    },
                    {
                        cardId = 9,
                        itemId = 50009,
                        cardLevel = 3,
                    },
                    {
                        cardId = 10,
                        itemId = 50010,
                        cardLevel = 4,
                    },
                    {
                        cardId = 11,
                        itemId = 50011,
                        cardLevel = 5,
                    },
                    {
                        cardId = 12,
                        itemId = 50012,
                        cardLevel = 6,
                    },
                    {
                        cardId = 13,
                        itemId = 50013,
                        cardLevel = 1,
                    },
                    {
                        cardId = 14,
                        itemId = 50014,
                        cardLevel = 2,
                    },
                    {
                        cardId = 15,
                        itemId = 50015,
                        cardLevel = 3,
                    },
                    {
                        cardId = 16,
                        itemId = 50016,
                        cardLevel = 4,
                    },
                    {
                        cardId = 17,
                        itemId = 50017,
                        cardLevel = 5,
                    },
                    {
                        cardId = 18,
                        itemId = 50018,
                        cardLevel = 6,
                    },
                },
                cardAlbumConfigList = {
                    {albumId = 1, cardIdStr = "1,2,3,4,5,6,7,8,9"},
                    {albumId = 2, cardIdStr = "10,11,12,13,14,15,16,17,18"},
                    {albumId = 3, cardIdStr = "19,20,21,22,23,24,25,26,27"},
                    {albumId = 4, cardIdStr = "28,29,30,31,32,33,34,35,36"},
                    {albumId = 5, cardIdStr = "37,38,39,40,41,42,43,44,45"},
                    {albumId = 6, cardIdStr = "46,47,48,49,50,51,52,53,54"},
                    {albumId = 7, cardIdStr = "55,56,57,58,59,60,61,62,63"},
                    {albumId = 8, cardIdStr = "64,65,66,67,68,69,70,71,72"},
                    {albumId = 9, cardIdStr = "73,74,75,76,77,78,79,80,81"},
                    {albumId = 10, cardIdStr = "82,83,84,85,86,87,88,89,90"},
                    {albumId = 11, cardIdStr = "91,92,93,94,95,96,97,98,99"},
                    {albumId = 12, cardIdStr = "100,101,102,103,104,105,106,107,108"},
                },
                cardStarExchangeConfigList = {
                    {
                        cardLevel = 1,
                        exchangeStarNum = 1,
                    },
                    {
                        cardLevel = 2,
                        exchangeStarNum = 2,
                    },
                    {
                        cardLevel = 3,
                        exchangeStarNum = 3,
                    },
                    {
                        cardLevel = 4,
                        exchangeStarNum = 4,
                    },
                    {
                        cardLevel = 5,
                        exchangeStarNum = 5,
                    },
                    {
                        cardLevel = 6,
                        exchangeStarNum = 5,
                    },
                },
                starBoxConfigList = {
                    {
                        boxId = 1,
                        needStarNum = 100,
                        rewards = {
                            {itemId = 2, num = 100},
                            {itemId = 14, num = 100},
                        },
                    }
                },
                cardAlbumRewardConfigList = {
                    {
                        albumId = 1,
                        roundRange = "1~2",
                        rewards = {
                            {itemId = 2, num = 200},
                            {itemId = 14, num = 200},
                            {itemId = 14, num = 200},
                        }
                    },
                    {
                        albumId = 2,
                        roundRange = "1~2",
                        rewards = {
                            {itemId = 53281, num = 0},
                            {itemId = 14, num = 200},
                        }
                    }
                },
                roundCompleteRewardConfigList = {
                    {
                        roundRange = "1~2",
                        rewards = {
                            {itemId = 2, num = 300},
                            {itemId = 14, num = 300},
                        },
                        showRewards = {
                            {itemId = 2, num = 300},
                            {itemId = 10061, num = 300},
                            {itemId = 10062, num = 300},
                            {itemId = 10063, num = 300},
                        }
                    },
                    {
                        roundRange = "3~100",
                        rewards = {
                            {itemId = 2, num = 300},
                            {itemId = 14, num = 300},
                        },
                        showRewards = {
                            {itemId = 10061, num = 300},
                            {itemId = 2, num = 300},
                            {itemId = 10063, num = 300},
                        }
                    },
                }
            },

        }
    }
    return mockData, 0
end

return Request
