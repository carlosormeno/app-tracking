package com.locationtracker.location.dto;

import java.time.LocalDate;

public record DailyDistanceResponse(
        String firebaseUid,
        LocalDate date,
        double distanceKm
) {
}
