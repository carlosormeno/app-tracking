package com.locationtracker.user.controller;

import com.locationtracker.user.dto.UserResponse;
import com.locationtracker.user.service.UserService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.UUID;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(UserController.class)
class UserControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockBean
    private UserService userService;

    @Test
    void list_returnsUsers() throws Exception {
        var u = new UserResponse(UUID.randomUUID(), "a@b.com", "abc", OffsetDateTime.now(), OffsetDateTime.now());
        Mockito.when(userService.findAll()).thenReturn(List.of(u));
        mockMvc.perform(get("/api/users").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].firebaseUid").value("abc"));
    }

    @Test
    void getByUid_returnsUser() throws Exception {
        var u = new UserResponse(UUID.randomUUID(), "a@b.com", "abc", OffsetDateTime.now(), OffsetDateTime.now());
        Mockito.when(userService.getByFirebaseUid("abc")).thenReturn(u);
        mockMvc.perform(get("/api/users/abc").accept(MediaType.APPLICATION_JSON))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value("a@b.com"));
    }
}

