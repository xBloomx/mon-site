-- ============================================================================
-- SCRIPT DE SÉCURISATION RLS — F.Dussault
-- ============================================================================
-- À exécuter dans : Supabase Dashboard → SQL Editor → New query
-- DURÉE : ~10 secondes
-- IMPACT : sécurise toutes les tables et applique le système de rôles A0/A1/A2/A3
--
-- ⚠️ AVANT D'EXÉCUTER :
--   1. Faire un backup (Database → Backups)
--   2. Vérifier que tu connais le rôle de ton compte (idéalement A0)
--   3. Tester sur un compte de chaque rôle après exécution
--
-- Le script est idempotent : tu peux le relancer sans problème,
-- il supprime et recrée les policies à chaque fois.
-- ============================================================================


-- ============================================================================
-- ÉTAPE 1 : NETTOYAGE — Supprimer la colonne mot_de_passe_clair
-- ============================================================================
-- Cette colonne stockait des mots de passe en clair, ce qui est dangereux.
-- Supabase Auth gère les mots de passe de façon sécurisée (hash bcrypt) dans
-- auth.users — on n'a JAMAIS besoin de les stocker en clair ailleurs.

ALTER TABLE public.profils DROP COLUMN IF EXISTS mot_de_passe_clair;


-- ============================================================================
-- ÉTAPE 2 : ACTIVER RLS PARTOUT
-- ============================================================================
-- profils n'avait pas RLS, on l'active.
-- Les autres tables ont déjà RLS, on s'assure juste que c'est bien le cas.

ALTER TABLE public.profils ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.logs_systeme ENABLE ROW LEVEL SECURITY;


-- ============================================================================
-- ÉTAPE 3 : FONCTIONS HELPER — Système de permissions flexible
-- ============================================================================
-- Ces fonctions permettent d'écrire des policies courtes et lisibles,
-- et surtout de modifier les permissions sans toucher aux policies.
--
-- SECURITY DEFINER = la fonction s'exécute avec les droits de son créateur
-- STABLE = la fonction retourne le même résultat dans la même requête (cache)

-- Récupère le rôle de l'utilisateur connecté
CREATE OR REPLACE FUNCTION public.current_user_role()
RETURNS text
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT role FROM public.profils WHERE id = auth.uid();
$$;

-- Vérifie si l'utilisateur est super admin (A0)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
  SELECT (SELECT role FROM public.profils WHERE id = auth.uid()) = 'A0';
$$;

-- Vérifie si l'utilisateur a une permission donnée
-- Lit la config dynamique dans parametres_globaux (clé 'roles_config')
-- Fallback sur une config par défaut si la clé n'existe pas
CREATE OR REPLACE FUNCTION public.user_has_permission(perm text)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
SET search_path = public
AS $$
DECLARE
  user_role text;
  roles_config jsonb;
  perms_array jsonb;
BEGIN
  -- A0 = super admin = tout autorisé sans question
  user_role := (SELECT role FROM public.profils WHERE id = auth.uid());
  IF user_role IS NULL THEN
    RETURN false;
  END IF;
  IF user_role = 'A0' THEN
    RETURN true;
  END IF;

  -- Lit la config des rôles depuis parametres_globaux
  SELECT valeur::jsonb INTO roles_config
  FROM public.parametres_globaux
  WHERE cle = 'roles_config'
  LIMIT 1;

  -- Si pas de config en DB, on utilise un fallback hardcodé
  -- (correspond à defaultRolesConfig dans code_admin.html)
  IF roles_config IS NULL THEN
    roles_config := '{
      "A1": {"perms": ["view_all_invoices","view_all_po","access_po_tab","access_soumissions_tab","access_courriel_tab","approve_timesheets","manage_tools","transfer_tools","create_clients","delete_clients","manage_calendar","manage_news","view_admin","manage_suppliers","view_archives_all","delete_documents"]},
      "A2": {"perms": ["view_all_invoices","view_all_po","access_po_tab","access_soumissions_tab","access_courriel_tab","approve_timesheets","manage_tools","create_clients","delete_clients","manage_calendar","manage_news"]},
      "A3": {"perms": ["transfer_tools","access_po_tab","access_soumissions_tab","create_clients"]}
    }'::jsonb;
  END IF;

  perms_array := roles_config -> user_role -> 'perms';
  IF perms_array IS NULL THEN
    RETURN false;
  END IF;

  RETURN perms_array ? perm;
