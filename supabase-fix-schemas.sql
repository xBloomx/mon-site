# ✍️ Changelog — Chantier 6 (Signature électronique améliorée)

**Date :** 26 avril 2026

## En une phrase

La signature électronique est maintenant **vraiment utilisable sur le
terrain** : trait lisse, bouton effacer, plein écran sur mobile,
vibration tactile, indicateur "Signé ✓" visible, et tout est mutualisé
dans `assets/shared/signature.js` (plus de code dupliqué entre factures
et soumissions).

---

## ⚠️ AVANT D'UTILISER : aucune action requise côté DB

Pas de SQL à exécuter. Tout est côté code.

**Mais comme on a bumpé le Service Worker v5 → v6**, les utilisateurs
devront recharger l'app une fois pour voir les changements (auto au
prochain chargement, ou Ctrl+Shift+R pour les impatients).

---

## 🎯 Ce qui change

### Pour les utilisateurs

**Quand on clique sur une zone signature :**
- Modal **plein écran** sur mobile (avant : petit canvas étroit)
- Trait beaucoup plus **lisse** (avant : trait cassant, pixelisé)
- Bouton **Effacer** dans le modal pour recommencer **sans fermer**
- **Vibration courte** au début du tracé (sur mobile, feedback tactile)
- Touche **Échap** pour annuler

**Une fois signé :**
- Petit badge vert **"✓ Signé"** apparaît sur la zone signature
- Visible directement dans la liste des pages, plus besoin d'ouvrir pour
  vérifier
- Toast de confirmation "Signature enregistrée"

**Si on reclique sur une zone déjà signée :**
- La signature précédente est **pré-chargée** dans le canvas
- On peut la modifier (rajouter un trait), pas besoin de tout
  recommencer
- Ou cliquer **Effacer** pour partir d'une page blanche
- **Annuler** garde la signature précédente intacte (avant : ça
  effaçait)

### Pour toi (maintenance)

- Tout est dans **un seul fichier** : `assets/shared/signature.js`
- Si tu veux changer la couleur du trait, l'épaisseur, le titre du
  modal, etc. : un seul endroit
- L'ancien code de signature dans `code_facture.html` et
  `code_soumissions.html` est **encore présent** (modal HTML #sig-modal
  + fonctions JS) mais **inactif** — neutralisé parce que `SignatureFD`
  intercepte les clics. À nettoyer plus tard si tu veux gagner ~50
  lignes par module, mais pas urgent.

---

## 📦 Détail des changements

### Nouveau fichier
- `assets/shared/signature.js` (~480 lignes)
  - Module auto-init au premier appel à `attach()`
  - Crée son propre modal global (singleton) et l'injecte dans `<body>`
  - Injecte ses propres styles via `<style>`
  - API : `attach(img)`, `attachAll(container)`, `watchContainer(container)`,
    `refreshIndicators(container)`, `openFor(img)`

### Modifiés

**`code_facture/code_facture.html` :**
- Ajout de `<script src="../assets/shared/signature.js"></script>` dans le `<head>`
- Activation au boot : `SignatureFD.watchContainer(containerInvoice)` +
  `attachAll(containerInvoice)` juste avant `initAuth()`
- Refresh des indicateurs après chargement d'une facture (ligne 761)

**`code_soumissions/code_soumissions.html` :**
- Idem facture, dans la fonction d'init et après chargement d'une soumission

**`sw.js` :**
- Bump v5 → v6
- Ajout de `signature.js` au cache offline

---

## 🛠 Détails techniques

### Trait lissé
La grosse différence visible :

```js
// AVANT (trait cassant) :
ctx.lineTo(pos.x, pos.y);

// APRÈS (trait lissé) :
const midX = (lastPoint.x + p.x) / 2;
const midY = (lastPoint.y + p.y) / 2;
ctx.quadraticCurveTo(lastPoint.x, lastPoint.y, midX, midY);
```

On dessine une **courbe quadratique** entre les points au lieu d'une
ligne droite. Le résultat ressemble vraiment à une signature manuscrite,
plus à un dessin enfantin.

### Canvas haute résolution
Le canvas utilise maintenant `devicePixelRatio` pour tenir compte des
écrans Retina/HiDPI. Sur un iPhone, ça veut dire qu'on capture en 2× ou
3× la résolution apparente → la signature reste nette même quand le PDF
est zoomé.

### Vibration tactile
```js
if (e.type === 'touchstart' && navigator.vibrate) {
    navigator.vibrate(10); // 10 ms
}
```
Très court (10 ms), juste assez pour donner un feedback de "ça commence
à dessiner". Marche sur Android, ignoré sur iOS (Apple n'expose pas
cette API).

