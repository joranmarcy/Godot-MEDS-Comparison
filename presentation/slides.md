---
theme: seriph
colorSchema: dark
background: '#0b1622'
title: MEDS — Une architecture modulaire pour Godot
info: |
  Présentation de MEDS (Modular · Editable · Debuggable · Scalable),
  une librairie Godot pour découpler les systèmes avec des Resources.
author: Joran
lang: fr
class: text-center
transition: slide-left
mdc: true
highlighter: shiki
lineNumbers: false
drawings:
  persist: false
---

# MEDS

## Une architecture modulaire pour Godot

<div class="mt-8 text-2xl tracking-widest opacity-90">
  <span class="m">M</span>odular ·
  <span class="e">E</span>ditable ·
  <span class="d">D</span>ebuggable ·
  <span class="s">S</span>calable
</div>

<div class="abs-b mb-10 text-sm opacity-60">
  Joran — Numix · ~25 min · Théorie courte puis démo dans Godot
</div>

<!--
Bonjour à toutes et à tous, et bienvenue dans cette présentation !

Aujourd'hui, je vais vous présenter MEDS, une librairie pour Godot, vous expliquer à quoi elle sert, pourquoi elle a été créée et surtout ce qu'elle peut apporter au développement de jeux et d'applications.

La présentation va durer environ 25 minutes. On va commencer par une petite partie théorique, assez courte, puis on passera rapidement à une démonstration directement dans Godot.

Mais avant ça, je vais me présenter rapidement.
-->

---
layout: two-cols
layoutClass: gap-12
---

# Qui suis-je ?

<v-clicks>

- 👨‍💻 **Joran** — ingénieur logiciel depuis **12+ ans**
- ✈️ Débuts dans les **logiciels critiques** (contrôle aérien)
- 🥽 Puis les **technologies immersives** : VR, AR, HoloLens
- 🏢 **Numix** depuis 6 ans ½ : formations VR, apps mobiles, e-learning
- 🎮 Moteur principal au quotidien : **Unity**

</v-clicks>

::right::

<div class="h-full flex flex-col justify-center items-center gap-6" v-click>
  <div class="text-7xl">🎮 ➜ 🤖</div>
  <div class="text-xl opacity-80 text-center">
    Unity au travail…<br/>
    <span class="godot font-bold">Godot</span> par passion
  </div>
</div>

<!--
Je m'appelle Joran et ça fait un peu plus de 12 ans que je suis ingénieur en développement logiciel.

[click] J'ai commencé ma carrière dans le domaine des logiciels critiques, notamment dans le contrôle aérien.

[click] Puis je me suis assez rapidement orienté vers les technologies immersives, quand j'ai découvert ce qu'il était possible de faire avec les casques de réalité virtuelle et de réalité augmentée, comme le Microsoft HoloLens.

[click] Aujourd'hui, ça fait six ans et demi que je travaille chez Numix, une entreprise spécialisée dans la création de formations en réalité virtuelle, d'applications mobiles et de contenus e-learning.

[click] Chez Numix, on utilise principalement Unity pour développer nos applications. C'est donc le moteur de jeu que je connais le mieux et sur lequel j'ai le plus d'expérience.

[click] Mais depuis quelque temps, je m'intéresse beaucoup à Godot.
-->

---

# Pourquoi Godot ?

<p class="opacity-70">L'open source, une piste sérieuse pour la 3D temps réel</p>

<div class="grid grid-cols-3 gap-6 mt-10">
  <div v-click class="card">
    <div class="text-4xl mb-3">🔍</div>
    <h3>Sécurité & transparence</h3>
    <p>Accéder au code source du moteur et comprendre exactement ce qu'il fait.</p>
  </div>
  <div v-click class="card">
    <div class="text-4xl mb-3">🧠</div>
    <h3>Curiosité technique</h3>
    <p>Comprendre ses outils, sans être limité à ce qu'on veut bien nous montrer.</p>
  </div>
  <div v-click class="card">
    <div class="text-4xl mb-3">🗽</div>
    <h3>Indépendance</h3>
    <p>Ne pas dépendre des décisions commerciales d'un éditeur.<br/><em class="opacity-60">cf. la tarification Unity…</em></p>
  </div>
</div>

<div v-click class="mt-10 text-center text-lg">
  ➜ Retrouver dans Godot les bonnes pratiques appréciées dans Unity… <strong>et c'est comme ça qu'est née MEDS.</strong>
</div>

<!--
Pourquoi ? Parce que je pense que l'open source représente une piste particulièrement intéressante pour le développement d'applications 3D temps réel.

[click] D'abord, pour des questions de sécurité et de transparence. Pouvoir accéder au code source d'un moteur, comprendre exactement ce qu'il fait, c'est un vrai avantage.

[click] Ensuite, par curiosité technique. Personnellement, j'aime bien comprendre comment fonctionnent les outils que j'utilise, et ne pas être limité à ce qu'on veut bien me montrer.

[click] Et enfin, pour une question d'indépendance. J'aime bien l'idée de ne pas dépendre des décisions commerciales d'une entreprise qui pourraient, du jour au lendemain, mettre en difficulté un projet, voire une société entière. On a d'ailleurs eu un très bon exemple de ce risque avec les changements de tarification annoncés par Unity.

[click] C'est donc assez naturellement que j'ai commencé à explorer Godot, avec l'envie d'y retrouver certaines pratiques de développement que j'appréciais particulièrement dans Unity. Et c'est comme ça qu'est née la librairie MEDS.
-->

---
layout: center
class: text-center
---

# MEDS, qu'est-ce que c'est ?

<div class="text-xl mt-6 opacity-80">
Une philosophie popularisée par <strong>Ryan Hipple</strong> pour Unity<br/>
<span class="text-base opacity-70">« Game Architecture with Scriptable Objects » — Unite Austin 2017</span>
</div>

<div v-click class="mt-10 text-lg">
  Découverte chez Numix… et coup de cœur 💙
</div>

<div v-click class="mt-4 text-lg">
  On y retrouve l'<strong>injection de dépendances</strong> et le <strong>découplage</strong>,<br/>
  mais adaptés au développement de jeux vidéo.
</div>

<!--
Alors, MEDS, qu'est-ce que c'est exactement ?

MEDS, c'est un acronyme qui reprend une philosophie de développement popularisée par Ryan Hipple pour Unity.

[click] Cette philosophie, je l'ai découverte en arrivant chez Numix. Et franchement, j'ai trouvé ça génial. Parce qu'elle résolvait pas mal de problèmes qui m'embêtaient dans le développement d'applications Unity.

[click] En venant du monde des logiciels critiques, j'avais notamment pris goût à certains principes d'architecture, comme l'injection de dépendances et le découplage des systèmes. Et avec cette approche, je retrouvais justement une partie de ces principes, mais d'une manière très adaptée au développement de jeux vidéo.

