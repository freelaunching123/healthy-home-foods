import React, { useState, useEffect } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { 
  getSubscriptions, createSubscription, updateSubscription, deleteSubscription, 
  pauseSubscription, resumeSubscription, cancelSubscription, renewSubscription,
  getSubscriptionDeliveries, getSubscriptionPlans, skipDelivery, getSubscriptionDashboard 
} from '../api/subscriptionsApi';
import { getProducts } from '../api/productsApi';
import { getUsers, getCustomerDetail } from '../api/usersApi';
import toast from 'react-hot-toast';
import { 
  Plus, Search, Filter, Calendar, DollarSign, Clock, User, MapPin, 
  Activity, ChevronDown, ChevronUp, Info, AlertCircle, Trash2, Edit2, 
  Play, Pause, XCircle, RefreshCw, X, Check, Eye
} from 'lucide-react';

const STATUS_STYLES = {
  active:          { bg: '#dcfce7', color: '#16a34a', label: 'Active' },
  paused:          { bg: '#fef3c7', color: '#d97706', label: 'Paused' },
  pending_payment: { bg: '#dbeafe', color: '#2563eb', label: 'Pending Payment' },
  completed:       { bg: '#f1f5f9', color: '#475569', label: 'Completed' },
  cancelled:       { bg: '#fee2e2', color: '#dc2626', label: 'Cancelled' },
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

const TABS = ['all', 'active', 'paused', 'pending_payment', 'completed', 'cancelled'];

export default function Subscriptions() {
  const qc = useQueryClient();
  const [tab, setTab] = useState('all');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const [selectedSubId, setSelectedSubId] = useState(null);
  const [detailTab, setDetailTab] = useState('items');

  // Modals state
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [showPauseModal, setShowPauseModal] = useState(false);
  const [showCancelModal, setShowCancelModal] = useState(false);
  const [showRenewModal, setShowRenewModal] = useState(false);

  const [pauseReason, setPauseReason] = useState('');
  const [cancelReason, setCancelReason] = useState('');
  const [renewPlanId, setRenewPlanId] = useState('');
  const [renewAutoRenew, setRenewAutoRenew] = useState(false);

  // Queries
  const { data: dashboardStats } = useQuery({
    queryKey: ['subscription-dashboard'],
    queryFn: async () => {
      const { data } = await getSubscriptionDashboard();
      return data;
    }
  });

  const { data: subs = [], isLoading } = useQuery({
    queryKey: ['subscriptions', page, tab, search],
    queryFn: async () => {
      const { data } = await getSubscriptions({ 
        status: tab, 
        search, 
        page, 
        page_size: 15 
      });
      return data?.items || data || [];
    },
  });

  const { data: plans = [] } = useQuery({
    queryKey: ['plans'],
    queryFn: async () => {
      const { data } = await getSubscriptionPlans();
      return data;
    }
  });

  const { data: productsData } = useQuery({
    queryKey: ['products-list'],
    queryFn: async () => {
      const { data } = await getProducts({ page_size: 100, active_only: true });
      return data?.items || data || [];
    }
  });

  const { data: customersData } = useQuery({
    queryKey: ['customers-list'],
    queryFn: async () => {
      const { data } = await getUsers({ role: 'customer', limit: 100 });
      return data?.items || data || [];
    }
  });

  const { data: subDetail, isLoading: isDetailLoading } = useQuery({
    queryKey: ['subscription-detail', selectedSubId],
    queryFn: async () => {
      const { data } = await getSubscription(selectedSubId);
      return data;
    },
    enabled: !!selectedSubId,
  });

  const { data: deliveries = [] } = useQuery({
    queryKey: ['subscription-deliveries', selectedSubId],
    queryFn: async () => {
      const { data } = await getSubscriptionDeliveries(selectedSubId);
      return data?.items || data || [];
    },
    enabled: !!selectedSubId && detailTab === 'schedule',
  });

  // Create Form State
  const [newSubCustomer, setNewSubCustomer] = useState('');
  const [newSubAddress, setNewSubAddress] = useState('');
  const [newSubPlan, setNewSubPlan] = useState('');
  const [newSubTime, setNewSubTime] = useState('Morning (6:00 AM - 8:00 AM)');
  const [newSubAutoRenew, setNewSubAutoRenew] = useState(false);
  const [newSubNotes, setNewSubNotes] = useState('');
  const [newSubItems, setNewSubItems] = useState([{ product_id: '', quantity: 1 }]);
  const [customerAddresses, setCustomerAddresses] = useState([]);

  // Fetch addresses when customer is chosen
  useEffect(() => {
    if (newSubCustomer) {
      getCustomerDetail(newSubCustomer).then(({ data }) => {
        setCustomerAddresses(data?.addresses || []);
        if (data?.addresses?.length > 0) {
          const defaultAddr = data.addresses.find(a => a.is_default) || data.addresses[0];
          setNewSubAddress(defaultAddr.id);
        } else {
          setNewSubAddress('');
        }
      });
    } else {
      setCustomerAddresses([]);
      setNewSubAddress('');
    }
  }, [newSubCustomer]);

  // Edit Form State
  const [editSubAddress, setEditSubAddress] = useState('');
  const [editSubTime, setEditSubTime] = useState('');
  const [editSubAutoRenew, setEditSubAutoRenew] = useState(false);
  const [editSubNotes, setEditSubNotes] = useState('');
  const [editSubItems, setEditSubItems] = useState([]);
  const [editCustomerAddresses, setEditCustomerAddresses] = useState([]);

  // Populate Edit Form State when subDetail is loaded
  useEffect(() => {
    if (subDetail && showEditModal) {
      setEditSubAddress(subDetail.address_id);
      setEditSubTime(subDetail.preferred_delivery_time || '');
      setEditSubAutoRenew(subDetail.auto_renew);
      setEditSubNotes(subDetail.notes || '');
      setEditSubItems(subDetail.items.map(item => ({
        product_id: item.product_id,
        quantity: item.quantity
      })));
      getCustomerDetail(subDetail.customer_id).then(({ data }) => {
        setEditCustomerAddresses(data?.addresses || []);
      });
    }
  }, [subDetail, showEditModal]);

  // Calculations for new Sub
  const calculateTotal = (items, planId) => {
    if (!productsData || !plans) return { pricePerDelivery: 0, total: 0 };
    const plan = plans.find(p => p.id === planId);
    if (!plan) return { pricePerDelivery: 0, total: 0 };
    let pricePerDelivery = 0;
    items.forEach(item => {
      const prod = productsData.find(p => p.id === item.product_id);
      if (prod) {
        pricePerDelivery += parseFloat(prod.price) * item.quantity;
      }
    });
    return {
      pricePerDelivery,
      total: pricePerDelivery * plan.total_deliveries
    };
  };

  const createTotalInfo = calculateTotal(newSubItems, newSubPlan);
  const editTotalInfo = calculateTotal(editSubItems, subDetail?.plan_id);

  // Mutations
  const createMut = useMutation({
    mutationFn: (payload) => createSubscription(payload),
    onSuccess: () => {
      qc.invalidateQueries(['subscriptions']);
      qc.invalidateQueries(['subscription-dashboard']);
      toast.success('Subscription created successfully!');
      setShowCreateModal(false);
      resetCreateForm();
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed to create subscription'),
  });

  const updateMut = useMutation({
    mutationFn: ({ id, payload }) => updateSubscription(id, payload),
    onSuccess: () => {
      qc.invalidateQueries(['subscriptions']);
      qc.invalidateQueries(['subscription-detail', selectedSubId]);
      toast.success('Subscription updated successfully!');
      setShowEditModal(false);
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed to update subscription'),
  });

  const deleteMut = useMutation({
    mutationFn: (id) => deleteSubscription(id),
    onSuccess: () => {
      qc.invalidateQueries(['subscriptions']);
      qc.invalidateQueries(['subscription-dashboard']);
      toast.success('Subscription deleted permanently');
      setSelectedSubId(null);
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed to delete subscription'),
  });

  const pauseMut = useMutation({
    mutationFn: ({ id, reason }) => pauseSubscription(id, reason),
    onSuccess: () => {
      qc.invalidateQueries(['subscriptions']);
      qc.invalidateQueries(['subscription-dashboard']);
      qc.invalidateQueries(['subscription-detail', selectedSubId]);
      toast.success('Subscription paused');
      setShowPauseModal(false);
      setPauseReason('');
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed to pause'),
  });

  const resumeMut = useMutation({
    mutationFn: (id) => resumeSubscription(id),
    onSuccess: () => {
      qc.invalidateQueries(['subscriptions']);
      qc.invalidateQueries(['subscription-dashboard']);
      qc.invalidateQueries(['subscription-detail', selectedSubId]);
      toast.success('Subscription resumed successfully');
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed to resume'),
  });

  const cancelMut = useMutation({
    mutationFn: ({ id, reason }) => cancelSubscription(id, reason),
    onSuccess: () => {
      qc.invalidateQueries(['subscriptions']);
      qc.invalidateQueries(['subscription-dashboard']);
      qc.invalidateQueries(['subscription-detail', selectedSubId]);
      toast.success('Subscription cancelled');
      setShowCancelModal(false);
      setCancelReason('');
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed to cancel'),
  });

  const renewMut = useMutation({
    mutationFn: ({ id, params }) => renewSubscription(id, params),
    onSuccess: () => {
      qc.invalidateQueries(['subscriptions']);
      qc.invalidateQueries(['subscription-dashboard']);
      toast.success('Subscription renewed successfully! New subscription created.');
      setShowRenewModal(false);
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed to renew'),
  });

  const skipMut = useMutation({
    mutationFn: (deliveryId) => skipDelivery(deliveryId),
    onSuccess: () => {
      qc.invalidateQueries(['subscription-deliveries', selectedSubId]);
      qc.invalidateQueries(['subscription-detail', selectedSubId]);
      toast.success('Delivery skipped and extended successfully!');
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed to skip delivery'),
  });

  const resetCreateForm = () => {
    setNewSubCustomer('');
    setNewSubPlan('');
    setNewSubAddress('');
    setNewSubItems([{ product_id: '', quantity: 1 }]);
    setNewSubNotes('');
    setNewSubAutoRenew(false);
  };

  const handleAddItemRow = (isEdit = false) => {
    if (isEdit) {
      setEditSubItems([...editSubItems, { product_id: '', quantity: 1 }]);
    } else {
      setNewSubItems([...newSubItems, { product_id: '', quantity: 1 }]);
    }
  };

  const handleRemoveItemRow = (index, isEdit = false) => {
    if (isEdit) {
      setEditSubItems(editSubItems.filter((_, i) => i !== index));
    } else {
      setNewSubItems(newSubItems.filter((_, i) => i !== index));
    }
  };

  const handleItemChange = (index, field, value, isEdit = false) => {
    const targetItems = isEdit ? [...editSubItems] : [...newSubItems];
    targetItems[index][field] = value;
    if (isEdit) {
      setEditSubItems(targetItems);
    } else {
      setNewSubItems(targetItems);
    }
  };

  const handleCreateSubmit = (e) => {
    e.preventDefault();
    if (!newSubCustomer || !newSubAddress || !newSubPlan || newSubItems.some(i => !i.product_id)) {
      toast.error('Please fill in all required fields');
      return;
    }
    createMut.mutate({
      plan_id: newSubPlan,
      address_id: newSubAddress,
      preferred_delivery_time: newSubTime,
      auto_renew: newSubAutoRenew,
      notes: newSubNotes || null,
      items: newSubItems
    });
  };

  const handleEditSubmit = (e) => {
    e.preventDefault();
    if (!editSubAddress || editSubItems.some(i => !i.product_id)) {
      toast.error('Please fill in all required fields');
      return;
    }
    updateMut.mutate({
      id: selectedSubId,
      payload: {
        address_id: editSubAddress,
        preferred_delivery_time: editSubTime,
        auto_renew: editSubAutoRenew,
        notes: editSubNotes || null,
        items: editSubItems
      }
    });
  };

  return (
    <div className="dashboard animate-fade-in" style={{ fontFamily: 'Inter, sans-serif' }}>
      
      {/* Header */}
      <div className="dashboard-header" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '24px' }}>
        <div>
          <h1 className="page-title" style={{ fontSize: '28px', fontWeight: 800, color: '#0f172a', margin: 0 }}>Subscriptions</h1>
          <p className="text-gray" style={{ color: '#64748b', marginTop: '4px', fontSize: '14px' }}>Manage client subscriptions, items, status logs, and deliveries</p>
        </div>
        <button 
          onClick={() => setShowCreateModal(true)}
          style={{
            background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)',
            color: '#fff', border: 'none', padding: '10px 20px', borderRadius: '8px',
            fontWeight: 600, display: 'flex', alignItems: 'center', gap: '8px',
            boxShadow: '0 4px 12px rgba(16, 185, 129, 0.25)', cursor: 'pointer', transition: 'all 0.2s'
          }}
        >
          <Plus size={18} /> Create Subscription
        </button>
      </div>

      {/* Dashboard Stats Panel */}
      <div className="stats-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: '20px', marginBottom: '28px' }}>
        <div className="card stat-card" style={{ padding: '20px', background: '#fff', borderRadius: '12px', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>Total Revenue</span>
            <DollarSign size={18} style={{ color: '#10b981' }} />
          </div>
          <p style={{ fontSize: '24px', fontWeight: 800, color: '#0f172a', margin: '8px 0 0' }}>
            ₹{(dashboardStats?.total_revenue || 0).toLocaleString('en-IN')}
          </p>
        </div>
        <div className="card stat-card" style={{ padding: '20px', background: '#fff', borderRadius: '12px', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>Active Subscriptions</span>
            <Activity size={18} style={{ color: '#10b981' }} />
          </div>
          <p style={{ fontSize: '24px', fontWeight: 800, color: '#0f172a', margin: '8px 0 0' }}>
            {dashboardStats?.active || 0}
          </p>
        </div>
        <div className="card stat-card" style={{ padding: '20px', background: '#fff', borderRadius: '12px', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>Paused</span>
            <Pause size={18} style={{ color: '#d97706' }} />
          </div>
          <p style={{ fontSize: '24px', fontWeight: 800, color: '#0f172a', margin: '8px 0 0' }}>
            {dashboardStats?.paused || 0}
          </p>
        </div>
        <div className="card stat-card" style={{ padding: '20px', background: '#fff', borderRadius: '12px', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '12px', color: '#64748b', fontWeight: 600, textTransform: 'uppercase' }}>Pending Payment</span>
            <Clock size={18} style={{ color: '#2563eb' }} />
          </div>
          <p style={{ fontSize: '24px', fontWeight: 800, color: '#0f172a', margin: '8px 0 0' }}>
            {dashboardStats?.pending_payment || 0}
          </p>
        </div>
      </div>

      {/* Tabs and Search Filters */}
      <div style={{ display: 'flex', flexDirection: 'column', gap: '16px', marginBottom: '20px' }}>
        {/* Search */}
        <div className="card" style={{ padding: '16px', display: 'flex', gap: '16px', flexWrap: 'wrap', alignItems: 'center', justifyContent: 'space-between', borderRadius: '12px' }}>
          <div style={{ display: 'flex', gap: '12px', flex: 1, minWidth: '280px' }}>
            <input 
              className="form-control" 
              placeholder="🔍 Search by customer name, phone, or product..."
              value={search} 
              onChange={e => { setSearch(e.target.value); setPage(1); }} 
              style={{ maxWidth: 420 }} 
            />
          </div>
        </div>

        {/* Tab Filters */}
        <div style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
          {TABS.map(t => (
            <button 
              key={t} 
              onClick={() => { setTab(t); setPage(1); }}
              style={{
                padding: '8px 18px', borderRadius: '999px', border: '1px solid',
                fontWeight: 600, fontSize: '13px', cursor: 'pointer', transition: 'all 0.2s',
                borderColor: tab === t ? '#10b981' : '#e2e8f0',
                background: tab === t ? '#10b981' : '#fff',
                color: tab === t ? '#fff' : '#475569',
                boxShadow: tab === t ? '0 4px 10px rgba(16, 185, 129, 0.15)' : 'none'
              }}
            >
              {t.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}
            </button>
          ))}
        </div>
      </div>

      {/* Subscriptions Table */}
      <div className="card" style={{ padding: 0, overflow: 'hidden', borderRadius: '12px', border: '1px solid #e2e8f0', boxShadow: '0 1px 3px rgba(0,0,0,0.05)' }}>
        {isLoading ? (
          <div style={{ padding: '64px', textAlign: 'center', color: '#94a3b8' }}>
            <RefreshCw className="spinner" style={{ color: '#10b981', marginRight: '8px' }} />
            Loading subscriptions...
          </div>
        ) : subs.length === 0 ? (
          <div style={{ padding: '80px 24px', textAlign: 'center', color: '#94a3b8' }}>
            <p style={{ fontSize: '56px', margin: '0 0 12px' }}>📭</p>
            <p style={{ fontSize: '16px', fontWeight: 500 }}>No subscriptions found</p>
          </div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
              <thead>
                <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0' }}>
                  {['Customer', 'Items (Qty)', 'Plan', 'Deliveries', 'Amount', 'Status', 'Actions'].map(h => (
                    <th key={h} style={{ padding: '16px 20px', fontSize: '12px',
                      fontWeight: 700, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em' }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {subs.map((s, i) => {
                  const st = STATUS_STYLES[s.status] || STATUS_STYLES.pending_payment;
                  return (
                    <tr 
                      key={s.id} 
                      style={{ 
                        borderBottom: '1px solid #f1f5f9',
                        background: i % 2 === 0 ? '#fff' : '#fafafa',
                        transition: 'background 0.2s',
                        cursor: 'pointer'
                      }}
                      onClick={() => { setSelectedSubId(s.id); setDetailTab('items'); }}
                    >
                      {/* Customer */}
                      <td style={{ padding: '16px 20px', fontSize: '14px' }}>
                        <div style={{ fontWeight: 600, color: '#1e293b' }}>{s.customer_name || 'Customer'}</div>
                        <div style={{ fontSize: '12px', color: '#64748b', marginTop: '2px' }}>{s.customer_phone || ''}</div>
                      </td>
                      
                      {/* Items */}
                      <td style={{ padding: '16px 20px', fontSize: '14px', color: '#334155' }}>
                        {s.items?.length > 0 ? (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                            {s.items.map(item => (
                              <div key={item.id} style={{ fontWeight: 500 }}>
                                • {item.product_name} <span style={{ color: '#64748b', fontWeight: 400 }}>(x{item.quantity})</span>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <span>{s.product_name || '—'}</span>
                        )}
                      </td>

                      {/* Plan */}
                      <td style={{ padding: '16px 20px', fontSize: '14px', textTransform: 'capitalize', color: '#475569', fontWeight: 500 }}>
                        {s.plan_name || '—'}
                      </td>

                      {/* Deliveries */}
                      <td style={{ padding: '16px 20px', fontSize: '14px', color: '#475569' }}>
                        <div style={{ fontWeight: 600 }}>{s.completed_deliveries} / {s.total_deliveries}</div>
                        {s.missed_deliveries > 0 && <span style={{ color: '#dc2626', fontSize: '11px', fontWeight: 600 }}>{s.missed_deliveries} missed</span>}
                      </td>

                      {/* Amount */}
                      <td style={{ padding: '16px 20px', fontSize: '14px', fontWeight: 700, color: '#0f172a' }}>
                        ₹{parseFloat(s.total_amount || 0).toLocaleString('en-IN')}
                      </td>

                      {/* Status */}
                      <td style={{ padding: '16px 20px' }}>
                        <span style={{ background: st.bg, color: st.color,
                          padding: '4px 12px', borderRadius: '999px', fontSize: '11px', fontWeight: 700, display: 'inline-block' }}>
                          {st.label}
                        </span>
                      </td>

                      {/* Actions */}
                      <td style={{ padding: '16px 20px' }} onClick={e => e.stopPropagation()}>
                        <div style={{ display: 'flex', gap: '8px' }}>
                          <button 
                            className="btn btn-outline" 
                            style={{ padding: '6px', borderRadius: '6px', border: '1px solid #e2e8f0', cursor: 'pointer' }}
                            onClick={() => { setSelectedSubId(s.id); setDetailTab('items'); }}
                            title="View Details"
                          >
                            <Eye size={14} style={{ color: '#64748b' }} />
                          </button>
                          
                          {s.status === 'active' && (
                            <button 
                              className="btn btn-outline" 
                              style={{ padding: '6px', borderRadius: '6px', border: '1px solid #e2e8f0', cursor: 'pointer' }}
                              onClick={() => { setSelectedSubId(s.id); setShowPauseModal(true); }}
                              title="Pause"
                            >
                              <Pause size={14} style={{ color: '#d97706' }} />
                            </button>
                          )}
                          
                          {s.status === 'paused' && (
                            <button 
                              className="btn" 
                              style={{ padding: '6px', borderRadius: '6px', background: '#ecfdf5', border: '1px solid #bbf7d0', cursor: 'pointer' }}
                              onClick={() => resumeMut.mutate(s.id)}
                              title="Resume"
                            >
                              <Play size={14} style={{ color: '#10b981' }} />
                            </button>
                          )}

                          {['active', 'paused', 'pending_payment'].includes(s.status) && (
                            <button 
                              style={{ padding: '6px', borderRadius: '6px', background: '#fff', border: '1px solid #fee2e2', cursor: 'pointer' }}
                              onClick={() => { setSelectedSubId(s.id); setShowCancelModal(true); }}
                              title="Cancel"
                            >
                              <XCircle size={14} style={{ color: '#dc2626' }} />
                            </button>
                          )}

                          {['completed', 'cancelled'].includes(s.status) && (
                            <button 
                              className="btn" 
                              style={{ padding: '6px', borderRadius: '6px', background: '#eff6ff', border: '1px solid #bfdbfe', cursor: 'pointer' }}
                              onClick={() => { setSelectedSubId(s.id); setRenewPlanId(s.plan_id); setRenewAutoRenew(s.auto_renew); setShowRenewModal(true); }}
                              title="Renew"
                            >
                              <RefreshCw size={14} style={{ color: '#2563eb' }} />
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* CREATE SUBSCRIPTION MODAL */}
      {showCreateModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(4px)',
          display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 1000,
          padding: '20px'
        }}>
          <div style={{
            width: '100%', maxWidth: '650px', background: '#fff', borderRadius: '12px',
            boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1)', display: 'flex', flexDirection: 'column',
            maxHeight: '90vh', overflow: 'hidden'
          }}>
            <div style={{ padding: '20px 24px', borderBottom: '1px solid #e2e8f0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h2 style={{ fontSize: '18px', fontWeight: 700, margin: 0, color: '#0f172a' }}>New Subscription</h2>
              <button onClick={() => setShowCreateModal(false)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}>
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleCreateSubmit} style={{ flex: 1, overflowY: 'auto', padding: '24px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
              
              {/* Customer */}
              <div>
                <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569', marginBottom: '6px', display: 'block' }}>Customer *</label>
                <select 
                  className="form-control"
                  value={newSubCustomer}
                  onChange={e => setNewSubCustomer(e.target.value)}
                  required
                >
                  <option value="">-- Select Customer --</option>
                  {customersData.map(c => (
                    <option key={c.id} value={c.id}>{c.full_name} ({c.phone})</option>
                  ))}
                </select>
              </div>

              {/* Address */}
              <div>
                <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569', marginBottom: '6px', display: 'block' }}>Delivery Address *</label>
                <select 
                  className="form-control"
                  value={newSubAddress}
                  onChange={e => setNewSubAddress(e.target.value)}
                  disabled={!newSubCustomer}
                  required
                >
                  <option value="">-- Select Address --</option>
                  {customerAddresses.map(a => (
                    <option key={a.id} value={a.id}>{a.address_line1}, {a.city} ({a.address_type})</option>
                  ))}
                </select>
                {!newSubCustomer && <span style={{ fontSize: '11px', color: '#64748b' }}>Choose a customer to load addresses</span>}
              </div>

              {/* Plan */}
              <div>
                <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569', marginBottom: '6px', display: 'block' }}>Plan *</label>
                <select 
                  className="form-control"
                  value={newSubPlan}
                  onChange={e => setNewSubPlan(e.target.value)}
                  required
                >
                  <option value="">-- Select Subscription Plan --</option>
                  {plans.map(p => (
                    <option key={p.id} value={p.id}>{p.name} ({p.total_deliveries} Deliveries)</option>
                  ))}
                </select>
              </div>

              {/* Products selection (dynamic list) */}
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569' }}>Products Selection *</label>
                  <button 
                    type="button" 
                    onClick={() => handleAddItemRow(false)}
                    style={{ background: '#ecfdf5', color: '#059669', border: '1px solid #a7f3d0', padding: '4px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 600, cursor: 'pointer' }}
                  >
                    + Add Product
                  </button>
                </div>
                
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  {newSubItems.map((item, idx) => (
                    <div key={idx} style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                      <select 
                        className="form-control"
                        value={item.product_id}
                        onChange={e => handleItemChange(idx, 'product_id', e.target.value, false)}
                        style={{ flex: 1 }}
                        required
                      >
                        <option value="">-- Choose Product --</option>
                        {productsData?.map(p => (
                          <option key={p.id} value={p.id}>{p.name} - ₹{p.price}</option>
                        ))}
                      </select>
                      
                      <input 
                        type="number" 
                        min="1"
                        className="form-control"
                        value={item.quantity}
                        onChange={e => handleItemChange(idx, 'quantity', parseInt(e.target.value) || 1, false)}
                        style={{ width: '80px' }}
                        required
                      />

                      <button 
                        type="button"
                        onClick={() => handleRemoveItemRow(idx, false)}
                        disabled={newSubItems.length === 1}
                        style={{ background: '#fee2e2', border: 'none', padding: '8px', borderRadius: '6px', cursor: 'pointer', display: 'flex', alignItems: 'center' }}
                      >
                        <Trash2 size={16} style={{ color: '#dc2626' }} />
                      </button>
                    </div>
                  ))}
                </div>
              </div>

              {/* Preferences */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div>
                  <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569', marginBottom: '6px', display: 'block' }}>Delivery Time Slot</label>
                  <select 
                    className="form-control"
                    value={newSubTime}
                    onChange={e => setNewSubTime(e.target.value)}
                  >
                    <option value="Morning (6:00 AM - 8:00 AM)">Morning (6-8 AM)</option>
                    <option value="Noon (12:00 PM - 2:00 PM)">Noon (12-2 PM)</option>
                    <option value="Evening (6:00 PM - 8:00 PM)">Evening (6-8 PM)</option>
                  </select>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', paddingTop: '28px' }}>
                  <input 
                    type="checkbox" 
                    id="autoRenewCreate"
                    checked={newSubAutoRenew}
                    onChange={e => setNewSubAutoRenew(e.target.checked)}
                    style={{ width: '18px', height: '18px' }}
                  />
                  <label htmlFor="autoRenewCreate" style={{ fontSize: '13px', fontWeight: 600, color: '#475569', cursor: 'pointer' }}>Auto Renew</label>
                </div>
              </div>

              {/* Notes */}
              <div>
                <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569', marginBottom: '6px', display: 'block' }}>Notes</label>
                <textarea 
                  className="form-control" 
                  rows="2"
                  value={newSubNotes}
                  onChange={e => setNewSubNotes(e.target.value)}
                  placeholder="E.g., Drop at the security guard's desk..."
                  style={{ resize: 'none' }}
                />
              </div>

              {/* Price Preview */}
              {newSubPlan && (
                <div style={{ background: '#f8fafc', padding: '16px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', color: '#64748b', marginBottom: '4px' }}>
                    <span>Price Per Delivery:</span>
                    <span style={{ fontWeight: 600, color: '#334155' }}>₹{createTotalInfo.pricePerDelivery.toFixed(2)}</span>
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px', fontWeight: 700, color: '#0f172a' }}>
                    <span>Estimated Total (excl. tax):</span>
                    <span>₹{createTotalInfo.total.toFixed(2)}</span>
                  </div>
                </div>
              )}

              {/* Actions */}
              <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', marginTop: '12px' }}>
                <button type="button" className="btn btn-outline" onClick={() => setShowCreateModal(false)}>Cancel</button>
                <button 
                  type="submit" 
                  className="btn btn-primary"
                  disabled={createMut.isPending}
                  style={{ background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)', border: 'none', color: '#fff' }}
                >
                  {createMut.isPending ? 'Saving...' : 'Create Subscription'}
                </button>
              </div>

            </form>
          </div>
        </div>
      )}

      {/* EDIT SUBSCRIPTION MODAL */}
      {showEditModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(4px)',
          display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 1000,
          padding: '20px'
        }}>
          <div style={{
            width: '100%', maxWidth: '650px', background: '#fff', borderRadius: '12px',
            boxShadow: '0 20px 25px -5px rgba(0, 0, 0, 0.1)', display: 'flex', flexDirection: 'column',
            maxHeight: '90vh', overflow: 'hidden'
          }}>
            <div style={{ padding: '20px 24px', borderBottom: '1px solid #e2e8f0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <h2 style={{ fontSize: '18px', fontWeight: 700, margin: 0, color: '#0f172a' }}>Edit Subscription</h2>
              <button onClick={() => setShowEditModal(false)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}>
                <X size={20} />
              </button>
            </div>
            
            <form onSubmit={handleEditSubmit} style={{ flex: 1, overflowY: 'auto', padding: '24px', display: 'flex', flexDirection: 'column', gap: '20px' }}>
              
              {/* Address */}
              <div>
                <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569', marginBottom: '6px', display: 'block' }}>Delivery Address *</label>
                <select 
                  className="form-control"
                  value={editSubAddress}
                  onChange={e => setEditSubAddress(e.target.value)}
                  required
                >
                  <option value="">-- Select Address --</option>
                  {editCustomerAddresses.map(a => (
                    <option key={a.id} value={a.id}>{a.address_line1}, {a.city} ({a.address_type})</option>
                  ))}
                </select>
              </div>

              {/* Products selection (dynamic list) */}
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '10px' }}>
                  <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569' }}>Products Selection *</label>
                  <button 
                    type="button" 
                    onClick={() => handleAddItemRow(true)}
                    style={{ background: '#ecfdf5', color: '#059669', border: '1px solid #a7f3d0', padding: '4px 8px', borderRadius: '4px', fontSize: '12px', fontWeight: 600, cursor: 'pointer' }}
                  >
                    + Add Product
                  </button>
                </div>
                
                <div style={{ display: 'flex', flexDirection: 'column', gap: '10px' }}>
                  {editSubItems.map((item, idx) => (
                    <div key={idx} style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
                      <select 
                        className="form-control"
                        value={item.product_id}
                        onChange={e => handleItemChange(idx, 'product_id', e.target.value, true)}
                        style={{ flex: 1 }}
                        required
                      >
                        <option value="">-- Choose Product --</option>
                        {productsData?.map(p => (
                          <option key={p.id} value={p.id}>{p.name} - ₹{p.price}</option>
                        ))}
                      </select>
                      
                      <input 
                        type="number" 
                        min="1"
                        className="form-control"
                        value={item.quantity}
                        onChange={e => handleItemChange(idx, 'quantity', parseInt(e.target.value) || 1, true)}
                        style={{ width: '80px' }}
                        required
                      />

                      <button 
                        type="button"
                        onClick={() => handleRemoveItemRow(idx, true)}
                        disabled={editSubItems.length === 1}
                        style={{ background: '#fee2e2', border: 'none', padding: '8px', borderRadius: '6px', cursor: 'pointer', display: 'flex', alignItems: 'center' }}
                      >
                        <Trash2 size={16} style={{ color: '#dc2626' }} />
                      </button>
                    </div>
                  ))}
                </div>
              </div>

              {/* Preferences */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                <div>
                  <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569', marginBottom: '6px', display: 'block' }}>Delivery Time Slot</label>
                  <select 
                    className="form-control"
                    value={editSubTime}
                    onChange={e => setEditSubTime(e.target.value)}
                  >
                    <option value="Morning (6:00 AM - 8:00 AM)">Morning (6-8 AM)</option>
                    <option value="Noon (12:00 PM - 2:00 PM)">Noon (12-2 PM)</option>
                    <option value="Evening (6:00 PM - 8:00 PM)">Evening (6-8 PM)</option>
                  </select>
                </div>
                <div style={{ display: 'flex', alignItems: 'center', gap: '8px', paddingTop: '28px' }}>
                  <input 
                    type="checkbox" 
                    id="autoRenewEdit"
                    checked={editSubAutoRenew}
                    onChange={e => setEditSubAutoRenew(e.target.checked)}
                    style={{ width: '18px', height: '18px' }}
                  />
                  <label htmlFor="autoRenewEdit" style={{ fontSize: '13px', fontWeight: 600, color: '#475569', cursor: 'pointer' }}>Auto Renew</label>
                </div>
              </div>

              {/* Notes */}
              <div>
                <label style={{ fontSize: '13px', fontWeight: 600, color: '#475569', marginBottom: '6px', display: 'block' }}>Notes</label>
                <textarea 
                  className="form-control" 
                  rows="2"
                  value={editSubNotes}
                  onChange={e => setEditSubNotes(e.target.value)}
                  style={{ resize: 'none' }}
                />
              </div>

              {/* Price Preview */}
              <div style={{ background: '#f8fafc', padding: '16px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '13px', color: '#64748b', marginBottom: '4px' }}>
                  <span>Price Per Delivery:</span>
                  <span style={{ fontWeight: 600, color: '#334155' }}>₹{editTotalInfo.pricePerDelivery.toFixed(2)}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px', fontWeight: 700, color: '#0f172a' }}>
                  <span>Estimated Total:</span>
                  <span>₹{editTotalInfo.total.toFixed(2)}</span>
                </div>
              </div>

              {/* Actions */}
              <div style={{ display: 'flex', gap: '12px', justifyContent: 'flex-end', marginTop: '12px' }}>
                <button type="button" className="btn btn-outline" onClick={() => setShowEditModal(false)}>Cancel</button>
                <button 
                  type="submit" 
                  className="btn btn-primary"
                  disabled={updateMut.isPending}
                  style={{ background: 'linear-gradient(135deg, #10b981 0%, #059669 100%)', border: 'none', color: '#fff' }}
                >
                  {updateMut.isPending ? 'Saving...' : 'Update Subscription'}
                </button>
              </div>

            </form>
          </div>
        </div>
      )}

      {/* PAUSE SUBSCRIPTION MODAL */}
      {showPauseModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(4px)',
          display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 1000
        }}>
          <div style={{ width: '400px', background: '#fff', borderRadius: '10px', padding: '24px', boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)' }}>
            <h3 style={{ margin: '0 0 16px', fontSize: '18px', fontWeight: 700 }}>Pause Subscription</h3>
            <label style={{ display: 'block', fontSize: '13px', color: '#475569', marginBottom: '8px' }}>Reason for pausing</label>
            <input 
              className="form-control" 
              placeholder="E.g., Customer on vacation..."
              value={pauseReason} 
              onChange={e => setPauseReason(e.target.value)} 
              style={{ marginBottom: '20px' }}
            />
            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button className="btn btn-outline" onClick={() => setShowPauseModal(false)}>Cancel</button>
              <button 
                className="btn btn-primary" 
                style={{ background: '#d97706', border: 'none', color: '#fff' }}
                onClick={() => pauseMut.mutate({ id: selectedSubId, reason: pauseReason })}
                disabled={pauseMut.isPending}
              >
                {pauseMut.isPending ? 'Pausing...' : 'Confirm Pause'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* CANCEL SUBSCRIPTION MODAL */}
      {showCancelModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(4px)',
          display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 1000
        }}>
          <div style={{ width: '400px', background: '#fff', borderRadius: '10px', padding: '24px', boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)' }}>
            <h3 style={{ margin: '0 0 16px', fontSize: '18px', fontWeight: 700, color: '#dc2626' }}>Cancel Subscription</h3>
            <label style={{ display: 'block', fontSize: '13px', color: '#475569', marginBottom: '8px' }}>Cancellation Reason *</label>
            <input 
              className="form-control" 
              placeholder="Reason is required..."
              value={cancelReason} 
              onChange={e => setCancelReason(e.target.value)} 
              style={{ marginBottom: '20px' }}
              required
            />
            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button className="btn btn-outline" onClick={() => setShowCancelModal(false)}>Cancel</button>
              <button 
                className="btn" 
                style={{ background: '#dc2626', border: 'none', color: '#fff', padding: '8px 16px', borderRadius: '6px', fontWeight: 600, cursor: 'pointer' }}
                onClick={() => {
                  if (!cancelReason.trim()) { toast.error('Reason is required'); return; }
                  cancelMut.mutate({ id: selectedSubId, reason: cancelReason });
                }}
                disabled={cancelMut.isPending}
              >
                {cancelMut.isPending ? 'Cancelling...' : 'Confirm Cancellation'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* RENEW SUBSCRIPTION MODAL */}
      {showRenewModal && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(4px)',
          display: 'flex', justifyContent: 'center', alignItems: 'center', zIndex: 1000
        }}>
          <div style={{ width: '420px', background: '#fff', borderRadius: '10px', padding: '24px', boxShadow: '0 20px 25px -5px rgba(0,0,0,0.1)' }}>
            <h3 style={{ margin: '0 0 16px', fontSize: '18px', fontWeight: 700 }}>Renew Subscription</h3>
            
            <div style={{ marginBottom: '16px' }}>
              <label style={{ display: 'block', fontSize: '13px', color: '#475569', marginBottom: '6px' }}>Plan Duration</label>
              <select 
                className="form-control" 
                value={renewPlanId} 
                onChange={e => setRenewPlanId(e.target.value)}
              >
                {plans.map(p => (
                  <option key={p.id} value={p.id}>{p.name} ({p.total_deliveries} Deliveries)</option>
                ))}
              </select>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '20px' }}>
              <input 
                type="checkbox" 
                id="renewAutoRenew"
                checked={renewAutoRenew}
                onChange={e => setRenewAutoRenew(e.target.checked)}
                style={{ width: '18px', height: '18px' }}
              />
              <label htmlFor="renewAutoRenew" style={{ fontSize: '13px', fontWeight: 600, color: '#475569', cursor: 'pointer' }}>Auto Renew</label>
            </div>

            <div style={{ display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
              <button className="btn btn-outline" onClick={() => setShowRenewModal(false)}>Cancel</button>
              <button 
                className="btn btn-primary" 
                style={{ background: '#2563eb', border: 'none', color: '#fff' }}
                onClick={() => renewMut.mutate({ id: selectedSubId, params: { new_plan_id: renewPlanId, auto_renew: renewAutoRenew } })}
                disabled={renewMut.isPending}
              >
                {renewMut.isPending ? 'Renewing...' : 'Confirm Renewal'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* SUBSCRIPTION DETAILS DRAWER */}
      {selectedSubId && (
        <div 
          style={{
            position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
            background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(4px)',
            display: 'flex', justifyContent: 'flex-end', zIndex: 900
          }}
          onClick={() => setSelectedSubId(null)}
        >
          <div 
            style={{
              width: '100%', maxWidth: '750px', background: '#fff', height: '100%',
              boxShadow: '-4px 0 24px rgba(0,0,0,0.15)', display: 'flex', flexDirection: 'column',
              overflow: 'hidden'
            }}
            onClick={e => e.stopPropagation()}
          >
            {/* Drawer Header */}
            <div style={{ padding: '20px 24px', borderBottom: '1px solid #e2e8f0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <h2 style={{ fontSize: '18px', fontWeight: 800, color: '#0f172a', margin: 0 }}>
                  Subscription Detail
                </h2>
                <span style={{ fontSize: '11px', fontFamily: 'monospace', color: '#64748b' }}>ID: {selectedSubId}</span>
              </div>
              <div style={{ display: 'flex', gap: '8px', alignItems: 'center' }}>
                {subDetail && (
                  <button 
                    onClick={() => setShowEditModal(true)}
                    style={{ background: '#f1f5f9', border: 'none', padding: '6px 12px', borderRadius: '6px', cursor: 'pointer', fontWeight: 600, fontSize: '13px', color: '#475569', display: 'flex', alignItems: 'center', gap: '4px' }}
                  >
                    <Edit2 size={13} /> Edit
                  </button>
                )}
                <button onClick={() => setSelectedSubId(null)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#64748b' }}>
                  <X size={20} />
                </button>
              </div>
            </div>

            {/* Content Body */}
            {isDetailLoading ? (
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '80px 0', color: '#94a3b8', flex: 1 }}>
                <RefreshCw className="spinner" style={{ color: '#10b981', width: '24px', height: '24px', marginBottom: '12px' }} />
                <p>Loading subscription breakdown...</p>
              </div>
            ) : !subDetail ? (
              <div style={{ textAlign: 'center', padding: '48px', color: '#94a3b8', flex: 1 }}>Failed to load subscription detail</div>
            ) : (
              <div style={{ flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
                {/* Meta details header card */}
                <div style={{ padding: '20px 24px', background: '#f8fafc', borderBottom: '1px solid #e2e8f0', display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: '16px' }}>
                  <div>
                    <span style={{ fontSize: '11px', color: '#94a3b8', textTransform: 'uppercase', fontWeight: 600 }}>Customer</span>
                    <div style={{ fontSize: '14px', fontWeight: 600, color: '#1e293b', marginTop: '2px' }}>{subDetail.customer_name || '—'}</div>
                  </div>
                  <div>
                    <span style={{ fontSize: '11px', color: '#94a3b8', textTransform: 'uppercase', fontWeight: 600 }}>Plan</span>
                    <div style={{ fontSize: '14px', fontWeight: 600, color: '#1e293b', marginTop: '2px', textTransform: 'capitalize' }}>{subDetail.plan_name || '—'}</div>
                  </div>
                  <div>
                    <span style={{ fontSize: '11px', color: '#94a3b8', textTransform: 'uppercase', fontWeight: 600 }}>Status</span>
                    <div style={{ marginTop: '2px' }}>
                      <span style={{
                        background: STATUS_STYLES[subDetail.status]?.bg || '#f1f5f9',
                        color: STATUS_STYLES[subDetail.status]?.color || '#64748b',
                        padding: '2px 8px', borderRadius: '4px', fontSize: '11px', fontWeight: 700
                      }}>{subDetail.status?.replace('_', ' ').toUpperCase()}</span>
                    </div>
                  </div>
                </div>

                {/* Tab Navigation */}
                <div style={{ display: 'flex', background: '#fff', borderBottom: '1px solid #e2e8f0', padding: '0 24px' }}>
                  {[
                    { id: 'items', label: 'Items Breakdown', icon: <Info size={14} /> },
                    { id: 'schedule', label: 'Delivery Calendar', icon: <Clock size={14} /> },
                    { id: 'history', label: 'Timeline & Logs', icon: <Activity size={14} /> }
                  ].map(t => (
                    <button 
                      key={t.id} 
                      onClick={() => setDetailTab(t.id)} 
                      style={{
                        display: 'flex', alignItems: 'center', gap: '6px', padding: '14px 16px',
                        background: 'none', border: 'none', cursor: 'pointer', fontSize: '13px',
                        fontWeight: 600, color: detailTab === t.id ? '#10b981' : '#64748b',
                        borderBottom: detailTab === t.id ? '2px solid #10b981' : '2px solid transparent',
                        transition: 'all 0.2s'
                      }}
                    >
                      {t.icon}
                      {t.label}
                    </button>
                  ))}
                </div>

                {/* Sub Tab contents */}
                <div style={{ flex: 1, overflowY: 'auto', padding: '24px' }}>
                  
                  {/* ITEMS TAB */}
                  {detailTab === 'items' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '20px' }}>
                      {/* Products card list */}
                      <div className="card" style={{ padding: 0, borderRadius: '8px', border: '1px solid #e2e8f0', overflow: 'hidden' }}>
                        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px', textAlign: 'left' }}>
                          <thead>
                            <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0' }}>
                              <th style={{ padding: '10px 16px', fontWeight: 600, color: '#64748b' }}>Product</th>
                              <th style={{ padding: '10px 16px', fontWeight: 600, color: '#64748b', textAlign: 'center' }}>Quantity</th>
                              <th style={{ padding: '10px 16px', fontWeight: 600, color: '#64748b', textAlign: 'right' }}>Price per day</th>
                            </tr>
                          </thead>
                          <tbody>
                            {subDetail.items.map(item => (
                              <tr key={item.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                                <td style={{ padding: '10px 16px', fontWeight: 500 }}>{item.product_name}</td>
                                <td style={{ padding: '10px 16px', textAlign: 'center', fontWeight: 600 }}>{item.quantity}</td>
                                <td style={{ padding: '10px 16px', textAlign: 'right', fontWeight: 600 }}>₹{item.price_per_delivery}</td>
                              </tr>
                            ))}
                          </tbody>
                        </table>
                      </div>

                      {/* Pricing Snapshot Breakdown */}
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '8px', background: '#f8fafc', padding: '16px', borderRadius: '8px', border: '1px solid #e2e8f0', fontSize: '13px' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <span style={{ color: '#64748b' }}>Combined Day Price:</span>
                          <span style={{ fontWeight: 600, color: '#334155' }}>₹{subDetail.price_per_delivery}</span>
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <span style={{ color: '#64748b' }}>Delivery Charge:</span>
                          <span style={{ fontWeight: 600, color: '#334155' }}>₹{subDetail.delivery_charge}</span>
                        </div>
                        <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                          <span style={{ color: '#64748b' }}>Tax/VAT:</span>
                          <span style={{ fontWeight: 600, color: '#334155' }}>₹{subDetail.tax_amount}</span>
                        </div>
                        <hr style={{ border: 'none', borderTop: '1px solid #e2e8f0', margin: '8px 0' }} />
                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '14px', fontWeight: 700 }}>
                          <span>Total Amount:</span>
                          <span style={{ color: '#10b981' }}>₹{subDetail.total_amount}</span>
                        </div>
                      </div>

                      {/* Settings Details */}
                      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px', fontSize: '13px' }}>
                        <div style={{ background: '#fff', border: '1px solid #e2e8f0', padding: '12px', borderRadius: '8px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#64748b', marginBottom: '4px', fontWeight: 600 }}>
                            <Clock size={14} /> Time Preferences
                          </div>
                          <div style={{ fontWeight: 600, color: '#334155' }}>{subDetail.preferred_delivery_time || 'None'}</div>
                        </div>
                        <div style={{ background: '#fff', border: '1px solid #e2e8f0', padding: '12px', borderRadius: '8px' }}>
                          <div style={{ display: 'flex', alignItems: 'center', gap: '6px', color: '#64748b', marginBottom: '4px', fontWeight: 600 }}>
                            <Calendar size={14} /> Auto Renewal
                          </div>
                          <div style={{ fontWeight: 600, color: subDetail.auto_renew ? '#10b981' : '#ef4444' }}>
                            {subDetail.auto_renew ? 'Enabled' : 'Disabled'}
                          </div>
                        </div>
                      </div>

                      {/* Notes Card */}
                      {subDetail.notes && (
                        <div style={{ background: '#fffbeb', border: '1px solid #fef3c7', padding: '14px', borderRadius: '8px', fontSize: '13px' }}>
                          <div style={{ fontWeight: 700, color: '#b45309', marginBottom: '4px' }}>Admin/Customer Notes</div>
                          <p style={{ color: '#78350f', margin: 0 }}>{subDetail.notes}</p>
                        </div>
                      )}
                    </div>
                  )}

                  {/* SCHEDULE CALENDAR TAB */}
                  {detailTab === 'schedule' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                      <div style={{ fontSize: '13px', color: '#64748b' }}>
                        Progress: <strong>{subDetail.completed_deliveries}</strong> completed of <strong>{subDetail.total_deliveries}</strong> total deliveries
                      </div>
                      
                      <div className="table-container" style={{ border: '1px solid #e2e8f0', borderRadius: '8px', overflow: 'hidden' }}>
                        <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px', textAlign: 'left' }}>
                          <thead>
                            <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0' }}>
                              <th style={{ padding: '10px 16px', fontWeight: 600, color: '#64748b' }}>Scheduled Date</th>
                              <th style={{ padding: '10px 16px', fontWeight: 600, color: '#64748b' }}>Status</th>
                              <th style={{ padding: '10px 16px', fontWeight: 600, color: '#64748b', textAlign: 'right' }}>Actions</th>
                            </tr>
                          </thead>
                          <tbody>
                            {deliveries.length === 0 ? (
                              <tr>
                                <td colSpan={3} style={{ textAlign: 'center', padding: '24px', color: '#94a3b8' }}>Loading schedule...</td>
                              </tr>
                            ) : (
                              deliveries.map(d => {
                                const st = DELIVERY_STATUS_STYLES[d.status] || DELIVERY_STATUS_STYLES.pending;
                                const isActionable = d.status === 'pending' || d.status === 'assigned' || d.status === 'carry_forward';
                                return (
                                  <tr key={d.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                                    <td style={{ padding: '10px 16px', fontWeight: 500 }}>
                                      {new Date(d.scheduled_date).toLocaleDateString('en-IN', { weekday: 'short', day: 'numeric', month: 'short' })}
                                    </td>
                                    <td style={{ padding: '10px 16px' }}>
                                      <span style={{ background: st.bg, color: st.color, padding: '2px 8px', borderRadius: '4px', fontSize: '11px', fontWeight: 600 }}>
                                        {st.label}
                                      </span>
                                    </td>
                                    <td style={{ padding: '10px 16px', textAlign: 'right' }}>
                                      {isActionable && (
                                        <button 
                                          className="btn" 
                                          style={{ background: '#fee2e2', border: 'none', color: '#dc2626', padding: '3px 8px', borderRadius: '4px', fontSize: '11px', fontWeight: 600, cursor: 'pointer' }}
                                          onClick={() => {
                                            if (window.confirm('Skip this day? Deliveries will slide by 1 day.')) {
                                              skipMut.mutate(d.id);
                                            }
                                          }}
                                          disabled={skipMut.isPending}
                                        >
                                          Skip Day
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

                  {/* HISTORY LOGS TIMELINES TAB */}
                  {detailTab === 'history' && (
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '28px', fontSize: '13px' }}>
                      
                      {/* Status timeline */}
                      <div>
                        <h4 style={{ fontSize: '14px', fontWeight: 700, color: '#0f172a', margin: '0 0 12px' }}>Status Audit Trail</h4>
                        {subDetail.status_history?.length === 0 ? (
                          <div style={{ color: '#94a3b8' }}>No logs yet</div>
                        ) : (
                          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', borderLeft: '2px solid #e2e8f0', paddingLeft: '16px', marginLeft: '8px' }}>
                            {subDetail.status_history.map(h => (
                              <div key={h.id} style={{ position: 'relative' }}>
                                <div style={{
                                  position: 'absolute', left: '-22px', top: '2px', width: '10px', height: '10px',
                                  borderRadius: '50%', background: '#10b981', border: '2px solid #fff'
                                }} />
                                <div style={{ fontWeight: 600, color: '#334155' }}>
                                  Changed status from <span style={{ textTransform: 'capitalize' }}>{h.old_status || 'initial'}</span> to <span style={{ color: '#059669', textTransform: 'capitalize' }}>{h.new_status}</span>
                                </div>
                                <div style={{ fontSize: '11px', color: '#64748b', marginTop: '2px' }}>
                                  {new Date(h.changed_at).toLocaleString('en-IN')} {h.reason && `• Reason: ${h.reason}`}
                                </div>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>

                      {/* Pause history logs */}
                      <div>
                        <h4 style={{ fontSize: '14px', fontWeight: 700, color: '#0f172a', margin: '0 0 12px' }}>Pause/Resume Timeline</h4>
                        {subDetail.pause_history?.length === 0 ? (
                          <div style={{ color: '#94a3b8' }}>No pause history recorded</div>
                        ) : (
                          <div className="table-container" style={{ border: '1px solid #e2e8f0', borderRadius: '8px', overflow: 'hidden' }}>
                            <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                              <thead>
                                <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0' }}>
                                  <th style={{ padding: '8px 12px', fontWeight: 600, color: '#64748b' }}>Paused At</th>
                                  <th style={{ padding: '8px 12px', fontWeight: 600, color: '#64748b' }}>Resumed At</th>
                                  <th style={{ padding: '8px 12px', fontWeight: 600, color: '#64748b' }}>Reason</th>
                                  <th style={{ padding: '8px 12px', fontWeight: 600, color: '#64748b', textAlign: 'right' }}>Days</th>
                                </tr>
                              </thead>
                              <tbody>
                                {subDetail.pause_history.map(p => (
                                  <tr key={p.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                                    <td style={{ padding: '8px 12px' }}>{new Date(p.paused_at).toLocaleDateString('en-IN')}</td>
                                    <td style={{ padding: '8px 12px' }}>{p.resumed_at ? new Date(p.resumed_at).toLocaleDateString('en-IN') : 'Ongoing'}</td>
                                    <td style={{ padding: '8px 12px', color: '#64748b' }}>{p.pause_reason || '—'}</td>
                                    <td style={{ padding: '8px 12px', textAlign: 'right', fontWeight: 600 }}>{p.paused_days}</td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                          </div>
                        )}
                      </div>

                      {/* Payment Logs */}
                      <div>
                        <h4 style={{ fontSize: '14px', fontWeight: 700, color: '#0f172a', margin: '0 0 12px' }}>Payment Status Logs</h4>
                        {subDetail.payment_history?.length === 0 ? (
                          <div style={{ color: '#94a3b8' }}>No payment history recorded</div>
                        ) : (
                          <div className="table-container" style={{ border: '1px solid #e2e8f0', borderRadius: '8px', overflow: 'hidden' }}>
                            <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
                              <thead>
                                <tr style={{ background: '#f8fafc', borderBottom: '1px solid #e2e8f0' }}>
                                  <th style={{ padding: '8px 12px', fontWeight: 600, color: '#64748b' }}>Date</th>
                                  <th style={{ padding: '8px 12px', fontWeight: 600, color: '#64748b' }}>Amount</th>
                                  <th style={{ padding: '8px 12px', fontWeight: 600, color: '#64748b' }}>Status</th>
                                  <th style={{ padding: '8px 12px', fontWeight: 600, color: '#64748b' }}>Ref</th>
                                </tr>
                              </thead>
                              <tbody>
                                {subDetail.payment_history.map(pay => (
                                  <tr key={pay.id} style={{ borderBottom: '1px solid #f1f5f9' }}>
                                    <td style={{ padding: '8px 12px' }}>{new Date(pay.changed_at).toLocaleDateString('en-IN')}</td>
                                    <td style={{ padding: '8px 12px', fontWeight: 700 }}>₹{pay.amount}</td>
                                    <td style={{ padding: '8px 12px' }}>
                                      <span style={{
                                        background: pay.status === 'success' ? '#dcfce7' : '#fee2e2',
                                        color: pay.status === 'success' ? '#16a34a' : '#dc2626',
                                        padding: '2px 6px', borderRadius: '4px', fontSize: '10px', fontWeight: 700
                                      }}>{pay.status.toUpperCase()}</span>
                                    </td>
                                    <td style={{ padding: '8px 12px', fontFamily: 'monospace', fontSize: '11px', color: '#64748b' }}>
                                      {pay.transaction_id || '—'}
                                    </td>
                                  </tr>
                                ))}
                              </tbody>
                            </table>
                          </div>
                        )}
                      </div>

                    </div>
                  )}

                </div>

                {/* Drawer Footer Actions */}
                <div style={{ padding: '16px 24px', borderTop: '1px solid #e2e8f0', background: '#f8fafc', display: 'flex', gap: '10px', justifyContent: 'flex-end' }}>
                  <button className="btn btn-outline" onClick={() => setSelectedSubId(null)}>Close</button>
                  {['active', 'paused', 'pending_payment'].includes(subDetail.status) && (
                    <button 
                      style={{ background: '#fee2e2', border: '1px solid #fca5a5', color: '#dc2626', padding: '8px 16px', borderRadius: '6px', cursor: 'pointer', fontWeight: 600, fontSize: '13px' }}
                      onClick={() => { if (window.confirm('Cancel this subscription?')) cancelMut.mutate({ id: subDetail.id, reason: 'Admin cancelled from details drawer' }); }}
                      disabled={cancelMut.isPending}
                    >
                      Cancel Subscription
                    </button>
                  )}
                  {subDetail.status === 'paused' && (
                    <button 
                      className="btn btn-primary"
                      onClick={() => resumeMut.mutate(subDetail.id)}
                      disabled={resumeMut.isPending}
                    >
                      Resume Subscription
                    </button>
                  )}
                  {subDetail.status === 'active' && (
                    <button 
                      className="btn"
                      style={{ background: '#d97706', color: '#fff', border: 'none', padding: '8px 16px', borderRadius: '6px', cursor: 'pointer', fontWeight: 600, fontSize: '13px' }}
                      onClick={() => setShowPauseModal(true)}
                    >
                      Pause Subscription
                    </button>
                  )}
                </div>
              </div>
            )}
          </div>
        </div>
      )}

    </div>
  );
}
