# 验证记录 · 2026-10-12

## 已执行

- Chrome / Playwright 22 项浏览器检查通过：课前显示学科角色、课外轻触回应、上课时隐藏眼睛并禁用社交互动、进度图形变化、课间切换下一学科、下课后恢复人物，以及课程增删改、存储、离线聊天、纯文本安全显示和设置说明。
- 375、390、430 像素宽度均无横向溢出；系统“减少动态效果”生效，浏览器控制台无 JavaScript 异常。
- 已目视检查 `desktop.png`、`iphone.png`、`after-class.png` 和 `chat.png`。其中手机截图分别记录高数上课 47% 与体育下课后的状态。
- 13 个 Swift 文件通过 tree-sitter Swift 语法解析（12 个 App 源文件、1 个 XCTest 文件），没有语法错误节点。
- Xcode `.pbxproj` 通过 OpenStep 解析：57 个工程对象引用有效，全部 Swift 源文件已登记；共享 scheme、钥匙串保护级别和许可证文件检查通过。
- 项目只保留实际使用的 HorizonCalendar Swift Package，并固定到已记录的上游提交。全局小幽灵、React Kawaii 和 Pow 已从源码、资源、工程与致谢中移除。
- 机器可读结果：`validation/source-check.json`、`validation/preview-check.json`。

## 尚未验证

- **未使用 Xcode 编译，也没有执行 Swift 类型检查。** Windows 上的语法树检查不能证明 Apple API 调用、依赖解析、链接或签名一定成功。
- **未运行 iOS 模拟器、真机或原生 XCTest。** 测试源码覆盖课程时间边界、周次、冲突、归档、持久化、AI 输出契约和学科角色映射，仍须在 Mac 上实际运行。
- **未验证真实 AI 服务。** 没有用户提供的模型配置与密钥。浏览器预览只提供清楚标注的离线规则回应。
- GitHub Actions 尚未执行，当前没有签名安装包、TestFlight 分发或 App Store 构建。

## 原生验收清单

1. 在 Mac 上解析 HorizonCalendar，并运行 `xcodebuild test`；修复所有编译与 XCTest 失败后，才能标记原生构建通过。
2. 在模拟器检查六种角色在课前、上课中、课间和下课后的绘制，确认大字体、VoiceOver、减少动态效果和键盘避让。
3. 检查课程新增、编辑、删除、重叠、单双周、周末、日期浏览以及课表导入导出。
4. 用实际服务测试 AI 正常回答、无效密钥、限流、超时、错误 JSON、取消和重试，并确认当前角色与课程状态确实进入提示上下文。
5. 在设备上检查钥匙串、重启后的本机数据和文件导入导出，再准备签名分发。
