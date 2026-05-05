# 📋 État du projet F.Dussault — Notes de transition

**Dernière mise à jour :** 28 avril 2026 (fix 4 erreurs console)

Ce document contient toutes les décisions et l'état du projet pour pouvoir reprendre proprement dans une nouvelle conversation Claude.

---

## ✅ Chantiers terminés

### Chantier 1 : Sécurité Supabase (terminé et déployé)

**Côté DB :**
- RLS activé sur les 14 tables
- Colonne `mot_de_passe_clair` supprimée de `profils`
- 55 policies créées avec hiérarchie A0/A1/A2/A3
- Fonctions helper : `is_admin()`, `current_user_role()`, `user_has_permission()`
- Trigger anti-promotion : `prevent_self_role_change`
- Config des rôles dans `parametres_globaux.cle = 'roles_config'`

**Côté code :**
- Viewports corrigés (zoom à nouveau possible)
- Service worker v3 avec tous les modules cachés
- Manifest avec shortcuts PWA
- `assets/shared/shared.css` et `shared.js` créés (toast, gestion erreurs Supabase)
- `index.html` charge le shared et setup le toast listener

### Chantier 2 : Sauvegarde auto + Numérotation + Archivage (terminé et déployé)

**Phase 1 — Numérotation auto + Autosave** (matin du 26 avril)
- Factures : numérotation `F-0001`, `F-0002`... auto-générée côté DB
- Autosave localStorage avec debounce 2s + force 30s sur factures, soumissions, feuilles de temps
- Toast "Brouillon restauré" silencieux à l'ouverture
- Voir `CHANGELOG-PHASE1-PART2.md`

**Phase 2 — Archivage soft delete** (soir du 26 avril)
- 5 nouvelles colonnes sur les 3 tables (`is_archived`, `archived_at`, `archived_by`, `archived_by_name`, `archive_reason`)
- Trigger Postgres qui logge automatiquement chaque archivage/restauration
- RLS update : doc archivé en lecture seule absolue (sauf restauration A0)
- Onglet "Archives" sur les 3 modules
- Panneau Admin "Nettoyer Archives" avec compteur + suppression > 1 an
- Tout mutualisé dans `assets/shared/archive.js`
- SQL exécuté : ✅
- Voir `CHANGELOG-PHASE2-ARCHIVAGE.md`

### Chantier 3 : Nettoyage technique (terminé le 26 avril soir)

**Bilan :** projet de 5.8 Mo → 1.3 Mo (-77%)

- **Service Worker v3 → v4** : ajout des fichiers shared/ et logos qui ont migré dans /assets/
- **Manifest** : vraie icône maskable créée (`logo_app_maskable.png`) avec safe zone
- **Dédoublonnage** : 16 logos dupliqués/orphelins supprimés des dossiers code_*
- **Compression** : tous les logos de /assets/ compressés (-73%)
- 3 fichiers HTML mis à jour pour pointer vers `../assets/...`
- Voir `CHANGELOG-CHANTIER3-NETTOYAGE.md`

**À faire après mise en prod :** vider le cache navigateur ou déconnecter
le SW une fois pour passer en v4. Ensuite, automatique pour tout le monde.

### Chantier 4 : Mutualisation CSS (terminé le 26 avril soir)

**Bilan :** variables CSS définies une seule fois dans `shared.css` au lieu de 14 endroits.

- **Variables CSS** (`--app-bg`, `--btn-yellow`, etc.) : retirées des 13 modules,
  centralisées dans `assets/shared/shared.css`
- **`* { box-sizing }`** : centralisé dans shared.css
- **`.svg-icon`** : centralisé dans shared.css (12 copies retirées)
- **Découverte importante** : 9 modules sur 12 ne chargeaient pas shared.css avant !
  Ils ont été corrigés (charge maintenant `shared.css` + `shared.js`).
  → **Bonus** : tous les modules ont maintenant accès à `window.showToast()`
- `login.html` charge aussi shared.css maintenant
- Exception conservée : `code_calendrier` garde son `:root` local pour
  ses 2 variables spécifiques (`--cal-grid-border`, `--cal-header-bg`)
- Voir `CHANGELOG-CHANTIER4-CSS.md`

**Pour changer le thème jaune en autre chose** : modifier `--btn-yellow`
et `--sidebar-bg` dans `assets/shared/shared.css` (1 seul fichier).

### Chantier 5 : Export PDF avec aperçu (terminé le 26 avril soir)

**Bilan :** vrai export PDF avec modal d'aperçu + bouton télécharger,
indépendant du menu d'impression du navigateur.

- **Nouveau module shared** : `assets/shared/pdf-export.js`
  - Charge html2canvas + jsPDF à la demande depuis CDN
  - Modal d'aperçu avec iframe
  - Nom de fichier intelligent : `F-0001_Tremblay_2026-04-26.pdf`
  - API : `window.PDFExportFD.openPreview({container, docType, docNumber, clientName, date})`
- **3 modules d'édition** mis à jour :
  - Bouton "Imprimer" → "PDF / Imprimer"
  - Fonction `exporterPDF()` réécrite (factures, soumissions, feuilles)
  - Plus de `window.print()` qui dépendait du navigateur
- **SW v4 → v5** : ajout de pdf-export.js au cache
- Voir `CHANGELOG-CHANTIER5-PDF.md`

