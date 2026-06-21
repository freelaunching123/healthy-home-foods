import api from './axios';

export const getSubscriptions = (params = {}) => api.get('/subscriptions/', { params });
export const getSubscription = (id) => api.get(`/subscriptions/${id}`);
export const createSubscription = (payload) => api.post('/subscriptions/', payload);
export const updateSubscription = (id, payload) => api.put(`/subscriptions/${id}`, payload);
export const deleteSubscription = (id) => api.delete(`/subscriptions/${id}`);
export const pauseSubscription = (id, reason) =>
  api.post(`/subscriptions/${id}/pause`, { reason });
export const resumeSubscription = (id) => api.post(`/subscriptions/${id}/resume`);
export const cancelSubscription = (id, reason) =>
  api.post(`/subscriptions/${id}/cancel`, { reason });
export const renewSubscription = (id, params = {}) =>
  api.post(`/subscriptions/${id}/renew`, null, { params });
export const getSubscriptionDeliveries = (id) =>
  api.get(`/subscriptions/${id}/deliveries`);
export const getSubscriptionPlans = () => api.get('/subscriptions/plans');
export const skipDelivery = (deliveryId) => api.post(`/subscriptions/deliveries/${deliveryId}/skip`);
export const getSubscriptionDashboard = () => api.get('/subscriptions/dashboard/stats');