MEDS repose sur quatre grands principes.
-->

---

# Quatre principes

<div class="grid grid-cols-4 gap-5 mt-12">
  <div v-click class="letter-card m-border">
    <div class="big-letter m">M</div>
    <h3>Modular</h3>
    <p>Des systèmes indépendants, assemblables comme des LEGO</p>
  </div>
  <div v-click class="letter-card e-border">
    <div class="big-letter e">E</div>
    <h3>Editable</h3>
    <p>Les données au centre, modifiables sans toucher au code</p>
  </div>
  <div v-click class="letter-card d-border">
    <div class="big-letter d">D</div>
    <h3>Debuggable</h3>
    <p>Comprendre vite, tester chaque système isolément</p>
  </div>
  <div v-click class="letter-card s-border">
    <div class="big-letter s">S</div>
    <h3>Scalable</h3>
    <p>Garder la maîtrise quand le projet grossit</p>
  </div>
</div>

<!--
MEDS repose sur quatre grands principes.

[click] Modular. [click] Editable. [click] Debuggable. [click] Et Scalable.

On va les voir un par un.
-->

---
layout: two-cols
layoutClass: gap-10
---

# <span class="m">M</span> — Modular

<v-clicks>

- 🧱 Des systèmes **aussi indépendants que possible**
- ♻️ Réutiliser un système dans un autre niveau… ou un autre projet
- ▶️ Lancer **une scène seule**, directement depuis l'éditeur
- 🎯 Un script = **une responsabilité**

</v-clicks>

::right::

<div class="h-full flex flex-col justify-center">
  <div v-click class="tip">
    <strong>💡 Pour les devs Unity</strong><br/>
    Une scène Godot ≈ un <em>prefab</em> qu'on pourrait exécuter directement.
  </div>
  <div v-click class="mt-6 text-center text-lg">
    Assembler · Remplacer · Tester · Réutiliser
  </div>
</div>

<!--
Le premier, c'est Modular, pour modulaire.

[click] L'idée, c'est que les différents systèmes de notre jeu doivent être aussi indépendants que possible. On veut pouvoir les assembler un peu comme des LEGO.

[click] Par exemple, si je développe un système d'ennemis, je veux pouvoir le réutiliser dans un autre niveau, voire dans un autre projet, sans devoir embarquer la moitié de mon jeu avec lui.

[click] Je veux aussi pouvoir lancer une scène toute seule, directement depuis l'éditeur, sans avoir besoin de lancer toute l'application.

[click] Et ça passe aussi par des scripts qui ont des responsabilités bien définies. Un script fait une chose, et il la fait bien.

[click] Pour les développeurs Unity, vous pouvez imaginer les scènes Godot un peu comme des prefabs qu'on pourrait exécuter directement.

[click] L'objectif, c'est d'avoir des systèmes qu'on peut facilement assembler, remplacer, tester et réutiliser.
-->

---

# <span class="e">E</span> — Editable

<div class="grid grid-cols-2 gap-10 mt-6">
<div>

<v-clicks>

- 📊 Placer les **données au centre** du développement
- 🚫 Pas de valeurs codées en dur
- 🛠️ Modifiables **dans l'éditeur**, sans toucher au code
- ⚡ … et **en temps réel**, pendant que le jeu tourne
- 🎨 Idéal pour expérimenter et faire du **game design**

</v-clicks>

</div>
<div v-click>

```gdscript
# Avant : valeur codée en dur
var speed: float = 320.0

# Après : donnée partagée et éditable
@export var move_speed: FloatVariable

func _physics_process(_delta):
    velocity = input * move_speed.value
```

</div>
</div>

<!--
Le deuxième principe, c'est Editable, pour éditable.

[click] L'idée, ici, c'est de placer les données au centre du développement.

[click] Plutôt que de coder en dur toutes les valeurs de notre jeu, on va chercher à les rendre facilement modifiables depuis l'extérieur du code. Par exemple, la vitesse d'un personnage, ses points de vie ou encore la couleur d'un élément d'interface.

[click] On veut pouvoir modifier ces données directement dans l'éditeur, sans toucher au code.

[click] Mais on veut aussi pouvoir le faire pendant que le jeu tourne, en temps réel.

[click] Et ça, c'est particulièrement pratique pour ajuster le comportement d'un jeu, expérimenter ou faire du game design.
-->

---

# <span class="d">D</span> — Debuggable

<div class="grid grid-cols-2 gap-10 mt-8 items-center">
<div>

<v-clicks>

- 🔎 Comprendre **rapidement** ce qui se passe
- 🧪 Tester chaque système **indépendamment**
- 🐛 Bug sur les ennemis ? On lance **uniquement** les ennemis

</v-clicks>

</div>
<div v-click class="flex flex-col gap-3">
  <div class="bad">❌ Lancer le jeu → 3 menus → charger un niveau → attendre les bonnes conditions…</div>
  <div class="good">✅ Lancer la scène de l'ennemi → reproduire → corriger</div>
</div>
</div>

<div v-click class="mt-12 text-center text-xl">
  Plus les systèmes sont <strong>isolés</strong>, plus il est facile de comprendre ce qui ne fonctionne pas.
</div>

<!--
Le troisième principe, c'est Debuggable, pour facile à déboguer.

[click] L'objectif, c'est de pouvoir comprendre rapidement ce qui se passe dans notre application,

[click] et surtout de pouvoir tester nos systèmes indépendamment les uns des autres.

[click] Si j'ai un problème avec mes ennemis, je veux pouvoir lancer uniquement mon système d'ennemis, reproduire le problème et le corriger.

[click] Je ne veux pas devoir lancer tout le jeu, passer trois menus, charger un niveau et attendre que les bonnes conditions soient réunies pour pouvoir observer mon bug.

[click] Plus les systèmes sont isolés, plus il devient facile de comprendre ce qui ne fonctionne pas.
-->

---

# <span class="s">S</span> — Scalable

<div class="text-lg opacity-70 mb-8">Mon apport personnel à cette philosophie</div>

<div class="grid grid-cols-3 gap-6">
  <div v-click class="card">
    <div class="text-3xl mb-2">✅</div>
    <h3>Ça marche</h3>
    <p>Approche déjà utilisée avec succès chez Numix sous Unity.</p>
  </div>
  <div v-click class="card">
    <div class="text-3xl mb-2">⚠️</div>
    <h3>Mais…</h3>
    <p>Gros projets = beaucoup de variables et d'événements.<br/>On gagne en modularité, on perd en <strong>lisibilité globale</strong>.</p>
  </div>
  <div v-click class="card">
    <div class="text-3xl mb-2">🧰</div>
    <h3>MEDS</h3>
    <p>Les mêmes principes dans Godot + des <strong>outils</strong> pour maîtriser la complexité.</p>
  </div>
