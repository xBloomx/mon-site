-- ============================================================================
-- supabase-fix-schemas.sql
-- Correctifs de schéma : aligner les tables Supabase avec ce que le code envoie
-- ============================================================================
-- 
-- CONTEXTE :
-- Au cours du développement, le code JS et les schémas DB ont divergé :
-- 
-- 1. La table 'soumissions' a une colonne 'id' de type bigint (entier)
--    mais le code envoie des IDs comme "S-8796" (texte). Erreur :
--    invalid input syntax for type bigint: "S-8796"
--    → Mêmes corrections qu'on a faites pour 'factures' en Phase 1.
-- 
-- 2. La table 'feuilles_de_temps' n'a pas la colonne 'employe_nom'
--    (probablement nommée 'employe' à l'origine). Erreur :
--    Could not find the 'employe_nom' column of 'feuilles_de_temps'
--    → On ajoute la colonne ou on la renomme selon ce qui existe.
-- 
-- ⚠️ AVANT D'EXÉCUTER :
-- - Tu m'as confirmé que tu n'as AUCUNE feuille de temps importante
-- - Le SQL VIDE 'soumissions' et 'feuilles_de_temps' avant correction
--   (parce qu'on change le type de colonne, données pas convertibles)
-- - Si tu as des soumissions/feuilles importantes, NE PAS exécuter
-- 
-- Le script est IDEMPOTENT : il peut être relancé sans problème.
-- ============================================================================

-- ============================================================================
-- 1. SOUMISSIONS : id bigint → text (comme on l'a fait pour factures)
-- ============================================================================

-- a. Vider la table (les données ne sont pas convertibles entre bigint et text S-XXXX)
DELETE FROM public.soumissions;

-- b. Retirer la propriété "identity" (auto-incrément) avant changement de type
ALTER TABLE public.soumissions ALTER COLUMN id DROP IDENTITY IF EXISTS;

-- c. Changer le type d'ID
ALTER TABLE public.soumissions DROP CONSTRAINT IF EXISTS soumissions_pkey;
ALTER TABLE public.soumissions ALTER COLUMN id TYPE text USING id::text;
ALTER TABLE public.soumissions ADD PRIMARY KEY (id);


-- ============================================================================
-- 2. FEUILLES_DE_TEMPS : ajouter la colonne employe_nom
-- ============================================================================

-- a. Vider la table (au cas où il y aurait des entrées de test)
DELETE FROM public.feuilles_de_temps;

-- b. Stratégie en 2 temps pour gérer 3 cas possibles :
--    - La colonne 'employe_nom' existe déjà → ne rien faire
--    - La colonne 's'appelle 'employe' → la renommer en 'employe_nom'
--    - Aucune des deux n'existe → créer 'employe_nom'

DO $$
BEGIN
    -- Si 'employe_nom' n'existe pas
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'feuilles_de_temps'
          AND column_name = 'employe_nom'
    ) THEN
        -- Si 'employe' existe → renommer
        IF EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'feuilles_de_temps'
              AND column_name = 'employe'
        ) THEN
            ALTER TABLE public.feuilles_de_temps RENAME COLUMN employe TO employe_nom;
            RAISE NOTICE '✓ Colonne renommée : employe → employe_nom';
        ELSE
            -- Sinon créer
            ALTER TABLE public.feuilles_de_temps ADD COLUMN employe_nom text;
            RAISE NOTICE '✓ Colonne ajoutée : employe_nom (text)';
        END IF;
    ELSE
        RAISE NOTICE '✓ Colonne employe_nom existe déjà — rien à faire';
    END IF;
END $$;


-- ============================================================================
-- 3. BONS_DE_COMMANDE : vérifier que id est bien text (pour PO-XXXXXX-XXXX)
-- ============================================================================

DO $$
DECLARE
    id_type text;
BEGIN
    SELECT data_type INTO id_type
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'bons_de_commande'
      AND column_name = 'id';

    IF id_type = 'bigint' THEN
        -- Si jamais l'id est bigint, on le change en text
        DELETE FROM public.bons_de_commande;
        EXECUTE 'ALTER TABLE public.bons_de_commande ALTER COLUMN id DROP IDENTITY IF EXISTS';
        EXECUTE 'ALTER TABLE public.bons_de_commande DROP CONSTRAINT IF EXISTS bons_de_commande_pkey';
        EXECUTE 'ALTER TABLE public.bons_de_commande ALTER COLUMN id TYPE text USING id::text';
        EXECUTE 'ALTER TABLE public.bons_de_commande ADD PRIMARY KEY (id)';
        RAISE NOTICE '✓ bons_de_commande.id changé de bigint à text';
    ELSE
        RAISE NOTICE '✓ bons_de_commande.id est déjà de type %', COALESCE(id_type, 'inconnu');
    END IF;
END $$;


-- ============================================================================
-- 4. VÉRIFICATIONS FINALES
-- ============================================================================

-- Type des colonnes id
SELECT
    table_name,
    data_type AS id_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND column_name = 'id'
  AND table_name IN ('factures', 'soumissions', 'feuilles_de_temps', 'bons_de_commande')
ORDER BY table_name;

-- Vérifier que employe_nom existe maintenant
SELECT
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'feuilles_de_temps'
  AND column_name IN ('employe_nom', 'employe')
ORDER BY column_name;

-- Compter les lignes restantes (devrait être 0 sur soumissions et feuilles_de_temps)
SELECT 'soumissions' AS tbl, COUNT(*) AS rows FROM public.soumissions
UNION ALL
SELECT 'feuilles_de_temps', COUNT(*) FROM public.feuilles_de_temps;
