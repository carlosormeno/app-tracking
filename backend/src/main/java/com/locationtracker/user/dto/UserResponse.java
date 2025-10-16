package com.locationtracker.user.dto;

import java.time.OffsetDateTime;
import java.util.UUID;

public record UserResponse(
        UUID id,
        String email,
        String firebaseUid,
        OffsetDateTime createdAt,
        OffsetDateTime updatedAt
) {
}
