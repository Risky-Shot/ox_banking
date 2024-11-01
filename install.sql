/*Add a new column fullname in players table*/;

ALTER TABLE players
   ADD COLUMN fullName VARCHAR(255)
	AS (CONCAT(
		JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.firstname')), 
		' ', 
		JSON_UNQUOTE(JSON_EXTRACT(charinfo, '$.lastname'))
	)) STORED 
AFTER name;

CREATE FULLTEXT INDEX IF NOT EXISTS `players_fullName_index`
  ON `players` (`fullName`);

/*Create Groups which store jobs/gangs data.*/;

CREATE TABLE IF NOT EXISTS `ox_groups` (
  `name` VARCHAR(20) NOT NULL,
  `label` VARCHAR(50) NOT NULL,
  `type` VARCHAR(50) NULL,
  `hasAccount` TINYINT(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Modify Player Groups Table*/;

ALTER TABLE player_groups
    ADD CONSTRAINT `fk_group`
    FOREIGN KEY (`group`)
    REFERENCES ox_groups(`name`)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

/*Create Accounts Table. Make Sure collate is same as foreign key columns*/;

CREATE TABLE IF NOT EXISTS `accounts` (
  `id` INT unsigned NOT NULL,
  `label` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `owner` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `group` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `balance` int(11) NOT NULL DEFAULT 0,
  `isDefault` tinyint(1) NOT NULL DEFAULT 0,
  `type` enum('personal','shared','group','inactive') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'personal',
  PRIMARY KEY (`id`),
  KEY `accounts_group_fk` (`group`),
  KEY `accounts_owner_fk` (`owner`),
  FULLTEXT KEY `accounts_label_index` (`label`),
  CONSTRAINT `accounts_group_fk` FOREIGN KEY (`group`) REFERENCES `ox_groups` (`name`) ON DELETE SET NULL ON UPDATE SET NULL,
  CONSTRAINT `accounts_owner_fk` FOREIGN KEY (`owner`) REFERENCES `players` (`citizenid`) ON DELETE SET NULL ON UPDATE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Create Account Roles Table*/;

CREATE TABLE `account_roles` (
  `id` INT(11) NOT NULL AUTO_INCREMENT,
  `name` VARCHAR(50) NOT NULL DEFAULT '',
  `deposit` TINYINT(1) NOT NULL DEFAULT '0',
  `withdraw` TINYINT(1) NOT NULL DEFAULT '0',
  `addUser` TINYINT(1) NOT NULL DEFAULT '0',
  `removeUser` TINYINT(1) NOT NULL DEFAULT '0',
  `manageUser` TINYINT(1) NOT NULL DEFAULT '0',
  `transferOwnership` TINYINT(1) NOT NULL DEFAULT '0',
  `viewHistory` TINYINT(1) NOT NULL DEFAULT '0',
  `manageAccount` TINYINT(1) NOT NULL DEFAULT '0',
  `closeAccount` TINYINT(1) NOT NULL DEFAULT '0',
  `sendInvoice` TINYINT(1) NOT NULL DEFAULT '0',
  `payInvoice` TINYINT(1) NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE INDEX `name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `account_roles` (`id`, `name`, `deposit`, `withdraw`, `addUser`, `removeUser`, `manageUser`, `transferOwnership`, `viewHistory`, `manageAccount`, `closeAccount`, `sendInvoice`, `payInvoice`) VALUES
  (1, 'viewer', 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (2, 'contributor', 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
  (3, 'manager', 1, 1, 1, 1, 1, 0, 1, 1, 0, 1, 1),
  (4, 'owner', 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1);

/*Create Group Grades Table. Make Sure collate is same as foreign key columns*/

CREATE TABLE IF NOT EXISTS `ox_group_grades` (
  `group` VARCHAR(20) NOT NULL,
  `grade` TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `label` VARCHAR(50) NOT NULL,
  `accountRole` VARCHAR(50) NULL DEFAULT NULL,
  PRIMARY KEY (`group`, `grade`),
  CONSTRAINT `ox_group_grades_group_fk` FOREIGN KEY (`group`) REFERENCES `ox_groups` (`name`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_ox_group_grades_account_roles` FOREIGN KEY (`accountRole`) REFERENCES `account_roles` (`name`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Create Account Access Table. Make Sure collate is same as foreign key columns*/;

CREATE TABLE IF NOT EXISTS `accounts_access` (
  `accountId` INT UNSIGNED NOT NULL,
  `charId` VARCHAR(50) NOT NULL,
  `role` VARCHAR(50) NOT NULL DEFAULT 'viewer',
  PRIMARY KEY (`accountId`, `charId`),
  CONSTRAINT `accounts_access_accountId_fk` FOREIGN KEY (`accountId`) REFERENCES `accounts` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `accounts_access_charId_fk` FOREIGN KEY (`charId`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `FK_accounts_access_account_roles` FOREIGN KEY (`role`) REFERENCES `account_roles` (`name`) ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

/*Store Transactions. Make Sure collate is same as foreign key columns*/;

CREATE TABLE IF NOT EXISTS `accounts_transactions` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `actorId` VARCHAR(50) DEFAULT NULL,
  `fromId` INT UNSIGNED DEFAULT NULL,
  `toId` INT UNSIGNED DEFAULT NULL,
  `amount` INT NOT NULL,
  `message` VARCHAR(255) NOT NULL,
  `note` VARCHAR(255) DEFAULT NULL,
  `fromBalance` INT DEFAULT NULL,
  `toBalance` INT DEFAULT NULL,
  `date` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `accounts_transactions_actorId_fk` FOREIGN KEY (`actorId`) REFERENCES `players` (`citizenid`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `accounts_transactions_fromId_fk` FOREIGN KEY (`fromId`) REFERENCES `accounts` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT `accounts_transactions_toId_fk` FOREIGN KEY (`toId`) REFERENCES `accounts` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE FULLTEXT INDEX IF NOT EXISTS `accounts_transactions_message_index`
  ON `accounts_transactions` (`message`);

/**/;

CREATE TABLE IF NOT EXISTS `accounts_invoices`
(
    `id`          INT UNSIGNED AUTO_INCREMENT           PRIMARY KEY,
    `actorId`     VARCHAR(50)                           NULL,
    `payerId`     VARCHAR(50)                           NULL,
    `fromAccount` INT UNSIGNED                      NOT NULL,
    `toAccount`   INT UNSIGNED                      NOT NULL,
    `amount`      INT UNSIGNED                          NOT NULL,
    `message`     VARCHAR(255)                          NULL,
    `sentAt`      TIMESTAMP DEFAULT CURRENT_TIMESTAMP() NOT NULL,
    `dueDate`     TIMESTAMP                             NOT NULL,
    `paidAt`      TIMESTAMP                             NULL,
    CONSTRAINT `accounts_invoices_accounts_id_fk`
        FOREIGN KEY (`fromAccount`) REFERENCES `accounts` (`id`),
    CONSTRAINT `accounts_invoices_accounts_id_fk_2`
        FOREIGN KEY (`toAccount`) REFERENCES `accounts` (`id`),
    CONSTRAINT `accounts_invoices_characters_charId_fk`
        FOREIGN KEY (`payerId`) REFERENCES `players` (`citizenid`),
    CONSTRAINT `accounts_invoices_characters_charId_fk_2`
        FOREIGN KEY (`actorId`) REFERENCES `players` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE FULLTEXT INDEX IF NOT EXISTS `idx_message_fulltext`
    ON `accounts_invoices` (`message`);