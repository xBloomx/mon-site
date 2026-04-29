# 📝 Changelog — Phase 2 (Archivage / Soft delete)

**Date :** 26 avril 2026

## En une phrase

Tes utilisateurs ne peuvent plus rien supprimer pour de vrai. Tout passe maintenant par un système d'**archivage** : le document est caché des listes normales, va dans un onglet "Archives" séparé, est traçable dans les logs, et **seul l'admin (toi, A0)** peut le restaurer ou le supprimer définitivement après 1 an.

---

## ⚠️ AVANT D'UTILISER : exécuter le SQL

Va dans **Supabase Dashboard → SQL Editor** et exécute le fichier **`supabase-phase2-archivage.sql`** (à la racine du projet).

Ce script est idempotent (tu peux le relancer sans problème). Il fait 4 choses :
1. Ajoute les colonnes `is_archived`, `archived_at`, `archived_by`, `archived_by_name`, `archive_reason` aux 3 tables `factures`, `soumissions`, `feuilles_de_temps`
2. Crée un trigger qui logge automatiquement chaque archivage/restauration dans `logs_systeme`
3. Met à jour les policies RLS UPDATE pour bloquer la modif d'un document archivé (sauf restauration A0)
4. Crée 2 fonctions Postgres : `count_archives_expired()` et `delete_expired_archives()`

---

## 🎯 Ce qui change pour les utilisateurs

### Pour Jean (A3 — employé)
- Le bouton 🗑️ "Supprimer" sur ses brouillons fonctionne toujours, **mais maintenant ça archive** au lieu de supprimer pour de vrai
- Le modal de confirmation lui dit : *"Le document sera déplacé dans les Archives. Vous pourrez le restaurer pendant 1 an (admin uniquement)."*
- Il voit un nouvel onglet **"Archives"** dans Factures, Soumissions, Feuilles de temps → il y voit ses propres archives en lecture seule (pas le bouton restaurer, c'est admin only)
- Il **ne peut plus** archiver ses documents envoyés/approuvés (seuls les brouillons)

### Pour Tristan (A1 — patron)
- Peut archiver **n'importe quel document**, même envoyé ou approuvé
- Quand il essaie d'archiver un doc déjà engagé, modal **renforcé** avec ⚠️ : *"Cette opération concerne un document déjà traité ou envoyé"*
- Voit l'onglet Archives avec **toutes les archives** (pas que les siennes)
- Pas le droit de restaurer (réservé A0)

### Pour A2 (chef équipe / contremaître)
- Aucun changement : pas le droit d'archiver
- Voit quand même l'onglet Archives (en lecture)

### Pour Xavier (A0 — toi)
- Tout ce que A1 peut faire, plus :
  - **Bouton ↺ Restaurer** sur chaque carte d'archive → remet le document dans la liste normale
  - Nouveau panneau **"Nettoyer Archives"** dans le module Admin (à côté de Mode Maintenance) :
    - Affiche le nombre d'archives > 1 an en temps réel
    - Bouton "Nettoyer" qui supprime définitivement après confirmation
    - Action loggée dans le journal technique

### Pour tout le monde
- Ouvrir un document archivé → **lecture seule absolue** (boutons Sauver/Envoyer/Page/Effacer cachés, autosave désactivé)
- Sur la carte d'archive : badge gris "📦 Archivé" remplace le statut habituel

---

## 📦 Fichiers modifiés

### Nouveaux fichiers
- `supabase-phase2-archivage.sql` — le SQL à exécuter
- `assets/shared/archive.js` — module shared `window.ArchiveFD` (mutualise toute la logique d'archivage)

### Modifiés
- `code_facture/code_facture.html`
- `code_soumissions/code_soumissions.html`
- `code_feuille_de_temps/code_feuille_de_temps.html`
- `code_admin/code_admin.html`

Pattern strictement identique sur les 3 modules d'édition pour faciliter la maintenance.

---

## ✅ Comment tester (5 min, ordre conseillé)

### Test 1 — Soft delete par A3
1. Connecte-toi en **Jean** (A3)
2. Crée une facture brouillon → sauvegarde-la
3. Reviens au dashboard → clique le bouton X sur sa carte
4. Modal devrait afficher *"sera déplacé dans les Archives... restaurer pendant 1 an"*
5. Confirme → la facture disparaît de "Mes Factures"
6. Va dans l'onglet **Archives** → tu la vois avec badge "📦 Archivé"
7. Clique dessus → s'ouvre en lecture seule (aucun bouton d'édition)

### Test 2 — Tentative d'archive interdite (A3)
1. Toujours en Jean, crée une feuille de temps → envoie-la au bureau
2. Reviens au dashboard → le bouton X **ne devrait plus apparaître** sur cette carte
3. ✅ Bon comportement : A3 ne peut plus archiver une feuille envoyée

### Test 3 — Confirmation forte (A1)
1. Connecte-toi en **Tristan** (A1)
2. Va dans Factures → onglet "Boîte de réception"
3. Clique X sur une facture envoyée
4. Modal devrait afficher **⚠️ avec message renforcé** *"document déjà traité ou envoyé"*
5. Confirme → archivée

### Test 4 — Restauration (A0 only)
1. Connecte-toi en **Xavier** (A0)
2. Va dans Factures → onglet **Archives**
3. Tu vois un bouton vert ↺ sur chaque carte
4. Clique sur ↺ → confirme → la facture revient dans la liste normale

### Test 5 — Trigger de log
1. En Xavier, va dans Admin → Journal Technique
2. Tu devrais voir des entrées **"Archivage"** et **"Restauration"** ajoutées automatiquement avec ton nom

### Test 6 — Panneau Nettoyer Archives
1. En Xavier, va dans Admin
2. Nouvelle carte orange "Nettoyer Archives" à côté de Mode Maintenance
3. Affiche "✓ Aucune archive expirée" (normal, rien n'a > 1 an)
4. Le bouton "Nettoyer" est cliquable mais ne fait rien tant qu'il n'y a pas d'expirées (sécurisé côté SQL)

---

## 🔒 Sécurité — pourquoi c'est solide

- Les policies RLS Postgres bloquent au niveau DB la modification d'un document archivé (même si quelqu'un essaie via l'API directement, ça échoue)
- La restauration est doublement protégée : côté JS via `ArchiveFD.canRestore(role)` + côté SQL via `is_admin()` dans la fonction
- Les fonctions `count_archives_expired()` et `delete_expired_archives()` lèvent une exception si l'appelant n'est pas admin
- Le trigger d'audit ne dépend pas du code applicatif — il s'écrit directement à chaque UPDATE de `is_archived`

---

## 🚀 Si tu veux modifier le comportement plus tard

Tout passe par `assets/shared/archive.js`. Quelques exemples :

- **Étendre l'archivage à A2** : modifie `canArchive()` au début du fichier (le bloc `if (role === 'A2')` retourne refus)
- **Changer la durée de rétention** (1 an → 2 ans) : remplace `interval '1 year'` par `interval '2 years'` dans `supabase-phase2-archivage.sql` puis relance le script
- **Permettre la restauration à A1** : modifie `canRestore()` (ajoute `|| role === 'A1'`) ET assouplis la policy SQL des fonctions
- **Ajouter une raison obligatoire d'archivage** : modifie `confirmAndArchive()` pour ouvrir un prompt de saisie avant d'appeler `archive()`

C'est volontairement isolé dans un seul fichier shared pour éviter d'avoir à toucher les 3 modules à chaque ajustement.
