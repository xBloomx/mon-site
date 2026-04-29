# 📄 Changelog — Chantier 5 (Export PDF)

**Date :** 26 avril 2026

## En une phrase

Les 3 modules (factures, soumissions, feuilles de temps) ont maintenant un
vrai **export PDF avec aperçu et bouton Télécharger**, qui marche
indépendamment des paramètres d'impression du navigateur. Le nom de
fichier est intelligent : `F-0001_Tremblay_2026-04-26.pdf`.

---

## ⚠️ AVANT D'UTILISER : aucune action requise côté DB

Pas de SQL à exécuter. Tout est côté code.

**Mais comme on a bumpé le Service Worker v4 → v5**, les utilisateurs
devront recharger l'app une fois pour que les nouveaux fichiers soient
mis en cache.

---

## 🎯 Ce qui change

### Pour les utilisateurs
- Le bouton "Imprimer" devient **"PDF / Imprimer"** dans les 3 modules
- Quand on clique : un **modal d'aperçu** s'ouvre avec le PDF généré
- Bouton **Télécharger** dans le modal → télécharge directement le PDF
- Plus de dépendance au menu d'impression du navigateur (qui était
  inconsistant entre Chrome / Safari / mobile)
- Le fichier est nommé intelligemment :
  - Facture : `F-0001_Tremblay_2026-04-26.pdf`
  - Soumission : `S-0042_Lacasse_2026-04-26.pdf` (selon le numéro saisi)
  - Feuille de temps : `TS-1714123456_Jean-Bouclin_2026-04-22.pdf`

### Pour toi (maintenance)
- Toute la logique PDF est dans **un seul fichier** :
  `assets/shared/pdf-export.js`
- Les 3 modules appellent simplement `window.PDFExportFD.openPreview({...})`
  avec leurs infos
- Si tu veux changer le format de nom, le style du modal, la qualité du
  PDF, etc. → tout est centralisé

---

## 📦 Fichiers modifiés

### Nouveaux fichiers
- `assets/shared/pdf-export.js` — module partagé d'export PDF (~250 lignes)

### Modifiés
- `code_facture/code_facture.html` :
  - Charge `pdf-export.js` dans le `<head>`
  - Fonction `exporterPDF()` réécrite pour utiliser `PDFExportFD.openPreview`
- `code_soumissions/code_soumissions.html` :
  - Charge `pdf-export.js`
  - Bouton `window.print()` → `exporterPDF()` (label "PDF / Imprimer")
  - Nouvelle fonction `exporterPDF()`
- `code_feuille_de_temps/code_feuille_de_temps.html` :
  - Idem soumissions
  - Pour les feuilles de temps, le "client" du nom de fichier = nom de
    l'employé, et la "date" = semaine du
- `sw.js` :
  - Bump v4 → v5
  - Ajout de `pdf-export.js` au cache

---

## 🛠 Détails techniques

### Bibliothèques utilisées
- **html2canvas** 1.4.1 — capture chaque `.page` en image
- **jsPDF** 2.5.1 — assemble les images en PDF Letter

Les deux libs sont chargées **à la demande** depuis un CDN
(cdnjs.cloudflare.com), pas au chargement initial. Donc :
- Premier export = ~200 Ko téléchargés en arrière-plan (1-2 secondes)
- Exports suivants = instantané (cache navigateur + cache module)

### Format du PDF
- **Letter US** (8.5 × 11 pouces) — adapté au format des `.page` (816 ×
  1056 px = format Letter à 96 dpi)
- **Multi-pages** : chaque `.page` du DOM devient une page PDF
- **Qualité** : capture en 2× (≈192 dpi) puis JPEG qualité 92%
- **Compression PDF** activée

### Modal d'aperçu
- Overlay sombre plein écran
- Header : titre + bouton fermer (×)
- Body : iframe avec PDF (toolbar PDF cachée pour épure)
- Footer : Fermer + Télécharger (avec le nom de fichier visible)
- Échap pour fermer
- Responsive (boutons en colonne sur mobile)

### Sécurité du nom de fichier
La fonction `safeName()` dans pdf-export.js :
- Retire les accents (NFD + suppression diacritiques)
- Remplace les caractères non-`[a-zA-Z0-9_-]` par `_`
- Tronque à 40 caractères max par segment
- Garantit un nom de fichier valide sur Windows / macOS / Linux

---

## ✅ Comment tester (5 min)

