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
-- - L'auteur OU un utilisateur avec la permission `manage_calendar` peut
--   MODIFIER ou SUPPRIMER un événement (basé sur les permissions
--   configurables, pas sur une hiérarchie de rôles codée en dur)
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
        OR public.user_has_permission('manage_calendar')
    );

-- 5. UPDATE : l'auteur OU quelqu'un avec la permission manage_calendar
-- (plus de hiérarchie codée en dur — basé sur les permissions configurables)
CREATE POLICY "evenements_update"
    ON public.evenements
    FOR UPDATE
    TO authenticated
    USING (
        author_id = auth.uid()
        OR public.user_has_permission('manage_calendar')
    )
    WITH CHECK (
        author_id = auth.uid()
        OR public.user_has_permission('manage_calendar')
    );

-- 6. DELETE : l'auteur OU quelqu'un avec la permission manage_calendar
CREATE POLICY "evenements_delete"
    ON public.evenements
    FOR DELETE
    TO authenticated
    USING (
        author_id = auth.uid()
        OR public.user_has_permission('manage_calendar')
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
