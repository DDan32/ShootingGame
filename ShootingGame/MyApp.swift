import SwiftUI
import CoreText

@main struct MyApp: App {
    init() {
        registerCustomFonts()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

    private func registerCustomFonts() {
        // Automatically register all custom fonts from the app bundle
        let fontNames = [
            "DelaGothicOne-Regular",
            "Orbitron-Bold",
            "Orbitron-ExtraBold",
            "Orbitron-Medium",
            "Orbitron-Regular",
            "Orbitron-Black"
        ]
        
        for name in fontNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf") {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
        
        // Also register if located in subfolders
        if let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) {
            for url in urls {
                CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
            }
        }
    }
}
