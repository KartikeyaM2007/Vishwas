import React, { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { ArrowLeft, ExternalLink, MapPin, ShieldCheck } from 'lucide-react';
import ComplaintDiscussion from '../components/ComplaintDiscussion';
import {
  approveComplaint,
  fetchComplaint,
  rejectComplaint,
  requestMoreProof,
  updateAdminStatus,
} from '../services/api';
import { humanizeValue, statusBadgeStyle } from '../utils/civicFormat';

const adminUser = { user_id: 'admin', username: 'Admin', user_role: 'admin', is_verified_user: true };

const ComplaintDetail = () => {
  const { id } = useParams();
  const [complaint, setComplaint] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchComplaint(id);
      setComplaint(data.data);
    } catch (err) {
      setError(err.message || 'Failed to load complaint.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    load();
  }, [id]);

  const run = async (label, action) => {
    if (!window.confirm(`${label} complaint #${id}?`)) return;
    try {
      await action();
      await load();
    } catch (err) {
      alert(err.message || `${label} failed`);
    }
  };

  const mediaUrl = complaint?.media_url || complaint?.image_url;
  const validation = complaint?.ai_metadata?.validation || {};

  return (
    <div className="page-container" style={{ padding: '2rem', maxWidth: '1180px', margin: '0 auto' }}>
      <Link to="/community" style={{ display: 'inline-flex', alignItems: 'center', gap: '0.5rem', color: 'var(--text-muted)', marginBottom: '1rem' }}>
        <ArrowLeft size={16} /> Back to Community
      </Link>

      {loading && <p>Loading complaint...</p>}
      {error && <p style={{ color: 'var(--danger)' }}>{error}</p>}

      {complaint && (
        <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1.2fr) minmax(320px, 0.8fr)', gap: '1rem', alignItems: 'start' }}>
          <main className="glass-panel" style={{ padding: '1.5rem' }}>
            <header style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap', marginBottom: '1rem' }}>
              <div>
                <h1>{humanizeValue(complaint.issue_type)} <span style={{ color: 'var(--text-muted)' }}>#{complaint.id}</span></h1>
                <p style={{ color: 'var(--text-muted)', lineHeight: 1.6 }}>{complaint.complaint_desc || 'No description provided.'}</p>
              </div>
              <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'flex-start', flexWrap: 'wrap' }}>
                <span className="badge" style={statusBadgeStyle(complaint.status)}>{humanizeValue(complaint.status)}</span>
                <span className="badge" style={statusBadgeStyle(complaint.validation_status)}>{humanizeValue(complaint.validation_status)}</span>
              </div>
            </header>

            {mediaUrl && (
              complaint.media_type === 'video' ? (
                <video src={mediaUrl} controls style={{ width: '100%', maxHeight: '420px', borderRadius: '8px', border: '1px solid var(--border-color)' }} />
              ) : (
                <img src={mediaUrl} alt="Complaint proof" style={{ width: '100%', maxHeight: '420px', objectFit: 'cover', borderRadius: '8px', cursor: 'pointer' }} onClick={() => window.open(mediaUrl, '_blank')} />
              )
            )}

            <section style={{ marginTop: '1.25rem', display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: '0.75rem' }}>
              <Info label="Citizen" value={complaint.citizen_id || complaint.username} />
              <Info label="Department" value={complaint.department} />
              <Info label="Priority" value={Number(complaint.priority_score || 0).toFixed(1)} />
              <Info label="Confirmations" value={complaint.community_confirmations || 0} />
              <Info label="Duplicates" value={complaint.duplicate_reports || 0} />
              <Info label="Comments" value={complaint.comments_count || 0} />
              <Info label="Reward Eligible" value={complaint.reward_eligible ? 'Yes' : 'No'} />
              <Info label="Created" value={complaint.submitted_at ? new Date(complaint.submitted_at).toLocaleString() : 'unknown'} />
            </section>

            <section style={{ marginTop: '1.25rem' }}>
              <h3 style={{ display: 'flex', alignItems: 'center', gap: '0.5rem' }}><ShieldCheck size={20} /> AI Validation</h3>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '0.75rem', marginTop: '0.75rem' }}>
                <Info label="Provider" value={complaint.validation_provider || validation.provider || 'unknown'} />
                <Info label="Confidence" value={complaint.validation_confidence ?? validation.confidence ?? 'n/a'} />
                <Info label="Visible Issue" value={validation.visible_issue || 'n/a'} />
                <Info label="Detected Type" value={validation.detected_issue_type || 'n/a'} />
                <Info label="Recommendation" value={validation.recommendation || 'n/a'} />
              </div>
              {(complaint.validation_reason || validation.mismatch_reason) && (
                <p style={{ marginTop: '0.75rem', color: 'var(--warning)' }}>{complaint.validation_reason || validation.mismatch_reason}</p>
              )}
            </section>

            <section style={{ marginTop: '1.5rem' }}>
              <ComplaintDiscussion complaintId={complaint.id} currentUser={adminUser} />
            </section>
          </main>

          <aside style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
            <section className="glass-panel" style={{ padding: '1.25rem' }}>
              <h3>Admin Actions</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.6rem', marginTop: '1rem' }}>
                <button className="btn-primary" onClick={() => run('Approve', () => approveComplaint(id, { note: 'Proof and location look valid.' }))}>Approve Report</button>
                <button className="btn-primary" onClick={() => run('Reject', () => rejectComplaint(id, { reason: 'Image does not show a valid matching civic issue.' }))} style={{ background: 'rgba(239,68,68,0.18)', color: '#ef4444' }}>Reject as Fake/Invalid</button>
                <button className="btn-primary" onClick={() => run('Request more proof', () => requestMoreProof(id, { note: 'Please upload clearer photo/video of the actual issue.' }))}>Request More Proof</button>
                <button className="btn-primary" onClick={() => run('Mark in progress', () => updateAdminStatus(id, { status: 'in_progress' }))}>Mark In Progress</button>
                <button className="btn-primary" onClick={() => run('Resolve', () => updateAdminStatus(id, { status: 'resolved', note: 'Marked resolved by admin.' }))}>Mark Resolved</button>
              </div>
            </section>

            <section className="glass-panel" style={{ padding: '1.25rem' }}>
              <h3>Location</h3>
              <p style={{ color: 'var(--text-muted)', margin: '0.75rem 0' }}>{complaint.latitude}, {complaint.longitude}</p>
              {Number(complaint.latitude) === 0 && Number(complaint.longitude) === 0 ? (
                  <span className="badge" style={statusBadgeStyle('rejected')}>Invalid Location</span>
              ) : (
                <a className="btn-primary" href={`https://www.google.com/maps?q=${complaint.latitude},${complaint.longitude}`} target="_blank" rel="noreferrer" style={{ textDecoration: 'none' }}>
                  <MapPin size={16} /> Open in Maps <ExternalLink size={14} />
                </a>
              )}
            </section>

            <section className="glass-panel" style={{ padding: '1.25rem' }}>
              <h3>Audit Timeline</h3>
              <div style={{ display: 'flex', flexDirection: 'column', gap: '0.75rem', marginTop: '1rem' }}>
                <TimelineItem label="Submitted" note={complaint.submitted_at ? new Date(complaint.submitted_at).toLocaleString() : ''} />
                {(complaint.audit_logs || []).map((log) => (
                  <TimelineItem key={log.id} label={humanizeValue(log.action)} note={log.note || `${humanizeValue(log.old_status)} -> ${humanizeValue(log.new_status)}`} />
                ))}
              </div>
            </section>
          </aside>
        </div>
      )}
    </div>
  );
};

const Info = ({ label, value }) => (
  <div style={{ border: '1px solid var(--border-color)', borderRadius: '8px', padding: '0.75rem' }}>
    <div style={{ color: 'var(--text-muted)', fontSize: '0.78rem' }}>{label}</div>
    <strong>{value ?? 'unknown'}</strong>
  </div>
);

const TimelineItem = ({ label, note }) => (
  <div style={{ borderLeft: '2px solid var(--primary)', paddingLeft: '0.75rem' }}>
    <strong>{label}</strong>
    {note && <p style={{ color: 'var(--text-muted)' }}>{note}</p>}
  </div>
);

export default ComplaintDetail;
