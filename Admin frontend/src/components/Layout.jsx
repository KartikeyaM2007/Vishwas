import React from 'react';
import Sidebar from './Sidebar';

const Layout = ({ children }) => {
  return (
    <div style={{ display: 'flex', minHeight: '100vh', width: '100%' }}>
      <Sidebar />
      <main style={{ marginLeft: 'var(--sidebar-width)', flex: 1, position: 'relative', overflowX: 'hidden' }}>
        {children}
      </main>
    </div>
  );
};

export default Layout;
