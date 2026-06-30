import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { Home, Filter, Sparkles, AlertTriangle, Mic, Users, Trophy, ShieldCheck } from 'lucide-react';
import { motion } from 'framer-motion';
import ThemeToggle from './ThemeToggle';
import './Sidebar.css';

const Sidebar = () => {
  const location = useLocation();

  const navItems = [
    { path: '/', label: 'Map Overview', icon: Home },
    { path: '/filter', label: 'Complaint Data', icon: Filter },
    { path: '/analyze', label: 'AI Analysis', icon: Sparkles },
    { path: '/voice-report', label: 'Voice Report', icon: Mic },
    { path: '/community', label: 'Community Feed', icon: Users },
    { path: '/review-queue', label: 'Review Queue', icon: ShieldCheck },
    { path: '/leaderboard', label: 'Leaderboard', icon: Trophy },
  ];

  return (
    <aside className="glass-panel sidebar-container">
      <div className="sidebar-header">
        <div className="logo-icon hover-glow">
          <AlertTriangle size={24} color="white" />
        </div>
        <div className="logo-text">
          <h1>SmartCity</h1>
          <p>COMPLAINT ADMIN</p>
        </div>
      </div>

      <nav className="sidebar-nav">
        {navItems.map((item) => {
          const isActive = location.pathname === item.path;
          const Icon = item.icon;

          return (
            <Link key={item.path} to={item.path} className="nav-link">
              {isActive && (
                <motion.div
                  layoutId="activeTab"
                  className="active-indicator"
                  initial={false}
                  transition={{ type: "spring", stiffness: 300, damping: 30 }}
                />
              )}
              <div className={`nav-item-content ${isActive ? 'active' : ''}`}>
                <Icon size={20} className="nav-icon" />
                <span>{item.label}</span>
              </div>
            </Link>
          );
        })}
      </nav>

      <div className="sidebar-footer">
        <ThemeToggle />
        <div className="glass-card user-profile">
          <img src="https://ui-avatars.com/api/?name=Admin+User&background=6366f1&color=fff" alt="Admin" />
          <div className="user-info">
            <p className="user-name">Administrator</p>
            <p className="user-email">admin@smartcity.gov</p>
          </div>
        </div>
      </div>
    </aside>
  );
};

export default Sidebar;
