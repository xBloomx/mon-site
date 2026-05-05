# 📝 Changelog — Phase 1, partie 2 (autosave soumissions + feuilles de temps)

**Date :** 26 avril 2026

## Ce qui a été fait

Le module `assets/shared/autosave.js` est maintenant branché dans **les 3 modules d'édition** :
- ✅ `code_facture.html` (déjà fait dans la session précédente)
- ✅ `code_soumissions.html` (cette session)
- ✅ `code_feuille_de_temps.html` (cette session)

Pattern strictement identique aux 3 modules pour faciliter la maintenance future.

## Fichiers modifiés

### `code_soumissions/code_soumissions.html`

1. **Imports ajoutés** dans le `<head>` (après `supabase-config.js`) :
   - `assets/shared/shared.css`
   - `assets/shared/shared.js`
   - `assets/shared/autosave.js`

2. **Variable globale** : `let autosave = null;` à côté de `currentQuoteId`.

3. **3 helpers ajoutés** : `startAutosave()`, `stopAutosave()`, `clearAutosaveForCurrent()`
   - `module: 'soumission'`
   - `containerSelector: '#quote-container'`
   - `draftIdGetter: () => currentQuoteId`

4. **Branchements** :
   - `openNewQuote()` → `startAutosave()` à la fin
   - `openExistingQuote()` → `startAutosave()` uniquement si statut `brouillon` / `corrige` / `corrigé`
   - `showDashboard()` → `stopAutosave()` au tout début
   - `saveCurrentQuote()` → `clearAutosaveForCurrent()` après confirmation que l'upsert Supabase a réussi (juste après `currentQuoteId = quoteNum`)

### `code_feuille_de_temps/code_feuille_de_temps.html`

Même pattern, avec :
- `module: 'feuille_de_temps'`
- `containerSelector: '#zoom-wrapper'` ⚠️ (pas `#timesheet-container` — ce module utilise `#zoom-wrapper` comme conteneur des pages d'inputs)
- `draftIdGetter: () => currentSheetId`

Branchements aux mêmes endroits :
- `openNewTimesheet()` → `startAutosave()`
- `openExistingTimesheet()` → `startAutosave()` si statut modifiable
- `showDashboard()` → `stopAutosave()`
- `saveCurrentTimesheet()` → `clearAutosaveForCurrent()` après upsert

## Ce qui n'a PAS été touché

- ❌ Pas de génération auto de numéro pour soumissions ou feuilles de temps (l'utilisateur garde la main, comme prévu)
- ❌ Pas de modifs côté SQL Supabase (déjà fait en partie 1)
- ❌ Pas de modifs sur `code_facture.html` (déjà bon)
- ❌ Phase 2 archivage : pas commencée (à faire dans une prochaine session)

## ✅ Comment tester

1. Aller dans **Soumissions** → Nouvelle soumission → taper qq champs → fermer l'onglet sans sauver → revenir → un toast **"Brouillon restauré"** doit apparaître + tes valeurs doivent être de retour.
2. Idem pour **Feuilles de temps** → Nouvelle feuille → taper des heures → signer → fermer → revenir → restauration auto + signature préservée.
3. Sauver la soumission/feuille pour de bon → fermer → rouvrir : **pas** de toast (le brouillon a été nettoyé après upsert Supabase réussi).
4. Bonus : feuille de temps déjà envoyée (statut `envoye`) → ouvrir → l'autosave **ne doit pas** démarrer (pas de toast au retour).

## 🚀 Prochaine étape : Phase 2 (archivage)

Voir `NOTES.md` section "Phase 2" pour la todo détaillée.
