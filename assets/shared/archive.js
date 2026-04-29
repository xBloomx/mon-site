/* =========================================================================
   archive.js — Soft delete & archivage (Phase 2)
   =========================================================================
   API publique exposée sur window.ArchiveFD :

     ArchiveFD.archive(table, id, options)
        → Marque le document comme archivé (is_archived = true).
        → table : 'factures' | 'soumissions' | 'feuilles_de_temps'
        → options : { reason: string|null, supabaseClient, currentUserId, currentUserName }
        → Retourne { success: bool, error: string|null }

     ArchiveFD.restore(table, id, options)
        → Restaure un document archivé (is_archived = false).
        → A0 uniquement (le RLS le bloquera de toute façon).
        → options : { supabaseClient }
        → Retourne { success: bool, error: string|null }

     ArchiveFD.canArchive(item, role, currentUserId)
        → Détermine si l'utilisateur courant peut archiver ce document.
        → Renvoie { allowed: bool, needsStrongConfirm: bool, reason: string }
        → Règles :
          - A3 : seulement ses brouillons (status === 'brouillon' ET authorId === currentUserId)
          - A2 : interdit (jamais)
          - A1 : peut tout, mais needsStrongConfirm si statut envoyé/traité/payé
          - A0 : peut tout, mais needsStrongConfirm si statut envoyé/traité/payé

     ArchiveFD.canSeeAllArchives(role)
        → true si A0/A1, false sinon. Détermine si l'onglet Archives montre
          uniquement les archives de l'utilisateur ou toutes.

     ArchiveFD.canRestore(role)
        → true si A0 uniquement.

     ArchiveFD.confirmAndArchive({ table, id, item, role, currentUserId,
                                   currentUserName, supabaseClient,
                                   onSuccess })
        → Helper haut-niveau : affiche le bon modal de confirmation
          (simple ou fort), demande optionnellement une raison, lance
          l'archivage, et appelle onSuccess() en cas de réussite.
   ========================================================================= */

