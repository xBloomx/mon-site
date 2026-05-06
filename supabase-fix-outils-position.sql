-- ============================================================================
-- supabase-fix-outils-position.sql
-- Ajoute une colonne 'position' à la table outils pour gérer l'ordre
-- d'affichage manuellement (drag & drop côté admin).
-- ============================================================================
-- IDEMPOTENT : peut être relancé plusieurs fois sans problème.
-- ============================================================================

-- 1. Ajouter la colonne position (sécurité : seulement si elle n'existe pas)
ALTER TABLE public.outils
  ADD COLUMN IF NOT EXISTS position INTEGER;

-- 2. Initialiser les positions pour les outils existants
-- On utilise l'ordre de création (created_at) pour ne pas bouleverser l'ordre actuel
WITH ordered AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY created_at ASC, id ASC) AS new_pos
    FROM public.outils
    WHERE position IS NULL
)
UPDATE public.outils o
SET position = ordered.new_pos * 10  -- multiplier par 10 pour laisser des "trous" entre positions
FROM ordered
WHERE o.id = ordered.id;

-- 3. Index pour accélérer le tri ORDER BY position
CREATE INDEX IF NOT EXISTS outils_position_idx ON public.outils (position);

-- ============================================================================
-- Vérification (optionnel, à exécuter manuellement après) :
--
-- SELECT id, nom, status, position
-- FROM public.outils
-- ORDER BY position ASC NULLS LAST, created_at ASC;
--
-- Doit retourner les outils dans l'ordre actuel avec des positions 10, 20, 30…
-- ============================================================================
