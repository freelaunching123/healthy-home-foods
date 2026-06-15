import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getUsers, deactivateUser, getCustomerDetail } from '../api/usersApi';
import { assignDelivery } from '../api/deliveriesApi';
import { skipDelivery } from '../api/subscriptionsApi';
import { getDeliveryPartners } from '../api/deliveriesApi';
import toast from 'react-hot-toast';
import { UserX, Edit2, Phone, X, Calendar, MapPin, CreditCard, Clock, User, CheckCircle2, ChevronRight, AlertCircle, RefreshCw } from 'lucide-react';

const STATUS_STYLES = {
  active:    { bg: '#dcfce7', color: '#16a34a' },
  inactive:  { bg: '#fee2e2', color: '#dc2626' },
  suspended: { bg: '#fef3c7', color: '#d97706' },
};

const DELIVERY_STATUS_STYLES = {
  pending:          { bg: '#f1f5f9', color: '#64748b', label: 'Pending' },
  assigned:         { bg: '#e0f2fe', color: '#0369a1', label: 'Assigned' },
  out_for_delivery: { bg: '#fef3c7', color: '#d97706', label: 'Out for Delivery' },
  delivered:        { bg: '#dcfce7', color: '#16a34a', label: 'Delivered' },
  missed:           { bg: '#fee2e2', color: '#dc2626', label: 'Missed' },
  skipped:          { bg: '#f3e8ff', color: '#7e22ce', label: 'Skipped' },
  carry_forward:    { bg: '#fae8ff', color: '#a21caf', label: 'Carry Forward' },
};

