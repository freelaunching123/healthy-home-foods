import React from 'react';
import { Bell, Search, UserCircle } from 'lucide-react';
import './Header.css';

const Header = () => {
  return (
    <header className="top-header">
      <div className="search-bar">
        <Search size={18} className="text-gray" />
        <input type="text" placeholder="Search customers, orders, deliveries..." />
      </div>

      <div className="header-actions">
        <button className="icon-btn relative">
          <Bell size={20} />
          <span className="notification-dot"></span>
        </button>
        <div className="user-profile">
          <UserCircle size={32} className="text-gray" />
          <div className="user-info">
            <span className="user-name">Super Admin</span>
            <span className="user-role">Administrator</span>
          </div>
        </div>
      </div>
    </header>
  );
};

export default Header;
