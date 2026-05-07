-- ============================================================================
-- supabase-fix-clients-suppression.sql
-- Corrige l'impossibilité de supprimer un client.
--
-- Cause probable : la colonne `est_supprime` n'existe pas dans la table
-- `clients`, donc l'UPDATE échoue silencieusement côté front.
--
-- Ce script ajoute la colonne si elle manque, et s'assure que les policies
-- RLS autorisent UPDATE/DELETE pour les utilisateurs authentifiés.
-- ============================================================================
-- IDEMPOTENT : peut être relancé plusieurs fois sans problème.
-- ============================================================================

-- 1) Ajouter la colonne si manquante
ALTER TABLE public.clients
    ADD COLUMN IF NOT EXISTS est_supprime BOOLEAN DEFAULT false;

-- Mettre tous les clients existants à FALSE par défaut (au cas où la colonne
-- vient d'être ajoutée et qu'il y aurait des NULL)
UPDATE public.clients SET est_supprime = false WHERE est_supprime IS NULL;

-- Index pour filtrer rapidement actifs vs supprimés (corbeille)
CREATE INDEX IF NOT EXISTS clients_est_supprime_idx
    ON public.clients (est_supprime);

-- 2) S'assurer que RLS est activé sur la table
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;

-- 3) Recréer les policies de base au cas où elles auraient été perdues
--    (ne touche à rien si elles existent déjà)
DO $$
BEGIN
    -- SELECT
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'clients' AND policyname = 'clients_select'
    ) THEN
        CREATE POLICY "clients_select" ON public.clients FOR SELECT TO authenticated USING (true);
    END IF;

    -- INSERT
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'clients' AND policyname = 'clients_insert'
    ) THEN
        CREATE POLICY "clients_insert" ON public.clients FOR INSERT TO authenticated WITH CHECK (true);
    END IF;

    -- UPDATE (c'est celle qui permet la mise à est_supprime = true)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'clients' AND policyname = 'clients_update'
    ) THEN
        CREATE POLICY "clients_update" ON public.clients FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
    END IF;

    -- DELETE (réservé aux rôles avec la permission delete_clients)
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'clients' AND policyname = 'clients_delete'
    ) THEN
        -- Si la fonction user_has_permission existe, on l'utilise ; sinon on autorise tout authentifié
        IF EXISTS (
            SELECT 1 FROM pg_proc WHERE proname = 'user_has_permission'
        ) THEN
            EXECUTE 'CREATE POLICY "clients_delete" ON public.clients FOR DELETE TO authenticated USING (public.user_has_permission(''delete_clients''))';
        ELSE
            EXECUTE 'CREATE POLICY "clients_delete" ON public.clients FOR DELETE TO authenticated USING (true)';
        END IF;
    END IF;
END
$$;

-- ============================================================================
-- VÉRIFICATION (à exécuter manuellement après) :
--
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'clients' AND column_name = 'est_supprime';
--
-- Doit retourner : est_supprime | boolean
-- ============================================================================
