/* =========================================================================
   pdf-export.js — Module shared d'export PDF F.Dussault
   =========================================================================

   Utilisation depuis les modules d'édition (factures/soumissions/feuilles) :

       window.PDFExportFD.openPreview({
           container: document.getElementById('container-invoice'),
           docType: 'facture',                  // 'facture' | 'soumission' | 'feuille'
           docNumber: 'F-0001',                 // ou null
           clientName: 'Tremblay',              // ou null
           date: '2026-04-26',                  // ou null
       });

   Le module ouvre un modal "Aperçu PDF" avec un bouton Télécharger.
   Les bibliothèques (html2canvas + jsPDF) sont chargées à la demande
   depuis un CDN, pour ne pas alourdir le chargement initial des modules.
   ========================================================================= */

(function () {
    'use strict';

    // ----- Config -----
    const HTML2CANVAS_CDN = 'https://cdnjs.cloudflare.com/ajax/libs/html2canvas/1.4.1/html2canvas.min.js';
    const JSPDF_CDN = 'https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js';

    // Dimensions d'une page Letter US à 96 dpi (correspond aux .page CSS)
    const PAGE_WIDTH_PX = 816;
    const PAGE_HEIGHT_PX = 1056;

    let _libsLoading = null;

    // ----- Chargement dynamique des libs -----
    function loadScript(src) {
        return new Promise((resolve, reject) => {
            // Si déjà chargé, ne pas re-télécharger
            if (document.querySelector(`script[src="${src}"]`)) {
                resolve();
                return;
            }
            const s = document.createElement('script');
            s.src = src;
            s.onload = () => resolve();
            s.onerror = () => reject(new Error('Échec chargement : ' + src));
            document.head.appendChild(s);
        });
    }

    async function ensureLibs() {
        if (window.html2canvas && window.jspdf) return;
        if (_libsLoading) return _libsLoading;
        _libsLoading = (async () => {
            await loadScript(HTML2CANVAS_CDN);
            await loadScript(JSPDF_CDN);
        })();
        try {
            await _libsLoading;
        } catch (e) {
            _libsLoading = null;
            throw e;
        }
    }

    // ----- Sanitize filename -----
    function safeName(s) {
        if (!s) return '';
        return String(s)
            .normalize('NFD').replace(/[\u0300-\u036f]/g, '')   // accents
            .replace(/[^a-zA-Z0-9_-]+/g, '_')
            .replace(/^_+|_+$/g, '')
            .substring(0, 40);
    }

    function buildFilename(opts) {
        const parts = [];
        if (opts.docNumber) parts.push(safeName(opts.docNumber));
        else if (opts.docType) {
            const map = { facture: 'Facture', soumission: 'Soumission', feuille: 'Feuille' };
            parts.push(map[opts.docType] || 'Document');
        }
        if (opts.clientName) parts.push(safeName(opts.clientName));
        if (opts.date) parts.push(safeName(opts.date));
        if (parts.length === 0) parts.push('Document');
        return parts.join('_') + '.pdf';
    }

    // ----- Génération du PDF (depuis un container .page-container) -----
    // Retourne { blob, pageImages: [dataURL, ...] }
    async function generatePdfBlob(container) {
        await ensureLibs();
        const { jsPDF } = window.jspdf;

        // Trouver toutes les .page dans le container
        const pages = container.querySelectorAll('.page');
        if (pages.length === 0) {
            throw new Error('Aucune page à exporter.');
        }

        // Format Letter (8.5 x 11 inches = 215.9 x 279.4 mm)
        const pdf = new jsPDF({
            orientation: 'portrait',
            unit: 'mm',
            format: 'letter',
            compress: true
        });
        const pdfW = pdf.internal.pageSize.getWidth();
        const pdfH = pdf.internal.pageSize.getHeight();

        const pageImages = []; // pour l'aperçu mobile

        for (let i = 0; i < pages.length; i++) {
            const page = pages[i];

            // Capturer la page sans tenir compte du zoom CSS appliqué
            // (on rend la page à sa taille naturelle avec scale ratio pour la qualité)
            const canvas = await window.html2canvas(page, {
                scale: 2,                       // 2x pour qualité (≈192 dpi)
                useCORS: true,
                allowTaint: false,
                backgroundColor: '#ffffff',
                width: PAGE_WIDTH_PX,
                height: PAGE_HEIGHT_PX,
                windowWidth: PAGE_WIDTH_PX,
                windowHeight: PAGE_HEIGHT_PX,
                onclone: (clonedDoc) => {
                    // Dans le clone, neutraliser le scale CSS pour capturer en taille réelle
                    const clonedPages = clonedDoc.querySelectorAll('.page');
                    clonedPages.forEach(p => {
                        p.style.transform = 'none';
                        p.style.boxShadow = 'none';
                        p.style.margin = '0';
                    });
                    // Et le container parent aussi (différent selon le module)
                    const containers = clonedDoc.querySelectorAll(
                        '#invoice-container, #quote-container, #zoom-wrapper'
                    );
                    containers.forEach(c => {
                        c.style.transform = 'none';
                        c.style.marginLeft = '0';
                        c.style.marginBottom = '0';
                    });
                    // Rendre les inputs/textarea transparents dans le PDF :
                    // - fond bleu remplacé par transparent
                    // - garder la valeur saisie en noir
                    // - garder la bordure inférieure pour l'effet "ligne à remplir"
                    const fields = clonedDoc.querySelectorAll(
                        'input[type="text"], input[type="number"], input[type="date"], input:not([type]), textarea, select'
                    );
                    fields.forEach(f => {
                        f.style.background = 'transparent';
                        f.style.backgroundColor = 'transparent';
                        f.style.color = '#000';
                        f.style.boxShadow = 'none';
                    });
                }
            });

            const imgData = canvas.toDataURL('image/jpeg', 0.92);
            pageImages.push(imgData);
            if (i > 0) pdf.addPage();
            pdf.addImage(imgData, 'JPEG', 0, 0, pdfW, pdfH, undefined, 'FAST');
        }

        return { blob: pdf.output('blob'), pageImages };
    }

    // ----- Modal aperçu -----
    function injectModalStyles() {
        if (document.getElementById('pdf-export-fd-styles')) return;
        const css = `
            .pdfx-overlay {
                position: fixed; inset: 0;
                background: rgba(0,0,0,0.75);
                z-index: 99998;
                display: flex; flex-direction: column;
                animation: pdfxFade 0.2s ease;
            }
            @keyframes pdfxFade { from { opacity: 0; } to { opacity: 1; } }
            .pdfx-header {
                background: var(--card-bg, #2b2c36);
                color: var(--text-light, #e0e0e0);
                padding: 14px 20px;
                display: flex; justify-content: space-between; align-items: center;
                border-bottom: 1px solid var(--border-color, #444);
            }
            .pdfx-title { font-size: 16px; font-weight: bold; }
            .pdfx-close {
                background: transparent; border: none; color: var(--text-light, #e0e0e0);
                font-size: 24px; cursor: pointer; padding: 0 8px; line-height: 1;
            }
            .pdfx-close:hover { color: var(--btn-red, #ff4d4d); }
            .pdfx-body {
                flex: 1;
                background: #525659;
                display: flex; align-items: flex-start; justify-content: center;
                overflow: auto;
                padding: 20px;
                -webkit-overflow-scrolling: touch;
            }
            .pdfx-body iframe {
                width: 100%; height: 100%; border: none; background: white;
                box-shadow: 0 4px 16px rgba(0,0,0,0.5);
            }
            /* Aperçu : images des pages (mobile-friendly contrairement à <iframe> PDF) */
            .pdfx-pages {
                display: flex;
                flex-direction: column;
                align-items: center;
                gap: 16px;
                width: 100%;
                max-width: 900px;
            }
            .pdfx-page {
                display: block;
                width: 100%;
                height: auto;
                background: white;
                box-shadow: 0 4px 16px rgba(0,0,0,0.5);
                border-radius: 2px;
            }
            .pdfx-loading {
                color: white; font-size: 18px;
                display: flex; flex-direction: column; align-items: center; gap: 16px;
            }
            .pdfx-spinner {
                width: 50px; height: 50px;
                border: 4px solid rgba(255,255,255,0.2);
                border-top-color: var(--btn-yellow, #fcca46);
                border-radius: 50%;
                animation: pdfxSpin 0.8s linear infinite;
            }
            @keyframes pdfxSpin { to { transform: rotate(360deg); } }
            .pdfx-footer {
                background: var(--card-bg, #2b2c36);
                color: var(--text-light, #e0e0e0);
                padding: 14px 20px;
                display: flex; justify-content: flex-end; gap: 10px;
                border-top: 1px solid var(--border-color, #444);
                flex-wrap: wrap;
            }
            .pdfx-btn {
                padding: 10px 20px;
                border-radius: 6px;
                border: none;
                font-weight: bold;
                font-size: 14px;
                cursor: pointer;
                display: inline-flex; align-items: center; gap: 8px;
                transition: 0.15s;
            }
            .pdfx-btn:disabled { opacity: 0.5; cursor: not-allowed; }
            .pdfx-btn-secondary {
                background: var(--btn-grey, #343a40); color: white;
            }
            .pdfx-btn-secondary:hover:not(:disabled) { background: #4a5057; }
            .pdfx-btn-primary {
                background: var(--btn-yellow, #fcca46); color: black;
            }
            .pdfx-btn-primary:hover:not(:disabled) { background: var(--btn-yellow-hover, #ffd66b); }
            .pdfx-error {
                color: #ffb3b3; font-size: 15px; padding: 20px; text-align: center;
                max-width: 500px;
            }
            @media (max-width: 600px) {
                .pdfx-body { padding: 8px; }
                .pdfx-footer { flex-direction: column-reverse; }
                .pdfx-btn { width: 100%; justify-content: center; }
            }
        `;
        const style = document.createElement('style');
        style.id = 'pdf-export-fd-styles';
        style.textContent = css;
        document.head.appendChild(style);
    }

    function buildModal(filename) {
        injectModalStyles();
        const overlay = document.createElement('div');
        overlay.className = 'pdfx-overlay';
        overlay.innerHTML = `
            <div class="pdfx-header">
                <span class="pdfx-title">Aperçu PDF</span>
                <button class="pdfx-close" data-pdfx-action="close" aria-label="Fermer">×</button>
            </div>
            <div class="pdfx-body">
                <div class="pdfx-loading">
                    <div class="pdfx-spinner"></div>
                    <div>Génération du PDF en cours…</div>
                </div>
            </div>
            <div class="pdfx-footer">
                <button class="pdfx-btn pdfx-btn-secondary" data-pdfx-action="close">Fermer</button>
                <button class="pdfx-btn pdfx-btn-primary" data-pdfx-action="download" disabled>
                    <span>⬇</span> Télécharger ${filename ? '(' + filename + ')' : ''}
                </button>
            </div>
        `;
        document.body.appendChild(overlay);

        function close() {
            // Libérer l'URL blob si présente
            if (overlay._blobUrl) {
                URL.revokeObjectURL(overlay._blobUrl);
                overlay._blobUrl = null;
            }
            // Aussi vérifier les anciens iframes (compat)
            const iframe = overlay.querySelector('iframe');
            if (iframe && iframe.src && iframe.src.startsWith('blob:')) {
                URL.revokeObjectURL(iframe.src);
            }
            overlay.remove();
        }

        overlay.addEventListener('click', (e) => {
            const action = e.target.closest('[data-pdfx-action]')?.dataset.pdfxAction;
            if (action === 'close') close();
        });
        // Échap pour fermer
        const escHandler = (e) => {
            if (e.key === 'Escape') {
                close();
                document.removeEventListener('keydown', escHandler);
            }
        };
        document.addEventListener('keydown', escHandler);

        return {
            overlay,
            setError(msg) {
                overlay.querySelector('.pdfx-body').innerHTML =
                    `<div class="pdfx-error">⚠ ${msg}</div>`;
            },
            setPdfBlob(blob, pageImages, downloadFilename) {
                const url = URL.createObjectURL(blob);
                // Aperçu : utiliser des <img> (au lieu d'un <iframe> PDF) pour que
                // le rendu fonctionne correctement sur mobile (Safari iOS notamment,
                // où les iframes PDF s'affichent à taille fixe et ne se redimensionnent pas).
                const imgsHtml = pageImages.map((src, i) =>
                    `<img class="pdfx-page" src="${src}" alt="Page ${i + 1}" />`
                ).join('');
                overlay.querySelector('.pdfx-body').innerHTML =
                    `<div class="pdfx-pages">${imgsHtml}</div>`;
                const dlBtn = overlay.querySelector('[data-pdfx-action="download"]');
                dlBtn.disabled = false;
                dlBtn.onclick = () => {
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = downloadFilename;
                    document.body.appendChild(a);
                    a.click();
                    a.remove();
                };
                // Stocker l'URL pour révocation à la fermeture
                overlay._blobUrl = url;
            },
            close
        };
    }

    // ----- API publique -----
    async function openPreview(opts) {
        if (!opts || !opts.container) {
            console.error('[PDFExportFD] opts.container requis');
            return;
        }

        const filename = buildFilename(opts);
        const modal = buildModal(filename);

        try {
            const { blob, pageImages } = await generatePdfBlob(opts.container);
            modal.setPdfBlob(blob, pageImages, filename);
        } catch (e) {
            console.error('[PDFExportFD] Erreur génération PDF :', e);
            modal.setError(
                'Impossible de générer le PDF. ' +
                (e && e.message ? '<br><small>' + e.message + '</small>' : '')
            );
            if (typeof window.showToast === 'function') {
                window.showToast('Erreur de génération du PDF', 'error');
            }
        }
    }

    window.PDFExportFD = {
        openPreview,
        // Exposé pour debug / cas avancés
        _generateBlob: generatePdfBlob,
        _buildFilename: buildFilename
    };
})();