</div>

<div v-click class="mt-10 text-center text-lg">
  ➜ Plus qu'une simple bibliothèque de variables et d'événements.
</div>

<!--
Et enfin, le dernier principe, c'est Scalable, pour la capacité à passer à l'échelle. C'est mon apport personnel à cette philosophie.

[click] Comme je vous le disais, chez Numix, on utilisait déjà cette approche avec Unity. Et elle fonctionnait très bien.

[click] Mais au fil du temps, on a aussi rencontré certaines limites, notamment quand les projets devenaient plus gros et que le nombre de systèmes, de variables et d'événements augmentait. On gagnait beaucoup en modularité, mais on pouvait aussi perdre en lisibilité globale.

[click] J'ai donc voulu reprendre les mêmes principes dans Godot, tout en apportant des outils supplémentaires pour mieux gérer la complexité des projets de grande taille.

[click] Et c'est notamment là que MEDS va se différencier d'une simple bibliothèque de variables et d'événements.
-->

---
layout: center
class: text-center
---

# 🪙 Coin Rush

<div class="text-xl opacity-80 mt-4">Assez de théorie !</div>

<div class="mt-10 grid grid-cols-2 gap-10 text-left">
  <div v-click class="card">
    <h3>📁 classic-game/</h3>
    <p>Architecture classique : singleton <code>GameState</code> en AutoLoad</p>
  </div>
  <div v-click class="card">
    <h3>📁 meds-game/</h3>
    <p>Le même jeu, mêmes fonctionnalités… avec MEDS</p>
  </div>
</div>

<div v-click class="mt-10 opacity-70">
  🎮 <em>Démo : on contrôle un personnage, on ramasse des pièces, on évite les ennemis.</em>
</div>

<!--
Bon, assez de théorie !

Pour vous montrer concrètement comment tout ça fonctionne, j'ai créé un petit jeu qui s'appelle Coin Rush.

[Lancer le jeu et faire une courte démonstration.]

Le principe est assez simple : on contrôle un personnage, on récupère des pièces et on essaie d'éviter les ennemis. Rien de révolutionnaire, mais c'est largement suffisant pour illustrer les problèmes d'architecture dont on va parler.

[click] Et surtout, j'ai développé ce jeu deux fois. Une première fois avec une architecture classique, sans MEDS.

[click] Et une deuxième fois avec MEDS.

L'intérêt, c'est qu'on va pouvoir comparer exactement le même jeu, avec les mêmes fonctionnalités, mais deux manières différentes d'organiser le code et de faire communiquer les systèmes.

Les deux projets sont disponibles sur GitHub si vous voulez y jeter un œil après la présentation.
-->

---
layout: section
---

# L'architecture classique

## Les singletons

---

# Le singleton `GameState`

<div class="grid grid-cols-2 gap-8">
<div>

<v-clicks>

- 📌 Un script qui **centralise** la logique du jeu
- ♾️ Chargé via l'**AutoLoad** de Godot
- 🌍 Disponible partout, pendant toute l'application

</v-clicks>

</div>
<div>

```gdscript {all|1-8|10-12|all}
# game_state.gd (AutoLoad)
signal health_changed(new_health: int)
signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal level_changed(new_level: int)
signal coin_collected
signal player_hit
signal game_over

func start_game() -> void: ...
func collect_coin() -> void: ...
func damage_player(amount: int = 1) -> void: ...
```

</div>
</div>

<!--
On va commencer par regarder la version classique.

Pour cette version, j'ai utilisé une approche assez courante dans Godot : le pattern singleton.

[click] Concrètement, j'ai un script que j'ai appelé GameState, qui centralise une bonne partie de la logique du jeu.

[click] Ce script est chargé grâce au système d'AutoLoad de Godot.

[click] L'avantage, c'est qu'il reste disponible pendant toute la durée de l'application et qu'on peut y accéder depuis n'importe quel autre script.
-->

---

# Architecture classique

<div class="mermaid-fit">

```mermaid
flowchart LR
  Player["🧍 Player"] -- "damage_player()" --> GS
  Coin["🪙 Coin"] -- "collect_coin()" --> GS
  Enemy["👾 Enemy"] -- "level, is_running" --> GS
  Enemy -. "get_first_node_in_group('player')" .-> Player
  GS["🧠 GameState<br/>(AutoLoad)"]
  GS -- "health_changed<br/>score_changed" --> HUD["📊 HUD"]
  GS -- "player_hit" --> Shake["📷 ScreenShake"]
  GS -- "coin_collected<br/>game_over" --> SFX["🔊 SoundEffects"]
  GS -- "game_over" --> GO["💀 GameOverScreen"]
  classDef core fill:#7c2d12,stroke:#f97316,color:#fff
  class GS core
```

</div>

<!--
Je vous ai préparé un petit schéma pour illustrer le fonctionnement.

Prenons un exemple. Quand notre joueur se fait toucher par un ennemi, son script appelle directement la fonction player_damaged() du GameState.

Le GameState va alors mettre à jour l'état du jeu, puis émettre des signaux Godot pour prévenir les autres systèmes qui doivent réagir.

Par exemple, l'interface peut mettre à jour les points de vie, et un autre système peut déclencher un effet de tremblement de caméra.
-->

---

# Plutôt pratique, non ?

<div class="grid grid-cols-2 gap-10 mt-8">
<div>

### ✅ Avantages

<v-clicks>

- Un **point d'entrée central** pour la logique
- **Persistant** entre les scènes
- Accessible depuis **tous les scripts**
- **Facile à comprendre**
- Découpable : `AudioManager`, `HUDManager`, `ScreenEffectManager`…

</v-clicks>

</div>
<div v-click>

### 🏁 Verdict

<div class="good mt-4">
  Petit jeu, <strong>game jam</strong> : ça fonctionne très bien.
</div>

<div class="bad mt-4" v-click>
  Projet qui grossit, <strong>plusieurs développeurs</strong> : ça se complique…
</div>

</div>
</div>

<!--
Et en soi, cette approche est plutôt pratique.

[click] On a un point d'entrée central pour gérer la logique du jeu, [click] le GameState reste disponible entre les scènes, [click] et tous les scripts peuvent facilement communiquer avec lui. [click] Il reste persistant tout au long du runtime. Facile à comprendre.

[click] On pourrait même aller plus loin et découper ce gros singleton en plusieurs petits singletons : un AudioManager, un HUDManager, un ScreenEffectManager, etc. Ça permettrait d'éviter d'avoir un seul script gigantesque.

[click] Et pour un petit jeu, notamment un projet de game jam, c'est une solution qui fonctionne très bien.

