package com.betterhalf.api.web.dto;

import com.fasterxml.jackson.annotation.JsonInclude;

import java.time.Instant;

/**
 * Standard API error response.
 */
@JsonInclude(JsonInclude.Include.NON_NULL)
public class ApiError {
    private String code;
    private String message;
    private String requestId;
    private Instant timestamp;
    private Object details;
    
    public ApiError() {
        this.timestamp = Instant.now();
    }
    
    public ApiError(String code, String message, String requestId) {
        this();
        this.code = code;
        this.message = message;
        this.requestId = requestId;
    }
    
    public ApiError(String code, String message, String requestId, Object details) {
        this(code, message, requestId);
        this.details = details;
    }
    
    public String getCode() {
        return code;
    }
    
    public void setCode(String code) {
        this.code = code;
    }
    
    public String getMessage() {
        return message;
    }
    
    public void setMessage(String message) {
        this.message = message;
    }
    
    public String getRequestId() {
        return requestId;
    }
    
    public void setRequestId(String requestId) {
        this.requestId = requestId;
    }
    
    public Instant getTimestamp() {
        return timestamp;
    }
    
    public void setTimestamp(Instant timestamp) {
        this.timestamp = timestamp;
    }
    
    public Object getDetails() {
        return details;
    }
    
    public void setDetails(Object details) {
        this.details = details;
    }
}
