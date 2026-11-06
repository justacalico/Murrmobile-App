# Changelog
All notable changes to this project will be documented in this file. See [conventional commits](https://www.conventionalcommits.org/) for commit guidelines.

- - -
## v0.5.0 - 2026-11-06
#### Features
- 登录流程校验会话并支持整串 Cookie 粘贴 - (a85157b) - HttpAnimations
#### Bug Fixes
- 备份导入严格校验，补齐 mounted 守卫 - (a4c69c2) - HttpAnimations
- 页面跳转不再引用 dart:io，补导航细节 - (6bb1c59) - HttpAnimations
- 修复收藏单、评论区与标签编辑的问题 - (12aecd1) - HttpAnimations

- - -

## v0.4.5 - 2026-11-06
#### Bug Fixes
- 修复播放器初始化失败、重建风暴与全屏问题 - (b5c0dbc) - HttpAnimations

- - -

## v0.4.4 - 2026-11-05
#### Bug Fixes
- 区分加载失败与空状态，修复通知导航 - (06918ad) - HttpAnimations

- - -

## v0.4.3 - 2026-11-05
#### Bug Fixes
- 修复分页重复请求与过期响应覆盖 - (33ae3e4) - HttpAnimations

- - -

## v0.4.2 - 2026-11-05
#### Bug Fixes
- 登录状态变化即时响应，切换不再清空各标签页 - (3dd9b3d) - HttpAnimations
- 只对 409 或非 JSON 响应重试，避免吞掉真实错误 - (6a3333d) - HttpAnimations
- 修复 API 容错解析与会话过期检测 - (216a2da) - HttpAnimations

- - -

## v0.4.1 - 2026-11-05
#### Bug Fixes
- 修复 Cookie 处理与会话持久化 - (1e84895) - HttpAnimations

- - -

## v0.4.0 - 2026-11-03
#### Features
- 双击屏幕两侧快进/快退10秒 - (60d7eea) - HttpAnimations
- 视频/主页/播放列表分享按钮 - (0bb331d) - HttpAnimations
- 播放器倍速切换 - (c972780) - HttpAnimations
- 视频卡片加时长角标、日期和悬停预览 - (656a259) - HttpAnimations
- 添加自更新 AltStore 应用源 - (0b8326f) - HttpAnimations
#### Bug Fixes
- 修复 CI 分析告警和失效的集成测试 - (a643b5d) - HttpAnimations
- 修复手势识别器泄漏并补充语义标签 - (a004f1e) - HttpAnimations
- 切换标签页时显示加载而非闪空态 - (c812d57) - HttpAnimations
- 移除无内容的 About 页面 - (f126423) - HttpAnimations
- 请求加超时并支持失败重试 - (5d310e7) - HttpAnimations
- 无 hls_url 时显示不可用提示 - (b37a5e0) - HttpAnimations
- 应用切后台时暂停播放 - (ede3510) - HttpAnimations
- 个人简介中的链接可点击 - (90e4a6b) - HttpAnimations
- 个人主页社交链接可点击打开 - (d70e992) - HttpAnimations
- 登录态检查改用 _murrtube_v3_session - (a70d04b) - HttpAnimations
- 退出按钮真正退出应用 - (343ef86) - HttpAnimations
- 修复全屏播放时导航栏仍然可见 - (3906bcb) - HttpAnimations
- 修复被图标生成器覆盖的 Xcode 构建设置 - (01668a9) - HttpAnimations
- 修复应用图标周围白边 - (680f85f) - HttpAnimations

- - -

## v0.3.1 - 2026-09-14
#### Bug Fixes
- 视频卡片网格单元格过高导致底部留白 - (5c26fde) - HttpAnimations

- - -

## v0.3.0 - 2026-09-13
#### Features
- 设置页添加应用数据导出导入功能 - (5522289) - HttpAnimations
- 设置页新增应用信息区块 - (4c7c5f9) - HttpAnimations
- 移除从 Murrtube 拉取主题的选项 - (4fb5e6f) - HttpAnimations

- - -

## v0.2.0 - 2026-09-13
#### Features
- 小屏幕改用底部导航栏 - (24e9246) - HttpAnimations

- - -

## v0.1.1 - 2026-09-13
#### Bug Fixes
- 移除未打包的 Inter 字体引用 - (9c0315d) - HttpAnimations

- - -

## v0.1.0 - 2026-09-12
#### Features
- nested navigation — each tab gets its own Navigator, shell stays visible - (786b396) - calico
- use PopScope, add haptic feedback on interactions - (3df2728) - calico
- replace custom nav with Material 3 NavigationBar and NavigationRail - (69bcef0) - calico
- replace all MaterialPageRoute calls with platform-aware AppPageRoute - (0638197) - calico
- add Hero animations between video cards and detail page - (e8ab229) - calico
- use IndexedStack in shell for tab state preservation - (80d418b) - calico
- add platform-aware page transition utility - (9c6f3c3) - calico
- auto-open comments and scroll to target comment from notification - (9ab3311) - calico
- navigate to video detail page from notification tap - (c967a72) - calico
- Force sidebar on desktop regardless of navigation preference - (9a08a5d) - calico
- Add NavigationProvider for reactive state management - (c885201) - calico
- Make sidebar responsive to screen size - (af2893c) - calico
- Add collapsible sidebar for desktop navigation - (57915c9) - calico
- prevent screen sleep while video plays - (7f525a7) - HttpAnimations
- auto-hide fullscreen controls with timeline - (532c25d) - HttpAnimations
- tappable tags navigate to search - (17c1790) - HttpAnimations
- tag and user suggestions in search - (fc297d9) - HttpAnimations
- pagination for search page - (b2a14e0) - HttpAnimations
- support vertical fullscreen for portrait videos - (8b23e7c) - HttpAnimations
- responsive grid for recommended videos on desktop - (969df91) - HttpAnimations
- clickable links in descriptions and comments - (845fd7f) - HttpAnimations
- ability to block and unblock users - (f11c5a8) - HttpAnimations
- ability to delete and reply to comments - (79a1974) - HttpAnimations
- ability to comment on videos - (857a6db) - HttpAnimations
#### Bug Fixes
- (**home**) make pill tabs horizontally scrollable on mobile - (a5fc29f) - calico
- (**theme**) use orange primary for NavigationRail and NavigationBar indicators - (add7ac0) - calico
- (**video**) add spacing between mute and fullscreen buttons in both player modes - (482e23b) - calico
- 修复 detached HEAD 推送 GitHub 需要完整 refname 的问题 - (7e9fca4) - HttpAnimations
- responsive card aspect ratio — taller on mobile to prevent overflow - (17b5b16) - calico
- tighten video cards more — 10/11 aspect ratio, single-line title, less padding - (347aaac) - calico
- tighten video cards — reduce padding, cut grid aspect ratio from 10/16 to 10/14, fewer desktop columns - (31222f1) - calico
- replace deprecated colorScheme.background with surface across pages - (990aba4) - calico
- address analyzer warnings (deprecated background, unnecessary underscores) - (64d8cd7) - calico
- properly scroll to reply comments from notification tap - (c53c383) - calico
- parse murrtube notifications API format and show actor avatars - (c29acc7) - calico
- Use context.read instead of context.watch in event handler - (9d69189) - calico
- Ensure bottom navbar never shows when sidebar is enabled - (003290b) - calico
- Remove divider line between sidebar and main content - (f2774da) - calico
- Adjust sidebar padding to prevent overflow in collapsed state - (2b1e812) - calico
- add network permissions for all platforms - (a5b0009) - HttpAnimations
- use correct follow/unfollow API endpoints - (0a1d14d) - HttpAnimations
- add SafeArea to video detail page - (2ac24ae) - HttpAnimations
- account for android and ios system bars covering content - (117054a) - HttpAnimations

- - -

Changelog generated by [cocogitto](https://github.com/cocogitto/cocogitto).