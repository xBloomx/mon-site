/* =========================================================================
   signature.js — Module shared de signature électronique F.Dussault
   =========================================================================

   Améliorations vs l'ancien système :
   - Trait lisse (courbes quadratiques + lissage de pression sur tablette)
   - Bouton "Effacer" dans le modal pour recommencer sans fermer
   - Annuler restaure vraiment la signature précédente
   - Plein écran sur mobile pour grand espace de signature
   - Vibration tactile au début du tracé (mobile)
   - Indicateur visuel "Signé ✓" sur les zones signées
   - Aperçu agrandi quand tu cliques sur une signature déjà présente

   Utilisation depuis les modules d'édition :
       window.SignatureFD.attach(document.getElementById('sig-id'));
   ou pour l'attacher à toutes les .display-sig d'un container :
       window.SignatureFD.attachAll(container);

   Le module crée AUTOMATIQUEMENT son modal global au premier appel.
   Plus besoin de #sig-modal dans le HTML des modules.
   ========================================================================= */

(function () {
    'use strict';

    let _modal = null;
    let _canvas = null;
    let _ctx = null;
    let _currentTargetImg = null;
    let _previousValue = null;
    let _isDrawing = false;
    let _lastPoint = null;
    let _hasDrawn = false;

    // ----- Styles injectés une seule fois -----
    function injectStyles() {
        if (document.getElementById('signature-fd-styles')) return;
        const css = `
            #sig-fd-modal {
                display: none;
                position: fixed;
                inset: 0;
                background: rgba(0,0,0,0.92);
                z-index: 9999;
                justify-content: center;
                align-items: center;
                flex-direction: column;
                padding: 20px;
                box-sizing: border-box;
            }
            #sig-fd-modal.show { display: flex; animation: sigFdFade 0.2s ease; }
            @keyframes sigFdFade { from { opacity: 0; } to { opacity: 1; } }
            #sig-fd-modal .sig-fd-title {
                color: var(--btn-yellow, #fcca46);
                font-size: 18px;
                font-weight: bold;
                margin-bottom: 12px;
                text-align: center;
            }
            #sig-fd-modal .sig-fd-canvas-wrap {
                width: 100%;
                max-width: 700px;
                background: white;
                border-radius: 8px;
                position: relative;
                box-shadow: 0 8px 24px rgba(0,0,0,0.5);
            }
            #sig-fd-canvas {
                width: 100%;
                height: 350px;
                touch-action: none;
                display: block;
                cursor: crosshair;
                border-radius: 8px;
            }
            #sig-fd-modal .sig-fd-hint {
                position: absolute;
                top: 50%; left: 50%;
                transform: translate(-50%, -50%);
                color: #aaa;
                font-style: italic;
                font-size: 16px;
                pointer-events: none;
                user-select: none;
                transition: opacity 0.2s;
            }
            #sig-fd-modal .sig-fd-hint.hidden { opacity: 0; }
            #sig-fd-modal .sig-fd-actions {
                display: flex;
                gap: 10px;
                margin-top: 16px;
                width: 100%;
                max-width: 700px;
                flex-wrap: wrap;
            }
            #sig-fd-modal .sig-fd-btn {
                flex: 1;
                min-width: 100px;
                padding: 14px 20px;
                border-radius: 6px;
                border: none;
                font-weight: bold;
                font-size: 15px;
                cursor: pointer;
                display: inline-flex;
                align-items: center;
                justify-content: center;
                gap: 8px;
                transition: 0.15s;
            }
            #sig-fd-modal .sig-fd-btn:active { transform: scale(0.97); }
            #sig-fd-modal .sig-fd-btn-clear {
                background: var(--btn-grey, #343a40);
                color: white;
            }
            #sig-fd-modal .sig-fd-btn-clear:hover { background: #4a5057; }
            #sig-fd-modal .sig-fd-btn-cancel {
                background: var(--btn-red, #ff4d4d);
                color: white;
            }
            #sig-fd-modal .sig-fd-btn-cancel:hover { background: #ff6666; }
            #sig-fd-modal .sig-fd-btn-ok {
                background: var(--btn-green, #28a745);
                color: white;
            }
            #sig-fd-modal .sig-fd-btn-ok:hover { background: #2cbb50; }
            #sig-fd-modal .sig-fd-btn-ok:disabled {
                background: #555;
                cursor: not-allowed;
            }

            /* Plein écran sur mobile pour grand espace de signature */
            @media (max-width: 768px) {
                #sig-fd-modal { padding: 10px; }
                /* En portrait : canvas grand (mais en portrait l'overlay rotation s'affiche) */
                #sig-fd-canvas { height: 60vh; min-height: 250px; }
                #sig-fd-modal .sig-fd-actions { flex-direction: column; }
                #sig-fd-modal .sig-fd-btn { width: 100%; padding: 16px; }
            }
            /* En paysage sur mobile : canvas plus petit pour laisser de la place
               aux boutons "Effacer / Annuler / Valider" qui sont visibles en bas */
            @media (max-width: 932px) and (orientation: landscape) {
                #sig-fd-modal { padding: 8px; gap: 8px; }
                #sig-fd-modal .sig-fd-title { font-size: 14px; margin-bottom: 4px; }
                #sig-fd-canvas { height: calc(100vh - 130px); min-height: 150px; max-height: 70vh; }
                #sig-fd-modal .sig-fd-actions { flex-direction: row; margin-top: 8px; flex-wrap: nowrap; }
                #sig-fd-modal .sig-fd-btn { padding: 10px 14px; font-size: 13px; min-width: 0; }
            }

            /* Safe-area pour téléphones avec encoche/Dynamic Island */
            #sig-fd-modal {
                padding-top: calc(20px + env(safe-area-inset-top, 0px));
                padding-bottom: calc(20px + env(safe-area-inset-bottom, 0px));
                padding-left: calc(20px + env(safe-area-inset-left, 0px));
                padding-right: calc(20px + env(safe-area-inset-right, 0px));
            }
            @media (max-width: 768px) {
                #sig-fd-modal {
                    padding-top: calc(10px + env(safe-area-inset-top, 0px));
                    padding-bottom: calc(10px + env(safe-area-inset-bottom, 0px));
                    padding-left: calc(10px + env(safe-area-inset-left, 0px));
                    padding-right: calc(10px + env(safe-area-inset-right, 0px));
                }
            }

            /* Overlay "Tournez votre téléphone" en mode portrait sur mobile */
            #sig-fd-rotate-hint {
                display: none;
                position: fixed;
                inset: 0;
                background: rgba(0,0,0,0.95);
                z-index: 10000;
                color: white;
                text-align: center;
                flex-direction: column;
                justify-content: center;
                align-items: center;
                padding: 30px;
                box-sizing: border-box;
            }
            #sig-fd-rotate-hint.show { display: flex; animation: sigFdFade 0.2s ease; }
            #sig-fd-rotate-hint .rotate-icon {
                width: 80px; height: 80px;
                margin-bottom: 25px;
                animation: sigFdRotate 1.8s ease-in-out infinite;
                color: var(--btn-yellow, #fcca46);
            }
            #sig-fd-rotate-hint h2 {
                margin: 0 0 12px 0;
                font-size: 22px;
                font-weight: bold;
            }
            #sig-fd-rotate-hint p {
                margin: 0;
                font-size: 15px;
                color: #bbb;
                line-height: 1.5;
                max-width: 320px;
            }
            @keyframes sigFdRotate {
                0%, 100% { transform: rotate(0deg); }
                40%, 60% { transform: rotate(90deg); }
            }

            /* Indicateur "Signé" sur les zones .display-sig */
            .display-sig.has-signature {
                position: relative;
            }
            .display-sig.has-signature::after {
                content: "✓";
                position: absolute;
                top: 2px; right: 4px;
                color: var(--btn-green, #28a745);
                font-size: 14px;
                font-weight: bold;
                background: white;
                border-radius: 50%;
                width: 18px; height: 18px;
                display: flex; align-items: center; justify-content: center;
                box-shadow: 0 1px 3px rgba(0,0,0,0.3);
                pointer-events: none;
            }
            /* Petit fix : <img> ne supporte pas ::after, on wrap en CSS */
            .sig-box.has-signature {
                position: relative;
            }
            .sig-box.has-signature::before {
                content: "✓ Signé";
                position: absolute;
                top: 2px; right: 4px;
                color: var(--btn-green, #28a745);
                font-size: 11px;
                font-weight: bold;
                background: white;
                padding: 2px 6px;
                border-radius: 10px;
                box-shadow: 0 1px 3px rgba(0,0,0,0.2);
                z-index: 2;
                pointer-events: none;
            }
        `;
        const style = document.createElement('style');
        style.id = 'signature-fd-styles';
        style.textContent = css;
        document.head.appendChild(style);
    }

    // ----- Modal créé une seule fois (singleton) -----
    function createModal() {
        if (_modal) return;
        injectStyles();

        _modal = document.createElement('div');
        _modal.id = 'sig-fd-modal';
        _modal.innerHTML = `
            <div class="sig-fd-title" id="sig-fd-title">Signez dans la zone ci-dessous</div>
            <div class="sig-fd-canvas-wrap">
                <canvas id="sig-fd-canvas"></canvas>
                <div class="sig-fd-hint" id="sig-fd-hint">Signez ici avec votre doigt ou la souris</div>
            </div>
            <div class="sig-fd-actions">
                <button class="sig-fd-btn sig-fd-btn-clear" data-action="clear">
                    <span>↺</span> Effacer
                </button>
                <button class="sig-fd-btn sig-fd-btn-cancel" data-action="cancel">
                    Annuler
                </button>
                <button class="sig-fd-btn sig-fd-btn-ok" data-action="ok" disabled>
                    <span>✓</span> Valider
                </button>
            </div>
        `;
        document.body.appendChild(_modal);

        // Overlay "Tournez votre téléphone" (apparaît si mode signature + portrait + mobile)
        const rotateHint = document.createElement('div');
        rotateHint.id = 'sig-fd-rotate-hint';
        rotateHint.innerHTML = `
            <svg class="rotate-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                <rect x="5" y="2" width="14" height="20" rx="2" ry="2"></rect>
                <line x1="12" y1="18" x2="12.01" y2="18"></line>
            </svg>
            <h2>Tournez votre téléphone</h2>
            <p>Pour signer plus confortablement, mettez votre téléphone à l'horizontale.</p>
        `;
        document.body.appendChild(rotateHint);

        _canvas = _modal.querySelector('#sig-fd-canvas');
        _ctx = _canvas.getContext('2d');

        // Boutons
        _modal.addEventListener('click', (e) => {
            const action = e.target.closest('[data-action]')?.dataset.action;
            if (action === 'clear') clearCanvas();
            else if (action === 'cancel') cancelSignature();
            else if (action === 'ok') saveSignature();
        });

        // Échap pour annuler
        document.addEventListener('keydown', (e) => {
            if (_modal.classList.contains('show') && e.key === 'Escape') {
                cancelSignature();
            }
        });

        // Dessin
        _canvas.addEventListener('mousedown', startDrawing);
        _canvas.addEventListener('mousemove', moveDrawing);
        window.addEventListener('mouseup', endDrawing);
        _canvas.addEventListener('mouseleave', endDrawing);

        _canvas.addEventListener('touchstart', startDrawing, { passive: false });
        _canvas.addEventListener('touchmove', moveDrawing, { passive: false });
        _canvas.addEventListener('touchend', endDrawing);
        _canvas.addEventListener('touchcancel', endDrawing);

        // Resize quand la fenêtre change (rotation mobile)
        window.addEventListener('resize', () => {
            if (_modal.classList.contains('show')) {
                // Préserver le contenu actuel pendant le resize
                const current = _hasDrawn ? _canvas.toDataURL() : null;
                resizeCanvas();
                if (current) {
                    const img = new Image();
                    img.onload = () => {
                        _ctx.drawImage(img, 0, 0, _canvas.clientWidth, _canvas.clientHeight);
                    };
                    img.src = current;
                }
                // Mettre à jour l'overlay rotation à chaque changement d'orientation
                updateRotationHint();
            }
        });

        // Aussi sur orientationchange (plus fiable sur certains mobiles)
        window.addEventListener('orientationchange', () => {
            if (_modal.classList.contains('show')) {
                setTimeout(updateRotationHint, 100);
            }
        });
    }

    // ----- Affichage de l'overlay "Tournez votre téléphone" -----
    // Apparaît seulement sur mobile en mode portrait pendant la signature
    function updateRotationHint(forceShow) {
        const hint = document.getElementById('sig-fd-rotate-hint');
        if (!hint) return;

        // Pas de modal actif (sauf si forceShow) → masquer
        if (!forceShow && (!_modal || !_modal.classList.contains('show'))) {
            hint.classList.remove('show');
            return;
        }

        // Détection mobile (largeur viewport < 900px = mobile/petite tablette)
        const isMobile = window.innerWidth < 900 || window.matchMedia('(pointer: coarse)').matches;
        // Mode portrait : hauteur > largeur
        const isPortrait = window.innerHeight > window.innerWidth;

        if (isMobile && isPortrait) {
            hint.classList.add('show');
        } else {
            hint.classList.remove('show');
        }
    }

    // ----- Resize / setup canvas haute résolution -----
    function resizeCanvas() {
        const ratio = Math.max(window.devicePixelRatio || 1, 1);
        const w = _canvas.clientWidth;
        const h = _canvas.clientHeight;
        _canvas.width = w * ratio;
        _canvas.height = h * ratio;
        _ctx.scale(ratio, ratio);
        _ctx.lineWidth = 2.5;
        _ctx.lineCap = 'round';
        _ctx.lineJoin = 'round';
        _ctx.strokeStyle = '#000';
        // Antialiasing maximal
        _ctx.imageSmoothingEnabled = true;
        _ctx.imageSmoothingQuality = 'high';
    }

    function clearCanvas() {
        _ctx.clearRect(0, 0, _canvas.width, _canvas.height);
        _hasDrawn = false;
        updateHint();
        updateOkButton();
    }

    function updateHint() {
        const hint = document.getElementById('sig-fd-hint');
        if (hint) hint.classList.toggle('hidden', _hasDrawn);
    }

    function updateOkButton() {
        const btn = _modal.querySelector('[data-action="ok"]');
        if (btn) btn.disabled = !_hasDrawn;
    }

    // ----- Position du curseur/doigt -----
    function getPos(e) {
        const rect = _canvas.getBoundingClientRect();
        if (e.touches && e.touches[0]) {
            return {
                x: e.touches[0].clientX - rect.left,
                y: e.touches[0].clientY - rect.top
            };
        }
        return {
            x: e.clientX - rect.left,
            y: e.clientY - rect.top
        };
    }

    // ----- Dessin -----
    function startDrawing(e) {
        e.preventDefault();
        _isDrawing = true;
        _lastPoint = getPos(e);
        _ctx.beginPath();
        _ctx.moveTo(_lastPoint.x, _lastPoint.y);
        _ctx.lineTo(_lastPoint.x + 0.1, _lastPoint.y); // Petit point de départ visible
        _ctx.stroke();

        // Vibration tactile sur mobile (très courte, 10ms)
        if (e.type === 'touchstart' && navigator.vibrate) {
            try { navigator.vibrate(10); } catch (_) {}
        }
    }

    function moveDrawing(e) {
        if (!_isDrawing) return;
        e.preventDefault();
        const p = getPos(e);

        // Trait lissé : courbe quadratique entre le dernier point et le nouveau
        // via un point de contrôle au milieu — donne un trait beaucoup plus naturel
        const midX = (_lastPoint.x + p.x) / 2;
        const midY = (_lastPoint.y + p.y) / 2;
        _ctx.quadraticCurveTo(_lastPoint.x, _lastPoint.y, midX, midY);
        _ctx.stroke();

        _lastPoint = p;
        _hasDrawn = true;
        updateHint();
        updateOkButton();
    }

    function endDrawing() {
        if (!_isDrawing) return;
        _isDrawing = false;
        // Finir le tracé proprement au dernier point
        if (_lastPoint) {
            _ctx.lineTo(_lastPoint.x, _lastPoint.y);
            _ctx.stroke();
        }
        _ctx.beginPath();
    }

    // ----- Ouvrir le modal pour signer -----
    function openFor(targetImg) {
        createModal();
        _currentTargetImg = targetImg;
        _previousValue = targetImg.src && targetImg.src !== '' && !targetImg.src.endsWith('/') ? targetImg.src : null;

        // Adapter le titre selon le contexte (signature plombier vs client)
        const title = document.getElementById('sig-fd-title');
        if (title) {
            const sigText = targetImg.parentElement?.querySelector('.sig-text');
            if (sigText && sigText.textContent.trim()) {
                title.textContent = sigText.textContent.trim();
            } else {
                title.textContent = 'Signez dans la zone ci-dessous';
            }
        }

        _modal.classList.add('show');
        // Notifier le parent (index.html) qu'on entre en mode signature plein écran
        try {
            if (window.parent && window.parent !== window) {
                console.log('[SignatureFD] Envoi signature_mode: enter au parent');
                window.parent.postMessage({ type: 'signature_mode', action: 'enter' }, '*');
            } else {
                console.warn('[SignatureFD] Pas de window.parent — postMessage non envoyé');
            }
        } catch (e) { console.error('[SignatureFD] Erreur postMessage:', e); }
        // Vérifier l'orientation tout de suite (forceShow=true car classList.add('show')
        // peut ne pas être encore visible dans une vérification immédiate)
        updateRotationHint(true);

        // Important : laisser le DOM se rendre avant de calculer la taille
        setTimeout(() => {
            resizeCanvas();
            // Si signature précédente, la pré-charger pour modification
            if (_previousValue) {
                const img = new Image();
                img.onload = () => {
                    _ctx.drawImage(img, 0, 0, _canvas.clientWidth, _canvas.clientHeight);
                    _hasDrawn = true;
                    updateHint();
                    updateOkButton();
                };
                img.src = _previousValue;
            } else {
                clearCanvas();
            }
        }, 30);
    }

    function close() {
        _modal.classList.remove('show');
        _currentTargetImg = null;
        _previousValue = null;
        _isDrawing = false;
        _lastPoint = null;
        _hasDrawn = false;
        // Cacher l'overlay rotation s'il était affiché
        const hint = document.getElementById('sig-fd-rotate-hint');
        if (hint) hint.classList.remove('show');
        // Notifier le parent qu'on sort du mode signature
        try {
            if (window.parent && window.parent !== window) {
                window.parent.postMessage({ type: 'signature_mode', action: 'exit' }, '*');
            }
        } catch (e) { /* ignore cross-origin */ }
    }

    function cancelSignature() {
        // Annuler ne touche pas à l'image cible — elle reste comme elle était avant
        close();
    }

    function saveSignature() {
        if (!_currentTargetImg || !_hasDrawn) return;
        _currentTargetImg.src = _canvas.toDataURL('image/png');
        markAsSigned(_currentTargetImg);
        close();

        // Toast de confirmation si dispo
        if (typeof window.showToast === 'function') {
            window.showToast('Signature enregistrée', 'success');
        }
    }

    // ----- Indicateur "Signé" -----
    function markAsSigned(img) {
        if (!img) return;
        const hasSig = img.src && img.src !== '' && !img.src.endsWith('/');
        const box = img.closest('.sig-box');
        if (box) {
            box.classList.toggle('has-signature', hasSig);
        }
        img.classList.toggle('has-signature', hasSig);
    }

    // ----- Détection des signatures déjà présentes au chargement -----
    function refreshIndicators(container) {
        const root = container || document;
        root.querySelectorAll('.display-sig').forEach(markAsSigned);
    }

    // ----- API publique -----
    function attach(targetImg) {
        if (!targetImg) return;
        // Remplacer le onclick existant qui appelle openModal()
        targetImg.onclick = (e) => {
            e.preventDefault();
            // Respecter l'état lecture seule
            if (targetImg.style.pointerEvents === 'none') return;
            openFor(targetImg);
        };
        markAsSigned(targetImg);
    }

    function attachAll(container) {
        if (!container) return;
        container.querySelectorAll('.display-sig').forEach(attach);
    }

    // Observer les changements de src (par ex. quand on charge un doc) pour refresh les indicateurs
    function watchContainer(container) {
        if (!container || !window.MutationObserver) return;
        const obs = new MutationObserver((mutations) => {
            for (const m of mutations) {
                if (m.type === 'attributes' && m.attributeName === 'src' && m.target.classList.contains('display-sig')) {
                    markAsSigned(m.target);
                }
                if (m.type === 'childList') {
                    m.addedNodes.forEach(n => {
                        if (n.nodeType === 1) {
                            const sigs = n.classList && n.classList.contains('display-sig')
                                ? [n] : (n.querySelectorAll ? n.querySelectorAll('.display-sig') : []);
                            sigs.forEach(s => { attach(s); markAsSigned(s); });
                        }
                    });
                }
            }
        });
        obs.observe(container, {
            childList: true,
            subtree: true,
            attributes: true,
            attributeFilter: ['src']
        });
    }

    window.SignatureFD = {
        attach,
        attachAll,
        refreshIndicators,
        watchContainer,
        // Expose le openFor au cas où on veut l'appeler programmatiquement
        openFor
    };
})();
