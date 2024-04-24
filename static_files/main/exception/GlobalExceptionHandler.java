package com.maksym.mytest.exception;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.validation.FieldError;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.util.HashMap;
import java.util.Map;

@RestControllerAdvice
public class GlobalExceptionHandler {
    private final String DOCUMENTATION_URI;

    public GlobalExceptionHandler(@Value("${swagger.documentation.uri}") String DOCUMENTATION_URI) {
        this.DOCUMENTATION_URI = DOCUMENTATION_URI;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ResponseEntity<Object> handleConstraintViolationException(MethodArgumentNotValidException e) {
        Map<String, String> errors = new HashMap<>();
        e.getBindingResult().getAllErrors().forEach(error -> {
            String fieldName = ((FieldError) error).getField();
            String errorMessage = error.getDefaultMessage();
            errors.put(fieldName, errorMessage);
        });
        return new ResponseEntity<>(new ExceptionPayload(errors, DOCUMENTATION_URI), HttpStatus.BAD_REQUEST);
    }

    @ExceptionHandler(EntityNotFoundException.class)
    public ResponseEntity<Object> handlerEntityNotFoundException(EntityNotFoundException e){
        return new ResponseEntity<>(new ExceptionPayload(e.getMessage(), DOCUMENTATION_URI), HttpStatus.NOT_FOUND);
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Object> handlerDataAccessException(DataAccessException e){
        return new ResponseEntity<>(new ExceptionPayload(e.getMessage(), DOCUMENTATION_URI), HttpStatus.SERVICE_UNAVAILABLE);
    }
}
