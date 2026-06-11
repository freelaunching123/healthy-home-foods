import React, { useState, useEffect, useRef } from 'react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import { sendOtp, verifyOtp, loginPassword, register } from '../api/authApi';
import '../index.css';

const RESEND_SECS = 60;

export default function Login() {
  const navigate = useNavigate();
  const [tab, setTab] = useState('otp'); // 'otp' | 'password' | 'register'
  const [loading, setLoading] = useState(false);

  // OTP state
  const [phone, setPhone] = useState('');
  const [otpSent, setOtpSent] = useState(false);
  const [otp, setOtp] = useState('');
  const [countdown, setCountdown] = useState(0);
  const timerRef = useRef(null);

  // Password state
  const [pwPhone, setPwPhone] = useState('');
  const [pwPass, setPwPass] = useState('');

  // Register state
  const [regName, setRegName] = useState('');
  const [regPhone, setRegPhone] = useState('');
  const [regPass, setRegPass] = useState('');

  useEffect(() => {
    if (localStorage.getItem('access_token')) navigate('/');
  }, []);

  const startTimer = () => {
    setCountdown(RESEND_SECS);
    timerRef.current = setInterval(() => {
      setCountdown(c => { if (c <= 1) { clearInterval(timerRef.current); return 0; } return c - 1; });
    }, 1000);
  };

  const saveSession = (data) => {
    localStorage.setItem('access_token', data.access_token);
    localStorage.setItem('refresh_token', data.refresh_token);
    localStorage.setItem('user_id', data.user_id);
    localStorage.setItem('role', data.role);
  };

  const handleSendOtp = async (e) => {
    e.preventDefault();
    if (!/^[6-9]\d{9}$/.test(phone)) { toast.error('Enter a valid 10-digit mobile number'); return; }
    setLoading(true);
    try {
      await sendOtp(phone);
      setOtpSent(true);
      startTimer();
      toast.success('OTP sent to +91 ' + phone);
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Failed to send OTP');
    } finally { setLoading(false); }
  };

  const handleVerifyOtp = async (e) => {
    e.preventDefault();
    if (otp.length < 4) { toast.error('Enter the OTP sent to your phone'); return; }
    setLoading(true);
    try {
      const { data } = await verifyOtp(phone, otp);
      saveSession(data);
      toast.success('Welcome! 🎉');
      navigate('/');
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Invalid or expired OTP');
    } finally { setLoading(false); }
  };

  const handlePasswordLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      const { data } = await loginPassword(pwPhone, pwPass);
      saveSession(data);
      toast.success('Welcome back! 🎉');
      navigate('/');
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Invalid credentials');
    } finally { setLoading(false); }
  };

  const handleRegister = async (e) => {
    e.preventDefault();
    if (regName.trim().length < 3) { toast.error('Name must be at least 3 characters'); return; }
    if (!/^[6-9]\d{9}$/.test(regPhone)) { toast.error('Enter valid 10-digit mobile'); return; }
    if (regPass.length < 8) { toast.error('Password must be at least 8 characters'); return; }
    setLoading(true);
    try {
      await register(regName.trim(), regPhone, regPass);
      toast.success('Registered! Please login with OTP.');
      setTab('otp');
      setPhone(regPhone);
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Registration failed');
    } finally { setLoading(false); }
  };

  const inputStyle = {
    width: '100%', padding: '13px 14px', border: '1.5px solid #e0e0e0',
    borderRadius: '10px', fontSize: '16px', fontFamily: 'Inter,sans-serif',
    outline: 'none', transition: 'border-color 0.2s',
  };

  return (
    <div style={{ minHeight: '100vh', background: 'linear-gradient(160deg, #E8F5E9 0%, #fff 60%)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: '24px' }}>
      <div style={{ width: '100%', maxWidth: 400 }}>
        {/* Logo */}
        <div style={{ textAlign: 'center', marginBottom: '32px' }}>
          <div style={{ fontSize: '56px', lineHeight: 1 }}>🥗</div>
          <h1 style={{ fontFamily: 'Poppins,sans-serif', fontSize: '24px', fontWeight: 700, color: '#2E7D32', marginTop: '8px' }}>
            Healthy Home Foods
          </h1>
          <p style={{ color: '#757575', fontSize: '14px', marginTop: '4px' }}>
            Fresh. Healthy. Delivered Daily.
          </p>
        </div>

        {/* Tab switcher */}
        <div style={{ display: 'flex', background: '#f5f5f5', borderRadius: '12px', padding: '4px', marginBottom: '24px' }}>
          {[{ id: 'otp', label: 'OTP Login' }, { id: 'password', label: 'Password' }, { id: 'register', label: 'Register' }].map(t => (
            <button key={t.id} onClick={() => setTab(t.id)} style={{
              flex: 1, padding: '10px', border: 'none', borderRadius: '10px', cursor: 'pointer',
              fontFamily: 'Inter,sans-serif', fontWeight: 600, fontSize: '13px',
              background: tab === t.id ? '#fff' : 'transparent',
              color: tab === t.id ? '#2E7D32' : '#757575',
              boxShadow: tab === t.id ? '0 2px 8px rgba(0,0,0,0.08)' : 'none',
              transition: 'all 0.2s',
            }}>{t.label}</button>
          ))}
        </div>

        <div style={{ background: '#fff', borderRadius: '16px', padding: '24px', boxShadow: '0 4px 24px rgba(0,0,0,0.08)' }}>
          {/* OTP Tab */}
          {tab === 'otp' && (
            !otpSent ? (
              <form onSubmit={handleSendOtp}>
                <div className="form-group">
                  <label className="form-label">Mobile Number</label>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <div style={{ padding: '13px 12px', background: '#f5f5f5', borderRadius: '10px', fontSize: '15px', fontWeight: 600, color: '#424242', flexShrink: 0 }}>+91</div>
                    <input style={inputStyle} type="tel" placeholder="9876543210" value={phone}
                      onChange={e => setPhone(e.target.value.replace(/\D/g, '').slice(0, 10))} required />
                  </div>
                </div>
                <button type="submit" className="btn-primary" disabled={loading || phone.length !== 10}>
                  {loading ? <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><span className="spinner" /> Sending OTP...</span> : 'Send OTP'}
                </button>
              </form>
            ) : (
              <form onSubmit={handleVerifyOtp}>
                <p style={{ fontSize: '14px', color: '#757575', marginBottom: '16px' }}>
                  OTP sent to <strong>+91 {phone}</strong>
                </p>
                <div className="form-group">
                  <label className="form-label">Enter OTP</label>
                  <input style={{ ...inputStyle, fontSize: '24px', letterSpacing: '12px', textAlign: 'center', fontWeight: 700 }}
                    type="tel" maxLength={6} placeholder="------"
                    value={otp} onChange={e => setOtp(e.target.value.replace(/\D/g, ''))}
                    autoFocus required />
                </div>
                <button type="submit" className="btn-primary" style={{ marginBottom: '12px' }} disabled={loading || otp.length < 4}>
                  {loading ? <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><span className="spinner" /> Verifying...</span> : 'Verify & Login'}
                </button>
                <div style={{ textAlign: 'center' }}>
                  {countdown > 0 ? (
                    <p style={{ fontSize: '13px', color: '#757575' }}>Resend in {countdown}s</p>
                  ) : (
                    <button type="button" onClick={handleSendOtp} style={{ background: 'none', border: 'none', color: '#2E7D32', fontWeight: 600, cursor: 'pointer', fontSize: '14px' }}>
                      Resend OTP
                    </button>
                  )}
                  <button type="button" onClick={() => { setOtpSent(false); setOtp(''); clearInterval(timerRef.current); }}
                    style={{ background: 'none', border: 'none', color: '#757575', fontSize: '13px', cursor: 'pointer', marginLeft: '16px' }}>
                    Change Number
                  </button>
                </div>
              </form>
            )
          )}

          {/* Password Tab */}
          {tab === 'password' && (
            <form onSubmit={handlePasswordLogin}>
              <div className="form-group">
                <label className="form-label">Mobile Number</label>
                <input style={inputStyle} type="tel" placeholder="10-digit mobile number"
                  value={pwPhone} onChange={e => setPwPhone(e.target.value.replace(/\D/g, '').slice(0, 10))} required />
              </div>
              <div className="form-group">
                <label className="form-label">Password</label>
                <input style={inputStyle} type="password" placeholder="Enter password"
                  value={pwPass} onChange={e => setPwPass(e.target.value)} required />
              </div>
              <button type="submit" className="btn-primary" disabled={loading}>
                {loading ? <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><span className="spinner" />Logging in...</span> : 'Login'}
              </button>
            </form>
          )}

          {/* Register Tab */}
          {tab === 'register' && (
            <form onSubmit={handleRegister}>
              <div className="form-group">
                <label className="form-label">Full Name</label>
                <input style={inputStyle} type="text" placeholder="Your full name"
                  value={regName} onChange={e => setRegName(e.target.value)} required />
              </div>
              <div className="form-group">
                <label className="form-label">Mobile Number</label>
                <input style={inputStyle} type="tel" placeholder="10-digit mobile"
                  value={regPhone} onChange={e => setRegPhone(e.target.value.replace(/\D/g, '').slice(0, 10))} required />
              </div>
              <div className="form-group">
                <label className="form-label">Password (min 8 chars)</label>
                <input style={inputStyle} type="password" placeholder="Create password"
                  value={regPass} onChange={e => setRegPass(e.target.value)} required />
              </div>
              <button type="submit" className="btn-primary" disabled={loading}>
                {loading ? <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><span className="spinner" />Registering...</span> : 'Create Account'}
              </button>
            </form>
          )}
        </div>
      </div>
    </div>
  );
}