**Limitation connue** : premier export en mode hors-ligne échoue (libs
CDN à télécharger). Une fois en cache navigateur, marche offline.

### Chantier 6 : Signature électronique améliorée (terminé le 26 avril soir)

**Bilan :** signature vraiment utilisable sur le terrain (mobile +
desktop), code mutualisé.

- **Nouveau module shared** : `assets/shared/signature.js`
  - Trait lissé (courbes quadratiques) au lieu de cassant
  - Canvas haute résolution (devicePixelRatio)
  - Modal plein écran sur mobile (60% de la hauteur)
  - Bouton **Effacer** pour recommencer sans fermer
  - **Annuler** garde la signature précédente intacte
  - Vibration tactile au début du tracé (Android)
  - Touche **Échap** pour annuler
  - Indicateur "✓ Signé" sur les zones signées (badge vert)
  - Pré-charge la signature précédente au reclic
  - API : `SignatureFD.attach(img)`, `attachAll(container)`,
    `watchContainer(container)`, `refreshIndicators(container)`
- **2 modules** mis à jour : `code_facture.html` et `code_soumissions.html`
  - Ajout du `<script>` signature.js
  - Activation au boot via `watchContainer` + `attachAll`
  - Refresh des indicateurs après chargement d'un doc
- **Code mort restant** : l'ancien système (modal `#sig-modal` + ~80
  lignes JS) est encore présent mais inactif. Ménage optionnel pour
  plus tard, ne dérange rien.
- **SW v5 → v6** : ajout de signature.js au cache
- Voir `CHANGELOG-CHANTIER6-SIGNATURE.md`

### Chantier 7 : Audit Log complet (terminé le 26 avril soir)

**Bilan :** vrai journal d'audit, traçabilité totale via triggers
PostgreSQL, accessible aussi à A1 (patron).

**SQL à exécuter :** `supabase-phase3-auditlog.sql` (idempotent)

- **Table `logs_systeme` enrichie** : 5 nouvelles colonnes
  (`table_name`, `doc_id`, `action`, `user_id`, `details_json`)
- **6 triggers PostgreSQL** : INSERT/UPDATE/DELETE sur factures,
  soumissions, feuilles_de_temps, clients, bons_de_commande + UPDATE OF
  role sur profils
- **Anti-doublon** : le trigger sait détecter les archivages (déjà
  loggés Phase 2) et ne les re-logge pas
- **Connexion loggée côté JS** une fois par session (sessionStorage)
- **Page Admin "Journal d'Audit"** :
  - Accessible à **A0 et A1** (avant : A0 seulement)
  - 4 filtres combinables : recherche + action + table + utilisateur
  - Export CSV des logs filtrés (BOM UTF-8 pour Excel)
  - Couleurs par action (vert création, rouge suppression, etc.)
  - Tableau 4 colonnes : Date | Action | Utilisateur | Détails
  - Limite 500 logs avec compteur affiché
- **Panneau "Nettoyer Journal"** (mauve, A0 only) à côté de "Nettoyer
  Archives" : RPC `count_logs_expired()` et `delete_expired_logs()`
  pour suppression manuelle des logs > 1 an
- 2 nouvelles fonctions Postgres réservées admin :
  `count_logs_expired()` et `delete_expired_logs()`
- Voir `CHANGELOG-CHANTIER7-AUDITLOG.md`

**Pour A1** : tab-dev visible mais panneaux A0-only masqués
(Permissions, Maintenance, Archives, Nettoyer logs, Support).

---

## 📌 Infos techniques importantes

### Comptes utilisateurs (en dev)
- **Xavier** (xavierbouclin@gmail.com) — A0 — UUID `348cb023-2ad1-4c29-9975-08fe8b0a31e9`
- **Tristan** (ttbouclin1@gmail.com) — A1 — UUID `3a61d67a-0949-4ed0-a10d-86c3f69b2e88`
- **Jean** (123@gmail.com) — A3 — UUID `0c34b103-fbcb-4b4e-87f3-cc453bdcb004`

### Hiérarchie des rôles
- **A0** : super admin (Xavier) — tout autorisé
- **A1** : patron / gestion
- **A2** : chef équipe / contremaître
- **A3** : employé régulier / plombier
- Possibilité d'ajouter A4, A5... plus tard via `parametres_globaux.roles_config`

### Notes métier
- Les "factures" dans l'app ne sont PAS des factures comptables — ce sont des **rapports de chantier / bons de travail**. Le bureau s'en sert pour générer la vraie facture après.
- D'où la rétention courte (1 an suffit) et la flexibilité sur la numérotation.

### Structure des données Supabase
Les valeurs des formulaires sont stockées en JSONB :
- `input_values` (jsonb) : array des valeurs des `<input>`
- `sig_values` (jsonb) : array des base64 des signatures

C'est sur ce mécanisme que repose la sauvegarde auto.

### Architecture fichiers (après Chantier 3)
- **Tous les logos** sont maintenant dans `/assets/` uniquement
- Les modules `code_*` les référencent via `../assets/nom_du_logo.png`
- Pour ajouter un logo : poser dans `/assets/`, référencer en relatif, ajouter au cache du SW

---

## 🐛 Audit + corrections de bugs (27 avril 2026)

