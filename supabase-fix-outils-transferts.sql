-- ============================================================================
-- supabase-fix-outils-transferts.sql
-- Ajout du système de transfert d'outils avec confirmation par le destinataire
-- ============================================================================
--
-- CONTEXTE :
-- Quand un employé veut transférer un outil à un collègue, le destinataire
-- doit confirmer la réception ET indiquer le nouveau lieu de l'outil.
-- En attendant, l'outil reste assigné à l'employé d'origine.
--
-- Ce script ajoute 2 colonnes :
--   - pending_transfer_to   : nom du destinataire en attente
--   - pending_transfer_at   : timestamp de la demande
--
-- IDEMPOTENT : peut être relancé plusieurs fois sans problème.
-- ============================================================================

-- 1. Ajouter les colonnes (si elles n'existent pas déjà)
ALTER TABLE public.outils
    ADD COLUMN IF NOT EXISTS pending_transfer_to TEXT NULL,
    ADD COLUMN IF NOT EXISTS pending_transfer_at TIMESTAMPTZ NULL;

-- 2. Index pour accélérer la recherche des transferts en attente par destinataire
CREATE INDEX IF NOT EXISTS idx_outils_pending_transfer_to
    ON public.outils (pending_transfer_to)
    WHERE pending_transfer_to IS NOT NULL;

-- ============================================================================
-- Vérification (à exécuter manuellement après) :
--
-- SELECT column_name, data_type, is_nullable
-- FROM information_schema.columns
-- WHERE table_name = 'outils'
--   AND column_name IN ('pending_transfer_to', 'pending_transfer_at');
--
-- Doit retourner 2 lignes.
-- ============================================================================
