import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  Truck, Calendar, Search, Filter, Download, Printer, Clock,
  User, MapPin, CheckCircle, AlertTriangle, XCircle, ArrowRight,
  TrendingUp, RefreshCw, BarChart2, ShoppingBag, Phone, Shield, FileSpreadsheet
} from 'lucide-react';
import {
  getAdminDeliveries,
  getAdminDeliveryById,
  assignAdminDelivery,
  updateAdminDeliveryStatus,
  getAdminDeliveriesAnalytics,
  exportAdminDeliveries,
  getDeliveryPartners
} from '../api/deliveriesApi';
import toast from 'react-hot-toast';

const STATUS_CONFIG = {
  pending: { label: 'Pending', bg: '#fef3c7', color: '#d97706', icon: Clock },
  assigned: { label: 'Assigned', bg: '#e0f2fe', color: '#0369a1', icon: User },
  picked_up: { label: 'Picked Up', bg: '#f3e8ff', color: '#7c3aed', icon: ShoppingBag },
  out_for_delivery: { label: 'Out for Delivery', bg: '#e0e7ff', color: '#4338ca', icon: Truck },
  delivered: { label: 'Delivered', bg: '#dcfce7', color: '#16a34a', icon: CheckCircle },
  missed: { label: 'Failed', bg: '#fee2e2', color: '#b91c1c', icon: AlertTriangle },
  skipped: { label: 'Cancelled', bg: '#f1f5f9', color: '#475569', icon: XCircle },
  carry_forward: { label: 'Carry Forward', bg: '#f3e8ff', color: '#7c3aed', icon: ArrowRight },
};

const getTodayString = () => {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
};

