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