END;
$$;

-- Donner les droits d'exécution aux utilisateurs authentifiés
GRANT EXECUTE ON FUNCTION public.current_user_role() TO authenticated;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.user_has_permission(text) TO authenticated;


-- ============================================================================
-- ÉTAPE 4 : TRIGGER ANTI-PROMOTION — Empêcher de modifier son propre rôle
-- ============================================================================
-- Sans ça, n'importe quel utilisateur pourrait faire :
--   UPDATE profils SET role = 'A0' WHERE id = auth.uid();
-- et devenir admin instantanément.

CREATE OR REPLACE FUNCTION public.prevent_self_role_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Si quelqu'un essaie de changer le rôle d'un profil ET ce n'est pas A0
  IF OLD.role IS DISTINCT FROM NEW.role THEN
    IF NOT public.is_admin() THEN
      RAISE EXCEPTION 'Seul un super admin (A0) peut modifier les rôles';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_prevent_self_role_change ON public.profils;
CREATE TRIGGER trg_prevent_self_role_change
  BEFORE UPDATE ON public.profils
  FOR EACH ROW
  EXECUTE FUNCTION public.prevent_self_role_change();


-- ============================================================================
-- ÉTAPE 5 : SUPPRIMER TOUTES LES ANCIENNES POLICIES
-- ============================================================================
-- On part de zéro pour éviter les conflits ou doublons.

DO $$
DECLARE
  pol RECORD;
BEGIN
  FOR pol IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON %I.%I',
                   pol.policyname, pol.schemaname, pol.tablename);
  END LOOP;
END $$;


-- ============================================================================
-- ÉTAPE 6 : POLICIES — TABLE profils
-- ============================================================================
-- Lecture : tout utilisateur authentifié peut voir la liste des collègues
-- (nécessaire pour collaboration : messagerie, calendriers partagés, transfert
-- d'outils, partage d'événements). Les UPDATE/DELETE restent strictes.
-- L'utilisateur ne peut MODIFIER que son propre profil (et le rôle reste
-- protégé par un trigger anti-promotion).
CREATE POLICY "profils_select_own_or_admin"
  ON public.profils FOR SELECT
  TO authenticated
  USING (true);

-- Insertion : seul l'admin peut créer un profil (les profils sont créés via Auth normalement)
CREATE POLICY "profils_insert_admin_only"
  ON public.profils FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

-- Modification : chacun peut modifier son propre profil (mais pas son rôle, le trigger bloque)
-- L'admin peut tout modifier
CREATE POLICY "profils_update_own_or_admin"
  ON public.profils FOR UPDATE
  TO authenticated
  USING (id = auth.uid() OR public.is_admin())
  WITH CHECK (id = auth.uid() OR public.is_admin());

-- Suppression : admin uniquement
CREATE POLICY "profils_delete_admin_only"
  ON public.profils FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ============================================================================
-- ÉTAPE 7 : POLICIES — TABLE factures
-- ============================================================================
-- A3 voit ses propres factures, A1/A2 voient tout (perm view_all_invoices)
CREATE POLICY "factures_select"
  ON public.factures FOR SELECT
  TO authenticated
  USING (
    author_id = auth.uid()
    OR public.user_has_permission('view_all_invoices')
  );

