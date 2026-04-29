/* =========================================================================
   console-filter.js — Filtre anti-bruit Supabase Lock
   À CHARGER EN TOUT PREMIER, AVANT supabase-js
   =========================================================================

   L'app charge Supabase 12 fois (une par iframe). Toutes les iframes
   essaient d'acquérir le même lock localStorage `lock:fdussault-auth-v1`
   au démarrage → conflits massifs qui polluent la console.

   Supabase gère la situation en interne (acquire forcé après 5s), donc
   l'app fonctionne quand même. Ces messages sont juste cosmétiques.

   Ce script intercepte console.warn, console.error et les promesses
   rejetées pour filtrer ces messages spécifiques.
   ========================================================================= */
(function() {
    'use strict';

    const _origWarn = console.warn.bind(console);
    const _origError = console.error.bind(console);
    const _origLog = console.log.bind(console);

    function isLockNoise(args) {
        try {
            // Concaténer tous les arguments en une seule chaîne
            const text = Array.from(args).map(a => {
                if (a === null || a === undefined) return '';
                if (typeof a === 'string') return a;
                if (typeof a === 'object') {
                    // Objet Error : prendre message + name + stack
                    let s = '';
                    if (a.message) s += a.message + ' ';
                    if (a.name) s += a.name + ' ';
                    if (a.stack) s += a.stack;
                    if (!s) {
                        try { s = JSON.stringify(a); } catch(e) { s = String(a); }
                    }
                    return s;
                }
                return String(a);
            }).join(' ');

            return text.includes('Lock not released within') ||
                   text.includes('lock:fdussault-auth') ||
                   (text.includes('AbortError') && text.includes('Lock broken')) ||
                   text.includes("Erreur d'initialisation") && text.includes('Lock broken') ||
                   text.includes('Erreur initAuth') && text.includes('Lock broken') ||
                   text.includes('Erreur Supabase') && text.includes('Lock broken');
        } catch (e) {
            return false;
        }
    }

    console.warn = function(...args) {
        if (isLockNoise(args)) return;
        _origWarn(...args);
    };

    console.error = function(...args) {
        if (isLockNoise(args)) return;
        _origError(...args);
    };

    // Intercepter les rejets de promesses non capturés
    window.addEventListener('unhandledrejection', function(event) {
        try {
            const reason = event.reason;
            const msg = (reason && (reason.message || String(reason))) || '';
            const name = (reason && reason.name) || '';
            if (msg.includes('Lock broken') ||
                msg.includes('Lock not released') ||
                (name === 'AbortError' && msg.includes('steal'))) {
                event.preventDefault();
                event.stopPropagation();
                event.stopImmediatePropagation && event.stopImmediatePropagation();
            }
        } catch (e) { /* ignore */ }
    }, true); // capture phase pour intercepter avant tout autre handler

    // Aussi capturer les erreurs globales
    window.addEventListener('error', function(event) {
        try {
            const msg = (event.message || '') + ' ' + (event.error && event.error.message || '');
            if (msg.includes('Lock broken') || msg.includes('Lock not released')) {
                event.preventDefault();
                event.stopPropagation();
            }
        } catch (e) { /* ignore */ }
    }, true);
})();
