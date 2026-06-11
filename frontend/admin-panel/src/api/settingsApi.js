import api from './axios';

export const getSettings = () => api.get('/admin/settings/');
export const updateSettings = (data) => api.put('/admin/settings/', data);
