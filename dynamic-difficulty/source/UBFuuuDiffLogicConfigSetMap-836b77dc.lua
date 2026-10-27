local _adjustConfigByDiffFixMap = {

    ------------------------增加难度--------------------------------
    [7] = {
        lineFix = -5,        --平移期望线
        defaultDsFix = -5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = -1},
        },
        maxDs = 8,
        minDs = -5,
    },
    [6] = {
        lineFix = -4,        --平移期望线
        defaultDsFix = -4,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 10,
        minDs = -5,
    },
    [5] = {
        lineFix = -3,        --平移期望线
        defaultDsFix = -3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 12,
        minDs = -5,
    },
    [4] = {
        lineFix = -2,        --平移期望线
        defaultDsFix = -2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 13,
        minDs = -5,
    },
    [3] = {
        lineFix = -1,        --平移期望线
        defaultDsFix = -2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 15,
        minDs = -5,
    },
    [2] = {
        lineFix = -1,        --平移期望线
        defaultDsFix = -1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [1] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = -1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },

    ------------------------默认难度-------------------------------------
    [0] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },

    ------------------------降低难度-------------------------------------
    [-1] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0.35,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-2] = {
        lineFix = 0.3,        --平移期望线
        defaultDsFix = 0.5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-3] = {
        lineFix = 0.6,        --平移期望线
        defaultDsFix = 0.5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-4] = {
        lineFix = 1,        --平移期望线
        defaultDsFix = 0.65,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-5] = {
        lineFix = 1,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-6] = {
        lineFix = 1.3,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-7] = {
        lineFix = 1.6,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-8] = {
        lineFix = 2,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-9] = {
        lineFix = 2,        --平移期望线
        defaultDsFix = 2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-10] = {
        lineFix = 3,        --平移期望线
        defaultDsFix = 2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-11] = {
        lineFix = 3,        --平移期望线
        defaultDsFix = 3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-12] = {
        lineFix = 4,        --平移期望线
        defaultDsFix = 3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-13] = {
        lineFix = 4,        --平移期望线
        defaultDsFix = 4,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-14] = {
        lineFix = 5,        --平移期望线
        defaultDsFix = 5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 3},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-15] = {
        lineFix = 6,        --平移期望线
        defaultDsFix = 6,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 3},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-16] = {
        lineFix = 9,        --平移期望线
        defaultDsFix = 12,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 5},
            {stepDiff = 5, rate = 6, dsFix = 5},
            {stepDiff = 10, rate = 10, dsFix = 4},
        },
        maxDs = 15,
        minDs = -5,
    },
}

