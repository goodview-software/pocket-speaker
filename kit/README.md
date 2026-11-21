# Goodview Kit

Kit d'interface Godot 4.7 inspiré de Tailwind : jetons, police Inter, icônes Lucide, composants animés, popups modernes,
mise en page responsive et lint automatique « sans yeux ». Pas de `class_name` : tout se charge par `preload`.

## Installation dans une app

```
~/goodview-kit/sync.sh ~/mon-app        # copie kit/, fonts/, icons/ dans mon-app/kit/ (res://kit/...)
```

Dans `export_presets.cfg` : `include_filter="kit/icons/*"` (les SVG sont lus tels quels). Lancer une fois `--import` pour les polices.

```gdscript
const K := preload("res://kit/k.gd")        # point d'entrée : K.Btn, K.Card, K.Modal, K.Grid, K.Page...
K.Tokens.apply(Color("4de1b4"))              # accent (+ surfaces optionnelles : {"bg","card","card_hi","field"})
theme = K.theme()                            # thème Godot complet généré depuis les jetons
```

Changer d'accent à chaud : `K.Tokens.apply(c)` (les composants se redessinent) ou `K.Tokens.fade_to(node, c)` pour un fondu.

## Jetons (`tokens.gd`)
- Espacements ×4 px : `S0..S16` = 0/4/8/12/16/24/32/48/64 ; `TOUCH` = 44. Rayons `R_SM 6, R_MD 10, R_LG 14, R_XL 20, R_FULL`.
- Texte : `FS_XS 12, SM 14, BASE 16, LG 18, XL 20, 2XL 24, 3XL 30` (+ interlignes `line_height()`), graisses 400/500/600/700.
- Couleurs : `accent`, `pal` (50→950), `surface0..3`, `text`, `text_muted`, `border`, `success/warn/danger/info`, `on_accent`, `accent_fg`.
- Ombres `shadow(sb, 0..3)`, anneau de focus 2 px, points de rupture `bp(w)` : xs <480, sm, md 768, lg 1024, xl 1280.

## Composants (`kit/ui`)
KButton (primary/secondary/ghost/danger/icon, sm/md/lg, icône gauche/droite, `loading`), KCard (`interactive`, `selected`),
KBadge, KInput / KTextarea (libellé flottant, erreur, icône), KToggle, KSegmented, KTabs, KAvatar, KSkeleton, KEmptyState,
KToast, KTooltip, KDivider, KListRow, KProgress, KSection, KStat, KKeyValue, KIcon (`Icon.make("house", 20, color)`).
Popups : KModal (voile + flou, Échap, piège de focus, variante danger), KSheet, KDialog (`confirm`, `alert`), KMenu, KFilePicker.
Tous les états hover / pressed / focus / disabled sont animés (150 ms).

## Mise en page (`kit/layout`)
KContainer (largeur max par rupture, marges 16/24/32, signal `breakpoint_changed`), KAdaptiveGrid (colonnes = floor(largeur / min_card_width),
hauteurs égales), KSplit (2 colonnes dès `wide_at`, sinon empilé), KStack, KRow (retour à la ligne), KHStack, KPage (en-tête + défilement + zones sûres).

## Faire une page propre
1. Étendre `KPage` (`build_shell()`), ajouter les blocs dans `body` ; jamais de largeur en dur.
2. Espacements et tailles de texte uniquement via `Tokens` ; labels dans une rangée : `wrap=true`, jamais de troncature involontaire.
3. Rangées qui peuvent déborder : `KRow` (wrap) ; listes de cartes : `KAdaptiveGrid` ; contenu + panneau : `KSplit`.
4. Cibles tactiles >= 44 px ; une donnée = un seul endroit à l'écran.
5. Remplacer tout popup natif par KModal / KSheet / KMenu / KToast.
6. Lancer le lint : `await Lint.sweep(host, root, Tokens.WIDTHS_TEST, tree, "ma page")` (débordement, chevauchement, tactile, texte coupé, contraste 4,5:1, marges hors échelle, polices non-Inter, doublons).

## Galerie
`kit/gallery.tscn` (autonome) ou page cachée du launcher (5 appuis sur le titre de « À propos »).

## Licences
Inter : SIL OFL 1.1 (`licenses/Inter-OFL.txt`). Lucide : ISC (`licenses/Lucide-ISC.txt`).