### Test 1 — Export d'une facture
1. Ouvre une facture (nouvelle ou existante)
2. Remplis au minimum : nom client (premier input top section), date
3. Clique le bouton **"PDF / Imprimer"**
4. Modal s'ouvre, affiche un spinner pendant 2-3 secondes
5. Le PDF apparaît dans l'iframe
6. Bouton **Télécharger (F-XXXX_Client_Date.pdf)** activé
7. Clique → le PDF se télécharge avec le bon nom

### Test 2 — Export multi-pages
1. Ouvre une facture, clique 2 fois sur "Page" pour avoir 3 pages
2. Remplis quelques inputs sur chaque page
3. PDF / Imprimer → vérifie que **les 3 pages** sont dans le PDF généré

### Test 3 — Soumission et feuille de temps
1. Idem sur les 2 autres modules
2. Vérifier les noms de fichiers :
   - Soumission : `S-XXXX_Client_Date.pdf` (ou `Soumission_...` si pas de no)
   - Feuille temps : `TS-...._Nom-Employe_Semaine.pdf`

### Test 4 — Pas de connexion réseau
1. Désactive le wifi temporairement
2. Tente un export PDF
3. **Premier essai** : erreur dans le modal "Impossible de générer le PDF"
   (les libs CDN ne peuvent pas se charger)
4. **Si tu as déjà fait un export AVANT de couper la connexion** : ça
   marche, les libs sont en cache navigateur

### Test 5 — Échap ferme le modal
1. Ouvre le PDF d'aperçu
2. Appuie sur Échap → le modal se ferme

### Test 6 — Document archivé
1. Connecte-toi en A0, va dans Archives
2. Ouvre une facture archivée
3. Bouton "PDF / Imprimer" devrait être **caché** (parce qu'archive.js
   masque les `.action-btn` sur les docs archivés)
4. ✅ Si tu peux quand même exporter : tant mieux, mais à voir si on
   veut explicitement permettre ou bloquer

---

## 🚀 Si tu veux modifier plus tard

### Changer la qualité / poids du PDF
Dans `assets/shared/pdf-export.js`, ligne `scale: 2` :
- `scale: 1` → PDF plus léger, qualité moindre (~96 dpi)
- `scale: 3` → qualité top mais 3× plus gros

Et `pdf.addImage(imgData, 'JPEG', ..., 0.92)` :
- Le `0.92` est la qualité JPEG (0 à 1). Baisser à 0.85 pour PDF plus léger.

### Changer le format du nom de fichier
Dans `pdf-export.js`, fonction `buildFilename(opts)`. Tout est là.

### Ajouter l'export à un autre module (PO, etc.)
1. Dans le HTML : ajoute `<script src="../assets/shared/pdf-export.js"></script>`
2. Dans le bouton : `onclick="exporterPDF()"`
3. Dans le JS du module :
```js
function exporterPDF() {
    const container = document.getElementById('mon-container');
    window.PDFExportFD.openPreview({
        container: container,
        docType: 'po',
        docNumber: 'PO-001',
        clientName: 'Truc',
        date: '2026-04-26'
    });
}
```

### Ajouter un bouton "Imprimer" en plus de Télécharger
Dans `pdf-export.js`, fonction `buildModal()`, dans le footer :
```html
<button class="pdfx-btn pdfx-btn-secondary" data-pdfx-action="print">Imprimer</button>
```
Puis gérer `action === 'print'` qui appelle `iframe.contentWindow.print()`.

---

## ⚠️ Limitations connues

1. **Capture des inputs sans border** : html2canvas peut ne pas rendre
   parfaitement certains styles CSS complexes (ex: `transform`,
   `box-shadow` très flous, certains pseudo-éléments). Si tu vois un
   rendu bizarre, dis-moi quel élément.

2. **Polices** : si une police custom est utilisée et qu'elle vient d'un
   CDN, html2canvas peut ne pas attendre son chargement. Pour
   F.Dussault, on utilise Segoe UI / Arial qui sont locales → no problem.

3. **Performance sur grosses factures** : un PDF de 5+ pages peut
   prendre 5-10 secondes à générer sur mobile. Le spinner reste affiché
   pendant ce temps.

4. **Mode hors-ligne** : le **premier** export en mode hors-ligne échoue
   parce que les libs CDN doivent être téléchargées. Une fois en cache
   navigateur, ça marche offline. Pour vraiment marcher offline dès le
   premier coup, il faudrait inclure html2canvas et jsPDF en local
   (~250 Ko de plus dans le projet) — pas fait pour l'instant.
