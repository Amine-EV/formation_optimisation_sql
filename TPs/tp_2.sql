-- =============================================================
--  TP 2 — Stratégie d'indexation
--  Formation : Optimisation des Requêtes SQL — Séance 2
--  Durée     : 35 minutes
--  Prérequis : TP 1 terminé — base ecommerce_formation peuplée
-- =============================================================

USE ecommerce_formation;

-- =============================================================
--  RAPPEL — Ce qu'on a vu en TP 1
-- =============================================================
--
--  - type = ALL  → Full Table Scan (à éviter)
--  - Un index sur customer_id transforme ALL → ref
--  - Using filesort reste même avec l'index sur customer_id seul
--  - EXPLAIN ANALYZE donne les valeurs réelles (actual rows, actual time)
--
--  Objectif du TP 2 :
--  - Comprendre quand et pourquoi créer un index composite
--  - Connaître la règle du préfixe le plus à gauche
--  - Identifier ce qui "casse" un index (fonctions, LIKE '%...', cast)
--  - Découvrir le concept d'index couvrant (covering index)
--
-- =============================================================
--  RAPPEL — Types d'index B-Tree et leurs usages
-- =============================================================
--
--  Index simple   : CREATE INDEX idx ON t (col_a)
--                   → Efficace pour WHERE col_a = ?
--
--  Index composite: CREATE INDEX idx ON t (col_a, col_b)
--                   → Efficace pour WHERE col_a = ? AND col_b = ?
--                   → Efficace pour WHERE col_a = ? ORDER BY col_b
--                   → PAS efficace pour WHERE col_b = ? seul (règle préfixe)
--
--  Index couvrant : toutes les colonnes du SELECT sont dans l'index
--                   → MySQL ne lit pas la table, juste l'index (Using index)
--
-- =============================================================


-- =============================================================
--  ÉTAT DE DÉPART — Vérification des index existants
-- =============================================================
--  Exécutez ces deux appels pour connaître l'état de la base
--  avant de commencer les exercices.

CALL etat_index('orders');
CALL etat_index('order_items');

-- Résultat attendu sur orders :
--   PRIMARY         → id
--   idx_orders_status   → status       (créé dans le schéma)
--   idx_orders_created  → created_at   (créé dans le schéma)
--   idx_orders_customer → customer_id  (créé en TP 1)
--
-- Si idx_orders_customer est absent (TP 1 non terminé) :
--   CREATE INDEX idx_orders_customer ON orders (customer_id);


-- ┌─────────────────────────────────────────────────────────────┐
-- │  EXERCICE 1 — Le problème du Using filesort persistant      │
-- │               et la solution : index composite  (8 min)     │
-- └─────────────────────────────────────────────────────────────┘
--
--  Contexte :
--  En TP 1 vous avez créé idx_orders_customer sur customer_id.
--  Le Full Scan a disparu mais "Using filesort" est toujours là.
--  Le tri sur created_at coûte cher quand un client a des centaines
--  de commandes (clients VIP, comptes pros).
--
--  1a. Vérifiez que Using filesort est toujours présent.

CALL analyse_requete(
    'SELECT id, status, total, created_at
     FROM orders
     WHERE customer_id = 42
     ORDER BY created_at DESC
     LIMIT 10'
);

-- ─── Questions à remplir ──────────────────────────────────────
-- type  = ?      key = ?      Extra = ?
-- Using filesort est-il toujours présent ? (oui / non) : ?
-- Pourquoi l'index sur customer_id seul ne suffit-il pas
-- pour éviter le tri ? __________________________________________

--  1b. Créez un index composite pour couvrir à la fois
--      le filtre WHERE et le tri ORDER BY.
--      Réfléchissez à l'ordre des colonnes avant d'écrire.

-- Votre réponse :
-- CREATE INDEX ... ON orders (..., ...);

--  1c. Relancez l'analyse et comparez.

CALL analyse_requete(
    'SELECT id, status, total, created_at
     FROM orders
     WHERE customer_id = 42
     ORDER BY created_at DESC
     LIMIT 10'
);

-- ─── Questions à remplir ──────────────────────────────────────
-- Using filesort a-t-il disparu ? (oui / non) : ?
-- type  avant = ?      type  après = ?
-- rows  avant = ?      rows  après = ?
-- Quelle est la différence de cost entre les deux plans ? _______


-- ┌─────────────────────────────────────────────────────────────┐
-- │  EXERCICE 2 — La règle du préfixe le plus à gauche (7 min) │
-- └─────────────────────────────────────────────────────────────┘
--
--  Contexte :
--  Vous avez maintenant un index composite sur (customer_id, created_at).
--  Voyons dans quels cas il est utilisé — et dans quels cas il ne l'est pas.
--
--  Analysez chacune des requêtes suivantes et notez si l'index
--  composite est utilisé ou non, et pourquoi.