[click] Mais les choses commencent à se compliquer quand le projet grossit, surtout quand plusieurs développeurs travaillent dessus.
-->

---

# Le problème des dépendances

<div class="grid grid-cols-2 gap-8">
<div class="code-sm">

```gdscript {all|7-10|13,15-16|all}
# classic-game/scripts/enemy.gd
extends Area2D

@export var base_speed: float = 110.0
@export var speed_per_level: float = 15.0

var _player: Node2D

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not GameState.is_running or _player == null:
		return
	var speed := base_speed \
		+ (GameState.level - 1) * speed_per_level
	global_position = global_position.move_toward(
		_player.global_position, speed * delta)
```

</div>
<div>

<v-clicks>

- 👾 Je veux tester **l'ennemi seul** → ça ne marche pas
- 🔗 Il cherche le **nœud du joueur** dans la scène
- 🧍 Donc il me faut un joueur… qui dépend lui-même du `GameState`
- 💥 Un collègue casse `GameState` → **ma scène ne marche plus**
- 🤷 … alors que je n'ai **rien changé** à mon système

</v-clicks>

</div>
</div>

<!--
Imaginons que je travaille sur le comportement des ennemis. Je crée une scène avec uniquement mon ennemi, pour pouvoir tester son déplacement. Sauf que ça ne fonctionne pas.

[click] Pourquoi ? Parce que mon ennemi cherche directement le nœud du joueur dans l'arborescence de la scène pour récupérer sa position. Donc pour tester mon ennemi, je suis obligé d'avoir aussi un joueur dans ma scène.

[click] Et potentiellement, ce joueur a lui-même besoin d'autres systèmes. On commence alors à accumuler les dépendances.

Autre exemple : je veux simplement tester le comportement de mon joueur. Mais mon script dépend du GameState. Donc, même si je veux uniquement tester le déplacement du joueur, je reste dépendant de ce singleton.

[click] Maintenant, imaginons qu'un collègue modifie le GameState et introduise un bug. Je lance ma scène pour tester mon joueur, et elle ne fonctionne plus.

[click] Pourtant, je n'ai absolument rien changé à mon système de joueur. Mon bug vient d'une dépendance extérieure. Et c'est précisément ce qu'on aimerait éviter.
-->

---
layout: center
class: text-center
---

<div class="text-3xl leading-relaxed">
  Le problème, ce n'est pas le <span class="opacity-60">singleton</span> en lui-même.<br/>
  <span v-click>C'est le <strong class="text-orange-400">couplage</strong> qu'il crée entre les systèmes.</span>
</div>

<div v-click class="mt-12 text-lg opacity-80">
  Le joueur accède à <code>GameState</code>… donc à <em>tout</em> le jeu (audio, HUD, effets…).<br/>
  Le principe d'encapsulation de la programmation objet est rompu.
</div>

<div v-click class="mt-10 text-xl">
  Plus de couplage = plus dur à <strong>tester</strong>, <strong>modifier</strong>, <strong>réutiliser</strong>.
</div>

<!--
Ça casse le contrat de la programmation objet. Parce que le script player va récupérer un script qui lui donne accès à la totalité du jeu (audio manager, hud manager...).

[click] Le problème, ce n'est pas le singleton en lui-même. C'est le couplage qu'il peut créer entre les différents systèmes de notre application.

[click] [click] Plus ce couplage est important, plus il devient difficile de tester, modifier et réutiliser nos systèmes indépendamment.

Alors, comment est-ce qu'on peut faire autrement ?
-->

---
layout: section
---

# L'approche MEDS

## Découpler les systèmes avec les Resources

---

# Les Resources Godot

<div class="grid grid-cols-2 gap-10 mt-6 items-center">
<div>

<v-clicks>

- 📦 Un objet qui **contient des données**
- 💾 Enregistré dans un **fichier** (`.tres`)
- 🤝 **Partagé** entre plusieurs éléments du jeu
- 🧩 On peut créer **nos propres types**

</v-clicks>

<div v-click class="tip mt-8">
  <strong>💡 Pour les devs Unity</strong><br/>
  Une Resource ≈ un <code>ScriptableObject</code>
</div>

</div>
<div v-click>

```ini
# game/variables/player-position.tres
[gd_resource type="Resource"
  script_class="Vector2Variable" format=3]

[ext_resource type="Script"
  path="res://addons/godot_meds_core/
        scripts/variables/vector2-variable.gd"
  id="1_script"]

[resource]
script = ExtResource("1_script")
initial_value = Vector2(623.63, 360)
```

</div>
</div>

<div v-click class="mt-6 text-center text-lg">
  ➜ MEDS utilise les Resources comme <strong>objets intermédiaires</strong> pour faire communiquer les systèmes.
</div>

<!--
L'idée avec MEDS, ça va être de limiter les dépendances directes entre les différents systèmes du jeu.

Et pour ça, on va s'appuyer sur une fonctionnalité native de Godot : les Resources.

[click] Une Resource, c'est un objet qui peut contenir des données, [click] être enregistré dans un fichier [click] et être partagé entre plusieurs éléments de notre jeu.

[click] Et ce qui est intéressant, c'est qu'on peut créer nos propres types de Resources.

[click] Pour ceux qui viennent d'Unity, c'est assez proche du concept de ScriptableObject.

[click] [click] Avec MEDS, on va utiliser ces Resources comme des objets intermédiaires pour faire communiquer nos systèmes.
-->

---

# Les variables partagées

<div class="mermaid-fit mermaid-small">

```mermaid
flowchart LR
  Player["🧍 Player"] -- "écrit" --> PP[("📍 PlayerPosition<br/>Vector2Variable")]
  PP -- "lit" --> Enemy["👾 Enemy"]
  Editor["🛠️ Éditeur / test"] -. "écrit aussi ?" .-> PP
  classDef var fill:#1e3a5f,stroke:#478cbf,color:#fff
  class PP var
```

</div>

<v-clicks>

- L'ennemi n'a plus besoin de connaître **le joueur** — seulement **une position**
- Remplacer le joueur, ou piloter la position depuis l'éditeur : l'ennemi fonctionne **pareil**

</v-clicks>

<!--
Reprenons notre exemple de l'ennemi qui doit connaître la position du joueur. Dans notre architecture classique, l'ennemi allait chercher directement le joueur dans la scène. Avec MEDS, on va faire autrement.

On va créer une Resource partagée qu'on va appeler PlayerPosition. Cette Resource va simplement contenir un Vector2, c'est-à-dire une position en X et Y.

Ensuite, on va donner cette même Resource à deux systèmes. D'un côté, le joueur va mettre à jour sa position dans PlayerPosition. De l'autre, l'ennemi va simplement lire cette valeur pour savoir où se déplacer. Et c'est tout.

