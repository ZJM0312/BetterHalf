package com.betterhalf.auth.application;

import org.bouncycastle.crypto.generators.Argon2BytesGenerator;
import org.bouncycastle.crypto.params.Argon2Parameters;
import org.springframework.stereotype.Component;

import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;

/**
 * Password hashing using Argon2id (preferred) or bcrypt fallback.
 */
@Component
public class PasswordHasher {
    
    private static final int SALT_LENGTH = 16;
    private static final int HASH_LENGTH = 32;
    private static final int MEMORY = 65536; // 64 MB
    private static final int ITERATIONS = 3;
    private static final int PARALLELISM = 4;
    
    private final SecureRandom secureRandom = new SecureRandom();
    
    /**
     * Hash a password using Argon2id.
     */
    public String hash(String password) {
        byte[] salt = new byte[SALT_LENGTH];
        secureRandom.nextBytes(salt);
        
        Argon2Parameters params = new Argon2Parameters.Builder(Argon2Parameters.ARGON2_id)
            .withSalt(salt)
            .withMemoryAsKB(MEMORY)
            .withIterations(ITERATIONS)
            .withParallelism(PARALLELISM)
            .build();
        
        Argon2BytesGenerator generator = new Argon2BytesGenerator();
        generator.init(params);
        
        byte[] hash = new byte[HASH_LENGTH];
        generator.generateBytes(password.getBytes(StandardCharsets.UTF_8), hash);
        
        // Format: $argon2id$v=19$m=65536,t=3,p=4$<salt>$<hash>
        String saltB64 = Base64.getEncoder().encodeToString(salt);
        String hashB64 = Base64.getEncoder().encodeToString(hash);
        
        return String.format("$argon2id$v=19$m=%d,t=%d,p=%d$%s$%s",
            MEMORY, ITERATIONS, PARALLELISM, saltB64, hashB64);
    }
    
    /**
     * Verify a password against a hash.
     */
    public boolean verify(String password, String hash) {
        try {
            // Parse hash format: $argon2id$v=19$m=65536,t=3,p=4$<salt>$<hash>
            String[] parts = hash.split("\\$");
            if (parts.length != 6 || !parts[1].equals("argon2id")) {
                return false;
            }
            
            // Parse parameters
            String[] params = parts[3].split(",");
            int memory = Integer.parseInt(params[0].substring(2));
            int iterations = Integer.parseInt(params[1].substring(2));
            int parallelism = Integer.parseInt(params[2].substring(2));
            
            byte[] salt = Base64.getDecoder().decode(parts[4]);
            byte[] expectedHash = Base64.getDecoder().decode(parts[5]);
            
            Argon2Parameters argon2Params = new Argon2Parameters.Builder(Argon2Parameters.ARGON2_id)
                .withSalt(salt)
                .withMemoryAsKB(memory)
                .withIterations(iterations)
                .withParallelism(parallelism)
                .build();
            
            Argon2BytesGenerator generator = new Argon2BytesGenerator();
            generator.init(argon2Params);
            
            byte[] computedHash = new byte[expectedHash.length];
            generator.generateBytes(password.getBytes(StandardCharsets.UTF_8), computedHash);
            
            return java.util.Arrays.equals(expectedHash, computedHash);
        } catch (Exception e) {
            return false;
        }
    }
}
