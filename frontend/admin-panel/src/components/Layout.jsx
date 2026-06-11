import React from 'react';
import { Outlet, Navigate } from 'react-router-dom';
import Sidebar from './Sidebar';
import Header from './Header';

const Layout = () => {
  const token = localStorage.getItem('access_token');
  
  if (!token) {
    return <Navigate to="/login" />;
  }

  return (
    <div className="app-container">
      <Sidebar />
      <div className="main-content">
        <Header />
        <main className="content-area animate-fade-in">
          <Outlet />
        </main>
      </div>
    </div>
  );
};

export default Layout;