[click] L'ennemi n'a plus besoin de connaître l'existence du joueur. Il a uniquement besoin d'une position. Et ça change pas mal de choses.

[click] Par exemple, si demain je décide de remplacer le joueur par un autre objet, ou même de contrôler directement la position depuis l'éditeur, mon ennemi continuera à fonctionner exactement de la même façon. Parce qu'il ne dépend plus d'un objet particulier, mais simplement d'une donnée qu'on lui fournit.
-->

---

# L'ennemi, avant / après

````md magic-move {lines: true}
```gdscript
# classic-game/scripts/enemy.gd
@export var base_speed: float = 110.0
@export var speed_per_level: float = 15.0

var _player: Node2D

func _ready() -> void:
	_player = get_tree().get_first_node_in_group("player")

func _physics_process(delta: float) -> void:
	if not GameState.is_running or _player == null:
		return
	var speed := base_speed + (GameState.level - 1) * speed_per_level
	global_position = global_position.move_toward(_player.global_position, speed * delta)
```

```gdscript
# meds-game/game/scripts/enemy.gd
@export var target_position: Vector2Variable
@export var base_speed: FloatVariable
@export var level: IntVariable
@export var game_over: BoolVariable
@export var speed_per_level: float = 15.0

func _physics_process(delta: float) -> void:
	if game_over.value:
		return
	var speed := base_speed.value + (level.value - 1) * speed_per_level
	global_position = global_position.move_toward(target_position.value, speed * delta)
```
````

<div v-click class="mt-6 text-center text-lg">
  Plus de <code>GameState</code>, plus de recherche de nœud : <strong>uniquement des dépendances explicites</strong>.
</div>

<!--
Voilà ce que ça donne concrètement dans le code.

[click] Avant : l'ennemi cherche le joueur dans l'arbre de scène et lit le niveau et l'état de la partie dans le GameState.

Après : l'ennemi déclare simplement ses dépendances avec des @export. Une position cible, une vitesse, un niveau, un booléen de fin de partie. C'est tout.

[click] Plus de GameState, plus de recherche de nœud : uniquement des dépendances explicites, injectées depuis l'inspecteur.
-->

---

# Des variables pour tous les types

<div class="grid grid-cols-4 gap-4 mt-10">
  <div v-click class="type-chip">BoolVariable</div>
  <div v-click class="type-chip">IntVariable</div>
  <div v-click class="type-chip">FloatVariable</div>
  <div v-click class="type-chip">StringVariable</div>
  <div v-click class="type-chip">ColorVariable</div>
  <div v-click class="type-chip">Vector2Variable</div>
  <div v-click class="type-chip">Vector3Variable</div>
  <div v-click class="type-chip opacity-60">…</div>
</div>

<div v-click class="mt-14 text-center text-2xl">
  ➜ Dans MEDS, on appelle ça des <strong class="godot">variables MEDS</strong>.
</div>

<!--
C'est ce principe qu'on va appliquer à toutes sortes de données.

Des nombres flottants, des entiers, des chaînes de caractères, des booléens, des couleurs, des vecteurs... Bref, les types de données dont on a besoin pour construire notre application.

Et dans MEDS, on va appeler ça des variables MEDS.
-->

---
layout: two-cols
layoutClass: gap-8
---

# Les événements partagés

<v-clicks>

- 🪙 Pièce ramassée, 💥 joueur touché, 💀 fin de partie…
- Un script **déclenche** l'événement
- Un autre script l'**écoute**
- Les deux **ne se connaissent pas**

</v-clicks>

<div v-click class="mt-6">

```gdscript
# player.gd — "Je signale, c'est tout."
@export var player_hit: Event

func _on_hurtbox_area_entered(area):
	# ...
	player_hit.raise_event()
```

</div>

::right::

<div class="mt-16" v-click>

```gdscript
# screen_shake.gd — "Je tremble, c'est tout."
extends Camera2D

@export var event: Event
@export var strength: float = 12.0
@export var duration: float = 0.3

func _ready() -> void:
	event.event_raised.connect(_on_event_raised)

func _on_event_raised() -> void:
	_time_left = duration
```

</div>

<div v-click class="mt-6 tip">
  Qui a déclenché l'événement ? Le joueur, un test, un bouton dans l'éditeur…<br/>
  <strong>On s'en fout un peu !</strong> 😄
</div>

<!--
Mais évidemment, dans un jeu, on n'a pas uniquement besoin de partager des valeurs. On a aussi besoin de réagir à des événements.

[click] Par exemple, quand le joueur se fait toucher, quand une pièce est ramassée ou quand une partie se termine. Et pour ça, MEDS propose un autre type de Resource : les événements.

[click] Le fonctionnement est assez simple. Un script peut déclencher un événement. [click] Un autre script peut écouter cet événement. [click] Et les deux n'ont pas besoin de se connaître.

[click] Reprenons notre exemple du joueur qui se fait toucher. Avant, notre joueur appelait directement player_damaged() dans le GameState. Avec MEDS, on va créer une Resource de type événement, qu'on va appeler PlayerDamaged. On va fournir cet événement au script du joueur. Et quand le joueur se fait toucher, il va simplement déclencher l'événement.

Il ne sait pas qui écoute cet événement. Il ne sait pas non plus ce qui va se passer ensuite. Mais c'est très bien ! Ce n'est pas sa responsabilité. Lui, son travail, c'est de détecter qu'il a subi des dégâts et de le signaler. C'est tout.

[click] De l'autre côté, on va fournir ce même événement aux différents systèmes qui doivent réagir. Par exemple, le système de tremblement de caméra. Lui, il va simplement écouter l'événement PlayerDamaged, et quand celui-ci est déclenché, il va faire trembler la caméra.

[click] Il ne sait pas qui a déclenché l'événement. Ça pourrait être le joueur, un script de test ou même un bouton dans l'éditeur. Mais là encore, on s'en fout un peu ! Son travail, c'est de faire trembler la caméra quand il reçoit cet événement. Et rien d'autre.

On obtient donc deux systèmes qui peuvent communiquer sans dépendre directement l'un de l'autre.
-->

---
layout: center
class: text-center
---

# Et si on applique ça partout…

<div v-click class="mt-10">
  <div class="text-9xl">🥣</div>
  <div class="text-5xl font-bold mt-4">Chocapic !</div>
</div>

<div v-click class="mt-10 text-2xl opacity-70">
  … bon, non, pas vraiment.
</div>

<!--
Maintenant, si on reprend l'ensemble de notre jeu et qu'on applique ce principe un peu partout, on obtient ça...

[click] [Afficher une image de Chocapic.]

[click] Bon, non, pas vraiment. On obtient plutôt ça !
-->

---

# Architecture MEDS

<div class="mermaid-fit">

