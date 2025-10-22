package com.locationtracker.location.service;

import com.locationtracker.location.LocationRecord;
import com.locationtracker.location.LocationRecordRepository;
import com.locationtracker.location.dto.LocationCreateRequest;
import com.locationtracker.user.User;
import com.locationtracker.user.service.UserService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.locationtech.jts.geom.Coordinate;
import org.locationtech.jts.geom.GeometryFactory;
import org.locationtech.jts.geom.Point;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;

import java.time.OffsetDateTime;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class LocationServiceTest {

    private LocationRecordRepository repo;
    private GeometryFactory geometryFactory;
    private UserService userService;
    private LocationService service;

    @BeforeEach
    void setup() {
        repo = mock(LocationRecordRepository.class);
        geometryFactory = mock(GeometryFactory.class);
        userService = mock(UserService.class);
        service = new LocationService(repo, geometryFactory, userService);
    }

    @Test
    void create_savesRecord() {
        var user = new User();
        user.setFirebaseUid("abc");
        when(userService.getEntityByFirebaseUid("abc")).thenReturn(user);

        Point point = mock(Point.class);
        when(geometryFactory.createPoint(any(Coordinate.class))).thenReturn(point);

        LocationRecord saved = new LocationRecord();
        saved.setId(1L);
        saved.setUser(user);
        saved.setGeom(point);
        saved.setTimestamp(OffsetDateTime.now());
        when(repo.save(any(LocationRecord.class))).thenReturn(saved);

        var req = new LocationCreateRequest(
                "abc", -12.0, -77.0, OffsetDateTime.now(), null, null, null, null, null, null
        );
        var resp = service.create(req);

        assertEquals(1L, resp.id());
        verify(repo, times(1)).save(any(LocationRecord.class));
    }

    @Test
    void history_usesRepositoryCalls() {
        var user = new User();
        user.setFirebaseUid("abc");
        user.setId(java.util.UUID.randomUUID());
        when(userService.getEntityByFirebaseUid("abc")).thenReturn(user);

        when(repo.findByUserAndTimestampBetweenOrderByTimestampAsc(any(), any(), any()))
                .thenReturn(List.of());
        when(repo.calculateDistanceMeters(any(), any(), any())).thenReturn(1500.0);

        var now = OffsetDateTime.now();
        var res = service.getHistory("abc", now.minusHours(1), now);
        assertEquals(1.5, res.totalDistanceKm(), 1e-6);
    }
}

