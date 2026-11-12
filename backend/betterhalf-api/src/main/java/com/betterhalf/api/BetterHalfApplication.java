package com.betterhalf.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.domain.EntityScan;
import org.springframework.context.annotation.ComponentScan;
import org.springframework.data.jpa.repository.config.EnableJpaAuditing;
import org.springframework.data.jpa.repository.config.EnableJpaRepositories;

@SpringBootApplication
@ComponentScan(basePackages = "com.betterhalf")
@EnableJpaAuditing
@EnableJpaRepositories(basePackages = "com.betterhalf")
@EntityScan(basePackages = "com.betterhalf")
public class BetterHalfApplication {
    public static void main(String[] args) {
        SpringApplication.run(BetterHalfApplication.class, args);
    }
}
