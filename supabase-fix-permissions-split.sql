-- ============================================================================
-- supabase-fix-permissions-split.sql
-- Migre les permissions A0/A1/A2 pour ajouter view_all_quotes et
-- view_all_timesheets (qui étaient incluses dans view_all_invoices avant).
-- ============================================================================
--
-- CONTEXTE :
-- Avant ce fix, view_all_invoices donnait accès à TOUT (factures + soumissions +
-- feuilles de temps). On a séparé en 3 permissions distinctes pour pouvoir
-- donner accès granulaire (ex: voir factures sans soumissions).
--
-- Pour préserver le comportement actuel des A0/A1/A2 (qui voyaient tout),
-- on leur ajoute automatiquement les 2 nouvelles permissions.
-- A3 reste inchangé (n'avait rien, n'aura rien).
--
-- IDEMPOTENT : peut être relancé sans problème.
-- ============================================================================

-- 1. Mettre à jour la config dynamique des rôles dans parametres_globaux
DO $$
DECLARE
  current_config jsonb;
  updated_config jsonb;
BEGIN
  -- Lire la config actuelle
  SELECT valeur::jsonb INTO current_config
  FROM public.parametres_globaux
  WHERE cle = 'roles_config'
  LIMIT 1;

  -- Si la config existe, ajouter les 2 nouvelles permissions à A1 et A2
  IF current_config IS NOT NULL THEN
    updated_config := current_config;

    -- A1 : ajouter view_all_quotes et view_all_timesheets si absents
    IF updated_config->'A1'->'perms' IS NOT NULL THEN
      IF NOT (updated_config->'A1'->'perms' ? 'view_all_quotes') THEN
        updated_config := jsonb_set(
          updated_config,
          '{A1,perms}',
          (updated_config->'A1'->'perms') || '["view_all_quotes"]'::jsonb
        );
      END IF;
      IF NOT (updated_config->'A1'->'perms' ? 'view_all_timesheets') THEN
        updated_config := jsonb_set(
          updated_config,
          '{A1,perms}',
          (updated_config->'A1'->'perms') || '["view_all_timesheets"]'::jsonb
        );
      END IF;
    END IF;

    -- A2 : ajouter view_all_quotes et view_all_timesheets si absents
    IF updated_config->'A2'->'perms' IS NOT NULL THEN
      IF NOT (updated_config->'A2'->'perms' ? 'view_all_quotes') THEN
        updated_config := jsonb_set(
          updated_config,
          '{A2,perms}',
          (updated_config->'A2'->'perms') || '["view_all_quotes"]'::jsonb
        );
      END IF;
      IF NOT (updated_config->'A2'->'perms' ? 'view_all_timesheets') THEN
        updated_config := jsonb_set(
          updated_config,
          '{A2,perms}',
          (updated_config->'A2'->'perms') || '["view_all_timesheets"]'::jsonb
        );
      END IF;
    END IF;

    -- Sauver la config mise à jour
    UPDATE public.parametres_globaux
    SET valeur = updated_config::text
    WHERE cle = 'roles_config';

    RAISE NOTICE 'Permissions A1/A2 mises à jour avec succès';
  ELSE
    RAISE NOTICE 'Aucune config dans parametres_globaux — utilise le fallback du code';
  END IF;
END $$;

-- ============================================================================
-- Vérification (à exécuter manuellement après) :
--
-- SELECT valeur::jsonb FROM public.parametres_globaux WHERE cle = 'roles_config';
--
-- Doit montrer view_all_quotes et view_all_timesheets dans les perms de A1 et A2.
-- ============================================================================
