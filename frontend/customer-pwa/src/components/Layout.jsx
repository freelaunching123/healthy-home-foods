import React from 'react';
import { NavLink, Outlet, Navigate } from 'react-router-dom';
import { Home, CalendarClock, User, MapPin } from 'lucide-react';

const Layout = () => {
  const token = localStorage.getItem('token');
  
  if (!token) {
    return <Navigate to="/login" />;
  }

  return (
    <>
      <div className="page-container">
        <Outlet />
      </div>

      <nav className="bottom-nav">
        <NavLink to="/" className={({isActive}) => `nav-item ${isActive ? 'active' : ''}`} end>
          <Home size={24} />
          <span>Home</span>
        </NavLink>
        <NavLink to="/subscriptions" className={({isActive}) => `nav-item ${isActive ? 'active' : ''}`}>
          <CalendarClock size={24} />
          <span>My Plan</span>
        </NavLink>
        <NavLink to="/track" className={({isActive}) => `nav-item ${isActive ? 'active' : ''}`}>
          <MapPin size={24} />
          <span>Track</span>
        </NavLink>
        <NavLink to="/profile" className={({isActive}) => `nav-item ${isActive ? 'active' : ''}`}>
          <User size={24} />
          <span>Profile</span>
        </NavLink>
      </nav>
    </>
  );
};

export default Layout;
