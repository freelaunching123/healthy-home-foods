import React from 'react';
import { BrowserRouter, Routes, Route, Navigate, Outlet, useLocation } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Toaster } from 'react-hot-toast';

import BottomNav from './components/BottomNav';
import Login from './pages/Login';
import Home from './pages/Home';
import ProductDetail from './pages/ProductDetail';
import Checkout from './pages/Checkout';
import MySubscriptions from './pages/MySubscriptions';
import SubscriptionDetail from './pages/SubscriptionDetail';
import Tracking from './pages/Tracking';
import Profile from './pages/Profile';
import PaymentHistory from './pages/PaymentHistory';

import './index.css';

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: 1, staleTime: 30000 } },
});

// Auth guard
const ProtectedRoute = () => {
  const token = localStorage.getItem('access_token');
  if (!token) return <Navigate to="/login" replace />;
  return (
    <div className="pwa-layout">
      <div className="pwa-content">
        <Outlet />
      </div>
      {/* Show BottomNav on main tabs */}
      <BottomNavWrapper />
    </div>
  );
};

// Helper to selectively show bottom nav
const BottomNavWrapper = () => {
  const { pathname } = useLocation();
  const showNav = ['/', '/subscriptions', '/track', '/profile'].includes(pathname);
  return showNav ? <BottomNav /> : null;
};

// Redirect tracking link if accessed directly without param
const TrackRedirect = () => {
  // Real app: we'd fetch the active delivery assignment ID.
  // For demo, we just show a placeholder page or redirect.
  return (
    <div style={{ padding: 24, textAlign: 'center', marginTop: 40 }}>
      <h3 style={{ marginBottom: 12 }}>Enter Tracking ID</h3>
      <p style={{ color: '#757575', fontSize: 14 }}>Or track directly from your active subscription delivery schedule.</p>
    </div>
  );
};

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Toaster
          position="top-center"
          toastOptions={{
            style: { borderRadius: '12px', fontSize: '14px', fontFamily: 'Inter,sans-serif' },
            success: { iconTheme: { primary: '#2E7D32', secondary: '#fff' } },
          }}
        />
        <Routes>
          <Route path="/login" element={<Login />} />

          <Route element={<ProtectedRoute />}>
            <Route path="/" element={<Home />} />
            <Route path="/product/:id" element={<ProductDetail />} />
            <Route path="/checkout" element={<Checkout />} />
            <Route path="/subscriptions" element={<MySubscriptions />} />
            <Route path="/subscriptions/:id" element={<SubscriptionDetail />} />
            <Route path="/track" element={<TrackRedirect />} />
            <Route path="/track/:assignmentId" element={<Tracking />} />
            <Route path="/profile" element={<Profile />} />
            <Route path="/payments" element={<PaymentHistory />} />
          </Route>

          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </QueryClientProvider>
  );
}

export default App;
