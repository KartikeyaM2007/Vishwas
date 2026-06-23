import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { fetchComplaints, confirmComplaint, markDuplicate } from '../services/api';
import { CheckCircle, Copy, Clock, MapPin, Building, AlertTriangle } from 'lucide-react';

const CommunityFeed = () => {
  const [issues, setIssues] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const loadIssues = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchComplaints();
      setIssues(data.data || []);
    } catch (err) {
      console.error("Failed to load community feed", err);
      setError(err.message || "Failed to load community feed.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadIssues();
  }, []);

  const handleConfirm = async (id) => {
    try {
      await confirmComplaint(id);
      loadIssues();
    } catch (err) {
      console.error("Error confirming issue", err);
      alert(err.message || "Failed to confirm issue");
    }
  };

  const handleDuplicate = async (id) => {
    try {
      await markDuplicate(id);
      loadIssues();
    } catch (err) {
      console.error("Error marking duplicate", err);
      alert(err.message || "Failed to mark duplicate");
    }
  };

  if (loading) {
    return (
      <div className="page-container" style={{ padding: '2rem', display: 'flex', justifyContent: 'center' }}>
        <p>Loading community feed...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="page-container" style={{ padding: '2rem', display: 'flex', justifyContent: 'center' }}>
        <div style={{ textAlign: 'center', backgroundColor: 'rgba(239, 68, 68, 0.1)', padding: '2rem', borderRadius: '12px', border: '1px solid rgba(239, 68, 68, 0.2)', color: '#ef4444' }}>
          <h3>⚠️ Error Loading Feed</h3>
          <p>{error}</p>
          <button onClick={loadIssues} className="btn-primary" style={{ marginTop: '1rem', background: 'rgba(239, 68, 68, 0.2)', color: '#ef4444' }}>
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <motion.div 
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="page-container"
      style={{ padding: '2rem', maxWidth: '900px', margin: '0 auto' }}
    >
      <header style={{ marginBottom: '2rem' }}>
        <h1 style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <Building color="#3b82f6" /> 
          Public Community Feed
        </h1>
        <p style={{ color: '#9ca3af' }}>
          View, confirm, and validate civic issues reported in your area.
        </p>
      </header>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
        <AnimatePresence>
          {issues.map((issue) => (
            <motion.div 
              key={issue.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="glass-panel"
              style={{ padding: '1.5rem', borderRadius: '16px', display: 'flex', flexDirection: 'column', gap: '1rem' }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
                <div>
                  <h3 style={{ textTransform: 'capitalize', color: '#f8fafc', marginBottom: '0.5rem', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    {issue.issue_type}
                    {issue.urgency_label && (
                      <span style={{ 
                        fontSize: '0.75rem', 
                        padding: '2px 8px', 
                        borderRadius: '12px',
                        background: issue.urgency_label === 'critical' ? 'rgba(239,68,68,0.2)' : 
                                  issue.urgency_label === 'high' ? 'rgba(245,158,11,0.2)' : 'rgba(59,130,246,0.2)',
                        color: issue.urgency_label === 'critical' ? '#fca5a5' : 
                               issue.urgency_label === 'high' ? '#fcd34d' : '#93c5fd'
                      }}>
                        {issue.urgency_label.toUpperCase()}
                      </span>
                    )}
                  </h3>
                  <p style={{ color: '#cbd5e1', fontSize: '0.95rem', lineHeight: '1.5' }}>
                    {issue.complaint_desc}
                  </p>
                </div>
                {issue.image_url && (
                  <img 
                    src={issue.image_url} 
                    alt="Issue" 
                    style={{ width: '80px', height: '80px', objectFit: 'cover', borderRadius: '8px', marginLeft: '1rem' }}
                  />
                )}
              </div>

              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '1rem', fontSize: '0.85rem', color: '#9ca3af' }}>
                <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <Building size={14} /> {issue.department || 'General'}
                </span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <MapPin size={14} /> {issue.latitude?.toFixed(4)}, {issue.longitude?.toFixed(4)}
                </span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}>
                  <Clock size={14} /> {new Date(issue.submitted_at).toLocaleDateString()}
                </span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '4px', color: issue.status === 'solved' ? '#34d399' : '#fbbf24' }}>
                  <AlertTriangle size={14} /> Status: <strong style={{ textTransform: 'capitalize' }}>{issue.status}</strong>
                </span>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: '0.5rem', borderTop: '1px solid rgba(255,255,255,0.1)', paddingTop: '1rem' }}>
                <div style={{ display: 'flex', gap: '1.5rem' }}>
                  <div style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: '1.2rem', fontWeight: 'bold', color: '#f8fafc' }}>{issue.priority_score?.toFixed(1) || '0'}</div>
                    <div style={{ fontSize: '0.75rem', color: '#9ca3af' }}>Priority</div>
                  </div>
                  <div style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: '1.2rem', fontWeight: 'bold', color: '#34d399' }}>{issue.community_confirmations || 0}</div>
                    <div style={{ fontSize: '0.75rem', color: '#9ca3af' }}>Confirmations</div>
                  </div>
                  <div style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: '1.2rem', fontWeight: 'bold', color: '#ef4444' }}>{issue.duplicate_reports || 0}</div>
                    <div style={{ fontSize: '0.75rem', color: '#9ca3af' }}>Duplicates</div>
                  </div>
                </div>
                
                <div style={{ display: 'flex', gap: '0.5rem' }}>
                  <button 
                    onClick={() => handleConfirm(issue.id)}
                    className="btn-primary"
                    style={{ background: 'rgba(16, 185, 129, 0.2)', color: '#34d399', border: '1px solid rgba(16, 185, 129, 0.4)' }}
                  >
                    <CheckCircle size={16} /> Confirm Issue
                  </button>
                  <button 
                    onClick={() => handleDuplicate(issue.id)}
                    className="btn-primary"
                    style={{ background: 'rgba(239, 68, 68, 0.2)', color: '#fca5a5', border: '1px solid rgba(239, 68, 68, 0.4)' }}
                  >
                    <Copy size={16} /> Mark Duplicate
                  </button>
                </div>
              </div>
            </motion.div>
          ))}
        </AnimatePresence>
        {issues.length === 0 && (
          <div style={{ textAlign: 'center', color: '#9ca3af', padding: '2rem' }}>
            No community issues reported yet.
          </div>
        )}
      </div>
    </motion.div>
  );
};

export default CommunityFeed;