-- Tout authentifié peut créer (avec son propre author_id)
CREATE POLICY "factures_insert"
  ON public.factures FOR INSERT
  TO authenticated
  WITH CHECK (author_id = auth.uid());

-- Auteur peut modifier les siennes, admin/gestion peut tout modifier
CREATE POLICY "factures_update"
  ON public.factures FOR UPDATE
  TO authenticated
  USING (
    author_id = auth.uid()
    OR public.user_has_permission('view_all_invoices')
  )
  WITH CHECK (
    author_id = auth.uid()
    OR public.user_has_permission('view_all_invoices')
  );

-- Suppression : seulement A0/A1/A2 (perm delete_documents)
CREATE POLICY "factures_delete"
  ON public.factures FOR DELETE
  TO authenticated
  USING (public.user_has_permission('delete_documents'));


-- ============================================================================
-- ÉTAPE 8 : POLICIES — TABLE soumissions
-- ============================================================================
CREATE POLICY "soumissions_select"
  ON public.soumissions FOR SELECT
  TO authenticated
  USING (
    author_id = auth.uid()
    OR public.user_has_permission('view_all_invoices')
  );

CREATE POLICY "soumissions_insert"
  ON public.soumissions FOR INSERT
  TO authenticated
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "soumissions_update"
  ON public.soumissions FOR UPDATE
  TO authenticated
  USING (
    author_id = auth.uid()
    OR public.user_has_permission('view_all_invoices')
  )
  WITH CHECK (
    author_id = auth.uid()
    OR public.user_has_permission('view_all_invoices')
  );

CREATE POLICY "soumissions_delete"
  ON public.soumissions FOR DELETE
  TO authenticated
  USING (public.user_has_permission('delete_documents'));


-- ============================================================================
-- ÉTAPE 9 : POLICIES — TABLE feuilles_de_temps
-- ============================================================================
CREATE POLICY "feuilles_de_temps_select"
  ON public.feuilles_de_temps FOR SELECT
  TO authenticated
  USING (
    author_id = auth.uid()
    OR public.user_has_permission('approve_timesheets')
  );

CREATE POLICY "feuilles_de_temps_insert"
  ON public.feuilles_de_temps FOR INSERT
  TO authenticated
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "feuilles_de_temps_update"
  ON public.feuilles_de_temps FOR UPDATE
  TO authenticated
  USING (
    author_id = auth.uid()
    OR public.user_has_permission('approve_timesheets')
  )
  WITH CHECK (
    author_id = auth.uid()
    OR public.user_has_permission('approve_timesheets')
  );

CREATE POLICY "feuilles_de_temps_delete"
  ON public.feuilles_de_temps FOR DELETE
  TO authenticated
  USING (public.user_has_permission('delete_documents'));


-- ============================================================================
-- ÉTAPE 10 : POLICIES — TABLE bons_de_commande
-- ============================================================================
CREATE POLICY "bons_de_commande_select"
  ON public.bons_de_commande FOR SELECT
  TO authenticated
  USING (
    author_id = auth.uid()
    OR public.user_has_permission('view_all_po')
  );

CREATE POLICY "bons_de_commande_insert"
  ON public.bons_de_commande FOR INSERT
  TO authenticated
  WITH CHECK (
    author_id = auth.uid()
    AND public.user_has_permission('access_po_tab')
  );

CREATE POLICY "bons_de_commande_update"
  ON public.bons_de_commande FOR UPDATE
  TO authenticated
  USING (
    author_id = auth.uid()
    OR public.user_has_permission('view_all_po')
  )
  WITH CHECK (
    author_id = auth.uid()
    OR public.user_has_permission('view_all_po')
  );

CREATE POLICY "bons_de_commande_delete"
  ON public.bons_de_commande FOR DELETE
  TO authenticated
  USING (public.user_has_permission('delete_documents'));


