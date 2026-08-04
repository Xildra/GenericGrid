# GenericGrid

Module SwiftUI (iOS 17+ / macOS 14+) de grille générique pour le placement d'objets par drag & drop : plan de cabine, parking, entrepôt, plan de salle… La grille est pilotée par une configuration JSON et reste agnostique du stockage (SwiftData, fichiers, mémoire) grâce à des callbacks.

## Concepts

- **Grille** : un canvas de `rows × cols` cellules.
- **Compartiments** (`ColumnBand`) : partition rectangulaire de la grille (découpes horizontales et verticales). Chaque compartiment possède ses propres titres de colonnes, un nombre de subdivisions optionnel, une bordure personnalisable, et ses zones.
- **Zones** (`GridZoneDefinition`) : rectangles posés dans un compartiment avec une règle de placement :
  - `free` — placement libre ;
  - `locked` — verrouillée (utilisée aussi par le verrouillage à la volée) ;
  - `forbidden` — aucun placement ;
  - `restricted` — seuls certains types (`allowedTypeNames`) sont acceptés.
- **Items** : vos modèles, qui adoptent `GridPlaceable` (position d'ancrage à la demi-cellule + rotation) et `GridItemType` (dimensions, couleur).

> **Convention de coordonnées** : toutes les positions (zones, items, cellules du moteur) sont en coordonnées **absolues** de la grille, sur les deux axes. Les fichiers antérieurs (sans `schemaVersion`) stockaient les colonnes des zones relativement à leur compartiment ; ils sont migrés automatiquement au décodage.

## Démarrage rapide

```swift
import GenericGrid

// 1. Votre type d'objet plaçable.
struct SeatType: GridItemType {
    var id: String { name }
    var name: String
    var width: Int
    var height: Int
    var colorHex: String
    var label: String
}

// 2. Votre modèle placé (classe observable — SwiftData fonctionne tel quel).
@Observable
final class Seat: GridPlaceable {
    var itemType: SeatType?
    var anchorRow: Double
    var anchorCol: Double
    var rotated: Bool
    // …
}

// 3. Le moteur + la vue.
let config = GridCanvasConfig.load(from: "cabine_a320") ?? .default
let engine = GridEngine<Seat>(config: config)

GenericGridView(
    engine: engine,
    items: seats,
    onInsert: { type, row, col, rotated in
        // Créez et persistez l'objet, puis resynchronisez :
        // engine.sync(seats)
    },
    onConflict: { cell, occupant in /* proposer un remplacement */ },
    onLock:     { cell in /* persister le verrouillage manuel */ },
    onUnlock:   { cell in /* retirer le verrouillage persisté */ }
)
```

Sélectionnez un type (`engine.selectedType = …`, `engine.rotated = true` pour pivoter) puis tapez une cellule pour placer. Un appui long déplace un objet existant. Sans type sélectionné, un tap sur une cellule libre la verrouille/déverrouille (`engine.lockLabel` personnalise le libellé du verrou).

### Vue personnalisée pour les items

Sans rien préciser, chaque item est dessiné par `GridDefaultItemView` : rectangle à la couleur du type, avec `type.name` (et `type.label` en seconde ligne). Pour reprendre totalement la main, passez votre vue en closure finale : la grille garde la **position et la taille** du bloc, vous décidez de **tout le contenu**.

```swift
GenericGridView(engine: engine, items: seats, onInsert: { … }) { seat, ctx in
    VStack(spacing: 2) {
        Text(seat.number)
            .font(.system(size: ctx.size.height * 0.35, weight: .bold))
        if let name = seat.passenger?.lastName {
            Text(name).font(.system(size: ctx.size.height * 0.22))
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(seat.itemType?.color.opacity(ctx.opacity) ?? .gray, in: .rect(cornerRadius: 4))
    .opacity(ctx.isMoving ? 0.3 : 1)
}
```

`GridItemContext` fournit ce que la grille sait du bloc :

| Champ | Rôle |
| --- | --- |
| `size` | taille en points du bloc (dépend du footprint, du zoom et de `itemsFillZone`) — c'est ce qui sert à dimensionner le texte |
| `isMoving` | `true` pendant le déplacement de l'item (à vous de le griser si besoin) |
| `opacity` | l'opacité demandée via `itemOpacity` |

La taille de police n'est donc plus un réglage du module : elle se déduit de `ctx.size` côté implémentation (`ctx.size.height * 0.35`, `.font(.caption)`, peu importe). `GridDefaultItemView(item:context:)` reste public si vous voulez le réutiliser ou l'habiller.

### Masquer les contrôles de zoom

```swift
GenericGridView(engine: engine, items: seats, showZoomControls: false, onInsert: { … })
```

Les boutons +/−/ajuster disparaissent ; le pinch et le pan restent actifs.

### Mode « un type = un emplacement »

```swift
engine.uniqueTypes = true
```

Placer un type déjà présent **déplace** l'objet existant au lieu d'en insérer un doublon (un passager = un siège).

### Statistiques

`engine.usedCells`, `engine.totalCells` (les zones `locked`/`forbidden` sont exclues), `engine.freeCells`, `engine.fillPct`.

## Éditeur de configuration

`GridConfigGeneratorView` est un éditeur visuel complet : dimensions, split/merge de compartiments (horizontal et vertical), zones déplaçables/redimensionnables, labels, bordures, import/export JSON.

```swift
GridConfigGeneratorView(url: configURL) { savedURL in … }
```

## Format JSON

```json
{
  "schemaVersion": 2,
  "rows": 10,
  "cols": 10,
  "title": "Exemple",
  "showMainGrid": true,
  "showZoneLabels": false,
  "columnBands": [
    { "rowStart": 0, "rowEnd": 9, "colStart": 0, "colEnd": 4, "zones": [] },
    { "rowStart": 0, "rowEnd": 9, "colStart": 5, "colEnd": 9,
      "labels": ["F", "G", "H", "I", "J"],
      "zones": [
        {
          "id": "11111111-1111-1111-1111-111111111111",
          "label": "Zone restreinte",
          "rule": "restricted",
          "rowStart": 2, "rowEnd": 5,
          "colStart": 6, "colEnd": 9,
          "colorHex": "#4A90D9",
          "allowedTypeNames": ["Small"]
        }
      ] }
  ]
}
```

- Les coordonnées des zones sont absolues (`schemaVersion: 2`).
- `colEnd: -1` sur un compartiment signifie « jusqu'au bord droit de la grille ».
- Chargement : `GridCanvasConfig(contentsOf: url)` (erreurs explicites) ou `GridCanvasConfig.load(url:)` / `load(from:bundle:)` (optionnels).

## Tests

```sh
swift test
```

La suite couvre le moteur (placement, rotation, verrouillage, statistiques), les mutations de compartiments (split/merge/redimensionnement), la convention de coordonnées (hit-testing, lookups multi-compartiments) et la migration de schéma JSON.
