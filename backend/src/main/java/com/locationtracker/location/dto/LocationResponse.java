package com.locationtracker.location.dto;

import java.time.OffsetDateTime;

public record LocationResponse(
        Long id,
        Double latitude,
        Double longitude,
        OffsetDateTime timestamp,
        Double accuracy,
        Double altitude,
        Double speed,
        Double heading,
        Integer batteryLevel,
        String activityType
) {
}
