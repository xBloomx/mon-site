-- ============================================================================
-- supabase-fix-clients-suppression.sql
-- Corrige l'impossibilité de supprimer un client.
--
-- Causes possibles :
--   1) La colonne `est_supprime` n'existe pas dans la table `clients`
--   2) La policy RLS UPDATE est trop restrictive et bloque silencieusement
--      l'UPDATE sans renvoyer d'erreur (0 rows affected)
--
-- Ce script :
--   - Ajoute la colonne `est_supprime` si elle manque
--   - Supprime et recrée les policies clients_update et clients_select
--     pour garantir qu'un authentifié peut bien lire et modifier les clients
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

-- 3) Recréer DE FORCE les policies SELECT, INSERT, UPDATE
--    (DROP IF EXISTS puis CREATE pour garantir l'état attendu)
DROP POLICY IF EXISTS "clients_select"  ON public.clients;
DROP POLICY IF EXISTS "clients_insert"  ON public.clients;
DROP POLICY IF EXISTS "clients_update"  ON public.clients;

CREATE POLICY "clients_select"
    ON public.clients FOR SELECT
    TO authenticated
    USING (true);

CREATE POLICY "clients_insert"
    ON public.clients FOR INSERT
    TO authenticated
    WITH CHECK (true);

-- IMPORTANT : USING + WITH CHECK à TRUE pour autoriser l'UPDATE
-- (c'est cette policy qui permet de mettre est_supprime = true)
CREATE POLICY "clients_update"
    ON public.clients FOR UPDATE
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- 4) DELETE policy : recréer seulement si elle n'existe pas
--    (on ne veut pas écraser une policy DELETE plus stricte)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies
        WHERE schemaname = 'public' AND tablename = 'clients' AND policyname = 'clients_delete'
    ) THEN
        IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'user_has_permission') THEN
            EXECUTE 'CREATE POLICY "clients_delete" ON public.clients FOR DELETE TO authenticated USING (public.user_has_permission(''delete_clients''))';
        ELSE
            EXECUTE 'CREATE POLICY "clients_delete" ON public.clients FOR DELETE TO authenticated USING (true)';
        END IF;
    END IF;
END
$$;

-- ============================================================================
-- VÉRIFICATIONS (à lancer manuellement après) :
--
-- a) La colonne existe :
--    SELECT column_name, data_type, column_default
--    FROM information_schema.columns
--    WHERE table_name = 'clients' AND column_name = 'est_supprime';
--
-- b) Les policies sont en place :
--    SELECT policyname, cmd, qual
--    FROM pg_policies
--    WHERE schemaname = 'public' AND tablename = 'clients';
--
-- c) Test direct (remplace l'UUID par un vrai client) :
--    UPDATE public.clients SET est_supprime = true
--    WHERE id = 'UUID_DU_CLIENT' RETURNING id, nom, est_supprime;
--    Doit retourner une ligne.
-- ============================================================================

