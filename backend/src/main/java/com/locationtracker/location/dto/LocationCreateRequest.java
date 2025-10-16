package com.locationtracker.location.dto;

import jakarta.validation.constraints.DecimalMax;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.OffsetDateTime;

public record LocationCreateRequest(
        @NotBlank String firebaseUid,
        @NotNull @DecimalMin(value = "-90.0") @DecimalMax(value = "90.0") Double latitude,
        @NotNull @DecimalMin(value = "-180.0") @DecimalMax(value = "180.0") Double longitude,
        @NotNull OffsetDateTime timestamp,
        Double accuracy,
        Double altitude,
        Double speed,
        Double heading,
        Integer batteryLevel,
        String activityType
) {
}
