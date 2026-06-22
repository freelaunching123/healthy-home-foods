import React, { useState } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { getProduct } from '../api/customerApi';
import { ArrowLeft } from 'lucide-react';

export default function ProductDetail() {
  const { id } = useParams();
  const navigate = useNavigate();
  const [plan, setPlan] = useState('monthly'); // 'weekly' | 'monthly'

  const { data: product, isLoading } = useQuery({
    queryKey: ['product', id],
    queryFn: async () => { const { data } = await getProduct(id); return data; },
    enabled: !!id,
  });

  if (isLoading) return (
    <div style={{ padding: '24px' }}>
      <div className="loading-dots"><span /><span /><span /></div>
    </div>
  );

  if (!product) return (
    <div className="empty-state" style={{ padding: '64px 24px' }}>
      <div className="empty-state-icon">❌</div>
      <h3>Product not found</h3>
      <button className="btn-outline" style={{ marginTop: '16px' }} onClick={() => navigate('/')}>← Back to Home</button>
    </div>
  );

  // Price computation — weekly = price * 6, monthly = price * 26
  const pricePerUnit = parseFloat(product.price || product.price_per_unit || 0);
  const weeklyTotal  = (pricePerUnit * 6).toFixed(0);
  const monthlyTotal = (pricePerUnit * 26).toFixed(0);

  const selectedPrice = plan === 'weekly' ? weeklyTotal : monthlyTotal;
  const deliveryCount = plan === 'weekly' ? 6 : 26;

  const isAvailable = product.availability === 'available' || product.is_available === true;

  return (
    <div>
      {/* Back button */}
      <div style={{ padding: '16px', display: 'flex', alignItems: 'center', gap: '8px', background: '#fff', borderBottom: '1px solid #e0e0e0' }}>
        <button onClick={() => navigate(-1)} style={{ background: 'none', border: 'none', cursor: 'pointer', display: 'flex', alignItems: 'center', color: '#2E7D32' }}>
          <ArrowLeft size={20} />
        </button>
        <h2 style={{ fontSize: '16px', fontFamily: 'Poppins,sans-serif', fontWeight: 600 }}>Product Details</h2>
      </div>

      {/* Hero image */}
      <div style={{ height: 220, background: 'linear-gradient(135deg, #E8F5E9, #C8E6C9)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '80px' }}>
        {product.image_url
          ? <img src={`http://localhost:8000${product.image_url}`} alt={product.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
          : '🥗'}
      </div>

      <div style={{ padding: '20px' }}>
        {/* Name + badge */}
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: '8px' }}>
          <h1 style={{ fontSize: '22px', fontFamily: 'Poppins,sans-serif', fontWeight: 700 }}>{product.name}</h1>
          <span className={`badge ${isAvailable ? 'badge-success' : 'badge-danger'}`}>{isAvailable ? '✓ Available' : 'Unavailable'}</span>
        </div>
        <p style={{ fontSize: '13px', color: '#757575', marginBottom: '16px' }}>
          {product.category_name || 'Healthy Food'}
        </p>

        {product.description && (
          <p style={{ fontSize: '14px', color: '#424242', lineHeight: 1.6, marginBottom: '20px' }}>
            {product.description}
          </p>
        )}

        {/* Plan Toggle */}
        <p className="section-title" style={{ marginBottom: '8px' }}>Choose Your Plan</p>
        <div className="plan-toggle" style={{ marginBottom: '16px' }}>
          <button className={`plan-btn ${plan === 'weekly' ? 'active' : ''}`} onClick={() => setPlan('weekly')}>
            📅 Weekly
          </button>
          <button className={`plan-btn ${plan === 'monthly' ? 'active' : ''}`} onClick={() => setPlan('monthly')}>
            🗓️ Monthly
          </button>
        </div>

        {/* Price card */}
        <div className="card" style={{ marginBottom: '16px', background: '#f0fdf4', border: '1.5px solid #a7f3d0' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <p style={{ fontSize: '13px', color: '#2E7D32', fontWeight: 500, marginBottom: '4px' }}>
                {plan === 'weekly' ? 'Weekly Plan' : 'Monthly Plan'}
              </p>
              <p style={{ fontSize: '28px', fontWeight: 700, color: '#2E7D32' }}>₹{selectedPrice}</p>
              <p style={{ fontSize: '12px', color: '#4caf50' }}>{deliveryCount} deliveries · ₹{pricePerUnit.toFixed(0)} per delivery</p>
            </div>
            <div style={{ textAlign: 'center', background: '#fff', padding: '12px', borderRadius: '10px' }}>
              <p style={{ fontSize: '24px', fontWeight: 700, color: '#2E7D32' }}>{deliveryCount}</p>
              <p style={{ fontSize: '11px', color: '#757575' }}>deliveries</p>
            </div>
          </div>
        </div>

        {/* Subscribe button */}
        <button
          className="btn-primary"
          disabled={!isAvailable}
          onClick={() => navigate('/checkout', { state: { product, plan } })}
        >
          {isAvailable ? `Subscribe — ₹${selectedPrice}` : 'Currently Unavailable'}
        </button>
      </div>
    </div>
  );
}
