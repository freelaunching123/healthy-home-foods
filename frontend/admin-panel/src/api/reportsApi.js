import api from './axios';

export const getDashboardStats = () => api.get('/reports/dashboard');
export const getDeliveryBoyPerformance = () => api.get('/reports/delivery-boys');
export const exportExcel = () =>
  api.get('/reports/export/excel', { responseType: 'blob' });
export const exportPdf = () =>
  api.get('/reports/export/pdf', { responseType: 'blob' });

export const downloadBlob = (blob, filename) => {
  const url = window.URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  a.click();
  window.URL.revokeObjectURL(url);
};