```mermaid
flowchart LR
  Player["🧍 Player"] -- "écrit" --> PP[("PlayerPosition")]
  PP --> Enemy["👾 Enemy"]
  Player -- "déclenche" --> PH>"PlayerHit"]
  PH --> Shake["📷 ScreenShake"]
  PH --> SFX["🔊 PlaySoundOnEvent"]
  PH --> DMG["DamageOnEvent"]
  DMG -- "écrit" --> HP[("PlayerHealth")]
  HP --> HUD["📊 HUD (bindings)"]
  HP --> GOZ["GameOverOnZeroHealth"]
  GOZ --> GO[("GameOver")]
  Coin["🪙 Coin"] -- "déclenche" --> CC>"CoinCollected"]
  CC --> SK["ScoreKeeper"]
  SK --> SC[("Score")]
  SC --> HUD
  SC --> LFS["LevelFromScore"]
  LFS --> LV[("Level")]
  LV --> Enemy
  classDef var fill:#1e3a5f,stroke:#478cbf,color:#fff
  classDef evt fill:#4c1d95,stroke:#a78bfa,color:#fff
  class PP,HP,GO,SC,LV var
  class PH,CC evt
```

</div>

<div class="absolute bottom-6 right-10 text-sm flex gap-6">
  <span><span class="legend var-legend"></span> Variable</span>
  <span><span class="legend evt-legend"></span> Événement</span>
</div>

<!--
On voit que les systèmes ne communiquent plus directement entre eux. Ils passent par des variables et des événements partagés.

Chaque système reçoit uniquement les dépendances dont il a besoin pour fonctionner. Et ces dépendances sont configurées directement depuis l'inspecteur de Godot.

C'est une forme d'injection de dépendances, mais avec une approche très visuelle, particulièrement adaptée au fonctionnement d'un moteur de jeu.

Et maintenant, on va voir ce que ça donne concrètement dans l'éditeur.
-->

---
layout: center
class: text-center
---

# 🎮 Démonstration dans Godot

<div class="mt-8 text-xl opacity-80">Coin Rush — version MEDS</div>

<div class="mt-12 grid grid-cols-3 gap-6 text-left">
  <div class="card"><h3>1️⃣ Ennemi isolé</h3><p>Lancer une scène seule, piloter <code>PlayerPosition</code></p></div>
  <div class="card"><h3>2️⃣ HUD & bindings</h3><p>Connecter l'UI aux variables sans script</p></div>
  <div class="card"><h3>3️⃣ Cycle de vie</h3><p><code>reset_on</code> et sauvegarde</p></div>
</div>

<!--
[Ouvrir le projet Coin Rush avec MEDS.]

On va commencer par regarder comment MEDS fonctionne directement dans Godot.
-->

---

# Démo 1 — Le déplacement d'un ennemi

<div class="grid grid-cols-2 gap-10 mt-8 items-center">
<div>

<v-clicks>

- ▶️ Lancer la scène de l'ennemi **toute seule**
- 🚫 Pas de jeu complet, **pas de joueur**
- ✏️ Modifier `PlayerPosition` depuis l'éditeur
- ⚡ L'ennemi réagit **immédiatement**
- 🧑‍💻 … sans toucher à son code

</v-clicks>

</div>
<div v-click class="flex flex-col gap-4 text-xl">
  <div class="letter-row"><span class="m font-bold">M</span> Système indépendant</div>
  <div class="letter-row"><span class="e font-bold">E</span> Données éditables</div>
  <div class="letter-row"><span class="d font-bold">D</span> Test isolé</div>
</div>
</div>

<!--
Je vais ouvrir la scène de mon ennemi.

[click] Et là, vous pouvez voir que je peux la lancer toute seule.

[click] Je n'ai pas besoin de charger le jeu entier. Je n'ai même pas besoin d'avoir un joueur dans ma scène. Mon ennemi utilise simplement une variable MEDS qui contient la position qu'il doit suivre.

[click] Et cette variable, je peux la modifier directement depuis l'éditeur.

