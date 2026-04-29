# 🧹 Changelog — Chantier 3 (Nettoyage technique)

**Date :** 26 avril 2026

## En une phrase

L'app pèse maintenant **1.3 Mo au lieu de 5.8 Mo** (gain ~77%), les logos
ne sont plus dupliqués dans 3 dossiers, le service worker connaît les
nouveaux fichiers shared et le manifest PWA a une vraie icône maskable.

---

## ⚠️ AVANT D'UTILISER : vider le cache navigateur

Comme on a bumpé le service worker `v3 → v4`, les utilisateurs verront
automatiquement les nouvelles versions au prochain chargement. **Mais**
si tu testes en local et que tu as déjà ouvert l'app, fais :

- **Chrome / Edge** : F12 → Application → Service Workers → "Unregister"
  puis Ctrl+Shift+R
- **Sur mobile** : ferme et rouvre l'app PWA (ou désinstalle/réinstalle)

C'est temporaire, juste pour cette mise à jour.

---

## 🎯 Ce qui change

### Pour les utilisateurs
- **Rien de visible**. Pas de nouveau bouton, pas de nouveau menu.
- L'app **se charge plus vite**, surtout sur mobile et en data.
- Mode hors-ligne plus fiable (le SW connaît tous les bons fichiers).
- L'icône PWA s'affiche correctement sur Android (plus de cropping).

### Pour toi (maintenance)
- **Un seul endroit** pour mettre à jour les logos : `/assets/`.
  Plus besoin d'aller toucher 3 dossiers à chaque changement.
- Le projet est passé de 5.8 Mo à 1.3 Mo → upload Render plus rapide,
  et les utilisateurs téléchargent moins.

---

## 📦 Détail des changements

### 1. Service Worker (`sw.js`)
- Bump version : `fdussault-v3` → `fdussault-v4`
- Ajout au cache : `assets/shared/shared.css`, `shared.js`,
  `autosave.js`, `archive.js`, plus `logo_dussault.png` et
  `cmmtq_et_slogan.png` qui sont maintenant dans `/assets/`

### 2. Manifest (`manifest.json`)
- Ajout d'une **vraie icône maskable** (`assets/logo_app_maskable.png`)
  avec safe zone à 80% et fond `#1e1f26` qui matche le `theme_color`
- Les icônes 192/512 restent en `purpose: "any"` (plus honnête —
  avant, on prétendait que c'était maskable alors que ça ne l'était pas)

### 3. Dédoublonnage des logos
**16 fichiers supprimés** des dossiers `code_*` :

| Fichier | Endroits | Total libéré |
|---|---|---|
| `logo_dussault.png` | facture, soumissions, feuille_de_temps | ~1.1 Mo |
| `cmmtq_et_slogan.png` | facture, soumissions | ~260 Ko |
| `logo_facture.png` | code_facture | ~230 Ko |
| `logo_soumission.png` | code_soumissions | ~220 Ko |
| `logo_calendrier.png` | code_calendrier | ~1 Mo |
| `logo_feuille_de_temps.png` (×2) | code_feuille_de_temps | ~390 Ko |
| `logo_accueil.png` | code_accueil | ~140 Ko |
| Petits logos (client, outils, po, profil) | divers | ~50 Ko |
| `logo_soumission 2.png` (orphelin) | assets | 8 Ko |

**Références mises à jour dans 3 fichiers HTML** :
- `code_facture/code_facture.html` (lignes ~1098 et ~1109)
- `code_soumissions/code_soumissions.html` (ligne ~620)
- `code_feuille_de_temps/code_feuille_de_temps.html` (ligne ~649)

Le pattern : `src="logo_dussault.png"` → `src="../assets/logo_dussault.png"`.

### 4. Compression des images (`/assets/`)
Toutes les images du dossier `assets` ont été passées au compresseur
(redimensionnées à une taille raisonnable + PNG optimisé) :

| Fichier | Avant | Après | Gain |
|---|---|---|---|
| `logo_dussault.png` | 379 K | 76 K | -80% |
| `logo_soumission.png` | 216 K | 44 K | -80% |
| `cmmtq_et_slogan.png` | 130 K | 27 K | -79% |
| `logo_facture.png` | 229 K | 56 K | -76% |
| `logo_accueil.png` | 138 K | 33 K | -76% |
| `logo_feuille_de_temps.png` | 141 K | 36 K | -74% |
| `logo_app.png` | 187 K | 50 K | -73% |
| `logo+nom.png` | 168 K | 53 K | -68% |
| `logo_calendrier.png` | 110 K | 54 K | -51% |
| Autres petits logos | ~64 K | ~46 K | -28% |

**Total assets : 1.76 Mo → 475 Ko (-73%)**

### 5. Bonus : icône maskable générée
- Nouveau fichier `assets/logo_app_maskable.png` (35.7 Ko)
- 512×512 avec safe zone à 80% et fond `#1e1f26`
- Conforme à la spec PWA maskable

---

## ✅ Comment tester (5 min)

### Test 1 — L'app se charge normalement
1. Ouvre `index.html`
2. Connecte-toi
3. Navigue dans les modules — tout doit fonctionner comme avant

### Test 2 — Les logos s'affichent
1. Ouvre une **nouvelle facture**
2. Le logo F.Dussault et le bandeau CMMTQ doivent apparaître en haut
3. Idem pour **soumissions** et **feuille de temps**
4. Ouvre la console (F12) → onglet Network → recharge → aucune erreur 404 sur des `.png`

### Test 3 — Service worker à jour
1. F12 → Application → Service Workers
2. Tu devrais voir `fdussault-v4` (pas v3)
3. Onglet Cache Storage → `fdussault-v4` → vérifie que `archive.js`,
   `autosave.js`, `shared.css`, `shared.js` sont dedans

### Test 4 — Mode hors-ligne
1. F12 → Network → coche "Offline"
2. Recharge l'app → elle doit s'ouvrir
3. Navigue entre Factures, Soumissions, Calendrier — chaque module charge depuis le cache
4. Ouvre une nouvelle facture → le logo doit être là (cache aussi)

### Test 5 — Icône PWA maskable
1. Désinstalle l'app PWA si elle est installée
2. Réinstalle-la depuis le navigateur
3. Sur Android : long-press l'icône → elle ne devrait plus être croppée bizarrement

---

## 🚀 Si tu veux modifier plus tard

- **Changer un logo** : mets le nouveau dans `/assets/` avec le **même nom**.
  Pense à bumper la version du SW (`v4` → `v5`) pour forcer la MAJ chez les
  utilisateurs déjà installés.
- **Ajouter une image** : déposer dans `/assets/`, référencer avec
  `../assets/...` depuis les modules, et l'ajouter à `ASSETS_TO_CACHE` dans
  `sw.js` si tu veux qu'elle marche hors-ligne.
- **Régénérer l'icône maskable** : si tu changes `logo_app.png`, va sur
  [maskable.app](https://maskable.app) avec ton nouveau logo, télécharge le
  résultat et remplace `assets/logo_app_maskable.png`.
