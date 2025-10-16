package com.locationtracker.location.dto;

import java.time.OffsetDateTime;
import java.util.List;

public record LocationHistoryResponse(
        String firebaseUid,
        OffsetDateTime start,
        OffsetDateTime end,
        List<LocationResponse> points,
        double totalDistanceKm
) {
}