(function() {
    'use strict';

    // ----------------------------------------------------------------------
    // Constantes
    // ----------------------------------------------------------------------
    const STATUSES_NEEDING_STRONG_CONFIRM = [
        'envoye', 'envoyé',
        'traite', 'traité', 'paye', 'payé',
        'En attente', 'Convertie',
        'approuve', 'approuvé'
    ];

    // ----------------------------------------------------------------------
    // Décisions de permission
    // ----------------------------------------------------------------------
    function canArchive(item, role, currentUserId) {
        if (!item) return { allowed: false, needsStrongConfirm: false, reason: 'Document introuvable' };

        const status = (item.status || 'brouillon').toString();
        const isAuthor = item.authorId === currentUserId;

        // A2 : aucun droit d'archivage
        if (role === 'A2') {
            return { allowed: false, needsStrongConfirm: false, reason: "Votre rôle ne permet pas d'archiver" };
        }

        // A3 : seulement ses propres brouillons
        if (role === 'A3') {
            if (!isAuthor) return { allowed: false, needsStrongConfirm: false, reason: "Vous n'êtes pas l'auteur de ce document" };
            if (status !== 'brouillon') return { allowed: false, needsStrongConfirm: false, reason: 'Votre rôle ne permet d\'archiver que les brouillons' };
            return { allowed: true, needsStrongConfirm: false, reason: '' };
        }

        // A0/A1 : peuvent tout archiver, confirmation forte si statut "engagé"
        if (role === 'A0' || role === 'A1') {
            const needsStrong = STATUSES_NEEDING_STRONG_CONFIRM.includes(status);
            return { allowed: true, needsStrongConfirm: needsStrong, reason: '' };
        }

        // Rôles inconnus (A4, A5...) : refus par défaut, l'admin pourra
        // étendre ce comportement plus tard.
        return { allowed: false, needsStrongConfirm: false, reason: 'Rôle non autorisé' };
    }

    function canSeeAllArchives(role) {
        return role === 'A0' || role === 'A1';
    }

    function canRestore(role) {
        return role === 'A0';
    }

    // ----------------------------------------------------------------------
    // Opérations DB
    // ----------------------------------------------------------------------
    async function archive(table, id, options) {
        if (!options || !options.supabaseClient) {
            return { success: false, error: 'supabaseClient manquant' };
        }
        const payload = {
            is_archived: true,
            archived_at: new Date().toISOString(),
            archived_by: options.currentUserId || null,
            archived_by_name: options.currentUserName || null,
            archive_reason: options.reason || null
        };
        const { error } = await options.supabaseClient
            .from(table)
            .update(payload)
            .eq('id', id);

        if (error) return { success: false, error: error.message };
        return { success: true, error: null };
    }

    async function restore(table, id, options) {
        if (!options || !options.supabaseClient) {
            return { success: false, error: 'supabaseClient manquant' };
        }
        const payload = {
            is_archived: false,
            archived_at: null,
            archived_by: null,
            archived_by_name: null,
            archive_reason: null
        };
        const { error } = await options.supabaseClient
            .from(table)
            .update(payload)
            .eq('id', id);

        if (error) return { success: false, error: error.message };
        return { success: true, error: null };
    }

    // ----------------------------------------------------------------------
    // Helper haut-niveau : confirmation + archivage en une étape
    // ----------------------------------------------------------------------
    // Suppose que les fonctions globales suivantes existent dans la page :
    //   - showConfirm(message, onConfirm, [titleOrButtonText])
    //   - showAlert(messageHTML)
    //   - showToast(message, type) (optionnel — vient de shared.js)
    function confirmAndArchive(opts) {
        const { table, id, item, role, currentUserId, currentUserName,
                supabaseClient, onSuccess } = opts;

        const verdict = canArchive(item, role, currentUserId);
        if (!verdict.allowed) {
            if (typeof showAlert === 'function') {
                showAlert("❌ " + verdict.reason);
            }
            return;
        }

        const docLabel = '#' + id;
        let msg;
        if (verdict.needsStrongConfirm) {
            msg = "⚠️ Cette opération concerne un document déjà <b>traité ou envoyé</b> ("
                + docLabel + ")." +
                "<br><br>Le document sera déplacé dans les <b>Archives</b>." +
                "<br>Vous pourrez le restaurer pendant <b>1 an</b> (admin uniquement)." +
                "<br><br>Confirmer la suppression ?";
        } else {
            msg = "Le document " + docLabel + " sera déplacé dans les <b>Archives</b>." +
                "<br>Vous pourrez le restaurer pendant <b>1 an</b> (admin uniquement)." +
                "<br><br>Confirmer ?";
        }

        if (typeof showConfirm !== 'function') {
            console.error('[archive] showConfirm() introuvable dans la page');
            return;
        }

        showConfirm(msg, async function() {
            const res = await archive(table, id, {
                supabaseClient: supabaseClient,
                currentUserId: currentUserId,
                currentUserName: currentUserName,
                reason: null
            });
            if (!res.success) {
                if (typeof showAlert === 'function') {
                    showAlert("❌ Erreur d'archivage : " + res.error);
                }
                return;
            }
            if (typeof window.showToast === 'function') {
                window.showToast('Document archivé', 'info', 3000);
            }
            if (typeof onSuccess === 'function') onSuccess();
        }, "Supprimer");
    }

    // ----------------------------------------------------------------------
    // Confirmation + restauration (A0 only)
    // ----------------------------------------------------------------------
    function confirmAndRestore(opts) {
        const { table, id, role, supabaseClient, onSuccess } = opts;

        if (!canRestore(role)) {
            if (typeof showAlert === 'function') {
                showAlert("❌ La restauration est réservée à l'administrateur (A0).");
            }
            return;
        }

        const msg = "Restaurer le document <b>#" + id + "</b> depuis les archives ?<br>" +
                    "<small style='color:#aaa;'>Il redeviendra visible dans la liste normale.</small>";

        if (typeof showConfirm !== 'function') {
            console.error('[archive] showConfirm() introuvable dans la page');
            return;
        }

        showConfirm(msg, async function() {
            const res = await restore(table, id, { supabaseClient: supabaseClient });
            if (!res.success) {
                if (typeof showAlert === 'function') {
                    showAlert("❌ Erreur de restauration : " + res.error);
                }
                return;
            }
            if (typeof window.showToast === 'function') {
                window.showToast('Document restauré', 'success', 3000);
            }
            if (typeof onSuccess === 'function') onSuccess();
        }, "Restaurer");
    }

    // ----------------------------------------------------------------------
    // Export global
    // ----------------------------------------------------------------------
    window.ArchiveFD = {
        archive: archive,
        restore: restore,
        canArchive: canArchive,
        canSeeAllArchives: canSeeAllArchives,
        canRestore: canRestore,
        confirmAndArchive: confirmAndArchive,
        confirmAndRestore: confirmAndRestore
    };
})();
