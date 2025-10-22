package com.locationtracker.location.controller;

import com.locationtracker.location.dto.DailyDistanceResponse;
import com.locationtracker.location.dto.LocationCreateRequest;
import com.locationtracker.location.dto.LocationHistoryResponse;
import com.locationtracker.location.dto.LocationResponse;
import com.locationtracker.location.service.LocationService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
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
@Tag(name = "Locations", description = "Endpoints de ubicaciones: creación, historial y distancia diaria")
@Slf4j
public class LocationController {

    private final LocationService locationService;

    public LocationController(LocationService locationService) {
        this.locationService = locationService;
    }

    @PostMapping
    @Operation(
            summary = "Registrar ubicación",
            description = "Crea un registro de ubicación para un usuario identificado por su firebaseUid",
            responses = {
                    @ApiResponse(responseCode = "201", description = "Creado",
                            content = @Content(schema = @Schema(implementation = LocationResponse.class))),
                    @ApiResponse(responseCode = "400", description = "Solicitud inválida")
            }
    )
    public ResponseEntity<LocationResponse> create(
            @Valid @RequestBody
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    description = "Payload de creación de ubicación",
                    required = true,
                    content = @Content(schema = @Schema(implementation = LocationCreateRequest.class))
            ) LocationCreateRequest request) {
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
    @Operation(
            summary = "Historial de ubicaciones",
            description = "Obtiene el historial de ubicaciones entre un rango de fechas (UTC)",
            responses = @ApiResponse(responseCode = "200",
                    content = @Content(schema = @Schema(implementation = LocationHistoryResponse.class)))
    )
    public LocationHistoryResponse history(
            @Parameter(description = "UID de Firebase del usuario", required = true)
            @RequestParam String firebaseUid,
            @Parameter(description = "Fecha/hora de inicio (UTC)")
            @RequestParam @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) OffsetDateTime start,
            @Parameter(description = "Fecha/hora de fin (UTC)")
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
    @Operation(
            summary = "Distancia diaria",
            description = "Obtiene la distancia total recorrida por día (UTC)",
            responses = @ApiResponse(responseCode = "200",
                    content = @Content(schema = @Schema(implementation = DailyDistanceResponse.class)))
    )
    public DailyDistanceResponse distance(
            @Parameter(description = "UID de Firebase del usuario", required = true)
            @RequestParam String firebaseUid,
            @Parameter(description = "Fecha (UTC) en formato ISO yyyy-MM-dd")
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
