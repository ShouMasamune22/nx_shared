-- NOVARA CITY RP — nx_shared migration 001
-- Foundational, additive-only schema. Safe to re-run.

-- Per-character client preferences (HUD layout, notify position, etc.).
CREATE TABLE IF NOT EXISTS `nx_player_settings` (
    `citizenid` VARCHAR(50) NOT NULL,
    `settings` LONGTEXT NOT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Append-only audit trail for sensitive operations.
CREATE TABLE IF NOT EXISTS `nx_audit_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `category` VARCHAR(48) NOT NULL,
    `action` VARCHAR(96) NOT NULL,
    `actor` VARCHAR(64) NOT NULL DEFAULT 'system',
    `actor_source` INT NOT NULL DEFAULT 0,
    `target` VARCHAR(64) DEFAULT NULL,
    `detail` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_category_time` (`category`, `created_at`),
    KEY `idx_actor_time` (`actor`, `created_at`),
    KEY `idx_target` (`target`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Persistent structured logs (warnings and errors by default).
CREATE TABLE IF NOT EXISTS `nx_log` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `level` VARCHAR(16) NOT NULL,
    `resource` VARCHAR(64) NOT NULL,
    `message` VARCHAR(1024) NOT NULL,
    `detail` LONGTEXT DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    KEY `idx_level_time` (`level`, `created_at`),
    KEY `idx_resource_time` (`resource`, `created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
