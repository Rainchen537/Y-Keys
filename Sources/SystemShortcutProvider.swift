import Carbon
import Foundation

enum SystemShortcutProvider {
    static func sections() -> [ShortcutSection] {
        [
            ShortcutSection(title: "启动台和程序坞", items: [
                item("打开或关闭隐藏程序坞", [.option, .command], "D"),
                item("强制退出应用程序", [.option, .command], "Esc"),
                item("应用程序窗口", [.control], "↓"),
                item("调度中心", [.control], "↑")
            ]),
            ShortcutSection(title: "聚焦和访达", items: [
                item("显示「聚焦」搜索", [.command], "Space"),
                item("显示 Finder 搜索窗口", [.option, .command], "Space"),
                item("打开当前应用帮助", [.shift, .command], "/")
            ]),
            ShortcutSection(title: "截屏和录制", items: [
                item("将屏幕图片存储为文件", [.shift, .command], "3"),
                item("将屏幕图片拷贝到剪切板", [.control, .shift, .command], "3"),
                item("将所选区域图片存储为文件", [.shift, .command], "4"),
                item("将所选区域图片拷贝到剪切板", [.control, .shift, .command], "4"),
                item("截屏和录制选项", [.shift, .command], "5")
            ]),
            ShortcutSection(title: "辅助功能", items: [
                item("放大", [.option, .command], "="),
                item("缩小", [.option, .command], "-"),
                item("打开或关闭旁白", [.command], "F5"),
                item("显示辅助功能控制", [.option, .command], "F5")
            ]),
            ShortcutSection(title: "输入法", items: [
                item("选择上一个输入法", [.control], "Space"),
                item("选择输入法菜单中的下一个输入法", [.control, .option], "Space")
            ])
        ]
    }

    private static func item(
        _ title: String,
        _ modifiers: Set<KeyModifier>,
        _ key: String
    ) -> ShortcutItem {
        ShortcutItem(
            title: title,
            subtitle: nil,
            combo: KeyCombo(modifiers: modifiers, key: key),
            isEnabled: true
        )
    }
}
