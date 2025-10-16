package com.locationtracker.user.controller;

import com.locationtracker.user.dto.UserRequest;
import com.locationtracker.user.dto.UserResponse;
import com.locationtracker.user.service.UserService;
import jakarta.validation.Valid;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/users")
@Slf4j
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    public ResponseEntity<UserResponse> createOrUpdate(@Valid @RequestBody UserRequest request) {
        log.debug("Recibida petición de registro/actualización de usuario: {}", request.firebaseUid());
        try {
            UserResponse response = userService.createOrUpdate(request);
            log.debug("Usuario procesado correctamente: {}", response.firebaseUid());
            return ResponseEntity.status(HttpStatus.CREATED).body(response);
        } catch (Exception ex) {
            log.error("Error procesando usuario {}", request.firebaseUid(), ex);
            throw ex;
        }
    }

    @GetMapping
    public List<UserResponse> findAll() {
        log.debug("Listando usuarios registrados");
        try {
            return userService.findAll();
        } catch (Exception ex) {
            log.error("Error listando usuarios", ex);
            throw ex;
        }
    }

    @GetMapping("/{firebaseUid}")
    public UserResponse getByFirebaseUid(@PathVariable String firebaseUid) {
        log.debug("Consultando usuario por firebaseUid={} ", firebaseUid);
        try {
            return userService.getByFirebaseUid(firebaseUid);
        } catch (Exception ex) {
            log.error("Error consultando usuario {}", firebaseUid, ex);
            throw ex;
        }
    }
}
