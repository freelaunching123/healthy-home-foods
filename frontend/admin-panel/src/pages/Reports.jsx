import React, { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { getDashboardStats, getDeliveryPartnerPerformance, exportExcel, exportPdf, downloadBlob } from '../api/reportsApi';
import toast from 'react-hot-toast';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, PieChart, Pie, Cell, Legend
} from 'recharts';

const COLORS = ['#10b981', '#f59e0b', '#3b82f6', '#ef4444', '#8b5cf6'];

export default function Reports() {
  const [exporting, setExporting] = useState('');

  const { data: stats } = useQuery({
    queryKey: ['dashboardStats'],
    queryFn: async () => { const { data } = await getDashboardStats(); return data; },
  });

  const { data: perfData = [], isLoading } = useQuery({
    queryKey: ['deliveryPartnerPerf'],
    queryFn: async () => { const { data } = await getDeliveryPartnerPerformance(); return data || []; },
  });

  const deliveryPieData = stats ? [
    { name: 'Completed', value: stats.completed_deliveries || 0 },
    { name: 'Pending', value: stats.pending_deliveries || 0 },
    { name: 'Missed', value: stats.missed_deliveries || 0 },
  ].filter(d => d.value > 0) : [];

  const perfBarData = perfData.map(db => ({
    name: (db.full_name || '').split(' ')[0],
    completed: db.completed_deliveries || 0,
    pending: db.pending_deliveries || 0,
    rate: db.success_rate || 0,
  }));

  const handleExport = async (type) => {
    setExporting(type);
    try {
      const fn = type === 'excel' ? exportExcel : exportPdf;
      const { data } = await fn();
      downloadBlob(data, `HHF_Report_${new Date().toLocaleDateString('en-IN').replace(/\//g, '-')}.${type === 'excel' ? 'xlsx' : 'pdf'}`);
      toast.success(`${type.toUpperCase()} report downloaded!`);
    } catch (e) {
      toast.error('Export failed — ' + (e.response?.data?.detail || e.message));
    } finally {
      setExporting('');
    }
  };

  const metricCards = [
    { label: 'Total Customers', value: stats?.total_customers || 0, icon: '👥' },
    { label: 'Active Subscriptions', value: stats?.active_subscriptions || 0, icon: '📦' },
    { label: 'Monthly Revenue', value: `₹${(stats?.monthly_revenue || 0).toLocaleString('en-IN')}`, icon: '💰' },
    { label: 'Delivery Success Rate', value: `${stats?.delivery_success_rate || 0}%`, icon: '✅' },
  ];

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <div>
          <h1 className="page-title">Reports & Analytics</h1>
          <p className="text-gray">Performance overview and exportable reports</p>
        </div>
        <div style={{ display: 'flex', gap: '10px' }}>
          <button className="btn btn-outline" onClick={() => handleExport('excel')}
            disabled={exporting === 'excel'}>
            {exporting === 'excel' ? 'Downloading...' : '⬇ Export Excel'}
          </button>
          <button className="btn btn-primary" onClick={() => handleExport('pdf')}
            disabled={exporting === 'pdf'}>
            {exporting === 'pdf' ? 'Downloading...' : '⬇ Export PDF'}
          </button>
        </div>
      </div>

      {/* Metric cards */}
      <div className="stats-grid">
        {metricCards.map(m => (
          <div key={m.label} className="card stat-card">
            <div className="stat-header">
              <div>
                <h3 className="stat-title">{m.label}</h3>
                <p className="stat-value">{m.value}</p>
              </div>
              <div className="stat-icon" style={{ fontSize: '28px' }}>{m.icon}</div>
            </div>
          </div>
        ))}
      </div>

      <div className="charts-grid">
        {/* Delivery Partner Performance Bar Chart */}
        <div className="card chart-card">
          <div className="card-header">
            <h3 className="card-title">Delivery Team Performance</h3>
          </div>
          <div className="chart-container">
            {perfBarData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <BarChart data={perfBarData} barGap={4}>
                  <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#e2e8f0" />
                  <XAxis dataKey="name" axisLine={false} tickLine={false} tick={{ fill: '#64748b', fontSize: 12 }} />
                  <YAxis axisLine={false} tickLine={false} tick={{ fill: '#64748b', fontSize: 12 }} />
                  <Tooltip contentStyle={{ borderRadius: '8px', border: 'none', boxShadow: '0 4px 6px rgba(0,0,0,0.1)' }} />
                  <Legend />
                  <Bar dataKey="completed" name="Completed" fill="#10b981" radius={[4, 4, 0, 0]} />
                  <Bar dataKey="pending" name="Pending" fill="#f59e0b" radius={[4, 4, 0, 0]} />
                </BarChart>
              </ResponsiveContainer>
            ) : (
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%', color: '#94a3b8' }}>
                No delivery data available
              </div>
            )}
          </div>
        </div>

        {/* Delivery Status Pie Chart */}
        <div className="card list-card">
          <div className="card-header">
            <h3 className="card-title">Delivery Status Breakdown</h3>
          </div>
          <div style={{ height: 220, marginTop: '8px' }}>
            {deliveryPieData.length > 0 ? (
              <ResponsiveContainer width="100%" height="100%">
                <PieChart>
                  <Pie data={deliveryPieData} cx="50%" cy="50%" innerRadius={60} outerRadius={90}
                    paddingAngle={4} dataKey="value" label={({ name, percent }) => `${name} ${(percent * 100).toFixed(0)}%`}>
                    {deliveryPieData.map((_, i) => (
                      <Cell key={i} fill={COLORS[i % COLORS.length]} />
                    ))}
                  </Pie>
                  <Tooltip />
                </PieChart>
              </ResponsiveContainer>
            ) : (
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100%', color: '#94a3b8' }}>
                No delivery data yet
              </div>
            )}
          </div>

          {/* Performance Table */}
          {perfData.length > 0 && (
            <div style={{ marginTop: '16px', borderTop: '1px solid #e2e8f0', paddingTop: '16px' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '13px' }}>
                <thead>
                  <tr>
                    {['Delivery Partner', 'Done', 'Pending', 'Rate'].map(h => (
                      <th key={h} style={{ padding: '6px 8px', textAlign: 'left', color: '#64748b', fontWeight: 600 }}>{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {perfData.map((db, i) => (
                    <tr key={i} style={{ borderTop: '1px solid #f1f5f9' }}>
                      <td style={{ padding: '6px 8px', fontWeight: 500 }}>{db.full_name || '—'}</td>
                      <td style={{ padding: '6px 8px', color: '#16a34a' }}>{db.completed_deliveries || 0}</td>
                      <td style={{ padding: '6px 8px', color: '#d97706' }}>{db.pending_deliveries || 0}</td>
                      <td style={{ padding: '6px 8px' }}>
                        <span style={{ fontWeight: 600, color: (db.success_rate || 0) >= 90 ? '#16a34a' : '#d97706' }}>
                          {db.success_rate || 0}%
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
