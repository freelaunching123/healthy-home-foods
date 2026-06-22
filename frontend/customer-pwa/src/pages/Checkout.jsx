import React, { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';
import { initiatePayment, verifyPayment } from '../api/customerApi';
import { ArrowLeft, MapPin, Plus } from 'lucide-react';
import toast from 'react-hot-toast';

const ORIGIN = 'Kalavasal, Madurai';
const FREE_KM = 5;
const CHARGE_PER_KM = 10;

export default function Checkout() {
  const navigate = useNavigate();
  const { state } = useLocation();
  const product = state?.product;
  const plan = state?.plan || 'monthly';

  const [address, setAddress] = useState({ line1: '', city: 'Madurai', pincode: '' });
  const [startDate, setStartDate] = useState(new Date().toISOString().split('T')[0]);
  const [distKm] = useState(0); // Would come from Google Maps API with key

  if (!product) {
    navigate('/');
    return null;
  }

  const pricePerUnit = parseFloat(product.price || product.price_per_unit || 0);
  const deliveryCount = plan === 'weekly' ? 6 : 26;
  const productTotal = pricePerUnit * deliveryCount;
  const deliveryCharge = distKm > FREE_KM ? Math.round((distKm - FREE_KM) * CHARGE_PER_KM) : 0;
  const grandTotal = productTotal + deliveryCharge;

  const payMut = useMutation({
    mutationFn: async () => {
      // Initiate payment to get Razorpay order
      const { data } = await initiatePayment({
        product_id: product.id,
        plan_type: plan,
        start_date: startDate,
        delivery_address: `${address.line1}, ${address.city} - ${address.pincode}`,
      });
      return data;
    },
    onSuccess: (orderData) => {
      // If Razorpay keys available, open checkout. Otherwise show mock success.
      const rzpKey = import.meta.env.VITE_RAZORPAY_KEY_ID;
      if (rzpKey && window.Razorpay) {
        const options = {
          key: rzpKey,
          amount: orderData.amount,
          currency: orderData.currency || 'INR',
          order_id: orderData.razorpay_order_id,
          name: 'Healthy Home Foods',
          description: `${product.name} — ${plan} plan`,
          image: '🥗',
          handler: async (response) => {
            try {
              await verifyPayment({ ...response, order_id: orderData.order_id });
              toast.success('Payment successful! Subscription activated. 🎉');
              navigate('/subscriptions');
            } catch {
              toast.error('Payment verification failed');
            }
          },
          prefill: { contact: localStorage.getItem('phone') || '' },
          theme: { color: '#2E7D32' },
        };
        new window.Razorpay(options).open();
      } else {
        // Mock success for development (no Razorpay key configured)
        toast.success('Order placed successfully! (Dev mode — payment skipped) 🎉', { duration: 4000 });
        navigate('/subscriptions');
      }
    },
    onError: (e) => toast.error(e.response?.data?.detail || 'Payment initiation failed'),
  });

  const isFormValid = address.line1.trim().length >= 5 && address.pincode.length === 6;

  return (
    <div>
      <div style={{ padding: '16px', background: '#fff', borderBottom: '1px solid #e0e0e0', display: 'flex', alignItems: 'center', gap: 8 }}>
        <button onClick={() => navigate(-1)} style={{ background: 'none', border: 'none', cursor: 'pointer', color: '#2E7D32' }}><ArrowLeft size={20} /></button>
        <h2 style={{ fontSize: '16px', fontFamily: 'Poppins,sans-serif', fontWeight: 600 }}>Checkout</h2>
      </div>

      <div style={{ padding: '16px', display: 'flex', flexDirection: 'column', gap: '16px' }}>
        {/* Product summary */}
        <div className="card">
          <p className="section-title" style={{ marginBottom: '12px' }}>Order Summary</p>
          <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
            <div style={{ width: 60, height: 60, background: '#E8F5E9', borderRadius: '10px', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: '28px', flexShrink: 0 }}>🥗</div>
            <div>
              <p style={{ fontWeight: 600, fontSize: '15px' }}>{product.name}</p>
              <p style={{ fontSize: '13px', color: '#757575', textTransform: 'capitalize' }}>{plan} Plan · {deliveryCount} deliveries</p>
              <p style={{ fontSize: '16px', fontWeight: 700, color: '#2E7D32' }}>₹{productTotal.toFixed(0)}</p>
            </div>
          </div>
        </div>

        {/* Delivery address */}
        <div className="card">
          <p className="section-title" style={{ marginBottom: '12px' }}>
            <MapPin size={16} style={{ marginRight: 6, verticalAlign: 'middle', color: '#2E7D32' }} />
            Delivery Address
          </p>
          <div className="form-group">
            <label className="form-label">Address Line *</label>
            <input className="form-input" placeholder="House no, street, area..."
              value={address.line1} onChange={e => setAddress(a => ({ ...a, line1: e.target.value }))} />
          </div>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '10px' }}>
            <div className="form-group">
              <label className="form-label">City</label>
              <input className="form-input" value={address.city}
                onChange={e => setAddress(a => ({ ...a, city: e.target.value }))} />
            </div>
            <div className="form-group">
              <label className="form-label">Pincode *</label>
              <input className="form-input" type="tel" maxLength={6} placeholder="625001"
                value={address.pincode} onChange={e => setAddress(a => ({ ...a, pincode: e.target.value.replace(/\D/g, '') }))} />
            </div>
          </div>
          <p style={{ fontSize: '12px', color: '#757575' }}>
            📍 Delivery from: <strong>{ORIGIN}</strong> · Free within {FREE_KM}km · ₹{CHARGE_PER_KM}/km beyond
          </p>
        </div>

        {/* Start date */}
        <div className="card">
          <label className="form-label" style={{ marginBottom: '8px', display: 'block' }}>📅 Subscription Start Date</label>
          <input className="form-input" type="date"
            value={startDate} min={new Date().toISOString().split('T')[0]}
            onChange={e => setStartDate(e.target.value)} />
        </div>

        {/* Bill breakdown */}
        <div className="card" style={{ background: '#f9fbe7' }}>
          <p className="section-title" style={{ marginBottom: '12px' }}>Bill Breakdown</p>
          {[
            { label: `${product.name} × ${deliveryCount}`, value: `₹${productTotal.toFixed(0)}` },
            { label: `Delivery Charge (${distKm}km)`, value: deliveryCharge > 0 ? `₹${deliveryCharge}` : 'FREE' },
          ].map(row => (
            <div key={row.label} style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '8px', fontSize: '14px' }}>
              <span style={{ color: '#757575' }}>{row.label}</span>
              <span style={{ fontWeight: 500 }}>{row.value}</span>
            </div>
          ))}
          <div style={{ borderTop: '1.5px dashed #c5e1a5', paddingTop: '10px', display: 'flex', justifyContent: 'space-between' }}>
            <span style={{ fontWeight: 700, fontSize: '16px' }}>Total Amount</span>
            <span style={{ fontWeight: 700, fontSize: '18px', color: '#2E7D32' }}>₹{grandTotal.toFixed(0)}</span>
          </div>
        </div>

        {/* Pay button */}
        <button className="btn-primary" style={{ fontSize: '16px', padding: '16px' }}
          onClick={() => payMut.mutate()}
          disabled={!isFormValid || payMut.isPending}>
          {payMut.isPending
            ? <span style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8 }}><span className="spinner" />Processing...</span>
            : `💳 Pay ₹${grandTotal.toFixed(0)}`}
        </button>

        <p style={{ textAlign: 'center', fontSize: '12px', color: '#9e9e9e' }}>
          🔒 Secured by Razorpay · Your data is safe
        </p>
      </div>
    </div>
  );
}
