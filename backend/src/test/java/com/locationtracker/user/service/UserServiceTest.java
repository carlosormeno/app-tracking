package com.locationtracker.user.service;

import com.locationtracker.common.exception.ResourceNotFoundException;
import com.locationtracker.user.User;
import com.locationtracker.user.UserRepository;
import com.locationtracker.user.dto.UserRequest;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class UserServiceTest {

    private UserRepository repo;
    private UserService service;

    @BeforeEach
    void setup() {
        repo = mock(UserRepository.class);
        service = new UserService(repo);
    }

    @Test
    void createOrUpdate_insertsWhenNotExists() {
        when(repo.findByFirebaseUid("abc")).thenReturn(Optional.empty());
        User saved = new User();
        saved.setFirebaseUid("abc");
        saved.setEmail("a@b.com");
        when(repo.save(any(User.class))).thenReturn(saved);

        var res = service.createOrUpdate(new UserRequest("a@b.com", "abc"));
        assertEquals("abc", res.firebaseUid());
        verify(repo, times(1)).save(any(User.class));
    }

    @Test
    void getByFirebaseUid_throwsWhenMissing() {
        when(repo.findByFirebaseUid("missing")).thenReturn(Optional.empty());
        assertThrows(ResourceNotFoundException.class, () -> service.getByFirebaseUid("missing"));
    }
}

