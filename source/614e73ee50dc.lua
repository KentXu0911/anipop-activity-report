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
        id = "LocationService",
        class = "amf.middleware.service.location.LocationServiceBase",
        autoRegEvent = true,
        routes = {
            android = "amf.middleware.service.location.android.LocationService",
            ios = "amf.middleware.service.location.ios.LocationService",
            ohos = "amf.middleware.service.location.ohos.LocationService",
        },
        properties = {
            {name = "userManager", ref = "UserManager"},
            {name = "deviceManager", ref = "DeviceManager"},
        },
    },
    {
        id = "AnnouncementMgr",
        class = "amf.middleware.notification.announce.AnnouncementMgr",
        properties = {
            {name = "userManager", ref = "UserManager"},
            {name = "loginUtil", ref = "LoginUtil"},
        },
    },
    {
        id = "PopoutManager",
        class = "amf.middleware.ui.popout.AMFPopoutManager",
        initMethod = "init",
        autoRegEvent = true,
    },
    {
        id = "AssetsUtil",
        class = "amf.middleware.resmanagement.util.AssetsUtil",
        noneInstantiable = true,
    },
    {
        id = "Rank2026AssetManager",
        class = "amf.middleware.ui.kit.panel.rank2026.Rank2026AssetManager",
        initMethod = "initialize",
    },
    {
        id = "HideAreaConfigParser",
        class = "amf.middleware.levelarea.levelconfig.HideAreaConfigParser",
        initMethod = "init",
    },
    {
        id = "LevelAreaConfigParser",
        class = "amf.middleware.levelarea.levelconfig.LevelAreaConfigParser",
        initMethod = "init",
    },
    {
        id = "LevelUnlockConfigParser",
        class = "amf.middleware.levelarea.levelconfig.LevelUnlockConfigParser",
        initMethod = "init",
    },
    {
        id = "UnlockManager",
        class = "amf.middleware.levelarea.unlock.UnlockManager",
        initMethod = "init",
        properties = {
            {name = "HideAreaConfigParser", ref = "HideAreaConfigParser"},
            {name = "LevelAreaConfigParser", ref = "LevelAreaConfigParser"},
            {name = "LevelUnlockConfigParser", ref = "LevelUnlockConfigParser"},
            {name = "levelAreaManager", ref = "LevelAreaManager"},
        },
    },
    {
        id = "LevelAreaConfigManager",
        class = "amf.middleware.levelarea.bridge.LevelAreaConfigManager",
        initMethod = "init",
        properties = {
            {name = "HideAreaConfigParser", ref = "HideAreaConfigParser"},
            {name = "LevelAreaConfigParser", ref = "LevelAreaConfigParser"},
        },
    },
    {
        id = "LevelUnLockManager",
        class = "amf.middleware.levelarea.bridge.LevelUnLockManager",
        initMethod = "init",
        properties = {
            {name = "LevelAreaConfigParser", ref = "LevelAreaConfigParser"},
            {name = "levelAreaManager", ref = "LevelAreaManager"},
            {name = "unlockManager", ref = "UnlockManager"},
            {name = "LevelUnlockConfigParser", ref = "LevelUnlockConfigParser"},
            
        },
    },
    {
        id = "OpenDataUtil",
        class = "amf.middleware.opendata.system.common.OpenDataUtil",
        noneInstantiable = true,
        routes = {
            mini = "amf.middleware.opendata.system.mini.OpenDataUtil",
        },
    },
    {
        id = "VersionUpdateManager",
        class = "amf.feature.versionupdate.VersionUpdateManager",
        appOnly = true,
        routes = {
            android = "amf.feature.versionupdate.system.android.VersionUpdateManagerAndroid",
            ios = "amf.feature.versionupdate.system.ios.VersionUpdateManagerIOS",
            ohos = "amf.feature.versionupdate.system.ohos.VersionUpdateManagerOhos",
            win32 = "amf.feature.versionupdate.system.win32.VersionUpdateManagerWin32",
        },
        properties = {
            {name = "optionalDataManager", ref = "OptionalDataManager"},
            {name = "levelAreaManager", ref = "LevelAreaManager"},
            {name = "networkStatusManager", ref = "NetworkStatusManager"},
        },
    },
    {
        id = "PermissionManager",
        class = "amf.middleware.permission.system.common.PermissionManager",
        appOnly = true,
        routes = {
            android = "amf.middleware.permission.system.android.PermissionManagerAndroid",
            ios = "amf.middleware.permission.system.ios.PermissionManagerIOS",
            ohos = "amf.middleware.permission.system.ohos.PermissionManagerOhos",
        }
    },
    {
        id = "HapticsHandler",
        class = "amf.middleware.haptics.HapticsHandler",
        initMethod = "initialize",
        properties = {
            {name = "settingManager", ref = "SettingManager"},
            {name = "serverCacheManager", ref = "ServerCacheManager"},
            {name = "accountManager", ref = "AccountManager"},
        }
    },
    {
        id = "ExitGameManager",
        class = "amf.middleware.exit.ExitGameManager",
        initMethod = "initialize",
    },
    {
        id = "FenceManager",
        class = "amf.middleware.fence.FenceManager",
        initMethod = "initialize",
    },
    {
        id = "HeadImageSyncManager",
        class = "amf.feature.personalhub.headimagesync.HeadImageSyncManager",
        initMethod = "initialize",
        properties = {
            {name = "profileManager", ref = "ProfileManager"},
            {name = "accountManager", ref = "AccountManager"},
            {name = "fenceManager", ref = "FenceManager"},
            {name = "sdkLoginManager", ref = "SDKLoginManager"},
        }
    },
    {
        id = "UpdateProfileManager",
        class = "amf.feature.personalhub.updateprofile.UpdateProfileManager",
        initMethod = "initialize",
        properties = {
            {name = "profileManager", ref = "ProfileManager"},
            {name = "accountManager", ref = "AccountManager"},
            {name = "fenceManager", ref = "FenceManager"},
            {name = "sdkLoginManager", ref = "SDKLoginManager"},
            {name = "headImageSyncManager", ref = "HeadImageSyncManager"},
        }
    },
    {
        id = "MiniGameAdaptor",
        class = "amf.middleware.multiplatform.minigameadaptor.MiniGameAdaptor",
        initMethod = "initialize",
    },
    {
        id = "InLevelBridgeManager",
        class = "amf.middleware.activity.base.inlevelbridge.InLevelBridgeManager",
        initMethod = "initialize",
    },
    {
        id = "CloudMusicTaskReportManager",
        class = "amf.feature.localactivity.cloudmusictask.CloudMusicTaskReportManager",
        initMethod = "initialize",
    },
}
