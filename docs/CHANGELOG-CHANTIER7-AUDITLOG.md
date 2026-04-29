# 📜 Changelog — Chantier 7 (Audit Log complet)

**Date :** 26 avril 2026

## En une phrase

Le journal technique devient un **vrai journal d'audit** : toute action
sur les documents (création/modif/suppression), changement de rôle, et
connexion est tracée automatiquement par PostgreSQL. Toi (A0) **et
Tristan (A1)** y ont accès, avec filtres avancés et export CSV.

---

## ⚠️ AVANT D'UTILISER : exécuter le SQL

Va dans **Supabase Dashboard → SQL Editor** et exécute le fichier
**`supabase-phase3-auditlog.sql`** (à la racine du projet).

Script idempotent (relançable sans problème). Il fait :
1. Ajoute 5 colonnes à `logs_systeme` : `table_name`, `doc_id`, `action`, `user_id`, `details_json`
2. Crée 4 index pour accélérer les filtres
3. Met à jour la policy RLS SELECT pour inclure A1 en lecture
4. Crée la fonction `log_audit()` utilisée par tous les triggers
5. Crée 6 triggers : 5 sur les tables docs (factures, soumissions, feuilles_de_temps, clients, bons_de_commande) + 1 sur profils (rôles)
6. Crée 2 fonctions admin : `count_logs_expired()` et `delete_expired_logs()`

---

## 🎯 Ce qui change

### Pour Xavier (A0) et Tristan (A1)
- Onglet **"Journal d'Audit"** dans Admin (au lieu de "Journal Technique")
- **A1 a maintenant accès** au journal (avant : A0 seulement)
- **Filtres** : recherche libre + action + table + utilisateur (4 filtres combinables)
- **Export CSV** des logs filtrés (bouton ⬇ dans le header du panneau)
- Affichage **enrichi** : Date | Action | Utilisateur | Détails (au lieu de juste Date | Action | Détails)
- Couleurs par action (vert création, rouge suppression, orange archivage, etc.)
- Compteur en bas : "X entrée(s) affichée(s) sur Y chargée(s)"

### Pour Xavier seul (A0)
- Nouveau panneau **"Nettoyer Journal"** (mauve) à côté de "Nettoyer Archives"
- Affiche le nb de logs > 1 an
- Bouton "Nettoyer" → suppression définitive après confirmation
- L'opération de nettoyage est elle-même loggée (méta-log)

### Pour A2 et A3
- Aucun changement — pas d'accès au journal

### Tracé automatique (côté DB)
À partir de maintenant, **chaque** action sur ces tables crée une entrée dans le journal :
- **factures, soumissions, feuilles_de_temps, clients, bons_de_commande** : INSERT, UPDATE, DELETE
- **profils** : changement de rôle (UPDATE OF role)

Un changement de **statut** (brouillon → envoyé → approuvé) génère un log
spécifique avec l'ancien et le nouveau statut.

Les **archivages/restaurations** sont déjà loggés par le trigger
Phase 2 (`log_archivage`) — pas de doublon.

### Tracé côté JS
- **Connexion** : enregistrée 1× par session (sessionStorage évite le spam si on rafraîchit)

---

## 📦 Fichiers modifiés

### Nouveaux fichiers
- `supabase-phase3-auditlog.sql` — le SQL à exécuter

### Modifiés
- `index.html` :
  - Logue la connexion 1× par session après identification
- `code_admin/code_admin.html` :
  - Section "Journal Technique" → "Journal d'Audit"
  - Nouveaux filtres : action + table + utilisateur
  - Nouveau bouton export CSV
  - Tableau passe de 3 à 4 colonnes (ajout colonne Utilisateur)
  - Limite passe de 100 → 500 logs chargés (avec compteur affiché)
  - Couleurs par action
  - Nouvelle icône `icon-download` ajoutée
  - Nouveau panneau "Nettoyer Journal" (A0 seulement)
  - Onglet "Journal" maintenant accessible à A1 (avec panneaux A0-only masqués)

---

## 🛠 Détails techniques

### Schéma de la table après MAJ

```
logs_systeme:
  id              uuid PK         -- existant
  type_erreur     text            -- existant (gardé pour compat)
  message         text            -- existant
  utilisateur_nom text            -- existant
  created_at      timestamptz     -- existant
  table_name      text            -- NOUVEAU
  doc_id          text            -- NOUVEAU
  action          text            -- NOUVEAU (creation/modification/...)
  user_id         uuid            -- NOUVEAU (FK vers profils.id)
  details_json    jsonb           -- NOUVEAU (payload structuré)
```

`type_erreur` est conservé pour ne pas casser les anciens logs déjà
écrits, mais `action` est le nouveau champ canonique.

### Détection du changement d'archivage (anti-doublon)

Le trigger Phase 2 `log_archivage` se déclenche quand `is_archived`
change. Si on ne faisait rien, le **nouveau** trigger Phase 3
`trg_audit_doc_changes` se déclencherait aussi sur le même UPDATE et
créerait un log "modification" en double.

Solution : dans `trg_audit_doc_changes`, on détecte si `is_archived` est
le seul champ modifié, et on `RETURN NEW` sans logger.

### Fonctions accessibles via RPC

```sql
-- Côté JS via supabaseClient.rpc(...)
public.count_logs_expired()      -- A0 only, retourne bigint
public.delete_expired_logs()     -- A0 only, supprime + retourne bigint
```

Ces 2 fonctions vérifient `is_admin()` au début et lèvent une exception
si non-admin. Donc même si quelqu'un appelle l'RPC depuis la console,
ça échoue.

### Format CSV exporté

Avec **BOM UTF-8** au début (`\uFEFF`) pour qu'Excel ouvre bien les
accents. Colonnes : Date | Action | Utilisateur | Table | Doc ID | Message.

