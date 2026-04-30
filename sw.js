// sw.js — Service Worker F.Dussault
// Stratégie :
//   - HTML/JS/CSS de l'app  : network-first, cache fallback (pour avoir les MAJ)
//   - Images/assets statiques : cache-first (rapide, change rarement)
//   - Supabase                : jamais touché (toujours réseau)

const CACHE_NAME = 'fdussault-v20';

// Tous les fichiers nécessaires pour que l'app fonctionne hors ligne.
// IMPORTANT : on inclut TOUS les modules pour que la nav fonctionne offline.
const ASSETS_TO_CACHE = [
    '/',
    '/index.html',
    '/login.html',
    '/manifest.json',
    '/supabase-config.js',

    // Modules
    '/code_accueil/code_accueil.html',
    '/code_facture/code_facture.html',
    '/code_soumissions/code_soumissions.html',
    '/code_feuille_de_temps/code_feuille_de_temps.html',
    '/code_messagerie/code_messagerie.html',
    '/code_courriel/code_courriel.html',
    '/code_calendrier/code_calendrier.html',
    '/code_clients/code_clients.html',
    '/code_outils/code_outils.html',
    '/code_po/code_po.html',
    '/code_admin/code_admin.html',
    '/code_profil_parametres/code_profil_parametres.html',

    // Shared (mutualisé entre tous les modules)
    '/assets/shared/shared.css',
    '/assets/shared/console-filter.js',
    '/assets/shared/shared.js',
    '/assets/shared/autosave.js',
    '/assets/shared/archive.js',
    '/assets/shared/pdf-export.js',
    '/assets/shared/signature.js',

    // Logos
    '/assets/logo_app.png',
    '/assets/logo+nom.png',
    '/assets/logo_accueil.png',
    '/assets/logo_facture.png',
    '/assets/logo_soumission.png',
    '/assets/logo_feuille_de_temps.png',
    '/assets/logo_messagerie.png',
    '/assets/logo_courriel.png',
    '/assets/logo_calendrier.png',
    '/assets/logo_client.png',
    '/assets/logo_outils.png',
    '/assets/logo_po.png',
    '/assets/logo_profil.png',
    '/assets/logo_dussault.png',
    '/assets/cmmtq_et_slogan.png'
];

// Installation — mise en cache initiale
self.addEventListener('install', event => {
    event.waitUntil(
        caches.open(CACHE_NAME).then(cache => {
            return Promise.allSettled(
                ASSETS_TO_CACHE.map(url => cache.add(url).catch(e => console.log('SW cache skip:', url)))
            );
        })
    );
    self.skipWaiting();
});

// Activation — nettoyage des anciens caches
self.addEventListener('activate', event => {
    event.waitUntil(
        caches.keys().then(keys =>
            Promise.all(
                keys.filter(key => key !== CACHE_NAME).map(key => caches.delete(key))
            )
        )
    );
    self.clients.claim();
});

// Fetch — stratégies différenciées
self.addEventListener('fetch', event => {
    const req = event.request;
    const url = new URL(req.url);

    // Ignorer : non-GET, extensions, Supabase
    if (req.method !== 'GET') return;
    if (url.protocol === 'chrome-extension:') return;
    if (url.hostname.includes('supabase.co')) return;

    // Stratégie cache-first pour les images (rapide, change rarement)
    if (req.destination === 'image') {
        event.respondWith(
            caches.match(req).then(cached =>
                cached || fetch(req).then(resp => {
                    if (resp && resp.status === 200) {
                        const clone = resp.clone();
                        caches.open(CACHE_NAME).then(cache =>
                            cache.put(req, clone).catch(() => {})
                        );
                    }
                    return resp;
                })
            )
        );
        return;
    }

    // Stratégie network-first pour le reste (HTML/JS/CSS)
    // Permet d'avoir les nouvelles versions, fallback cache si offline
    event.respondWith(
        fetch(req)
            .then(response => {
                if (response && response.status === 200 && response.type !== 'opaque') {
                    const clone = response.clone();
                    caches.open(CACHE_NAME).then(cache =>
                        cache.put(req, clone).catch(() => {})
                    );
                }
                return response;
            })
            .catch(() =>
                caches.match(req).then(cached => {
                    if (cached) return cached;
                    // Page d'erreur si aucune connexion et rien en cache
                    if (req.destination === 'document') {
                        return new Response(getOfflinePage(), {
                            headers: { 'Content-Type': 'text/html; charset=utf-8' }
                        });
                    }
                })
            )
    );
});

function getOfflinePage() {
    return `<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Hors ligne - F.Dussault</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; background: #1e1f26; color: #e0e0e0;
               display: flex; justify-content: center; align-items: center; height: 100vh;
               margin: 0; text-align: center; padding: 20px; }
        h1 { color: #fcca46; font-size: 24px; }
        p { color: #aaa; line-height: 1.6; }
        button { background: #fcca46; color: black; border: none; padding: 12px 25px;
                 border-radius: 8px; font-weight: bold; cursor: pointer; margin-top: 20px;
                 font-size: 16px; }
    </style>
</head>
<body>
    <div>
        <h1>Pas de connexion</h1>
        <p>L'application F.Dussault nécessite une connexion internet pour synchroniser tes données.</p>
        <button onclick="window.location.reload()">Réessayer</button>
    </div>
</body>
</html>`;
}
