package com.betterhalf.common.domain;

import java.util.UUID;

/**
 * Interface for couple information used in authorization.
 * Breaks circular dependency between authorization and couple modules.
 */
public interface CoupleInfo {
    UUID getId();
    Visibility getVisibility();
}