export default function Deliveries() {
  const queryClient = useQueryClient();

  // Filters State
  const [selectedDate, setSelectedDate] = useState(getTodayString());
  const [search, setSearch] = useState('');
  const [statusFilter, setStatusFilter] = useState('');
  const [partnerFilter, setPartnerFilter] = useState('');
  
  // Modal State
  const [detailId, setDetailId] = useState(null);

  // Queries
  const { data: deliveries = [], isLoading: isListLoading } = useQuery({
    queryKey: ['admin-deliveries', selectedDate, search, statusFilter, partnerFilter],
    queryFn: async () => {
      const params = { selected_date: selectedDate };
      if (search) params.search = search;
      if (statusFilter) params.status = statusFilter;
      if (partnerFilter) params.delivery_partner_id = partnerFilter;
      
      const { data } = await getAdminDeliveries(params);
      return data || [];
    }
  });

  const { data: analytics, isLoading: isAnalyticsLoading } = useQuery({
    queryKey: ['admin-deliveries-analytics', selectedDate],
    queryFn: async () => {
      const { data } = await getAdminDeliveriesAnalytics({ selected_date: selectedDate });
      return data;
    }
  });

  const { data: partners = [] } = useQuery({
    queryKey: ['delivery-partners-list'],
    queryFn: async () => {
      const { data } = await getDeliveryPartners();
      return data || [];
    }
  });

  const { data: activeDetail, isLoading: isDetailLoading } = useQuery({
    queryKey: ['admin-delivery-detail', detailId],
    queryFn: async () => {
      if (!detailId) return null;
      const { data } = await getAdminDeliveryById(detailId);
      return data;
    },
    enabled: !!detailId
  });

  // Mutations
  const assignMutation = useMutation({
    mutationFn: ({ id, partnerId }) => assignAdminDelivery(id, partnerId),
    onSuccess: (data) => {
      toast.success(data.message || 'Delivery assigned successfully!');
      queryClient.invalidateQueries(['admin-deliveries']);
      queryClient.invalidateQueries(['admin-delivery-detail', detailId]);
      queryClient.invalidateQueries(['admin-deliveries-analytics']);
    },
    onError: (err) => {
      toast.error(err.response?.data?.detail || 'Assignment failed');
    }
  });

  const statusMutation = useMutation({
    mutationFn: ({ id, status, failureReason }) => updateAdminDeliveryStatus(id, { status, failure_reason: failureReason }),
    onSuccess: (data) => {
      toast.success(data.message || 'Status updated successfully!');
      queryClient.invalidateQueries(['admin-deliveries']);
      queryClient.invalidateQueries(['admin-delivery-detail', detailId]);
      queryClient.invalidateQueries(['admin-deliveries-analytics']);
    },
    onError: (err) => {
      toast.error(err.response?.data?.detail || 'Status update failed');
    }
  });

  // Helpers
  const handleExport = async (format) => {
    try {
      const params = { selected_date: selectedDate };
      if (search) params.search = search;
      if (statusFilter) params.status = statusFilter;
      if (partnerFilter) params.delivery_partner_id = partnerFilter;
      params.format = format;

      toast.loading(`Preparing ${format.toUpperCase()} export...`, { id: 'export-toast' });
      const response = await exportAdminDeliveries(params);
      
      const blob = new Blob([response.data], {
        type: format === 'excel'
          ? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          : 'text/csv'
      });
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.setAttribute('download', `Deliveries_${selectedDate}.${format === 'excel' ? 'xlsx' : 'csv'}`);
      document.body.appendChild(link);
      link.click();
      link.remove();
      
      toast.success('Export downloaded!', { id: 'export-toast' });
    } catch (e) {
      toast.error('Export failed', { id: 'export-toast' });
    }
  };

  const handlePrint = () => {
    const printContent = document.getElementById('deliveries-table-print-area').innerHTML;
    const printWindow = window.open('', '_blank');
    printWindow.document.write(`
      <html>
        <head>
          <title>Deliveries Report - ${selectedDate}</title>
          <style>
            body { font-family: sans-serif; padding: 20px; }
            h1 { font-size: 20px; margin-bottom: 5px; }
            h2 { font-size: 14px; color: #555; margin-bottom: 20px; }
            table { width: 100%; border-collapse: collapse; }
            th, td { border: 1px solid #ddd; padding: 8px; text-align: left; font-size: 12px; }
            th { background-color: #f2f2f2; }
          </style>
        </head>
        <body onload="window.print();window.close()">
          <h1>Healthy Home Foods — Delivery Report</h1>
          <h2>Date: ${selectedDate} | Total Deliveries: ${deliveries.length}</h2>
          ${printContent}
        </body>
      </html>
    `);
    printWindow.document.close();
  };

  return (
    <div className="dashboard animate-fade-in" style={{ paddingBottom: '40px' }}>
      
      {/* Header section */}
      <div className="dashboard-header">
        <div>
          <h1 className="page-title" style={{ fontSize: '28px', display: 'flex', alignItems: 'center', gap: '10px' }}>
            <Truck size={32} style={{ color: 'var(--primary-600)' }} /> Admin Delivery Dashboard
          </h1>
          <p className="text-gray">Real-time scheduling, partner routing, and status lifecycle management.</p>
        </div>
        <div className="dashboard-actions">
          <button className="btn btn-outline" style={{ background: '#fff' }} onClick={() => {
            queryClient.invalidateQueries(['admin-deliveries']);
            queryClient.invalidateQueries(['admin-deliveries-analytics']);
            toast.success('Data refreshed!');
          }}>
            <RefreshCw size={16} /> Refresh
          </button>
          <button className="btn btn-outline" style={{ background: '#fff' }} onClick={() => handleExport('csv')}>
            <Download size={16} /> Export CSV
          </button>
          <button className="btn btn-outline" style={{ background: '#fff' }} onClick={() => handleExport('excel')}>
            <FileSpreadsheet size={16} /> Export Excel
          </button>
          <button className="btn btn-primary" onClick={handlePrint}>
            <Printer size={16} /> Print Report
          </button>
        </div>
      </div>

      {/* Analytics Cards section */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: '16px' }}>
        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '16px 20px' }}>
          <div style={{ background: '#ecfdf5', color: '#059669', borderRadius: '12px', padding: '12px' }}>
            <TrendingUp size={24} />
          </div>
          <div>
            <p style={{ fontSize: '13px', color: '#64748b', margin: 0 }}>Delivery Success Rate</p>
            <h3 style={{ fontSize: '22px', fontWeight: 700, margin: 0 }}>
              {isAnalyticsLoading ? '...' : `${analytics?.success_rate || 0}%`}
            </h3>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '16px 20px' }}>
          <div style={{ background: '#eff6ff', color: '#2563eb', borderRadius: '12px', padding: '12px' }}>
            <Clock size={24} />
          </div>
          <div>
            <p style={{ fontSize: '13px', color: '#64748b', margin: 0 }}>Average Delivery Time</p>
            <h3 style={{ fontSize: '22px', fontWeight: 700, margin: 0 }}>
              {isAnalyticsLoading ? '...' : `${analytics?.average_delivery_time || 0} mins`}
            </h3>
          </div>
        </div>

        <div className="card" style={{ display: 'flex', alignItems: 'center', gap: '16px', padding: '16px 20px' }}>
          <div style={{ background: '#faf5ff', color: '#7c3aed', borderRadius: '12px', padding: '12px' }}>
            <User size={24} />
          </div>
          <div>
            <p style={{ fontSize: '13px', color: '#64748b', margin: 0 }}>Top Performing Partner</p>
            <h3 style={{ fontSize: '18px', fontWeight: 700, margin: 0, textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap', maxWidth: '180px' }} title={analytics?.top_partner_name}>
              {isAnalyticsLoading ? '...' : (analytics?.top_partner_name || 'N/A')}
            </h3>
          </div>
        </div>
      </div>

      {/* Summary Status Filters */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(130px, 1fr))', gap: '12px' }}>
        {[
          { label: 'Total', count: analytics?.total_deliveries || 0, value: '', color: '#475569', bg: '#f1f5f9' },
          { label: 'Pending', count: analytics?.pending || 0, value: 'pending', color: '#d97706', bg: '#fef3c7' },
          { label: 'Assigned', count: analytics?.assigned || 0, value: 'assigned', color: '#0369a1', bg: '#e0f2fe' },
          { label: 'Out For Delivery', count: analytics?.out_for_delivery || 0, value: 'out_for_delivery', color: '#4338ca', bg: '#e0e7ff' },
          { label: 'Delivered', count: analytics?.delivered || 0, value: 'delivered', color: '#16a34a', bg: '#dcfce7' },
          { label: 'Failed', count: analytics?.failed || 0, value: 'failed', color: '#b91c1c', bg: '#fee2e2' },
          { label: 'Cancelled', count: analytics?.cancelled || 0, value: 'cancelled', color: '#64748b', bg: '#f1f5f9' }
        ].map((card) => {
          const isActive = statusFilter === card.value;
          return (
            <div
              key={card.label}
              onClick={() => setStatusFilter(card.value)}
              className="glass-panel"
              style={{
                padding: '12px',
                textAlign: 'center',
                cursor: 'pointer',
                border: isActive ? `2px solid ${card.color}` : '1px solid var(--glass-border)',
                background: isActive ? card.bg : 'var(--bg-surface)',
                transform: isActive ? 'scale(1.02)' : 'none',
                transition: 'all 0.2s ease',
              }}
            >
              <p style={{ fontSize: '12px', color: '#64748b', margin: '0 0 4px', fontWeight: 500 }}>{card.label}</p>
              <h4 style={{ fontSize: '20px', fontWeight: 700, color: card.color, margin: 0 }}>
                {isAnalyticsLoading ? '...' : card.count}
              </h4>
            </div>
          );
        })}
      </div>

      {/* Filter and search panel */}
      <div className="card" style={{ padding: '16px', display: 'flex', flexWrap: 'wrap', gap: '12px', alignItems: 'center' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', background: '#f8fafc', border: '1px solid #cbd5e1', borderRadius: '8px', padding: '6px 12px', flex: 1, minWidth: '220px' }}>
          <Search size={18} style={{ color: '#94a3b8' }} />
          <input
            type="text"
            placeholder="Search Order ID, Customer, Partner..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            style={{ border: 'none', background: 'transparent', outline: 'none', width: '100%', fontSize: '13px' }}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: '150px' }}>
          <Calendar size={18} style={{ color: '#64748b' }} />
          <input
            type="date"
            className="form-control"
            style={{ padding: '6px 10px', fontSize: '13px' }}
            value={selectedDate}
            onChange={(e) => setSelectedDate(e.target.value || getTodayString())}
          />
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: '160px' }}>
          <Filter size={18} style={{ color: '#64748b' }} />
          <select
            className="form-control"
            style={{ padding: '6px 10px', fontSize: '13px' }}
            value={partnerFilter}
            onChange={(e) => setPartnerFilter(e.target.value)}
          >
            <option value="">All Partners</option>
            {partners.map(p => (
              <option key={p.id} value={p.id}>{p.full_name}</option>
            ))}
          </select>
        </div>

        <div style={{ display: 'flex', alignItems: 'center', gap: '8px', minWidth: '150px' }}>
          <select
            className="form-control"
            style={{ padding: '6px 10px', fontSize: '13px' }}
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value)}
          >
            <option value="">All Statuses</option>
            <option value="pending">Pending</option>
            <option value="assigned">Assigned</option>
            <option value="out_for_delivery">Out for Delivery</option>
            <option value="delivered">Delivered</option>
            <option value="failed">Failed / Missed</option>
            <option value="cancelled">Cancelled / Skipped</option>
          </select>
        </div>
      </div>

      {/* Deliveries Table */}
      <div className="table-container shadow-sm">
        <div id="deliveries-table-print-area">
          <table className="table">
            <thead>
              <tr>
                <th style={{ width: '100px' }}>Order ID</th>
                <th>Customer</th>
                <th>Delivery Partner</th>
                <th>Address</th>
                <th>Date & Time</th>
                <th>Amount</th>
                <th>Payment</th>
                <th>Status</th>
                <th style={{ textAlign: 'center' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {isListLoading ? (
                <tr>
                  <td colSpan={9} style={{ textAlign: 'center', padding: '40px', color: '#94a3b8' }}>
                    <div className="spinner" style={{ borderTopColor: 'var(--primary-500)', width: 24, height: 24, marginBottom: 8 }} />
                    <p>Loading scheduled deliveries...</p>
                  </td>
                </tr>
              ) : deliveries.length === 0 ? (
                <tr>
                  <td colSpan={9} style={{ textAlign: 'center', padding: '50px', color: '#94a3b8' }}>
                    <p style={{ fontSize: '32px' }}>🚚</p>
                    <p style={{ fontWeight: 500 }}>No deliveries scheduled matching filters</p>
                  </td>
                </tr>
              ) : (
                deliveries.map((d) => {
                  const sc = STATUS_CONFIG[d.status] || STATUS_CONFIG.pending;
                  const StatusIcon = sc.icon;

                  return (
                    <tr key={d.id}>
                      <td style={{ fontWeight: 600, fontSize: '12px', color: 'var(--primary-700)' }}>
                        #{d.subscription_id.substring(0, 8)}
                      </td>
                      <td>
                        <div style={{ display: 'flex', flexDirection: 'column' }}>
                          <span style={{ fontWeight: 500 }}>{d.customer_name}</span>
                          <span style={{ fontSize: '11px', color: '#64748b' }}>{d.phone}</span>
                        </div>
                      </td>
                      <td>
                        <select
                          className="form-control"
                          style={{
                            padding: '4px 8px',
                            fontSize: '12px',
                            width: '150px',
                            borderColor: d.delivery_partner_id ? '#cbd5e1' : '#f59e0b',
                            background: d.delivery_partner_id ? '#fff' : '#fef3c7'
                          }}
                          value={d.delivery_partner_id || ''}
                          onChange={(e) => {
                            if (e.target.value) {
                              assignMutation.mutate({ id: d.id, partnerId: e.target.value });
                            }
                          }}
                        >
                          <option value="">Select Partner...</option>
                          {partners.map(p => (
                            <option key={p.id} value={p.id}>{p.full_name}</option>
                          ))}
                        </select>
                      </td>
                      <td style={{ maxWidth: '200px', textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }} title={d.delivery_address}>
                        {d.delivery_address}
                      </td>
                      <td>
                        <div style={{ display: 'flex', flexDirection: 'column' }}>
                          <span style={{ fontSize: '12px' }}>{new Date(d.scheduled_date).toLocaleDateString('en-IN')}</span>
                          <span style={{ fontSize: '11px', color: '#64748b' }}>⏰ {d.delivery_time || 'No Preference'}</span>
                        </div>
                      </td>
                      <td style={{ fontWeight: 600 }}>₹{d.amount.toFixed(2)}</td>
                      <td>
                        <span style={{
                          color: d.payment_status === 'Paid' ? '#16a34a' : '#dc2626',
                          fontWeight: 600,
                          fontSize: '12px'
                        }}>
                          {d.payment_status}
                        </span>
                      </td>
                      <td>
                        <span style={{
                          background: sc.bg,
                          color: sc.color,
                          padding: '3px 10px',
                          borderRadius: '999px',
                          fontSize: '11px',
                          fontWeight: 600,
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: '4px'
                        }}>
                          <StatusIcon size={12} /> {sc.label}
                        </span>
                      </td>
                      <td style={{ textAlign: 'center' }}>
                        <button
                          className="btn btn-outline"
                          style={{ padding: '6px 12px', fontSize: '12px' }}
                          onClick={() => setDetailId(d.id)}
                        >
                          View Detail
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>

      {/* Details drawer/modal */}
      {detailId && (
        <div style={{
          position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
          background: 'rgba(15, 23, 42, 0.4)', backdropFilter: 'blur(4px)',
          display: 'flex', justifyContent: 'flex-end', zIndex: 1000,
          animation: 'fadeIn 0.2s ease-out'
        }} onClick={() => setDetailId(null)}>
          
          <div style={{
            width: '600px', height: '100%', background: '#fff',
            boxShadow: '-4px 0 24px rgba(0,0,0,0.15)', display: 'flex',
            flexDirection: 'column', overflow: 'hidden'
          }} onClick={e => e.stopPropagation()}>
            
            {/* Modal Header */}
            <div style={{ padding: '20px', borderBottom: '1px solid #e2e8f0', display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <div>
                <h3 style={{ fontSize: '18px', fontWeight: 700, margin: 0 }}>Delivery Details</h3>
                {activeDetail && (
                  <p style={{ fontSize: '12px', color: '#64748b', margin: '4px 0 0' }}>
                    Order ID: #{activeDetail.subscription_id.substring(0, 8)} | Scheduled: {new Date(activeDetail.scheduled_date).toLocaleDateString('en-IN')}
                  </p>
                )}
              </div>
              <button
                style={{ background: 'none', border: 'none', fontSize: '20px', cursor: 'pointer', color: '#64748b' }}
                onClick={() => setDetailId(null)}
              >
                ✕
              </button>
            </div>

            {/* Modal Body */}
            <div style={{ flex: 1, overflowY: 'auto', padding: '20px', display: 'flex', flexDirection: 'column', gap: '24px' }}>
              {isDetailLoading || !activeDetail ? (
                <div style={{ textAlign: 'center', padding: '40px' }}>
                  <div className="spinner" style={{ borderTopColor: 'var(--primary-500)', width: 32, height: 32 }} />
                </div>
              ) : (
                <>
                  {/* Status update panel */}
                  <div className="card" style={{ padding: '16px', background: '#f8fafc' }}>
                    <h4 style={{ fontSize: '13px', color: '#475569', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '10px' }}>Update Lifecycle Status</h4>
                    <div style={{ display: 'flex', gap: '10px' }}>
                      <select
                        className="form-control"
                        value={activeDetail.status}
                        onChange={(e) => {
                          const newStatus = e.target.value;
                          let failReason = null;
                          if (newStatus === 'failed') {
                            failReason = window.prompt('Please enter the failure reason:');
                            if (failReason === null) return; // cancelled prompt
                          }
                          statusMutation.mutate({ id: activeDetail.id, status: newStatus, failureReason: failReason });
                        }}
                      >
                        <option value="pending">Pending</option>
                        <option value="assigned">Assigned</option>
                        <option value="picked_up">Picked Up</option>
                        <option value="out_for_delivery">Out for Delivery</option>
                        <option value="delivered">Delivered</option>
                        <option value="failed">Failed / Missed</option>
                        <option value="cancelled">Cancelled / Skipped</option>
                      </select>
                    </div>
                  </div>

                  {/* Customer Information */}
                  <div>
                    <h4 style={{ fontSize: '14px', fontWeight: 600, color: '#334155', borderBottom: '1px solid #f1f5f9', paddingBottom: '6px', marginBottom: '8px' }}>
                      👤 Customer Profile
                    </h4>
                    <p style={{ fontSize: '13px', margin: '4px 0' }}><strong>Name:</strong> {activeDetail.customer.full_name}</p>
                    <p style={{ fontSize: '13px', margin: '4px 0' }}><strong>Phone:</strong> {activeDetail.customer.phone}</p>
                    {activeDetail.customer.email && (
                      <p style={{ fontSize: '13px', margin: '4px 0' }}><strong>Email:</strong> {activeDetail.customer.email}</p>
                    )}
                    <p style={{ fontSize: '13px', margin: '4px 0' }}><strong>Code:</strong> {activeDetail.customer.customer_code}</p>
                  </div>

                  {/* Products Table */}
                  <div>
                    <h4 style={{ fontSize: '14px', fontWeight: 600, color: '#334155', borderBottom: '1px solid #f1f5f9', paddingBottom: '6px', marginBottom: '8px' }}>
                      🥗 Ordered Items
                    </h4>
                    <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '12px' }}>
                      <thead>
                        <tr style={{ background: '#f8fafc', borderBottom: '1px solid #cbd5e1' }}>
                          <th style={{ padding: '6px 8px', textAlign: 'left' }}>Product</th>
                          <th style={{ padding: '6px 8px', textAlign: 'center' }}>Qty</th>
                          <th style={{ padding: '6px 8px', textAlign: 'right' }}>Price / Delivery</th>
                        </tr>
                      </thead>
                      <tbody>
                        {activeDetail.products.map((p, idx) => (
                          <tr key={idx} style={{ borderBottom: '1px solid #f1f5f9' }}>
                            <td style={{ padding: '6px 8px' }}>{p.product_name}</td>
                            <td style={{ padding: '6px 8px', textAlign: 'center' }}>{p.quantity}</td>
                            <td style={{ padding: '6px 8px', textAlign: 'right' }}>₹{p.price_per_delivery.toFixed(2)}</td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>

                  {/* Delivery Partner */}
                  <div>
                    <h4 style={{ fontSize: '14px', fontWeight: 600, color: '#334155', borderBottom: '1px solid #f1f5f9', paddingBottom: '6px', marginBottom: '8px' }}>
                      🏍 Delivery Partner Details
                    </h4>
                    {activeDetail.delivery_partner ? (
                      <>
                        <p style={{ fontSize: '13px', margin: '4px 0' }}><strong>Partner:</strong> {activeDetail.delivery_partner.full_name}</p>
                        <p style={{ fontSize: '13px', margin: '4px 0' }}><strong>Phone:</strong> {activeDetail.delivery_partner.phone}</p>
                        <p style={{ fontSize: '13px', margin: '4px 0' }}><strong>Employee Code:</strong> {activeDetail.delivery_partner.employee_code}</p>
                        <p style={{ fontSize: '13px', margin: '4px 0' }}>
                          <strong>Vehicle:</strong> {activeDetail.delivery_partner.vehicle_type?.toUpperCase()} ({activeDetail.delivery_partner.vehicle_number || 'No Number'})
                        </p>
                      </>
                    ) : (
                      <p style={{ fontSize: '13px', color: '#d97706', margin: '4px 0', fontWeight: 500 }}>⚠️ No partner assigned yet.</p>
                    )}
                  </div>

                  {/* Delivery Address */}
                  <div>
                    <h4 style={{ fontSize: '14px', fontWeight: 600, color: '#334155', borderBottom: '1px solid #f1f5f9', paddingBottom: '6px', marginBottom: '8px' }}>
                      📍 Delivery Address
                    </h4>
                    <p style={{ fontSize: '13px', margin: '4px 0' }}>
                      {activeDetail.address.address_line1}
                      {activeDetail.address.address_line2 ? `, ${activeDetail.address.address_line2}` : ''}
                    </p>
                    <p style={{ fontSize: '13px', margin: '4px 0' }}>{activeDetail.address.city}, {activeDetail.address.state} - {activeDetail.address.pincode}</p>
                    {activeDetail.address.landmark && (
                      <p style={{ fontSize: '13px', margin: '4px 0' }}><strong>Landmark:</strong> {activeDetail.address.landmark}</p>
                    )}
                  </div>

                  {/* Delivery Progress Timeline */}
                  <div>
                    <h4 style={{ fontSize: '14px', fontWeight: 600, color: '#334155', borderBottom: '1px solid #f1f5f9', paddingBottom: '6px', marginBottom: '12px' }}>
                      ⏳ Status Progression Timeline
                    </h4>
                    <div style={{ display: 'flex', flexDirection: 'column', gap: '12px', position: 'relative', paddingLeft: '24px' }}>
                      
                      {/* Vertical line connecting steps */}
                      <div style={{
                        position: 'absolute', left: '7px', top: '10px', bottom: '10px',
                        width: '2px', background: '#cbd5e1', zIndex: 0
                      }} />

                      {activeDetail.timeline.map((step, idx) => {
                        return (
                          <div key={idx} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', position: 'relative', zIndex: 1 }}>
                            
                            {/* Bullet circle */}
                            <div style={{
                              position: 'absolute', left: '-22px', top: '5px',
                              width: '12px', height: '12px', borderRadius: '50%',
                              background: step.completed ? 'var(--primary-500)' : '#cbd5e1',
                              boxShadow: step.completed ? '0 0 0 4px var(--primary-100)' : 'none'
                            }} />

                            <div>
                              <span style={{ fontSize: '13px', fontWeight: 500, color: step.completed ? '#0f172a' : '#94a3b8' }}>
                                {step.stage}
                              </span>
                            </div>
                            
                            <div>
                              <span style={{ fontSize: '11px', color: '#64748b' }}>
                                {step.completed && step.timestamp
                                  ? new Date(step.timestamp).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })
                                  : '—'}
                              </span>
                            </div>

                          </div>
                        );
                      })}
                    </div>
                  </div>

                  {/* Reassignment logs */}
                  {activeDetail.assignment_history.length > 0 && (
                    <div>
                      <h4 style={{ fontSize: '14px', fontWeight: 600, color: '#334155', borderBottom: '1px solid #f1f5f9', paddingBottom: '6px', marginBottom: '8px' }}>
                        📋 Reassignment Logs
                      </h4>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: '8px' }}>
                        {activeDetail.assignment_history.map((log, idx) => (
                          <div key={idx} style={{ fontSize: '11px', color: '#64748b', background: '#f8fafc', padding: '6px 10px', borderRadius: '6px' }}>
                            Changed from <strong>{log.previous_partner_name || 'Unassigned'}</strong> to <strong>{log.new_partner_name}</strong>
                            <br />
                            By: {log.changed_by_name || 'System'} · {new Date(log.changed_at).toLocaleString('en-IN')}
                          </div>
                        ))}
                      </div>
                    </div>
                  )}
                </>
              )}
            </div>

            {/* Modal Footer */}
            <div style={{ padding: '16px', borderTop: '1px solid #e2e8f0', display: 'flex', justifyContent: 'flex-end', background: '#f8fafc' }}>
              <button
                className="btn btn-outline"
                onClick={() => setDetailId(null)}
              >
                Close Drawer
              </button>
            </div>

          </div>
        </div>
      )}
    </div>
  );
}
