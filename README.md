# HSK Help

**HSK Help** est une application mobile **Flutter**, entièrement **hors ligne**, pour réviser le **vocabulaire** chinois et étudier la **grammaire** du mandarin — des niveaux **HSK 1 à 7-9**. L'interface et les significations sont disponibles en **français, anglais et chinois**.

![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-%5E3.10.7-0175C2?logo=dart&logoColor=white)
![Plateforme](https://img.shields.io/badge/plateforme-Android-3DDC84?logo=android&logoColor=white)
![Hors ligne](https://img.shields.io/badge/100%25-hors%20ligne-success)
![Tests](https://img.shields.io/badge/tests-24%20%2F%2024-brightgreen)
![Licence](https://img.shields.io/badge/licence-MIT-blue)

Aucun compte, aucun serveur, aucune connexion réseau à l'exécution : le lexique, la grammaire, les exercices et les polices sont embarqués dans l'application.

---

## Sommaire

- [Présentation](#présentation)
- [Télécharger l'application](#télécharger-lapplication)
- [Fonctionnalités](#fonctionnalités)
  - [Révision du vocabulaire](#révision-du-vocabulaire)
  - [Grammaire et exercices](#grammaire-et-exercices)
  - [Moteur d'apprentissage adaptatif](#moteur-dapprentissage-adaptatif)
  - [Réglages, thèmes et langues](#réglages-thèmes-et-langues)
- [Prise en main](#prise-en-main)
  - [Prérequis](#prérequis)
  - [Installation et lancement](#installation-et-lancement)
  - [Générer l'APK](#générer-lapk)
- [Tests et qualité](#tests-et-qualité)
- [Architecture du projet](#architecture-du-projet)
- [Données embarquées](#données-embarquées)
- [Chaîne de fabrication des données](#chaîne-de-fabrication-des-données)
- [Comparaison du pinyin](#comparaison-du-pinyin)
- [Hors ligne et vie privée](#hors-ligne-et-vie-privée)
- [Contribuer](#contribuer)
- [Licence](#licence)
- [Remerciements](#remerciements)

---

## Présentation

L'application propose deux activités complémentaires, accessibles depuis une bascule sur l'écran d'accueil :

| Mode | Principe |
| --- | --- |
| **Vocabulaire** | Un mot chinois est affiché en grand ; il faut saisir son **pinyin**. La correction tient compte des tons (au choix) et affiche la signification. |
| **Grammaire** | Une bibliothèque de **513 règles** classées par niveau, section et catégorie, avec explications, structures et exemples — et des exercices à deux formes générés à partir de ces exemples. |

La progression, les statistiques et tous les réglages sont conservés **localement sur l'appareil** (`shared_preferences`). Rien n'est envoyé nulle part.

---

## Télécharger l'application

Les versions publiées sont fournies ci-dessous au format **APK**, à installer directement (aucun magasin d'applications requis). La **dernière version est recommandée**.

| Version | Date | Taille | Interface | Contenu | APK |
| --- | --- | ---: | --- | --- | --- |
| **3.2.0** ⭐ | 15 nov. 2026 | 50,1 Mo | fr · en · zh | **Version actuelle** — 513 règles de grammaire, 102 600 exercices pré-calculés, polices allégées. | [HSKHelp-3.2.0.apk](HSKHelp-3.2.0.apk)|

<!-- Pour ajouter une version, dupliquez la ligne ci-dessus :
| **X.Y.Z** ⭐ | JJ mois AAAA | XX,X Mo | fr · en · zh | Description courte. | [HSKHelp-X.Y.Z.apk](HSKHelp-X.Y.Z.apk) |
-->

**Installation** — téléchargez l'APK, autorisez l'installation depuis des sources inconnues, puis ouvrez le fichier. Les versions **3.2.x** nécessitent **Android 7.0 (API 24) ou plus récent**.

> Les liens ci-dessus pointent vers les fichiers versionnés dans ce dépôt. Pour un téléchargement en un clic, vous pouvez aussi attacher les APK à une *release* GitHub.

---

## Fonctionnalités

### Révision du vocabulaire

- **11 000 mots** issus des listes de vocabulaire HSK, tous niveaux confondus :

  | Niveau | Entrées | Traductions |
  | --- | ---: | --- |
  | 1 | 300 | fr · en · zh |
  | 2 | 200 | fr · en · zh |
  | 3 | 500 | fr · en · zh |
  | 4 | 1 000 | fr · en · zh |
  | 5 | 1 600 | fr · en · zh |
  | 6 | 1 800 | fr · en · zh |
  | 7-9 | 5 600 | *aucune* (voir ci-dessous) |
  | **Total** | **11 000** | |

- **Sélection cumulative** : le curseur « du niveau 1 à N » entraîne sur tous les niveaux inférieurs ou égaux au niveau choisi.
- **Sessions** de **10** mots, **20** mots ou **tous** les mots de la sélection.
- Les mots **non maîtrisés passent en priorité**, dans un ordre aléatoire ; des rappels de mots déjà acquis complètent la session.
- **Saisie du pinyin** libre : avec les accents (`nǐhǎo`), avec les chiffres de ton (`ni3hao3`) ou sans espace. Un **pavé de tons** sous le champ insère une voyelle accentuée à la position du curseur.
- Réglage **« Exiger les tons »** : activé, le bon ton est obligatoire ; désactivé, seules les lettres comptent. Une simple **erreur de ton** est signalée explicitement.
- **Indice** (première lettre du pinyin) et bouton **« Je ne sais pas »** qui révèle la réponse sans faux verdict.
- **Bilan de session** : score, nombre de nouveaux mots maîtrisés, meilleure série.

#### Le cas particulier des niveaux 7-9

Les listes HSK 7-9 ne fournissent **aucune traduction**. Plutôt que d'en inventer, la carte **Signification** y affiche le **pinyin** à la place de la glose, et la ligne « Pinyin : » séparée est masquée pour éviter un doublon.

### Grammaire et exercices

- **513 règles** réparties en **5 niveaux** (A1 → HSK 1 … C1 → HSK 5-6), **3 sections** (*Catégories grammaticales*, *Structures grammaticales*, *Comparaisons*) et **33 catégories** (Adverbes, Verbes, Particules, Prépositions…).
- Navigation **niveau → section → catégorie → règle**. Chaque fiche de règle présente son titre, ses parties, ses **structures** et ses **exemples** — hanzi, pinyin et traduction, le **mot clé en rouge**.
- Contenu traduit **intégralement en français, anglais et chinois** : titres, explications, structures et traductions d'exemples.
- **102 600 exercices pré-calculés** : **100 « mot manquant »** et **100 « phrase mélangée »** par règle (51 300 de chaque type), fabriqués une fois pour toutes et embarqués.
  - *mot manquant* — une phrase à trou, **quatre propositions** et un indice (le sens du mot manquant) ;
  - *phrase mélangée* — les morceaux de la phrase à remettre dans l'ordre.
- **Sessions de 15 questions**, tirées **vraiment au hasard** dans tous les niveaux disponibles : une règle ne revient pas deux fois dans une session, et deux exercices du **même type** ne s'enchaînent jamais plus de deux fois.
- Bouton **« s'exercer »** depuis une fiche pour s'entraîner sur une seule règle.
- Après chaque réponse, la **règle est rappelée** (rappel affiché systématiquement).

### Moteur d'apprentissage adaptatif

`lib/services/learning_engine.dart` est un moteur persistant (`shared_preferences`) qui combine **dix algorithmes** pour choisir l'élément le plus utile au bon moment :

1. **SM-2** — répétition espacée (intervalle et facteur de facilité) ;
2. **Leitner** — boîtes de maîtrise (1 → 5) ;
3. **BKT** (Bayesian Knowledge Tracing) — probabilité de maîtrise latente ;
4. **Elo** — compétence de l'apprenant face à la difficulté de l'item ;
5. **Courbe d'oubli d'Ebbinghaus** — révision au bord de l'oubli ;
6. **Difficulté adaptative** — cible la zone proximale de développement ;
7. **Analyse des erreurs** — séries d'échecs et erreurs récentes ;
8. **Vitesse d'apprentissage** — rythme de progression ;
9. **Indice de maîtrise** — note de maîtrise par item ;
10. **Ensemble pondéré** — pondération de tous les signaux pour la sélection finale.

### Réglages, thèmes et langues

- **Niveau** : curseur cumulatif « jusqu'au niveau N » (7 = bandeau 7-9). Il pilote l'accueil, le paquet **et** la grammaire.
- **Tons** : exiger ou non les tons dans la saisie.
- **Thème** : **8 palettes** (4 claires, 4 sombres), dérivées d'une `Palette` dont les teintes secondaires et le contraste du texte sont calculés automatiquement (luminance WCAG).
- **Langue** : **français, anglais ou chinois**. Le choix porte sur toute l'interface ; les significations suivent la langue quand une traduction existe.

---

## Prise en main

### Prérequis

- [Flutter](https://docs.flutter.dev/get-started/install) stable, avec un SDK Dart compatible avec la contrainte du projet (`^3.10.7`).
- Pour Android : Android Studio (SDK + outils de build) et un émulateur, ou un appareil connecté.

### Installation et lancement

Le projet Flutter se trouve dans le dossier `hskhelp/` :

```bash
cd hskhelp
flutter pub get
flutter run
```

Dans un IDE, ouvrez le dossier `hskhelp` et lancez la configuration Flutter.

### Générer l'APK

```bash
cd hskhelp
flutter build apk --release
```

L'APK est produit dans `hskhelp/build/app/outputs/flutter-apk/app-release.apk`. Pour le distribuer, copiez-le à la racine du dépôt sous `HSKHelp-<version>.apk`, puis ajoutez-le au tableau [Télécharger l'application](#télécharger-lapplication) :

```bash
cp hskhelp/build/app/outputs/flutter-apk/app-release.apk HSKHelp-3.2.0.apk
```

> **Publication Android** — la configuration Gradle actuelle signe la version *release* avec les **clés de débogage** (`signingConfig = signingConfigs.getByName("debug")`), ce qui suffit pour tester et installer, mais **pas** pour publier sur le Play Store. Avant une distribution publique, configurez une clé de signature de release dans `android/app/build.gradle.kts`.

---

## Tests et qualité

```bash
cd hskhelp
flutter analyze     # analyse statique — aucun avertissement
flutter test        # 24 tests
```

Les tests couvrent notamment la **comparaison du pinyin** (les 11 000 mots du JSON réel acceptent leur propre transcription, les tons erronés sont refusés), la structure du lexique (décomptes par niveau, traductions 1-6 présentes / 7-9 absentes, identifiants uniques), le **moteur d'apprentissage**, la **grammaire** (chargement, tirage de session, deux types d'exercices, textes traduits) et plusieurs parcours d'interface (accueil, quiz, réglages, exercices).

---

## Architecture du projet

```text
HskHelp/
├── hskhelp/                        # projet Flutter
│   ├── android/                    # hôte Android (Gradle / Kotlin)
│   ├── assets/
│   │   ├── vocab.json              # 11 000 mots HSK (fr · en · zh)
│   │   ├── grammar_rules.json      # 513 règles de grammaire
│   │   ├── grammar_exercises.json  # 102 600 exercices pré-calculés
│   │   └── fonts/                  # HskHelp-Regular.ttf · HskHelp-Bold.ttf
│   ├── lib/
│   │   ├── data/                   # chargement du lexique, paquet, table des syllabes
│   │   ├── models/                 # Word, Pinyin, GrammarRule, GrammarExercise
│   │   ├── screens/                # accueil, quiz, grammaire, réglages, bilan
│   │   ├── services/               # dépôts, moteur adaptatif, statistiques
│   │   ├── l10n.dart               # textes fr / en / zh
│   │   ├── main.dart
│   │   └── theme.dart              # palettes et dérivées de couleurs
│   ├── test/widget_test.dart       # 24 tests
│   └── pubspec.yaml
├── tools/                          # chaîne de fabrication des données (Python)
├── LICENSE
└── README.md
```

Quelques points d'entrée :

| Fichier | Rôle |
| --- | --- |
| `lib/main.dart` | Amorçage : charge les réglages et le lexique, monte `HskHelpApp`. |
| `lib/services/learning_engine.dart` | Moteur adaptatif (10 algorithmes) et sélection du prochain élément. |
| `lib/services/grammar_repository.dart` | Chargement des règles et exercices, tirage des sessions, noms de catégories traduits. |
| `lib/models/pinyin.dart` | Segmentation et normalisation du pinyin (comparaison des tons). |
| `lib/data/syllables.dart` | Table des **412 syllabes** valides du mandarin (générée). |
| `lib/l10n.dart` | Tous les textes de l'interface, dans les trois langues. |
| `lib/theme.dart` | Les 8 palettes et le calcul des couleurs dérivées. |

---

## Données embarquées

Trois fichiers JSON et deux polices sont déclarés dans `hskhelp/pubspec.yaml` et empaquetés dans l'APK. Rien n'est téléchargé au démarrage.

### `vocab.json` — une entrée

```json
{
  "id": 1,
  "level": 1,
  "hanzi": "爱",
  "pinyin": "ài",
  "posEn": "verb",
  "posFr": "verbe",
  "posZh": "动词",
  "en": "to love",
  "fr": "aimer",
  "zh": "爱",
  "plain": "ai",
  "answers": ["ai"]
}
```

`plain` / `answers` sont les formes **sans ton** ; les formes toniques sont recalculées au chargement par `Pinyin`.

### `grammar_rules.json` — structure

```text
levels[]  →  sections[]  →  categories[]  →  rules[]
rules[]   →  blocks[]  (paragraphe, titre, structure, exemples)
```

Une règle :

```json
{
  "id": "ASG004ZK",
  "title": "Indiquer un nombre en excès",
  "titleI18n": { "en": "…", "zh": "…" },
  "level": 3,
  "levelCode": "B1",
  "section": "Structures grammaticales",
  "category": "Nombres",
  "hasExamples": true,
  "blocks": [
    { "t": "p", "fr": "…", "i18n": { "en": "…", "zh": "…" } },
    { "t": "structure", "fr": "…", "i18n": { "en": "…", "zh": "…" } },
    {
      "t": "examples",
      "items": [
        {
          "zh": "他 的 妈妈 已经 五十 多 岁 了。",
          "py": "Tā de māmā yǐjīng wǔshí duō suì le.",
          "fr": "Sa maman a déjà plus de cinquante ans.",
          "frI18n": { "en": "…", "zh": "…" },
          "hl": [[13, 14]]
        }
      ]
    }
  ]
}
```

`hl` repère, par **plages d'indices de caractères**, les mots mis en rouge (le mot clé de la règle). Le corpus compte **7 423 blocs** dont **6 502 exemples**.

### `grammar_exercises.json` — format compact

Les exercices sont pré-calculés et rangés en **tableaux d'entiers** pour rester légers :

| Clé | Contenu |
| --- | --- |
| `v` | Version du format. |
| `s` | Phrases par règle (jetons indexés, pinyin, traduction). |
| `t` | Table des jetons (mots) par règle. |
| `m` | Exercices « mot manquant » : `[indexPhrase, indexMotCaché, typeIndice, …]`. |
| `w` | Exercices « phrase mélangée » : l'ordre mélangé des jetons. |

Rien n'est généré à l'exécution : les 102 600 exercices sont déjà dans le fichier, ce qui garde l'application fluide.

---

## Chaîne de fabrication des données

Le dossier `tools/` regroupe les scripts Python qui **fabriquent** les données une fois pour toutes. Ils ne font pas partie de l'application et ne sont pas nécessaires pour la compiler.

| Script | Entrée → sortie |
| --- | --- |
| `parse_hsk.py` | Les PDF « New HSK Vocabulary » → `assets/_raw_vocab.json` (lecture par coordonnées, insensible aux retours à la ligne). |
| `build_i18n.py` | `_raw_vocab.json` → `assets/vocab.json` (anglais, français, natures grammaticales). |
| `build_i18n_langs.py` / `build_i18n_local.py` | Ajout des traductions supplémentaires (dont le **chinois**) — méthode **en ligne** (repli en cascade) ou **hors ligne** (modèles neuronaux Argos, cache disque reprenable). |
| `fix_i18n_garbage.py` | Corrige les rares résidus produits par les modèles (points de code parasites, écriture étrangère glissée). |
| `extract_grammar_rules.py` | Le corpus de grammaire hors ligne → `assets/grammar_rules.json`. |
| `build_i18n_grammar.py` | Traduit titres, explications, structures et exemples en **anglais** puis **chinois**. |
| `build_grammar_exercises.py` | Fabrique les 102 600 exercices → `assets/grammar_exercises.json`. |
| `build_syllables.py` | Génère la table des 412 syllabes → `lib/data/syllables.dart`. |
| `build_fonts.py` | Sous-ensembles les polices → `assets/fonts/HskHelp-{Regular,Bold}.ttf`. |
| `build_icons.py` | Génère l'icône Android (cachet rouge 汉). |

Exemples d'exécution :

```bash
python3 tools/parse_hsk.py
python3 tools/build_i18n.py
python3 tools/extract_grammar_rules.py
python3 tools/build_i18n_grammar.py            # en puis zh
python3 tools/build_grammar_exercises.py
python3 tools/build_syllables.py
python3 tools/build_fonts.py
```

> Les modèles de traduction hors ligne se téléchargent une seule fois puis tournent en local ; ils ne sont requis que pour **régénérer** les traductions. `tools/` contient aussi quelques scripts historiques (extracteur de leçons, variante en ligne) conservés pour référence.

Les PDF sources de vocabulaire ne sont pas distribués dans ce dépôt. Pour relancer `parse_hsk.py`, procurez-vous séparément les documents sources nécessaires.

### Polices

L'application embarque un **sous-ensemble de Noto Sans SC** (famille `HskHelp`, deux graisses), limité aux caractères réellement utilisés : latin accentué, pinyin tonique (`ā á ǎ à …`), ponctuation et **sinogrammes** présents dans les données. `build_fonts.py` collecte tous les caractères non ASCII des sources Dart **et** des JSON, produit les deux graisses, puis **échoue** si un caractère collecté n'est couvert par aucune police — ce qui évite les carrés vides à l'écran. La police source est téléchargée une seule fois si elle est absente.

---

## Comparaison du pinyin

Le lexique et la saisie passent par **exactement le même traitement** : la lecture est segmentée en syllabes (programme dynamique sur la table des 412 syllabes), puis ramenée à une forme canonique où le **ton est noté par un chiffre après chaque syllabe**. C'est cette forme qui est comparée.

Deux modes coexistent, réglables par « Exiger les tons » (actif par défaut). Pour 爱 `ài` :

| Saisie | Tons exigés | Tons ignorés |
| --- | :---: | :---: |
| `ài` | ✅ | ✅ |
| `ai4` | ✅ | ✅ |
| `ai` | ❌ ton manquant | ✅ |
| `ai1` | ❌ mauvais ton | ✅ |
| `a i 4` | ✅ | ✅ |

Tolérances, dans les deux modes : le `ü` noté `u`, `v` ou `u:` ; les espaces, apostrophes et tirets ; la casse ; et les **lectures multiples** du lexique (`谁` : `shéi` **ou** `shuí`). Trois points particuliers sont traités :

- **Ton neutre** — une syllabe sans accent (`de`, `ma`, `le`) vaut le ton 5 : `de` pour 的 est juste même en mode strict, mais `dē` est refusé.
- **变调 (tons de liaison)** — seules les syllabes 不 et 一 acceptent aussi leur ton de citation (`bú`/`bù`, `yí`/`yī`) ; les autres mots ne sont pas touchés.
- **儿化** — le « r » final fusionne avec la dernière syllabe : `hǎowánr` donne à la fois `hao3wanr2` et `hao3wan2er5`.

---

## Hors ligne et vie privée

- **Aucune dépendance réseau à l'exécution.** Le lexique, la grammaire, les exercices, les traductions et les polices sont embarqués dans l'APK. Les services de traduction n'interviennent que lors de la **fabrication** des données.
- **Aucun compte, aucun serveur, aucune télémétrie.** La progression, les statistiques et les préférences sont stockées sur l'appareil (`shared_preferences`) et ne sont pas synchronisées.
- La progression peut être **réinitialisée** depuis l'écran d'accueil.

---

## Contribuer

Les contributions sont les bienvenues.

1. Ouvrez une *issue* pour décrire le changement ou le problème.
2. Créez une branche dédiée et faites une modification ciblée.
3. Vérifiez le formatage, l'analyse et les tests :
   ```bash
   cd hskhelp
   flutter analyze
   flutter test
   ```
4. Ouvrez une *pull request* en décrivant le comportement modifié et les vérifications effectuées.

Merci de garder le code et les données **cohérents dans les trois langues** (fr · en · zh) et de ne pas introduire de dépendance réseau à l'exécution.

---

## Licence

Ce projet est distribué sous **licence MIT** — voir le fichier [LICENSE](LICENSE).

---

## Remerciements

- **[Noto Sans SC](https://fonts.google.com/noto/specimen/Noto+Sans+SC)** (Google Fonts), sous *SIL Open Font License 1.1*, utilisée pour le sous-ensemble de polices embarqué.
- **Material Icons** (Flutter), sous *Apache License 2.0*.
- Les listes de vocabulaire **HSK** et le contenu de grammaire sont issus de ressources pédagogiques publiques ; vérifiez les droits et attributions applicables avant toute redistribution commerciale.
