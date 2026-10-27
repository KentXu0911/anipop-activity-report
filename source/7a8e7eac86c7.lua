
local data = {
    userData = {
        replaceTasks = {
            {
                originalTaskId = 4,
                replaceTaskId = 5,
                relateActId = 6076,
            },
        },
        perDayMap = {
            {
                unlocked = true,
                tasks = { 
                    { taskId=1, curValue = 1, finished = true},
                    { taskId=2, curValue = 0, finished = false},
                    { taskId=3, curValue = 0, finished = false},
                    { taskId=4, curValue = 0, finished = false},
                    { taskId=5, curValue = 0, finished = false},
                }
            },
            {
                unlocked = false,
                tasks = { 
                    { taskId=6, curValue = 0, finished = false},
                    { taskId=7, curValue = 0, finished = false},
                    { taskId=8, curValue = 0, finished = false},
                    { taskId=9, curValue = 0, finished = false},
                    { taskId=10, curValue = 0, finished = false},
                }
            },
            {
                unlocked = false,
                tasks = { 
                    { taskId=11, curValue = 0, finished = false},
                    { taskId=12, curValue = 0, finished = false},
                    { taskId=13, curValue = 0, finished = false},
                    { taskId=14, curValue = 0, finished = false},
                    { taskId=15, curValue = 0, finished = false},
                }
            },
            {
                unlocked = false,
                tasks = { 
                    { taskId=16, curValue = 0, finished = false},
                    { taskId=17, curValue = 2, finished = false},
                    { taskId=18, curValue = 0, finished = false},
                    { taskId=19, curValue = 0, finished = false},
                    { taskId=20, curValue = 0, finished = false},
                }
            },
            {
                unlocked = false,
                tasks = { 
                    { taskId=21, curValue = 0, finished = false},
                    { taskId=22, curValue = 0, finished = false},
                    { taskId=23, curValue = 0, finished = false},
                    { taskId=24, curValue = 0, finished = false},
                    { taskId=25, curValue = 0, finished = false},
                }
            },
            {
                unlocked = false,
                tasks = { 
                    { taskId=26, curValue = 0, finished = false},
                    { taskId=27, curValue = 0, finished = false},
                    { taskId=28, curValue = 0, finished = false},
                    { taskId=29, curValue = 0, finished = false},
                    { taskId=30, curValue = 0, finished = false},
                }
            },
            {
                unlocked = false,
                tasks = { 
                    { taskId=31, curValue = 0, finished = false},
                    { taskId=32, curValue = 0, finished = false},
                    { taskId=33, curValue = 0, finished = false},
                    { taskId=34, curValue = 0, finished = false},
                    { taskId=35, curValue = 0, finished = false},
                    { taskId=36, curValue = 0, finished = false},
                }
            }
        },
        finishedProgressBoxIds = {},
        curProgressValue = 58,
        taskFlag = 0,
        guideIds = {},
    }
}

