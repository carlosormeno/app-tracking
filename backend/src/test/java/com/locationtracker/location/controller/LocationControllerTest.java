package com.locationtracker.location.controller;

import com.locationtracker.location.dto.DailyDistanceResponse;
import com.locationtracker.location.dto.LocationHistoryResponse;
import com.locationtracker.location.dto.LocationResponse;
import com.locationtracker.location.service.LocationService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(LocationController.class)
class LocationControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private LocationService locationService;

    @Test
    void history_returnsPayload() throws Exception {
        var now = OffsetDateTime.now();
        var resp = new LocationHistoryResponse(
                "abc",
                now.minusHours(1),
                now,
                List.of(new LocationResponse(1L, -12.05, -77.05, now, null, null, null, null, null, null)),
                1.23
        );
        Mockito.when(locationService.getHistory(Mockito.anyString(), Mockito.any(), Mockito.any()))
                .thenReturn(resp);

        mockMvc.perform(get("/api/locations/history")
                        .param("firebaseUid", "abc")
                        .param("start", now.minusHours(1).toString())
                        .param("end", now.toString())
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.firebaseUid").value("abc"))
                .andExpect(jsonPath("$.points[0].latitude").value(-12.05));
    }

    @Test
    void distance_returnsPayload() throws Exception {
        var today = LocalDate.now();
        var resp = new DailyDistanceResponse("abc", today, 2.5);
        Mockito.when(locationService.getDailyDistance(Mockito.anyString(), Mockito.any()))
                .thenReturn(resp);

        mockMvc.perform(get("/api/locations/distance")
                        .param("firebaseUid", "abc")
                        .param("date", today.toString())
                        .accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.distanceKm").value(2.5));
    }
}

