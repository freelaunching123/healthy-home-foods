import React from 'react';
import { NavLink, useNavigate } from 'react-router-dom';
import {
  LayoutDashboard, Package, Users, RefreshCw,
  Truck, BarChart3, Settings, LogOut, ShoppingBag
} from 'lucide-react';
import toast from 'react-hot-toast';
import { logout } from '../api/authApi';
import './Sidebar.css';

const navItems = [
  { to: '/',             icon: LayoutDashboard, label: 'Dashboard',     end: true },
  { to: '/products',     icon: Package,         label: 'Products'       },
  { to: '/customers',    icon: Users,           label: 'Customers'      },
  { to: '/subscriptions',icon: RefreshCw,       label: 'Subscriptions'  },
  { to: '/deliveries',   icon: Truck,           label: 'Deliveries'     },
  { to: '/reports',      icon: BarChart3,       label: 'Reports'        },
  { to: '/settings',     icon: Settings,        label: 'Settings'       },
];

export default function Sidebar() {
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    localStorage.clear();
    toast.success('Logged out successfully');
    navigate('/login');
  };

  return (
    <aside className="sidebar">
      <div className="sidebar-brand">
        <div className="brand-icon">🥗</div>
        <div>
          <h1 className="brand-title">HHF Admin</h1>
          <p className="brand-sub">Management Portal</p>
        </div>
      </div>

      <nav className="sidebar-nav">
        {navItems.map(({ to, icon: Icon, label, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}
          >
            <Icon size={18} />
            <span>{label}</span>
          </NavLink>
        ))}
      </nav>

      <div className="sidebar-footer">
        <div className="sidebar-user">
          <div className="user-avatar">SA</div>
          <div>
            <p className="user-name">Super Admin</p>
            <p className="user-role">Administrator</p>
          </div>
        </div>
        <button className="logout-btn" onClick={handleLogout} title="Logout">
          <LogOut size={16} />
        </button>
      </div>
    </aside>
  );
}
