package com.locationtracker.health;

import lombok.extern.slf4j.Slf4j;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

@RestController
@RequestMapping("/api/health")
@Slf4j
public class DatabaseHealthController {

    private final JdbcTemplate jdbcTemplate;

    public DatabaseHealthController(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @GetMapping("/db")
    public Map<String, Object> databaseStatus() {
        Integer result = jdbcTemplate.queryForObject("SELECT 1", Integer.class);
        log.debug("Health-check DB ejecutado, resultado={}", result);
        return Map.of("status", "UP", "db", result);
    }
}
