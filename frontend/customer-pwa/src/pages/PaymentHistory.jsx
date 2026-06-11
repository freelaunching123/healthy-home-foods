import React from 'react';
import { useQuery } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { getPaymentHistory } from '../api/customerApi';
import { ArrowLeft, Receipt } from 'lucide-react';
import toast from 'react-hot-toast';

export default function PaymentHistory() {
  const navigate = useNavigate();

  const { data: payments = [], isLoading } = useQuery({
    queryKey: ['payments'],
    queryFn: async () => {
      try {
        const { data } = await getPaymentHistory();
        return data?.items || data || [];
      } catch {
        return [];
      }
    },
  });

  const downloadInvoice = () => {
    toast('Invoice download would happen here if supported by backend API', { icon: 'ℹ️' });
  };

  return (
    <div>
      <div style={{ padding: '16px', background: '#fff', borderBottom: '1px solid #e0e0e0', display: 'flex', alignItems: 'center', gap: 8 }}>
        <button onClick={() => navigate(-1)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#2E7D32' }}><ArrowLeft size={20} /></button>
        <h2 style={{ fontSize: '16px', fontFamily: 'Poppins,sans-serif', fontWeight: 600 }}>Payment History</h2>
      </div>

      <div style={{ padding: '16px' }}>
        {isLoading ? (
          <div className="loading-dots"><span /><span /><span /></div>
        ) : payments.length === 0 ? (
          <div className="empty-state">
            <div className="empty-state-icon">💳</div>
            <h3>No payments yet</h3>
            <p>Your transaction history will appear here</p>
          </div>
        ) : (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
            {payments.map(p => (
              <div key={p.id} className="card" style={{ padding: '16px' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '8px' }}>
                  <div>
                    <h3 style={{ fontSize: '15px', fontWeight: 600 }}>₹{parseFloat(p.amount || 0).toFixed(0)}</h3>
                    <p style={{ fontSize: '12px', color: '#757575', fontFamily: 'monospace' }}>{p.razorpay_payment_id || 'N/A'}</p>
                  </div>
                  <span className={`badge ${p.status === 'success' ? 'badge-success' : p.status === 'pending' ? 'badge-warning' : 'badge-error'}`}>
                    {p.status || 'unknown'}
                  </span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-end', marginTop: '12px', borderTop: '1px solid #f5f5f5', paddingTop: '12px' }}>
                  <p style={{ fontSize: '12px', color: '#757575' }}>
                    {p.created_at ? new Date(p.created_at).toLocaleString('en-IN') : 'Date unknown'}
                  </p>
                  {p.status === 'success' && (
                    <button onClick={downloadInvoice} style={{ background: 'none', border: 'none', color: '#2E7D32', cursor: 'pointer', display: 'flex', alignItems: 'center', gap: '4px', fontSize: '12px', fontWeight: 500 }}>
                      <Receipt size={14} /> Invoice
                    </button>
                  )}
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