-- ============================================================================
-- ÉTAPE 11 : POLICIES — TABLE clients
-- ============================================================================
-- Tout authentifié peut consulter et modifier les clients (besoin métier)
-- Mais seuls A0/A1 (delete_clients) peuvent supprimer définitivement
CREATE POLICY "clients_select"
  ON public.clients FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "clients_insert"
  ON public.clients FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "clients_update"
  ON public.clients FOR UPDATE
  TO authenticated
  USING (true)
  WITH CHECK (true);

CREATE POLICY "clients_delete"
  ON public.clients FOR DELETE
  TO authenticated
  USING (public.user_has_permission('delete_clients'));


-- ============================================================================
-- ÉTAPE 12 : POLICIES — TABLE outils
-- ============================================================================
-- Lecture : tous
-- Modification : selon perm manage_tools (A0/A1/A2) ou transfer_tools (tous + A3)
CREATE POLICY "outils_select"
  ON public.outils FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "outils_insert"
  ON public.outils FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "outils_update"
  ON public.outils FOR UPDATE
  TO authenticated
  USING (
    public.user_has_permission('manage_tools')
    OR public.user_has_permission('transfer_tools')
  )
  WITH CHECK (
    public.user_has_permission('manage_tools')
    OR public.user_has_permission('transfer_tools')
  );

CREATE POLICY "outils_delete"
  ON public.outils FOR DELETE
  TO authenticated
  USING (public.user_has_permission('manage_tools'));


-- ============================================================================
-- ÉTAPE 13 : POLICIES — TABLE annonces
-- ============================================================================
CREATE POLICY "annonces_select"
  ON public.annonces FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "annonces_insert"
  ON public.annonces FOR INSERT
  TO authenticated
  WITH CHECK (public.user_has_permission('manage_news'));

CREATE POLICY "annonces_update"
  ON public.annonces FOR UPDATE
  TO authenticated
  USING (public.user_has_permission('manage_news'))
  WITH CHECK (public.user_has_permission('manage_news'));

CREATE POLICY "annonces_delete"
  ON public.annonces FOR DELETE
  TO authenticated
  USING (public.user_has_permission('manage_news'));


-- ============================================================================
-- ÉTAPE 14 : POLICIES — TABLE message (messagerie)
-- ============================================================================
-- chat_id format : "userA_userB" (les 2 ids triés alphabétiquement)
-- L'utilisateur peut voir un message s'il est dans le chat_id
CREATE POLICY "message_select"
  ON public.message FOR SELECT
  TO authenticated
  USING (
    chat_id LIKE '%' || auth.uid()::text || '%'
    OR public.is_admin()
  );

CREATE POLICY "message_insert"
  ON public.message FOR INSERT
  TO authenticated
  WITH CHECK (
    expediteur_id = auth.uid()
    AND chat_id LIKE '%' || auth.uid()::text || '%'
  );

-- Modifier (réactions) : seul l'expéditeur ou si tu es dans le chat (réactions)
CREATE POLICY "message_update"
  ON public.message FOR UPDATE
  TO authenticated
  USING (chat_id LIKE '%' || auth.uid()::text || '%')
  WITH CHECK (chat_id LIKE '%' || auth.uid()::text || '%');

CREATE POLICY "message_delete"
  ON public.message FOR DELETE
  TO authenticated
  USING (expediteur_id = auth.uid() OR public.is_admin());


-- ============================================================================
-- ÉTAPE 15 : POLICIES — TABLE courriels
-- ============================================================================
-- Un utilisateur voit les courriels où il est expéditeur ou destinataire
CREATE POLICY "courriels_select"
  ON public.courriels FOR SELECT
  TO authenticated
  USING (
    auth.email() = expediteur
    OR auth.email() = destinataire
    OR public.is_admin()
  );

CREATE POLICY "courriels_insert"
  ON public.courriels FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.email() = expediteur
    AND public.user_has_permission('access_courriel_tab')
  );

