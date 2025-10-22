package com.locationtracker.config;

import io.swagger.v3.oas.annotations.OpenAPIDefinition;
import io.swagger.v3.oas.annotations.info.Contact;
import io.swagger.v3.oas.annotations.info.Info;
import io.swagger.v3.oas.annotations.servers.Server;
import org.springframework.context.annotation.Configuration;

@Configuration
@OpenAPIDefinition(
        info = @Info(
                title = "ONP Thaqhiri API",
                version = "1.0.0",
                description = "API para registro de ubicaciones, historial y usuarios de la aplicación ONP Thaqhiri.",
                contact = @Contact(name = "Equipo ONP Thaqhiri")
        ),
        servers = {
                @Server(url = "/", description = "Servidor actual")
        }
)
public class OpenApiConfig {
}

