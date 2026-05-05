/* =========================================================================
   autosave.js — Système de sauvegarde automatique en localStorage
   =========================================================================
   Usage :
     const autosave = window.AutosaveFD.create({
         module: 'facture',           // 'facture' | 'soumission' | 'feuille_de_temps'
         containerSelector: '#invoice-container',
         draftIdGetter: () => currentInvoiceId,  // fonction qui retourne l'ID brouillon courant
         onRestore: (data) => { ... }            // callback de restauration
     });

     autosave.start();   // démarre la surveillance
     autosave.stop();    // arrête (ex: quand on ferme l'éditeur)
     autosave.clear();   // efface le brouillon (après vraie sauvegarde Supabase)
     autosave.restore(); // tente de restaurer un brouillon existant
   ========================================================================= */

(function() {
    'use strict';

    const STORAGE_PREFIX = 'fdussault_draft_';
    const DEBOUNCE_MS = 2000;       // 2 secondes après la dernière frappe
    const FORCED_SAVE_MS = 30000;   // 30 secondes max entre 2 sauvegardes

    function create(config) {
        if (!config.module) throw new Error('autosave: module requis');
        if (!config.containerSelector) throw new Error('autosave: containerSelector requis');

        let debounceTimer = null;
        let intervalTimer = null;
        let isRunning = false;
        let inputListener = null;
        let lastSavedAt = 0;

        // ------------------------------------------------------------------
        // Helpers
        // ------------------------------------------------------------------
        function getStorageKey() {
            const id = config.draftIdGetter ? config.draftIdGetter() : null;
            const suffix = id || 'new';
            return STORAGE_PREFIX + config.module + '_' + suffix;
        }

        function captureCurrentState() {
            const container = document.querySelector(config.containerSelector);
            if (!container) return null;

            const inputs = Array.from(container.querySelectorAll('input'));
            const sigs = Array.from(container.querySelectorAll('.display-sig'));

            return {
                inputValues: inputs.map(i => i.value),
                sigValues: sigs.map(img => img.getAttribute('src')),
                pageCount: container.querySelectorAll('.page').length,
                savedAt: Date.now()
            };
        }

        function applyState(state) {
            const container = document.querySelector(config.containerSelector);
            if (!container || !state) return false;

            const inputs = container.querySelectorAll('input');
            const sigs = container.querySelectorAll('.display-sig');

            if (state.inputValues) {
                inputs.forEach((input, idx) => {
                    if (state.inputValues[idx] !== undefined) {
                        input.value = state.inputValues[idx];
                    }
                });
            }
            if (state.sigValues) {
                sigs.forEach((img, idx) => {
                    if (state.sigValues[idx]) img.src = state.sigValues[idx];
                });
            }

            return true;
        }

        // ------------------------------------------------------------------
        // Sauvegarde
        // ------------------------------------------------------------------
        function save() {
            try {
                const state = captureCurrentState();
                if (!state) return;

                // Optimisation : ne pas écrire si rien n'a changé depuis la dernière fois
                const key = getStorageKey();
                const existing = localStorage.getItem(key);
                if (existing) {
                    const parsed = JSON.parse(existing);
                    if (JSON.stringify(parsed.inputValues) === JSON.stringify(state.inputValues) &&
                        JSON.stringify(parsed.sigValues) === JSON.stringify(state.sigValues)) {
                        return;
                    }
                }

                localStorage.setItem(key, JSON.stringify(state));
                lastSavedAt = Date.now();
            } catch (e) {
                // localStorage plein ou indisponible — on log mais on ne crashe pas
                console.warn('[autosave] sauvegarde impossible:', e);
            }
        }

        function scheduleDebouncedSave() {
            if (debounceTimer) clearTimeout(debounceTimer);
            debounceTimer = setTimeout(save, DEBOUNCE_MS);
        }

        // ------------------------------------------------------------------
        // Restauration
        // ------------------------------------------------------------------
        function restore() {
            try {
                const key = getStorageKey();
                const raw = localStorage.getItem(key);
                if (!raw) return null;

                const state = JSON.parse(raw);
                const applied = applyState(state);

                if (applied && config.onRestore) {
                    config.onRestore(state);
                }

                // Toast de notification
                if (window.showToast && applied) {
                    const minutesAgo = Math.floor((Date.now() - state.savedAt) / 60000);
                    let timeText;
                    if (minutesAgo < 1) timeText = "à l'instant";
                    else if (minutesAgo < 60) timeText = "il y a " + minutesAgo + " min";
                    else timeText = "il y a " + Math.floor(minutesAgo / 60) + " h";

                    window.showToast('Brouillon restauré (' + timeText + ')', 'info', 4000);
                }

                return state;
            } catch (e) {
                console.warn('[autosave] restauration impossible:', e);
                return null;
            }
        }

        function hasDraft() {
            try {
                return localStorage.getItem(getStorageKey()) !== null;
            } catch (e) {
                return false;
            }
        }

        // ------------------------------------------------------------------
        // Effacement (après vraie sauvegarde Supabase)
        // ------------------------------------------------------------------
        function clear() {
            try {
                localStorage.removeItem(getStorageKey());
            } catch (e) { /* silent */ }
        }

        // Efface les brouillons orphelins très anciens (> 7 jours)
        function cleanupOldDrafts() {
            try {
                const SEVEN_DAYS_MS = 7 * 24 * 60 * 60 * 1000;
                const now = Date.now();

                for (let i = localStorage.length - 1; i >= 0; i--) {
                    const k = localStorage.key(i);
                    if (k && k.startsWith(STORAGE_PREFIX)) {
                        try {
                            const data = JSON.parse(localStorage.getItem(k));
                            if (data.savedAt && (now - data.savedAt) > SEVEN_DAYS_MS) {
                                localStorage.removeItem(k);
                            }
                        } catch (e) {
                            localStorage.removeItem(k); // données corrompues
                        }
                    }
                }
            } catch (e) { /* silent */ }
        }

        // ------------------------------------------------------------------
        // Démarrage / arrêt
        // ------------------------------------------------------------------
        function start() {
            if (isRunning) return;
            isRunning = true;

            const container = document.querySelector(config.containerSelector);
            if (!container) {
                console.warn('[autosave] container introuvable:', config.containerSelector);
                return;
            }

            // Listener sur input/change events (capture toute frappe)
            inputListener = function() { scheduleDebouncedSave(); };
            container.addEventListener('input', inputListener, true);
            container.addEventListener('change', inputListener, true);

            // Sauvegarde forcée toutes les 30 secondes (au cas où le debounce
            // ne se déclenche jamais à cause de modifs continues)
            intervalTimer = setInterval(() => {
                if (Date.now() - lastSavedAt > FORCED_SAVE_MS) {
                    save();
                }
            }, FORCED_SAVE_MS);

            // Sauvegarde aussi quand la page perd le focus (changement d'onglet, fermeture)
            window.addEventListener('beforeunload', save);
            document.addEventListener('visibilitychange', () => {
                if (document.visibilityState === 'hidden') save();
            });

            // Nettoyage des vieux brouillons en arrière-plan
            cleanupOldDrafts();
        }

        function stop() {
            if (!isRunning) return;
            isRunning = false;

            if (debounceTimer) { clearTimeout(debounceTimer); debounceTimer = null; }
            if (intervalTimer) { clearInterval(intervalTimer); intervalTimer = null; }

            const container = document.querySelector(config.containerSelector);
            if (container && inputListener) {
                container.removeEventListener('input', inputListener, true);
                container.removeEventListener('change', inputListener, true);
            }
            inputListener = null;

            window.removeEventListener('beforeunload', save);
        }

        // ------------------------------------------------------------------
        // API publique de l'instance
        // ------------------------------------------------------------------
        return {
            start: start,
            stop: stop,
            save: save,
            restore: restore,
            clear: clear,
            hasDraft: hasDraft
        };
    }

    // ----------------------------------------------------------------------
    // Export global
    // ----------------------------------------------------------------------
    window.AutosaveFD = {
        create: create,

        // Liste tous les brouillons stockés (utile pour debug ou onglet brouillons)
        listAllDrafts: function() {
            const drafts = [];
            try {
                for (let i = 0; i < localStorage.length; i++) {
                    const k = localStorage.key(i);
                    if (k && k.startsWith(STORAGE_PREFIX)) {
                        try {
                            const data = JSON.parse(localStorage.getItem(k));
                            drafts.push({ key: k, data: data });
                        } catch (e) { /* skip */ }
                    }
                }
            } catch (e) { /* silent */ }
            return drafts;
        }
    };
})();
