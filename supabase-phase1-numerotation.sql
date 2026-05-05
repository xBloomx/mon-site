-- ============================================================================
-- PHASE 1 : Numérotation auto pour les factures (VERSION CORRIGÉE)
-- ============================================================================
-- À exécuter dans Supabase SQL Editor.
-- Cette version corrige l'erreur "identity column type must be bigint".
-- ============================================================================

-- 1. Vider les factures de test
DELETE FROM public.factures;

-- 2. Retirer la propriété "identity" (auto-incrément) avant changement de type
ALTER TABLE public.factures ALTER COLUMN id DROP IDENTITY IF EXISTS;

-- 3. Changer le type d'ID de bigint à text (pour stocker F-0001, F-0002...)
ALTER TABLE public.factures DROP CONSTRAINT IF EXISTS factures_pkey;
ALTER TABLE public.factures ALTER COLUMN id TYPE text USING id::text;
ALTER TABLE public.factures ADD PRIMARY KEY (id);

-- 4. Fonction de génération du prochain numéro
-- Cherche le plus grand F-XXXX existant et retourne le suivant.
-- Atomique grâce au LOCK : pas de doublon possible.
CREATE OR REPLACE FUNCTION public.next_facture_number()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  next_num int;
BEGIN
  LOCK TABLE public.factures IN EXCLUSIVE MODE;

  SELECT COALESCE(MAX(
    CASE
      WHEN id ~ '^F-[0-9]+$' THEN substring(id from 3)::int
      ELSE 0
    END
  ), 0) + 1
  INTO next_num
  FROM public.factures;

  RETURN 'F-' || lpad(next_num::text, 4, '0');
END;
$$;

GRANT EXECUTE ON FUNCTION public.next_facture_number() TO authenticated;

-- 5. Vérifications
SELECT 
  column_name, 
  data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'factures' 
  AND column_name = 'id';

SELECT public.next_facture_number() AS prochain_numero;

SELECT COUNT(*) AS nb_factures_restantes FROM public.factures;
