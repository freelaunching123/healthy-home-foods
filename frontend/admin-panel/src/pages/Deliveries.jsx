import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getPendingDeliveries, assignDelivery, updateDeliveryStatus } from '../api/deliveriesApi';
import { getUsers } from '../api/usersApi';
import toast from 'react-hot-toast';

const STATUS_STYLES = {
  pending:     { bg: '#fef3c7', color: '#d97706' },
  assigned:    { bg: '#dbeafe', color: '#2563eb' },
  delivered:   { bg: '#dcfce7', color: '#16a34a' },
  missed:      { bg: '#fee2e2', color: '#dc2626' },
  carry_forward:{ bg: '#f3e8ff', color: '#7c3aed' },
};

const DELIVERY_STATUSES = ['pending', 'delivered', 'missed', 'carry_forward'];

export default function Deliveries() {
  const qc = useQueryClient();
  const [statusFilter, setStatusFilter] = useState('pending');

  const { data: deliveries = [], isLoading } = useQuery({
    queryKey: ['deliveries'],
    queryFn: async () => {
      const { data } = await getPendingDeliveries();
      return data?.items || data || [];
    },
    refetchInterval: 30000,
  });

  const { data: deliveryPartners = [] } = useQuery({
    queryKey: ['delivery-partners-list'],
    queryFn: async () => {
      try {
        const { data } = await getUsers({ role: 'delivery_partner' });
        return data?.items || data || [];
      } catch { return []; }
    },
  });

  const assignMut = useMutation({
    mutationFn: (data) => assignDelivery(data),
    onSuccess: () => { qc.invalidateQueries(['deliveries']); toast.success('Delivery assigned!'); },
    onError: (e) => toast.error(e.response?.data?.detail || 'Assignment failed'),
  });

  const statusMut = useMutation({
    mutationFn: ({ id, status }) => updateDeliveryStatus(id, { status }),
    onSuccess: () => { qc.invalidateQueries(['deliveries']); toast.success('Status updated!'); },
    onError: (e) => toast.error(e.response?.data?.detail || 'Update failed'),
  });

  const filtered = deliveries.filter(d =>
    statusFilter === 'all' || d.status === statusFilter
  );

  const tabs = ['all', 'pending', 'assigned', 'delivered', 'missed'];

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <div>
          <h1 className="page-title">Deliveries</h1>
          <p className="text-gray">{deliveries.length} total · {deliveries.filter(d => d.status === 'pending').length} pending</p>
        </div>
        <button className="btn btn-outline" onClick={() => qc.invalidateQueries(['deliveries'])}>
          ↻ Refresh
        </button>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
        {tabs.map(t => (
          <button key={t} onClick={() => setStatusFilter(t)}
            style={{
              padding: '6px 16px', borderRadius: '999px', border: '1px solid',
              fontWeight: 500, fontSize: '13px', cursor: 'pointer',
              borderColor: statusFilter === t ? '#10b981' : '#e2e8f0',
              background: statusFilter === t ? '#10b981' : '#fff',
              color: statusFilter === t ? '#fff' : '#475569',
            }}>
            {t === 'all' ? 'All' : t.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}
            <span style={{ marginLeft: 6, opacity: 0.8 }}>
              ({t === 'all' ? deliveries.length : deliveries.filter(d => d.status === t).length})
            </span>
          </button>
        ))}
      </div>

      {/* List */}
      {isLoading ? (
        <div style={{ padding: '48px', textAlign: 'center', color: '#94a3b8' }}>Loading deliveries...</div>
      ) : filtered.length === 0 ? (
        <div style={{ padding: '64px', textAlign: 'center', color: '#94a3b8' }}>
          <p style={{ fontSize: '48px', marginBottom: '8px' }}>🚚</p>
          <p>No {statusFilter} deliveries</p>
        </div>
      ) : (
        <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
          {filtered.map(d => {
            const st = STATUS_STYLES[d.status] || STATUS_STYLES.pending;
            return (
              <div key={d.id} className="card" style={{ padding: '20px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '12px' }}>
                  <div>
                    <div style={{ display: 'flex', alignItems: 'center', gap: '10px', marginBottom: '6px' }}>
                      <h3 style={{ fontSize: '15px', fontWeight: 600 }}>{d.customer_name || 'Customer'}</h3>
                      <span style={{ background: st.bg, color: st.color,
                        padding: '2px 10px', borderRadius: '999px', fontSize: '12px', fontWeight: 600 }}>
                        {d.status?.replace('_', ' ')}
                      </span>
                    </div>
                    <p style={{ fontSize: '13px', color: '#64748b' }}>📦 {d.product_name || 'Product'}</p>
                    <p style={{ fontSize: '13px', color: '#64748b' }}>📍 {d.delivery_address || 'Address not available'}</p>
                    {d.scheduled_date && (
                      <p style={{ fontSize: '13px', color: '#64748b' }}>
                        📅 {new Date(d.scheduled_date).toLocaleDateString('en-IN')}
                      </p>
                    )}
                  </div>
                  <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
                    {/* Assign dropdown */}
                    {d.status === 'pending' && deliveryPartners.length > 0 && (
                      <select className="form-control" style={{ fontSize: '13px', padding: '6px 10px' }}
                        defaultValue=""
                        onChange={e => {
                          if (e.target.value) {
                            assignMut.mutate({ delivery_id: d.id, delivery_partner_id: e.target.value });
                            e.target.value = '';
                          }
                        }}>
                        <option value="">Assign to...</option>
                        {deliveryPartners.map(dp => (
                          <option key={dp.id} value={dp.id}>{dp.full_name}</option>
                        ))}
                      </select>
                    )}
                    {/* Status update */}
                    {['pending', 'assigned'].includes(d.status) && (
                      <select className="form-control" style={{ fontSize: '13px', padding: '6px 10px' }}
                        defaultValue=""
                        onChange={e => {
                          if (e.target.value) {
                            statusMut.mutate({ id: d.id, status: e.target.value });
                            e.target.value = '';
                          }
                        }}>
                        <option value="">Update status...</option>
                        {DELIVERY_STATUSES.filter(s => s !== d.status).map(s => (
                          <option key={s} value={s}>{s.replace('_', ' ')}</option>
                        ))}
                      </select>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </div>
  );
}
