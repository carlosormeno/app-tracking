package com.locationtracker.user.service;

import com.locationtracker.common.exception.ResourceNotFoundException;
import com.locationtracker.user.User;
import com.locationtracker.user.UserRepository;
import com.locationtracker.user.dto.UserRequest;
import com.locationtracker.user.dto.UserResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.UUID;

@Service
@Transactional
@Slf4j
public class UserService {

    private final UserRepository userRepository;

    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public UserResponse createOrUpdate(UserRequest request) {
        log.debug("Procesando usuario {}", request.firebaseUid());
        User user = userRepository
                .findByFirebaseUid(request.firebaseUid())
                .orElseGet(User::new);

        user.setEmail(request.email());
        user.setFirebaseUid(request.firebaseUid());

        User saved = userRepository.save(user);
        log.debug("Usuario guardado con id={} firebaseUid={}", saved.getId(), saved.getFirebaseUid());
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public UserResponse getByFirebaseUid(String firebaseUid) {
        User user = userRepository.findByFirebaseUid(firebaseUid)
                .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado para firebaseUid=" + firebaseUid));
        log.debug("Usuario encontrado firebaseUid={}", firebaseUid);
        return toResponse(user);
    }

    @Transactional(readOnly = true)
    public List<UserResponse> findAll() {
        log.debug("Recuperando lista completa de usuarios");
        return userRepository.findAll().stream()
                .map(this::toResponse)
                .toList();
    }

    @Transactional(readOnly = true)
    public User getEntityByFirebaseUid(String firebaseUid) {
        return userRepository.findByFirebaseUid(firebaseUid)
                .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado para firebaseUid=" + firebaseUid));
    }

    @Transactional(readOnly = true)
    public User getEntity(UUID id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("Usuario no encontrado para id=" + id));
    }

    private UserResponse toResponse(User user) {
        return new UserResponse(
                user.getId(),
                user.getEmail(),
                user.getFirebaseUid(),
                user.getCreatedAt(),
                user.getUpdatedAt()
        );
    }
}
