import api from './axios';

export const loginWithPassword = (phone, password) =>
  api.post('/auth/login-password', { phone, password });

export const loginWithOtp = (phone, otp) =>
  api.post('/auth/verify-otp', { phone, otp, purpose: 'login' });

export const sendOtp = (phone) =>
  api.post('/auth/send-otp', { phone, purpose: 'login' });

export const logout = () =>
  api.post('/auth/logout').catch(() => {}); // fire-and-forget

export const refreshToken = (refresh_token) =>
  api.post('/auth/refresh-token', { refresh_token });
