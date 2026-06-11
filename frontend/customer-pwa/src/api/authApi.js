import api from './axios';

export const sendOtp    = (phone) => api.post('/auth/send-otp', { phone, purpose: 'login' });
export const verifyOtp  = (phone, otp) => api.post('/auth/verify-otp', { phone, otp, purpose: 'login' });
export const register   = (full_name, mobile_number, password) =>
  api.post('/auth/register', { full_name, mobile_number, password });
export const loginPassword = (phone, password) =>
  api.post('/auth/login-password', { phone, password });
export const doLogout   = () => api.post('/auth/logout').catch(() => {});
