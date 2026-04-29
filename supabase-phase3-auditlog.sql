-- ============================================================================
-- PHASE 3 : Audit Log complet — F.Dussault
-- ============================================================================
-- À exécuter dans Supabase SQL Editor APRÈS supabase-securite.sql,
-- supabase-phase1-numerotation.sql, et supabase-phase2-archivage.sql.
--
-- Ce script est IDEMPOTENT : tu peux le relancer sans problème.
--
-- Ce qu'il fait :
--   1. Enrichit la table logs_systeme avec colonnes structurées (table, doc_id, action)
--   2. Met à jour la policy SELECT pour inclure A1 (patron) en plus de A0
--   3. Crée une fonction utilitaire log_audit() pour faciliter l'écriture
--   4. Crée des triggers sur 5 tables : factures, soumissions, feuilles_de_temps,
--      clients, bons_de_commande
--   5. Crée un trigger sur profils pour tracer les changements de rôle
--   6. Crée 2 fonctions admin : nettoyer logs > 1 an + compter logs > 1 an
-- ============================================================================


-- ============================================================================
-- ÉTAPE 1 : Enrichir la table logs_systeme
-- ============================================================================
-- Colonnes ajoutées (toutes optionnelles, ON DELETE SET NULL pour user_id) :
--   table_name      : nom de la table concernée (factures, clients, ...)
--   doc_id          : id du document concerné (texte pour gérer F-0001 etc.)
--   action          : 'creation' | 'modification' | 'suppression' | 'archivage'
--                     | 'restauration' | 'envoi' | 'retour' | 'connexion' | 'role_change'
--   user_id         : UUID de l'utilisateur (référence profils.id)
--   details_json    : payload structuré pour stocker l'avant/après si besoin
-- ----------------------------------------------------------------------------

