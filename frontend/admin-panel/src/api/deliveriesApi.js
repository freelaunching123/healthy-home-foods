import api from './axios';

export const getPendingDeliveries = () => api.get('/deliveries/pending');
export const getMyAssignments = () => api.get('/deliveries/assigned');
export const assignDelivery = (data) => api.post('/deliveries/assign', data);
export const updateDeliveryStatus = (assignmentId, data) =>
  api.put(`/deliveries/${assignmentId}/status`, data);
export const uploadDeliveryProof = (assignmentId, formData) =>
  api.post(`/deliveries/${assignmentId}/proof`, formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
export const updateGpsLocation = (data) => api.post('/deliveries/gps/update', data);
export const getGpsLocation = (assignmentId) =>
  api.get(`/deliveries/gps/track/${assignmentId}`);
export const getDeliveryPartners = () => api.get('/delivery-partners');

// Admin Dashboard Deliveries APIs
export const getAdminDeliveries = (params) => api.get('/admin/deliveries', { params });
export const getAdminDeliveryById = (id) => api.get(`/admin/deliveries/${id}`);
export const assignAdminDelivery = (id, partnerId) => api.post(`/admin/deliveries/${id}/assign`, { delivery_partner_id: partnerId });
export const updateAdminDeliveryStatus = (id, payload) => api.put(`/admin/deliveries/${id}/status`, payload);
export const getAdminDeliveriesAnalytics = (params) => api.get('/admin/deliveries/analytics', { params });
export const exportAdminDeliveries = (params) => api.get('/admin/deliveries/export', { params, responseType: 'blob' });
