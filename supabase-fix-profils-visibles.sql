-- ============================================================================
-- supabase-fix-profils-visibles.sql
-- Permettre à tous les utilisateurs authentifiés de voir la liste des collègues
-- ============================================================================
--
-- CONTEXTE :
-- Avant ce fix, seul A0 (admin) pouvait voir tous les profils. Les comptes
-- A1/A2/A3 ne voyaient que leur propre profil, ce qui rendait impossible :
--   - de partager un calendrier avec un collègue
--   - de créer une nouvelle conversation dans la messagerie
--   - de transférer un outil à un collègue
--   - de partager un événement avec un autre utilisateur
--
-- Ce script remplace la politique de lecture sur la table profils pour que
-- tout utilisateur authentifié puisse voir la liste des collègues (id, nom,
-- rôle, etc.). Les politiques INSERT/UPDATE/DELETE restent strictes — seul
-- l'admin (ou l'utilisateur sur son propre profil) peut modifier.
--
-- IDEMPOTENT : peut être relancé plusieurs fois sans problème.
-- ============================================================================

-- 1. Supprimer l'ancienne politique restrictive
DROP POLICY IF EXISTS "profils_select_own_or_admin" ON public.profils;

-- 2. Créer la nouvelle politique permissive en lecture
CREATE POLICY "profils_select_own_or_admin"
  ON public.profils FOR SELECT
  TO authenticated
  USING (true);

-- ============================================================================
-- Vérification (à exécuter manuellement après) :
--
-- SELECT id, prenom_nom, role FROM public.profils ORDER BY role;
--
-- Doit retourner TOUS les utilisateurs (plus seulement le vôtre).
-- ============================================================================