### MutationObserver
L'observer écoute :
1. Les nouvelles `.display-sig` ajoutées dans le container (par
   `addPage()`, `duplicatePage()`, ou par chargement d'un doc) →
   réattache automatiquement.
2. Les changements d'attribut `src` (= signature chargée depuis
   Supabase) → met à jour l'indicateur "✓ Signé".

Donc tu n'as **pas besoin** d'appeler manuellement `attach()` à chaque
fois que tu crées une page. Tout est automatique.

---

## ✅ Comment tester (5 min)

### Test 1 — Trait lissé
1. Ouvre une nouvelle facture
2. Clique sur "Signature du plombier"
3. Signe avec ta souris ou ton doigt
4. Compare au trait d'avant : le trait doit être **fluide et continu**,
   pas en escalier

### Test 2 — Bouton Effacer
1. Dans le modal de signature, signe quelque chose
2. Clique **Effacer** → le canvas se vide
3. Re-signe correctement
4. Clique **Valider** → la bonne signature est enregistrée

### Test 3 — Annuler garde la signature précédente
1. Signe et valide une signature
2. Reclique dessus → modal s'ouvre **avec ta signature précédente**
3. Modifie-la (ajoute un trait)
4. Clique **Annuler** → la signature **originale** reste, pas la modifiée

### Test 4 — Indicateur "Signé ✓"
1. Signe une zone et valide
2. Ferme le modal
3. Sur la zone signature, en haut à droite, tu dois voir un petit
   badge **"✓ Signé"** vert
4. Sauvegarde la facture, reviens-y plus tard → l'indicateur doit
   réapparaître automatiquement

### Test 5 — Plein écran mobile
1. Ouvre une soumission sur ton téléphone
2. Clique sur une zone signature
3. Le canvas doit prendre **60% de la hauteur de l'écran** (au lieu d'un
   petit rectangle)
4. Les boutons (Effacer, Annuler, Valider) doivent être en colonne
5. Bonus : tu devrais sentir une **micro-vibration** quand tu commences
   à dessiner

### Test 6 — Échap pour annuler
1. Ouvre le modal de signature
2. Appuie sur la touche Échap → le modal se ferme

### Test 7 — Document archivé (lecture seule)
1. Connecte-toi en A0, va dans Archives
2. Ouvre une facture archivée avec signatures
3. Clique sur une zone signature → **rien ne doit se passer**
   (pointer-events: none est respecté par notre `attach()`)
4. Mais l'indicateur "✓ Signé" doit quand même être visible

---

## 🚀 Si tu veux modifier plus tard

### Changer la couleur du trait
Dans `assets/shared/signature.js`, fonction `resizeCanvas()` :
```js
_ctx.strokeStyle = '#000';  // ← change ici
```

### Changer l'épaisseur du trait
```js
_ctx.lineWidth = 2.5;  // ← change ici (pixels)
```

### Changer la durée de la vibration
```js
navigator.vibrate(10);  // ← millisecondes
```

### Désactiver la vibration complètement
Commenter le bloc `if (e.type === 'touchstart' && navigator.vibrate)`.

### Ajouter signature à un autre module
1. Charger `<script src="../assets/shared/signature.js"></script>` dans
   le `<head>`
2. Mettre des `<img class="display-sig">` dans le HTML (idéalement
   dans une `.sig-box` pour le badge "Signé")
3. Au boot du module : `SignatureFD.watchContainer(monContainer);
   SignatureFD.attachAll(monContainer);`

C'est tout. Le module se charge du reste.

---

## 🧹 Ménage à faire plus tard (optionnel)

Le code de l'**ancien système** est encore présent mais **inactif** dans
les 2 modules. Si tu veux gagner ~80 lignes par module et avoir un code
plus propre, tu peux supprimer (mais pas urgent — ça ne dérange rien) :

Dans `code_facture.html` et `code_soumissions.html` :
- Le bloc HTML `<div id="sig-modal">...</div>` (lignes ~361-370 facture, ~225-235 soumissions)
- Les CSS `#sig-modal { ... }` et `#modal-canvas { ... }` (~lignes 156-158 facture, ~94-96 soumissions)
- Les fonctions JS : `resizeCanvas`, `openModal` (la version sig
  uniquement), `clearModalCanvas`, `saveSignature`, `getPos`,
  `startDrawing`, `moveDrawing`, et les addEventListener associés
  (~lignes 1137-1145 facture, ~663-672 soumissions)
- Attention : `closeModal(id)` est utilisé pour d'autres modals
  (`returnModal`, `confirmModal`, `alertModal`) — **ne PAS le supprimer**.
  Juste retirer la branche `else { ...sig-modal... }` dedans.

Mais encore une fois : **tout fonctionne sans faire ce ménage**, c'est
juste du code mort qui ne dérange rien.