Audit statique complet du code (script Python qui analyse chaque fichier
HTML/JS pour trouver références cassées, fonctions manquantes, IDs
fantômes, etc.). 4 vrais bugs trouvés et corrigés :

1. **Recherche cassée dans Factures** : `onkeyup="filterInvoices()"`
   appelait une fonction inexistante. Corrigé en
   `onkeyup="renderInvoiceList()"` qui faisait déjà le travail.

2. **Compteur de factures invisible** : code cherchait `#inv-compteur`
   absent du HTML. Ajout du `<div>` correspondant.

3. **Bouton "Charger plus" cassé dans Soumissions et Feuilles de temps** :
   cherchait `getElementById('listContainer')` au lieu des vrais IDs
   `quoteListContainer` et `timesheetListContainer`. Conséquence : si tu
   avais plus de 50 docs, tu ne pouvais pas voir les suivants. Corrigé.

4. **Shortcuts PWA ne fonctionnaient pas** : le `manifest.json` définit
   `?view=factures`, `?view=temps`, `?view=messagerie` mais `index.html`
   n'avait aucune logique pour lire ce paramètre. Ajout de la fonction
   `handlePWAShortcut()` qui parse l'URL et clique sur le bon module.

### 🆕 Amélioration UX — Compactage des lignes vides (Feuilles de temps)

Quand l'utilisateur saisit ses heures dans la feuille de temps et qu'il
laisse une **ligne complètement vide entre deux lignes remplies**, ces
lignes vides sont maintenant **automatiquement déplacées à la fin** au
moment de la sauvegarde.

- Déclenchement : à chaque clic sur **Sauvegarder** ou **Envoyer au bureau**
- **Pas pendant la saisie** : l'utilisateur peut taper où il veut, rien
  ne bouge tant qu'il ne sauvegarde pas
- Définition d'une "ligne vide" : les **4 champs** (Date, # Bon, Adresse,
  Heures) sont **tous vides** après trim. Si même un seul champ est
  rempli, la ligne reste à sa place.
- Aucune donnée perdue : c'est juste un réordonnancement.
- Le total des heures est calculé après le compactage (résultat identique).

### 🆕 Ajustements Feuilles de temps (27 avril)

**Dupliquer copie maintenant la page entière**
- Avant : seuls le nom de l'employé + la semaine étaient copiés
- Maintenant : tous les inputs (header + lignes du tableau) sont copiés
- Utile pour reproduire une semaine type qui se répète

**Case TOTAL retirée de la feuille**
- L'input "TOTAL : ___" en bas de chaque page n'existe plus
- Le calcul du total est **conservé** côté code (variable `totalGlobal`)
  → toujours sauvegardé dans Supabase comme avant
- Toujours affiché dans le **dashboard** (carte de chaque feuille de
  temps avec les heures totales en jaune)
- L'utilisateur ne le voit plus dans le formulaire (à remettre plus tard
  ailleurs si besoin, par exemple dans un menu)
- CSS de `.total-box` aussi retiré
- Fonction `calculerTotal()` conservée mais vidée (compatibilité avec
  appels existants)

**Centrage horizontal des pages aligné dans les 3 modules**
- Avant : seulement les soumissions étaient parfaitement centrées
  horizontalement. Factures et feuilles de temps avaient un léger
  décalage à gauche selon le niveau de zoom.
- Cause : différence de CSS entre les 3 modules
  (`transform-origin: top left` vs `top center`, et présence ou non de
  `margin: 0 auto` sur le container).
- Fix : aligné les 3 modules sur le même pattern que soumissions
  (`transform-origin: top center` + `margin: 0 auto`).

### 🆕 Messagerie — Indicateur "🟢 Connecté" retiré

Le statut de présence "🟢 Connecté" affiché sous le nom de la
conversation a été complètement retiré.

- **Pourquoi** : c'était hardcodé, ça affichait "Connecté" en dur peu
  importe si la personne était vraiment en ligne. Mensonge
  cosmétique → plutôt rien que faux.
- **Retiré** : élément HTML `<p id="chatHeaderStatus">`, toutes les
  valeurs `status: '🟢 Connecté'` dans `conversationsData`, et le code
  JS qui manipulait `chatHeaderStatus`.
- **Conservé** : tout le mécanisme Realtime Supabase
  (`supabaseClient.channel(...)`, `.on(...)`, `.subscribe(...)`,
  `removeChannel`) qui fait que les messages arrivent en temps réel.
  Le retrait du faux statut n'affecte en rien la livraison des messages.

### 🆕 PO — Fournisseurs récurrents (liste éditable)

Le champ "Fournisseur" du modal Nouveau Bon de Commande devient un menu
déroulant + option "Autre..." pour fournisseurs ponctuels. La liste est
gérée depuis l'admin par A0/A1/A2.

**Côté code_po.html :**
- Le `<input type="text" id="inpFournisseur">` est remplacé par un
  `<select id="selFournisseur">` qui se remplit dynamiquement
- Si "Autre..." est choisi → un champ texte apparaît pour saisie libre
- Un `<input type="hidden" id="inpFournisseur">` conserve le même ID
  qu'avant pour la compat avec le code de save (ligne 307)
- La liste est rechargée à chaque ouverture du modal (au cas où qqn
  aurait modifié dans Admin entre-temps)

