package com.betterhalf.api.web.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.time.Duration;

/**
 * Rate limiting filter using Redis.
 * Limits by IP (unauth) and by user/couple (auth).
 */
@Component
@ConditionalOnProperty(name = "betterhalf.rate-limit.enabled", havingValue = "true", matchIfMissing = true)
public class RateLimitFilter extends OncePerRequestFilter {
    
    private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);
    
    private final RedisTemplate<String, String> redisTemplate;
    private final int perIpLimit;
    private final int perUserLimit;
    private final int windowSeconds;
    
    public RateLimitFilter(
        RedisTemplate<String, String> redisTemplate,
        @Value("${betterhalf.rate-limit.per-ip:100}") int perIpLimit,
        @Value("${betterhalf.rate-limit.per-user:1000}") int perUserLimit,
        @Value("${betterhalf.rate-limit.window-seconds:60}") int windowSeconds
    ) {
        this.redisTemplate = redisTemplate;
        this.perIpLimit = perIpLimit;
        this.perUserLimit = perUserLimit;
        this.windowSeconds = windowSeconds;
    }
    
    @Override
    protected void doFilterInternal(
        HttpServletRequest request,
        HttpServletResponse response,
        FilterChain filterChain
    ) throws ServletException, IOException {
        
        try {
            String key;
            int limit;
            
            // Get user ID from security context if authenticated
            String userId = (String) request.getAttribute("userId");
            if (userId != null) {
                key = "rate_limit:user:" + userId;
                limit = perUserLimit;
            } else {
                // Rate limit by IP for unauthenticated requests
                String ip = getClientIp(request);
                key = "rate_limit:ip:" + ip;
                limit = perIpLimit;
            }
            
            ValueOperations<String, String> ops = redisTemplate.opsForValue();
            String current = ops.get(key);
            
            int currentCount = current != null ? Integer.parseInt(current) : 0;
            
            if (currentCount >= limit) {
                response.setStatus(429);
                response.setContentType("application/json");
                response.setHeader("X-RateLimit-Limit", String.valueOf(limit));
                response.setHeader("X-RateLimit-Remaining", "0");
                response.setHeader("Retry-After", String.valueOf(windowSeconds));
                response.getWriter().write("{\"code\":\"RATE_LIMIT_EXCEEDED\",\"message\":\"Too many requests\"}");
                return;
            }
            
            // Increment counter
            if (current == null) {
                ops.set(key, "1", Duration.ofSeconds(windowSeconds));
            } else {
                ops.increment(key);
            }
            
            int remaining = limit - currentCount - 1;
            response.setHeader("X-RateLimit-Limit", String.valueOf(limit));
            response.setHeader("X-RateLimit-Remaining", String.valueOf(Math.max(0, remaining)));
        } catch (Exception e) {
            // If Redis is unavailable, log and continue without rate limiting
            log.warn("Rate limiting unavailable: {}", e.getMessage());
        }
        
        filterChain.doFilter(request, response);
    }
    
    private String getClientIp(HttpServletRequest request) {
        String xForwardedFor = request.getHeader("X-Forwarded-For");
        if (xForwardedFor != null && !xForwardedFor.isEmpty()) {
            return xForwardedFor.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