local configTable = {
    periodId = 1,
    perDayMetas = {
        {
            dayOfWeek = 1,
            taskMetas = {
                { taskId = 1, taskType = 'TOTAL_LOGIN', target = 1, finishProgressValue = 10 },
                { taskId = 2, taskType = 'PASS_LEVEL', target = 2, finishProgressValue = 20 },
                { taskId = 3, taskType = 'PASS_LEVEL', target = 3, finishProgressValue = 30 },
                { taskId = 4, taskType = 'BLOCK_ELIMINATE_COST_BLOCK', target = 4, finishProgressValue = 40 },
                { taskId = 5, taskType = 'COLLECT_RED', target = 5, finishProgressValue = 50 },
            }
        },
        {
            dayOfWeek = 2,
            taskMetas = {
                { taskId = 6, taskType = 'TOTAL_LOGIN', target = 2, finishProgressValue = 10 },
                { taskId = 7, taskType = 'PASS_LEVEL', target = 2, finishProgressValue = 20 },
                { taskId = 8, taskType = 'PASS_LEVEL', target = 3, finishProgressValue = 30 },
                { taskId = 9, taskType = 'PASS_LEVEL', target = 4, finishProgressValue = 40 },
                { taskId = 10, taskType = 'PASS_LEVEL', target = 5, finishProgressValue = 50 },
            }
        },
        {
            dayOfWeek = 3,
            taskMetas = {
                { taskId = 11, taskType = 'TOTAL_LOGIN', target = 3, finishProgressValue = 10 },
                { taskId = 12, taskType = 'PASS_LEVEL', target = 2, finishProgressValue = 20 },
                { taskId = 13, taskType = 'PASS_LEVEL', target = 3, finishProgressValue = 30 },
                { taskId = 14, taskType = 'PASS_LEVEL', target = 4, finishProgressValue = 40 },
                { taskId = 15, taskType = 'PASS_LEVEL', target = 5, finishProgressValue = 50 },
            }
        },
        {
            dayOfWeek = 4,
            taskMetas = {
                { taskId = 16, taskType = 'TOTAL_LOGIN', target = 4, finishProgressValue = 10 },
                { taskId = 17, taskType = 'PASS_LEVEL', target = 2, finishProgressValue = 20 },
                { taskId = 18, taskType = 'PASS_LEVEL', target = 3, finishProgressValue = 30 },
                { taskId = 19, taskType = 'PASS_LEVEL', target = 4, finishProgressValue = 40 },
                { taskId = 20, taskType = 'PASS_LEVEL', target = 5, finishProgressValue = 50 },
            }
        },
        {
            dayOfWeek = 5,
            taskMetas = {
                { taskId = 21, taskType = 'TOTAL_LOGIN', target = 5, finishProgressValue = 10 },
                { taskId = 22, taskType = 'PASS_LEVEL', target = 2, finishProgressValue = 20 },
                { taskId = 23, taskType = 'PASS_LEVEL', target = 3, finishProgressValue = 30 },
                { taskId = 24, taskType = 'PASS_LEVEL', target = 4, finishProgressValue = 40 },
                { taskId = 25, taskType = 'PASS_LEVEL', target = 5, finishProgressValue = 50 },
            }
        },
        {
            dayOfWeek = 6,
            taskMetas = {
                { taskId = 26, taskType = 'TOTAL_LOGIN', target = 6, finishProgressValue = 10 },
                { taskId = 27, taskType = 'PASS_LEVEL', target = 2, finishProgressValue = 20 },
                { taskId = 28, taskType = 'PASS_LEVEL', target = 3, finishProgressValue = 30 },
                { taskId = 29, taskType = 'PASS_LEVEL', target = 4, finishProgressValue = 40 },
                { taskId = 30, taskType = 'PASS_LEVEL', target = 5, finishProgressValue = 50 },
            }
        },
        {
            dayOfWeek = 7,
            taskMetas = {
                { taskId = 31, taskType = 'TOTAL_LOGIN', target = 7, finishProgressValue = 10 },
                { taskId = 32, taskType = 'PASS_LEVEL', target = 2, finishProgressValue = 20 },
                { taskId = 33, taskType = 'PASS_LEVEL', target = 3, finishProgressValue = 30 },
                { taskId = 34, taskType = 'PASS_LEVEL', target = 4, finishProgressValue = 40 },
                { taskId = 35, taskType = 'PASS_LEVEL', target = 5, finishProgressValue = 50 },
                { taskId = 36, taskType = 'RMB', target = 1, finishProgressValue = 50 },
            }
        }
    },
    extendsValueTaskTypes = {'PASS_LEVEL'},
    progressBoxMetas = {
        { progressBoxId = 1, rewardItems = {{itemId=2,num=100}}, needTotalProgressValue = 10 },
        { progressBoxId = 2, rewardItems = {{itemId=2,num=200}}, needTotalProgressValue = 20 },
        { progressBoxId = 3, rewardItems = {{itemId=2,num=300}}, needTotalProgressValue = 30 },
        { progressBoxId = 4, rewardItems = {{itemId=2,num=400}}, needTotalProgressValue = 40 },
        { progressBoxId = 5, rewardItems = {{itemId=2,num=500}}, needTotalProgressValue = 50 },
        { progressBoxId = 6, rewardItems = {{itemId=2,num=600}}, needTotalProgressValue = 60 },
    }
}

local config = {
  config = table.serialize(configTable),
  serverMd5 = "2f0c08b9071459e9a4b4b2f444a6f4e4"
}
data.serverVersionedConfig = config

