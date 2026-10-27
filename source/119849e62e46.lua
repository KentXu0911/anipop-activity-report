local config = {}

config.StarList = {
    {x = 242, y = 24},
    {x = 174, y = -165},
    {x = 14, y = -165},
    {x = -55, y = -274},
    {x = -87, y = -46},
    {x = 48, y = -7},
    {x = 199, y = 196},
    {x = 26, y = 212},
    {x = -138, y = 208},
    {x = -123, y = 312},
}

config.LineList = {
    {from = 1, to = 2},
    {from = 2, to = 3},
    {from = 3, to = 4},
    {from = 3, to = 5},
    {from = 5, to = 6},
    {from = 6, to = 7},
    {from = 7, to = 8},
    {from = 8, to = 9},
    {from = 9, to = 10},
}

config.BgPositonOffset = {x = 10, y = -10}

-- 在全部界面的位置
config.MainPosition = {x = 140, y = 212}
config.MainScale = 0.43 * 0.95

return config