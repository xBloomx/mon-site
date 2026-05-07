-- ============================================================================
-- supabase-fix-trigger-audit-clients.sql
-- Corrige l'erreur :
--    Erreur lors de la suppression : record "new" has no field "input_values"
--
-- CAUSE : la fonction trigger d'audit `trg_audit_doc_changes()` (Phase 3)
-- accède directement à `NEW.input_values`, `NEW.is_archived`, `NEW.status`
-- sans vérifier que ces colonnes existent sur la table concernée. Or :
--   - `clients` n'a pas de `input_values` ni de `status`
--   - `bons_de_commande` peut ne pas avoir tous ces champs non plus
-- → tout UPDATE/INSERT/DELETE sur ces tables plante avec l'erreur ci-dessus.
--
-- SOLUTION : réécrire la fonction en utilisant `to_jsonb(NEW)` pour accéder
-- aux champs de manière dynamique. Si un champ n'existe pas sur la table,
-- on récupère NULL au lieu de planter.
-- ============================================================================
-- IDEMPOTENT : peut être relancé plusieurs fois sans problème.
-- ============================================================================

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

  -- Représentations JSONB pour accès dynamique sécurisé aux champs
  v_new_jsonb jsonb;
  v_old_jsonb jsonb;

  -- Variables extraites (NULL si la colonne n'existe pas sur la table)
  v_new_archived boolean;
  v_old_archived boolean;
  v_new_status   text;
  v_old_status   text;
  v_new_input    jsonb;
  v_old_input    jsonb;
BEGIN
  -- Récupérer l'ID du document (texte pour gérer F-0001, S-0042, etc.)
  IF (TG_OP = 'DELETE') THEN
    v_doc_id := OLD.id::text;
    v_old_jsonb := to_jsonb(OLD);
  ELSIF (TG_OP = 'INSERT') THEN
    v_doc_id := NEW.id::text;
    v_new_jsonb := to_jsonb(NEW);
  ELSE -- UPDATE
    v_doc_id := NEW.id::text;
    v_new_jsonb := to_jsonb(NEW);
    v_old_jsonb := to_jsonb(OLD);
  END IF;

  -- Déterminer l'action et le message selon le contexte
  IF (TG_OP = 'INSERT') THEN
    v_action  := 'creation';
    v_message := 'Création de ' || v_table || ' #' || v_doc_id;

  ELSIF (TG_OP = 'DELETE') THEN
    v_action  := 'suppression';
    v_message := 'SUPPRESSION DÉFINITIVE de ' || v_table || ' #' || v_doc_id;

  ELSIF (TG_OP = 'UPDATE') THEN
    -- Extraire les champs susceptibles d'être présents (NULL si absents)
    v_new_archived := (v_new_jsonb ->> 'is_archived')::boolean;
    v_old_archived := (v_old_jsonb ->> 'is_archived')::boolean;
    v_new_status   := v_new_jsonb ->> 'status';
    v_old_status   := v_old_jsonb ->> 'status';
    v_new_input    := v_new_jsonb -> 'input_values';
    v_old_input    := v_old_jsonb -> 'input_values';

    -- Cas spéciaux : archivage et restauration sont déjà loggés par le trigger
    -- log_archivage de la Phase 2. On ne re-logge donc pas ici si seul
    -- is_archived a changé.
    IF (v_new_archived IS DISTINCT FROM v_old_archived)
       AND (
         v_new_jsonb - 'is_archived' - 'archived_at' - 'archived_by' - 'archived_by_name'
         IS NOT DISTINCT FROM
         v_old_jsonb - 'is_archived' - 'archived_at' - 'archived_by' - 'archived_by_name'
       ) THEN
      RETURN NEW; -- Skip : l'archivage/restauration est déjà logué
    END IF;

    -- Détection changement de statut (uniquement sur les tables concernées)
    IF (TG_TABLE_NAME IN ('factures', 'soumissions', 'feuilles_de_temps')
        AND v_new_status IS DISTINCT FROM v_old_status) THEN
      v_action  := 'modification';
      v_message := 'Statut de ' || v_table || ' #' || v_doc_id
                || ' : ' || COALESCE(v_old_status, 'NULL')
                || ' → ' || COALESCE(v_new_status, 'NULL');
      v_details := jsonb_build_object(
        'old_status', v_old_status,
        'new_status', v_new_status
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
EXCEPTION
  -- Filet de sécurité : si jamais quelque chose plante dans le trigger d'audit,
  -- on NE BLOQUE PAS l'opération métier. On retourne juste sans logger.
  WHEN OTHERS THEN
    RAISE WARNING 'trg_audit_doc_changes a échoué (%): %', SQLSTATE, SQLERRM;
    IF (TG_OP = 'DELETE') THEN
      RETURN OLD;
    ELSE
      RETURN NEW;
    END IF;
END;
$$;

GRANT EXECUTE ON FUNCTION public.trg_audit_doc_changes() TO authenticated;

-- ============================================================================
-- VÉRIFICATIONS (à lancer manuellement après) :
--
-- a) Test direct (remplace l'UUID par un vrai client) :
--    UPDATE public.clients SET est_supprime = true
--    WHERE id = 'UUID_DU_CLIENT' RETURNING id, nom, est_supprime;
--    → Doit retourner une ligne sans erreur.
--
-- b) Vérifier que le log d'audit a bien été inséré :
--    SELECT * FROM public.logs_systeme
--    WHERE table_name = 'clients'
--    ORDER BY created_at DESC LIMIT 5;
-- ============================================================================
