# 米乳内核 Miru H.40 Linux 4.14.336 更新日志

- 内核版本由 Linux 4.14.305 更新至 Linux 4.14.336，保留 Android Common 的真实双亲合并历史和 OnePlus H.40/Oplus 下游兼容层。
- 完成 14 项真实语义冲突处理，14 项全部解决，剩余 0 项；未使用整体 `ours`/`theirs` 覆盖，也未将 Android Common 历史扁平化。
- 修复 Qualcomm DWC3 挂起事件处理与下游 glue 不匹配的问题，恢复直接 pending-event 分发；实机确认 USB 数据和 ADB 正常工作。
- 更新外部音频模块的 GPL-only codec export，并将最终构建固定到模块仓库生产提交；实机确认音频正常。
- 保留 Miru H.40 已验证的 KCAL 屏幕 RGB 校准、刷新率、AOD、指纹 HBM、NFC、充电、Wi-Fi 和其他 OnePlus/Qualcomm 适配。
- 最终构建验证包含 5 个生产 DTB、13 个内置模块和 32 个外部模块；DWC3 语义审计 40/40 通过，模块 ABI/MODVERSIONS、vermagic 与包校验全部通过。
- `4.14.336-miru-h40-lts336-ci1+` 已在 OnePlus 7 Pro 实机完整验证，维护者确认全部功能正常。
- 必须搭配同一 4.14.336 构建产物中的外部模块；不要与 4.14.305、4.14.269、旧版 Miru 或原厂模块混用。

## 验证状态

最终候选构建在 Actions run `30854697145` 通过。维护者随后在 OnePlus 7 Pro 上确认精确 `4.14.336-miru-h40-lts336-ci1+` 包完全正常。PR #87 已于 2026-08-04 以普通 merge commit `253775be7028de96f41ffcf3c5903573ff0b5fb8` 推广到 `miru-h40`。永久生产验证在 workflow-only gate correction `079c3a491e0260bbc795b8a7c2a074c2f40ac355` 后的 run `30875788887` 成功；未创建 GitHub Release 或新标签。
