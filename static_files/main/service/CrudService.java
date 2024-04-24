package com.maksym.mytest.service;

import java.util.List;

public interface CrudService<T> {
    public T create(T model);
    public T getById(Long id);
    public List<T> getAll();
    public T update(Long id, T model);
    public Boolean deleteById(Long id);
}
