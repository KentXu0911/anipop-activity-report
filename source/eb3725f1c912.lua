local YYBWashingPackageConfig = {}

YYBWashingPackageConfig.bShowLog = true

YYBWashingPackageConfig.actId = 9076
YYBWashingPackageConfig.actSource = 'yybWashingPackage01/Config.lua'
YYBWashingPackageConfig.openPassLevel = 500

-----配置
YYBWashingPackageConfig.yybScheme = 'tmast://appdetails?pname=com.happyelements.AndroidAnimal.qq'

YYBWashingPackageConfig.commonPackageName = 'com.happyelements.AndroidAnimal'
YYBWashingPackageConfig.commonMainActivityName = 'com.happyelements.hellolua.MainActivity'
YYBWashingPackageConfig.commonActivityAliasName = 'com.happyelements.hellolua.HELauncher'

YYBWashingPackageConfig.HEPlatformInfoConfigs = {
	platform = PlatformNameEnum.kHE, 
	packageName = YYBWashingPackageConfig.commonPackageName,
	launchScheme = 'happyanimal3://', --happyanimalchangelaunch 是he独有的
	MainActivity = YYBWashingPackageConfig.commonMainActivityName, 
	LaunchActivity = YYBWashingPackageConfig.commonActivityAliasName
}


YYBWashingPackageConfig.DownPackagePanelShowType = {
	kDownUIShow = 1, --默认下载按钮面板
	kDownLoadingPackage = 4, --下载安装包loading
	kDownLoadComplete = 5, --安装包下载完成
	kDownLoadError = 6, --下载失败
	kInstallApkComplete = 7, --安装完成
	kDownLoadErrorNoNetWork = 8, --下载失败,没有网
}


-----

return YYBWashingPackageConfig