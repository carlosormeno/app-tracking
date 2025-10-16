package com.locationtracker.user.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

public record UserRequest(
        @NotBlank @Email String email,
        @NotBlank String firebaseUid
) {
}