-- Requête A : filtre sur les deux colonnes
CALL analyse_requete(
    'SELECT id, total
     FROM orders
     WHERE customer_id = 42
       AND created_at >= ''2024-01-01'''
);

-- Requête B : filtre sur la première colonne seulement
CALL analyse_requete(
    'SELECT id, total
     FROM orders
     WHERE customer_id = 42'
);

-- Requête C : filtre sur la deuxième colonne seulement (sans la première)
CALL analyse_requete(
    'SELECT id, total
     FROM orders
     WHERE created_at >= ''2024-01-01'''
);

-- Requête D : tri sur la deuxième colonne sans filtre sur la première
CALL analyse_requete(
    'SELECT id, total
     FROM orders
     ORDER BY created_at DESC
     LIMIT 20'
);

-- ─── Questions à remplir ──────────────────────────────────────
-- Requête A : index utilisé ? (oui/non) : ?   type = ?
-- Requête B : index utilisé ? (oui/non) : ?   type = ?
-- Requête C : index utilisé ? (oui/non) : ?   type = ?
-- Requête D : index utilisé ? (oui/non) : ?   type = ?
--
-- Formulez la règle du préfixe en une phrase :
-- _______________________________________________________________


-- ┌─────────────────────────────────────────────────────────────┐
-- │  EXERCICE 3 — Ce qui casse un index (8 min)                 │
-- └─────────────────────────────────────────────────────────────┘
--
--  Contexte :
--  Même avec un index disponible, certaines écritures de requêtes
--  empêchent MySQL de l'utiliser. Identifiez le problème dans
--  chaque cas et proposez une réécriture qui utilise l'index.

-- Cas A : fonction sur la colonne indexée
--  Le service marketing veut toutes les commandes de l'année 2024.
CALL analyse_requete(
    'SELECT id, customer_id, total
     FROM orders
     WHERE YEAR(created_at) = 2024'
);

-- ─── Questions à remplir ──────────────────────────────────────
-- L'index idx_orders_created est-il utilisé ? (oui/non) : ?
-- Pourquoi ? ____________________________________________________
-- Réécrivez la requête pour utiliser l'index :
-- SELECT id, customer_id, total FROM orders WHERE ...


-- Cas B : LIKE avec wildcard en préfixe
--  Recherche de codes promo commençant par n'importe quoi et finissant par "SUMMER".
CALL analyse_requete(
    'SELECT id, customer_id, coupon_code
     FROM orders
     WHERE coupon_code LIKE ''%SUMMER'''
);

-- ─── Questions à remplir ──────────────────────────────────────
-- Un index sur coupon_code serait-il utilisé ici ? (oui/non) : ?
-- Pourquoi un LIKE ''%...'' casse-t-il l'index ? _______________
-- Quelle alternative proposez-vous si cette recherche est fréquente ?
-- _______________________________________________________________


-- Cas C : conversion de type implicite
--  Un développeur passe customer_id en chaîne de caractères.
CALL analyse_requete(
    'SELECT id, total
     FROM orders
     WHERE customer_id = ''42'''
);

-- ─── Questions à remplir ──────────────────────────────────────
-- L'index est-il utilisé malgré la chaîne ''42'' ? (oui/non) : ?
-- MySQL gère-t-il toujours le cast implicite de VARCHAR vers INT ?
-- Dans quel sens le cast est-il dangereux pour l'index ? ________


-- ┌─────────────────────────────────────────────────────────────┐
-- │  EXERCICE 4 — Index couvrant (covering index)  (7 min)      │
-- └─────────────────────────────────────────────────────────────┘
--
--  Contexte :
--  Un index couvrant contient TOUTES les colonnes nécessaires à
--  la requête (WHERE + SELECT). MySQL peut alors répondre en
--  lisant uniquement l'index, sans toucher la table.
--  C'est le Saint Graal de l'optimisation par index.
--  On le reconnaît à "Using index" dans la colonne Extra.
--
--  4a. Comparez ces deux requêtes sur la même table order_items.

CALL comparer_requetes(
    -- Requête A : colonnes non couvertes par l'index
    'SELECT order_id, product_id, quantity, unit_price, discount
     FROM order_items
     WHERE order_id = 100',

    -- Requête B : colonnes toutes présentes dans idx_order_items_order
    'SELECT order_id
     FROM order_items
     WHERE order_id = 100'
);