ALTER TABLE public.logs_systeme
  ADD COLUMN IF NOT EXISTS table_name    text,
  ADD COLUMN IF NOT EXISTS doc_id        text,
  ADD COLUMN IF NOT EXISTS action        text,
  ADD COLUMN IF NOT EXISTS user_id       uuid REFERENCES public.profils(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS details_json  jsonb;

-- Index pour accélérer les filtres fréquents
CREATE INDEX IF NOT EXISTS logs_systeme_action_idx     ON public.logs_systeme(action);
CREATE INDEX IF NOT EXISTS logs_systeme_table_name_idx ON public.logs_systeme(table_name);
CREATE INDEX IF NOT EXISTS logs_systeme_user_id_idx    ON public.logs_systeme(user_id);
CREATE INDEX IF NOT EXISTS logs_systeme_created_at_idx ON public.logs_systeme(created_at DESC);


-- ============================================================================
-- ÉTAPE 2 : Mise à jour des policies pour inclure A1 en lecture
-- ============================================================================
-- Avant : SELECT réservé à A0
-- Après : SELECT pour A0 + A1
-- DELETE reste réservé à A0 uniquement (sécurité)
-- ----------------------------------------------------------------------------

DROP POLICY IF EXISTS "logs_systeme_select" ON public.logs_systeme;
CREATE POLICY "logs_systeme_select"
  ON public.logs_systeme FOR SELECT
  TO authenticated
  USING (
    public.is_admin()
    OR public.current_user_role() = 'A1'
  );

-- (les policies INSERT et DELETE restent inchangées : insert ouvert, delete A0 only)


-- ============================================================================
-- ÉTAPE 3 : Fonction utilitaire log_audit()
-- ============================================================================
-- Permet d'écrire un log d'audit en une ligne depuis n'importe quel trigger.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.log_audit(
  p_table_name   text,
  p_doc_id       text,
  p_action       text,
  p_message      text,
  p_details_json jsonb DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_name text;
  v_user_id   uuid;
BEGIN
  v_user_id := auth.uid();
  SELECT COALESCE(prenom_nom, 'Utilisateur inconnu')
    INTO v_user_name
  FROM public.profils
  WHERE id = v_user_id;

  INSERT INTO public.logs_systeme (
    type_erreur, message, utilisateur_nom,
    table_name, doc_id, action, user_id, details_json,
    created_at
  )
  VALUES (
    p_action,
    p_message,
    COALESCE(v_user_name, 'Système'),
    p_table_name,
    p_doc_id,
    p_action,
    v_user_id,
    p_details_json,
    now()
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.log_audit(text, text, text, text, jsonb) TO authenticated;


-- ============================================================================
-- ÉTAPE 4 : Trigger générique pour les 5 tables documents
-- ============================================================================
-- Ce trigger se déclenche après INSERT, UPDATE ou DELETE sur les tables docs.
-- Il distingue l'action selon TG_OP et selon les changements de statut/archivage.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_audit_doc_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_action  text;
  v_message text;
  v_doc_id  text;
  v_table   text := TG_TABLE_NAME;
  v_details jsonb;
BEGIN
  -- Récupérer l'ID du document (texte pour gérer F-0001, S-0042, etc.)
  IF (TG_OP = 'DELETE') THEN
    v_doc_id := OLD.id::text;
  ELSE
    v_doc_id := NEW.id::text;
  END IF;

  -- Déterminer l'action et le message selon le contexte
  IF (TG_OP = 'INSERT') THEN
    v_action  := 'creation';
    v_message := 'Création de ' || v_table || ' #' || v_doc_id;

  ELSIF (TG_OP = 'DELETE') THEN
    v_action  := 'suppression';
    v_message := 'SUPPRESSION DÉFINITIVE de ' || v_table || ' #' || v_doc_id;

  ELSIF (TG_OP = 'UPDATE') THEN
    -- Cas spéciaux : archivage et restauration sont déjà loggés par le trigger
    -- log_archivage de la Phase 2. On ne re-logge donc pas ici si seul
    -- is_archived a changé.
    IF (NEW.is_archived IS DISTINCT FROM OLD.is_archived)
       AND (
         row(NEW.*) IS NOT DISTINCT FROM row(OLD.*)
         OR (
           -- Tous les autres champs sont identiques (le seul changement est is_archived)
           NEW.input_values IS NOT DISTINCT FROM OLD.input_values
           AND COALESCE(NEW.status, '') = COALESCE(OLD.status, '')
         )
       ) THEN
      RETURN NEW; -- Skip : l'archivage/restauration est déjà logué
    END IF;

    -- Détection changement de statut
    IF (TG_TABLE_NAME IN ('factures', 'soumissions', 'feuilles_de_temps')
        AND NEW.status IS DISTINCT FROM OLD.status) THEN
      v_action  := 'modification';
      v_message := 'Statut de ' || v_table || ' #' || v_doc_id
                || ' : ' || COALESCE(OLD.status, 'NULL')
                || ' → ' || COALESCE(NEW.status, 'NULL');
      v_details := jsonb_build_object(
        'old_status', OLD.status,
        'new_status', NEW.status
      );
    ELSE
      v_action  := 'modification';
      v_message := 'Modification de ' || v_table || ' #' || v_doc_id;
    END IF;
  END IF;

  -- On ne logue pas si v_action est null (cas de skip plus haut)
  IF v_action IS NOT NULL THEN
    PERFORM public.log_audit(v_table, v_doc_id, v_action, v_message, v_details);
  END IF;

  IF (TG_OP = 'DELETE') THEN
    RETURN OLD;
  ELSE
    RETURN NEW;
  END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.trg_audit_doc_changes() TO authenticated;


-- ============================================================================
-- ÉTAPE 5 : Attacher le trigger aux 5 tables documents
-- ============================================================================
-- DROP IF EXISTS pour idempotence
-- ----------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_audit_factures ON public.factures;
CREATE TRIGGER trg_audit_factures
  AFTER INSERT OR UPDATE OR DELETE ON public.factures
  FOR EACH ROW EXECUTE FUNCTION public.trg_audit_doc_changes();

DROP TRIGGER IF EXISTS trg_audit_soumissions ON public.soumissions;
CREATE TRIGGER trg_audit_soumissions
  AFTER INSERT OR UPDATE OR DELETE ON public.soumissions
  FOR EACH ROW EXECUTE FUNCTION public.trg_audit_doc_changes();

DROP TRIGGER IF EXISTS trg_audit_feuilles_de_temps ON public.feuilles_de_temps;
CREATE TRIGGER trg_audit_feuilles_de_temps
  AFTER INSERT OR UPDATE OR DELETE ON public.feuilles_de_temps
  FOR EACH ROW EXECUTE FUNCTION public.trg_audit_doc_changes();

DROP TRIGGER IF EXISTS trg_audit_clients ON public.clients;
CREATE TRIGGER trg_audit_clients
  AFTER INSERT OR UPDATE OR DELETE ON public.clients
  FOR EACH ROW EXECUTE FUNCTION public.trg_audit_doc_changes();

DROP TRIGGER IF EXISTS trg_audit_bons_de_commande ON public.bons_de_commande;
CREATE TRIGGER trg_audit_bons_de_commande
  AFTER INSERT OR UPDATE OR DELETE ON public.bons_de_commande
  FOR EACH ROW EXECUTE FUNCTION public.trg_audit_doc_changes();


-- ============================================================================
-- ÉTAPE 6 : Trigger spécial — Changement de rôle dans profils
-- ============================================================================
-- Critique pour la sécurité : on veut savoir si quelqu'un a changé de rôle.
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_audit_role_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF (NEW.role IS DISTINCT FROM OLD.role) THEN
    PERFORM public.log_audit(
      'profils',
      NEW.id::text,
      'role_change',
      'Rôle de ' || COALESCE(NEW.prenom_nom, 'utilisateur') || ' : '
        || COALESCE(OLD.role, 'NULL') || ' → ' || COALESCE(NEW.role, 'NULL'),
      jsonb_build_object(
        'user_name', NEW.prenom_nom,
        'old_role', OLD.role,
        'new_role', NEW.role
      )
    );
  END IF;
  RETURN NEW;
END;
$$;

GRANT EXECUTE ON FUNCTION public.trg_audit_role_change() TO authenticated;

DROP TRIGGER IF EXISTS trg_audit_role_change ON public.profils;
CREATE TRIGGER trg_audit_role_change
  AFTER UPDATE OF role ON public.profils
  FOR EACH ROW EXECUTE FUNCTION public.trg_audit_role_change();


-- ============================================================================
-- ÉTAPE 7 : Fonctions admin — Nettoyer / compter les logs > 1 an
-- ============================================================================

CREATE OR REPLACE FUNCTION public.count_logs_expired()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count bigint;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé : réservé aux administrateurs';
  END IF;

  SELECT count(*) INTO v_count
  FROM public.logs_systeme
  WHERE created_at < (now() - interval '1 year');

  RETURN COALESCE(v_count, 0);
END;
$$;

GRANT EXECUTE ON FUNCTION public.count_logs_expired() TO authenticated;


CREATE OR REPLACE FUNCTION public.delete_expired_logs()
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_deleted bigint;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Accès refusé : réservé aux administrateurs';
  END IF;

  WITH d AS (
    DELETE FROM public.logs_systeme
    WHERE created_at < (now() - interval '1 year')
    RETURNING 1
  )
  SELECT count(*) INTO v_deleted FROM d;

  -- On logge la suppression (méta-log)
  INSERT INTO public.logs_systeme (
    type_erreur, message, utilisateur_nom, action, table_name,
    user_id, created_at
  )
  VALUES (
    'maintenance',
    'Nettoyage manuel : ' || v_deleted || ' log(s) supprimé(s) (> 1 an)',
    (SELECT COALESCE(prenom_nom, 'Admin') FROM public.profils WHERE id = auth.uid()),
    'maintenance',
    'logs_systeme',
    auth.uid(),
    now()
  );

  RETURN v_deleted;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_expired_logs() TO authenticated;


-- ============================================================================
-- VÉRIFICATIONS — à exécuter individuellement après le script
-- ============================================================================

-- Vérifier que les colonnes ont été ajoutées :
-- SELECT column_name, data_type FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'logs_systeme'
-- ORDER BY ordinal_position;

-- Vérifier que les triggers sont bien en place :
-- SELECT tgname, tgrelid::regclass FROM pg_trigger
-- WHERE tgname LIKE 'trg_audit_%' AND NOT tgisinternal
-- ORDER BY tgname;

-- Compter les logs > 1 an :
-- SELECT public.count_logs_expired();

-- Tester un log (en INSÉRANT manuellement une facture) puis :
-- SELECT created_at, action, table_name, doc_id, utilisateur_nom, message
-- FROM public.logs_systeme ORDER BY created_at DESC LIMIT 10;
