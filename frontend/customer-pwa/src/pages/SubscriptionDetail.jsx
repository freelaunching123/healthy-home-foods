import React from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getSubscription, getSubscriptionDeliveries, pauseSubscription, resumeSubscription } from '../api/customerApi';
import { ArrowLeft } from 'lucide-react';
import toast from 'react-hot-toast';

const DELIVERY_STATUS = {
  pending:       { color: '#FF6F00', bg: '#FFF3E0', label: 'Pending'   },
  delivered:     { color: '#2E7D32', bg: '#E8F5E9', label: 'Delivered' },
  missed:        { color: '#D32F2F', bg: '#FFEBEE', label: 'Missed'    },
  carry_forward: { color: '#7B1FA2', bg: '#F3E5F5', label: 'Carry Fwd' },
};

export default function SubscriptionDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const qc = useQueryClient();

  const { data: sub, isLoading } = useQuery({
    queryKey: ['subscription', id],
    queryFn: async () => { const { data } = await getSubscription(id); return data; },
    enabled: !!id,
  });

  const { data: deliveries = [] } = useQuery({
    queryKey: ['sub-deliveries', id],
    queryFn: async () => { const { data } = await getSubscriptionDeliveries(id); return data?.items || data || []; },
    enabled: !!id,
  });

  const pauseMut = useMutation({
    mutationFn: () => pauseSubscription(id),
    onSuccess: () => { qc.invalidateQueries(['subscription', id]); toast.success('Subscription paused'); },
  });

  const resumeMut = useMutation({
    mutationFn: () => resumeSubscription(id),
    onSuccess: () => { qc.invalidateQueries(['subscription', id]); toast.success('Subscription resumed!'); },
  });

  if (isLoading) return <div className="loading-dots" style={{ padding: '64px 0' }}><span /><span /><span /></div>;
  if (!sub) return <div className="empty-state"><div className="empty-state-icon">❌</div><h3>Not found</h3></div>;

  return (
    <div>
      <div style={{ padding: '16px', background: '#fff', borderBottom: '1px solid #e0e0e0', display: 'flex', alignItems: 'center', gap: 8 }}>
        <button onClick={() => navigate('/subscriptions')} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#2E7D32' }}><ArrowLeft size={20} /></button>
        <h2 style={{ fontSize: '16px', fontFamily: 'Poppins,sans-serif', fontWeight: 600 }}>Subscription Details</h2>
      </div>

      <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {/* Summary Card */}
        <div className="card" style={{ background: 'linear-gradient(135deg, #2E7D32, #43A047)', color: '#fff' }}>
          <h3 style={{ fontSize: '18px', fontFamily: 'Poppins,sans-serif', marginBottom: '8px' }}>{sub.product_name || 'Subscription'}</h3>
          <p style={{ opacity: 0.85, fontSize: '13px', textTransform: 'capitalize', marginBottom: '16px' }}>
            {sub.plan_type} Plan · ₹{parseFloat(sub.total_amount || 0).toFixed(0)}
          </p>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: '8px' }}>
            {[
              { label: 'Total', val: sub.total_deliveries || 0 },
              { label: 'Done', val: sub.completed_deliveries || 0 },
              { label: 'Pending', val: (sub.total_deliveries || 0) - (sub.completed_deliveries || 0) },
              { label: 'Missed', val: sub.missed_deliveries || 0 },
            ].map(s => (
              <div key={s.label} style={{ textAlign: 'center', background: 'rgba(255,255,255,0.15)', borderRadius: '8px', padding: '8px' }}>
                <p style={{ fontSize: '20px', fontWeight: 700 }}>{s.val}</p>
                <p style={{ fontSize: '11px', opacity: 0.8 }}>{s.label}</p>
              </div>
            ))}
          </div>
        </div>

        {/* Action buttons */}
        <div style={{ display: 'flex', gap: '10px' }}>
          {sub.status === 'active' && (
            <button className="btn-outline" style={{ flex: 1 }}
              onClick={() => { if (window.confirm('Pause subscription?')) pauseMut.mutate(); }}>
              ⏸ Pause Subscription
            </button>
          )}
          {sub.status === 'paused' && (
            <button className="btn-primary" style={{ flex: 1 }} onClick={() => resumeMut.mutate()}>
              ▶ Resume Subscription
            </button>
          )}
        </div>

        {/* Delivery Calendar List */}
        <div className="card">
          <p className="section-title" style={{ marginBottom: '12px' }}>📅 Delivery Schedule ({deliveries.length} days)</p>
          {deliveries.length === 0 ? (
            <p style={{ color: '#757575', fontSize: '14px', textAlign: 'center', padding: '16px' }}>No deliveries scheduled yet</p>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', maxHeight: '320px', overflowY: 'auto' }}>
              {deliveries.map((d, i) => {
                const cfg = DELIVERY_STATUS[d.status] || DELIVERY_STATUS.pending;
                return (
                  <div key={d.id || i} style={{
                    display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                    padding: '10px 12px', borderRadius: '8px', background: cfg.bg,
                  }}>
                    <div>
                      <p style={{ fontSize: '13px', fontWeight: 500 }}>
                        {d.scheduled_date ? new Date(d.scheduled_date).toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' }) : `Day ${i + 1}`}
                      </p>
                      {d.delivered_at && <p style={{ fontSize: '11px', color: '#757575' }}>Delivered: {new Date(d.delivered_at).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}</p>}
                    </div>
                    <span style={{ color: cfg.color, fontWeight: 700, fontSize: '12px', background: '#fff', padding: '3px 10px', borderRadius: '999px' }}>
                      {cfg.label}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
