import React, { useEffect, useMemo, useState } from 'react';
import { Link } from 'react-router-dom';
import { AlertTriangle, CheckCircle, ExternalLink, FileVideo, MapPin, RefreshCw, ShieldCheck, XCircle } from 'lucide-react';
import {
  approveComplaint,
  assignComplaint,
  fetchReviewQueue,
  rejectComplaint,
  requestMoreProof,
  updateAdminStatus,
} from '../services/api';
import { humanizeValue, statusBadgeStyle } from '../utils/civicFormat';

const mediaUrl = (item) => item.media_url || item.image_url;

const ReviewQueue = () => {
  const [items, setItems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [busyId, setBusyId] = useState(null);
  const [departmentDrafts, setDepartmentDrafts] = useState({});

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchReviewQueue();
      setItems(data.data || []);
    } catch (err) {
      setError(err.message || 'Failed to load review queue.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, []);

  const summary = useMemo(() => ({
    total: items.length,
    failClosed: items.filter((item) => item.validation_provider === 'fail_closed').length,
    videos: items.filter((item) => item.media_type === 'video').length,
  }), [items]);

  const runAction = async (item, label, action) => {
    const confirmed = window.confirm(`${label} complaint #${item.id}?`);
    if (!confirmed) return;
    setBusyId(item.id);
    try {
      await action();
      await load();
    } catch (err) {
      alert(err.message || `${label} failed`);
    } finally {
      setBusyId(null);
    }
  };

  const assign = async (item) => {
    const department = (departmentDrafts[item.id] || item.department || '').trim();
    if (!department) {
      alert('Enter a department first.');
      return;
    }
    setBusyId(item.id);
    try {
      await assignComplaint(item.id, { department });
      await load();
    } catch (err) {
      alert(err.message || 'Assign failed');
    } finally {
      setBusyId(null);
    }
  };

  return (
    <div className="page-container" style={{ padding: '2rem', maxWidth: '1280px', margin: '0 auto' }}>
      <header style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', alignItems: 'center', marginBottom: '1.5rem' }}>
        <div>
          <h1 style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
            <ShieldCheck color="#4f46e5" /> Review Queue
          </h1>
          <p style={{ color: 'var(--text-muted)' }}>Manual review for reports that AI could not safely verify.</p>
        </div>
        <button className="btn-primary" onClick={load}><RefreshCw size={16} /> Refresh</button>
      </header>

      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(190px, 1fr))', gap: '1rem', marginBottom: '1.5rem' }}>
        <div className="glass-panel" style={{ padding: '1rem' }}><strong>{summary.total}</strong><p style={{ color: 'var(--text-muted)' }}>Needs review</p></div>
        <div className="glass-panel" style={{ padding: '1rem' }}><strong>{summary.failClosed}</strong><p style={{ color: 'var(--text-muted)' }}>Fail-closed AI</p></div>
        <div className="glass-panel" style={{ padding: '1rem' }}><strong>{summary.videos}</strong><p style={{ color: 'var(--text-muted)' }}>Video/manual checks</p></div>
      </div>

      {loading && <p>Loading review queue...</p>}
      {error && <p style={{ color: 'var(--danger)' }}>{error}</p>}

      <div style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
        {!loading && items.map((item) => (
          <article key={item.id} className="glass-panel" style={{ padding: '1.25rem', display: 'grid', gridTemplateColumns: '160px 1fr', gap: '1rem' }}>
            <div>
              {mediaUrl(item) ? (
                item.media_type === 'video' ? (
                  <div style={{ height: '120px', display: 'grid', placeItems: 'center', border: '1px solid var(--border-color)', borderRadius: '8px' }}>
                    <FileVideo size={36} />
                  </div>
                ) : (
                  <img src={mediaUrl(item)} alt="Proof" style={{ width: '100%', height: '120px', objectFit: 'cover', borderRadius: '8px', cursor: 'pointer' }} onClick={() => window.open(mediaUrl(item), '_blank')} />
                )
              ) : (
                <div style={{ height: '120px', display: 'grid', placeItems: 'center', border: '1px solid var(--border-color)', borderRadius: '8px', color: 'var(--text-muted)' }}>No media</div>
              )}
            </div>

            <div style={{ minWidth: 0 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap' }}>
                <div>
                  <h3>{humanizeValue(item.issue_type)} <span style={{ color: 'var(--text-muted)' }}>#{item.id}</span></h3>
                  <p style={{ color: 'var(--text-muted)', lineHeight: 1.5 }}>{item.complaint_desc || 'No description provided.'}</p>
                </div>
                <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'flex-start', flexWrap: 'wrap' }}>
                  <span className="badge" style={statusBadgeStyle(item.status)}>{humanizeValue(item.status)}</span>
                  <span className="badge" style={statusBadgeStyle(item.validation_status)}>{humanizeValue(item.validation_status || 'unknown')}</span>
                </div>
              </div>

              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.75rem', margin: '1rem 0', color: 'var(--text-muted)', fontSize: '0.9rem' }}>
                <span>Provider: <strong>{item.validation_provider || 'unknown'}</strong></span>
                <span>Confidence: <strong>{item.validation_confidence ?? 'n/a'}</strong></span>
                <span>Media: <strong>{item.media_type || 'image'}</strong></span>
                <span>Citizen: <strong>{item.citizen_id || item.username || 'unknown'}</strong></span>
                <span>Confirmations: <strong>{item.community_confirmations || 0}</strong></span>
                <span>Duplicates: <strong>{item.duplicate_reports || 0}</strong></span>
                <span>Comments: <strong>{item.comments_count || 0}</strong></span>
                <span>Priority: <strong>{Number(item.priority_score || 0).toFixed(1)}</strong></span>
                <span>Created: <strong>{item.submitted_at ? new Date(item.submitted_at).toLocaleString() : 'unknown'}</strong></span>
              </div>

              {item.validation_reason && (
                <p style={{ color: 'var(--warning)', display: 'flex', alignItems: 'center', gap: '0.5rem' }}>
                  <AlertTriangle size={16} /> {item.validation_reason}
                </p>
              )}

              <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', marginTop: '1rem' }}>
                <a className="btn-primary" href={`https://www.google.com/maps?q=${item.latitude},${item.longitude}`} target="_blank" rel="noreferrer" style={{ textDecoration: 'none' }}>
                  <MapPin size={16} /> Open in Maps
                </a>
                <Link className="btn-primary" to={`/complaints/${item.id}`} style={{ textDecoration: 'none' }}>
                  <ExternalLink size={16} /> View Details
                </Link>
                <button className="btn-primary" disabled={busyId === item.id} onClick={() => runAction(item, 'Approve', () => approveComplaint(item.id, { note: 'Proof and location look valid.' }))}>
                  <CheckCircle size={16} /> Approve
                </button>
                <button className="btn-primary" disabled={busyId === item.id} onClick={() => runAction(item, 'Reject', () => rejectComplaint(item.id, { reason: 'Image does not show a valid matching civic issue.' }))} style={{ background: 'rgba(239,68,68,0.18)', color: '#ef4444' }}>
                  <XCircle size={16} /> Reject
                </button>
                <button className="btn-primary" disabled={busyId === item.id} onClick={() => runAction(item, 'Request more proof', () => requestMoreProof(item.id, { note: 'Please upload clearer photo/video of the actual issue.' }))}>
                  Request More Proof
                </button>
                <button className="btn-primary" disabled={busyId === item.id} onClick={() => runAction(item, 'Mark in progress', () => updateAdminStatus(item.id, { status: 'in_progress' }))}>
                  Mark In Progress
                </button>
                <button className="btn-primary" disabled={busyId === item.id} onClick={() => runAction(item, 'Resolve', () => updateAdminStatus(item.id, { status: 'resolved', note: 'Marked resolved by admin.' }))}>
                  Mark Resolved
                </button>
              </div>

              <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.75rem', maxWidth: '520px' }}>
                <input
                  className="input-field"
                  value={departmentDrafts[item.id] ?? item.department ?? ''}
                  onChange={(event) => setDepartmentDrafts((drafts) => ({ ...drafts, [item.id]: event.target.value }))}
                  placeholder="Assign department"
                />
                <button className="btn-primary" disabled={busyId === item.id} onClick={() => assign(item)}>Assign</button>
              </div>
            </div>
          </article>
        ))}
        {!loading && items.length === 0 && (
          <div className="glass-panel" style={{ padding: '2rem', textAlign: 'center', color: 'var(--text-muted)' }}>
            No manual review reports right now.
          </div>
        )}
      </div>
    </div>
  );
};

export default ReviewQueue;