**Côté code_admin.html :**
- Nouveau panneau "Fournisseurs récurrents" (bleu) dans `sec-users`
  juste après "Gestion du Personnel"
- Champ texte + bouton "Ajouter" (ou Enter pour valider)
- Liste avec bouton "X" pour retirer chaque entrée
- Détection de doublons (insensible à la casse)
- Confirmation avant suppression
- Sauvegarde dans `parametres_globaux.cle = 'fournisseurs_recurrents'`
  (JSON array)

**Permissions :**
- Nouvelle perm : `manage_suppliers`
- Ajoutée par défaut à A0, A1 **et A2**
- Pour A2 : ajout aussi de `view_admin` pour qu'il puisse ouvrir l'onglet
  Admin, mais on masque pour lui le panneau "Gestion du Personnel"
  (`employeesPanel` caché). Donc A2 voit Admin avec **uniquement** le
  panneau Fournisseurs.

**Données :**
- Pré-remplissage automatique au premier usage : Deschênes, Wolseley,
  Plomberie Provinciale
- Pas de SQL à exécuter — utilise la table `parametres_globaux`
  existante
- Anciens PO non affectés : leur valeur `fournisseur` reste en texte
  libre (historique préservé)

### 🆕 Tableau de bord Admin — Nouveaux panneaux

3 nouveaux panneaux ajoutés dans l'onglet "Tableau de bord" (sec-users)
et 1 panneau déplacé.

**1. Outils — Inventaire** (vert) — A0/A1
- Permet d'ajouter rapidement un nouvel outil dans la table `outils`
- Champ texte + bouton Ajouter (ou Enter pour valider)
- Liste des outils existants avec leur assigné (ou "Non assigné")
- Bouton retirer pour supprimer un outil de l'inventaire (avec confirm)
- Détection de doublons par nom (insensible à la casse)
- L'outil est créé avec `status: 'active'` et `assignee_nom: null` →
  apparaît dans le module Outils prêt à être assigné

**2. Compteurs** (jaune) — A0/A1
- Carte gauche : **Dernière facture** créée (ex: F-0042) +
  Prochaine (F-0043)
- Carte droite : **Dernier PO** créé (ex: PO-260427-1234) +
  Total de PO créés
- Numérotation factures basée sur le `MAX(id)` qui correspond au
  pattern `F-XXXX` (cohérent avec la fonction SQL `next_facture_number()`)
- Numérotation PO : juste le dernier en date + total

**3. Tickets de Support** (orange) — A0/A1 — DÉPLACÉ
- Avant : dans l'onglet "Permissions et système" (réservé A0)
- Après : dans le tableau de bord (visible aussi pour A1)
- Logique JS inchangée (`initSupportUI()`)
- A1 voit donc maintenant les tickets de support, en plus du journal
  d'audit → le patron a une vraie vue d'ensemble

**Permissions résumées :**
| Rôle | Personnel | Fournisseurs | Outils | Compteurs | Support |
|---|---|---|---|---|---|
| A0 | ✅ | ✅ | ✅ | ✅ | ✅ |
| A1 | ✅ | ✅ | ✅ | ✅ | ✅ |
| A2 | ❌ (Admin pas accessible) | | | | |
| A3 | ❌ (Admin pas accessible) | | | | |

**Note** : A2 avait été temporairement autorisé à gérer les fournisseurs,
mais retiré le 27 avril (plus simple). Si tu veux le remettre plus tard,
ajouter `view_admin` et `manage_suppliers` aux perms de A2 dans
`code_admin.html` et `index.html`, puis remettre le bloc `else if
(myRole === 'A2')` dans `initAdmin()` qui masquait `employeesPanel`.

### 🆕 Factures — Bouton "Dupliquer" (bleu) retiré

Sur les cartes de factures du dashboard, il y avait un petit bouton
bleu de duplication (à côté du X de suppression). Il a été retiré.

- **Conséquence** : on ne peut plus dupliquer une facture en 1 clic
  depuis le dashboard
