import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import toast from 'react-hot-toast';
import { loginWithPassword } from '../api/authApi';
import './Login.css';

const Login = () => {
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [showPw, setShowPw] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const navigate = useNavigate();

  const handleLogin = async (e) => {
    e.preventDefault();
    if (!/^[6-9]\d{9}$/.test(phone.trim())) {
      toast.error('Enter a valid 10-digit Indian mobile number');
      return;
    }
    setIsLoading(true);
    try {
      const { data } = await loginWithPassword(phone.trim(), password);
      localStorage.setItem('access_token', data.access_token);
      localStorage.setItem('refresh_token', data.refresh_token);
      localStorage.setItem('user_id', data.user_id);
      localStorage.setItem('role', data.role);
      toast.success('Welcome back, Admin! 🎉');
      navigate('/');
    } catch (err) {
      toast.error(err.response?.data?.detail || 'Login failed. Check your credentials.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="login-container">
      <div className="login-box glass-panel">
        <div className="login-header">
          <div className="login-logo">🥗</div>
          <h2>Admin Portal</h2>
          <p>Healthy Home Foods Management</p>
        </div>

        <form onSubmit={handleLogin} className="login-form">
          <div className="form-group">
            <label className="form-label">Mobile Number</label>
            <div style={{ position: 'relative' }}>
              <span style={{
                position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)',
                color: '#64748b', fontSize: '14px', fontWeight: 600
              }}>+91</span>
              <input
                type="tel"
                className="form-control"
                placeholder="9876543210"
                value={phone}
                onChange={(e) => setPhone(e.target.value.replace(/\D/g, '').slice(0, 10))}
                style={{ paddingLeft: '44px' }}
                required
              />
            </div>
          </div>

          <div className="form-group">
            <label className="form-label">Password</label>
            <div style={{ position: 'relative' }}>
              <input
                type={showPw ? 'text' : 'password'}
                className="form-control"
                placeholder="••••••••"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                required
              />
              <button
                type="button"
                onClick={() => setShowPw(!showPw)}
                style={{
                  position: 'absolute', right: '12px', top: '50%', transform: 'translateY(-50%)',
                  background: 'none', border: 'none', cursor: 'pointer', color: '#64748b', fontSize: '14px'
                }}
              >
                {showPw ? '🙈' : '👁️'}
              </button>
            </div>
          </div>

          <button
            type="submit"
            className="btn btn-primary w-100 mt-4"
            disabled={isLoading}
          >
            {isLoading ? (
              <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }}>
                <span className="spinner" />
                Signing In...
              </span>
            ) : 'Sign In to Dashboard'}
          </button>
        </form>

        <p style={{ textAlign: 'center', marginTop: '16px', fontSize: '13px', color: '#94a3b8' }}>
          Admin access only — unauthorized access is prohibited
        </p>
      </div>
    </div>
  );
};

export default Login;
