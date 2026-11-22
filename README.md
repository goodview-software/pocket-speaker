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

**Sous-titres en direct (Vosk)** : le bouton « Sous-titres en bulles » lance `tools/vosk_stream.py` (reconnaissance en flux continu : les mots apparaissent pendant que ça parle, ligne verte, puis bulles à la fin de la phrase). Langue parlée au choix (fr/en/es). Prérequis : `python3 -m venv --system-site-packages ~/.local/share/pocket-speaker/venv && ~/.local/share/pocket-speaker/venv/bin/pip install vosk`, modèles `vosk-model-small-{fr-0.22,en-us-0.15,es-0.42}` dans `~/.local/share/pocket-speaker/models/` (alphacephei.com/vosk/models). La traduction (Ollama) tourne dans un fil séparé.

**Bulle flottante (Android)** : en quittant l'app, un service de premier plan + une bulle « par-dessus les autres applis » (état, coupure son/micro, toucher = rouvre). Plugin Java dans `android/build/src/main/java/fr/goodview/overlay` (build gradle ; `android/build/libs` = template, à réinstaller depuis `android_source.zip` sur un clone neuf).