- **Code conservé** : la fonction `duplicateInvoice()` (~30 lignes)
  reste dans le fichier mais n'est plus jamais appelée. Si tu veux
  remettre le bouton plus tard, c'est juste 1 ligne à rajouter dans
  `actionsHTML` (cherche le commentaire "Vue normale : bouton Supprimer
  (= archiver)" dans `code_facture.html` ligne ~1064).
- **Note** : ce bouton n'existait que dans factures, pas dans
  soumissions ni feuilles de temps.

### 🐛 Fix critique — Erreurs de sauvegarde "Lock broken" / "Failed to fetch"

**Symptôme observé** : au clic sur Sauvegarder ou Envoyer au bureau,
l'utilisateur recevait parfois :
- `TypeError: Failed to fetch`
- `AbortError: Lock broken by another request with the 'steal' option.`
- Et dans feuilles de temps spécifiquement, du HTML brut s'affichait
  dans le message (`<br><small style='color:#aaa;'>...</small>`)

**Cause racine** : l'app charge Supabase 12 fois (1 client par iframe).
Quand 2 requêtes essaient de toucher le lock d'authentification en
même temps (clic + autosave qui se déclenche en parallèle), le lock
est "volé" et la 1ère requête échoue.

**Trois corrections appliquées :**

1. **Bug HTML brut dans feuilles de temps** : `showAlert()` utilisait
   `.textContent` au lieu de `.innerHTML`, donc les balises HTML du
   message d'erreur s'affichaient littéralement. Corrigé en `.innerHTML`
   (cohérent avec factures et soumissions).

2. **Retry automatique** : nouveau helper `window.SharedFD.withRetry()`
   ajouté dans `assets/shared/shared.js`. Détecte les erreurs
   transitoires (`AbortError`, `Lock broken`, `Failed to fetch`,
   `network`, HTTP 5xx) et réessaie automatiquement **1 fois** après
   600ms. Invisible pour l'utilisateur dans 99% des cas.
   - Wrappe les appels `upsert` dans : `code_facture.html` ligne ~948,
     `code_soumissions.html` ligne ~520, `code_feuille_de_temps.html`
     ligne ~528.
   - API : `withRetry(operation, { delay: 600, maxAttempts: 2 })`
   - Pattern d'usage :
     ```js
     const retry = window.SharedFD ? window.SharedFD.withRetry : (op) => op();
     const { error } = await retry(() => supabaseClient.from('X').upsert(payload));
     ```

3. **Messages d'erreur user-friendly** : si malgré le retry une erreur
   persiste, le message est désormais clair :
   - "Une autre opération est en cours. Attends 2 secondes et réessaie."
     (Lock broken)
   - "Pas de connexion internet. Vérifie ta connexion et réessaie."
     (network)
   - "Tu n'as pas la permission de modifier cette facture/soumission/
     feuille." (RLS)
   - Plus le message technique brut.

**À tester** : clique vite sur Sauvegarder plusieurs fois d'affilée,
ou clique pendant que l'autosave tourne. Avec le retry, ça devrait
passer silencieusement. Si ça échoue quand même, le message sera
propre.

### 🐛 Fix critique — Calendrier : bouton Sauvegarder sans effet

**Symptôme** : dans le calendrier, le bouton "Sauvegarder" du modal
"Service d'urgence" (ou "Nouvel Événement") ne faisait rien. Le modal
se fermait, mais l'événement n'apparaissait pas dans le calendrier.

**Cause double :**
1. **SQL** : la table `evenements` avait RLS activé (via le SQL
   sécurité initial qui touche toutes les tables) mais **aucune
   policy** définie. Conséquence : tout INSERT/UPDATE/DELETE était
   bloqué par défaut.
2. **JS** : le code `saveEvent()` appelait `upsert` mais ne vérifiait
   pas l'erreur retournée. L'opération échouait silencieusement, le
   modal se fermait, l'utilisateur ne voyait rien.

**SQL à exécuter** : `supabase-fix-evenements-rls.sql` (à la racine).
Idempotent (relançable). Crée 4 policies :
- `evenements_select` : tous les utilisateurs auth peuvent lire (le
  filtrage par calendrier/partage se fait côté JS)
- `evenements_insert` : auteur = utilisateur courant, ou admin (A0/A1)
- `evenements_update` : auteur ou admin
- `evenements_delete` : auteur ou admin

**JS corrigé** : `code_calendrier.html`
- `saveEvent()` : utilise `withRetry`, vérifie l'erreur, désactive le
  bouton pendant la sauvegarde, message user-friendly si échec
- `saveCalendar()` (création de calendrier custom) : pareil
- `deleteCurrentCalendar()` : pareil pour les 2 deletes en cascade
- `deleteCurrentEvent()` : pareil

**À tester** : crée un événement Service d'urgence ou un événement
normal. Doit apparaître immédiatement dans le calendrier. Si ça
échoue, message clair affiché.

### 🐛 Fix critique — Désalignement entre schéma DB et code JS

**Symptômes observés** au save dans soumissions et feuilles de temps :
- Soumissions : `invalid input syntax for type bigint: "S-8796"`
- Feuilles : `Could not find the 'employe_nom' column of 'feuilles_de_temps' in the schema cache`

**Cause** : pendant le développement le code JS et la structure des
tables Supabase ont divergé.

1. **Soumissions** : la colonne `id` est de type `bigint` (entier
   auto-incrément) mais le code envoie `"S-8796"` (texte). Ce souci
   avait déjà été corrigé pour `factures` en Phase 1, mais pas pour
   les soumissions.

2. **Feuilles de temps** : le code envoie une colonne `employe_nom`
   mais la table avait probablement `employe` à la place (ou rien).

**SQL à exécuter** : `supabase-fix-schemas.sql` (à la racine).
Idempotent (relançable). Le script :

- **Vide les tables `soumissions` et `feuilles_de_temps`** (tu as
  confirmé que c'est OK, les données étaient pas importantes)
- Change le type `soumissions.id` de `bigint` vers `text` (mêmes étapes
  qu'on a faites pour factures)
- Pour `feuilles_de_temps.employe_nom` : détection intelligente
  - Si `employe_nom` existe déjà → ne touche pas
  - Si `employe` existe → renomme `employe` en `employe_nom`
  - Si rien → ajoute la colonne `employe_nom text`
- Vérifie aussi `bons_de_commande.id` (si bigint, change en text)
- À la fin, affiche les types des colonnes `id` de toutes les tables
  pour vérification

**À tester après exécution** :
1. Crée une nouvelle soumission, sauvegarde → doit marcher sans
   erreur, l'ID sera du genre `S-1234`
2. Crée une nouvelle feuille de temps, sauvegarde → doit marcher
3. Vérifie aussi qu'envoyer au bureau marche

### 🆕 Uniformisation de l'icône suppression/archivage

Les cartes de **factures** affichaient un simple `X` rouge pour le
bouton supprimer/archiver, alors que tous les autres modules
(soumissions, feuilles, clients, outils, PO, etc.) utilisaient déjà
la jolie icône poubelle SVG (`icon-trash`).

- **Fix** : `code_facture.html` ligne ~1085, remplacement du `X` par
  `<svg class="svg-icon"><use href="#icon-trash"></use></svg>` (mêmes
  dimensions 18x18 que dans les feuilles de temps)
- **Vérification** : toutes les définitions de `icon-trash` dans les
  12 modules ont le même hash MD5 → cohérence visuelle complète
- Aucun autre `X` littéral comme bouton de suppression dans le code

### 🆕 Audit complet de cohérence visuelle (8 corrections)

Suite à un audit visuel approfondi de tous les modules, 8 incohérences
détectées et corrigées :

**Bugs SVG (typos invisibles à l'œil mais réels dans le code) :**
1. `icon-edit` dans `code_calendrier.html` avait une typo (`2-2h14`
   au lieu de `2 2v14`) qui déformait subtilement l'icône.
2. `icon-save` dans `code_profil_parametres.html` avait une typo
   similaire dans le path SVG.

**Incohérences de boutons "Nouveau X" :**
3. "Nouvelle feuille" n'avait pas le `style="background-color:
   var(--btn-yellow);"` → couleur grise au lieu du jaune des autres.
4. "Nouvelle feuille" avait une minuscule (devrait être "Nouvelle
   Feuille" comme "Nouvelle Facture" / "Nouvelle Soumission").

**Cohérence des classes CSS :**
5. PO utilisait `class="btn-action"` au lieu de `class="action-btn"`.
   Renommage global dans `code_po.html` (CSS + HTML).

**Compteurs manquants :**
6. Soumissions et Feuilles de temps n'avaient pas le compteur "X
   chargée(s)" qui existait dans Factures. Ajout des `<div
   id="quote-compteur">` et `<div id="ts-compteur">` + mise à jour
   des fonctions `renderQuoteList()` et `renderTimesheetList()`.

**Style btn-icon :**
7. `code_clients.html` avait un `btn-icon` rond (`border-radius:
   50%`) avec rotation au hover, alors que les autres modules ont des
   carrés arrondis (`8px`) sans rotation. Aligné sur le standard.

**Modal d'alerte :**
8. Clients avait un titre "Attention" en rouge `#ff4d4d`, alors que
   les 9 autres modules ont "Information" en jaune `var(--btn-yellow)`.
   Aligné sur le standard.

**Vérification finale** : icônes `icon-edit`, `icon-save`, `icon-trash`
sont maintenant toutes identiques dans les 12 modules (vérifié par
hash MD5).

### 🐛 Fix critique — Brouillon localStorage qui restaurait les anciennes données

**Symptôme** : quand tu cliques "Nouvelle Soumission" (ou Facture, ou
Feuille de temps), l'ancien contenu de la dernière soumission s'affichait
dans le formulaire vide, comme si le formulaire était "hanté". Sauvegarder
écrasait alors la précédente au lieu d'en créer une nouvelle.

**Cause** : l'autosave (Phase 1) sauve les brouillons en localStorage
sous une clé `fdussault_draft_<module>_<id>`. Quand l'ID est `null`
(brouillon non encore sauvegardé), la clé devient `..._<module>_new`.
Mais cette clé `_new` n'était jamais effacée :
- Tu écris du contenu → autosave stocke dans `..._soumission_new`
- Tu sauvegardes → ID devient `S-8796`, `..._soumission_S-8796` est
  effacé... mais `..._soumission_new` reste accroché
- Tu reviens plus tard sur "Nouvelle Soumission" → `currentQuoteId =
  null` → `..._soumission_new` existe toujours → restauration des
  anciennes données

**Corrections appliquées dans les 3 modules** (factures, soumissions,
feuilles de temps) :

1. **Au début de `openNewQuote/Invoice/Timesheet`** : effacer
   explicitement `localStorage.removeItem('fdussault_draft_<module>_new')`
   AVANT de réinitialiser le formulaire et de démarrer l'autosave.

2. **À la fin du save** : après avoir mis à jour `currentXId` avec le
   nouveau numéro, effacer aussi `..._<module>_new` (en plus du
   `clearAutosaveForCurrent()` qui efface l'ID nouveau).

Plus aucune contamination entre soumissions/factures/feuilles successives.

---

## 📂 Organisation des fichiers à la racine

```
mon-site-chantier7-complete/
├── NOTES.md                            ← ce fichier (à jour)
├── index.html, login.html, sw.js, manifest.json, supabase-config.js
├── supabase-securite.sql               ← Chantier 1 (RLS)
├── supabase-phase1-numerotation.sql    ← Phase 1 (numérotation auto)
├── supabase-phase2-archivage.sql       ← Phase 2 (archivage)
├── supabase-phase3-auditlog.sql        ← Phase 3 (audit log) — DÉJÀ EXÉCUTÉ ?
├── assets/
│   ├── *.png (logos, compressés)
│   └── shared/
│       ├── shared.css, shared.js       ← thème, toast, helpers
│       ├── autosave.js                 ← Phase 1
│       ├── archive.js                  ← Phase 2
│       ├── pdf-export.js               ← Chantier 5
│       └── signature.js                ← Chantier 6
├── code_*/code_*.html                  ← 12 modules
└── docs/                               ← historique, à consulter au besoin
    ├── CHANGELOG-SECURITE.md           (Chantier 1)
    ├── CHANGELOG-PHASE1-PART2.md       (numérotation + autosave)
    ├── CHANGELOG-PHASE2-ARCHIVAGE.md   (archivage)
    ├── CHANGELOG-CHANTIER3-NETTOYAGE.md (poids/images)
    ├── CHANGELOG-CHANTIER4-CSS.md      (mutualisation CSS)
    ├── CHANGELOG-CHANTIER5-PDF.md      (export PDF)
    ├── CHANGELOG-CHANTIER6-SIGNATURE.md (signature améliorée)
    └── CHANGELOG-CHANTIER7-AUDITLOG.md (audit log)
```

---

## 🚀 Pour reprendre dans une nouvelle conversation

7 chantiers complètement terminés. Le projet est dans un état très
propre : sécurisé, fonctionnel, léger, mutualisé, avec audit log.

**Pistes restantes du plan original (par ordre d'impact) :**

🥇 **À fort impact métier** :
- **Templates de soumissions** — modèles récurrents (chauffe-eau,
  débouchage) pour générer une soumission en 2 clics
- **Dashboard analytique sur l'Accueil** — CA mois, top clients, factures
  en attente
- **Photos avant/après** sur fiches client (Supabase Storage)

🥈 **Améliorations utiles** :
- **Notifications push** réelles (Web Push API + Supabase Edge Functions
  — complexe, iOS limité)
- **Calculatrice CMMTQ** dans Outils

🏗️ **Gros chantier technique** :
- **Migration SPA** (Vite + vanilla JS) — règle le problème des 12
  iframes. Réécrit l'architecture, ~3-5 sessions, risque de régression
  élevé. À garder pour quand on a vraiment du temps.

**Si besoin de reprendre :**
1. Renvoyer à Claude le zip à jour du projet
2. Coller ce document `NOTES.md` dans la conversation
3. Préciser ce qu'on veut faire ensuite

Claude pourra alors démarrer un nouveau chantier sans avoir à redécouvrir
le code.

---

## 🐛 Fix 28 avril (soir) — 4 erreurs console DevTools

Suite à inspection des DevTools (F12 → Console), 4 erreurs détectées
et corrigées :

**1. `Uncaught ReferenceError: timesheetObj is not defined` (feuilles de temps)**
- Ligne 403-405 de `code_feuille_de_temps.html` : `applyEditorSecurity()`
  utilisait `timesheetObj` (ancien nom) au lieu de `sheetObj` (nom du
  paramètre). Plantait à chaque ouverture d'une feuille existante.
- Aussi corrigé ligne 460 : commentaire `// timesheetObj passé fitToScreen();`
  qui mangeait l'appel à `fitToScreen()`. Maintenant 2 lignes séparées.

**2. Erreurs HTTP 400 Supabase (`id=eq.null`, profil)**
- Dans `code_profil_parametres.html`, `initAuth()` appelait
  `initProfileData()` sans setter `myUserIdGlobal = user.id`. Du coup
  les requêtes partaient avec `id=null` → 400 Bad Request.
- Fix : `myUserIdGlobal = user.id;` ajouté avant `initProfileData()`,
  + garde de sécurité dans `initProfileData` qui abandonne si l'ID
  n'est pas défini.

**3. Erreur HTTP 404 `count_logs_expired`**
- La fonction RPC n'existait pas dans Supabase (Phase 3 SQL pas
  exécuté).
- Fix : `loadLogsExpiredCount()` détecte maintenant le 404 et affiche
  "Fonction non disponible (exécuter Phase 3 SQL)" proprement, au lieu
  de spammer la console avec une erreur.
- **Action utilisateur si le message apparaît** : exécuter
  `supabase-phase3-auditlog.sql` dans Supabase SQL Editor.

**4. Bonus — 3 bugs `showConfirm` cassés dans admin**
- En investiguant, trouvé que 3 fonctions appelaient `showConfirm()`
  qui n'existe pas dans `code_admin.html` (le module utilise
  `showConfirmAdmin()`). Conséquence : silence total au clic.
- Fix : remplacement `showConfirm` → `showConfirmAdmin` dans :
  - `cleanExpiredLogs` (Nettoyer Journal)
  - `removeSupplier` (Retirer un fournisseur récurrent)
  - `removeTool` (Retirer un outil de l'inventaire)

**5. Avertissement meta apple-mobile-web-app-capable déprécié**
- Chrome demande aussi `<meta name="mobile-web-app-capable">` pour
  les PWA modernes.
- Fix : ajout dans `index.html` (en plus de la version Apple).

### 🐛 Fix 28 avril (tard) — Filtre anti-bruit pour les warnings Lock Supabase

**Symptôme** (visible après exécution du SQL Phase 3) :
- 30+ warnings/erreurs dans la console au démarrage de l'app :
  - "Lock 'lock:fdussault-auth-v1' was not released within 5000ms"
  - "AbortError: Lock broken by another request with the 'steal' option"
  - "Erreur d'initialisation : AbortError"
  - "Uncaught (in promise) AbortError: Lock broken"

**Cause racine** : l'app charge le client Supabase 12 fois (une par
iframe). Chaque instance essaie d'acquérir le même lock localStorage
`lock:fdussault-auth-v1` au démarrage → conflits massifs. Supabase
gère la situation en interne (acquire forcé après 5s), donc l'app
fonctionne quand même, mais les warnings polluent la console.

**Pourquoi pas de fix architectural** : la vraie solution serait de
migrer vers une SPA avec un seul client Supabase, mais c'est un gros
chantier (3-5 sessions, risque de régression élevé). Pour le moment,
on filtre le bruit cosmétique.

**Fix appliqué** : nouveau bloc en haut de `assets/shared/shared.js`
qui :
1. Wrapper `console.warn` et `console.error` pour ignorer les
   messages contenant "Lock not released within", "lock:fdussault-auth"
   ou "AbortError + Lock broken"
2. Listener sur `unhandledrejection` qui empêche les promesses
   rejetées avec ces erreurs de polluer la console
3. Préserve tous les autres warnings/erreurs (qui restent visibles)

**Le code applicatif a déjà** : un helper `withRetry()` dans `shared.js`
qui détecte les erreurs transitoires (Lock broken, etc.) et réessaie
automatiquement. Il est appliqué aux upserts dans les 3 modules
factures/soumissions/feuilles + 4 endroits dans le calendrier. Les
opérations critiques sont donc déjà robustes.

**Conséquence** : la console redevient lisible (les vraies erreurs
ressortent), l'app continue à fonctionner normalement.

Comme le filtre est dans `shared.js` et que tous les 12 modules
chargent ce fichier, la couverture est complète.

### 🎨 Fix mobile — Bouton "Rédiger" courriel

**Symptôme** : sur mobile, le bouton "Rédiger" du module Courriel
était partiellement caché par le hamburger (menu ≡ en haut à droite).

**Fix** dans `code_courriel.html` :
- Sur écrans ≤ 900px, le bouton devient un **cercle 44×44** avec
  uniquement l'icône (texte "Rédiger" caché)
- Ajout d'un `margin-right: 60px` pour laisser de la place au
  hamburger (~50px)
- Le titre "Rédiger un courriel" en tooltip si on hover

Sur desktop, le bouton reste comme avant (ovale jaune avec icône + texte).

**Note** : d'autres modules ont des boutons d'action principaux
(`Nouvelle Facture`, `Emprunter un outil`, etc.) qui pourraient aussi
être collés au hamburger sur mobile. Si problème observé, appliquer
la même logique avec span text caché sur mobile.

### 🐛 Fix v2 — Le filtre console ne marchait pas (timing)

**Symptôme** : malgré le filtre ajouté dans `shared.js`, la console
montrait encore 25+ erreurs `Lock broken` et `AbortError`.

**Cause** : `shared.js` se charge **APRÈS** `supabase-js` et
`supabase-config.js`. Quand Supabase commence à acquérir le lock
au démarrage, mon filtre n'est pas encore en place. Du coup les
premières erreurs passent.

**Fix v2** :
1. Le filtre a été déplacé dans un fichier dédié : `assets/shared/console-filter.js`
2. Ce fichier est chargé en **TOUT premier** (avant supabase-js) dans :
   - `index.html` et `login.html`
   - Les 12 modules
3. Le filtre intercepte aussi les `error` events globaux (pas juste
   `unhandledrejection`)
4. Pour les objets Error, on inspecte `message`, `name` ET `stack`
   pour matcher les patterns
5. Service Worker bumpé en v7 pour forcer le rechargement
6. Le bloc redondant retiré de `shared.js`

Ordre de chargement final dans chaque module :
```
1. console-filter.js   ← intercepte tout
2. supabase-js@2       ← le client lourd qui fait des locks
3. supabase-config.js
4. shared.js
5. ...autres
```

### 🐛 Fix 29 avril — Centrage feuille sur mobile

**Symptôme** : sur mobile (≤ 600px en gros), la page (facture,
soumission, feuille de temps) était en pleine taille (816px) et
débordait à droite, non centrée. Sur desktop ça allait.

**Cause** : la fonction `fitToScreen()` calcule le zoom en fonction
de `scrollArea.clientWidth`. Mais sur mobile, quand la fonction est
appelée immédiatement après l'affichage de la vue éditeur
(`viewEditor.style.display = 'flex'`), le navigateur n'a pas encore
fini son rendu → `clientWidth` retourne 0 → la condition
`screenWidth > 0 && screenWidth < pageWidth` est fausse → on garde
`currentZoom = 1.0` → débordement.

Sur desktop, le problème ne se voyait pas parce que même sans zoom,
l'écran fait > 816px donc `currentZoom = 1.0` est correct.

**Fix** : si `clientWidth === 0`, on réessaie au prochain frame avec
`requestAnimationFrame(fitToScreen)`. Une fois le navigateur a fini
le rendu, la fonction calcule correctement le zoom et on appelle
`updateZoom()` qui centre la page (via le `marginLeft` calculé).

Appliqué dans les 3 modules : factures, soumissions, feuilles de temps.

**Service Worker bumpé en v8** pour forcer le rechargement.
