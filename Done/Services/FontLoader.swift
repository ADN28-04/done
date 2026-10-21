import CoreText
import Foundation

/// Enregistre les polices livrées avec l'app (Done/Fonts), pour ce processus uniquement.
enum FontLoader {
    static func registerBundledFonts() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        for url in urls {
            // Une police déjà enregistrée renvoie une erreur sans conséquence.
            _ = CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
