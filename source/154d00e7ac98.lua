local source = debug.getinfo(1, "S").source
local filePath = string.sub(source, 1, 1) == "@" and string.sub(source, 2) or source
local luaRoot = string.match(filePath, "^(.*Assets/Scripts/Lua)/")
local assetsRoot = string.match(filePath, "^(.*Assets)/Scripts/Lua/")
assert(luaRoot and assetsRoot, "unable to resolve Lua roots from " .. tostring(filePath))
package.path = luaRoot .. "/?.lua;" .. assetsRoot .. "/?.lua;" .. package.path

local suites = {
    (require "amf.feature.mainscene.module.icon.v2.test.IconStateWriterTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.CanonicalProgressContractTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ShaderBaseLifecycleTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.RankSemanticStateTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.IconStateSchedulerTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ProviderResultTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.AnimationBatchCoordinatorTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ParallelAnimationTaskTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PlaceholderFeedbackTasksTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.RewardPresentationMemoryTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.SharedClickCooldownTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.BundleDownloaderRetryTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.NewActivityPolicyTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.NewActivityRecordStoreTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PopupModelPersistenceTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.NotificationCoordinatorTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.NewActivityFlyPlannerTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PopupNewActivityFlowTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.IconV2ExperimentTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PackageIconV2HostTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PackageIconV2AdapterTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.SingleIconGiftV2ModuleTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.BlockIconProviderTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.MeMeFoxIconDataTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.MeMeFoxPackageIconIntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.MusicMasterIconDataTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.MusicMasterPackageIconIntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.DailyLevelIconDataTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.DailyLevelIconV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.WaterfallGiftPackageIconV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.GiftSingleIconsV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.HugeGoldGiftIconV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.NewbieGiftChoiceIconV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.CollectCardGiftIconV2IntegrationTest"),
    (require "amf.feature.localactivity.sprintgiftpackage.test.SprintGiftPackageIconV2IntegrationTest"),
    (require "amf.feature.localactivity.teamcamping.test.TeamCampingIconV2ConsumerContractTest"),
    (require "amf.feature.localactivity.teamcamping.test.TeamCampingIconV2CompatibilityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.RewardPresentationBatchTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.AccountBindPackageIconIntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.AccessToPcIconV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.AddSidebarIconV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.DesktopShortcutIconV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.AliPayGameCenterIconV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.AliPayDesktopShortcutIconV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PromoteDailyIconDataTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PromoteDailyIconV2ConfigTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PromoteDailyResLogicTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PromoteDailyPackageIconIntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PromoteDailyPackageIconVisualTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.MagicRushIconDataTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.MagicRushIntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PromotionEvent2025PackageIconIntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.WinRepeatRank2024IconV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.AssetCapabilityFactoryTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.PetIconV2IntegrationTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ColorfulStarIconRemovalTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ActivityOwnerReleaseCoordinatorTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.IconProcessorTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ActivityCleanupOwnerTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.CoreRendererTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ActivityMountStateTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.CapabilityStateMappingTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.BubbleRendererTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.IconAssetFactoryTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ActivityFakeIconFactoryTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.IconSnapshotCollectorTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ActivityMountTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ActivitySurfaceRemovalTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.BaseSurfaceRemovalTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.IconCompatibilityTestBenchTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.TimerCapabilityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ActivityRewardTimeFormatTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.LabelCapabilityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.IconPriorityControllerTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.SideIconPoolSpacingTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.RightBottomOcclusionTimingTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.IconReorderTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.DataDrivenLifecycleTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.LifecycleAnimationCapabilityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.AnimationLegacyParityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.FlyActCollectionBarrierTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ReminderTipsCapabilityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ReminderRendererTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ReminderHookLegacyParityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.TipsRendererTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.TagSlotCapabilityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.TouchActivityCapabilityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.TouchLegacyParityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.LegacyCapabilityParityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ProgressLegacyParityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.BaseDisposeLegacyParityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.BaseLifecycleLegacyParityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.AssetLegacyParityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.RemainingLegacyParityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.StateGetterLegacyParityTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ActivityStatusPipelineTest"),
    (require "amf.feature.mainscene.module.icon.v2.test.ActInfoStateOverrideTest"),
}

local failed = 0
local total = 0
local assertions = 0
for _, suite in ipairs(suites) do
    local result = suite:run()
    failed = failed + result.failed
    total = total + result.total
    assertions = assertions + (result.assertions or 0)
end

print(string.format("[IconV2] %d cases, %d failed", total, failed))
print(string.format("ICON_V2_SUMMARY\t%d\t%d\t%d", total, failed, assertions))
if failed > 0 then
    os.exit(1)
end
