import React, { useEffect, useState } from 'react';
// eslint-disable-next-line no-unused-vars
import { AnimatePresence, motion } from 'framer-motion';
import { Link } from 'react-router-dom';
import { AlertTriangle, Building, CheckCircle, Clock, Copy, ExternalLink, Image, MapPin, MessageCircle, Play } from 'lucide-react';
import ComplaintDiscussion from '../components/ComplaintDiscussion';
import { confirmComplaint, fetchComplaints, markDuplicate } from '../services/api';
import { humanizeValue, statusBadgeStyle } from '../utils/civicFormat';

const mediaUrl = (issue) => issue.media_url || issue.image_url;
const adminUser = { user_id: 'admin', username: 'Admin', user_role: 'admin', is_verified_user: true };

const CommunityFeed = () => {
  const [issues, setIssues] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [expandedId, setExpandedId] = useState(null);
  const [modalMedia, setModalMedia] = useState(null);

  const loadIssues = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchComplaints();
      setIssues(data.data || []);
    } catch (err) {
      setError(err.message || 'Failed to load community feed.');
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
      alert(err.message || 'Failed to confirm issue');
    }
  };

  const handleDuplicate = async (id) => {
    try {
      await markDuplicate(id);
      loadIssues();
    } catch (err) {
      alert(err.message || 'Failed to mark duplicate');
    }
  };

  if (loading) {
    return <div className="page-container" style={{ padding: '2rem', display: 'flex', justifyContent: 'center' }}><p>Loading community feed...</p></div>;
  }

  if (error) {
    return (
      <div className="page-container" style={{ padding: '2rem', display: 'flex', justifyContent: 'center' }}>
        <div style={{ textAlign: 'center', backgroundColor: 'rgba(239, 68, 68, 0.1)', padding: '2rem', borderRadius: '8px', border: '1px solid rgba(239, 68, 68, 0.2)', color: '#ef4444' }}>
          <h3>Error Loading Feed</h3>
          <p>{error}</p>
          <button onClick={loadIssues} className="btn-primary" style={{ marginTop: '1rem' }}>Retry</button>
        </div>
      </div>
    );
  }

  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="page-container"
      style={{ padding: '2rem', maxWidth: '980px', margin: '0 auto' }}
    >
      <header style={{ marginBottom: '2rem' }}>
        <h1 style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <Building color="#3b82f6" />
          Public Community Feed
        </h1>
        <p style={{ color: 'var(--text-muted)' }}>Discuss, confirm, and track civic reports from the community.</p>
      </header>

      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        <AnimatePresence>
          {issues.map((issue) => (
            <motion.article
              key={issue.id}
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, scale: 0.95 }}
              className="glass-panel"
              style={{ padding: '1.25rem', display: 'flex', flexDirection: 'column', gap: '1rem' }}
            >
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 128px', gap: '1rem', alignItems: 'start' }}>
                <div>
                  <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', flexWrap: 'wrap', marginBottom: '0.5rem' }}>
                    <h3 style={{ color: 'var(--text-main)' }}>{humanizeValue(issue.issue_type)}</h3>
                    <span className="badge" style={statusBadgeStyle(issue.status)}>{humanizeValue(issue.status)}</span>
                    {issue.urgency_label && <span className="badge pending">{humanizeValue(issue.urgency_label)}</span>}
                  </div>
                  <p style={{ color: 'var(--text-muted)', fontSize: '0.95rem', lineHeight: 1.55 }}>{issue.complaint_desc}</p>
                </div>

                <button
                  type="button"
                  onClick={() => mediaUrl(issue) && setModalMedia(issue)}
                  style={{ border: 0, padding: 0, background: 'transparent', cursor: mediaUrl(issue) ? 'pointer' : 'default' }}
                >
                  {mediaUrl(issue) ? (
                    issue.media_type === 'video' ? (
                      <div style={{ width: '128px', height: '96px', borderRadius: '8px', border: '1px solid var(--border-color)', display: 'grid', placeItems: 'center' }}>
                        <Play size={28} />
                      </div>
                    ) : (
                      <img src={mediaUrl(issue)} alt="Issue proof" style={{ width: '128px', height: '96px', objectFit: 'cover', borderRadius: '8px' }} />
                    )
                  ) : (
                    <div style={{ width: '128px', height: '96px', borderRadius: '8px', border: '1px solid var(--border-color)', display: 'grid', placeItems: 'center', color: 'var(--text-muted)' }}>
                      <Image size={24} />
                    </div>
                  )}
                </button>
              </div>

              <div style={{ display: 'flex', flexWrap: 'wrap', gap: '1rem', fontSize: '0.85rem', color: 'var(--text-muted)' }}>
                <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}><Building size={14} /> {issue.department || 'General'}</span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}><MapPin size={14} /> {Number(issue.latitude).toFixed(4)}, {Number(issue.longitude).toFixed(4)}</span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}><Clock size={14} /> {issue.submitted_at ? new Date(issue.submitted_at).toLocaleDateString() : 'Unknown'}</span>
                <span style={{ display: 'flex', alignItems: 'center', gap: '4px' }}><MessageCircle size={14} /> {issue.comments_count || 0} comments</span>
                {(Number(issue.latitude) === 0 && Number(issue.longitude) === 0) && <span className="badge danger">Invalid Location</span>}
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderTop: '1px solid var(--border-color)', paddingTop: '1rem', gap: '1rem', flexWrap: 'wrap' }}>
                <div style={{ display: 'flex', gap: '1.5rem' }}>
                  <Metric label="Priority" value={Number(issue.priority_score || 0).toFixed(1)} />
                  <Metric label="Confirmations" value={issue.community_confirmations || 0} color="#10b981" />
                  <Metric label="Duplicates" value={issue.duplicate_reports || 0} color="#ef4444" />
                </div>

                <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                  <button onClick={() => handleConfirm(issue.id)} className="btn-primary" style={{ background: 'rgba(16, 185, 129, 0.2)', color: '#059669' }}>
                    <CheckCircle size={16} /> Confirm Issue
                  </button>
                  <button onClick={() => handleDuplicate(issue.id)} className="btn-primary" style={{ background: 'rgba(239, 68, 68, 0.2)', color: '#dc2626' }}>
                    <Copy size={16} /> Mark Duplicate
                  </button>
                  <button onClick={() => setExpandedId(expandedId === issue.id ? null : issue.id)} className="btn-primary">
                    <MessageCircle size={16} /> {expandedId === issue.id ? 'Hide Discussion' : 'Expand Discussion'}
                  </button>
                  <Link to={`/complaints/${issue.id}`} className="btn-primary" style={{ textDecoration: 'none' }}>
                    <ExternalLink size={16} /> View Details
                  </Link>
                </div>
              </div>

              {expandedId === issue.id && (
                <div style={{ borderTop: '1px solid var(--border-color)', paddingTop: '1rem' }}>
                  <ComplaintDiscussion complaintId={issue.id} compact currentUser={adminUser} />
                </div>
              )}
            </motion.article>
          ))}
        </AnimatePresence>
        {issues.length === 0 && (
          <div style={{ textAlign: 'center', color: 'var(--text-muted)', padding: '2rem' }}>
            No community issues reported yet.
          </div>
        )}
      </div>

      {modalMedia && (
        <div onClick={() => setModalMedia(null)} style={{ position: 'fixed', inset: 0, background: 'rgba(15,23,42,0.75)', zIndex: 50, display: 'grid', placeItems: 'center', padding: '2rem' }}>
          <div onClick={(event) => event.stopPropagation()} className="glass-panel" style={{ maxWidth: '860px', width: '100%', padding: '1rem' }}>
            {modalMedia.media_type === 'video' ? (
              <video src={mediaUrl(modalMedia)} controls style={{ width: '100%', maxHeight: '70vh', borderRadius: '8px' }} />
            ) : (
              <img src={mediaUrl(modalMedia)} alt="Expanded proof" style={{ width: '100%', maxHeight: '70vh', objectFit: 'contain', borderRadius: '8px' }} />
            )}
          </div>
        </div>
      )}
    </motion.div>
  );
};

const Metric = ({ label, value, color = 'var(--text-main)' }) => (
  <div style={{ textAlign: 'center' }}>
    <div style={{ fontSize: '1.1rem', fontWeight: 'bold', color }}>{value}</div>
    <div style={{ fontSize: '0.75rem', color: 'var(--text-muted)' }}>{label}</div>
  </div>
);

export default CommunityFeed;
