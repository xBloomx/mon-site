-- ============================================================================
-- supabase-fix-chats-caches.sql
-- Système de masquage de conversations dans la messagerie
-- ============================================================================
--
-- CONTEXTE :
-- Quand un utilisateur "supprime" une conversation, on ne supprime pas les
-- messages de la table 'message' — ils restent visibles pour l'autre
-- participant. À la place, on enregistre dans cette table que CE user
-- a masqué CE chat.
--
-- Si un nouveau message arrive sur un chat masqué, le client doit retirer
-- l'entrée pour que la conversation réapparaisse (faisable côté client
-- via DELETE).
--
-- IDEMPOTENT : peut être relancé plusieurs fois sans problème.
-- ============================================================================

-- 1. Table : un user (user_id) a masqué un chat (chat_id)
CREATE TABLE IF NOT EXISTS public.chats_caches (
    user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    chat_id    TEXT NOT NULL,
    hidden_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, chat_id)
);

-- 2. Index pour accélérer les requêtes côté client
CREATE INDEX IF NOT EXISTS idx_chats_caches_user
    ON public.chats_caches (user_id);

-- 3. Activer Row Level Security
ALTER TABLE public.chats_caches ENABLE ROW LEVEL SECURITY;

-- 4. Politiques : chaque utilisateur ne peut voir/gérer que ses propres entrées
DROP POLICY IF EXISTS "chats_caches_select" ON public.chats_caches;
CREATE POLICY "chats_caches_select"
    ON public.chats_caches
    FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "chats_caches_insert" ON public.chats_caches;
CREATE POLICY "chats_caches_insert"
    ON public.chats_caches
    FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "chats_caches_delete" ON public.chats_caches;
CREATE POLICY "chats_caches_delete"
    ON public.chats_caches
    FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- ============================================================================
-- Vérification (à exécuter manuellement après) :
--
-- SELECT * FROM public.chats_caches LIMIT 5;
-- → Devrait être vide au début, ne montrer QUE vos propres masquages.
-- ============================================================================
