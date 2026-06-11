import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getSubscriptions, pauseSubscription, resumeSubscription, cancelSubscription } from '../api/subscriptionsApi';
import toast from 'react-hot-toast';

const STATUS_STYLES = {
  active:          { bg: '#dcfce7', color: '#16a34a' },
  paused:          { bg: '#fef3c7', color: '#d97706' },
  pending_payment: { bg: '#dbeafe', color: '#2563eb' },
  completed:       { bg: '#f1f5f9', color: '#475569' },
  cancelled:       { bg: '#fee2e2', color: '#dc2626' },
};

const TABS = ['all', 'active', 'paused', 'pending_payment', 'completed', 'cancelled'];

export default function Subscriptions() {
  const qc = useQueryClient();
  const [tab, setTab] = useState('all');
  const [search, setSearch] = useState('');

  const { data: subs = [], isLoading } = useQuery({
    queryKey: ['subscriptions'],
    queryFn: async () => { const { data } = await getSubscriptions(); return data?.items || data || []; },
  });

  const pauseMut = useMutation({
    mutationFn: ({ id, reason }) => pauseSubscription(id, reason),
    onSuccess: () => { qc.invalidateQueries(['subscriptions']); toast.success('Subscription paused'); },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed to pause'),
  });

  const resumeMut = useMutation({
    mutationFn: (id) => resumeSubscription(id),
    onSuccess: () => { qc.invalidateQueries(['subscriptions']); toast.success('Subscription resumed'); },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed to resume'),
  });

  const cancelMut = useMutation({
    mutationFn: ({ id, reason }) => cancelSubscription(id, reason),
    onSuccess: () => { qc.invalidateQueries(['subscriptions']); toast.success('Subscription cancelled'); },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed to cancel'),
  });

  const filtered = subs.filter(s =>
    (tab === 'all' || s.status === tab) &&
    (s.product_name?.toLowerCase().includes(search.toLowerCase()) || true)
  );

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <div>
          <h1 className="page-title">Subscriptions</h1>
          <p className="text-gray">{subs.length} total subscriptions</p>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap', marginBottom: '0' }}>
        {TABS.map(t => (
          <button key={t} onClick={() => setTab(t)}
            style={{
              padding: '6px 16px', borderRadius: '999px', border: '1px solid',
              fontWeight: 500, fontSize: '13px', cursor: 'pointer',
              borderColor: tab === t ? '#10b981' : '#e2e8f0',
              background: tab === t ? '#10b981' : '#fff',
              color: tab === t ? '#fff' : '#475569',
            }}>
            {t.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}
            <span style={{ marginLeft: 6, opacity: 0.8 }}>
              ({t === 'all' ? subs.length : subs.filter(s => s.status === t).length})
            </span>
          </button>
        ))}
      </div>

      {/* Table */}
      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        {isLoading ? (
          <div style={{ padding: '48px', textAlign: 'center', color: '#94a3b8' }}>Loading subscriptions...</div>
        ) : filtered.length === 0 ? (
          <div style={{ padding: '64px', textAlign: 'center', color: '#94a3b8' }}>
            <p style={{ fontSize: '48px', marginBottom: '8px' }}>📭</p>
            <p>No subscriptions found</p>
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0' }}>
                {['Customer', 'Product', 'Plan', 'Deliveries', 'Amount', 'Status', 'Actions'].map(h => (
                  <th key={h} style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px',
                    fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filtered.map((s, i) => {
                const st = STATUS_STYLES[s.status] || STATUS_STYLES.pending_payment;
                return (
                  <tr key={s.id} style={{ borderBottom: '1px solid #f1f5f9',
                    background: i % 2 === 0 ? '#fff' : '#fafafa' }}>
                    <td style={{ padding: '12px 16px', fontSize: '14px' }}>
                      <div style={{ fontWeight: 500 }}>{s.customer_name || 'Customer'}</div>
                      <div style={{ fontSize: '12px', color: '#64748b' }}>{s.customer_phone || ''}</div>
                    </td>
                    <td style={{ padding: '12px 16px', fontSize: '14px' }}>{s.product_name || '—'}</td>
                    <td style={{ padding: '12px 16px', fontSize: '14px', textTransform: 'capitalize' }}>
                      {s.plan_type || '—'}
                    </td>
                    <td style={{ padding: '12px 16px', fontSize: '14px' }}>
                      {s.completed_deliveries}/{s.total_deliveries}
                      {s.missed_deliveries > 0 && <span style={{ color: '#dc2626', fontSize: '12px' }}> ({s.missed_deliveries} missed)</span>}
                    </td>
                    <td style={{ padding: '12px 16px', fontSize: '14px', fontWeight: 600 }}>
                      ₹{parseFloat(s.total_amount || 0).toLocaleString('en-IN')}
                    </td>
                    <td style={{ padding: '12px 16px' }}>
                      <span style={{ background: st.bg, color: st.color,
                        padding: '3px 10px', borderRadius: '999px', fontSize: '12px', fontWeight: 600 }}>
                        {s.status?.replace('_', ' ')}
                      </span>
                    </td>
                    <td style={{ padding: '12px 16px' }}>
                      <div style={{ display: 'flex', gap: '6px' }}>
                        {s.status === 'active' && (
                          <button className="btn btn-outline" style={{ fontSize: '12px', padding: '4px 10px' }}
                            onClick={() => { const r = prompt('Pause reason (optional):'); pauseMut.mutate({ id: s.id, reason: r }); }}>
                            Pause
                          </button>
                        )}
                        {s.status === 'paused' && (
                          <button className="btn btn-primary" style={{ fontSize: '12px', padding: '4px 10px' }}
                            onClick={() => resumeMut.mutate(s.id)}>
                            Resume
                          </button>
                        )}
                        {['active', 'paused', 'pending_payment'].includes(s.status) && (
                          <button style={{ fontSize: '12px', padding: '4px 10px', background: '#fff',
                            border: '1px solid #fee2e2', color: '#dc2626', borderRadius: '6px', cursor: 'pointer' }}
                            onClick={() => { if (window.confirm('Cancel this subscription?')) cancelMut.mutate({ id: s.id, reason: 'Admin cancelled' }); }}>
                            Cancel
                          </button>
                        )}
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
