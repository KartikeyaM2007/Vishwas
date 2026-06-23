import React from 'react';
import { useTheme } from '../contexts/ThemeContext';
import { Sun, Moon } from 'lucide-react';
import { motion } from 'framer-motion';
import './ThemeToggle.css';

const ThemeToggle = () => {
  const { theme, toggleTheme } = useTheme();

  return (
    <div className="theme-toggle-wrapper glass-card">
      <button 
        className={`theme-toggle-btn ${theme === 'light' ? 'active' : ''}`}
        onClick={() => theme !== 'light' && toggleTheme()}
      >
        <Sun size={18} />
        <span className="sr-only">White</span>
      </button>
      
      <button 
        className={`theme-toggle-btn ${theme === 'dark' ? 'active' : ''}`}
        onClick={() => theme !== 'dark' && toggleTheme()}
      >
        <Moon size={18} />
        <span className="sr-only">Blue</span>
      </button>

      {/* Floating active background */}
      <motion.div
        className="theme-toggle-active-bg"
        layoutId="theme-toggle-active"
        initial={false}
        animate={{
          x: theme === 'light' ? 0 : '100%',
        }}
        transition={{ type: "spring", stiffness: 400, damping: 30 }}
      />
    </div>
  );
};

export default ThemeToggle;
