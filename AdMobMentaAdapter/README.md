# AdMobMentaAdapter

Menta 作为 Google AdMob 自定义广告网络的 iOS Adapter。AdMob 后台填写的适配器类名为 **`AdMobMentaAdapter`**。

## CocoaPods

```ruby
pod 'AdMobMentaAdapter', '1.0.33'
```

本地调试：

```ruby
pod 'AdMobMentaAdapter', :path => '../'
```

## 广告位映射

| Menta | AdMob | Adapter 类 |
| --- | --- | --- |
| 开屏 `MentaMediationSplash` | App Open | `AdMobMentaSplashAdapter` |
| 横幅 `MentaMediationBanner` | Banner | `AdMobMentaBannerAdapter` |
| 插屏 `MentaMediationInterstitial` | Interstitial | `AdMobMentaInterstitialAdapter` |
| 激励视频 `MentaMediationRewardVideo` | Rewarded / Rewarded Interstitial | `AdMobMentaRewardedAdapter` |
| 信息流自渲染 `MentaMediationNativeSelfRender` | Native | `AdMobMentaNativeAdapter` |

信息流模板渲染（`MentaMediationNativeExpress`）不是 AdMob Native 的能力，请用自渲染广告位对接 Native。

## AdMob 后台配置

1. 自定义事件 / 自定义广告网络的 **Adapter class name**：
   - 所有广告位共用：`AdMobMentaAdapter`
   - 或按广告位分别填写：`AdMobMentaInterstitialAdapter`、`AdMobMentaSplashAdapter`、`AdMobMentaBannerAdapter`、`AdMobMentaRewardedAdapter`、`AdMobMentaNativeAdapter`  
   这些类都实现了 `GADMediationAdapter`（新 API），不要填写旧版 Custom Event 类名。
2. **初始化参数**
   - `appId`：Menta App ID（例如 Demo 中的 `A0004`）
   - `appKey`：Menta App Key
3. **广告位 Parameter**：Menta Placement ID（例如开屏 `P0017`、激励 `P0021`、插屏 `P0023`、Banner `P0025`、自渲染 `P0019`）

也可以在请求侧通过 `AdMobMentaAdapterExtras` 传入 `appId` / `appKey` / `placementId`。

## 依赖

`AdMobMentaAdapter.podspec` 会自动带上：

```ruby
pod 'Google-Mobile-Ads-SDK',      '>= 12.0'
pod 'MentaBaseGlobal',            '1.0.33'
pod 'MentaMediationGlobal',       '1.0.33'
pod 'MentaVlionGlobal',           '1.0.33'
pod 'MentaVlionGlobalAdapter',    '1.0.33'
```

## 接入说明

- 入口类 `AdMobMentaAdapter` 实现 `GADMediationAdapter`，并在 `setUpWithConfiguration:completionHandler:` 中初始化 `MentaAdSDK`。
- 各广告位在渲染成功后才回调 GMA 加载完成；展示前会调用 `sendWinnerNotificationWith:`。
- 开屏按 AdMob App Open 接入；激励插屏与激励视频共用 Menta 激励视频。
- 若配置了 RTB `bidResponse`，Banner / Native 走 `loadAdWithAdm:`，开屏 / 插屏 / 激励在展示时传入 adm。
