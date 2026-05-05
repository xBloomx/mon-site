<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no, viewport-fit=cover">
    <title>Messagerie F.Dussault</title>
    
    <script>
        if (window.self === window.top) { window.location.href = '../login.html'; }
    </script>
    
    <script src="../assets/shared/console-filter.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>
    <script src="../supabase-config.js"></script>
    <link rel="stylesheet" href="../assets/shared/shared.css">
    <script src="../assets/shared/shared.js"></script>
    <script type="module" src="https://cdn.jsdelivr.net/npm/emoji-picker-element@1/index.js"></script>

    <style>
        /* =========================================
           1. VARIABLES & THEME (F.Dussault Dark)
           ========================================= */
        body { 
            font-family: 'Segoe UI', Arial, sans-serif;
            background-color: var(--app-bg); 
            color: var(--text-light);
            margin: 0; padding: 0;
            height: 100vh;
            display: flex;
            overflow: hidden;
        }

        .main-content {
            flex: 1; display: flex; flex-direction: column; position: relative;
            background-color: var(--app-bg); overflow: hidden;
        }

        #view-dashboard { padding: 30px; height: 100%; overflow: hidden; display: flex; gap: 20px; }

/* =========================================
           2. BARRE LATÉRALE
           ========================================= */
        .chat-sidebar {
            width: 380px; background-color: var(--card-bg); border-radius: 15px;
            display: flex; flex-direction: column; box-shadow: 0 4px 15px rgba(0,0,0,0.2);
            border: 1px solid #3a3b46; overflow: hidden;
        }
        .sidebar-header { padding: 20px; border-bottom: 1px solid var(--border-color); display: flex; justify-content: space-between; align-items: center; }
        .dash-title h1 { margin: 0; font-size: 24px; color: white; }
        .dash-title p { margin: 5px 0 0; color: #aaa; font-size: 13px; }
        
        .btn-new-chat { background: var(--btn-yellow); color: black; border: none; width: 38px; height: 38px; border-radius: 50%; cursor: pointer; display: flex; align-items: center; justify-content: center; transition: 0.2s; padding: 0; box-shadow: 0 2px 5px rgba(0,0,0,0.2); }
        .btn-new-chat:hover { transform: scale(1.1); background: #ffd66b; }
        .btn-new-chat svg { width: 20px; height: 20px; }

        .sidebar-footer { padding: 15px 20px; border-top: 1px solid var(--border-color); display: flex; gap: 15px; align-items: center; background-color: var(--card-bg); z-index: 10; }
        .sidebar-footer .search-box { flex: 1; position: relative; display: flex; align-items: center; }
        .sidebar-footer .btn-new-chat { flex-shrink: 0; }

        .search-box input { 
            width: 100%; background: var(--app-bg); border: 1px solid #444; color: white; 
            padding: 12px 15px 12px 40px; border-radius: 8px; font-size: 14px; outline: none; transition: 0.2s;
        }
        .search-box input:focus { border-color: var(--btn-yellow); }
        .search-icon { position: absolute; left: 12px; margin-top: -5px; color: #888; pointer-events: none; }

        .contact-list { flex: 1; overflow-y: auto; overflow-x: hidden; padding: 10px 0; }
        
        .contact-wrapper {
            position: relative; background-color: var(--btn-red);
            overflow: hidden; border-bottom: 1px solid #3a3b46;
        }
        .contact-wrapper:last-child { border-bottom: none; }
        
        .delete-btn-bg {
            position: absolute; top: 0; right: 0; bottom: 0; width: 80px;
            display: flex; align-items: center; justify-content: center;
            color: white; z-index: 1; cursor: pointer;
        }
        .delete-btn-bg svg { width: 24px; height: 24px; }

        /* Bouton poubelle visible sur chaque conversation (sauf global).
           Discret par défaut, plus visible au survol. */
        .contact-delete-btn {
            background: rgba(255, 77, 77, 0.1); color: var(--btn-red);
            border: 1px solid transparent; border-radius: 6px;
            width: 32px; height: 32px;
            display: flex; align-items: center; justify-content: center;
            cursor: pointer; flex-shrink: 0; margin-left: 8px;
            transition: all 0.2s; padding: 0;
        }
        .contact-delete-btn svg { width: 16px; height: 16px; }
        .contact-delete-btn:hover {
            background: var(--btn-red); color: white;
            border-color: var(--btn-red);
        }

        .contact-item { 
            display: flex; align-items: center; padding: 15px 20px; cursor: pointer; 
            border-left: 4px solid transparent; background-color: var(--card-bg);
            position: relative; z-index: 2; transition: background-color 0.2s, transform 0.3s ease;
        }
        .contact-item:hover { background-color: #343542; }
        .contact-item.active { background-color: #3a3b46; border-left-color: var(--btn-yellow); }
        
        .avatar { width: 45px; height: 45px; border-radius: 50%; background-color: #444; color: white; display: flex; justify-content: center; align-items: center; font-weight: bold; font-size: 18px; margin-right: 15px; flex-shrink: 0; }
        .avatar-group { background-color: var(--btn-yellow); color: black; }
        .avatar-group svg { width: 22px; height: 22px; }
        
        .contact-info { flex: 1; min-width: 0; }
        .contact-name { font-weight: bold; color: white; font-size: 15px; display: flex; justify-content: space-between; margin-bottom: 4px; pointer-events: none; }
        .contact-time { font-size: 11px; color: #888; font-weight: normal; }
        .contact-last-msg { font-size: 13px; color: #aaa; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; display: flex; align-items: center; gap: 5px; pointer-events: none; }

        /* =========================================
           3. ZONE DE CHAT PRINCIPALE
           ========================================= */
        .chat-main {
            flex: 1; background-color: var(--card-bg); border-radius: 15px;
            display: flex; flex-direction: column; box-shadow: 0 4px 15px rgba(0,0,0,0.2);
            border: 1px solid #3a3b46; overflow: hidden;
        }
        .chat-header { padding: 15px 20px; border-bottom: 1px solid var(--border-color); display: flex; justify-content: space-between; align-items: center; background-color: #2e2f3a; }
        .chat-header-info { display: flex; align-items: center; gap: 10px;}
        .chat-header-info h2 { margin: 0; font-size: 18px; color: white; }
        .chat-header-info p { margin: 2px 0 0; font-size: 12px; color: var(--btn-green); }
        
        .btn-back { display: none; background: transparent; border: none; color: var(--btn-yellow); cursor: pointer; padding-right: 15px; padding-left: 0; }
        .btn-back svg { width: 24px; height: 24px; }

        .messages-container {
            flex: 1; padding: 20px; overflow-y: auto; display: flex;
            flex-direction: column; gap: 20px; background-color: var(--app-bg);
        }

        .message-wrapper { display: flex; flex-direction: column; max-width: 75%; }
        .message-wrapper.received { align-self: flex-start; }
        .message-wrapper.sent { align-self: flex-end; align-items: flex-end; }
        .message-sender { font-size: 11px; color: #888; margin-bottom: 5px; margin-left: 5px; }
        .sent .message-sender { display: none; }

        .message-content-row { display: flex; align-items: center; gap: 8px; position: relative; }
        .sent .message-content-row { flex-direction: row-reverse; }

        .message-bubble { padding: 12px 16px; border-radius: 15px; font-size: 14px; line-height: 1.4; position: relative; box-shadow: 0 2px 5px rgba(0,0,0,0.2); }
        .received .message-bubble { background-color: var(--card-bg); color: var(--text-light); border-top-left-radius: 2px; border: 1px solid #444; }
        .sent .message-bubble { background-color: var(--btn-yellow); color: black; border-top-right-radius: 2px; font-weight: 500; }

        .bubble-image { padding: 3px; overflow: hidden; line-height: 0; position: relative; }
        .bubble-image img { max-width: 100%; max-height: 300px; border-radius: 12px; cursor: pointer; transition: 0.2s; }
        .bubble-image img:hover { opacity: 0.9; }

        .bubble-file { padding: 10px; display: flex; align-items: center; gap: 12px; text-decoration: none; min-width: 200px; position: relative; }
        .received .bubble-file { color: var(--text-light); }
        .sent .bubble-file { color: black; }
        .file-icon { width: 28px; height: 28px; }
        .file-icon svg { width: 100%; height: 100%; } 
        .file-meta { display: flex; flex-direction: column; flex: 1; min-width: 0;}
        .file-name { font-weight: bold; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
        .file-size { font-size: 11px; opacity: 0.8; }
        
        .file-download-icon { width: 18px; height: 18px; opacity: 0.7; }
        .file-download-icon svg { width: 100%; height: 100%; }

        .message-time { font-size: 10px; opacity: 0.7; margin-top: 5px; text-align: right; display: block; }
        .sent .message-time { color: #333; }
        .bubble-image .message-time, .bubble-file .message-time { position: absolute; bottom: 8px; right: 10px; background: rgba(0,0,0,0.5); color: white; padding: 2px 5px; border-radius: 4px; }
        .bubble-file .message-time { position: relative; bottom: auto; right: auto; background: transparent; padding: 0; color: inherit; margin-top: 0; }

        /* =========================================
           SYSTÈME DE RÉACTIONS AVANCÉ
           ========================================= */
        .msg-react-btn {
            background: transparent; border: none; color: #888; cursor: pointer; padding: 5px; border-radius: 50%;
            display: flex; align-items: center; justify-content: center; opacity: 0; transition: all 0.2s; flex-shrink: 0;
        }
        .message-content-row:hover .msg-react-btn { opacity: 1; }
        .msg-react-btn:hover { background: #444; color: var(--btn-yellow); transform: scale(1.1); }

        .msg-reaction-badge {
            position: absolute; bottom: -12px; right: 15px; background: var(--card-bg); border: 1px solid #444;
            border-radius: 15px; padding: 2px 6px; font-size: 14px; box-shadow: 0 2px 5px rgba(0,0,0,0.5); z-index: 5;
            cursor: pointer; transition: 0.2s; user-select: none; display: flex; align-items: center; justify-content: center;
        }
        .received .msg-reaction-badge { right: auto; left: 15px; }
        .msg-reaction-badge:hover { transform: scale(1.2); }

        .reaction-picker {
            position: fixed; background: #323340; border: 1px solid #555; border-radius: 30px; padding: 8px 15px;
            display: none; gap: 10px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); z-index: 200; align-items: center; justify-content: center;
        }
        .reaction-list { display: flex; gap: 10px; }
        .reaction-list span { cursor: pointer; font-size: 22px; transition: transform 0.2s; display: block; user-select: none; }
        .reaction-list span:hover { transform: scale(1.4) translateY(-3px); }
        .reaction-divider { width: 1px; background: #555; margin: 0 5px; align-self: stretch; }
        
        .react-tool-btn { 
            background: transparent; border: none; cursor: pointer; transition: 0.2s; 
            display: flex; align-items: center; justify-content: center; width: 32px; height: 32px; 
            border-radius: 50%; color: #aaa; padding: 6px;
        }
        .react-tool-btn:hover { background: #444; color: white; }

        .bottom-sheet-modal {
            position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.7);
            display: none; z-index: 6000; align-items: flex-end; justify-content: center;
        }
        .bottom-sheet-card {
            background: var(--card-bg); width: 100%; max-width: 500px; border-radius: 20px 20px 0 0;
            padding: 20px; box-shadow: 0 -10px 30px rgba(0,0,0,0.5); border-top: 1px solid #444;
            display: flex; flex-direction: column; animation: slideUp 0.3s ease-out;
        }
        @keyframes slideUp { from { transform: translateY(100%); } to { transform: translateY(0); } }

        .top-quick-reactions {
            display: flex; justify-content: space-between; align-items: center;
            background: #1a1b23; padding: 10px 15px; border-radius: 12px; margin-bottom: 15px;
        }
        .top-react-slot {
            font-size: 24px; padding: 8px; border-radius: 50%; cursor: pointer; transition: 0.2s;
            display: flex; align-items: center; justify-content: center; width: 45px; height: 45px;
            background: transparent; border: 2px solid transparent; user-select: none;
        }
        .top-react-slot:hover { background: rgba(255,255,255,0.1); transform: scale(1.1); }
        .top-react-slot.active-slot { border-color: var(--btn-yellow); background: rgba(252, 202, 70, 0.1); transform: scale(1.1); }

        emoji-picker {
            --background: transparent; --border-color: transparent; --text-color: #fff;
            --category-icon-color: #aaa; --category-icon-active-color: var(--btn-yellow);
            --indicator-color: var(--btn-yellow); --input-border-color: #555;
            width: 100%; height: 350px;
        }

        /* =========================================
           4. ZONE DE SAISIE ET MENUS
           ========================================= */
        .chat-input-container { border-top: 1px solid var(--border-color); background-color: var(--card-bg); display: flex; flex-direction: column; position: relative; }
        
        .attach-menu-popup { 
            position: absolute; bottom: 75px; left: 15px; background: rgba(43, 44, 54, 0.95);
            backdrop-filter: blur(10px); border: 1px solid #444; border-radius: 16px;
            display: flex; flex-direction: column; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.5);
            padding: 5px; width: 220px; transform: translateY(10px); opacity: 0; pointer-events: none; transition: 0.2s; z-index: 100;
        }
        .attach-menu-popup.show { transform: translateY(0); opacity: 1; pointer-events: auto; }
        
        .attach-option { 
            background: transparent; border: none; color: white; padding: 12px 15px; text-align: left; 
            font-size: 15px; display: flex; align-items: center; gap: 15px; cursor: pointer; border-radius: 10px; transition: 0.2s; 
        }
        .attach-option:hover { background: #3a3b46; }
        .attach-icon { width: 22px; height: 22px; color: var(--btn-yellow); display: flex; align-items: center; justify-content: center;}

        .chat-input-area { padding: 15px 20px; display: flex; align-items: center; gap: 10px; }
        .btn-attach { background: transparent; border: none; color: #888; width: 30px; height: 30px; display: flex; align-items: center; justify-content: center; cursor: pointer; transition: 0.2s; padding: 2px; flex-shrink: 0; }
        .btn-attach:hover, .btn-attach.active { color: var(--btn-yellow); transform: scale(1.1); }
        
        .message-input { flex: 1; background: var(--app-bg); border: 1px solid #444; color: white; padding: 14px 20px; border-radius: 25px; font-size: 14px; outline: none; transition: 0.2s; min-width: 0; }
        .message-input:focus { border-color: var(--btn-yellow); }
        
        .btn-send { 
            background-color: var(--btn-yellow); color: black; border: none; 
            width: 42px; height: 42px; border-radius: 50%; 
            display: flex; align-items: center; justify-content: center; 
            cursor: pointer; box-shadow: 0 4px 6px rgba(0,0,0,0.3); transition: 0.2s; flex-shrink: 0;
        }
        .btn-send:hover { background-color: #ffd66b; transform: scale(1.1); }
        .btn-send svg { width: 20px; height: 20px; stroke-width: 2.5px; margin-left: -2px; }

        /* =========================================
           5. NOUVEAU DESIGN CRÉATION DE CHAT
           ========================================= */
        .modal-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.8); display: none; z-index: 5000; justify-content: center; align-items: center; }
        
        .new-chat-card {
            background: var(--card-bg); width: 90%; max-width: 450px; padding: 0;
            border-radius: 20px; border: 1px solid #444; box-shadow: 0 15px 35px rgba(0,0,0,0.5);
            display: flex; flex-direction: column; max-height: 85vh; overflow: hidden;
        }
        
        .new-chat-header {
            padding: 20px; border-bottom: 1px solid #333; display: flex; align-items: center; justify-content: space-between;
            background: #2e2f3a;
        }
        .new-chat-header h3 { margin: 0; color: white; font-size: 18px; display: flex; align-items: center; gap: 10px; }
        
        .new-chat-body { padding: 20px; overflow-y: auto; flex: 1; display: flex; flex-direction: column; gap: 15px; }

        #groupNameGroup {
            transition: max-height 0.3s ease, opacity 0.3s ease, margin 0.3s ease;
            max-height: 0; opacity: 0; overflow: hidden; margin-bottom: 0;
        }
        #groupNameGroup.show { max-height: 100px; opacity: 1; margin-bottom: 5px; overflow: visible; }
        
        .new-chat-input {
            width: 100%; padding: 12px 15px; background: #1e1f26; border: 1px solid #555;
            color: white; border-radius: 10px; font-size: 14px; outline: none; transition: 0.2s;
        }
        .new-chat-input:focus { border-color: var(--btn-yellow); }
        .new-chat-label { display: block; color: #aaa; margin-bottom: 8px; font-size: 12px; font-weight: bold; text-transform: uppercase;}

        #newChatUserList {
            max-height: 250px; overflow-y: auto; display: flex; flex-direction: column; gap: 8px;
            padding-right: 5px; 
        }
        #newChatUserList::-webkit-scrollbar { width: 5px; }
        #newChatUserList::-webkit-scrollbar-thumb { background: #555; border-radius: 10px; }

        .user-select-row {
            display: flex; align-items: center; gap: 12px; padding: 10px 15px;
            cursor: pointer; transition: 0.2s; border-radius: 10px;
            border: 1px solid #444; background: #22232c;
        }
        .user-select-row:hover { background: #2b2c36; border-color: #666; }
        .user-select-row.selected { background: rgba(252, 202, 70, 0.05); border-color: var(--btn-yellow); }
        
        .user-select-row input[type="checkbox"] { display: none; } 
        
        .user-info { display: flex; align-items: center; gap: 12px; flex: 1; }
        .user-select-name { font-size: 14px; color: white; font-weight: bold; }
        
        .custom-checkbox {
            width: 20px; height: 20px; border-radius: 50%; border: 2px solid #555;
            display: block; transition: 0.2s; margin-left: auto; background: transparent;
            flex-shrink: 0;
        }
        .user-select-row.selected .custom-checkbox { background: var(--btn-yellow); border-color: var(--btn-yellow); }

        .new-chat-footer {
            padding: 20px; border-top: 1px solid #333; background: var(--card-bg);
            display: flex; gap: 15px; justify-content: flex-end;
        }

        .btn-modal-gray { background: #444; color: white; border: none; padding: 12px 20px; border-radius: 10px; cursor: pointer; font-weight:bold; transition: 0.2s; }
        .btn-modal-gray:hover { background: #555; }
        .btn-modal-green { background: var(--btn-green); color: white; border: none; padding: 12px 30px; border-radius: 10px; cursor: pointer; font-weight:bold; transition: 0.2s; }
        .btn-modal-green:hover { background: #218838; }

        .modal-card-basic { background: var(--card-bg); width: 90%; max-width: 400px; padding: 25px; border-radius: 15px; text-align: center; border: 1px solid #555; box-shadow: 0 10px 25px rgba(0,0,0,0.5); }
        .btn-modal-yellow { background: var(--btn-yellow); color: black; border: none; padding: 12px 20px; border-radius: 10px; cursor: pointer; font-weight:bold; width: 100%; }
        .btn-modal-red { background: var(--btn-red); color: white; border: none; padding: 12px 20px; border-radius: 10px; cursor: pointer; font-weight:bold; }

        @media (max-width: 900px) {
            #view-dashboard { padding: 15px; gap: 0; }
            .chat-sidebar { width: 100%; border-radius: 12px; }
            .chat-main { display: none; width: 100%; border-radius: 12px; }
            .show-chat .chat-sidebar { display: none; }
            .show-chat .chat-main { display: flex; }
            .btn-back { display: block; }
            .chat-header { padding: 15px; }
            .message-wrapper { max-width: 85%; }
            .attach-menu-popup { width: calc(100% - 30px); }
            .msg-react-btn { opacity: 1; }
            .reaction-picker { padding: 8px; gap: 5px; }
            .reaction-list { gap: 5px; }
            .reaction-list span { font-size: 20px; }
            .new-chat-card { width: 95%; max-height: 90vh; }
            .new-chat-footer .btn-modal-green { flex: 1; }
            .new-chat-footer .btn-modal-gray { flex: 1; }
        }
    </style>
</head>
<body>

<div id="security-loader" style="position: fixed; inset: 0; background: #1e1f26; z-index: 9999; display: flex; justify-content: center; align-items: center;">
    <div style="color: #444; font-size: 12px; font-family: sans-serif;">Chargement du module...</div>
</div>

<svg style="display: none;">
    <symbol id="icon-users" viewBox="0 0 24 24"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path><circle cx="9" cy="7" r="4"></circle><path d="M23 21v-2a4 4 0 0 0-3-3.87"></path><path d="M16 3.13a4 4 0 0 1 0 7.75"></path></symbol>
    <symbol id="icon-paperclip" viewBox="0 0 24 24"><path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"></path></symbol>
    <symbol id="icon-camera" viewBox="0 0 24 24"><path d="M14.5 4h-5L7 7H4a2 2 0 0 0-2 2v9a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2V9a2 2 0 0 0-2-2h-3l-2.5-3z"></path><circle cx="12" cy="13" r="3"></circle></symbol>
    <symbol id="icon-image" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect><circle cx="8.5" cy="8.5" r="1.5"></circle><polyline points="21 15 16 10 5 21"></polyline></symbol>
    <symbol id="icon-file" viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path><polyline points="13 2 13 9 20 9"></polyline></symbol>
    <symbol id="icon-search" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></symbol>
    <symbol id="icon-back" viewBox="0 0 24 24"><line x1="19" y1="12" x2="5" y2="12"></line><polyline points="12 19 5 12 12 5"></polyline></symbol>
    <symbol id="icon-download" viewBox="0 0 24 24"><path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"></path><polyline points="7 10 12 15 17 10"></polyline><line x1="12" y1="15" x2="12" y2="3"></line></symbol>
    <symbol id="icon-smile" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10"></circle><path d="M8 14s1.5 2 4 2 4-2 4-2"></path><line x1="9" y1="9" x2="9.01" y2="9"></line><line x1="15" y1="9" x2="15.01" y2="9"></line></symbol>
    <symbol id="icon-plus" viewBox="0 0 24 24"><line x1="12" y1="5" x2="12" y2="19"></line><line x1="5" y1="12" x2="19" y2="12"></line></symbol>
    <symbol id="icon-edit" viewBox="0 0 24 24"><path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path><path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path></symbol>
    <symbol id="icon-trash" viewBox="0 0 24 24"><polyline points="3 6 5 6 21 6"></polyline><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path></symbol>
    <symbol id="icon-send" viewBox="0 0 24 24"><line x1="22" y1="2" x2="11" y2="13"></line><polygon points="22 2 15 22 11 13 2 9 22 2"></polygon></symbol>
</svg>

<div id="reactionPicker" class="reaction-picker">
    <div id="quickReactionsList" class="reaction-list"></div>
    <div class="reaction-divider"></div>
    <button class="react-tool-btn" onclick="openFullPicker()" title="Plus d'emojis"><svg class="svg-icon"><use href="#icon-plus"></use></svg></button>
</div>

<div class="bottom-sheet-modal" id="fullPickerModal">
    <div class="bottom-sheet-card">
        <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:15px;">
            <b style="color:white; font-size:16px;">Réactions</b>
            <div style="display:flex; gap:15px; align-items:center;">
                <button id="btnToggleCustomize" onclick="toggleCustomizeMode()" style="background:none; border:none; color:var(--btn-blue); font-weight:bold; font-size:14px; cursor:pointer; padding:0;">Personnaliser</button>
                <button onclick="closeModal('fullPickerModal')" style="background:none; border:none; color:#888; font-size:24px; cursor:pointer; padding:0; line-height:1;">×</button>
            </div>
        </div>
        <div id="topQuickReactions" class="top-quick-reactions"></div>
        <emoji-picker id="myEmojiPicker"></emoji-picker>
    </div>
</div>

<div class="modal-overlay" id="newChatModal" style="z-index: 5000;">
    <div class="new-chat-card">
        <div class="new-chat-header">
            <h3><svg class="svg-icon" style="width:20px;height:20px; color:var(--btn-yellow)"><use href="#icon-edit"></use></svg> Nouvelle discussion</h3>
            <button onclick="closeModal('newChatModal')" style="background:none; border:none; color:#888; font-size:24px; cursor:pointer; padding:0;">×</button>
        </div>
        <div class="new-chat-body">
            <div id="groupNameGroup">
                <label class="new-chat-label">Nom du groupe</label>
                <input type="text" class="new-chat-input" id="newGroupName" placeholder="Ex: Chantier Montréal...">
            </div>
            <label class="new-chat-label" style="margin-bottom: 2px;">Sélectionner les participants</label>
            <div id="newChatUserList"></div>
        </div>
        <div class="new-chat-footer">
            <button class="btn-modal-gray" onclick="closeModal('newChatModal')">Annuler</button>
            <button class="btn-modal-green" onclick="createNewChat()">Créer la discussion</button>
        </div>
    </div>
</div>

<div class="modal-overlay" id="confirmDeleteModal" style="z-index: 6000;">
    <div class="modal-card-basic" style="text-align: center;">
        <h3 style="color:var(--btn-red); margin-top:0;">Masquer la conversation</h3>
        <p style="color:#e0e0e0; font-size:15px; margin: 20px 0;">Cette conversation sera retirée de votre liste, mais l'autre participant la conservera. Si un nouveau message arrive, elle réapparaîtra automatiquement.</p>
        <div class="modal-actions">
            <button class="btn-modal-gray" style="flex:1;" onclick="closeModal('confirmDeleteModal')">Annuler</button>
            <button class="btn-modal-red" style="flex:1;" onclick="executeDeleteChat()">Masquer</button>
        </div>
    </div>
</div>

<div class="modal-overlay" id="alertModal" style="z-index: 6000;">
    <div class="modal-card-basic" style="text-align: center;">
        <h3 style="color:var(--btn-yellow); margin-top:0;">Information</h3>
        <p id="alertMessage" style="color:white; font-size:15px; margin: 20px 0;">...</p>
        <button class="btn-modal-yellow" onclick="closeModal('alertModal')">Compris</button>
    </div>
</div>

<div class="main-content">
    <div id="view-dashboard">
        
        <aside class="chat-sidebar">
            <div class="sidebar-header">
                <div class="dash-title">
                    <h1>Messagerie</h1>
                    <p>F.Dussault</p>
                </div>
            </div>
            
            <div class="contact-list" id="contactListContainer"></div>

            <div class="sidebar-footer">
                <div class="search-box">
                    <span class="search-icon"><svg class="svg-icon" style="width:18px;height:18px;"><use href="#icon-search"></use></svg></span>
                    <input type="text" id="searchContactInput" placeholder="Rechercher..." onkeyup="filterContacts()">
                </div>
                <button class="btn-new-chat" onclick="openNewChatModal()" title="Nouvelle discussion">
                    <svg class="svg-icon"><use href="#icon-plus"></use></svg>
                </button>
            </div>
        </aside>

        <main class="chat-main">
            <header class="chat-header">
                <div class="chat-header-info">
                    <button class="btn-back" onclick="closeChat()"><svg class="svg-icon" style="width:24px;height:24px;"><use href="#icon-back"></use></svg></button>
                    <div id="chatHeaderAvatar" class="avatar" style="width:40px; height:40px; font-size:15px; background: transparent;"></div>
                    <div>
                        <h2 id="chatHeaderName">Sélectionnez une discussion</h2>
                    </div>
                </div>
            </header>

            <div class="messages-container" id="chatMessages">
                <div style="text-align:center; color:#888; font-style:italic; margin-top:50px;">Aucune conversation sélectionnée.</div>
            </div>

            <div class="chat-input-container">
                <div class="attach-menu-popup" id="attachMenu">
                    <button class="attach-option" onclick="triggerInput('inputCamera')"><div class="attach-icon"><svg class="svg-icon"><use href="#icon-camera"></use></svg></div> Appareil photo</button>
                    <button class="attach-option" onclick="triggerInput('inputGallery')"><div class="attach-icon"><svg class="svg-icon"><use href="#icon-image"></use></svg></div> Galerie photos</button>
                    <button class="attach-option" onclick="triggerInput('inputFile')"><div class="attach-icon"><svg class="svg-icon"><use href="#icon-file"></use></svg></div> Document</button>
                </div>

                <input type="file" id="inputCamera" accept="image/*" capture="environment" hidden>
                <input type="file" id="inputGallery" accept="image/*,video/*" multiple hidden>
                <input type="file" id="inputFile" accept=".pdf,.doc,.docx,.xls,.xlsx,.txt" multiple hidden>

                <div class="attachment-preview" id="attachmentPreview"></div>

                <div class="chat-input-area">
                    <button class="btn-attach" title="Joindre un élément" id="attachBtn"><svg class="svg-icon" style="width:24px; height:24px;"><use href="#icon-paperclip"></use></svg></button>
                    <input type="text" class="message-input" placeholder="Écrire un message..." id="messageInput" autocomplete="off">
                    <button class="btn-send" onclick="sendMessage()" title="Envoyer"><svg class="svg-icon"><use href="#icon-send"></use></svg></button>
                </div>
            </div>
        </main>

    </div>
</div>

<script>
    // --- ÉLÉMENTS DU DOM ---
    const dashboard = document.getElementById('view-dashboard');
    const contactListContainer = document.getElementById('contactListContainer');
    const messagesContainer = document.getElementById('chatMessages');
    const messageInput = document.getElementById('messageInput');
    const attachBtn = document.getElementById('attachBtn');
    const attachMenu = document.getElementById('attachMenu');
    const attachmentPreview = document.getElementById('attachmentPreview');
    const reactionPicker = document.getElementById('reactionPicker');

    // --- VARIABLES GLOBALES ---
    let selectedFiles = [];
    let currentChatId = null;
    let currentReactMsgId = null; 
    let currentChatIdToDelete = null;
    let isCustomizing = false;
    let selectedCustomizeIndex = 0;
    let allEmployees = []; 

    let quickReactions = JSON.parse(localStorage.getItem('dussault_quick_reacts')) || ['❤️', '👍', '😂', '😮', '😢', '🙏'];

    const conversationsData = {
        'global': { name: 'Équipe (Général)', isGroup: true, messages: [] }
    };

    // --- CONFIGURATION SUPABASE ---

    let myUserId = 'local-user';
    let myUserName = 'Moi';
    let hiddenChatIds = new Set(); // Chats que CET utilisateur a masqués

    // Charger la liste des chats masqués pour cet utilisateur
    async function chargerChatsMasques() {
        try {
            const { data, error } = await supabaseClient
                .from('chats_caches')
                .select('chat_id')
                .eq('user_id', myUserId);
            if (error) throw error;
            hiddenChatIds = new Set((data || []).map(r => r.chat_id));
        } catch (e) {
            console.warn('[Messagerie] Impossible de charger les chats masqués:', e.message);
            hiddenChatIds = new Set();
        }
    }

    // 1. INITIALISATION
    async function initAuth() {
        try {
            const { data: { user } } = await supabaseClient.auth.getUser();
            if (!user) { window.top.location.href = '../login.html'; return; }

            myUserId = user.id;
            const { data: profil } = await supabaseClient.from('profils').select('prenom_nom').eq('id', user.id).maybeSingle();
            if (profil && profil.prenom_nom) { myUserName = profil.prenom_nom; } else { myUserName = user.email.split('@')[0]; }
            
            await chargerProfilsEmployes();
            
        } catch (error) { console.error("Erreur d'initialisation :", error);
        } finally {
            const loader = document.getElementById('security-loader');
            if (loader) loader.style.display = 'none';
            initApp();
            window.parent.postMessage({ type: 'module_ready', module: 'view-messagerie' }, '*');
        }
    }

    async function chargerProfilsEmployes() {
        const { data, error } = await supabaseClient.from('profils').select('id, prenom_nom');
        if (data && !error) {
            allEmployees = data
                .filter(p => p.id !== myUserId)
                .map(p => {
                    let nomComplet = p.prenom_nom || 'Utilisateur';
                    let parts = nomComplet.split(' ');
                    let initials = parts[0][0] + (parts.length > 1 ? parts[1][0] : '');
                    return { id: p.id, name: nomComplet, initials: initials.toUpperCase() };
                });
        }
    }

    async function initApp() {
        renderQuickReactions();
        // Charger d'abord les chats masqués (avant de rendre la liste)
        await chargerChatsMasques();
        renderContactList();
        chargerMessagesSupabase();

        const emojiPicker = document.getElementById('myEmojiPicker');
        if (emojiPicker) {
            emojiPicker.addEventListener('emoji-click', event => {
                const emoji = event.detail.unicode;
                if (isCustomizing) { quickReactions[selectedCustomizeIndex] = emoji; selectedCustomizeIndex = (selectedCustomizeIndex + 1) % quickReactions.length; renderTopQuickReactions();
                } else { selectReaction(emoji); closeModal('fullPickerModal'); }
            });
        }
    }

    function decoderMessage(contenuBrut) {
        if (!contenuBrut) return { type: 'text', text: '', url: '', fileName: '', fileSize: '' };
        if (contenuBrut.startsWith('IMG|||')) { const parts = contenuBrut.split('|||'); return { type: 'image', text: '', url: parts[1], fileName: '', fileSize: '' }; } 
        else if (contenuBrut.startsWith('FILE|||')) { const parts = contenuBrut.split('|||'); return { type: 'file', text: '', url: parts[1], fileName: parts[2], fileSize: parts[3] }; } 
        else { return { type: 'text', text: contenuBrut, url: '', fileName: '', fileSize: '' }; }
    }

    // 3. LECTURE DE L'HISTORIQUE TRIÉ PAR CHAT_ID
    async function chargerMessagesSupabase() {
        const { data, error } = await supabaseClient
            .from('message')
            .select('id, created_at, contenu, expediteur_id, chat_id, profils(prenom_nom)')
            .order('created_at', { ascending: true });

        if (error) { 
            console.error("Erreur Supabase:", error); 
            showAlert("❌ Erreur de chargement : " + error.message);
            return; 
        }

        Object.values(conversationsData).forEach(c => c.messages = []);

        data.forEach(msgDB => {
            const date = new Date(msgDB.created_at);
            const timeStr = date.getHours() + ':' + String(date.getMinutes()).padStart(2, '0');
            const isMine = msgDB.expediteur_id === myUserId;
            const senderName = msgDB.profils ? msgDB.profils.prenom_nom : 'Inconnu';
            const decodage = decoderMessage(msgDB.contenu);
            
            const cId = msgDB.chat_id || 'global';

            if (!conversationsData[cId]) {
                let nomChat = "Conversation";
                if (cId !== 'global') {
                    // Trouver le VRAI nom de l'autre personne
                    const uuids = cId.split('_');
                    const otherId = uuids[0] === myUserId ? uuids[1] : uuids[0];
                    const otherEmp = allEmployees.find(e => e.id === otherId);
                    nomChat = otherEmp ? otherEmp.name : (isMine ? "Conversation Privée" : senderName);
                }
                conversationsData[cId] = { name: nomChat, isGroup: cId === 'global', messages: [] };
            }

            conversationsData[cId].messages.push({
                id: msgDB.id, sender: senderName, time: timeStr, isMine: isMine, reaction: msgDB.reaction || null,
                type: decodage.type, text: decodage.text, url: decodage.url, fileName: decodage.fileName, fileSize: decodage.fileSize
            });
        });

        if (currentChatId && conversationsData[currentChatId]) { renderMessages(conversationsData[currentChatId].messages, true); }
        renderContactList();
        ecouterNouveauxMessages();
    }

    // 4. LE TEMPS RÉEL (REALTIME) — Version améliorée avec reconnexion
    let realtimeChannel = null;

    function ecouterNouveauxMessages() {
        // Nettoyer l'ancien canal si existant
        if (realtimeChannel) {
            supabaseClient.removeChannel(realtimeChannel);
            realtimeChannel = null;
        }

        realtimeChannel = supabaseClient
            .channel('messagerie-globale')
            .on('postgres_changes', { event: 'INSERT', schema: 'public', table: 'message' }, async (payload) => {
                const newMsg = payload.new;

                // Ignorer nos propres messages (déjà affichés localement)
                if (newMsg.expediteur_id === myUserId) return;

                const { data: profil } = await supabaseClient
                    .from('profils')
                    .select('prenom_nom')
                    .eq('id', newMsg.expediteur_id)
                    .maybeSingle();
                const senderName = profil ? profil.prenom_nom : 'Inconnu';

                const date = new Date(newMsg.created_at);
                const timeStr = date.getHours() + ':' + String(date.getMinutes()).padStart(2, '0');
                const decodage = decoderMessage(newMsg.contenu);
                const cId = newMsg.chat_id || 'global';

                if (!conversationsData[cId]) {
                    conversationsData[cId] = { name: senderName, isGroup: false, messages: [] };
                }

                // Éviter les doublons
                const dejaDans = conversationsData[cId].messages.some(m => m.id === newMsg.id);
                if (dejaDans) return;

                conversationsData[cId].messages.push({
                    id: newMsg.id, sender: senderName, time: timeStr, isMine: false, reaction: null,
                    type: decodage.type, text: decodage.text, url: decodage.url,
                    fileName: decodage.fileName, fileSize: decodage.fileSize
                });

                // Si ce chat était masqué pour cet utilisateur, le démasquer
                // automatiquement (un nouveau message arrive → la conversation revient)
                if (hiddenChatIds.has(cId)) {
                    hiddenChatIds.delete(cId);
                    try {
                        await supabaseClient
                            .from('chats_caches')
                            .delete()
                            .eq('user_id', myUserId)
                            .eq('chat_id', cId);
                    } catch (e) {
                        console.warn('[Messagerie] Erreur démasquage auto:', e.message);
                    }
                }

                // Mettre à jour l'affichage si on est dans ce chat
                if (currentChatId === cId) {
                    renderMessages(conversationsData[cId].messages, true);
                }

                // Toujours rafraîchir la liste pour montrer le nouveau message
                renderContactList();

                // Notification sonore subtile si le chat n'est pas ouvert
                if (currentChatId !== cId) {
                    notifierNouveauMessage(senderName, cId);
                }
            })
            .on('system', {}, (status) => {
                // Reconnexion automatique si la connexion est perdue
                if (status === 'CHANNEL_ERROR' || status === 'TIMED_OUT') {
                    console.warn('Realtime déconnecté, reconnexion dans 3s...');
                    setTimeout(() => ecouterNouveauxMessages(), 3000);
                }
            })
            .subscribe((status) => {
                if (status === 'SUBSCRIBED') {
                    console.log('✅ Realtime connecté — messages en temps réel actifs');
                }
            });
    }

    // Notification visuelle discrète pour les nouveaux messages
    function notifierNouveauMessage(senderName, chatId) {
        // Envoyer le signal de badge à index.html (instantané)
        if (window.parent && window.parent.postMessage) {
            window.parent.postMessage({ type: 'new_message_notif', sender: senderName, chatId: chatId }, '*');
        }

        // Mettre à jour le titre de la page avec un indicateur
        if (!document.title.startsWith('●')) {
            document.title = '● ' + document.title;
        }

        // Remettre le titre normal quand l'utilisateur revient
        document.addEventListener('visibilitychange', function handler() {
            if (!document.hidden) {
                document.title = document.title.replace('● ', '');
                document.removeEventListener('visibilitychange', handler);
            }
        });

        // Mettre en évidence la conversation dans la liste
        const contactItems = document.querySelectorAll('.contact-item');
        contactItems.forEach(item => {
            if (item.dataset.chatId === chatId) {
                item.style.borderLeft = '3px solid var(--btn-yellow)';
                setTimeout(() => { item.style.borderLeft = ''; }, 5000);
            }
        });
    }

    // 5. ENVOI DES MESSAGES (AVEC ALERTE D'ERREUR)
    async function sendMessage() {
        if(!messageInput) return;
        const text = messageInput.value.trim();
        const hasFiles = selectedFiles.length > 0;

        if ((!text && !hasFiles) || !currentChatId) return;

        const activeChat = conversationsData[currentChatId];
        const now = new Date();
        const timeStr = now.getHours() + ':' + String(now.getMinutes()).padStart(2, '0');

        // -- Envoi des fichiers d'abord --
        if (hasFiles) {
            const fichiersAEnvoyer = [...selectedFiles];
            selectedFiles = []; renderPreviews();

            for (let i = 0; i < fichiersAEnvoyer.length; i++) {
                const file = fichiersAEnvoyer[i];
                const fileExt = file.name.split('.').pop();
                const uniqueName = `${Date.now()}_${Math.random().toString(36).substring(2)}.${fileExt}`;
                const filePath = `${myUserId}/${uniqueName}`;

                const { error: uploadError } = await supabaseClient.storage.from('pieces_jointes').upload(filePath, file);
                if (uploadError) { console.error(uploadError); showAlert("Erreur d'envoi de la pièce jointe."); continue; }

                const { data: { publicUrl } } = supabaseClient.storage.from('pieces_jointes').getPublicUrl(filePath);

                const isImg = file.type.startsWith('image/');
                let contenuFormatte = "";
                let fileSizeTxt = Math.round(file.size / 1024) + ' KB';
                if (isImg) { contenuFormatte = `IMG|||${publicUrl}`; } else { contenuFormatte = `FILE|||${publicUrl}|||${file.name}|||${fileSizeTxt}`; }

                activeChat.messages.push({ 
                    id: Date.now(), sender: myUserName, time: timeStr, isMine: true, reaction: null,
                    type: isImg ? 'image' : 'file', text: '', url: publicUrl, fileName: file.name, fileSize: fileSizeTxt 
                });
                renderMessages(activeChat.messages, true);

                const { error: dbError } = await supabaseClient.from('message').insert([{ contenu: contenuFormatte, expediteur_id: myUserId, chat_id: currentChatId }]);
                if (dbError) { showAlert("❌ Le fichier n'a pas été sauvegardé : " + dbError.message); }
            }
        }

        // -- Envoi du texte --
        if (text) {
            activeChat.messages.push({ id: Date.now(), sender: myUserName, text: text, time: timeStr, isMine: true, type: 'text', reaction: null });
            messageInput.value = '';
            renderMessages(activeChat.messages, true);
            
            // LA VÉRIFICATION CRUCIALE EST ICI
            const { error: txtError } = await supabaseClient.from('message').insert([{ contenu: text, expediteur_id: myUserId, chat_id: currentChatId }]);
            if (txtError) {
                console.error("Erreur Supabase:", txtError);
                showAlert("❌ Le message n'a pas pu être envoyé : " + txtError.message);
            }
        }
        renderContactList();
    }

    // =============================================
    // SÉCURITÉ : Nettoyage XSS pour tout texte affiché dans innerHTML
    // =============================================
    function sanitize(str) {
        if (!str) return '';
        return String(str)
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#39;');
    }

    // --- CREATION DE NOUVEAUX CHATS ---
    function openNewChatModal() {
        const list = document.getElementById('newChatUserList');
        list.innerHTML = '';
        allEmployees.forEach(emp => {
            list.innerHTML += `
                <label class="user-select-row" id="row-${emp.id}">
                    <input type="checkbox" class="new-chat-cb" value="${emp.id}" data-name="${emp.name}" data-initials="${emp.initials}" onchange="toggleRowSelection(this, 'row-${emp.id}')">
                    <div class="user-info">
                        <div class="avatar" style="width:36px;height:36px;font-size:14px;margin:0;">${sanitize(emp.initials)}</div>
                        <span class="user-select-name">${sanitize(emp.name)}</span>
                    </div>
                    <div class="custom-checkbox"></div>
                </label>
            `;
        });
        document.getElementById('newGroupName').value = '';
        document.getElementById('groupNameGroup').classList.remove('show');
        document.getElementById('newChatModal').style.display = 'flex';
        window.parent.postMessage({ type: 'toggle_menu', action: 'hide' }, '*');
    }

    async function createNewChat() {
        const selected = document.querySelectorAll('.new-chat-cb:checked');
        if (selected.length === 0) return showAlert("Veuillez sélectionner au moins une personne.");
        
        let newChatId = "";
        let newChat = null;

        if (selected.length === 1) {
            const otherUserId = selected[0].value;
            newChatId = [myUserId, otherUserId].sort().join('_');
            newChat = { name: selected[0].dataset.name, isGroup: false, messages: [] };
        } else {
            newChatId = 'groupe_' + Date.now();
            let groupName = document.getElementById('newGroupName').value.trim() || "Nouveau Groupe";
            newChat = { name: groupName, isGroup: true, messages: [] };
        }
        
        if (!conversationsData[newChatId]) { conversationsData[newChatId] = newChat; }

        // Si l'utilisateur avait masqué cette conversation auparavant, on la démasque
        if (hiddenChatIds.has(newChatId)) {
            hiddenChatIds.delete(newChatId);
            try {
                await supabaseClient
                    .from('chats_caches')
                    .delete()
                    .eq('user_id', myUserId)
                    .eq('chat_id', newChatId);
            } catch (e) {
                console.warn('[Messagerie] Erreur démasquage manuel:', e.message);
            }
        }

        closeModal('newChatModal');
        renderContactList();
        openChat(newChatId);
    }

    // --- FONCTIONS UI ---
    function showAlert(msg) { document.getElementById('alertMessage').innerHTML = msg; document.getElementById('alertModal').style.display = 'flex'; window.parent.postMessage({ type: 'toggle_menu', action: 'hide' }, '*'); }
    function askDeleteChat(chatId) { if (chatId === 'global') return; currentChatIdToDelete = chatId; document.getElementById('confirmDeleteModal').style.display = 'flex'; window.parent.postMessage({ type: 'toggle_menu', action: 'hide' }, '*'); }
    async function executeDeleteChat() {
        if (!currentChatIdToDelete || currentChatIdToDelete === 'global') return;

        const chatIdToHide = currentChatIdToDelete;

        // Persister le masquage dans Supabase pour CET utilisateur uniquement.
        // Les messages ne sont PAS supprimés — l'autre participant garde l'historique.
        try {
            const { error } = await supabaseClient
                .from('chats_caches')
                .upsert({ user_id: myUserId, chat_id: chatIdToHide }, { onConflict: 'user_id,chat_id' });
            if (error) throw error;
        } catch (e) {
            console.error('Erreur masquage chat:', e);
            showAlert("❌ Impossible de masquer la conversation : " + e.message);
            return;
        }

        // Mise à jour locale
        hiddenChatIds.add(chatIdToHide);
        closeModal('confirmDeleteModal');

        if (currentChatId === chatIdToHide) {
            currentChatId = null;
            document.getElementById('chatHeaderName').textContent = "Sélectionnez une discussion";
            document.getElementById('chatHeaderAvatar').innerHTML = "";
            document.getElementById('chatHeaderAvatar').className = "avatar";
            document.getElementById('chatMessages').innerHTML = '<div style="text-align:center; color:#888; font-style:italic; margin-top:50px;">Aucune conversation sélectionnée.</div>';
            closeChat();
        }
        renderContactList();
        currentChatIdToDelete = null;
    }
    function toggleRowSelection(cb, rowId) { const row = document.getElementById(rowId); if (cb.checked) { row.classList.add('selected'); } else { row.classList.remove('selected'); } checkNewChatSelection(); }
    function checkNewChatSelection() { const selected = document.querySelectorAll('.new-chat-cb:checked'); const groupGroup = document.getElementById('groupNameGroup'); if (selected.length > 1) { groupGroup.classList.add('show'); } else { groupGroup.classList.remove('show'); } }
    
    function renderContactList() {
        const list = document.getElementById('contactListContainer');
        if(!list) return; list.innerHTML = '';
        Object.entries(conversationsData).reverse().forEach(([id, chat]) => {
            // Filtrer les chats masqués par l'utilisateur (sauf 'global' qui ne se masque pas)
            if (id !== 'global' && hiddenChatIds.has(id)) return;

            const isActive = id === currentChatId ? 'active' : '';
            const avatarLet = chat.isGroup ? `<svg class="svg-icon"><use href="#icon-users"></use></svg>` : (chat.name ? chat.name.charAt(0).toUpperCase() : '?');
            const avatarClass = chat.isGroup ? 'avatar-group' : '';
            let lastMsg = 'Nouvelle discussion'; let lastTime = '';
            if (chat.messages && chat.messages.length > 0) { const lastM = chat.messages[chat.messages.length - 1]; lastMsg = lastM.type === 'text' ? lastM.text : (lastM.type === 'image' ? '📷 Image' : '📎 Fichier'); lastTime = lastM.time; }
            // Bouton poubelle visible directement (pas de swipe). Stop propagation pour
            // ne pas ouvrir la conversation au clic sur la poubelle.
            const deleteBtn = id !== 'global'
                ? `<button class="contact-delete-btn" onclick="event.stopPropagation(); askDeleteChat('${id}')" title="Masquer cette conversation"><svg class="svg-icon"><use href="#icon-trash"></use></svg></button>`
                : '';
            list.insertAdjacentHTML('beforeend', `
                <div class="contact-wrapper" id="wrapper-${id}">
                    <div class="contact-item ${isActive}" id="contact-${id}" onclick="openChat('${id}', event)">
                        <div class="avatar ${avatarClass}">${avatarLet}</div>
                        <div class="contact-info">
                            <div class="contact-name"><span>${chat.name}</span> <span class="contact-time">${lastTime}</span></div>
                            <div class="contact-last-msg">${chat.messages && chat.messages.length > 0 && chat.messages[chat.messages.length-1].isMine ? 'Vous: ' : ''}${lastMsg}</div>
                        </div>
                        ${deleteBtn}
                    </div>
                </div>
            `);
        });
    }

    function filterContacts() { const searchTerm = document.getElementById('searchContactInput').value.toLowerCase(); document.querySelectorAll('#contactListContainer .contact-wrapper').forEach(wrapper => { wrapper.style.display = wrapper.textContent.toLowerCase().includes(searchTerm) ? 'block' : 'none'; }); }
    
    function openChat(chatId, e) {
        if (!conversationsData[chatId]) return; currentChatId = chatId; const chat = conversationsData[chatId];
        const nameEl = document.getElementById('chatHeaderName'); const avatarBox = document.getElementById('chatHeaderAvatar');
        if(nameEl) nameEl.textContent = chat.name || "Inconnu";
        if(avatarBox) { avatarBox.className = chat.isGroup ? 'avatar avatar-group' : 'avatar'; avatarBox.innerHTML = chat.isGroup ? `<svg class="svg-icon"><use href="#icon-users"></use></svg>` : (chat.name ? chat.name.charAt(0).toUpperCase() : '?'); }
        renderContactList(); renderMessages(chat.messages || [], true);
        if (dashboard && window.innerWidth <= 900) {
            dashboard.classList.add('show-chat');
            // Cacher le menu instantanément quand on entre dans un chat
            if (window.parent && window.parent.hideMenuBtn) window.parent.hideMenuBtn();
            else window.parent.postMessage({ type: 'toggle_menu', action: 'hide' }, '*');
        }
        selectedFiles = []; renderPreviews();
    }

    function closeChat() {
        if(dashboard) dashboard.classList.remove('show-chat');
        // Remonter le menu instantanément quand on quitte le chat
        if (window.parent && window.parent.showMenuBtn) window.parent.showMenuBtn();
        else window.parent.postMessage({ type: 'toggle_menu', action: 'show' }, '*');
    }
    
    function renderMessages(messages, scroll = false) {
        if(!messagesContainer) return; const scrollPos = messagesContainer.scrollTop; messagesContainer.innerHTML = '';
        if(messages.length === 0) { messagesContainer.innerHTML = '<div style="text-align:center; color:#888; font-style:italic; margin-top:50px;">Envoyez un premier message pour démarrer la discussion.</div>'; return; }
        messages.forEach(msg => {
            const wrapper = document.createElement('div'); wrapper.className = `message-wrapper ${msg.isMine ? 'sent' : 'received'}`;
            let senderHtml = !msg.isMine ? `<span class="message-sender">${sanitize(msg.sender)}</span>` : '';
            let reactionHtml = msg.reaction ? `<div class="msg-reaction-badge" onclick="removeReaction('${msg.id}')">${msg.reaction}</div>` : '';
            let innerBubble = '';
            if (msg.type === 'text') { innerBubble = `<div class="message-bubble">${sanitize(msg.text)}<span class="message-time">${sanitize(msg.time)}</span>${reactionHtml}</div>`; } 
            else if (msg.type === 'image') { innerBubble = `<div class="message-bubble bubble-image"><img src="${msg.url}" onclick="window.open('${msg.url}')"><span class="message-time">${msg.time}</span>${reactionHtml}</div>`; } 
            else if (msg.type === 'file') { innerBubble = `<a href="${msg.url}" target="_blank" class="message-bubble bubble-file"><div class="file-icon"><svg class="svg-icon" style="width:28px;height:28px;"><use href="#icon-file"></use></svg></div><div class="file-meta"><span class="file-name">${sanitize(msg.fileName)}</span><span class="file-size">${sanitize(msg.fileSize)}</span></div><div class="file-download-icon"><svg class="svg-icon" style="width:18px;height:18px;"><use href="#icon-download"></use></svg></div><span class="message-time" style="position: absolute; bottom: 5px; right: 10px; font-size: 9px; color: #333;">${msg.time}</span>${reactionHtml}</a>`; }
            wrapper.innerHTML = senderHtml + `<div class="message-content-row">${innerBubble}<button class="msg-react-btn" onclick="showReactionPicker(event, '${msg.id}')"><svg class="svg-icon" style="width:16px;height:16px;"><use href="#icon-smile"></use></svg></button></div>`;
            messagesContainer.appendChild(wrapper);
        });
        if (scroll) { scrollToBottom(); } else { messagesContainer.scrollTop = scrollPos; }
    }

    function scrollToBottom() { if(messagesContainer) messagesContainer.scrollTop = messagesContainer.scrollHeight; }
    function renderQuickReactions() { const list = document.getElementById('quickReactionsList'); if(!list) return; list.innerHTML = ''; quickReactions.forEach(emoji => { const span = document.createElement('span'); span.textContent = emoji; span.onclick = () => selectReaction(emoji); list.appendChild(span); }); }
    function showReactionPicker(e, msgId) { e.stopPropagation(); currentReactMsgId = msgId; if(reactionPicker) { reactionPicker.style.display = 'flex'; const rect = e.currentTarget.getBoundingClientRect(); let topPos = rect.top - 55; let leftPos = rect.left - 130; if (topPos < 10) topPos = rect.bottom + 10; if (leftPos < 10) leftPos = 10; if (leftPos + reactionPicker.offsetWidth > window.innerWidth) leftPos = window.innerWidth - reactionPicker.offsetWidth - 10; reactionPicker.style.top = topPos + 'px'; reactionPicker.style.left = leftPos + 'px'; } }
    async function selectReaction(emoji) {
        if (!currentReactMsgId || !currentChatId) return;
        const chat = conversationsData[currentChatId];
        if (!chat) return;
        const msg = chat.messages.find(m => m.id === currentReactMsgId || m.id == currentReactMsgId);
        if (msg) {
            msg.reaction = emoji;
            renderMessages(chat.messages, false);
            // Persister dans Supabase
            try {
                await supabaseClient.from('message')
                    .update({ reaction: emoji })
                    .eq('id', currentReactMsgId);
            } catch(e) { console.error('Erreur sauvegarde réaction:', e); }
        }
        if (reactionPicker) reactionPicker.style.display = 'none';
    }
    async function removeReaction(msgId) {
        if (!currentChatId) return;
        const chat = conversationsData[currentChatId];
        if (!chat) return;
        const msg = chat.messages.find(m => m.id === msgId || m.id == msgId);
        if (msg) {
            msg.reaction = null;
            renderMessages(chat.messages, false);
            // Retirer dans Supabase
            try {
                await supabaseClient.from('message')
                    .update({ reaction: null })
                    .eq('id', msgId);
            } catch(e) { console.error('Erreur suppression réaction:', e); }
        }
    }
    function openFullPicker() { isCustomizing = false; const fullPicker = document.getElementById('fullPickerModal'); if(fullPicker) fullPicker.style.display = 'flex'; if(reactionPicker) reactionPicker.style.display = 'none'; renderTopQuickReactions(); window.parent.postMessage({ type: 'toggle_menu', action: 'hide' }, '*'); }
    function toggleCustomizeMode() { isCustomizing = !isCustomizing; const btn = document.getElementById('btnToggleCustomize'); if(!btn) return; if (isCustomizing) { btn.textContent = "Terminé"; btn.style.color = "var(--btn-green)"; selectedCustomizeIndex = 0; } else { btn.textContent = "Personnaliser"; btn.style.color = "var(--btn-blue)"; selectedCustomizeIndex = null; localStorage.setItem('dussault_quick_reacts', JSON.stringify(quickReactions)); renderQuickReactions(); } renderTopQuickReactions(); }
    function renderTopQuickReactions() { const container = document.getElementById('topQuickReactions'); if(!container) return; container.innerHTML = ''; quickReactions.forEach((emoji, index) => { const div = document.createElement('div'); div.className = 'top-react-slot' + (isCustomizing && selectedCustomizeIndex === index ? ' active-slot' : ''); div.textContent = emoji; if (isCustomizing) { div.onclick = () => { selectedCustomizeIndex = index; renderTopQuickReactions(); }; } else { div.onclick = () => { selectReaction(emoji); closeModal('fullPickerModal'); }; } container.appendChild(div); }); }
    function closeModal(id) { const el = document.getElementById(id); if(el) el.style.display = 'none'; window.parent.postMessage({ type: 'toggle_menu', action: 'show' }, '*'); }
    document.addEventListener('click', (e) => { if (reactionPicker && !reactionPicker.contains(e.target)) { reactionPicker.style.display = 'none'; } });
    if(attachBtn && attachMenu) { attachBtn.addEventListener('click', (e) => { e.stopPropagation(); attachMenu.classList.toggle('show'); attachBtn.classList.toggle('active'); }); document.addEventListener('click', (e) => { if (!attachMenu.contains(e.target) && e.target !== attachBtn && !attachBtn.contains(e.target)) { attachMenu.classList.remove('show'); if(selectedFiles.length === 0) attachBtn.classList.remove('active'); } }); }
    function triggerInput(inputId) { const inp = document.getElementById(inputId); if(inp) inp.click(); if(attachMenu) attachMenu.classList.remove('show'); }
    
    const inputCamera = document.getElementById('inputCamera'); const inputGallery = document.getElementById('inputGallery'); const inputFile = document.getElementById('inputFile');
    if(inputCamera) inputCamera.addEventListener('change', handleFileSelect); if(inputGallery) inputGallery.addEventListener('change', handleFileSelect); if(inputFile) inputFile.addEventListener('change', handleFileSelect);
    function handleFileSelect(e) { const files = Array.from(e.target.files); if (files.length === 0) return; selectedFiles = selectedFiles.concat(files); renderPreviews(); e.target.value = ''; }
    function renderPreviews() { if(!attachmentPreview) return; attachmentPreview.innerHTML = ''; if (selectedFiles.length > 0) { attachmentPreview.classList.add('active'); if(attachBtn) attachBtn.classList.add('active'); } else { attachmentPreview.classList.remove('active'); if(attachBtn) attachBtn.classList.remove('active'); return; } selectedFiles.forEach((file, index) => { const previewItem = document.createElement('div'); if (file.type.startsWith('image/')) { previewItem.className = 'preview-item'; const img = document.createElement('img'); img.src = URL.createObjectURL(file); previewItem.appendChild(img); } else { previewItem.className = 'preview-item-file'; const truncatedName = file.name.length > 15 ? file.name.substring(0,12)+'...' : file.name; previewItem.innerHTML = `<div class="file-icon"><svg class="svg-icon" style="width:16px;height:16px;"><use href="#icon-file"></use></svg></div> <span>${truncatedName}</span>`; } const removeBtn = document.createElement('button'); removeBtn.className = 'remove-attachment'; removeBtn.innerText = '×'; removeBtn.onclick = () => removeFile(index); previewItem.appendChild(removeBtn); attachmentPreview.appendChild(previewItem); }); }
    function removeFile(index) { selectedFiles.splice(index, 1); renderPreviews(); }
    if(messageInput) { messageInput.addEventListener('keypress', (e) => { if (e.key === 'Enter') sendMessage(); }); }
    window.onload = initAuth;
</script>
</body>
</html>