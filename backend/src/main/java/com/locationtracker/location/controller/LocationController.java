package com.locationtracker.location.controller;

import com.locationtracker.location.dto.DailyDistanceResponse;
import com.locationtracker.location.dto.LocationCreateRequest;
import com.locationtracker.location.dto.LocationHistoryResponse;
import com.locationtracker.location.dto.LocationResponse;
import com.locationtracker.location.service.LocationService;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDate;
import java.time.OffsetDateTime;

@RestController
@RequestMapping("/api/locations")
@Slf4j
public class LocationController {

    private final LocationService locationService;

    public LocationController(LocationService locationService) {
        this.locationService = locationService;
    }

    @PostMapping
    public ResponseEntity<LocationResponse> create(@Valid @RequestBody LocationCreateRequest request) {
        log.debug("Recibida ubicación para firebaseUid={} lat={} lng={}",
                request.firebaseUid(), request.latitude(), request.longitude());
        try {
            LocationResponse response = locationService.create(request);
            log.debug("Ubicación almacenada con id={}", response.id());
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (Exception ex) {
            log.error("Error almacenando ubicación para firebaseUid={}", request.firebaseUid(), ex);
            throw ex;
        }
    }

    @GetMapping("/history")
    public LocationHistoryResponse history(
            @RequestParam String firebaseUid,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime start,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime end
    ) {
        log.debug("Consultando historial para uid={} start={} end={}", firebaseUid, start, end);
        try {
            return locationService.getHistory(firebaseUid, start, end);
        } catch (Exception ex) {
            log.error("Error consultando historial para uid={}", firebaseUid, ex);
            throw ex;
        }
    }

    @GetMapping("/distance")
    public DailyDistanceResponse distance(
            @RequestParam String firebaseUid,
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE) LocalDate date
    ) {
        log.debug("Consultando distancia para uid={} fecha={}", firebaseUid, date);
        try {
            return locationService.getDailyDistance(firebaseUid, date);
        } catch (Exception ex) {
            log.error("Error consultando distancia para uid={} fecha={} ", firebaseUid, date, ex);
            throw ex;
        }
    }
}