export default function Customers() {
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('all'); // all, active, inactive
  const [subFilter, setSubFilter] = useState('all'); // all, active_sub, paused_sub, expired_sub
  const [page, setPage] = useState(1);
  const [selectedUserId, setSelectedUserId] = useState(null);
  const [activeTab, setActiveTab] = useState('overview');

  // List all users
  const { data, isLoading } = useQuery({
    queryKey: ['customers', page],
    queryFn: async () => {
      const { data } = await getUsers({ role: 'customer', skip: (page - 1) * 20, limit: 20 });
      return data;
    },
  });

  // Get active delivery boys for override dropdown
  const { data: partners = [] } = useQuery({
    queryKey: ['delivery-partners'],
    queryFn: async () => {
      const { data } = await getDeliveryPartners();
      return data;
    },
    enabled: !!selectedUserId,
  });

  // Get selected customer detailed profile
  const { data: detail, isLoading: isDetailLoading, refetch: refetchDetail } = useQuery({
    queryKey: ['customer-detail', selectedUserId],
    queryFn: async () => {
      const { data } = await getCustomerDetail(selectedUserId);
      return data;
    },
    enabled: !!selectedUserId,
  });

  // Re-assign delivery boy mutation
  const reassignMut = useMutation({
    mutationFn: (payload) => assignDelivery(payload),
    onSuccess: () => {
      refetchDetail();
      qc.invalidateQueries(['customers']);
      toast.success('Delivery partner reassigned successfully!');
    },
    onError: (err) => {
      toast.error(err.response?.data?.detail || 'Reassignment failed');
    }
  });

  // Skip delivery day mutation
  const skipMut = useMutation({
    mutationFn: (deliveryId) => skipDelivery(deliveryId),
    onSuccess: () => {
      refetchDetail();
      qc.invalidateQueries(['customers']);
      toast.success('Delivery skipped and schedule extended successfully!');
    },
    onError: (err) => {
      toast.error(err.response?.data?.detail || 'Failed to skip delivery');
    }
  });

  const deactivateMut = useMutation({
    mutationFn: (id) => deactivateUser(id),
    onSuccess: () => {
      qc.invalidateQueries(['customers']);
      if (selectedUserId) refetchDetail();
      toast.success('User status updated');
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed'),
  });

  // Client side filters based on search and filters selection
  const rawUsers = data?.items || data || [];
  
  const filteredUsers = rawUsers.filter(u => {
    // 1. Search term match
    const nameMatch = u.full_name?.toLowerCase().includes(search.toLowerCase());
    const phoneMatch = u.phone?.includes(search);
    if (search && !nameMatch && !phoneMatch) return false;

    // 2. User status filter
    if (statusFilter !== 'all' && u.status !== statusFilter) return false;

    return true;
  });

  const total = data?.total || filteredUsers.length;

  return (
    <div className="dashboard animate-fade-in">
      <div className="dashboard-header">
        <div>
          <h1 className="page-title">Customer Management</h1>
          <p className="text-gray">Monitor profiles, history, pauses, and reassign delivery partners in real time</p>
        </div>
      </div>

      {/* Filter and Search Bar */}
      <div className="card" style={{ padding: '16px', display: 'flex', gap: '16px', flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between' }}>
        <div style={{ display: 'flex', gap: '12px', flex: 1, minWidth: '280px' }}>
          <input className="form-control" placeholder="🔍  Search by name or phone..."
            value={search} onChange={e => setSearch(e.target.value)} style={{ maxWidth: 360 }} />
        </div>
        <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
          <span style={{ fontSize: '13px', color: '#64748b', fontWeight: 500 }}>Status:</span>
          <select className="form-control" value={statusFilter} onChange={e => setStatusFilter(e.target.value)} style={{ width: '130px', padding: '6px 12px' }}>
            <option value="all">All Statuses</option>
            <option value="active">Active</option>
            <option value="inactive">Inactive</option>
            <option value="suspended">Suspended</option>
          </select>
        </div>
      </div>

      {/* Customers List Table */}
      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        {isLoading ? (
          <div style={{ padding: '48px', textAlign: 'center', color: '#94a3b8' }}>
            <RefreshCw className="spinner" style={{ color: '#10b981', marginRight: '8px' }} />
            Loading customers...
          </div>
        ) : filteredUsers.length === 0 ? (
          <div style={{ padding: '64px', textAlign: 'center', color: '#94a3b8' }}>
            <p style={{ fontSize: '48px', marginBottom: '8px' }}>👥</p>
            <p>No customers found matching the criteria</p>
          </div>
        ) : (
          <table style={{ width: '100%', borderCollapse: 'collapse' }}>
            <thead>
              <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0' }}>
                {['#', 'Name', 'Phone', 'Email', 'Status', 'Joined', 'Actions'].map(h => (
                  <th key={h} style={{ padding: '12px 16px', textAlign: 'left', fontSize: '12px',
                    fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{h}</th>
                ))}
              </tr>
            </thead>
            <tbody>
              {filteredUsers.map((u, i) => {
                const st = STATUS_STYLES[u.status] || STATUS_STYLES.active;
                return (
                  <tr key={u.id} style={{ borderBottom: '1px solid #f1f5f9', background: i % 2 === 0 ? '#fff' : '#fafafa', cursor: 'pointer' }}
                    onClick={() => { setSelectedUserId(u.id); setActiveTab('overview'); }}>
                    <td style={{ padding: '12px 16px', fontSize: '13px', color: '#94a3b8' }}>
                      {(page - 1) * 20 + i + 1}
                    </td>
                    <td style={{ padding: '12px 16px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <div style={{
                          width: 36, height: 36, borderRadius: '50%', background: '#ecfdf5',
                          color: '#059669', display: 'flex', alignItems: 'center', justifyContent: 'center',
                          fontWeight: 700, fontSize: '14px', flexShrink: 0
                        }}>
                          {(u.full_name || 'U')[0].toUpperCase()}
                        </div>
                        <div>
                          <span style={{ fontWeight: 600, color: '#1e293b' }}>{u.full_name || '—'}</span>
                          <div style={{ fontSize: '11px', color: '#94a3b8' }}>View Details &rarr;</div>
                        </div>
                      </div>
                    </td>
                    <td style={{ padding: '12px 16px', fontSize: '14px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 4, color: '#475569' }}>
                        <Phone size={12} style={{ color: '#94a3b8' }} />
                        {u.phone || '—'}
                      </div>
                    </td>
                    <td style={{ padding: '12px 16px', fontSize: '14px', color: '#64748b' }}>{u.email || '—'}</td>
                    <td style={{ padding: '12px 16px' }}>
                      <span style={{ background: st.bg, color: st.color,
                        padding: '3px 10px', borderRadius: '999px', fontSize: '11px', fontWeight: 600 }}>
                        {u.status || 'active'}
                      </span>
                    </td>
                    <td style={{ padding: '12px 16px', fontSize: '13px', color: '#64748b' }}>
                      {u.created_at ? new Date(u.created_at).toLocaleDateString('en-IN') : '—'}
                    </td>
                    <td style={{ padding: '12px 16px' }} onClick={e => e.stopPropagation()}>
                      <div style={{ display: 'flex', gap: '8px' }}>
                        <button className="btn" style={{
                          background: '#fff', border: '1px solid #e2e8f0', color: '#475569',
                          padding: '4px 10px', borderRadius: '6px', cursor: 'pointer', fontSize: '12px'
                        }}
                          onClick={() => { setSelectedUserId(u.id); setActiveTab('overview'); }}>
                          Manage
                        </button>
                        {u.status !== 'inactive' && (
                          <button style={{
                            background: '#fff', border: '1px solid #fee2e2', color: '#dc2626',
                            padding: '4px 10px', borderRadius: '6px', cursor: 'pointer',
                            fontSize: '12px', display: 'flex', alignItems: 'center', gap: 4
                          }}
                            onClick={() => { if (window.confirm('Deactivate this user?')) deactivateMut.mutate(u.id); }}>
                            <UserX size={12} /> Deactivate
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

        {/* Pagination */}
        {total > 20 && (
          <div style={{ display: 'flex', justifyContent: 'center', gap: '8px', padding: '16px' }}>
            <button className="btn btn-outline" disabled={page === 1} onClick={() => setPage(p => p - 1)}>← Prev</button>
            <span style={{ lineHeight: '36px', fontSize: '14px', color: '#64748b' }}>Page {page}</span>
            <button className="btn btn-outline" onClick={() => setPage(p => p + 1)}>Next →</button>
          </div>
        )}
      </div>

      {/* Customer Detail Profile Modal */}
      {selectedUserId && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(4px)',
          display: 'flex', justifyContent: 'flex-end', zIndex: 1000,
          animation: 'fadeIn 0.2s ease-out'
        }} onClick={() => setSelectedUserId(null)}>
          <div style={{
            width: '100%', maxWidth: '850px', background: '#fff', height: '100%',
            boxShadow: '-4px 0 24px rgba(0,0,0,0.15)', display: 'flex', flexDirection: 'column',
            overflow: 'hidden'
          }} onClick={e => e.stopPropagation()}>
            
            {/* Modal Header */}
            <div style={{ padding: '20px 24px', borderBottom: '1px solid #e2e8f0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
                <div style={{
                  width: 48, height: 48, borderRadius: '50%', background: '#ecfdf5',
                  color: '#059669', display: 'flex', alignItems: 'center', justifycontent: 'center',
                  fontWeight: 700, fontSize: '18px', display: 'flex', justifyContent: 'center', alignItems: 'center'
                }}>
                  {detail?.user?.full_name ? detail.user.full_name[0].toUpperCase() : 'U'}
                </div>
                <div>
                  <h2 style={{ fontSize: '1.25rem', fontWeight: 700, color: '#0f172a', marginBottom: 2 }}>
                    {detail?.user?.full_name || 'Loading Details...'}
                  </h2>
                  <p style={{ fontSize: '12px', color: '#64748b', margin: 0 }}>
                    Customer Code: <strong style={{ color: '#0f172a' }}>{detail?.customer?.customer_code || '—'}</strong>
                  </p>
                </div>
              </div>
              <button onClick={() => setSelectedUserId(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}>
                <X size={24} />
              </button>
            </div>

            {/* Modal Tabs Navigation */}
            <div style={{ display: 'flex', background: '#f8fafc', borderBottom: '1px solid #e2e8f0', padding: '0 24px' }}>
              {[
                { id: 'overview', label: 'Overview', icon: <User size={14} /> },
                { id: 'subscriptions', label: 'Subscription History', icon: <Calendar size={14} /> },
                { id: 'deliveries', label: 'Delivery Schedule', icon: <Clock size={14} /> },
                { id: 'payments', label: 'Payment Logs', icon: <CreditCard size={14} /> }
              ].map(t => (
                <button key={t.id} onClick={() => setActiveTab(t.id)} style={{
                  display: 'flex', alignItems: 'center', gap: 6, padding: '14px 16px',
                  background: 'none', border: 'none', cursor: 'pointer', fontSize: '13px',
                  fontWeight: 600, color: activeTab === t.id ? '#059669' : '#64748b',
                  borderBottom: activeTab === t.id ? '2px solid #059669' : '2px solid transparent',
                  transition: 'all 0.2s'
                }}>
                  {t.icon}
                  {t.label}
                </button>
              ))}
            </div>

            {/* Modal Content */}
            <div style={{ flex: 1, overflowY: 'auto', padding: '24px' }}>
              {isDetailLoading ? (
                <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '64px 0', color: '#94a3b8' }}>
                  <RefreshCw className="spinner" style={{ color: '#059669', width: '24px', height: '24px', marginBottom: '12px' }} />
                  <p>Loading full profile history...</p>
                </div>
              ) : !detail ? (
                <div style={{ textAlign: 'center', padding: '48px', color: '#94a3b8' }}>Failed to load profile details</div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '24px' }}>
                  
                  {/* OVERVIEW TAB */}
                  {activeTab === 'overview' && (
                    <>
                      {/* Personal Info Grid */}
                      <div className="stats-grid">
                        <div className="card stat-card" style={{ padding: '16px' }}>
                          <span style={{ fontSize: '11px', color: '#94a3b8', textTransform: 'uppercase', fontWeight: 600 }}>Mobile</span>
                          <p style={{ fontSize: '15px', fontWeight: 600, color: '#1e293b', marginTop: 4 }}>{detail.user.phone}</p>
                        </div>
                        <div className="card stat-card" style={{ padding: '16px' }}>
                          <span style={{ fontSize: '11px', color: '#94a3b8', textTransform: 'uppercase', fontWeight: 600 }}>Email</span>
                          <p style={{ fontSize: '15px', fontWeight: 600, color: '#1e293b', marginTop: 4 }}>{detail.user.email || '—'}</p>
                        </div>
                        <div className="card stat-card" style={{ padding: '16px' }}>
                          <span style={{ fontSize: '11px', color: '#94a3b8', textTransform: 'uppercase', fontWeight: 600 }}>Status</span>
                          <p style={{ marginTop: 6 }}>
                            <span style={{
                              background: STATUS_STYLES[detail.user.status]?.bg || '#f1f5f9',
                              color: STATUS_STYLES[detail.user.status]?.color || '#64748b',
                              padding: '2px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 600
                            }}>{detail.user.status}</span>
                          </p>
                        </div>
                        <div className="card stat-card" style={{ padding: '16px' }}>
                          <span style={{ fontSize: '11px', color: '#94a3b8', textTransform: 'uppercase', fontWeight: 600 }}>Joined Date</span>
                          <p style={{ fontSize: '15px', fontWeight: 600, color: '#1e293b', marginTop: 4 }}>
                            {new Date(detail.user.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })}
                          </p>
                        </div>
                      </div>

                      {/* Addresses */}
                      <div>
                        <h4 style={{ fontSize: '14px', color: '#0f172a', fontWeight: 600, marginBottom: '12px', display: 'flex', alignItems: 'center', gap: 6 }}>
                          <MapPin size={16} style={{ color: '#059669' }} /> Delivery Addresses
                        </h4>
                        {detail.addresses.length === 0 ? (
                          <div style={{ background: '#f8fafc', padding: '16px', borderRadius: '8px', color: '#64748b', fontSize: '13px' }}>
                            No delivery addresses configured.
                          </div>
                        ) : (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: 10 }}>
                            {detail.addresses.map(addr => (
                              <div key={addr.id} style={{
                                padding: '14px 16px', borderRadius: '8px', border: '1px solid #e2e8f0',
                                background: addr.is_default ? '#f0fdf4' : '#fff',
                                borderColor: addr.is_default ? '#bbf7d0' : '#e2e8f0'
                              }}>
                                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 4 }}>
                                  <strong style={{ fontSize: '13px', textTransform: 'capitalize', color: '#1e293b' }}>
                                    {addr.label || 'Address'} ({addr.address_type})
                                  </strong>
                                  {addr.is_default && <span style={{ fontSize: '10px', background: '#22c55e', color: '#fff', padding: '1px 6px', borderRadius: '4px', fontWeight: 700 }}>DEFAULT</span>}
                                </div>
                                <p style={{ fontSize: '13px', color: '#475569', margin: 0 }}>
                                  {addr.address_line1}{addr.address_line2 ? `, ${addr.address_line2}` : ''}, {addr.city}, {addr.state} - {addr.pincode}
                                </p>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>

                      {/* Active Subscriptions Summary */}
                      <div>
                        <h4 style={{ fontSize: '14px', color: '#0f172a', fontWeight: 600, marginBottom: '12px', display: 'flex', alignItems: 'center', gap: 6 }}>
                          <CheckCircle2 size={16} style={{ color: '#059669' }} /> Active Subscriptions
                        </h4>
                        {detail.subscriptions.filter(s => s.status === 'active' || s.status === 'paused').length === 0 ? (
                          <div style={{ background: '#f8fafc', padding: '24px', borderRadius: '8px', color: '#64748b', fontSize: '13px', textAlign: 'center' }}>
                            No active subscriptions.
                          </div>
                        ) : (
                          detail.subscriptions.filter(s => s.status === 'active' || s.status === 'paused').map(sub => (
                            <div key={sub.id} className="card" style={{ padding: '16px', borderLeft: '4px solid #10b981', marginBottom: 10 }}>
                              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
                                <div>
                                  <h5 style={{ fontSize: '15px', fontWeight: 700, margin: 0 }}>{sub.product_name}</h5>
                                  <p style={{ fontSize: '12px', color: '#64748b', margin: 0 }}>{sub.plan_name} Plan</p>
                                </div>
                                <span style={{
                                  background: sub.status === 'paused' ? '#fef3c7' : '#dcfce7',
                                  color: sub.status === 'paused' ? '#b45309' : '#15803d',
                                  padding: '2px 8px', borderRadius: '4px', fontSize: '11px', fontWeight: 600, textTransform: 'uppercase'
                                }}>{sub.status}</span>
                              </div>
                              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8 }}>
                                <div style={{ background: '#f8fafc', padding: 8, borderRadius: 6, textAlign: 'center' }}>
                                  <span style={{ fontSize: '18px', fontWeight: 700, color: '#1e293b' }}>{sub.total_deliveries}</span>
                                  <div style={{ fontSize: '10px', color: '#64748b' }}>Total</div>
                                </div>
                                <div style={{ background: '#f8fafc', padding: 8, borderRadius: 6, textAlign: 'center' }}>
                                  <span style={{ fontSize: '18px', fontWeight: 700, color: '#16a34a' }}>{sub.completed_deliveries}</span>
                                  <div style={{ fontSize: '10px', color: '#64748b' }}>Delivered</div>
                                </div>
                                <div style={{ background: '#f8fafc', padding: 8, borderRadius: 6, textAlign: 'center' }}>
                                  <span style={{ fontSize: '18px', fontWeight: 700, color: '#dc2626' }}>{sub.missed_deliveries}</span>
                                  <div style={{ fontSize: '10px', color: '#64748b' }}>Missed</div>
                                </div>
                                <div style={{ background: '#f8fafc', padding: 8, borderRadius: 6, textAlign: 'center' }}>
                                  <span style={{ fontSize: '18px', fontWeight: 700, color: '#7e22ce' }}>{sub.total_paused_days}</span>
                                  <div style={{ fontSize: '10px', color: '#64748b' }}>Paused Days</div>
                                </div>
                              </div>
                            </div>
                          ))
                        )}
                      </div>
                    </>
                  )}

                  {/* SUBSCRIPTION HISTORY TAB */}
                  {activeTab === 'subscriptions' && (
                    <div className="table-container" style={{ border: '1px solid #e2e8f0' }}>
                      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
                        <thead>
                          <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0' }}>
                            {['Product', 'Plan', 'Amount', 'Progress', 'Paused Days', 'Start Date', 'Status'].map(h => (
                              <th key={h} style={{ padding: '12px', fontWeight: 600, color: '#64748b', textAlign: 'left' }}>{h}</th>
                            ))}
                          </tr>
                        </thead>
                        <tbody>
                          {detail.subscriptions.length === 0 ? (
                            <tr>
                              <td colSpan={7} style={{ textAlign: 'center', padding: '24px', color: '#94a3b8' }}>No subscription history</td>
                            </tr>
                          ) : (
                            detail.subscriptions.map(sub => (
                              <tr key={sub.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                                <td style={{ padding: '12px', fontWeight: 500 }}>{sub.product_name}</td>
                                <td style={{ padding: '12px', color: '#475569' }}>{sub.plan_name}</td>
                                <td style={{ padding: '12px', fontWeight: 600 }}>₹{sub.total_amount}</td>
                                <td style={{ padding: '12px' }}>
                                  {sub.completed_deliveries} / {sub.total_deliveries}
                                </td>
                                <td style={{ padding: '12px', color: '#7e22ce', fontWeight: 600 }}>{sub.total_paused_days}</td>
                                <td style={{ padding: '12px', color: '#64748b' }}>
                                  {sub.start_date ? new Date(sub.start_date).toLocaleDateString('en-IN') : '—'}
                                </td>
                                <td style={{ padding: '12px' }}>
                                  <span style={{
                                    background: sub.status === 'active' ? '#dcfce7' : sub.status === 'paused' ? '#fef3c7' : '#f1f5f9',
                                    color: sub.status === 'active' ? '#15803d' : sub.status === 'paused' ? '#b45309' : '#475569',
                                    padding: '2px 8px', borderRadius: '4px', fontSize: '11px', fontWeight: 600, textTransform: 'uppercase'
                                  }}>{sub.status}</span>
                                </td>
                              </tr>
                            ))
                          )}
                        </tbody>
                      </table>
                    </div>
                  )}

                  {/* DELIVERIES & REAL-TIME REASSIGNMENT TAB */}
                  {activeTab === 'deliveries' && (
                    <div>
                      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                        <h4 style={{ fontSize: '14px', fontWeight: 600, margin: 0 }}>Delivery Logs & Schedules ({detail.deliveries.length})</h4>
                        <span style={{ fontSize: '11px', color: '#94a3b8' }}>*Changes reflect instantly to delivery boys & customer PWAs</span>
                      </div>
                      <div className="table-container" style={{ border: '1px solid #e2e8f0', maxHeight: '480px', overflowY: 'auto' }}>
                        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
                          <thead>
                            <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0', position: 'sticky', top: 0, zIndex: 10 }}>
                              {['Date', 'Status', 'Assigned Boy Override (Real-time)', 'Action'].map(h => (
                                <th key={h} style={{ padding: '12px', fontWeight: 600, color: '#64748b', textAlign: 'left', background: '#f8fafc' }}>{h}</th>
                              ))}
                            </tr>
                          </thead>
                          <tbody>
                            {detail.deliveries.length === 0 ? (
                              <tr>
                                <td colSpan={4} style={{ textAlign: 'center', padding: '24px', color: '#94a3b8' }}>No scheduled deliveries</td>
                              </tr>
                            ) : (
                              detail.deliveries.map(d => {
                                const st = DELIVERY_STATUS_STYLES[d.status] || DELIVERY_STATUS_STYLES.pending;
                                const isActionable = d.status === 'pending' || d.status === 'assigned' || d.status === 'carry_forward';
                                return (
                                  <tr key={d.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                                    <td style={{ padding: '12px', fontWeight: 500 }}>
                                      {new Date(d.scheduled_date).toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' })}
                                    </td>
                                    <td style={{ padding: '12px' }}>
                                      <span style={{
                                        background: st.bg, color: st.color,
                                        padding: '2px 8px', borderRadius: '4px', fontSize: '11px', fontWeight: 600
                                      }}>{st.label}</span>
                                    </td>
                                    <td style={{ padding: '12px' }}>
                                      {isActionable ? (
                                        <select
                                          className="form-control"
                                          style={{ padding: '4px 8px', fontSize: '12px', width: '220px' }}
                                          value={d.assigned_partner?.id || ''}
                                          onChange={(e) => {
                                            const val = e.target.value;
                                            if (val) {
                                              reassignMut.mutate({
                                                delivery_id: d.id,
                                                delivery_partner_id: val
                                              });
                                            }
                                          }}
                                          disabled={reassignMut.isPending}
                                        >
                                          <option value="">-- Choose Partner (Unassigned) --</option>
                                          {partners.map(p => (
                                            <option key={p.id} value={p.id}>
                                              {p.full_name} ({p.mobile_number}) - Workload: {p.assigned_count}
                                            </option>
                                          ))}
                                        </select>
                                      ) : (
                                        <span style={{ color: '#64748b' }}>
                                          {d.assigned_partner ? `${d.assigned_partner.full_name} (${d.assigned_partner.mobile_number})` : '—'}
                                        </span>
                                      )}
                                    </td>
                                    <td style={{ padding: '12px' }}>
                                      {isActionable && (
                                        <button
                                          className="btn"
                                          style={{
                                            padding: '4px 8px', fontSize: '11px', background: '#f3e8ff', color: '#7e22ce',
                                            border: 'none', borderRadius: '4px', cursor: 'pointer', fontWeight: 600
                                          }}
                                          onClick={() => {
                                            if (window.confirm('Skip/Pause this delivery day? A carry-forward day will be appended to the end of their schedule.')) {
                                              skipMut.mutate(d.id);
                                            }
                                          }}
                                          disabled={skipMut.isPending}
                                        >
                                          Pause Day
                                        </button>
                                      )}
                                    </td>
                                  </tr>
                                );
                              })
                            )}
                          </tbody>
                        </table>
                      </div>
                    </div>
                  )}

                  {/* PAYMENTS TAB */}
                  {activeTab === 'payments' && (
                    <div className="table-container" style={{ border: '1px solid #e2e8f0' }}>
                      <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
                        <thead>
                          <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0' }}>
                            {['Payment ID', 'Gateway Reference', 'Method', 'Paid At', 'Amount', 'Status'].map(h => (
                              <th key={h} style={{ padding: '12px', fontWeight: 600, color: '#64748b', textAlign: 'left' }}>{h}</th>
                            ))}
                          </tr>
                        </thead>
                        <tbody>
                          {detail.payments.length === 0 ? (
                            <tr>
                              <td colSpan={6} style={{ textAlign: 'center', padding: '24px', color: '#94a3b8' }}>No payments recorded</td>
                            </tr>
                          ) : (
                            detail.payments.map(p => (
                              <tr key={p.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                                <td style={{ padding: '12px', fontFamily: 'monospace', fontSize: '11px', color: '#64748b' }}>{p.id.substring(0, 8)}...</td>
                                <td style={{ padding: '12px' }}>{p.gateway_payment_id || '—'}</td>
                                <td style={{ padding: '12px', textTransform: 'capitalize' }}>{p.payment_method}</td>
                                <td style={{ padding: '12px', color: '#64748b' }}>
                                  {p.paid_at ? new Date(p.paid_at).toLocaleString('en-IN') : '—'}
                                </td>
                                <td style={{ padding: '12px', fontWeight: 700 }}>₹{p.amount}</td>
                                <td style={{ padding: '12px' }}>
                                  <span style={{
                                    background: p.status === 'capture_success' || p.status === 'success' ? '#dcfce7' : '#fee2e2',
                                    color: p.status === 'capture_success' || p.status === 'success' ? '#15803d' : '#b91c1c',
                                    padding: '2px 8px', borderRadius: '4px', fontSize: '11px', fontWeight: 600, textTransform: 'uppercase'
                                  }}>{p.status === 'capture_success' ? 'SUCCESS' : p.status}</span>
                                </td>
                              </tr>
                            ))
                          )}
                        </tbody>
                      </table>
                    </div>
                  )}

                </div>
              )}
            </div>

            {/* Modal Footer */}
            <div style={{ padding: '16px 24px', borderTop: '1px solid #e2e8f0', display: 'flex', justifyContent: 'flex-end', background: '#f8fafc' }}>
              <button className="btn btn-outline" onClick={() => setSelectedUserId(null)}>Close Profile</button>
            </div>

          </div>
        </div>
      )}
    </div>
  );
}
