-- =============================================================
--  BASE E-COMMERCE — Schéma complet
-- =============================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';
SET foreign_key_checks = 0;

DROP DATABASE IF EXISTS ecommerce_formation;
CREATE DATABASE ecommerce_formation
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE ecommerce_formation;

-- -------------------------------------------------------------
-- TABLE : categories
-- Hiérarchie à 2 niveaux (parent_id NULL = catégorie racine)
-- ~200 lignes — petite table de référence
-- -------------------------------------------------------------
CREATE TABLE categories (
    id         INT          UNSIGNED NOT NULL AUTO_INCREMENT,
    name       VARCHAR(100) NOT NULL,
    slug       VARCHAR(110) NOT NULL,
    parent_id  INT UNSIGNED          DEFAULT NULL,
    created_at DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_categories_slug (slug),
    KEY        fk_categories_parent (parent_id),
    CONSTRAINT fk_categories_parent
        FOREIGN KEY (parent_id) REFERENCES categories (id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
-- TABLE : customers
-- ~50 000 lignes
-- -------------------------------------------------------------
CREATE TABLE customers (
    id         INT           UNSIGNED NOT NULL AUTO_INCREMENT,
    email      VARCHAR(180)  NOT NULL,
    first_name VARCHAR(80)   NOT NULL,
    last_name  VARCHAR(80)   NOT NULL,
    country    CHAR(2)       NOT NULL DEFAULT 'FR',
    birthdate  DATE                   DEFAULT NULL,
    is_active  TINYINT(1)    NOT NULL DEFAULT 1,
    created_at DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                             ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_customers_email (email),
    KEY        idx_customers_country   (country),
    KEY        idx_customers_created   (created_at),
    KEY        idx_customers_active    (is_active)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
-- TABLE : products
-- ~10 000 lignes
-- -------------------------------------------------------------
CREATE TABLE products (
    id          INT            UNSIGNED NOT NULL AUTO_INCREMENT,
    sku         VARCHAR(50)    NOT NULL,
    name        VARCHAR(255)   NOT NULL,
    description TEXT                    DEFAULT NULL,
    price       DECIMAL(10,2)  NOT NULL,
    cost        DECIMAL(10,2)           DEFAULT NULL,
    stock       INT            NOT NULL DEFAULT 0,
    category_id INT UNSIGNED            DEFAULT NULL,
    is_active   TINYINT(1)     NOT NULL DEFAULT 1,
    created_at  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                               ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_products_sku         (sku),
    KEY        idx_products_category   (category_id),
    KEY        idx_products_price      (price),
    KEY        idx_products_active     (is_active),
    KEY        idx_products_created    (created_at),
    CONSTRAINT fk_products_category
        FOREIGN KEY (category_id) REFERENCES categories (id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
-- TABLE : orders
-- ⚡ TABLE CENTRALE — ~100 000 lignes (volume moyen)
-- C'est ici que se jouent tous les exercices d'optimisation
-- Volontairement SANS index sur customer_id au départ
-- -------------------------------------------------------------
CREATE TABLE orders (
    id          INT           UNSIGNED NOT NULL AUTO_INCREMENT,
    customer_id INT           UNSIGNED NOT NULL,
    status      ENUM(
                    'pending',
                    'confirmed',
                    'shipped',
                    'delivered',
                    'cancelled',
                    'refunded'
                )             NOT NULL DEFAULT 'pending',
    total       DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    shipping    DECIMAL(8,2)  NOT NULL DEFAULT 0.00,
    discount    DECIMAL(8,2)  NOT NULL DEFAULT 0.00,
    coupon_code VARCHAR(50)            DEFAULT NULL,
    note        TEXT                   DEFAULT NULL,
    created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
    shipped_at  DATETIME               DEFAULT NULL,
    delivered_at DATETIME              DEFAULT NULL,
    PRIMARY KEY (id),
    -- ⚠ Pas d'index sur customer_id intentionnellement (TP 1 & 2)
    KEY idx_orders_status    (status),
    KEY idx_orders_created   (created_at),
    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id) REFERENCES customers (id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- -------------------------------------------------------------
-- TABLE : order_items
-- ~300 000 lignes (3 lignes en moyenne par commande)
-- -------------------------------------------------------------
CREATE TABLE order_items (
    id          INT           UNSIGNED NOT NULL AUTO_INCREMENT,
    order_id    INT           UNSIGNED NOT NULL,
    product_id  INT           UNSIGNED NOT NULL,
    quantity    SMALLINT      UNSIGNED NOT NULL DEFAULT 1,
    unit_price  DECIMAL(10,2) NOT NULL,
    discount    DECIMAL(8,2)  NOT NULL DEFAULT 0.00,
    created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_order_items_order   (order_id),
    KEY idx_order_items_product (product_id),
    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)   REFERENCES orders   (id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id) REFERENCES products (id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- =============================================================
--  PROCÉDURE : generate_data
--  Génère des données réalistes pour tous les TP
--  Usage : CALL generate_data(50000, 10000, 100000);
--            p_customers : nombre de clients
--            p_products  : nombre de produits
--            p_orders    : nombre de commandes
-- =============================================================
DELIMITER $$

CREATE PROCEDURE generate_data(
    IN p_customers INT,
    IN p_products  INT,
    IN p_orders    INT
)
BEGIN
    DECLARE i          INT DEFAULT 0;
    DECLARE v_cat_id   INT;
    DECLARE v_cust_id  INT;
    DECLARE v_order_id INT;
    DECLARE v_prod_id  INT;
    DECLARE v_items    INT;
    DECLARE v_total    DECIMAL(12,2);
    DECLARE v_price    DECIMAL(10,2);
    DECLARE v_qty      INT;
    DECLARE v_status   VARCHAR(20);
    DECLARE v_date     DATETIME;

    -- Désactiver les checks pour la vitesse d'insertion
    SET foreign_key_checks  = 0;
    SET unique_checks        = 0;
    SET autocommit           = 0;

    -- ----------------------------------------------------------
    -- 1. CATÉGORIES (structure fixe, réaliste)
    -- ----------------------------------------------------------
    INSERT IGNORE INTO categories (name, slug, parent_id) VALUES
        ('Électronique',        'electronique',         NULL),
        ('Informatique',        'informatique',         NULL),
        ('Mode',                'mode',                 NULL),
        ('Maison & Jardin',     'maison-jardin',        NULL),
        ('Sports & Loisirs',    'sports-loisirs',       NULL),
        ('Smartphones',         'smartphones',          1),
        ('Tablettes',           'tablettes',            1),
        ('Audio & Hi-Fi',       'audio-hifi',           1),
        ('TV & Vidéo',          'tv-video',             1),
        ('Ordinateurs portables','ordinateurs-portables',2),
        ('PC Fixes',            'pc-fixes',             2),
        ('Périphériques',       'peripheriques',        2),
        ('Composants',          'composants',           2),
        ('Homme',               'mode-homme',           3),
        ('Femme',               'mode-femme',           3),
        ('Enfants',             'mode-enfants',         3),
        ('Chaussures',          'chaussures',           3),
        ('Meubles',             'meubles',              4),
        ('Cuisine',             'cuisine',              4),
        ('Outillage',           'outillage',            4),
        ('Jardinage',           'jardinage',            4),
        ('Fitness',             'fitness',              5),
        ('Vélos',               'velos',                5),
        ('Randonnée',           'randonnee',            5),
        ('Sports collectifs',   'sports-collectifs',    5);

    -- ----------------------------------------------------------
    -- 2. CLIENTS
    -- ----------------------------------------------------------
    SET i = 0;
    WHILE i < p_customers DO
        INSERT INTO customers (email, first_name, last_name, country, birthdate, is_active, created_at)
        VALUES (
            CONCAT('user', i, '_', FLOOR(RAND()*9000+1000), '@exemple.fr'),
            ELT(FLOOR(RAND()*10)+1, 'Alice','Bob','Camille','David','Emma',
                                    'Fabien','Grace','Hugo','Inès','Jules'),
            ELT(FLOOR(RAND()*10)+1, 'Martin','Dupont','Bernard','Thomas','Petit',
                                    'Robert','Richard','Durand','Moreau','Simon'),
            ELT(FLOOR(RAND()*5)+1, 'FR','BE','CH','CA','LU'),
            DATE_SUB(CURDATE(), INTERVAL FLOOR(RAND()*15000+6570) DAY),
            IF(RAND() > 0.05, 1, 0),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND()*1460) DAY)
        );
        SET i = i + 1;

        -- Commit par lots de 1000
        IF i MOD 1000 = 0 THEN
            COMMIT;
        END IF;
    END WHILE;
    COMMIT;

    -- ----------------------------------------------------------
    -- 3. PRODUITS
    -- ----------------------------------------------------------
    SET i = 0;
    WHILE i < p_products DO
        SET v_cat_id = FLOOR(RAND() * 25) + 1;
        SET v_price  = ROUND((RAND() * 990 + 10), 2);
        INSERT INTO products (sku, name, price, cost, stock, category_id, is_active, created_at)
        VALUES (
            CONCAT('SKU-', LPAD(i, 6, '0')),
            CONCAT(
                ELT(FLOOR(RAND()*6)+1,'Pro','Ultra','Smart','Essential','Premium','Basic'),
                ' ',
                ELT(FLOOR(RAND()*8)+1,'X','Z','S','Max','Lite','Air','Plus','Neo'),
                ' ',
                FLOOR(RAND()*9000+1000)
            ),
            v_price,
            ROUND(v_price * (RAND() * 0.3 + 0.4), 2),
            FLOOR(RAND() * 500),
            v_cat_id,
            IF(RAND() > 0.08, 1, 0),
            DATE_SUB(NOW(), INTERVAL FLOOR(RAND()*730) DAY)
        );
        SET i = i + 1;

        IF i MOD 1000 = 0 THEN
            COMMIT;
        END IF;
    END WHILE;
    COMMIT;

    -- ----------------------------------------------------------
    -- 4. COMMANDES + LIGNES DE COMMANDE
    -- ----------------------------------------------------------
    SET i = 0;
    WHILE i < p_orders DO
        -- Client aléatoire
        SET v_cust_id = FLOOR(RAND() * p_customers) + 1;

        -- Statut pondéré (répartition réaliste)
        SET v_status = CASE
            WHEN RAND() < 0.05 THEN 'pending'
            WHEN RAND() < 0.10 THEN 'confirmed'
            WHEN RAND() < 0.15 THEN 'shipped'
            WHEN RAND() < 0.70 THEN 'delivered'
            WHEN RAND() < 0.85 THEN 'cancelled'
            ELSE 'refunded'
        END;

        -- Date de création (2 dernières années)
        SET v_date = DATE_SUB(NOW(), INTERVAL FLOOR(RAND()*730) DAY);

        INSERT INTO orders (customer_id, status, total, shipping, discount, created_at, updated_at, shipped_at, delivered_at)
        VALUES (
            v_cust_id,
            v_status,
            0.00,   -- sera mis à jour après les lignes
            ROUND(RAND() * 15, 2),
            ROUND(RAND() * 20, 2),
            v_date,
            v_date,
            IF(v_status IN ('shipped','delivered'), DATE_ADD(v_date, INTERVAL FLOOR(RAND()*5+1) DAY), NULL),
            IF(v_status = 'delivered',              DATE_ADD(v_date, INTERVAL FLOOR(RAND()*10+3) DAY), NULL)
        );

        SET v_order_id = LAST_INSERT_ID();

        -- Lignes de commande (1 à 5 par commande)
        SET v_items = FLOOR(RAND() * 5) + 1;
        SET v_total = 0;

        WHILE v_items > 0 DO
            SET v_prod_id = FLOOR(RAND() * p_products) + 1;
            SET v_qty     = FLOOR(RAND() * 3) + 1;
            SET v_price   = ROUND(RAND() * 990 + 10, 2);

            INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount)
            VALUES (v_order_id, v_prod_id, v_qty, v_price, ROUND(RAND() * 5, 2));

            SET v_total = v_total + (v_qty * v_price);
            SET v_items = v_items - 1;
        END WHILE;

        -- Mise à jour du total de la commande
        UPDATE orders SET total = ROUND(v_total, 2) WHERE id = v_order_id;

        SET i = i + 1;

        IF i MOD 500 = 0 THEN
            COMMIT;
        END IF;
    END WHILE;
    COMMIT;

    -- Réactiver les checks
    SET foreign_key_checks = 1;
    SET unique_checks       = 1;
    SET autocommit          = 1;

    -- Résumé
    SELECT
        'categories'  AS `table`, COUNT(*) AS lignes FROM categories  UNION ALL
    SELECT 'customers',                               COUNT(*) FROM customers   UNION ALL
    SELECT 'products',                                COUNT(*) FROM products    UNION ALL
    SELECT 'orders',                                  COUNT(*) FROM orders      UNION ALL
    SELECT 'order_items',                             COUNT(*) FROM order_items;
END$$

DELIMITER ;


-- =============================================================
--  PROCÉDURE : analyse_requete
--  Wrapper autour de EXPLAIN ANALYZE
--  Utilisée dans tous les TPs pour comparer avant/après
--
--  Usage :
--    CALL analyse_requete('SELECT * FROM orders WHERE customer_id = 1');
-- =============================================================
DELIMITER $$

CREATE PROCEDURE analyse_requete(IN p_sql TEXT)
BEGIN
    -- Afficher la requête analysée
    SELECT CONCAT('🔍  Requête : ', p_sql) AS '';

    -- Plan d'exécution classique (statique)
    SET @q = CONCAT('EXPLAIN FORMAT=TRADITIONAL ', p_sql);
    PREPARE stmt FROM @q;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    -- Plan d'exécution JSON enrichi (coûts estimés)
    SET @q2 = CONCAT('EXPLAIN FORMAT=JSON ', p_sql);
    PREPARE stmt2 FROM @q2;
    EXECUTE stmt2;
    DEALLOCATE PREPARE stmt2;

    -- EXPLAIN ANALYZE : exécution réelle + métriques
    SET @q3 = CONCAT('EXPLAIN ANALYZE ', p_sql);
    PREPARE stmt3 FROM @q3;
    EXECUTE stmt3;
    DEALLOCATE PREPARE stmt3;
END$$

DELIMITER ;


-- =============================================================
--  PROCÉDURE : comparer_requetes
--  Compare deux requêtes côte à côte via EXPLAIN ANALYZE
--  Utilisée en TP pour valider un gain d'optimisation
--
--  Usage :
--    CALL comparer_requetes(
--        'SELECT * FROM orders WHERE customer_id = 1',   -- avant
--        'SELECT id, total FROM orders WHERE customer_id = 1'  -- après
--    );
-- =============================================================
DELIMITER $$

CREATE PROCEDURE comparer_requetes(
    IN p_sql_avant TEXT,
    IN p_sql_apres TEXT
)
BEGIN
    SELECT '─── AVANT ──────────────────────────────────────────' AS '';
    SET @q1 = CONCAT('EXPLAIN ANALYZE ', p_sql_avant);
    PREPARE stmt FROM @q1;
    EXECUTE stmt;
    DEALLOCATE PREPARE stmt;

    SELECT '─── APRÈS ──────────────────────────────────────────' AS '';
    SET @q2 = CONCAT('EXPLAIN ANALYZE ', p_sql_apres);
    PREPARE stmt2 FROM @q2;
    EXECUTE stmt2;
    DEALLOCATE PREPARE stmt2;
END$$

DELIMITER ;


-- =============================================================
--  PROCÉDURE : etat_index
--  Liste tous les index d'une table avec leurs statistiques
--
--  Usage : CALL etat_index('orders');
-- =============================================================
DELIMITER $$

CREATE PROCEDURE etat_index(IN p_table VARCHAR(100))
BEGIN
    SELECT
        INDEX_NAME       AS `Index`,
        SEQ_IN_INDEX     AS `Pos`,
        COLUMN_NAME      AS `Colonne`,
        CARDINALITY      AS `Cardinalité`,
        NON_UNIQUE       AS `Non unique`,
        INDEX_TYPE       AS `Type`
    FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME   = p_table
    ORDER BY INDEX_NAME, SEQ_IN_INDEX;
END$$

DELIMITER ;


-- =============================================================
--  INSTRUCTIONS DE DÉMARRAGE
-- =============================================================
-- 1. Charger ce fichier :
--      mysql -u root -p < ecommerce_schema.sql
--
-- 2. Générer les données (volume moyen recommandé) :
--      USE ecommerce_formation;
--      CALL generate_data(50000, 10000, 100000);
--    ⏱ Durée estimée : 3-5 minutes
--
-- 3. Vérifier le résultat :
--    La procédure affiche automatiquement le nombre de lignes
--    par table en fin d'exécution.
--
-- 4. Pour les TP, utiliser les procédures :
--      CALL analyse_requete('...');
--      CALL comparer_requetes('...avant...', '...apres...');
--      CALL etat_index('orders');
-- =============================================================