-- ─── Questions à remplir ──────────────────────────────────────
-- Requête A : Extra contient-il "Using index" ? (oui/non) : ?
-- Requête B : Extra contient-il "Using index" ? (oui/non) : ?
-- Quelle est la différence de cost entre A et B ? ______________
-- Expliquez pourquoi B est plus rapide en termes d'I/O : ________

--  4b. Créez un index couvrant pour la requête suivante
--      (rapport des ventes par produit) et vérifiez le résultat.

CALL analyse_requete(
    'SELECT product_id, SUM(quantity) AS total_qty, SUM(unit_price * quantity) AS ca
     FROM order_items
     GROUP BY product_id
     ORDER BY ca DESC
     LIMIT 10'
);

-- Votre index couvrant :
-- CREATE INDEX ... ON order_items (...);

-- Relancez après création et vérifiez que "Using index" apparaît.


-- ┌─────────────────────────────────────────────────────────────┐
-- │  EXERCICE 5 — Cas réel : requête multi-critères (5 min)     │
-- └─────────────────────────────────────────────────────────────┘
--
--  Contexte :
--  Le back-office affiche la liste des commandes "shipped"
--  des 30 derniers jours, triée par montant décroissant.
--  Cette requête est appelée toutes les 10 secondes par
--  le tableau de bord opérationnel.
--
--  5a. Analysez la requête telle quelle.

CALL analyse_requete(
    'SELECT id, customer_id, total, created_at
     FROM orders
     WHERE status = ''shipped''
       AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
     ORDER BY total DESC
     LIMIT 50'
);

-- ─── Questions à remplir ──────────────────────────────────────
-- type = ?    key = ?    rows = ?    Extra = ?
-- Quels index existants sont candidates (possible_keys) ? _______

--  5b. Proposez l'index le plus adapté à cette requête.
--      Réfléchissez à l'ordre des colonnes et justifiez votre choix.

-- Votre réponse :
-- CREATE INDEX ... ON orders (...);
-- Justification : _______________________________________________

--  5c. Vérifiez avec comparer_requetes que votre index est utilisé
--      et que le cost a diminué.

CALL comparer_requetes(
    'SELECT id, customer_id, total, created_at
     FROM orders
     WHERE status = ''shipped''
       AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
     ORDER BY total DESC
     LIMIT 50',

    'SELECT id, customer_id, total, created_at
     FROM orders
     WHERE status = ''shipped''
       AND created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
     ORDER BY total DESC
     LIMIT 50'
);

-- ┌─────────────────────────────────────────────────────────────┐
-- │  EXERCICE 6 — Sous-requête corrélée → JOIN  (8 min)         │
-- └─────────────────────────────────────────────────────────────┘
--
--  Contexte :
--  Le service client veut la liste des clients avec le montant
--  de leur dernière commande. Un développeur a écrit cette requête
--  qui fonctionne, mais elle est très lente sur 50 000 clients.

-- Requête originale (sous-requête corrélée)
CALL analyse_requete(
    'SELECT
         c.id,
         c.first_name,
         c.last_name,
         c.email,
         (SELECT MAX(o.total)
          FROM orders o
          WHERE o.customer_id = c.id) AS derniere_commande
     FROM customers c
     WHERE c.is_active = 1
     LIMIT 100'
);

-- ─── Questions à remplir ──────────────────────────────────────
-- Combien de fois la sous-requête est-elle exécutée ? __________
-- Quel est le type d'accès sur orders dans la sous-requête ? ___
-- Quel est le coût total estimé ? _____________________________
-- Pourquoi dit-on que cette sous-requête est "corrélée" ? ______

--  Réécrivez cette requête en utilisant un JOIN et une agrégation.
--  Le résultat doit être identique.

-- Votre réécriture :
-- SELECT ...
-- FROM customers c
-- ...

-- Comparez les deux versions :
CALL comparer_requetes(
    'SELECT
         c.id, c.first_name, c.last_name, c.email,
         (SELECT MAX(o.total)
          FROM orders o
          WHERE o.customer_id = c.id) AS derniere_commande
     FROM customers c
     WHERE c.is_active = 1
     LIMIT 100',

    -- Remplacez cette ligne par votre réécriture
    'SELECT c.id, c.first_name, c.last_name, c.email, NULL AS derniere_commande
     FROM customers c WHERE c.is_active = 1 LIMIT 100'
);

-- ─── Questions à remplir ──────────────────────────────────────
-- Différence de cost entre les deux versions : _________________
-- Différence de rows estimées : ________________________________
-- La sous-requête corrélée est-elle toujours plus lente ? _______