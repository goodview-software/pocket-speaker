# Pocket Speaker

Le téléphone Android devient l'**enceinte** et le **micro** de ton PC Linux, en USB ou Wi-Fi (Godot 4.7).
Inspiré de usb-speaker, refait propre : une seule app (PC + Android), interface soignée, niveaux en direct, volume, latence.
Mascotte : la variante choisie dans le Goodview Launcher (profil partagé `~/.config/goodview/profile.json`) est utilisée ici ; le téléphone la reçoit du PC.

- **PC** : prérequis `adb` (USB), `pactl`, `parec`, `pacat`. Crée la sortie « Telephone-Pocket » et le micro « Micro-Telephone ».
- **Téléphone** : ouvre l'app ; en USB le PC l'installe/lance tout seul (`pocket-speaker.apk` à côté de l'exécutable).
- **Connexion** : Auto (USB puis Wi-Fi), USB seulement ou Wi-Fi seulement.
- Lancer : `flatpak run org.godotengine.Godot --path ~/pocket-speaker`
- Test de liaison sans téléphone : `POCKET_PHONE=1` (instance « téléphone ») + `POCKET_TEST=1 POCKET_NOROUTE=1` (instance PC).

Note : sur le Wi-Fi, le téléphone accepte toute connexion entrante (pas d'appairage pour l'instant).

**Sous-titres (Whisper)** : le bouton « Sous-titres en bulles » (PC ou téléphone) lance `tools/whisper_stream.py` (openai-whisper, GPU si dispo, modèle `small`, `POCKET_WHISPER=medium` pour changer) sur le son du PC et affiche en bulles, sur l'écran du téléphone, ce qui est compris (langue détectée automatiquement). Le son doit passer par Pocket Speaker (« Son » activé). Prérequis : `python3` avec `openai-whisper`.

**Bulle flottante (Android)** : en quittant l'app, un service de premier plan + une bulle « par-dessus les autres applis » (état, coupure son/micro, toucher = rouvre). Plugin Java dans `android/build/src/main/java/fr/goodview/overlay` (build gradle ; `android/build/libs` = template, à réinstaller depuis `android_source.zip` sur un clone neuf).
