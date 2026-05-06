-- ============================================================================
-- supabase-fix-messages-edit-delete.sql
-- Ajoute la modification et suppression de messages dans la messagerie.
-- ============================================================================
--
-- CONTEXTE :
-- - Modifier ses propres messages dans les 5 min après envoi
-- - Supprimer ses propres messages à tout moment (le message reste affiché
--   avec "Message supprimé")
-- - Quand les 2 utilisateurs d'une conversation 1-à-1 ont caché la conversation
--   (chats_caches), les messages associés sont supprimés définitivement
--   pour libérer l'espace de la BDD.
--
-- IDEMPOTENT : peut être relancé sans problème.
-- ============================================================================

-- 1. Ajouter les colonnes nécessaires à la table messages
ALTER TABLE public.message
    ADD COLUMN IF NOT EXISTS edited_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 2. Politique RLS : permettre à un utilisateur de modifier/supprimer ses propres messages
-- (en vérifiant que c'est bien lui l'expéditeur)
DROP POLICY IF EXISTS "messages_update_own" ON public.message;
CREATE POLICY "messages_update_own"
    ON public.message FOR UPDATE
    TO authenticated
    USING (expediteur_id = auth.uid())
    WITH CHECK (expediteur_id = auth.uid());

-- Note : on n'ajoute PAS de politique DELETE — la suppression "soft" se fait via
-- UPDATE en mettant deleted_at = NOW(). La vraie suppression (hard delete) se
-- fait par la fonction cleanup_orphaned_messages() ci-dessous.

-- 3. Fonction qui supprime DÉFINITIVEMENT les messages d'une conversation
-- quand les 2 utilisateurs l'ont cachée. Appelée automatiquement par trigger
-- quand un nouveau cache est ajouté.
CREATE OR REPLACE FUNCTION public.cleanup_messages_if_hidden_by_all()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_chat_id TEXT := NEW.chat_id;
    v_other_user_id UUID;
    v_other_hidden BOOLEAN;
BEGIN
    -- Pour les chats 1-à-1, le chat_id contient les 2 IDs séparés par "_"
    -- (format : "uuid1_uuid2"). On extrait l'autre utilisateur.
    -- Si c'est un chat de groupe ou "global", on ne nettoie pas.
    IF v_chat_id NOT LIKE '%\_%' OR v_chat_id = 'global' THEN
        RETURN NEW;
    END IF;

    -- Identifier l'autre utilisateur dans le chat_id
    -- Format attendu : "uuid1_uuid2" — on prend celui qui n'est pas NEW.user_id
    BEGIN
        IF split_part(v_chat_id, '_', 1)::UUID = NEW.user_id THEN
            v_other_user_id := split_part(v_chat_id, '_', 2)::UUID;
        ELSE
            v_other_user_id := split_part(v_chat_id, '_', 1)::UUID;
        END IF;
    EXCEPTION WHEN OTHERS THEN
        -- Si le split ne fonctionne pas (chat de groupe avec UUID custom),
        -- on ignore le nettoyage.
        RETURN NEW;
    END;

    -- Vérifier si l'autre utilisateur a aussi caché cette conversation
    SELECT EXISTS (
        SELECT 1 FROM public.chats_caches
        WHERE user_id = v_other_user_id
          AND chat_id = v_chat_id
    ) INTO v_other_hidden;

    -- Si OUI : supprimer définitivement les messages de cette conversation
    -- (et les caches eux-mêmes pour nettoyer)
    IF v_other_hidden THEN
        DELETE FROM public.message WHERE chat_id = v_chat_id;
        DELETE FROM public.chats_caches WHERE chat_id = v_chat_id;
        RAISE NOTICE 'Messages de chat % supprimés définitivement (caché par les 2 users)', v_chat_id;
    END IF;

    RETURN NEW;
END;
$$;

-- 4. Trigger : déclenche le cleanup à chaque INSERT dans chats_caches
DROP TRIGGER IF EXISTS trigger_cleanup_hidden_messages ON public.chats_caches;
CREATE TRIGGER trigger_cleanup_hidden_messages
    AFTER INSERT ON public.chats_caches
    FOR EACH ROW
    EXECUTE FUNCTION public.cleanup_messages_if_hidden_by_all();

-- ============================================================================
-- Vérification (à exécuter manuellement après) :
--
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'message'
--   AND column_name IN ('edited_at', 'deleted_at');
--
-- Doit retourner les 2 colonnes avec type "timestamp with time zone".
-- ============================================================================
