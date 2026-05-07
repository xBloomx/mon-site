-- ============================================================================
-- supabase-fix-colonnes-manquantes.sql
-- Ajoute les colonnes d'archivage manquantes sur feuilles_de_temps et clients,
-- ainsi que is_archived sur clients pour le système d'archivage.
-- ============================================================================
-- IDEMPOTENT : peut être relancé plusieurs fois sans problème.
-- ============================================================================

-- ============================================================
-- TABLE : feuilles_de_temps
-- Colonnes manquantes : is_archived, archived_at, archived_by,
--                       archived_by_name, archive_reason
-- ============================================================
ALTER TABLE public.feuilles_de_temps
    ADD COLUMN IF NOT EXISTS is_archived    BOOLEAN     DEFAULT false,
    ADD COLUMN IF NOT EXISTS archived_at    TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS archived_by    UUID,
    ADD COLUMN IF NOT EXISTS archived_by_name TEXT,
    ADD COLUMN IF NOT EXISTS archive_reason TEXT,
    ADD COLUMN IF NOT EXISTS input_values   JSONB;

-- Index pour filtrer rapidement les archives vs non-archives
CREATE INDEX IF NOT EXISTS feuilles_de_temps_is_archived_idx
    ON public.feuilles_de_temps (is_archived);

-- ============================================================
-- TABLE : clients
-- Colonnes manquantes : is_archived, archived_at, archived_by,
--                       archived_by_name, archive_reason
-- ============================================================
ALTER TABLE public.clients
    ADD COLUMN IF NOT EXISTS is_archived    BOOLEAN     DEFAULT false,
    ADD COLUMN IF NOT EXISTS archived_at    TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS archived_by    UUID,
    ADD COLUMN IF NOT EXISTS archived_by_name TEXT,
    ADD COLUMN IF NOT EXISTS archive_reason TEXT;

CREATE INDEX IF NOT EXISTS clients_is_archived_idx
    ON public.clients (is_archived);

-- ============================================================
-- Vérification (à exécuter manuellement après) :
--
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name IN ('feuilles_de_temps', 'clients')
--   AND column_name LIKE '%archived%'
-- ORDER BY table_name, column_name;
--
-- Doit retourner is_archived, archived_at, archived_by,
-- archived_by_name, archive_reason pour chaque table.
-- ============================================================
