import React, { useState, useEffect } from 'react';
import { useQuery, useMutation } from '@tanstack/react-query';
import { getSettings, updateSettings } from '../api/settingsApi';
import toast from 'react-hot-toast';

export default function Settings() {
  const [form, setForm] = useState(null);

  const { data, isLoading } = useQuery({
    queryKey: ['adminSettings'],
    queryFn: async () => { const { data } = await getSettings(); return data; },
  });

  useEffect(() => { if (data) setForm(data); }, [data]);

  const saveMut = useMutation({
    mutationFn: (payload) => updateSettings(payload),
    onSuccess: () => toast.success('Settings saved successfully!'),
    onError: (e) => toast.error(e.response?.data?.detail || 'Save failed'),
  });

  const field = (key, label, type = 'text', hint = '') => (
    <div className="form-group">
      <label className="form-label">{label}</label>
      {type === 'toggle' ? (
        <label style={{ display: 'flex', alignItems: 'center', gap: '10px', cursor: 'pointer' }}>
          <div style={{ position: 'relative', width: 44, height: 24 }}>
            <input type="checkbox" checked={form?.[key] || false}
              onChange={e => setForm(f => ({ ...f, [key]: e.target.checked }))}
              style={{ opacity: 0, width: 0, height: 0 }} />
            <div onClick={() => setForm(f => ({ ...f, [key]: !f?.[key] }))} style={{
              position: 'absolute', inset: 0, borderRadius: '999px', cursor: 'pointer',
              background: form?.[key] ? '#10b981' : '#cbd5e1', transition: 'background 0.2s'
            }}>
              <div style={{
                position: 'absolute', top: 2, left: form?.[key] ? 22 : 2,
                width: 20, height: 20, borderRadius: '50%', background: '#fff',
                transition: 'left 0.2s', boxShadow: '0 1px 3px rgba(0,0,0,0.2)'
              }} />
            </div>
          </div>
          <span style={{ fontSize: '14px', color: form?.[key] ? '#16a34a' : '#64748b' }}>
            {form?.[key] ? 'Enabled' : 'Disabled'}
          </span>
        </label>
      ) : (
        <input className="form-control" type={type} value={form?.[key] || ''}
          onChange={e => setForm(f => ({ ...f, [key]: type === 'number' ? parseFloat(e.target.value) : e.target.value }))} />
      )}
      {hint && <p style={{ fontSize: '12px', color: '#94a3b8', marginTop: '4px' }}>{hint}</p>}
    </div>
  );

  if (isLoading || !form) return (
    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '60vh' }}>
      <div style={{ textAlign: 'center', color: '#94a3b8' }}>Loading settings...</div>
    </div>
  );

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <div>
          <h1 className="page-title">Admin Settings</h1>
          <p className="text-gray">Configure platform-wide settings</p>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button className="btn btn-outline" onClick={() => setForm(data)}>Reset</button>
          <button className="btn btn-primary" onClick={() => saveMut.mutate(form)}
            disabled={saveMut.isPending}>
            {saveMut.isPending ? 'Saving...' : '💾 Save Settings'}
          </button>
        </div>
      </div>

      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px' }}>
        {/* Delivery Config */}
        <div className="card" style={{ padding: '24px' }}>
          <h3 style={{ fontSize: '16px', fontWeight: 700, marginBottom: '20px', color: '#1e293b' }}>
            🚚 Delivery Configuration
          </h3>
          {field('free_delivery_radius_km', 'Free Delivery Radius (km)', 'number', 'Deliveries within this radius are free')}
          {field('delivery_charge_per_km', 'Charge per km (₹)', 'number', 'Charged beyond free radius')}
          {field('business_address', 'Business Address (Origin)', 'text', 'Used for distance calculation')}
          {field('working_hours', 'Working Hours', 'text', 'e.g. 7:00 AM – 7:00 PM')}
          {field('sunday_holiday', 'Sunday Holiday', 'toggle')}
        </div>

        {/* Subscription Config */}
        <div className="card" style={{ padding: '24px' }}>
          <h3 style={{ fontSize: '16px', fontWeight: 700, marginBottom: '20px', color: '#1e293b' }}>
            📦 Subscription Configuration
          </h3>
          {field('weekly_delivery_count', 'Weekly Delivery Count', 'number', 'Deliveries per week plan')}
          {field('monthly_delivery_count', 'Monthly Delivery Count', 'number', 'Deliveries per month plan')}
          {field('tax_percentage', 'Tax Percentage (%)', 'number', 'Applied on total order value')}
          {field('service_available', 'Service Available', 'toggle')}
        </div>

        {/* OTP Config */}
        <div className="card" style={{ padding: '24px' }}>
          <h3 style={{ fontSize: '16px', fontWeight: 700, marginBottom: '20px', color: '#1e293b' }}>
            🔐 OTP & Security
          </h3>
          {field('otp_expiry_minutes', 'OTP Expiry (minutes)', 'number')}
          {field('max_otp_attempts', 'Max OTP Attempts', 'number')}
          {field('jwt_expiry_minutes', 'JWT Expiry (minutes)', 'number')}
        </div>

        {/* Platform Config */}
        <div className="card" style={{ padding: '24px' }}>
          <h3 style={{ fontSize: '16px', fontWeight: 700, marginBottom: '20px', color: '#1e293b' }}>
            ⚙️ Platform Settings
          </h3>
          {field('app_name', 'App Name')}
          {field('support_phone', 'Support Phone')}
          {field('support_email', 'Support Email')}
          {field('razorpay_enabled', 'Razorpay Payments', 'toggle')}
        </div>
      </div>
    </div>
  );
}
