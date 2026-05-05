-- ============================================================================
-- supabase-fix-factures-papier.sql
-- Ajout du système de factures papier (photos scannées au lieu du formulaire)
-- ============================================================================
--
-- CONTEXTE :
-- L'employé sur le terrain peut envoyer une facture papier au bureau en
-- prenant des photos (1 par page) au lieu de la remplir dans l'app.
-- Le bureau la traite ensuite comme une facture normale.
--
-- IDEMPOTENT : peut être relancé plusieurs fois sans problème.
-- ============================================================================

-- 1. Colonnes pour distinguer les factures papier
ALTER TABLE public.factures
    ADD COLUMN IF NOT EXISTS is_paper BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS paper_pages JSONB NULL;

-- paper_pages : tableau d'objets [{url: '...', name: '...'}, ...] décrivant
-- les images téléversées (1 par page de la facture papier)
-- Exemple : [{"url": "https://...page1.jpg", "name": "page1.jpg"},
--            {"url": "https://...page2.jpg", "name": "page2.jpg"}]

-- 2. Index pour trouver rapidement les factures papier en boîte de réception
CREATE INDEX IF NOT EXISTS idx_factures_is_paper
    ON public.factures (is_paper)
    WHERE is_paper = TRUE;

-- ============================================================================
-- Vérification (à exécuter manuellement après) :
--
-- SELECT column_name, data_type
-- FROM information_schema.columns
-- WHERE table_name = 'factures'
--   AND column_name IN ('is_paper', 'paper_pages');
--
-- Doit retourner 2 lignes.
-- ============================================================================