Toutes les valeurs sont entourées de guillemets et les guillemets
internes sont doublés (échappement CSV standard).

---

## ✅ Comment tester (10 min)

### Test 1 — Logs de création
1. Connecte-toi en **Jean (A3)**
2. Crée une nouvelle facture brouillon, sauvegarde
3. Connecte-toi en **Xavier (A0)** ou **Tristan (A1)**
4. Va dans Admin → Journal d'Audit
5. Tu devrais voir **2 logs** récents : "Connexion de Jean" + "Création de factures #..."

### Test 2 — Logs de modification + statut
1. En Jean, modifie ta facture (change un input), sauvegarde
2. Envoie-la au bureau
3. En Xavier, recharge le journal
4. Tu vois maintenant : "Modification de factures #..." + "Statut de factures #... : brouillon → envoye"

### Test 3 — Logs d'archivage (anti-doublon)
1. En Tristan, archive la facture
2. En Xavier, recharge le journal
3. Tu dois voir **UN seul log** "Document factures #... archivé" (pas deux entrées)

### Test 4 — Logs de changement de rôle
1. En Xavier, va dans Admin → Gestion du Personnel
2. Édite un employé (pas A0), change son rôle de A3 → A2 (ou autre)
3. Recharge le journal
4. Tu vois "Rôle de [nom] : A3 → A2"

### Test 5 — Logs de connexion
1. Déconnecte-toi puis reconnecte-toi
2. Va dans Journal d'Audit
3. Tu vois "Connexion de [ton nom]"
4. **Rafraîchir la page ne doit PAS créer un nouveau log de connexion** (sessionStorage)
5. Ferme l'onglet, rouvre, reconnecte → là, nouveau log

### Test 6 — Filtres
1. Dans Journal d'Audit, sélectionne **Action = "Création"**
2. Seuls les logs de création s'affichent
3. Ajoute **Table = "factures"**
4. Seuls les logs de création de factures
5. Tape "Tremblay" dans la recherche
6. Filtre cumulé
7. Compteur en bas se met à jour : "X entrée(s) affichée(s) sur Y chargée(s)"

### Test 7 — Export CSV
1. Filtre les logs qui t'intéressent
2. Clique le bouton ⬇ download dans le header
3. Un fichier `journal_audit_2026-04-26.csv` se télécharge
4. Ouvre-le dans Excel — les accents doivent être bien affichés

### Test 8 — Accès A1 vs A0
1. Connecte-toi en **Tristan (A1)**
2. Va dans Admin → onglet **Journal**
3. Tu vois le journal MAIS tu ne vois pas :
   - Le panneau "Mode Maintenance"
   - Le panneau "Rôles & Permissions"
   - Le panneau "Nettoyer Archives"
   - Le panneau "Nettoyer Journal"
   - Le panneau "Tickets de Support"

### Test 9 — Nettoyage des logs > 1 an
1. En Xavier, va dans Admin
2. Carte "Nettoyer Journal" doit afficher "✓ Aucun log expiré" (normal, rien n'a > 1 an)
3. Le bouton "Nettoyer" doit être grisé tant qu'il n'y a rien à supprimer

### Test 10 — Sécurité côté DB (anti-bypass)
Si tu veux vraiment tester : ouvre la console JS sur le navigateur de
Jean (A3) et tape :
```js
await supabaseClient.from('logs_systeme').select('*').limit(5)
```
Tu dois recevoir **un tableau vide** (pas une erreur). RLS bloque la
lecture pour A3.

---

## 🚀 Si tu veux modifier plus tard

### Logger une nouvelle action depuis le code JS
```js
await supabaseClient.from('logs_systeme').insert([{
    action: 'mon_action',           // ex: 'export_pdf', 'login_failed'
    type_erreur: 'mon_action',
    message: 'Ce qui s\'est passé',
    utilisateur_nom: 'Nom user',
    user_id: userId,
    table_name: 'factures',
    doc_id: 'F-0001'
}]);
```

### Ajouter une nouvelle table à logger automatiquement
Dans Supabase SQL Editor :
```sql
CREATE TRIGGER trg_audit_ma_table
  AFTER INSERT OR UPDATE OR DELETE ON public.ma_table
  FOR EACH ROW EXECUTE FUNCTION public.trg_audit_doc_changes();
```

### Étendre le filtre Action avec une nouvelle valeur
Dans `code_admin.html`, ajoute une `<option>` dans `#logActionFilter`,
et un libellé dans la fonction `actionLabel()`.

### Changer la durée de rétention (1 an → 2 ans)
Dans `supabase-phase3-auditlog.sql`, remplace `interval '1 year'` par
`interval '2 years'` dans `count_logs_expired()` et `delete_expired_logs()`,
puis re-exécute le script.

---

## ⚠️ Limitations connues

1. **Logs de connexion** : seulement la connexion réussie est tracée.
   Les tentatives échouées ne le sont pas (Supabase Auth ne permet pas
   d'intercepter ça facilement côté client).

2. **Volume** : si l'app est utilisée intensivement, le journal peut
   grossir vite (ex: 50 modifications/jour × 365 jours = 18 250 logs/an).
   Le panneau "Nettoyer Journal" permet de gérer ça manuellement.

3. **Utilisateur supprimé** : si un employé est supprimé, ses logs
   conservent son `prenom_nom` mais le `user_id` passe à NULL (ON
   DELETE SET NULL). Donc l'historique reste lisible.

4. **Logs antérieurs au Chantier 7** : les anciens logs (avant
   exécution du SQL) n'ont pas les nouveaux champs (action, table_name,
   etc.). Ils restent affichés mais avec une action générique.
