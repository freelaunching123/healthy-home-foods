import api from './axios';

export const getCategories = () => api.get('/products/categories', { params: { active_only: true } });
export const getProducts = (params = {}) => api.get('/products/', { params });
export const getProduct = (id) => api.get(`/products/${id}`);

export const getSubscriptions = () => api.get('/subscriptions/');
export const getSubscription = (id) => api.get(`/subscriptions/${id}`);
export const getSubscriptionDeliveries = (id) => api.get(`/subscriptions/${id}/deliveries`);
export const pauseSubscription = (id) => api.post(`/subscriptions/${id}/pause`);
export const resumeSubscription = (id) => api.post(`/subscriptions/${id}/resume`);
export const getPlans = () => api.get('/subscriptions/plans');

export const initiatePayment = (data) => api.post('/payments/initiate', data);
export const verifyPayment = (data) => api.post('/payments/verify', data);
export const getPaymentHistory = () => api.get('/payments/history');

export const getMe = () => api.get('/users/me');
export const updateMe = (data) => api.put('/users/me', data);

export const getGpsLocation = (assignmentId) => api.get(`/deliveries/gps/track/${assignmentId}`);
export const getSettings = () => api.get('/admin/settings/');
