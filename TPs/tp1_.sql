-- =============================================================
--  TP 1 — Lire un plan d'exécution EXPLAIN
--  Formation : Optimisation des Requêtes SQL — Séance 1
--  Prérequis : Base ecommerce_formation chargée et peuplée
-- =============================================================

USE ecommerce_formation;

-- =============================================================
--  RAPPEL — Colonnes clés de EXPLAIN
-- =============================================================
--
--  | Colonne       | Ce qu'elle dit                                      |
--  |---------------|-----------------------------------------------------|
--  | type          | Mode d'accès (ALL=scan complet, ref, eq_ref, const) |
--  | key           | Index utilisé (NULL = aucun)                        |
--  | rows          | Estimation du nombre de lignes lues                 |
--  | filtered      | % de lignes retenues après le WHERE                 |
--  | Extra         | Infos supplémentaires (Using filesort, Using index…) |
--
--  Hiérarchie des type (du pire au meilleur) :
--  ALL > index > range > ref > eq_ref > const > system
--
-- =============================================================


-- ┌─────────────────────────────────────────────────────────────┐
-- │  EXERCICE 1 — Identifier un Full Table Scan                 │
-- └─────────────────────────────────────────────────────────────┘
--
--  Contexte :
--  La page "Mes commandes" appelle la requête ci-dessous.
--  Le client se plaint que la page met plusieurs secondes à charger.
--
--  Question :
--  1. Analysez le plan d'exécution avec la procédure analyse_requete.
--  2. Identifiez la valeur de `type` et ce qu'elle signifie.
--  3. Combien de lignes MySQL doit-il lire pour retourner le résultat ?
--  4. Quel index est utilisé ? Pourquoi ?

-- Supprimer la foreign key et l'index sur la colonne customer_id 
ALTER TABLE orders DROP FOREIGN KEY fk_orders_customer;
DROP INDEX fk_orders_customer ON orders;

CALL analyse_requete(
    'SELECT id, status, total, created_at
     FROM orders
     WHERE customer_id = 42
     ORDER BY created_at DESC
     LIMIT 10'
);

-- ─── Questions à remplir ──────────────────────────────────────
-- type     = ?
-- key      = ?
-- rows     = ?
-- Extra    = ?
-- Diagnostic : ________________________________________________



-- ┌─────────────────────────────────────────────────────────────┐
-- │  EXERCICE 2 — Comparer deux requêtes (7 min)                │
-- └─────────────────────────────────────────────────────────────┘
--
--  Contexte :
--  Un développeur pense que remplacer SELECT * par une liste de
--  colonnes améliore le plan d'exécution. Est-il dans le vrai ?
--
--  Question :
--  Comparez les deux requêtes avec comparer_requetes.
--  Les plans sont-ils différents ? Pourquoi ?

CALL comparer_requetes(
    -- Requête A : SELECT *
    'SELECT *
     FROM orders
     WHERE customer_id = 42',

    -- Requête B : colonnes explicites
    'SELECT id, status, total, created_at
     FROM orders
     WHERE customer_id = 42'
);

-- ─── Questions à remplir ──────────────────────────────────────
-- Les plans sont-ils identiques ? (oui / non) : ?
-- La sélection de colonnes change-t-elle le nombre de lignes lues ? ?
-- Conclusion : ________________________________________________



-- ┌─────────────────────────────────────────────────────────────┐
-- │  EXERCICE 3 — Ajouter un index et mesurer le gain (8 min)   │
-- └─────────────────────────────────────────────────────────────┘
--
--  Contexte :
--  Suite à l'exercice 1, vous décidez d'ajouter un index.
--
--  3a. Avant d'ajouter l'index, vérifiez l'état actuel des index
--      sur la table orders.

CALL etat_index('orders');

-- Avant index (la même qu'exercice 1)
EXPLAIN ANALYZE SELECT id, status, total, created_at
     FROM orders
     WHERE customer_id = 42
     ORDER BY created_at DESC
     LIMIT 10;

--  3b. Ajoutez un index sur customer_id.

-- Votre réponse :
-- CREATE INDEX ... ON orders (...);


--  3c. Ré-exécutez la même requête qu'en exercice 1 et comparez.

EXPLAIN ANALYZE SELECT id, status, total, created_at
     FROM orders
     WHERE customer_id = 42
     ORDER BY created_at DESC
     LIMIT 10;

-- ─── Questions à remplir ──────────────────────────────────────
-- type avant  = ?          type après  = ?
-- rows avant  = ?          rows après  = ?
-- key  avant  = ?          key  après  = ?
-- Extra avant = ?          Extra après = ?
-- Gain estimé : ________________________________________________



-- ┌─────────────────────────────────────────────────────────────┐
-- │  EXERCICE 4 — Détecter un Using filesort (5 min)            │
-- └─────────────────────────────────────────────────────────────┘
--
--  Contexte :
--  Le rapport de direction affiche les 20 dernières commandes
--  par montant décroissant, tous clients confondus.
--
--  Question :
--  1. Analysez la requête.
--  2. Repérez "Using filesort" dans la colonne Extra.
--  3. Expliquez pourquoi il apparaît et dans quel cas c'est problématique.

CALL analyse_requete(
    'SELECT id, customer_id, total, status, created_at
     FROM orders
     ORDER BY total DESC
     LIMIT 20'
);

-- ─── Questions à remplir ──────────────────────────────────────
-- Extra contient-il "Using filesort" ? (oui / non) : ?
-- Pourquoi MySQL ne peut-il pas éviter le tri ici ?
-- _______________________________________________________________
-- Est-ce forcément un problème avec LIMIT 20 ? Pourquoi ?
-- _______________________________________________________________