--------------------- 注意事项 ---------------------
-- id是必须的
--class 和 routes 二选一
--routes 用于跨平台的class路径配置, 优先寻找routes， 没找到使用class作为默认路径
--[[
routes = {
    android = "amf.middleware.data.userdata.android.AMFUserTagManager",
    ios = "amf.middleware.data.userdata.ios.AMFUserTagManager",
    ohos = "amf.middleware.data.userdata.ohos.AMFUserTagManager",
    linux = "amf.middleware.data.userdata.linux.AMFUserTagManager",
    win32 = "amf.middleware.data.userdata.win32.AMFUserTagManager",
},
]]
-- scope字段默认为singleton，可以缺省
-- lazyInit字段默认为false，可以缺省
-- constructorArgs字段默认为nil，可以缺省，constructorArgs内部除value字段外，其它也可缺省
--      如果有constructorArgs字段，create时会依次传入参数，注意顺序和空值
-- initMethod字段默认为nil，可以缺省，如果有initMethod字段，则在bean实例化后会调用该方法，调用顺序是create->setProperties->initMethod
--      用到其它类的实例做初始化时，可以在initMethod中调用，此时其它类已经被注入了
-- properties字段默认为nil，可以缺省，其内type字段可缺省
--      name字段是必须的，且保证对应的类中已经定义了对应的setter方法，比如name为propParam1NameA，则类中必须有setPropParam1NameA方法
--      value和ref字段至少有一个，value和ref字段不要同时存在，会优先判断value字段
--      ref字段是要注入的其它类的id，其它类必须在本配置文件中定义，否则会报错
-- autoRegEvent字段默认nil, 为true时，自动注册到EventCenter的FeatureEventBus，SystemEventBus，TransactionEventBus
---------------------------------------------------
-- ioc框架支持循环引用，示例本身就是循环引用的例子：CongfigA_ClassA->CongfigA_ClassB->CongfigB_ClassC->CongfigA_ClassA
-- 注意：循环引用时，如果定义了initMethod，initMethod的调用顺序与实例创建顺序是反的
---------------------------------------------------
-- ClassConfigA.lua和ClassConfigB.lua是两个示例配置文件
-- 最简单的定义方式是只有id和class字段，其它字段都可以缺省，像ClassConfigB.lua中的CongfigB_ClassD和CongfigB_ClassE
---------------------------------------------------
return {
    {
        id = "MainApplication",
        routes = {
            android = "amf.feature.login.system.android.MainApplication",
            ios = "amf.feature.login.system.ios.MainApplication",
            ohos = "amf.feature.login.system.ohos.MainApplication",
            linux = "amf.feature.login.system.win32.MainApplication",
            win32 = "amf.feature.login.system.win32.MainApplication",
            mac = "amf.feature.login.system.standalone.MainApplication",
            mini = "amf.feature.login.system.mini.MainApplication",
        },
        initMethod = "init",    -- init里面用到了注入的其它类，必须显示的指明初始化函数，将new和init分开
        properties = {
            {name = "deviceAccountMgr", ref = "DeviceAccountMgr"},
            {name = "loginStatus", ref = "LoginStatus"},
            {name = "userManager", ref = "UserManager"},
            {name = "hugeEngineMgr", ref = "HugeEngineDeepLinkMgr"},
        },
    },
    {
        id = "MetaManager",
        class = "amf.middleware.data.config.MetaManager",
    },
    {
        id = "ResourceConfig",
        class = "amf.feature.login.system.common.ResourceConfig",
        routes = {
            mini = "amf.feature.login.system.mini.ResourceConfig",
        }
    },
    {
        id = "PhoneLoginHistoryChecker",
        class = "amf.feature.login.stage.load.PhoneLoginHistoryChecker",
        initMethod = "initialize",
    },
    {
        id = "AppReportManager",
        class = "amf.feature.ad.appreport.AppReportManager",
        initMethod = "initialize",
    },
    {
        id = "ShanYanManager",
        class = "amf.middleware.multiplatform.login.shanyan.ShanYanManager",
        initMethod = "initialize",
        properties = {
            {name = "cacheAccountLogic", ref = "CacheAccountLogic"},
        },
    },
    {
        id = "FlyVerifyManager",
        class = "amf.middleware.multiplatform.login.flyverify.FlyVerifyManager",
        initMethod = "initialize",
        properties = {
            {name = "cacheAccountLogic", ref = "CacheAccountLogic"},
        },
    },
    {
        id = "PhoneLoginManager",
        class = "amf.middleware.multiplatform.login.PhoneLoginManager",
        initMethod = "initialize",
        properties = {
            {name = "shanYanManager", ref = "ShanYanManager"},
            {name = "flyVerifyManager", ref = "FlyVerifyManager"},
        },
    },
    {
        id = "LoginUtil",
        class = "amf.feature.login.util.LoginUtil",
    },
    {
        id = "DeviceAccountMgr",
        class = "amf.feature.login.stage.login.account.DeviceAccountMgr",
        properties = {
            {name = "loginUtil", ref = "LoginUtil"},
        },
    },
    {
        id = "CacheAccountLogic",
        class = "amf.feature.login.stage.login.account.CacheAccountLogic",
    },
    {
        id = "RegisterMgr",
        class = "amf.feature.login.stage.login.register.RegisterMgr",
        properties = {
            {name = "loginUtil", ref = "LoginUtil"},
        },
    },
    {
        id = "LoginStatus",
        class = "amf.feature.login.stage.login.LoginStatus",
    },
    {
        id = "CommonLoginLogic",
        class = "amf.feature.login.system.common.CommonLoginLogic",
        routes = {
            mini = "amf.feature.login.system.mini.CommonLoginLogic",
        },
        properties = {
            {name = "deviceAccountMgr", ref = "DeviceAccountMgr"},
            {name = "loginUtil", ref = "LoginUtil"},
            {name = "userManager", ref = "UserManager"},
            {name = "registerMgr", ref = "RegisterMgr"},
            {name = "cacheAccountLogic", ref = "CacheAccountLogic"},
            {name = "loginStatus", ref = "LoginStatus"},
            {name = "networkCheckLogic", ref = "NetworkCheckLogic"},
            {name = "sdkLoginManager", ref = "SDKLoginManager"},
        },
    },
    {
        id = "SDKLoginManager",
        routes = {
            android = "amf.middleware.multiplatform.system.android.SDKLoginManager",
            ios = "amf.middleware.multiplatform.system.ios.SDKLoginManager",
            ohos = "amf.middleware.multiplatform.system.ohos.SDKLoginManager",
            linux = "amf.middleware.multiplatform.system.win32.SDKLoginManager",
            win32 = "amf.middleware.multiplatform.system.win32.SDKLoginManager",
            mac = "amf.middleware.multiplatform.system.win32.SDKLoginManager",
            mini = "amf.middleware.multiplatform.system.mini.SDKLoginManager",
        },
    },
    {
        id = "SilentBindMgr",
        class = "amf.feature.accountbind.silentbind.SilentBindMgr",
        initMethod = "initialize",
        appOnly = true,
        properties = {
            -- {name = "profileManager", ref = "ProfileManager"},
            {name = "accountManager", ref = "AccountManager"},
            {name = "levelAreaManager", ref = "LevelAreaManager"},
        },   
    },
    {
        id = "FAQ",
        class = "amf.middleware.faq.FAQ",
        initMethod = "initialize",
        routes = {
            android = "amf.middleware.faq.system.android.FAQ",
            ios = "amf.middleware.faq.system.ios.FAQ",
            ohos = "amf.middleware.faq.system.ohos.FAQ",
            mini = "amf.middleware.faq.system.mini.FAQ",
        },
    },
    {
        id = "YYBWashingPackageManager",
        class = "amf.feature.localactivity.yybwashingpackage.YYBWashingPackageManager",
        properties = {
        },
        initMethod = "initialize",
    },
    {
        id = "HugeEngineDeepLinkMgr",
        class = "amf.feature.ad.hugeengine.HugeEngineDeepLinkMgr",
        properties = {
        },
        initMethod = "initialize",
    },
}