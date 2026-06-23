import React from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { CheckCircle, AlertTriangle, XCircle, Info } from 'lucide-react';
import './NeumorphicAlert.css';

const NeumorphicAlert = ({ isOpen, message, type = 'info', onClose }) => {
  const icons = {
    success: <CheckCircle className="neu-icon success" size={36} />,
    error: <XCircle className="neu-icon error" size={36} />,
    warning: <AlertTriangle className="neu-icon warning" size={36} />,
    info: <Info className="neu-icon info" size={36} />
  };

  return (
    <AnimatePresence>
      {isOpen && (
        <motion.div 
          className="neu-overlay"
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
        >
          <motion.div 
            className="neu-popup"
            initial={{ scale: 0.8, opacity: 0, y: 30 }}
            animate={{ scale: 1, opacity: 1, y: 0 }}
            exit={{ scale: 0.8, opacity: 0, y: 30 }}
            transition={{ type: "spring", stiffness: 300, damping: 25 }}
          >
            <div className="neu-content">
              <div className="neu-icon-wrapper">
                {icons[type]}
              </div>
              <h3 className="neu-title">
                {type.charAt(0).toUpperCase() + type.slice(1)}
              </h3>
              <p className="neu-message">{message}</p>
              <button className="neu-btn" onClick={onClose}>
                Confirm
              </button>
            </div>
          </motion.div>
        </motion.div>
      )}
    </AnimatePresence>
  );
};

export default NeumorphicAlert;