CREATE POLICY "courriels_update"
  ON public.courriels FOR UPDATE
  TO authenticated
  USING (auth.email() = expediteur OR auth.email() = destinataire)
  WITH CHECK (auth.email() = expediteur OR auth.email() = destinataire);

CREATE POLICY "courriels_delete"
  ON public.courriels FOR DELETE
  TO authenticated
  USING (auth.email() = expediteur OR auth.email() = destinataire);


-- ============================================================================
-- ÉTAPE 16 : POLICIES — TABLE formations
-- ============================================================================
-- Chacun voit ses propres formations, l'admin voit tout
CREATE POLICY "formations_select"
  ON public.formations FOR SELECT
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());

CREATE POLICY "formations_insert"
  ON public.formations FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

CREATE POLICY "formations_update"
  ON public.formations FOR UPDATE
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin())
  WITH CHECK (user_id = auth.uid() OR public.is_admin());

CREATE POLICY "formations_delete"
  ON public.formations FOR DELETE
  TO authenticated
  USING (user_id = auth.uid() OR public.is_admin());


-- ============================================================================
-- ÉTAPE 17 : POLICIES — TABLE parametres_globaux
-- ============================================================================
-- Tout le monde peut LIRE (besoin pour mode_maintenance, roles_config)
-- Mais seul l'admin peut écrire
CREATE POLICY "parametres_globaux_select"
  ON public.parametres_globaux FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "parametres_globaux_insert"
  ON public.parametres_globaux FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "parametres_globaux_update"
  ON public.parametres_globaux FOR UPDATE
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

CREATE POLICY "parametres_globaux_delete"
  ON public.parametres_globaux FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ============================================================================
-- ÉTAPE 18 : POLICIES — TABLE logs_systeme
-- ============================================================================
-- Lecture : admin uniquement
-- Insertion : tout authentifié peut logger ses actions
CREATE POLICY "logs_systeme_select"
  ON public.logs_systeme FOR SELECT
  TO authenticated
  USING (public.is_admin());

CREATE POLICY "logs_systeme_insert"
  ON public.logs_systeme FOR INSERT
  TO authenticated
  WITH CHECK (true);

CREATE POLICY "logs_systeme_delete"
  ON public.logs_systeme FOR DELETE
  TO authenticated
  USING (public.is_admin());


-- ============================================================================
-- ÉTAPE 19 : POLICIES — TABLE tickets_support
-- ============================================================================
-- Chacun voit ses propres tickets, l'admin voit tout
CREATE POLICY "tickets_support_select"
  ON public.tickets_support FOR SELECT
  TO authenticated
  USING (author_id = auth.uid() OR public.is_admin());

CREATE POLICY "tickets_support_insert"
  ON public.tickets_support FOR INSERT
  TO authenticated
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "tickets_support_update"
  ON public.tickets_support FOR UPDATE
  TO authenticated
  USING (author_id = auth.uid() OR public.is_admin())
  WITH CHECK (author_id = auth.uid() OR public.is_admin());

CREATE POLICY "tickets_support_delete"
  ON public.tickets_support FOR DELETE
  TO authenticated
  USING (author_id = auth.uid() OR public.is_admin());


-- ============================================================================
-- ÉTAPE 20 : VÉRIFICATION FINALE
-- ============================================================================
-- Cette requête te montre l'état après exécution.
-- Tu devrais voir RLS=true partout et au moins 3-4 policies par table.

SELECT 
  t.tablename,
  t.rowsecurity AS rls_active,
  (SELECT count(*) FROM pg_policies p WHERE p.tablename = t.tablename AND p.schemaname = 'public') AS nb_policies
FROM pg_tables t
WHERE t.schemaname = 'public'
ORDER BY t.tablename;


-- ============================================================================
-- FIN DU SCRIPT
-- ============================================================================
-- Si tu vois ce commentaire dans le résultat, tout s'est bien passé.
-- Teste avec un compte de chaque rôle pour vérifier le comportement.