-- {
--     config = {
--         clientVersionLimit = "1.155",
--         extendsValueTaskTypes = {
--             "TOTAL_LOGIN",
--             "PASS_LEVEL",
--             "COLLECT_MAGIC_BIRD",
--             "MAGIC_RUSH_TOTAL_WIN",
--             "MUSIC_ARTIS_COLLECT",
--             "FISH_WINER_BOOK",
--             "MERGE_COST_ENERGY",
--             "GROUP_BUILDING_LEVEL_UP",
--             "LITTLE_MERGE_BOOK",
--             "CARD_COLLECT",
--         },
--         logicVersion = 1,
--         perDayMetas = {
--             {
--                 dayOfWeek = 1,
--                 taskMetas = {
--                     {
--                         finishProgressValue = 10,
--                         target = 1,
--                         taskId = 1,
--                         taskType = "TOTAL_LOGIN",
--                     },
--                     {
--                         finishProgressValue = 20,
--                         target = 30,
--                         taskId = 2,
--                         taskType = "COLLECT_MAGIC_BIRD",
--                     },
--                     {
--                         finishProgressValue = 30,
--                         target = 10,
--                         taskId = 3,
--                         taskType = "PASS_LEVEL",
--                     },
--                     {
--                         finishProgressValue = 40,
--                         target = 5,
--                         taskId = 4,
--                         taskType = "CARD_COLLECT",
--                     },
--                     {
--                         finishProgressValue = 50,
--                         target = 1,
--                         taskId = 5,
--                         taskType = "MAGIC_RUSH_TOTAL_WIN",
--                     },
--                 },
--             },
--             {
--                 dayOfWeek = 2,
--                 taskMetas = {
--                     {
--                         finishProgressValue = 10,
--                         target = 2,
--                         taskId = 6,
--                         taskType = "TOTAL_LOGIN",
--                     },
--                     {
--                         finishProgressValue = 20,
--                         target = 80,
--                         taskId = 7,
--                         taskType = "COLLECT_MAGIC_BIRD",
--                     },
--                     {
--                         finishProgressValue = 30,
--                         target = 20,
--                         taskId = 8,
--                         taskType = "PASS_LEVEL",
--                     },
--                     {
--                         finishProgressValue = 40,
--                         target = 15,
--                         taskId = 9,
--                         taskType = "CARD_COLLECT",
--                     },
--                     {
--                         finishProgressValue = 50,
--                         target = 2,
--                         taskId = 10,
--                         taskType = "MAGIC_RUSH_TOTAL_WIN",
--                     },
--                 },
--             },
--             {
--                 dayOfWeek = 3,
--                 taskMetas = {
--                     {
--                         finishProgressValue = 10,
--                         target = 3,
--                         taskId = 11,
--                         taskType = "TOTAL_LOGIN",
--                     },
--                     {
--                         finishProgressValue = 30,
--                         target = 150,
--                         taskId = 12,
--                         taskType = "COLLECT_MAGIC_BIRD",
--                     },
--                     {
--                         finishProgressValue = 40,
--                         target = 35,
--                         taskId = 13,
--                         taskType = "PASS_LEVEL",
--                     },
--                     {
--                         finishProgressValue = 70,
--                         target = 30,
--                         taskId = 14,
--                         taskType = "CARD_COLLECT",
--                     },
--                     {
--                         finishProgressValue = 100,
--                         target = 4,
--                         taskId = 15,
--                         taskType = "MAGIC_RUSH_TOTAL_WIN",
--                     },
--                 },
--             },
--             {
--                 dayOfWeek = 4,
--                 taskMetas = {
--                     {
--                         finishProgressValue = 20,
--                         target = 4,
--                         taskId = 16,
--                         taskType = "TOTAL_LOGIN",
--                     },
--                     {
--                         finishProgressValue = 40,
--                         target = 280,
--                         taskId = 17,
--                         taskType = "COLLECT_MAGIC_BIRD",
--                     },
--                     {
--                         finishProgressValue = 50,
--                         target = 50,
--                         taskId = 18,
--                         taskType = "PASS_LEVEL",
--                     },
--                     {
--                         finishProgressValue = 90,
--                         target = 50,
--                         taskId = 19,
--                         taskType = "CARD_COLLECT",
--                     },
--                     {
--                         finishProgressValue = 250,
--                         target = 7,
--                         taskId = 20,
--                         taskType = "MAGIC_RUSH_TOTAL_WIN",
--                     },
--                 },
--             },
--             {
--                 dayOfWeek = 5,
--                 taskMetas = {
--                     {
--                         finishProgressValue = 20,
--                         target = 5,
--                         taskId = 21,
--                         taskType = "TOTAL_LOGIN",
--                     },
--                     {
--                         finishProgressValue = 50,
--                         target = 450,
--                         taskId = 22,
--                         taskType = "COLLECT_MAGIC_BIRD",
--                     },
--                     {
--                         finishProgressValue = 60,
--                         target = 70,
--                         taskId = 23,
--                         taskType = "PASS_LEVEL",
--                     },
--                     {
--                         finishProgressValue = 110,
--                         target = 75,
--                         taskId = 24,
--                         taskType = "CARD_COLLECT",
--                     },
--                     {
--                         finishProgressValue = 50,
--                         target = 200,
--                         taskId = 25,
--                         taskType = "MUSIC_ARTIS_COLLECT",
--                     },
--                 },
--             },
--             {
--                 dayOfWeek = 6,
--                 taskMetas = {
--                     {
--                         finishProgressValue = 30,
--                         target = 6,
--                         taskId = 26,
--                         taskType = "TOTAL_LOGIN",
--                     },
--                     {
--                         finishProgressValue = 60,
--                         target = 660,
--                         taskId = 27,
--                         taskType = "COLLECT_MAGIC_BIRD",
--                     },
--                     {
--                         finishProgressValue = 70,
--                         target = 100,
--                         taskId = 28,
--                         taskType = "PASS_LEVEL",
--                     },
--                     {
--                         finishProgressValue = 140,
--                         target = 110,
--                         taskId = 29,
--                         taskType = "CARD_COLLECT",
--                     },
--                     {
--                         finishProgressValue = 100,
--                         target = 640,
--                         taskId = 30,
--                         taskType = "MUSIC_ARTIS_COLLECT",
--                     },
--                 },
--             },
--             {
--                 dayOfWeek = 7,
--                 taskMetas = {
--                     {
--                         finishProgressValue = 40,
--                         target = 7,
--                         taskId = 31,
--                         taskType = "TOTAL_LOGIN",
--                     },
--                     {
--                         finishProgressValue = 80,
--                         target = 800,
--                         taskId = 32,
--                         taskType = "COLLECT_MAGIC_BIRD",
--                     },
--                     {
--                         finishProgressValue = 100,
--                         target = 150,
--                         taskId = 33,
--                         taskType = "PASS_LEVEL",
--                     },
--                     {
--                         finishProgressValue = 180,
--                         target = 150,
--                         taskId = 34,
--                         taskType = "CARD_COLLECT",
--                     },
--                     {
--                         finishProgressValue = 250,
--                         target = 1200,
--                         taskId = 35,
--                         taskType = "MUSIC_ARTIS_COLLECT",
--                     },
--                     {
--                         finishProgressValue = 40,
--                         target = 1,
--                         taskId = 36,
--                         taskType = "RMB",
--                     },
--                 },
--             },
--         },
--         periodId = 1,
--         progressBoxMetas = {
--             {
--                 needTotalProgressValue = 140,
--                 progressBoxId = 1,
--                 rewardItems = {
--                     {
--                         itemId = 50687,
--                         num = 1,
--                     },
--                 },
--             },
--             {
--                 needTotalProgressValue = 300,
--                 progressBoxId = 2,
--                 rewardItems = {
--                     {
--                         itemId = 53286,
--                         num = 1,
--                     },
--                     {
--                         itemId = 10098,
--                         num = 10,
--                     },
--                 },
--             },
--             {
--                 needTotalProgressValue = 450,
--                 progressBoxId = 3,
--                 rewardItems = {
--                     {
--                         itemId = 53287,
--                         num = 1,
--                     },
--                     {
--                         itemId = 10088,
--                         num = 1,
--                     },
--                 },
--             },
--             {
--                 needTotalProgressValue = 700,
--                 progressBoxId = 4,
--                 rewardItems = {
--                     {
--                         itemId = 53288,
--                         num = 1,
--                     },
--                     {
--                         itemId = 10121,
--                         num = 10,
--                     },
--                     {
--                         itemId = 2,
--                         num = 2000,
--                     },
--                 },
--             },
--             {
--                 needTotalProgressValue = 1200,
--                 progressBoxId = 5,
--                 rewardItems = {
--                     {
--                         itemId = 53289,
--                         num = 1,
--                     },
--                     {
--                         itemId = 10059,
--                         num = 1,
--                     },
--                     {
--                         itemId = 10058,
--                         num = 1,
--                     },
--                     {
--                         itemId = 10013,
--                         num = 1,
--                     },
--                 },
--             },
--             {
--                 needTotalProgressValue = 2560,
--                 progressBoxId = 6,
--                 rewardItems = {
--                     {
--                         itemId = 53290,
--                         num = 1,
--                     },
--                     {
--                         itemId = 10060,
--                         num = 1,
--                     },
--                     {
--                         itemId = 10061,
--                         num = 1,
--                     },
--                     {
--                         itemId = 10063,
--                         num = 1,
--                     },
--                     {
--                         itemId = 10088,
--                         num = 1,
--                     },
--                     {
--                         itemId = 10098,
--                         num = 15,
--                     },
--                     {
--                         itemId = 10121,
--                         num = 15,
--                     },
--                     {
--                         itemId = 2,
--                         num = 6666,
--                     },
--                 },
--             },
--         },
--     },
--     serverMd5 = "c853d28bc399450358cb31f08d27758f",
-- }


return data
