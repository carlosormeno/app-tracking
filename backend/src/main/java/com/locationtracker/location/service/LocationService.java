package com.locationtracker.location.service;

import com.locationtracker.location.LocationRecord;
import com.locationtracker.location.LocationRecordRepository;
import com.locationtracker.location.dto.DailyDistanceResponse;
import com.locationtracker.location.dto.LocationCreateRequest;
import com.locationtracker.location.dto.LocationHistoryResponse;
import com.locationtracker.location.dto.LocationResponse;
import com.locationtracker.user.User;
import com.locationtracker.user.service.UserService;
import lombok.extern.slf4j.Slf4j;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.List;

@Service
@Transactional
@Slf4j
public class LocationService {

    private final LocationRecordRepository locationRecordRepository;
    private final GeometryFactory geometryFactory;
    private final UserService userService;

    public LocationService(LocationRecordRepository locationRecordRepository,
                           GeometryFactory geometryFactory,
                           UserService userService) {
        this.locationRecordRepository = locationRecordRepository;
        this.geometryFactory = geometryFactory;
        this.userService = userService;
    }

    public LocationResponse create(LocationCreateRequest request) {
        User user = userService.getEntityByFirebaseUid(request.firebaseUid());
        log.debug("Guardando ubicación para usuario {}", user.getFirebaseUid());

        Point geom = geometryFactory.createPoint(new Coordinate(
                request.longitude(),
                request.latitude()
        ));
        geom.setSRID(4326);

        LocationRecord record = new LocationRecord();
        record.setUser(user);
        record.setGeom(geom);
        record.setTimestamp(request.timestamp());
        record.setAccuracy(request.accuracy());
        record.setAltitude(request.altitude());
        record.setSpeed(request.speed());
        record.setHeading(request.heading());
        record.setBatteryLevel(request.batteryLevel());
        record.setActivityType(request.activityType());

        LocationRecord saved = locationRecordRepository.save(record);
        log.debug("Ubicación persistida con id={}", saved.getId());
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public LocationHistoryResponse getHistory(String firebaseUid, OffsetDateTime start, OffsetDateTime end) {
        User user = userService.getEntityByFirebaseUid(firebaseUid);
        log.debug("Obteniendo historial para uid={} entre {} y {}", firebaseUid, start, end);

        List<LocationResponse> points = locationRecordRepository
                .findByUserAndTimestampBetweenOrderByTimestampAsc(user, start, end)
                .stream()
                .map(this::toResponse)
                .toList();

        double distanceMeters = locationRecordRepository.calculateDistanceMeters(user.getId(), start, end);
        double distanceKm = distanceMeters / 1000.0;
        log.debug("Historial obtenido: puntos={} distanciaKm={}", points.size(), distanceKm);

        return new LocationHistoryResponse(firebaseUid, start, end, points, distanceKm);
    }

    @Transactional(readOnly = true)
    public DailyDistanceResponse getDailyDistance(String firebaseUid, LocalDate date) {
        User user = userService.getEntityByFirebaseUid(firebaseUid);
        log.debug("Calculando distancia diaria para uid={} fecha={}", firebaseUid, date);
        OffsetDateTime start = date.atStartOfDay().atOffset(ZoneOffset.UTC);
        OffsetDateTime end = start.plusDays(1);

        double distanceMeters = locationRecordRepository.calculateDistanceMeters(user.getId(), start, end);
        double distanceKm = distanceMeters / 1000.0;
        log.debug("Distancia diaria calculada: {} km", distanceKm);

        return new DailyDistanceResponse(firebaseUid, date, distanceKm);
    }

    private LocationResponse toResponse(LocationRecord record) {
        Point point = record.getGeom();
        Double latitude = point != null ? point.getY() : null;
        Double longitude = point != null ? point.getX() : null;
        return new LocationResponse(
                record.getId(),
                latitude,
                longitude,
                record.getTimestamp(),
                record.getAccuracy(),
                record.getAltitude(),
                record.getSpeed(),
                record.getHeading(),
                record.getBatteryLevel(),
                record.getActivityType()
        );
    }
}
