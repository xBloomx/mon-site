# F.Dussault — Corrections de sécurité et qualité

Document récapitulant les changements appliqués lors du chantier "priorités".

---

## 🔐 Côté Supabase (déjà appliqué via SQL)

### Sécurité — RLS complet
- RLS activé sur les 14 tables (avant : `profils` et `logs_systeme` n'en avaient pas)
- 55 policies créées suivant la hiérarchie A0/A1/A2/A3
- Colonne `mot_de_passe_clair` supprimée de la table `profils`

### Système de permissions flexible
3 fonctions PostgreSQL créées :
- `current_user_role()` — retourne le rôle de l'utilisateur
- `is_admin()` — vérifie si A0
- `user_has_permission(perm)` — lit la config dans `parametres_globaux.roles_config`

→ Pour ajouter un rôle A4 plus tard, il suffit de mettre à jour la clé `roles_config` dans `parametres_globaux`. **Aucune policy à modifier.**

### Trigger anti-promotion
Empêche un utilisateur de modifier son propre `role` (sécurité critique).

---

## 💻 Côté code (changements dans ce zip)

### 1. Viewports (14 fichiers)
**Avant :** `maximum-scale=1.0, user-scalable=no` (problème d'accessibilité)
**Après :** `viewport-fit=cover` — zoom à nouveau possible

### 2. Service Worker (`sw.js`)
**Avant :** ne cachait aucun module HTML → app inutilisable hors ligne
**Après :** cache tous les modules + stratégie cache-first pour images / network-first pour le reste

### 3. Manifest (`manifest.json`)
**Avant :** une seule image déclarée pour 192×192 ET 512×512 + `purpose: "any maskable"` problématique
**Après :** `purpose: "any"` + ajout de **shortcuts PWA** (long-press sur l'icône Android = accès rapide à Facture / Temps / Messagerie)

### 4. Fichiers partagés (`assets/shared/`)
- `shared.css` — variables CSS communes, toast styling, fix font-size 16px sur inputs mobile
- `shared.js` — système de toast/snackbar, `handleSupabaseError()`, `guardIframe()`

### 5. `index.html` mis à jour
- Charge `shared.css` et `shared.js`
- Setup du toast listener global (les iframes peuvent envoyer un `postMessage` pour afficher un toast)
- Permission `delete_documents` ajoutée à A1 et A2 (cohérence avec policies SQL)

---

## 🎨 Comment utiliser le système de toast

Dans n'importe quel module ou dans index.html :

```javascript
window.showToast('Facture sauvegardée', 'success');
window.showToast('Erreur réseau', 'error');
window.showToast('Attention', 'warning');
window.showToast('Info utile', 'info');
```

Pour utiliser depuis un iframe, il faut d'abord charger `shared.js` :

```html
<script src="../assets/shared/shared.js"></script>
```

Puis tu peux utiliser `window.showToast(...)` qui enverra automatiquement le toast au parent pour qu'il s'affiche par-dessus toute l'app.

---

## 🛠️ Comment gérer les erreurs Supabase proprement

Au lieu de :
```javascript
const { data, error } = await supabaseClient.from('factures').select('*');
if (error) { console.error(error); return; }
```

Utilise :
```javascript
const { data, error } = await supabaseClient.from('factures').select('*');
if (error) {
    window.SharedFD.handleSupabaseError(error, 'chargement factures');
    return;
}
```

`handleSupabaseError()` reconnaît automatiquement :
- Erreurs RLS (permission refusée) → "Tu n'as pas la permission..."
- JWT expiré → "Session expirée" + redirige vers login
- Erreurs réseau → "Problème de connexion réseau"

Et affiche un toast clair pour l'utilisateur au lieu d'un silence.

---

## ⚠️ Points à vérifier après déploiement

1. **Sur mobile**, vérifier que les inputs ne déclenchent plus le zoom auto sur iOS
2. **PWA** : désinstaller et réinstaller l'app pour que le nouveau manifest et le service worker v3 soient pris en compte
3. **Hors-ligne** : tester en activant le mode avion → l'app devrait charger les modules cachés

---

## 📋 Ce qui reste à faire (chantiers suivants)

Voir le diagnostic initial pour la liste complète. En résumé :
- Compresser les images (logo_calendrier.png fait 1 Mo, ridicule)
- Mutualiser le code dupliqué entre les 12 modules
- Migration progressive vers une vraie SPA (long terme)
- Ajout de fonctionnalités métier (signature, export PDF, géolocalisation, etc.)
