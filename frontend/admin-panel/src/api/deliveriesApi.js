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
