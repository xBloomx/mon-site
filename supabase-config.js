// supabase-config.js — Configuration centralisée Supabase
// Pour changer de projet, modifier seulement les deux lignes URL et KEY.

window.SUPABASE_URL = 'https://ipxmloqgoukieuerbxtl.supabase.co';
window.SUPABASE_KEY = 'sb_publishable_jVOmm2g3WLxtIrr-rVRvtA_aWaUtB-E';

// storageKey unique évite les conflits de lock entre iframes
// lockAcquireTimeout réduit les délais d'attente
window.supabaseClient = window.supabase.createClient(
    window.SUPABASE_URL,
    window.SUPABASE_KEY,
    {
        auth: {
            storageKey: 'fdussault-auth-v1',
            autoRefreshToken: true,
            persistSession: true,
            detectSessionInUrl: false
        }
    }
);
