import api from './axios';

// Categories
export const getCategories = (active_only = false) =>
  api.get('/products/categories', { params: { active_only } });

export const createCategory = (data) => api.post('/products/categories', data);
export const updateCategory = (id, data) => api.put(`/products/categories/${id}`, data);

// Products
export const getProducts = (params = {}) => api.get('/products/', { params });
export const getProduct = (id) => api.get(`/products/${id}`);
export const createProduct = (data) => api.post('/products/', data);
export const updateProduct = (id, data) => api.put(`/products/${id}`, data);
export const deleteProduct = (id) => api.delete(`/products/${id}`);
export const uploadProductImage = (id, formData) =>
  api.post(`/products/${id}/image`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
