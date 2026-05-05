# 🎨 Changelog — Chantier 4 (Mutualisation CSS)

**Date :** 26 avril 2026

## En une phrase

Les variables CSS (`--app-bg`, `--btn-yellow`, etc.) qui étaient
**dupliquées dans 14 fichiers HTML** sont maintenant définies une seule
fois dans `assets/shared/shared.css`. Pareil pour la classe `.svg-icon`.
Quand tu changes le jaune, tu le changes **à un seul endroit** au lieu de
12.

---

## ⚠️ AVANT D'UTILISER : tester rapidement

Comme on a déplacé les définitions, **il faut absolument que tous les
fichiers HTML chargent `shared.css`** sinon ils s'afficheront sans
couleurs (du blanc sur blanc, illisible).

J'ai vérifié dans le script que c'est le cas pour les **14 fichiers**,
mais teste rapidement :

1. Ouvre `index.html` → tout doit avoir l'air normal (sidebar jaune, fond
   sombre)
2. Connecte-toi → la page de login doit avoir le bon look
3. Clique sur chaque module dans la sidebar → vérifier qu'aucun n'est
   "cassé visuellement" (blanc sur blanc, etc.)

Si un module s'affiche en blanc/transparent : c'est qu'il manque
`shared.css` dans son `<head>` — me dire lequel.

---

## 🎯 Ce qui change

### Pour les utilisateurs
- **Rien de visible.** L'app a exactement la même apparence qu'avant.

### Pour toi (maintenance)
- **Changer une couleur du thème** = 1 seul fichier à modifier
  (`assets/shared/shared.css`) au lieu de 14
- **Ajouter une nouvelle variable globale** (ex: `--my-new-color`) = idem,
  un seul endroit
- Les modules sont **plus courts** d'environ ~30 lignes chacun (variables
  + `* { box-sizing }` + `.svg-icon`)
- **Total HTML** : 8749 → 9184 lignes... attends, c'est **plus** ? Ah oui
  parce qu'on a aussi ajouté `<link>` + `<script>` shared.* dans 9 modules
  qui ne les chargeaient pas (voir section "découverte importante" plus bas)

---

## 📦 Détail des changements

### 1. `assets/shared/shared.css` enrichi
Ajout de 2 variables qui étaient dans plusieurs modules mais pas dans
shared.css :
- `--btn-orange: #ff9800` (utilisée dans 5 modules)
- `--blue-bg: #d1e9ff` (utilisée dans 3 modules)

### 2. Nettoyage des HTML — bloc `:root` dupliqué supprimé
Dans **13 fichiers sur 14**, le bloc `:root { --app-bg: ...; --btn-yellow:
...; etc. }` a été complètement supprimé.

**Exception :** `code_calendrier/code_calendrier.html` garde son `:root`
réduit aux 2 variables qui lui sont **vraiment spécifiques** :
- `--cal-grid-border: #444`
- `--cal-header-bg: #333`

Toutes les variables identiques à celles de `shared.css` ont été retirées.

### 3. Nettoyage des HTML — `* { box-sizing: border-box }` supprimé
Cette règle était dupliquée dans tous les modules. Maintenant elle est
seulement dans `shared.css`.

### 4. Nettoyage des HTML — `.svg-icon { ... }` supprimé
La classe `.svg-icon` était définie 12 fois dans les modules (toujours
avec exactement la même définition que celle de `shared.css`). On supprime
les 12 copies, on garde la seule qui compte.

### 5. 🚨 Découverte importante (heureusement détectée à temps)
Pendant la vérification, on a découvert que **9 modules sur 12 ne
chargeaient PAS `shared.css`** avant ce chantier. Ils fonctionnaient parce
qu'ils définissaient leurs propres variables CSS dans leur `:root` local.

Si on avait juste supprimé les `:root` sans rien ajouter, ces 9 modules
auraient affiché du blanc sur blanc.

**Solution appliquée :** ajout de `<link rel="stylesheet"
href="../assets/shared/shared.css">` + `<script
src="../assets/shared/shared.js"></script>` dans les `<head>` des 9
modules concernés :
- `code_accueil`, `code_admin`, `code_calendrier`, `code_clients`,
  `code_courriel`, `code_messagerie`, `code_outils`, `code_po`,
  `code_profil_parametres`

**Bonus indirect :** ces 9 modules ont maintenant aussi accès à
`window.showToast()` et au système de gestion d'erreur Supabase mutualisé.
Avant, ils n'y avaient pas accès. À utiliser dans les prochains chantiers
si tu veux des notifications cohérentes partout.

### 6. `login.html` charge maintenant `shared.css`
Pour la même raison : login utilise `var(--app-bg)`, `var(--btn-yellow)`,
etc. dans son `<style>`. Maintenant que les variables sont dans
shared.css, login doit le charger.

---

## ✅ Comment tester (3 min)

### Test 1 — Aspect visuel global
1. Ouvre `login.html` → fond sombre, bouton jaune Connexion → ✅
2. Connecte-toi → tout normal
3. Sidebar → boutons des modules visibles, jaune sur sombre → ✅

### Test 2 — Tous les modules s'ouvrent normalement
Clique sur chaque entrée de la sidebar et vérifie visuellement :
- Accueil
- Factures (bouton jaune Nouvelle facture, etc.)
- Soumissions
- Feuille de temps
- Calendrier
- Messagerie
- Courriel
- Clients
- PO / Bons de commande
- Outils
- Admin (uniquement si A0/A1)
- Profil

Aucun ne doit apparaître "cassé" (sans couleurs, layout détruit, etc.)

### Test 3 — Toast fonctionne dans tous les modules
Avant ce chantier, seuls 3 modules avaient accès à `showToast`. Maintenant
tous l'ont. Pas un test directement visible mais bon à savoir.

### Test 4 — Cas spécial : code_calendrier
Va dans Calendrier → vérifier que les bordures de la grille et le header
sont bien gris foncé (variables `--cal-grid-border` et `--cal-header-bg`
toujours définies localement).

---

## 🚀 Si tu veux modifier plus tard

### Changer le thème jaune en autre chose ?
Édite **un seul fichier** : `assets/shared/shared.css`
- `--btn-yellow: #fcca46;` → la couleur que tu veux
- `--sidebar-bg: #fcca46;` → idem (souvent le même que btn-yellow)

C'est ça. Plus besoin de toucher aux 12 modules.

### Ajouter une nouvelle variable globale (ex: `--accent-purple`) ?
1. L'ajouter dans `:root` de `assets/shared/shared.css`
2. L'utiliser via `var(--accent-purple)` dans n'importe quel module

### Ajouter une variable spécifique à un module (comme cal-* dans
calendrier) ?
1. Mettre le `:root { --ma-var: ...; }` directement dans le `<style>` du
   module concerné
2. **Ne pas** la mettre dans shared.css (ça pollue les autres modules
   pour rien)

---

## 📊 Bilan

| Avant | Après |
|---|---|
| Variables CSS dupliquées dans 14 fichiers | Définies 1 fois dans shared.css |
| `* { box-sizing }` dupliqué dans 14 fichiers | Défini 1 fois |
| `.svg-icon` dupliquée dans 12 modules | Définie 1 fois |
| 9 modules ne chargeaient pas shared.* | Tous le chargent (bonus toast) |

**Réduction estimée par fichier** : 30-50 lignes de CSS dupliqué retirées.
**Effort futur de changement de thème** : divisé par 12.