local _adjustConfigByStepFixMap = {

    ------------------------增加难度--------------------------------
    [1] = {
        lineFix = -7,        --平移期望线
        defaultDsFix = -15,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 3},
        },
        maxDs = 0,
        minDs = -5,
    },
    [2] = {
        lineFix = -6,        --平移期望线
        defaultDsFix = -12,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 3,
        minDs = -5,
    },
    [3] = {
        lineFix = -5,        --平移期望线
        defaultDsFix = -8,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 5,
        minDs = -5,
    },
    [4] = {
        lineFix = -5,        --平移期望线
        defaultDsFix = -5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = -1},
        },
        maxDs = 8,
        minDs = -5,
    },
    [5] = {
        lineFix = -4,        --平移期望线
        defaultDsFix = -4,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 10,
        minDs = -5,
    },
    [6] = {
        lineFix = -3,        --平移期望线
        defaultDsFix = -3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 12,
        minDs = -5,
    },
    [7] = {
        lineFix = -2,        --平移期望线
        defaultDsFix = -2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 13,
        minDs = -5,
    },
    [8] = {
        lineFix = -1,        --平移期望线
        defaultDsFix = -2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 15,
        minDs = -5,
    },
    [9] = {
        lineFix = -1,        --平移期望线
        defaultDsFix = -1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [10] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = -1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },

    ------------------------默认难度-------------------------------------
    [11] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },

    ------------------------降低难度-------------------------------------
    [12] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0.35,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [13] = {
        lineFix = 0.3,        --平移期望线
        defaultDsFix = 0.5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [14] = {
        lineFix = 0.6,        --平移期望线
        defaultDsFix = 0.5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [15] = {
        lineFix = 1,        --平移期望线
        defaultDsFix = 0.65,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [16] = {
        lineFix = 1,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [17] = {
        lineFix = 1.3,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [18] = {
        lineFix = 1.6,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [19] = {
        lineFix = 2,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [20] = {
        lineFix = 2,        --平移期望线
        defaultDsFix = 2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    -- [17] = {
    --     lineFix = 3,        --平移期望线
    --     defaultDsFix = 2,   --ds强度整体偏移
    --     stepDiffFix = {     --不同step区间内，ds的偏移值
    --         {stepDiff = 3, rate = 4, dsFix = 2},
    --         {stepDiff = 5, rate = 10, dsFix = 2},
    --         {stepDiff = 10, rate = 15, dsFix = 2},
    --     },
    --     maxDs = 15,
    --     minDs = -5,
    -- },
    [21] = {
        lineFix = 3,        --平移期望线
        defaultDsFix = 3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    -- [19] = {
    --     lineFix = 4,        --平移期望线
    --     defaultDsFix = 3,   --ds强度整体偏移
    --     stepDiffFix = {     --不同step区间内，ds的偏移值
    --         {stepDiff = 3, rate = 4, dsFix = 2},
    --         {stepDiff = 5, rate = 10, dsFix = 3},
    --         {stepDiff = 10, rate = 15, dsFix = 2},
    --     },
    --     maxDs = 15,
    --     minDs = -5,
    -- },
    [22] = {
        lineFix = 4,        --平移期望线
        defaultDsFix = 4,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [23] = {
        lineFix = 5,        --平移期望线
        defaultDsFix = 5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 3},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    -- [22] = {
    --     lineFix = 6,        --平移期望线
    --     defaultDsFix = 6,   --ds强度整体偏移
    --     stepDiffFix = {     --不同step区间内，ds的偏移值
    --         {stepDiff = 3, rate = 4, dsFix = 3},
    --         {stepDiff = 5, rate = 10, dsFix = 3},
    --         {stepDiff = 10, rate = 15, dsFix = 2},
    --     },
    --     maxDs = 15,
    --     minDs = -5,
    -- },
    [24] = {
        lineFix = 7,        --平移期望线
        defaultDsFix = 7,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 3},
            {stepDiff = 5, rate = 10, dsFix = 4},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    -- [24] = {
    --     lineFix = 8,        --平移期望线
    --     defaultDsFix = 8,   --ds强度整体偏移
    --     stepDiffFix = {     --不同step区间内，ds的偏移值
    --         {stepDiff = 3, rate = 4, dsFix = 3},
    --         {stepDiff = 5, rate = 10, dsFix = 5},
    --         {stepDiff = 10, rate = 15, dsFix = 3},
    --     },
    --     maxDs = 15,
    --     minDs = -5,
    -- },
    [25] = {
        lineFix = 9,        --平移期望线
        defaultDsFix = 9,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 4},
            {stepDiff = 5, rate = 10, dsFix = 5},
            {stepDiff = 10, rate = 15, dsFix = 4},
        },
        maxDs = 15,
        minDs = -5,
    },
    -- [26] = {
    --     lineFix = 9,        --平移期望线
    --     defaultDsFix = 10,   --ds强度整体偏移
    --     stepDiffFix = {     --不同step区间内，ds的偏移值
    --         {stepDiff = 3, rate = 4, dsFix = 5},
    --         {stepDiff = 5, rate = 10, dsFix = 5},
    --         {stepDiff = 10, rate = 15, dsFix = 4},
    --     },
    --     maxDs = 15,
    --     minDs = -5,
    -- },
    [26] = {
        lineFix = 9,        --平移期望线
        defaultDsFix = 12,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 5},
            {stepDiff = 5, rate = 6, dsFix = 5},
            {stepDiff = 10, rate = 10, dsFix = 4},
        },
        maxDs = 15,
        minDs = -5,
    },
}
--[[
local _adjustConfigByStepFixMap_2 = {

    ------------------------增加难度--------------------------------
    [1] = {
        lineFix = -7,        --平移期望线
        defaultDsFix = -12,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 3},
        },
        maxDs = 8,
        minDs = -5,
    },
    [2] = {
        lineFix = -6,        --平移期望线
        defaultDsFix = -9,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 8,
        minDs = -5,
    },
    [3] = {
        lineFix = -5,        --平移期望线
        defaultDsFix = -7,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 8,
        minDs = -5,
    },
    [4] = {
        lineFix = -5,        --平移期望线
        defaultDsFix = -5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = -1},
        },
        maxDs = 8,
        minDs = -5,
    },
    [5] = {
        lineFix = -4,        --平移期望线
        defaultDsFix = -4,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 10,
        minDs = -5,
    },
    [6] = {
        lineFix = -3,        --平移期望线
        defaultDsFix = -3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 12,
        minDs = -5,
    },
    [7] = {
        lineFix = -2,        --平移期望线
        defaultDsFix = -2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 13,
        minDs = -5,
    },
    [8] = {
        lineFix = -1,        --平移期望线
        defaultDsFix = -2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 15,
        minDs = -5,
    },
    [9] = {
        lineFix = -1,        --平移期望线
        defaultDsFix = -1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [10] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = -1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },

    ------------------------默认难度-------------------------------------
    [11] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },

    ------------------------降低难度-------------------------------------
    [12] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0.35,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [13] = {
        lineFix = 0.3,        --平移期望线
        defaultDsFix = 0.5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [14] = {
        lineFix = 0.6,        --平移期望线
        defaultDsFix = 0.5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [15] = {
        lineFix = 1,        --平移期望线
        defaultDsFix = 0.65,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [16] = {
        lineFix = 1,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [17] = {
        lineFix = 1.3,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [18] = {
        lineFix = 1.6,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [19] = {
        lineFix = 2,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [20] = {
        lineFix = 2,        --平移期望线
        defaultDsFix = 2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    -- [17] = {
    --     lineFix = 3,        --平移期望线
    --     defaultDsFix = 2,   --ds强度整体偏移
    --     stepDiffFix = {     --不同step区间内，ds的偏移值
    --         {stepDiff = 3, rate = 4, dsFix = 2},
    --         {stepDiff = 5, rate = 10, dsFix = 2},
    --         {stepDiff = 10, rate = 15, dsFix = 2},
    --     },
    --     maxDs = 15,
    --     minDs = -5,
    -- },
    [21] = {
        lineFix = 3,        --平移期望线
        defaultDsFix = 3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    -- [19] = {
    --     lineFix = 4,        --平移期望线
    --     defaultDsFix = 3,   --ds强度整体偏移
    --     stepDiffFix = {     --不同step区间内，ds的偏移值
    --         {stepDiff = 3, rate = 4, dsFix = 2},
    --         {stepDiff = 5, rate = 10, dsFix = 3},
    --         {stepDiff = 10, rate = 15, dsFix = 2},
    --     },
    --     maxDs = 15,
    --     minDs = -5,
    -- },
    [22] = {
        lineFix = 4,        --平移期望线
        defaultDsFix = 4,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [23] = {
        lineFix = 5,        --平移期望线
        defaultDsFix = 5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 3},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    -- [22] = {
    --     lineFix = 6,        --平移期望线
    --     defaultDsFix = 6,   --ds强度整体偏移
    --     stepDiffFix = {     --不同step区间内，ds的偏移值
    --         {stepDiff = 3, rate = 4, dsFix = 3},
    --         {stepDiff = 5, rate = 10, dsFix = 3},
    --         {stepDiff = 10, rate = 15, dsFix = 2},
    --     },
    --     maxDs = 15,
    --     minDs = -5,
    -- },
    [24] = {
        lineFix = 7,        --平移期望线
        defaultDsFix = 7,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 3},
            {stepDiff = 5, rate = 10, dsFix = 4},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    -- [24] = {
    --     lineFix = 8,        --平移期望线
    --     defaultDsFix = 8,   --ds强度整体偏移
    --     stepDiffFix = {     --不同step区间内，ds的偏移值
    --         {stepDiff = 3, rate = 4, dsFix = 3},
    --         {stepDiff = 5, rate = 10, dsFix = 5},
    --         {stepDiff = 10, rate = 15, dsFix = 3},
    --     },
    --     maxDs = 15,
    --     minDs = -5,
    -- },
    [25] = {
        lineFix = 9,        --平移期望线
        defaultDsFix = 9,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 4},
            {stepDiff = 5, rate = 10, dsFix = 5},
            {stepDiff = 10, rate = 15, dsFix = 4},
        },
        maxDs = 15,
        minDs = -5,
    },
    -- [26] = {
    --     lineFix = 9,        --平移期望线
    --     defaultDsFix = 10,   --ds强度整体偏移
    --     stepDiffFix = {     --不同step区间内，ds的偏移值
    --         {stepDiff = 3, rate = 4, dsFix = 5},
    --         {stepDiff = 5, rate = 10, dsFix = 5},
    --         {stepDiff = 10, rate = 15, dsFix = 4},
    --     },
    --     maxDs = 15,
    --     minDs = -5,
    -- },
    [26] = {
        lineFix = 9,        --平移期望线
        defaultDsFix = 12,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 5},
            {stepDiff = 5, rate = 6, dsFix = 5},
            {stepDiff = 10, rate = 10, dsFix = 4},
        },
        maxDs = 15,
        minDs = -5,
    },
}

local _adjustConfigByStepFixMap_old = {

    [0] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = -5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -9},
            {stepDiff = 20, rate = 24, dsFix = -7},
            {stepDiff = 20, rate = 18, dsFix = -5},
            {stepDiff = 20, rate = 12, dsFix = -3},
            {stepDiff = 20, rate = 6, dsFix = -1},
            
        },
        maxDs = 5,
        minDs = -5,
    },

    [1] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = -4,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -9},
            {stepDiff = 20, rate = 24, dsFix = -7},
            {stepDiff = 20, rate = 18, dsFix = -5},
            {stepDiff = 20, rate = 12, dsFix = -3},
            {stepDiff = 20, rate = 6, dsFix = -1},
        },
        maxDs = 6,
        minDs = -5,
    },
    [2] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = -3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -9},
            {stepDiff = 20, rate = 24, dsFix = -7},
            {stepDiff = 20, rate = 18, dsFix = -5},
            {stepDiff = 20, rate = 12, dsFix = -3},
            {stepDiff = 20, rate = 6, dsFix = -1},
        },
        maxDs = 7,
        minDs = -5,
    },
    [3] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = -2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -9},
            {stepDiff = 20, rate = 24, dsFix = -7},
            {stepDiff = 20, rate = 18, dsFix = -5},
            {stepDiff = 20, rate = 12, dsFix = -3},
            {stepDiff = 20, rate = 6, dsFix = -1},
        },
        maxDs = 8,
        minDs = -5,
    },
    [4] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = -1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -9},
            {stepDiff = 20, rate = 24, dsFix = -7},
            {stepDiff = 20, rate = 18, dsFix = -5},
            {stepDiff = 20, rate = 12, dsFix = -3},
            {stepDiff = 20, rate = 6, dsFix = -1},
        },
        maxDs = 9,
        minDs = -5,
    },
    [5] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -9},
            {stepDiff = 20, rate = 24, dsFix = -7},
            {stepDiff = 20, rate = 18, dsFix = -5},
            {stepDiff = 20, rate = 12, dsFix = -3},
            {stepDiff = 20, rate = 6, dsFix = -1},
        },
        maxDs = 10,
        minDs = -5,
    },
    [6] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -8},
            {stepDiff = 20, rate = 24, dsFix = -6},
            {stepDiff = 20, rate = 18, dsFix = -4},
            {stepDiff = 20, rate = 12, dsFix = -3},
            {stepDiff = 20, rate = 6, dsFix = -1},
        },
        maxDs = 10,
        minDs = -5,
    },
    [7] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -7},
            {stepDiff = 20, rate = 24, dsFix = -5},
            {stepDiff = 20, rate = 18, dsFix = -3},
            {stepDiff = 20, rate = 12, dsFix = -2},
            {stepDiff = 20, rate = 6, dsFix = -1},
        },
        maxDs = 10,
        minDs = -5,
    },
    [8] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -6},
            {stepDiff = 20, rate = 24, dsFix = -4},
            {stepDiff = 20, rate = 18, dsFix = -3},
            {stepDiff = 20, rate = 12, dsFix = -2},
            {stepDiff = 20, rate = 6, dsFix = -1},
        },
        maxDs = 10,
        minDs = -5,
    },
    [9] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -5},
            {stepDiff = 20, rate = 24, dsFix = -4},
            {stepDiff = 20, rate = 18, dsFix = -3},
            {stepDiff = 20, rate = 12, dsFix = -2},
            {stepDiff = 20, rate = 6, dsFix = -1},
    },
        maxDs = 10,
        minDs = -5,
    },
    [10] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -4},
            {stepDiff = 20, rate = 24, dsFix = -3},
            {stepDiff = 20, rate = 18, dsFix = -2},
            {stepDiff = 20, rate = 12, dsFix = -1},
        },
        maxDs = 10,
        minDs = -5,
    },
    [11] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -3},
            {stepDiff = 20, rate = 24, dsFix = -2},
            {stepDiff = 20, rate = 18, dsFix = -1},
        },
        maxDs = 11,
        minDs = -5,
    },
    [12] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -2},
            {stepDiff = 20, rate = 24, dsFix = -1},
        },
        maxDs = 12,
        minDs = -5,
    },
    [13] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 30, dsFix = -1},
        },
        maxDs = 13,
        minDs = -5,
    },
    [14] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
        },
        maxDs = 14,
        minDs = -5,
    },
    [15] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
        },
        maxDs = 15,
        minDs = -5,
    },
    -------------------------------------------------------------------------------     
    [16] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 12, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },

    [17] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 12, dsFix = 2},
            {stepDiff = 20, rate = 6, dsFix = 1},
            {stepDiff = 10, rate = 5, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [18] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 20, rate = 18, dsFix = 3},
            {stepDiff = 20, rate = 12, dsFix = 2},
            {stepDiff = 20, rate = 6, dsFix = 1},
            {stepDiff = 10, rate = 5, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [19] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
        {stepDiff = 6, rate = 5, dsFix = 1},
        {stepDiff = 10, rate = 5, dsFix = 2},
        {stepDiff = 20, rate = 18, dsFix = 4},
        {stepDiff = 20, rate = 12, dsFix = 3},
        {stepDiff = 20, rate = 6, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [20] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 6, rate = 5, dsFix = 1},
            {stepDiff = 10, rate = 5, dsFix = 2},
            {stepDiff = 20, rate = 24, dsFix = 5},
            {stepDiff = 20, rate = 18, dsFix = 4},
            {stepDiff = 20, rate = 12, dsFix = 3},
            {stepDiff = 20, rate = 6, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [21] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 6, rate = 5, dsFix = 1},
            {stepDiff = 10, rate = 5, dsFix = 2},
            {stepDiff = 20, rate = 30, dsFix = 7},
            {stepDiff = 20, rate = 24, dsFix = 6},
            {stepDiff = 20, rate = 18, dsFix = 5},
            {stepDiff = 20, rate = 12, dsFix = 4},
            {stepDiff = 20, rate = 6, dsFix = 3},
        },
        maxDs = 15,
        minDs = -5,
    },
    [22] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 5, dsFix = 1},
            {stepDiff = 6, rate = 5, dsFix = 1},
            {stepDiff = 10, rate = 5, dsFix = 2},
            {stepDiff = 20, rate = 30, dsFix = 8},
            {stepDiff = 20, rate = 24, dsFix = 7},
            {stepDiff = 20, rate = 18, dsFix = 5},
            {stepDiff = 20, rate = 12, dsFix = 4},
            {stepDiff = 20, rate = 6, dsFix = 3},
        },
        maxDs = 15,
        minDs = -5,
    },
    [23] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 10, dsFix = 2},
            {stepDiff = 3, rate = 5, dsFix = 1},
            {stepDiff = 6, rate = 5, dsFix = 2},
            {stepDiff = 10, rate = 5, dsFix = 3},
            {stepDiff = 20, rate = 30, dsFix = 8},
            {stepDiff = 20, rate = 24, dsFix = 7},
            {stepDiff = 20, rate = 18, dsFix = 6},
            {stepDiff = 20, rate = 12, dsFix = 5},
            {stepDiff = 20, rate = 6, dsFix = 4},
        },
        maxDs = 15,
        minDs = -5,
    },
    [24] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 4,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 10, dsFix = 2},
            {stepDiff = 3, rate = 5, dsFix = 1},
            {stepDiff = 6, rate = 5, dsFix = 2},
            {stepDiff = 10, rate = 5, dsFix = 3},
            {stepDiff = 20, rate = 30, dsFix = 9},
            {stepDiff = 20, rate = 24, dsFix = 8},
            {stepDiff = 20, rate = 18, dsFix = 7},
            {stepDiff = 20, rate = 12, dsFix = 5},
            {stepDiff = 20, rate = 6, dsFix = 4},
        },
        maxDs = 15,
        minDs = -5,
    },
    [25] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 4,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 10, dsFix = 3},
            {stepDiff = 3, rate = 5, dsFix = 2},
            {stepDiff = 6, rate = 5, dsFix = 3},
            {stepDiff = 10, rate = 5, dsFix = 5},
            {stepDiff = 20, rate = 30, dsFix = 9},
            {stepDiff = 20, rate = 24, dsFix = 8},
            {stepDiff = 20, rate = 18, dsFix = 7},
            {stepDiff = 20, rate = 12, dsFix = 6},
            {stepDiff = 20, rate = 6, dsFix = 5},
        },
        maxDs = 15,
        minDs = -5,
    },
    [26] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 10, dsFix = 5},
            {stepDiff = 3, rate = 5, dsFix = 3},
            {stepDiff = 6, rate = 5, dsFix = 5},
            {stepDiff = 10, rate = 5, dsFix = 8},
            {stepDiff = 20, rate = 30, dsFix = 9},
            {stepDiff = 20, rate = 24, dsFix = 8},
            {stepDiff = 20, rate = 18, dsFix = 7},
            {stepDiff = 20, rate = 12, dsFix = 6},
            {stepDiff = 20, rate = 6, dsFix = 5},
        },
        maxDs = 15,
        minDs = -5,
    },
}
]]

return { diffFixMap = _adjustConfigByDiffFixMap, stepFixMap = _adjustConfigByStepFixMap}