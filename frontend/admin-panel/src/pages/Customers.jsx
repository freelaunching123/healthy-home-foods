import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getUsers, updateUser, deactivateUser } from '../api/usersApi';
import toast from 'react-hot-toast';
import { UserX, Edit2, Phone } from 'lucide-react';

const STATUS_STYLES = {
  active:    { bg: '#dcfce7', color: '#16a34a' },
  inactive:  { bg: '#fee2e2', color: '#dc2626' },
  suspended: { bg: '#fef3c7', color: '#d97706' },
};

export default function Customers() {
  const qc = useQueryClient();
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);

  const { data, isLoading } = useQuery({
    queryKey: ['customers', page],
    queryFn: async () => {
      const { data } = await getUsers({ skip: (page - 1) * 20, limit: 20 });
      return data;
    },
  });

  const deactivateMut = useMutation({
    mutationFn: (id) => deactivateUser(id),
    onSuccess: () => { qc.invalidateQueries(['customers']); toast.success('User deactivated'); },
    onError: (e) => toast.error(e.response?.data?.detail || 'Failed'),
  });

  const users = (data?.items || data || []).filter(u =>
    u.full_name?.toLowerCase().includes(search.toLowerCase()) ||
    u.phone?.includes(search)
  );
  const total = data?.total || users.length;

  return (
    <div className="dashboard">
      <div className="dashboard-header">
        <div>
          <h1 className="page-title">Customers</h1>
          <p className="text-gray">{total} registered users</p>
        </div>
      </div>

      <div className="card" style={{ padding: '16px', marginBottom: '0' }}>
        <input className="form-control" placeholder="🔍  Search by name or phone..."
          value={search} onChange={e => setSearch(e.target.value)} style={{ maxWidth: 360 }} />
      </div>

      <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
        {isLoading ? (
          <div style={{ padding: '48px', textAlign: 'center', color: '#94a3b8' }}>Loading customers...</div>
        ) : users.length === 0 ? (
          <div style={{ padding: '64px', textAlign: 'center', color: '#94a3b8' }}>
            <p style={{ fontSize: '48px', marginBottom: '8px' }}>👥</p>
            <p>No customers found</p>
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
              {users.map((u, i) => {
                const st = STATUS_STYLES[u.status] || STATUS_STYLES.active;
                return (
                  <tr key={u.id} style={{ borderBottom: '1px solid #f1f5f9', background: i % 2 === 0 ? '#fff' : '#fafafa' }}>
                    <td style={{ padding: '12px 16px', fontSize: '13px', color: '#94a3b8' }}>
                      {(page - 1) * 20 + i + 1}
                    </td>
                    <td style={{ padding: '12px 16px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                        <div style={{
                          width: 36, height: 36, borderRadius: '50%', background: '#f0fdf4',
                          color: '#16a34a', display: 'flex', alignItems: 'center', justifyContent: 'center',
                          fontWeight: 700, fontSize: '14px', flexShrink: 0
                        }}>
                          {(u.full_name || 'U')[0].toUpperCase()}
                        </div>
                        <span style={{ fontWeight: 500 }}>{u.full_name || '—'}</span>
                      </div>
                    </td>
                    <td style={{ padding: '12px 16px', fontSize: '14px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 4 }}>
                        <Phone size={12} style={{ color: '#94a3b8' }} />
                        {u.phone || '—'}
                      </div>
                    </td>
                    <td style={{ padding: '12px 16px', fontSize: '14px', color: '#64748b' }}>{u.email || '—'}</td>
                    <td style={{ padding: '12px 16px' }}>
                      <span style={{ background: st.bg, color: st.color,
                        padding: '3px 10px', borderRadius: '999px', fontSize: '12px', fontWeight: 600 }}>
                        {u.status || 'active'}
                      </span>
                    </td>
                    <td style={{ padding: '12px 16px', fontSize: '13px', color: '#64748b' }}>
                      {u.created_at ? new Date(u.created_at).toLocaleDateString('en-IN') : '—'}
                    </td>
                    <td style={{ padding: '12px 16px' }}>
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
    </div>
  );
}
