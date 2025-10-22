package com.locationtracker.user.controller;

import com.locationtracker.user.dto.UserRequest;
import com.locationtracker.user.dto.UserResponse;
import com.locationtracker.user.service.UserService;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.media.Content;
import io.swagger.v3.oas.annotations.media.Schema;
import io.swagger.v3.oas.annotations.responses.ApiResponse;
import io.swagger.v3.oas.annotations.tags.Tag;
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
@Tag(name = "Users", description = "Gestión de usuarios")
@Slf4j
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    @Operation(
            summary = "Crear/Actualizar usuario",
            description = "Registra o actualiza un usuario por su firebaseUid",
            responses = {
                    @ApiResponse(responseCode = "201", description = "Creado",
                            content = @Content(schema = @Schema(implementation = UserResponse.class))),
                    @ApiResponse(responseCode = "400", description = "Solicitud inválida")
            }
    )
    public ResponseEntity<UserResponse> createOrUpdate(
            @Valid @RequestBody
            @io.swagger.v3.oas.annotations.parameters.RequestBody(
                    description = "Payload de registro/actualización de usuario",
                    required = true,
                    content = @Content(schema = @Schema(implementation = UserRequest.class))
            ) UserRequest request) {
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
    @Operation(summary = "Listar usuarios", description = "Devuelve todos los usuarios registrados")
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
    @Operation(summary = "Obtener usuario", description = "Busca un usuario por su firebaseUid")
    public UserResponse getByFirebaseUid(
            @Parameter(description = "UID de Firebase", required = true)
            @PathVariable String firebaseUid) {
        log.debug("Consultando usuario por firebaseUid={} ", firebaseUid);
        try {
            return userService.getByFirebaseUid(firebaseUid);
        } catch (Exception ex) {
            log.error("Error consultando usuario {}", firebaseUid, ex);
            throw ex;
        }
    }
}
