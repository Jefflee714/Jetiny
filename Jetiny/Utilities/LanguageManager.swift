import SwiftUI

@Observable
final class LanguageManager {
    static let shared = LanguageManager()

    var language: String = "zh-Hant" {
        didSet {
            UserDefaults.standard.set(language, forKey: "AppLanguage")
        }
    }

    var locale: Locale { Locale(identifier: language) }

    static let supportedLanguages: [(code: String, name: String)] = [
        ("zh-Hant", "繁體中文"),
        ("en", "English")
    ]

    private init() {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let defaultLang = preferred.hasPrefix("zh") ? "zh-Hant" : "en"
        language = UserDefaults.standard.string(forKey: "AppLanguage") ?? defaultLang
    }
}

/// Localized string using the app's current language setting
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, locale: LanguageManager.shared.locale)
}
