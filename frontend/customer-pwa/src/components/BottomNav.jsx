import React from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Home, Package, MapPin, User } from 'lucide-react';

export default function BottomNav() {
  const navigate = useNavigate();
  const { pathname } = useLocation();

  const navItems = [
    { to: '/', icon: Home, label: 'Home' },
    { to: '/subscriptions', icon: Package, label: 'Plans' },
    { to: '/track', icon: MapPin, label: 'Track' },
    { to: '/profile', icon: User, label: 'Profile' },
  ];

  return (
    <nav className="bottom-nav">
      {navItems.map(({ to, icon: Icon, label }) => {
        // Active if exact match OR if we're on a subpath of subscriptions
        const isActive = pathname === to || (to === '/subscriptions' && pathname.startsWith('/subscriptions'));
        return (
          <button
            key={to}
            className={`nav-btn ${isActive ? 'active' : ''}`}
            onClick={() => navigate(to)}
          >
            <Icon size={22} />
            <span>{label}</span>
          </button>
        );
      })}
    </nav>
  );
}
