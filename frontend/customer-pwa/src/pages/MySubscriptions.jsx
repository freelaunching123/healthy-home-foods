import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { getSubscriptions, pauseSubscription, resumeSubscription } from '../api/customerApi';
import toast from 'react-hot-toast';

const STATUS_CONFIG = {
  active:          { label: 'Active',    cls: 'badge-success', emoji: '✅' },
  paused:          { label: 'Paused',    cls: 'badge-warning', emoji: '⏸️' },
  pending_payment: { label: 'Pending',   cls: 'badge-info',    emoji: '🔄' },
  completed:       { label: 'Done',      cls: 'badge-neutral', emoji: '🏁' },
  cancelled:       { label: 'Cancelled', cls: 'badge-error',   emoji: '❌' },
};

const TABS = ['active', 'paused', 'pending_payment', 'completed', 'cancelled'];

export default function MySubscriptions() {
  const navigate = useNavigate();
  const qc = useQueryClient();
  const [tab, setTab] = useState('active');

  const { data: subs = [], isLoading } = useQuery({
    queryKey: ['my-subscriptions'],
    queryFn: async () => {
      const { data } = await getSubscriptions();
      return data?.items || data || [];
    },
  });

  const pauseMut = useMutation({
    mutationFn: (id) => pauseSubscription(id),
    onSuccess: () => { qc.invalidateQueries(['my-subscriptions']); toast.success('Subscription paused'); },
    onError: (e) => toast.error(e.response?.data?.detail || 'Could not pause'),
  });

  const resumeMut = useMutation({
    mutationFn: (id) => resumeSubscription(id),
    onSuccess: () => { qc.invalidateQueries(['my-subscriptions']); toast.success('Subscription resumed!'); },
    onError: (e) => toast.error(e.response?.data?.detail || 'Could not resume'),
  });

  const filtered = subs.filter(s => s.status === tab);

  return (
    <div>
      <div style={{ padding: '16px', background: '#fff', borderBottom: '1px solid #e0e0e0' }}>
        <h2 style={{ fontSize: '18px', fontFamily: 'Poppins,sans-serif', fontWeight: 700, marginBottom: '12px' }}>My Subscriptions</h2>
        {/* Tab strip */}
        <div style={{ display: 'flex', gap: '6px', overflowX: 'auto', scrollbarWidth: 'none', paddingBottom: '2px' }}>
          {TABS.map(t => {
            const count = subs.filter(s => s.status === t).length;
            return (
              <button key={t} onClick={() => setTab(t)} style={{
                flexShrink: 0, padding: '6px 14px', borderRadius: '999px',
                border: '1.5px solid', fontWeight: 500, fontSize: '12px', cursor: 'pointer',
                borderColor: tab === t ? '#2E7D32' : '#e0e0e0',
                background: tab === t ? '#2E7D32' : '#fff',
                color: tab === t ? '#fff' : '#757575',
                fontFamily: 'Inter,sans-serif',
              }}>
                {STATUS_CONFIG[t]?.emoji} {STATUS_CONFIG[t]?.label} {count > 0 && `(${count})`}
              </button>
            );
          })}
        </div>
      </div>

      <div style={{ padding: '16px' }}>
        {isLoading ? (
          <div className="loading-dots"><span /><span /><span /></div>
        ) : filtered.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon">📭</div>
            <h3>No {STATUS_CONFIG[tab]?.label.toLowerCase()} subscriptions</h3>
            {tab === 'active' && (
              <button className="btn-primary" style={{ marginTop: '16px' }} onClick={() => navigate('/')}>
                Browse Products
              </button>
            )}
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {filtered.map(sub => {
              const cfg = STATUS_CONFIG[sub.status] || STATUS_CONFIG.active;
              const progress = sub.total_deliveries > 0 ? (sub.completed_deliveries / sub.total_deliveries) * 100 : 0;
              return (
                <div key={sub.id} className="card" onClick={() => navigate(`/subscriptions/${sub.id}`)} style={{ cursor: 'pointer' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '10px' }}>
                    <div>
                      <h3 style={{ fontSize: '15px', fontWeight: 700, marginBottom: '2px' }}>{sub.product_name || 'Product'}</h3>
                      <p style={{ fontSize: '12px', color: '#757575', textTransform: 'capitalize' }}>
                        {sub.plan_type} · ₹{parseFloat(sub.total_amount || 0).toFixed(0)}
                      </p>
                    </div>
                    <span className={`badge ${cfg.cls}`}>{cfg.emoji} {cfg.label}</span>
                  </div>

                  {/* Progress bar */}
                  <div style={{ background: '#e0e0e0', borderRadius: '999px', height: '6px', marginBottom: '8px' }}>
                    <div style={{ width: `${progress}%`, background: '#2E7D32', borderRadius: '999px', height: '100%', transition: 'width 0.5s' }} />
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '12px', color: '#757575', marginBottom: '12px' }}>
                    <span>✅ {sub.completed_deliveries || 0} delivered</span>
                    <span>📦 {(sub.total_deliveries || 0) - (sub.completed_deliveries || 0)} remaining</span>
                    {sub.missed_deliveries > 0 && <span style={{ color: '#D32F2F' }}>❌ {sub.missed_deliveries} missed</span>}
                  </div>

                  {/* Actions */}
                  <div style={{ display: 'flex', gap: '8px' }}>
                    {sub.status === 'active' && (
                      <button className="btn-outline" style={{ flex: 1, fontSize: '13px', padding: '8px' }}
                        onClick={e => { e.stopPropagation(); if (window.confirm('Pause this subscription?')) pauseMut.mutate(sub.id); }}>
                        ⏸ Pause
                      </button>
                    )}
                    {sub.status === 'paused' && (
                      <button className="btn-primary" style={{ flex: 1, fontSize: '13px', padding: '8px' }}
                        onClick={e => { e.stopPropagation(); resumeMut.mutate(sub.id); }}>
                        ▶ Resume
                      </button>
                    )}
                    {sub.status === 'completed' && (
                      <button className="btn-primary" style={{ flex: 1, fontSize: '13px', padding: '8px' }}
                        onClick={e => { e.stopPropagation(); navigate('/'); }}>
                        🔄 Re-subscribe
                      </button>
                    )}
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}
