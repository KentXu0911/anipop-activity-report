local RecruitHighPayExpandConst = {
    ACT_ID = 6062,
    DB_FILE = "recruit_high_pay_expand",
    OPEN_URL_TIMEOUT = 5,
    PAYMENT_POPUP_DELAY = 0,
    PAYMENT_PERIOD_LIMIT = 3,
    PAYMENT_DAY_LIMIT = 1,
    Scene = {
        ENERGY = "energy",
        PAYMENT_CANCEL = "payment_cancel",
        SIGN_IN = "sign_in",
    },
    StateKey = {
        PAYMENT_COUNT = "payment_count",
        PAYMENT_DAY = "payment_day",
        PAYMENT_DAY_COUNT = "payment_day_count",
        PAYMENT_STOPPED = "payment_stopped",
    },
}

return RecruitHighPayExpandConst
