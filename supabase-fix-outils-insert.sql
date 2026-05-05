-- ============================================================================
-- supabase-fix-outils-insert.sql
-- Permettre à tous les utilisateurs authentifiés de créer un emprunt d'outil
-- ============================================================================
--
-- CONTEXTE :
-- Avant ce fix, seuls les utilisateurs avec la permission 'manage_tools'
-- (A0/A1/A2) pouvaient créer une entrée dans la table outils. Les comptes
-- A3 (employés terrain) recevaient l'erreur :
--   "new row violates row-level security policy for table outils"
-- quand ils essayaient d'emprunter un outil.
--
-- Or le module Outils est conçu pour que TOUT employé puisse enregistrer
-- ses propres emprunts (c'est le but du module : registre de matériel
-- accessible à tous).
--
-- Ce script remplace la politique INSERT pour autoriser tout authentifié.
-- Les politiques UPDATE/DELETE restent strictes (seuls manage_tools ou
-- transfer_tools peuvent modifier).
--
-- IDEMPOTENT : peut être relancé plusieurs fois sans problème.
-- ============================================================================

-- 1. Supprimer l'ancienne politique restrictive
DROP POLICY IF EXISTS "outils_insert" ON public.outils;

-- 2. Créer la nouvelle politique permissive en INSERT
CREATE POLICY "outils_insert"
  ON public.outils FOR INSERT
  TO authenticated
  WITH CHECK (true);

-- ============================================================================
-- Vérification (à exécuter manuellement après) :
--
-- Connecte-toi avec un compte A3 et essaie d'emprunter un outil. Devrait
-- maintenant fonctionner sans erreur RLS.
-- ============================================================================
