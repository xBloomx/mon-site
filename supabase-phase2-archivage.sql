-- ============================================================================
-- PHASE 2 : Archivage (soft delete) — F.Dussault
-- ============================================================================
-- À exécuter dans Supabase SQL Editor APRÈS supabase-securite.sql et
-- supabase-phase1-numerotation.sql.
--
-- Ce script est IDEMPOTENT : tu peux le relancer sans problème.
--
-- Ce qu'il fait :
--   1. Ajoute 5 colonnes d'archivage à factures, soumissions, feuilles_de_temps
--   2. Crée un trigger qui logge automatiquement chaque archivage/restauration
--   3. Met à jour les policies RLS UPDATE pour bloquer la modif des archives
--      (sauf l'opération de restauration elle-même)
--   4. Crée 2 fonctions utilitaires : compter / supprimer les archives > 1 an
-- ============================================================================


-- ============================================================================
-- ÉTAPE 1 : Colonnes d'archivage sur les 3 tables
-- ============================================================================
-- is_archived       : booléen, FALSE par défaut
-- archived_at       : timestamp de l'archivage
-- archived_by       : UUID de l'utilisateur qui a archivé
-- archived_by_name  : nom (snapshot) au moment de l'archivage
-- archive_reason    : raison libre (texte court, optionnel)
-- ----------------------------------------------------------------------------

ALTER TABLE public.factures
  ADD COLUMN IF NOT EXISTS is_archived       boolean   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS archived_at       timestamptz,
  ADD COLUMN IF NOT EXISTS archived_by       uuid,
  ADD COLUMN IF NOT EXISTS archived_by_name  text,
  ADD COLUMN IF NOT EXISTS archive_reason    text;

ALTER TABLE public.soumissions
  ADD COLUMN IF NOT EXISTS is_archived       boolean   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS archived_at       timestamptz,
  ADD COLUMN IF NOT EXISTS archived_by       uuid,
  ADD COLUMN IF NOT EXISTS archived_by_name  text,
  ADD COLUMN IF NOT EXISTS archive_reason    text;

ALTER TABLE public.feuilles_de_temps
  ADD COLUMN IF NOT EXISTS is_archived       boolean   NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS archived_at       timestamptz,
  ADD COLUMN IF NOT EXISTS archived_by       uuid,
  ADD COLUMN IF NOT EXISTS archived_by_name  text,
  ADD COLUMN IF NOT EXISTS archive_reason    text;

-- Index pour accélérer les filtres "is_archived = false" (cas le plus fréquent)
CREATE INDEX IF NOT EXISTS factures_is_archived_idx
  ON public.factures(is_archived) WHERE is_archived = false;
CREATE INDEX IF NOT EXISTS soumissions_is_archived_idx
  ON public.soumissions(is_archived) WHERE is_archived = false;
CREATE INDEX IF NOT EXISTS feuilles_de_temps_is_archived_idx
  ON public.feuilles_de_temps(is_archived) WHERE is_archived = false;


-- ============================================================================
-- ÉTAPE 2 : Trigger générique pour logger les archivages / restaurations
-- ============================================================================
-- Ce trigger s'attache aux 3 tables et écrit dans logs_systeme dès que
-- is_archived passe de false à true (archivage) ou de true à false (restauration).
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.log_archivage()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  table_name_str text := TG_TABLE_NAME;
  doc_id_str     text := NEW.id::text;
  user_name_str  text;
  action_label   text;
  msg            text;
BEGIN
  -- On ne réagit qu'aux changements is_archived
  IF (OLD.is_archived IS DISTINCT FROM NEW.is_archived) THEN

    -- Récupère le nom de l'utilisateur courant (snapshot)
    SELECT COALESCE(prenom_nom, 'Utilisateur inconnu')
      INTO user_name_str
    FROM public.profils
    WHERE id = auth.uid();

    IF NEW.is_archived = true THEN
      action_label := 'Archivage';
      msg := 'Document ' || table_name_str || ' #' || doc_id_str || ' archivé';
      IF NEW.archive_reason IS NOT NULL AND NEW.archive_reason <> '' THEN
        msg := msg || ' — raison : ' || NEW.archive_reason;
      END IF;
    ELSE
      action_label := 'Restauration';
      msg := 'Document ' || table_name_str || ' #' || doc_id_str || ' restauré depuis les archives';
    END IF;

    INSERT INTO public.logs_systeme (type_erreur, message, utilisateur_nom, created_at)
    VALUES (action_label, msg, COALESCE(user_name_str, 'Système'), now());
  END IF;

  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_archivage() TO authenticated;

-- Attacher le trigger aux 3 tables (DROP IF EXISTS pour idempotence)
DROP TRIGGER IF EXISTS trg_log_archivage_factures ON public.factures;
CREATE TRIGGER trg_log_archivage_factures
  AFTER UPDATE OF is_archived ON public.factures
  FOR EACH ROW EXECUTE FUNCTION public.log_archivage();

DROP TRIGGER IF EXISTS trg_log_archivage_soumissions ON public.soumissions;
CREATE TRIGGER trg_log_archivage_soumissions
  AFTER UPDATE OF is_archived ON public.soumissions
  FOR EACH ROW EXECUTE FUNCTION public.log_archivage();

DROP TRIGGER IF EXISTS trg_log_archivage_feuilles ON public.feuilles_de_temps;
CREATE TRIGGER trg_log_archivage_feuilles
  AFTER UPDATE OF is_archived ON public.feuilles_de_temps
  FOR EACH ROW EXECUTE FUNCTION public.log_archivage();


-- ============================================================================
-- ÉTAPE 3 : Mise à jour des policies RLS UPDATE
-- ============================================================================
-- Règle : un document archivé est en lecture seule.
-- La SEULE chose qu'on autorise sur un document archivé, c'est la
-- restauration (is_archived passant de true à false), réservée à A0.
--
-- L'archivage (passage à true) est autorisé via la policy normale, mais
-- côté code on contrôlera qui a le droit de le faire pour quel statut.
-- ----------------------------------------------------------------------------

-- ----- factures -----
DROP POLICY IF EXISTS "factures_update" ON public.factures;
CREATE POLICY "factures_update"
  ON public.factures FOR UPDATE
  TO authenticated
  USING (
    -- On peut TENTER l'update si on a normalement le droit ET que
    -- le doc n'est pas archivé, OU qu'on est A0 (peut tout faire).
    (
      (author_id = auth.uid() OR public.user_has_permission('view_all_invoices'))
      AND is_archived = false
    )
    OR public.is_admin()
  )
  WITH CHECK (
    -- Après l'update, on accepte si :
    --  - le doc reste non-archivé et qu'on a les droits normaux, ou
    --  - on archive (is_archived passant à true) avec les droits normaux, ou
    --  - on est A0 (qui peut tout, y compris restaurer)
    (
      (author_id = auth.uid() OR public.user_has_permission('view_all_invoices'))
    )
    OR public.is_admin()
  );

-- ----- soumissions -----
DROP POLICY IF EXISTS "soumissions_update" ON public.soumissions;
CREATE POLICY "soumissions_update"
  ON public.soumissions FOR UPDATE
  TO authenticated
  USING (
    (
      (author_id = auth.uid() OR public.user_has_permission('view_all_invoices'))
      AND is_archived = false
    )
    OR public.is_admin()
  )
  WITH CHECK (
    (author_id = auth.uid() OR public.user_has_permission('view_all_invoices'))
    OR public.is_admin()
  );

-- ----- feuilles_de_temps -----
DROP POLICY IF EXISTS "feuilles_de_temps_update" ON public.feuilles_de_temps;
CREATE POLICY "feuilles_de_temps_update"
  ON public.feuilles_de_temps FOR UPDATE
  TO authenticated
  USING (
    (
      (author_id = auth.uid() OR public.user_has_permission('approve_timesheets'))
      AND is_archived = false
    )
    OR public.is_admin()
  )
  WITH CHECK (
    (author_id = auth.uid() OR public.user_has_permission('approve_timesheets'))
    OR public.is_admin()
  );


-- ============================================================================
-- ÉTAPE 4 : Fonctions utilitaires — compter / supprimer les archives > 1 an
-- ============================================================================
-- Pas de cron : c'est l'admin (A0) qui déclenche manuellement depuis le panneau.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.count_archives_expired()
RETURNS TABLE(table_name text, nb bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé : réservé aux administrateurs';
  END IF;

  RETURN QUERY
  SELECT 'factures'::text, count(*)::bigint
    FROM public.factures
    WHERE is_archived = true AND archived_at < (now() - interval '1 year')
  UNION ALL
  SELECT 'soumissions'::text, count(*)::bigint
    FROM public.soumissions
    WHERE is_archived = true AND archived_at < (now() - interval '1 year')
  UNION ALL
  SELECT 'feuilles_de_temps'::text, count(*)::bigint
    FROM public.feuilles_de_temps
    WHERE is_archived = true AND archived_at < (now() - interval '1 year');
END;
$$;

GRANT EXECUTE ON FUNCTION public.count_archives_expired() TO authenticated;


CREATE OR REPLACE FUNCTION public.delete_expired_archives()
RETURNS TABLE(table_name text, nb_deleted bigint)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  n_fact bigint;
  n_soum bigint;
  n_feui bigint;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé : réservé aux administrateurs';
  END IF;

  WITH d AS (
    DELETE FROM public.factures
    WHERE is_archived = true AND archived_at < (now() - interval '1 year')
    RETURNING 1
  )
  SELECT count(*) INTO n_fact FROM d;

  WITH d AS (
    DELETE FROM public.soumissions
    WHERE is_archived = true AND archived_at < (now() - interval '1 year')
    RETURNING 1
  )
  SELECT count(*) INTO n_soum FROM d;

  WITH d AS (
    DELETE FROM public.feuilles_de_temps
    WHERE is_archived = true AND archived_at < (now() - interval '1 year')
    RETURNING 1
  )
  SELECT count(*) INTO n_feui FROM d;

  -- Trace dans les logs
  INSERT INTO public.logs_systeme (type_erreur, message, utilisateur_nom, created_at)
  VALUES (
    'Nettoyage Archives',
    'Suppression définitive : ' || n_fact || ' facture(s), '
      || n_soum || ' soumission(s), ' || n_feui || ' feuille(s) de temps.',
    (SELECT COALESCE(prenom_nom, 'Admin') FROM public.profils WHERE id = auth.uid()),
    now()
  );

  RETURN QUERY VALUES
    ('factures'::text, n_fact),
    ('soumissions'::text, n_soum),
    ('feuilles_de_temps'::text, n_feui);
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_expired_archives() TO authenticated;


-- ============================================================================
-- VÉRIFICATIONS — à exécuter individuellement après le script
-- ============================================================================

-- Vérifier que les colonnes existent bien sur les 3 tables :
-- SELECT table_name, column_name, data_type
-- FROM information_schema.columns
-- WHERE table_schema = 'public'
--   AND column_name IN ('is_archived','archived_at','archived_by','archived_by_name','archive_reason')
-- ORDER BY table_name, column_name;

-- Compter les archives par table :
-- SELECT 'factures' AS t, count(*) FROM public.factures WHERE is_archived
-- UNION ALL SELECT 'soumissions', count(*) FROM public.soumissions WHERE is_archived
-- UNION ALL SELECT 'feuilles_de_temps', count(*) FROM public.feuilles_de_temps WHERE is_archived;

-- Tester la fonction de comptage :
-- SELECT * FROM public.count_archives_expired();
