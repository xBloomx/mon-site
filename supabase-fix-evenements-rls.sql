-- ============================================================================
-- supabase-fix-evenements-rls.sql
-- Correctif : ajout des policies RLS manquantes pour la table 'evenements'
-- ============================================================================
-- 
-- CONTEXTE :
-- Le SQL initial supabase-securite.sql active RLS sur toutes les tables
-- métier mais a oublié d'ajouter les policies pour la table 'evenements'
-- (calendriers + événements).
-- 
-- Conséquence : depuis l'activation de RLS, toute insertion/update/delete
-- sur evenements échouait silencieusement (le code JS ne vérifiait pas
-- l'erreur), ce qui faisait que :
-- - Le bouton Sauvegarder du modal "Service d'urgence" ne faisait rien
-- - Les événements du calendrier ne se sauvaient pas
-- - Aucun message d'erreur ne s'affichait
-- 
-- Ce script ajoute les 4 policies (SELECT, INSERT, UPDATE, DELETE) avec
-- les mêmes règles métier que les autres tables :
-- - Tout utilisateur connecté peut LIRE les événements (filtrage côté JS
--   selon shared_with)
-- - Tout utilisateur connecté peut CRÉER ses propres événements
-- - Seul l'auteur (ou un admin A0/A1 avec manage_calendar) peut MODIFIER
--   ou SUPPRIMER un événement
-- 
-- Le script est IDEMPOTENT : il peut être relancé plusieurs fois sans
-- problème (DROP IF EXISTS avant CREATE).
-- ============================================================================

-- 1. S'assurer que RLS est bien activé sur la table
ALTER TABLE public.evenements ENABLE ROW LEVEL SECURITY;

-- 2. Supprimer les anciennes policies si elles existent (idempotence)
DROP POLICY IF EXISTS "evenements_select" ON public.evenements;
DROP POLICY IF EXISTS "evenements_insert" ON public.evenements;
DROP POLICY IF EXISTS "evenements_update" ON public.evenements;
DROP POLICY IF EXISTS "evenements_delete" ON public.evenements;

-- 3. SELECT : tout utilisateur authentifié peut lire
-- Le filtrage par calendar_id et shared_with se fait côté JS dans loadData()
CREATE POLICY "evenements_select"
    ON public.evenements
    FOR SELECT
    TO authenticated
    USING (true);

-- 4. INSERT : tout utilisateur authentifié peut créer un événement
-- (les contraintes métier sont vérifiées côté JS - calendar_id valide, etc.)
CREATE POLICY "evenements_insert"
    ON public.evenements
    FOR INSERT
    TO authenticated
    WITH CHECK (
        author_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.profils
            WHERE id = auth.uid() AND role IN ('A0', 'A1')
        )
    );

-- 5. UPDATE : seul l'auteur ou un admin peut modifier
CREATE POLICY "evenements_update"
    ON public.evenements
    FOR UPDATE
    TO authenticated
    USING (
        author_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.profils
            WHERE id = auth.uid() AND role IN ('A0', 'A1')
        )
    )
    WITH CHECK (
        author_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.profils
            WHERE id = auth.uid() AND role IN ('A0', 'A1')
        )
    );

-- 6. DELETE : seul l'auteur ou un admin peut supprimer
CREATE POLICY "evenements_delete"
    ON public.evenements
    FOR DELETE
    TO authenticated
    USING (
        author_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.profils
            WHERE id = auth.uid() AND role IN ('A0', 'A1')
        )
    );

-- ============================================================================
-- Vérification (à exécuter manuellement) :
-- 
-- SELECT schemaname, tablename, policyname, permissive, roles, cmd
-- FROM pg_policies
-- WHERE tablename = 'evenements';
-- 
-- Doit retourner 4 lignes (SELECT, INSERT, UPDATE, DELETE).
-- ============================================================================