[Modifier la variable PlayerPosition et montrer le déplacement de l'ennemi.]

[click] Vous voyez que mon ennemi réagit immédiatement aux changements.

[click] Et le plus intéressant, c'est que je n'ai pas eu besoin de modifier son code. Je lui fournis juste une donnée différente.

[click] C'est exactement ce qu'on recherchait avec les principes Modular, Editable et Debuggable. Mon système est indépendant, ses données sont éditables, et je peux tester son comportement de manière isolée.
-->

---

# Démo 2 — Le HUD et les bindings

<div class="grid grid-cols-2 gap-10 mt-6">
<div>

<v-clicks>

- 📊 Afficher score, points de vie, temps restant…
- 😩 Habituellement : un **petit script de synchro** par élément
- 🔗 Avec MEDS : **connecter directement** un composant UI à une variable
- 🔄 La valeur change → l'UI se met à jour **automatiquement**
- ↔️ Certains composants **modifient** aussi la variable

</v-clicks>

</div>
<div v-click>

| Composant | Binding MEDS |
| --- | --- |
| `Label` | VariableDrivenLabel |
| `Slider` | VariableDrivenSlider |
| `ProgressBar` | VariableDrivenProgressBar |
| `CheckBox` | BoolDrivenCheckbox |
| `ColorPicker` | ColorDrivenColorPicker |

</div>
</div>

<!--
Maintenant, on va regarder un autre exemple avec l'interface utilisateur.

[click] Dans un jeu, on a souvent besoin d'afficher des données : le score, les points de vie, le temps restant, etc.

[click] Traditionnellement, on va écrire des scripts qui récupèrent ces valeurs et mettent à jour les composants de l'interface.

[click] Avec MEDS, on peut simplifier ça grâce à un système de bindings. L'idée, c'est de connecter directement un composant d'interface à une variable MEDS. Par exemple, je peux associer un label à une variable qui contient le score.

[click] Et quand la valeur change, le texte affiché se met automatiquement à jour. Je n'ai pas besoin d'écrire un script spécifique pour faire cette liaison.

[Montrer le binding d'un label avec une variable MEDS.]

[click] Et évidemment, on peut aussi modifier certaines valeurs depuis l'interface, selon le composant utilisé.

[click] Et ça ne fonctionne pas uniquement avec les labels. MEDS propose aussi des bindings pour les sliders, les barres de progression, les cases à cocher ou encore les sélecteurs de couleur.

Cela permet de construire des interfaces qui réagissent directement aux données, sans multiplier les petits scripts de synchronisation.
-->

---

# Démo 3 — Le cycle de vie des variables

<div class="grid grid-cols-2 gap-10 mt-6">
<div>

<v-clicks>

- 🧠 Une Resource **garde sa valeur** en mémoire pendant l'exécution
- ❤️ Points de vie → **réinitialisés** à chaque partie
- 🔊 Volume audio → **conservé**
- ⚙️ `reset_on` : *On Scene Load* ou *On Application Start*
- 💾 `save_to_device` : **persister** la valeur (paramètres utilisateur…)

</v-clicks>

</div>
<div v-click>

```gdscript
# base-variable.gd (extrait)
@export var save_to_device: bool = false

@export_enum("On Scene Load", "On Application Start")
var reset_on: String = RESET_ON_SCENE_LOAD
```

<div class="tip mt-6">
  Le comportement des données est <strong>déclaré une fois</strong>,<br/>
  pas réécrit dans chaque système.
</div>

</div>
</div>

<!--
Un autre sujet important quand on utilise des données partagées, c'est leur cycle de vie.

[click] Parce qu'une Resource peut conserver une valeur en mémoire pendant que l'application fonctionne. Et parfois, ce n'est pas ce qu'on veut.

[click] Par exemple, les points de vie du joueur doivent peut-être être réinitialisés quand on relance une partie.

[click] Mais les paramètres audio, eux, doivent probablement conserver leur valeur.

[click] MEDS propose donc un système de réinitialisation configurable avec reset_on. On peut définir à quel moment une variable doit retrouver sa valeur initiale. Pour les réinitialisations au démarrage de l'application, MEDS utilise également un mécanisme de cache à l'exécution afin de gérer correctement les valeurs de référence.

[Montrer les options de réinitialisation et, si possible, un exemple de changement de scène ou de redémarrage.]

[click] Et on peut également sauvegarder les valeurs de certaines variables, lorsqu'on souhaite les conserver. C'est pratique, par exemple, pour les paramètres utilisateur ou certaines données persistantes.

[click] L'objectif, c'est que le développeur puisse définir clairement le comportement des données sans avoir à réécrire toute cette logique dans chaque système.
-->

---

# Les outils de débogage

<div class="text-lg opacity-70">Qui utilise quoi ? Que se passe-t-il quand ça ne marche pas ?</div>

<div class="grid grid-cols-3 gap-6 mt-10">
  <div v-click class="card">
    <div class="text-4xl mb-3">🔗</div>
    <h3>Suivi des références</h3>
    <p>Pour chaque variable ou événement : quels scripts et scènes l'utilisent.</p>
    <p class="opacity-60 text-sm mt-2">Fini les recherches manuelles dans tout le projet.</p>
  </div>
  <div v-click class="card">
    <div class="text-4xl mb-3">📈</div>
    <h3>Débogueur de variables</h3>
    <p>Observer <strong>et modifier</strong> les valeurs en temps réel.</p>
    <p class="opacity-60 text-sm mt-2">Ex. : passer le joueur à 1 PV instantanément.</p>
  </div>
  <div v-click class="card">
    <div class="text-4xl mb-3">⚡</div>
    <h3>Débogueur d'événements</h3>
    <p>Surveiller les événements… et les <strong>déclencher</strong> depuis l'éditeur.</p>
    <p class="opacity-60 text-sm mt-2">Ex. : <code>PlayerHit</code> sans se faire toucher.</p>
  </div>
</div>

<div v-click class="mt-10 text-center text-xl">
  Tester une animation, un effet, un son ou l'UI <strong>sans reproduire les conditions du jeu</strong>.
</div>

<!--
On a vu comment MEDS permettait de rendre les systèmes plus indépendants. Mais quand on travaille avec beaucoup de variables et d'événements partagés, une autre difficulté apparaît. Comment savoir qui utilise quoi ? Et surtout, comment comprendre ce qui se passe quand quelque chose ne fonctionne pas ?

C'est pour répondre à ces questions que MEDS propose plusieurs outils de débogage intégrés à l'éditeur.

[click] Le premier, c'est le suivi des références. Pour chaque variable ou événement MEDS, on peut retrouver les éléments du projet qui l'utilisent. Par exemple, si je sélectionne ma variable PlayerPosition, je peux identifier les scripts ou les scènes qui y font référence. C'est particulièrement utile quand un projet commence à grossir.

[Montrer le suivi des références d'une variable ou d'un événement.]

[click] Ensuite, on a un débogueur de variables en temps réel. Il permet d'observer la valeur des variables MEDS pendant que l'application tourne. Mais surtout, il permet aussi de les modifier directement. Imaginons que je veuille tester ce qui se passe quand le joueur n'a plus qu'un seul point de vie. Plutôt que de lancer le jeu et de me faire toucher plusieurs fois, je peux simplement modifier la valeur dans le débogueur.

[Modifier une valeur pendant l'exécution.]

[click] On retrouve le même principe pour les événements. MEDS permet de surveiller les événements déclenchés pendant l'exécution. Mais aussi de les déclencher manuellement depuis l'éditeur. Par exemple, je peux déclencher PlayerDamaged sans avoir besoin de faire toucher le joueur par un ennemi. Et tous les systèmes qui écoutent cet événement vont réagir normalement.

[Déclencher manuellement un événement depuis l'éditeur.]

[click] On peut donc tester facilement une animation, un effet visuel, un son ou une réaction de l'interface, sans avoir besoin de reproduire toutes les conditions du jeu. Et ça, pour le développement et le débogage, c'est un vrai gain de temps.
-->

---

# Passer à l'échelle : le graphe de dépendances

<div class="grid grid-cols-2 gap-10 mt-6">
<div>

### 🤔 Le revers du découplage

<v-clicks>

- Moins de dépendances directes = 👍 modularité
- Mais les relations deviennent **moins visibles**
- 1 événement émis, 5 systèmes qui écoutent… **où est-ce écrit ?**
- Des centaines de variables et d'événements → 😵

</v-clicks>

</div>
<div>

### 🕸️ Le graphe de dépendances

<v-clicks>

- **Visualiser** qui lit / écrit quelles variables
- Qui **déclenche** et qui **réagit** à quels événements
- Comprendre comment une modification **se propage**
- Explorer une base de code **inconnue**, ou oubliée depuis des mois

</v-clicks>

</div>
</div>

<!--
Maintenant, il reste un problème important. Avec MEDS, on a supprimé beaucoup de dépendances directes entre nos systèmes. C'est très bien pour la modularité.

[click] [click] Mais en contrepartie, les relations entre les systèmes deviennent parfois moins évidentes à comprendre.

[click] Parce que si un système émet un événement et que cinq autres systèmes l'écoutent, cette relation n'apparaît pas directement dans le code.

[click] Sur un petit projet, ce n'est pas très grave. Mais sur un gros projet, avec des centaines de variables et d'événements, ça peut vite devenir compliqué.

Et c'est justement pour répondre à ce problème que j'ai ajouté le principe Scalable à MEDS. L'un des outils les plus importants pour ça, c'est le graphe de dépendances.

[Ouvrir le graphe de dépendances de MEDS.]

[click] L'idée, c'est de pouvoir visualiser les relations entre les différents éléments du projet. On peut voir quels systèmes utilisent quelles variables, [click] quels systèmes déclenchent des événements et lesquels y réagissent. Cela permet de retrouver une vue d'ensemble de l'architecture, même si les systèmes sont découplés.

[click] On peut ainsi comprendre plus rapidement comment une modification peut se propager dans le projet.

[click] Et surtout, ça devient beaucoup plus simple d'explorer une base de code qu'on ne connaît pas. C'est particulièrement intéressant quand on travaille à plusieurs sur une même application, ou quand on doit reprendre un projet après plusieurs mois sans y avoir touché.
-->

---

# MEDS à l'ère de l'IA 🤖

<div class="grid grid-cols-2 gap-10 mt-6">
<div>

<v-clicks>

- 🧩 Le défi de l'IA : **le contexte**
- 🕸️ Système couplé → l'IA doit comprendre **toute l'architecture**
- 🎯 Système modulaire → **périmètre restreint** et maîtrisé
- ✅ Système testable seul → **vérification facile**
- 🔍 Références, graphe, débogueurs → **reprendre le contrôle**

</v-clicks>

</div>
<div v-click>

<div class="prompt">
  <div class="text-xs opacity-60 mb-2">💬 Prompt</div>
  « Voilà le système d'ennemis. Il reçoit une <strong>position cible</strong>, une <strong>vitesse</strong> et quelques <strong>événements</strong>.<br/><br/>
  Modifie son comportement, mais <strong>conserve ces interfaces</strong>. »
</div>

<div v-click class="mt-6 opacity-70 text-sm">
  MEDS ne garantit pas que l'IA produira du bon code…<br/>
  mais des composants indépendants, des interfaces explicites et des tests isolés s'y prêtent particulièrement bien.
</div>

</div>
</div>

<!--
Et pour terminer, j'aimerais aborder un sujet qui me semble de plus en plus important : le développement assisté par intelligence artificielle.

Aujourd'hui, on utilise de plus en plus d'outils capables de générer du code, de modifier des scripts ou même d'implémenter des fonctionnalités entières à partir d'une simple description. Et je pense que ce type d'outil rend les principes de modularité encore plus intéressants.

[click] Pourquoi ? Parce que l'un des problèmes avec le code généré par une IA, c'est la gestion du contexte. Pour modifier correctement un système, l'IA doit comprendre comment il fonctionne, mais aussi de quoi il dépend et quelles conséquences ses modifications peuvent avoir sur le reste de l'application.

[click] Plus les systèmes sont fortement couplés, plus cette tâche devient complexe. Imaginons qu'on demande à une IA de modifier le comportement d'un ennemi. Si cet ennemi dépend directement du joueur, du GameState, du HUD et de plusieurs autres systèmes, l'IA doit potentiellement comprendre une grande partie de l'architecture pour faire une modification relativement simple. Et plus elle doit manipuler de contexte, plus il devient difficile de maîtriser les effets de bord.

[click] Avec une architecture modulaire, on peut beaucoup mieux délimiter le travail.

[click] L'IA peut alors se concentrer sur un périmètre beaucoup plus restreint. Elle n'a pas forcément besoin de comprendre toute l'application. Et de notre côté, on peut plus facilement vérifier ce qu'elle a produit, puisque le système peut être testé indépendamment.

[click] Les outils de MEDS peuvent aussi nous aider à reprendre le contrôle sur ce code. Avec le suivi des références et le graphe de dépendances, on peut mieux comprendre les relations entre les systèmes. Avec les débogueurs, on peut observer les valeurs et déclencher des événements pour vérifier les comportements. Et avec l'architecture basée sur les Resources, on dispose de contrats relativement simples entre les différents éléments.

[click] On peut lui dire : « Voilà le système d'ennemis. Il reçoit une position cible, une vitesse de déplacement et quelques événements. Modifie son comportement, mais conserve ces interfaces. »

[click] Bien sûr, MEDS ne garantit pas qu'une IA produira du bon code. Mais je pense qu'une architecture qui favorise des composants indépendants, des interfaces explicites et des tests isolés est particulièrement adaptée à ce type de développement. Et à mesure que les outils d'IA prennent plus de place dans nos pratiques, je pense que ces qualités vont devenir encore plus importantes.
-->

---

# Conclusion

<v-clicks>

- 🙅 Les singletons ne sont **pas mauvais** — il n'y a pas *une* seule bonne façon de faire
- 🏁 Petit projet : l'architecture classique **fait très bien l'affaire**
- 🏗️ Gros projet, plusieurs devs, systèmes qui évoluent : **M · E · D** prennent tout leur sens
- 📈 Et **S** : les outils pour garder une bonne compréhension du projet quand il grossit

</v-clicks>

<div v-click class="mt-12 text-center text-2xl">
  Des systèmes <strong>indépendants</strong>, faciles à <strong>configurer</strong>, <strong>tester</strong> et <strong>réutiliser</strong>.
</div>

<!--
Pour conclure, l'objectif de MEDS n'est pas de dire que les singletons sont mauvais ou qu'il n'existe qu'une seule bonne façon de développer un jeu avec Godot.

[click] [click] Pour un petit projet, une architecture classique peut très bien faire l'affaire, et il n'y a aucune raison de complexifier les choses inutilement.

[click] En revanche, dès qu'on commence à travailler sur des projets plus importants, avec plusieurs développeurs et des systèmes qui doivent évoluer dans le temps, je pense que les principes de modularité, d'édition des données et de débogage prennent tout leur sens.

[click] [click] C'est ce que j'ai voulu retrouver avec MEDS : une façon de développer des applications Godot avec des systèmes aussi indépendants que possible, faciles à configurer, à tester et à réutiliser. Et surtout, avec les outils nécessaires pour garder une bonne compréhension du projet quand celui-ci commence à grossir.
-->

---
layout: center
class: text-center
---

# Merci ! 🙏

<div class="text-2xl mt-6 opacity-80">Des questions ?</div>

<div class="mt-12 text-lg">
  <carbon-logo-github class="inline-block mr-2" />
  <a href="https://github.com/joranmarcy/Godot-MEDS-Comparison" target="_blank">github.com/joranmarcy/Godot-MEDS-Comparison</a>
</div>

<div class="mt-4 opacity-60">
  Coin Rush classique · Coin Rush MEDS · Librairie MEDS
</div>

<!--
La librairie est disponible sur GitHub, tout comme les deux versions de Coin Rush.

Donc si ça vous intéresse, n'hésitez pas à aller regarder le code, tester la librairie ou même contribuer au projet.

Merci à toutes et à tous pour votre attention !

Et si vous avez des questions, ce sera avec plaisir.
-->
