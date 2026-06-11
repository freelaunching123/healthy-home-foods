import api from './axios';

export const getUsers = (params = {}) => api.get('/users/', { params });
export const getUser = (id) => api.get(`/users/${id}`);
export const updateUser = (id, data) => api.put(`/users/${id}`, data);
export const deactivateUser = (id) => api.delete(`/users/${id}`);
export const getMe = () => api.get('/users/me');
export const updateMe = (data) => api.put('/users/me', data);
