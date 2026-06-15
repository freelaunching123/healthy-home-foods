import api from './axios';

export const getSubscriptions = (params = {}) => api.get('/subscriptions/', { params });
export const getSubscription = (id) => api.get(`/subscriptions/${id}`);
export const pauseSubscription = (id, reason) =>
  api.post(`/subscriptions/${id}/pause`, { reason });
export const resumeSubscription = (id) => api.post(`/subscriptions/${id}/resume`);
export const cancelSubscription = (id, reason) =>
  api.post(`/subscriptions/${id}/cancel`, { reason });
export const getSubscriptionDeliveries = (id) =>
  api.get(`/subscriptions/${id}/deliveries`);
export const getSubscriptionPlans = () => api.get('/subscriptions/plans');
export const skipDelivery = (deliveryId) => api.post(`/subscriptions/deliveries/${deliveryId}/skip`);
