#!/usr/bin/env python3
"""
Configure les projets Android et iOS générés par `flutter create` pour
Cheque Manager Pro (notifications programmées, biométrie, appareil photo...).

Usage (depuis le dossier du projet) :
    flutter create --org ma.chequemanager --project-name cheque_manager_pro --platforms android,ios .
    python outils/configurer_plateformes.py

Le script est idempotent : il peut être relancé sans risque.
"""
import pathlib
import re
import sys

RACINE = pathlib.Path(__file__).resolve().parent.parent
OK, KO = "  [OK] ", "  [!!] "


def lire(p):
    return p.read_text(encoding="utf-8")


def ecrire(p, s):
    p.write_text(s, encoding="utf-8")


# --------------------------------------------------------------- Android
def android():
    print("Android")
    manifest = RACINE / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        print(KO + "android/ introuvable : lancez d'abord `flutter create` (voir README).")
        return False
    s = lire(manifest)
    permissions = [
        "android.permission.POST_NOTIFICATIONS",
        "android.permission.VIBRATE",
        "android.permission.RECEIVE_BOOT_COMPLETED",
        "android.permission.USE_BIOMETRIC",
    ]
    for perm in permissions:
        if perm not in s:
            s = s.replace("<application", f'<uses-permission android:name="{perm}"/>\n    <application', 1)
    receivers = '''
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON" />
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
'''
    if "ScheduledNotificationReceiver" not in s:
        s = s.replace("</application>", receivers + "    </application>", 1)
    s = re.sub(r'android:label="[^"]*"', 'android:label="Cheque Manager Pro"', s, count=1)
    ecrire(manifest, s)
    print(OK + "AndroidManifest.xml : permissions, récepteurs de notifications, nom de l'application")

    # MainActivity -> FlutterFragmentActivity (exigé par local_auth)
    actives = list((RACINE / "android/app/src/main").rglob("MainActivity.kt")) + list(
        (RACINE / "android/app/src/main").rglob("MainActivity.java"))
    for a in actives:
        t = lire(a)
        t = t.replace("io.flutter.embedding.android.FlutterActivity", "io.flutter.embedding.android.FlutterFragmentActivity")
        t = re.sub(r"\bFlutterActivity\(\)", "FlutterFragmentActivity()", t)
        t = re.sub(r"extends FlutterActivity\b", "extends FlutterFragmentActivity", t)
        ecrire(a, t)
        print(OK + f"{a.name} : FlutterFragmentActivity (biométrie)")

    # Gradle : compileSdk 37, minSdk 28, desugaring
    kts = RACINE / "android/app/build.gradle.kts"
    groovy = RACINE / "android/app/build.gradle"
    if kts.exists():
        g = lire(kts)
        g = re.sub(r"compileSdk\s*=\s*[^\n]+", "compileSdk = 37", g, count=1)
        g = re.sub(r"minSdk\s*=\s*[^\n]+", "minSdk = 28", g, count=1)
        if "isCoreLibraryDesugaringEnabled" not in g:
            g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        isCoreLibraryDesugaringEnabled = true", g, count=1)
        if "desugar_jdk_libs" not in g:
            g += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        ecrire(kts, g)
        print(OK + "build.gradle.kts : compileSdk 37, minSdk 28 (Android 9+), desugaring")
    elif groovy.exists():
        g = lire(groovy)
        g = re.sub(r"compileSdk(Version)?\s*=?\s*[^\n]+", "compileSdk 37", g, count=1)
        g = re.sub(r"minSdk(Version)?\s*=?\s*[^\n]+", "minSdk 28", g, count=1)
        if "coreLibraryDesugaringEnabled" not in g:
            g = re.sub(r"compileOptions\s*\{", "compileOptions {\n        coreLibraryDesugaringEnabled true", g, count=1)
        if "desugar_jdk_libs" not in g:
            g += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
        ecrire(groovy, g)
        print(OK + "build.gradle : compileSdk 37, minSdk 28, desugaring")
    else:
        print(KO + "Fichier Gradle de l'application introuvable.")
        return False
    return True


# ------------------------------------------------------------------- iOS
def ios():
    print("iOS")
    plist = RACINE / "ios/Runner/Info.plist"
    if not plist.exists():
        print(KO + "ios/ introuvable (normal sous Windows si vous n'avez généré qu'Android).")
        return True
    s = lire(plist)
    cles = {
        "NSCameraUsageDescription": "Photographier les chèques et les justificatifs.",
        "NSPhotoLibraryUsageDescription": "Joindre une photo de chèque depuis la galerie.",
        "NSFaceIDUsageDescription": "Déverrouiller Cheque Manager Pro avec Face ID.",
    }
    for cle, texte in cles.items():
        if cle not in s:
            s = s.replace("<dict>", f"<dict>\n\t<key>{cle}</key>\n\t<string>{texte}</string>", 1)
    s = re.sub(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)", r"\1Cheque Manager Pro\2", s)
    ecrire(plist, s)
    print(OK + "Info.plist : autorisations appareil photo, galerie, Face ID")

    delegate = RACINE / "ios/Runner/AppDelegate.swift"
    if delegate.exists():
        d = lire(delegate)
        ligne = "UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate"
        if ligne not in d:
            d, n = re.subn(r"(\n(\s*)return super\.application\(application, didFinishLaunchingWithOptions)",
                           "\n    " + ligne + r"\1", d, count=1)
            if n and "import UserNotifications" not in d:
                d = d.replace("import UIKit", "import UIKit\nimport UserNotifications", 1)
            ecrire(delegate, d)
        if ligne in d:
            print(OK + "AppDelegate.swift : notifications au premier plan")
        else:
            print(KO + "AppDelegate.swift : ajoutez manuellement dans didFinishLaunchingWithOptions :\n       " + ligne)

    podfile = RACINE / "ios/Podfile"
    if podfile.exists():
        p = lire(podfile)
        p = re.sub(r"#?\s*platform :ios, '[\d.]+'", "platform :ios, '13.0'", p, count=1)
        ecrire(podfile, p)
        print(OK + "Podfile : iOS 13 minimum")
    return True


if __name__ == "__main__":
    print("Configuration de Cheque Manager Pro\n")
    ok = android() & ios()
    print("\nTerminé." if ok else "\nTerminé avec des avertissements (voir ci-dessus).")
    sys.exit(0 if ok else 1)
