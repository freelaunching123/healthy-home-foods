import React, { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { getMe, updateMe, doLogout } from '../api/customerApi';
import { LogOut, User, Phone, MapPin, Receipt, Shield } from 'lucide-react';
import toast from 'react-hot-toast';

export default function Profile() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [isEditing, setIsEditing] = useState(false);
  const [form, setForm] = useState({ full_name: '', email: '' });

  const { data: user, isLoading } = useQuery({
    queryKey: ['me'],
    queryFn: async () => {
      const { data } = await getMe();
      // Only keep full_name and email in localStorage for fast access
      if (data.full_name) localStorage.setItem('full_name', data.full_name);
      return data;
    },
  });

  useEffect(() => {
    if (user) setForm({ full_name: user.full_name || '', email: user.email || '' });
  }, [user]);

  const updateMut = useMutation({
    mutationFn: (data) => updateMe(data),
    onSuccess: () => {
      qc.invalidateQueries(['me']);
      setIsEditing(false);
      toast.success('Profile updated');
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Update failed'),
  });

  const handleLogout = async () => {
    await doLogout();
    localStorage.clear();
    toast.success('Logged out');
    navigate('/login');
  };

  if (isLoading) return <div className="loading-dots" style={{ padding: '64px 0' }}><span /><span /><span /></div>;
  if (!user) return <div className="empty-state"><h3>Failed to load profile</h3></div>;

  return (
    <div style={{ background: '#f5f5f5', minHeight: '100vh', paddingBottom: '80px' }}>
      <div style={{ background: 'linear-gradient(135deg, #2E7D32, #43A047)', padding: '32px 16px', color: '#fff', textAlign: 'center', borderBottomLeftRadius: '24px', borderBottomRightRadius: '24px' }}>
        <div style={{ width: 80, height: 80, background: '#fff', color: '#2E7D32', borderRadius: '50%', margin: '0 auto 16px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '32px', fontWeight: 700, boxShadow: '0 8px 16px rgba(0,0,0,0.1)' }}>
          {user.full_name ? user.full_name[0].toUpperCase() : 'U'}
        </div>
        <h2 style={{ fontSize: '20px', fontFamily: 'Poppins,sans-serif', fontWeight: 600 }}>{user.full_name}</h2>
        <p style={{ fontSize: '14px', opacity: 0.9 }}>+91 {user.phone}</p>
      </div>

      <div style={{ padding: '16px', marginTop: '-24px' }}>
        <div className="card" style={{ marginBottom: '16px' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
            <p className="section-title" style={{ margin: 0 }}>Personal Details</p>
            {!isEditing && <button className="btn-outline" style={{ padding: '6px 12px', fontSize: '12px' }} onClick={() => setIsEditing(true)}>Edit</button>}
          </div>

          {isEditing ? (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
              <div className="form-group" style={{ margin: 0 }}>
                <label className="form-label">Full Name</label>
                <input className="form-input" value={form.full_name} onChange={e => setForm(f => ({ ...f, full_name: e.target.value }))} />
              </div>
              <div className="form-group" style={{ margin: 0 }}>
                <label className="form-label">Email</label>
                <input className="form-input" type="email" value={form.email} onChange={e => setForm(f => ({ ...f, email: e.target.value }))} />
              </div>
              <div style={{ display: 'flex', gap: '8px', marginTop: '8px' }}>
                <button className="btn-outline" style={{ flex: 1 }} onClick={() => { setIsEditing(false); setForm({ full_name: user.full_name || '', email: user.email || '' }); }}>Cancel</button>
                <button className="btn-primary" style={{ flex: 1 }} onClick={() => updateMut.mutate(form)} disabled={updateMut.isPending}>Save</button>
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '16px' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <div style={{ width: 36, height: 36, background: '#E8F5E9', color: '#2E7D32', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><User size={18} /></div>
                <div><p style={{ fontSize: '11px', color: '#757575', marginBottom: 2 }}>Full Name</p><p style={{ fontSize: '14px', fontWeight: 500 }}>{user.full_name || 'Not set'}</p></div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <div style={{ width: 36, height: 36, background: '#E8F5E9', color: '#2E7D32', borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><Phone size={18} /></div>
                <div><p style={{ fontSize: '11px', color: '#757575', marginBottom: 2 }}>Phone</p><p style={{ fontSize: '14px', fontWeight: 500 }}>+91 {user.phone}</p></div>
              </div>
            </div>
          )}
        </div>

        <div className="card" style={{ padding: '8px 16px' }}>
          {[
            { icon: MapPin, label: 'Manage Addresses', onClick: () => toast('Address management coming soon') },
            { icon: Receipt, label: 'Payment History', onClick: () => navigate('/payments') },
            { icon: Shield, label: 'Privacy Policy', onClick: () => toast('Privacy Policy') },
          ].map((item, i) => (
            <div key={item.label} onClick={item.onClick} style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '16px 0', borderBottom: i < 2 ? '1px solid #f5f5f5' : 'none', cursor: 'pointer' }}>
              <div style={{ width: 36, height: 36, background: '#f5f5f5', color: '#616161', borderRadius: '8px', display: 'flex', alignItems: 'center', justifyContent: 'center' }}><item.icon size={18} /></div>
              <span style={{ flex: 1, fontSize: '15px', fontWeight: 500 }}>{item.label}</span>
              <span style={{ color: '#9e9e9e' }}>›</span>
            </div>
          ))}
        </div>

        <button className="btn-danger" style={{ width: '100%', marginTop: '24px', display: 'flex', alignItems: 'center', justifyContent: 'center', gap: '8px' }} onClick={handleLogout}>
          <LogOut size={16} /> Logout
        </button>
      </div>
    </div>
  );
}
