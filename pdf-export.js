/* =========================================================================
   shared.js — Fonctions communes à tous les modules F.Dussault
   ========================================================================= */

(function() {
    'use strict';

    // Note : le filtre anti-bruit Supabase Lock a été déplacé dans
    // assets/shared/console-filter.js, qui doit être chargé EN PREMIER
    // (avant supabase-js) pour intercepter les erreurs dès le démarrage.

    // ---------------------------------------------------------------------
    // 1. Garde anti-accès direct : redirige vers login si pas dans un iframe
    //    À appeler dans chaque module : window.SharedFD.guardIframe();
    // ---------------------------------------------------------------------
    function guardIframe() {
        if (window.self === window.top) {
            // L'utilisateur a accédé directement à un module → retour au login
            window.location.href = '../login.html';
        }
    }

    // ---------------------------------------------------------------------
    // 2. Système de toast/snackbar global
    //    Utilisation : window.showToast('Texte', 'success'|'error'|'warning'|'info', 3000)
    // ---------------------------------------------------------------------
    function ensureToastContainer() {
        let container = document.getElementById('shared-toast-container');
        if (!container) {
            container = document.createElement('div');
            container.id = 'shared-toast-container';
            document.body.appendChild(container);
        }
        return container;
    }

    function showToast(message, type = 'info', duration = 3000) {
        // Si on est dans un iframe, on demande au parent d'afficher le toast
        // (pour qu'il s'affiche par-dessus toute l'app)
        if (window.parent && window.parent !== window) {
            try {
                window.parent.postMessage({
                    type: 'show_toast',
                    message: message,
                    toastType: type,
                    duration: duration
                }, '*');
                return;
            } catch(e) { /* fallback ci-dessous */ }
        }

        const container = ensureToastContainer();
        const toast = document.createElement('div');
        toast.className = 'shared-toast ' + type;
        toast.textContent = message;
        container.appendChild(toast);

        // Animation d'entrée
        requestAnimationFrame(() => {
            requestAnimationFrame(() => toast.classList.add('show'));
        });

        // Disparition
        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => toast.remove(), 300);
        }, duration);
    }

    // ---------------------------------------------------------------------
    // 3. Gestion uniforme des erreurs Supabase
    //    Convertit les erreurs Supabase en messages clairs pour l'utilisateur
    // ---------------------------------------------------------------------
    function handleSupabaseError(error, context = '') {
        if (!error) return;
        console.error(`[Supabase] ${context}:`, error);

        let userMessage = 'Une erreur est survenue.';

        // Erreurs RLS courantes
        if (error.code === '42501' || error.message?.includes('row-level security')) {
            userMessage = "Tu n'as pas la permission d'effectuer cette action.";
        } else if (error.code === 'PGRST116') {
            userMessage = "Aucun résultat trouvé.";
        } else if (error.message?.includes('JWT expired') || error.message?.includes('refresh_token')) {
            userMessage = "Ta session a expiré. Reconnecte-toi.";
            // Optionnel : redirect après 2s
            setTimeout(() => {
                if (window.parent && window.parent !== window) {
                    window.parent.location.href = 'login.html';
                } else {
                    window.location.href = 'login.html';
                }
            }, 2000);
        } else if (error.message?.includes('network') || error.message?.includes('fetch')) {
            userMessage = "Problème de connexion réseau.";
        } else if (error.message) {
            userMessage = error.message;
        }

        showToast(userMessage, 'error', 4000);
        return userMessage;
    }

    // ---------------------------------------------------------------------
    // 4. Listener pour les toasts venant des iframes (à initialiser dans index.html)
    // ---------------------------------------------------------------------
    function setupToastListener() {
        window.addEventListener('message', function(event) {
            if (event.data && event.data.type === 'show_toast') {
                showToast(
                    event.data.message,
                    event.data.toastType || 'info',
                    event.data.duration || 3000
                );
            }
        });
    }

    // ---------------------------------------------------------------------
    // 5. Helper pour récupérer l'utilisateur courant (avec cache mémoire)
    // ---------------------------------------------------------------------
    let _cachedUser = null;
    async function getCurrentUser(supabaseClient) {
        if (_cachedUser) return _cachedUser;
        const { data: { user } } = await supabaseClient.auth.getUser();
        _cachedUser = user;
        return user;
    }

    function clearUserCache() {
        _cachedUser = null;
    }

    // ---------------------------------------------------------------------
    // 6. Helper de retry pour les erreurs transitoires Supabase
    //    Utilise quand : sauvegardes (insert/update/upsert) qui peuvent rater
    //    sur "AbortError: Lock broken" ou "Failed to fetch" ponctuels.
    //
    //    Usage :
    //      const result = await window.SharedFD.withRetry(async () => {
    //          return await supabaseClient.from('factures').upsert(payload);
    //      });
    //      if (result.error) { ... }
    //
    //    Comportement :
    //    - Si l'opération réussit du premier coup → retourne tout de suite
    //    - Si erreur transitoire → réessaie 1x après 600ms
    //    - Si erreur permanente (RLS, validation, etc.) → retourne tout de suite
    // ---------------------------------------------------------------------
    function isTransientError(error) {
        if (!error) return false;
        const msg = (error.message || '').toLowerCase();
        const name = error.name || '';
        // Erreurs typiques de lock Supabase entre iframes
        if (name === 'AbortError') return true;
        if (msg.includes('lock broken')) return true;
        if (msg.includes('failed to fetch')) return true;
        if (msg.includes('network')) return true;
        // Erreurs HTTP 5xx (serveur surchargé)
        if (error.code && /^5\d\d$/.test(String(error.code))) return true;
        return false;
    }

    async function withRetry(operation, options = {}) {
        const delay = options.delay || 600; // ms entre les tentatives
        const maxAttempts = options.maxAttempts || 2; // 1 essai + 1 retry par défaut

        let lastResult = null;
        for (let attempt = 1; attempt <= maxAttempts; attempt++) {
            try {
                lastResult = await operation();
                // Si la fonction retourne { error: ... } à la mode Supabase
                if (lastResult && lastResult.error) {
                    if (attempt < maxAttempts && isTransientError(lastResult.error)) {
                        await new Promise(r => setTimeout(r, delay));
                        continue;
                    }
                    return lastResult;
                }
                return lastResult; // succès
            } catch (e) {
                // Exception JS (TypeError: Failed to fetch, etc.)
                if (attempt < maxAttempts && isTransientError(e)) {
                    await new Promise(r => setTimeout(r, delay));
                    continue;
                }
                // Renvoyer dans le format Supabase pour cohérence
                return { error: e };
            }
        }
        return lastResult;
    }

    // ---------------------------------------------------------------------
    // Export global
    // ---------------------------------------------------------------------
    window.SharedFD = {
        guardIframe,
        showToast,
        handleSupabaseError,
        setupToastListener,
        getCurrentUser,
        clearUserCache,
        withRetry,
        isTransientError
    };

    // Aussi disponible en raccourci global
    window.showToast = showToast;
})();
