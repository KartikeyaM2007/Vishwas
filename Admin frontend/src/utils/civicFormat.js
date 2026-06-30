export const humanizeValue = (value) => {
  const text = (value || 'unknown').toString().replace(/_/g, ' ').trim();
  return text ? text.replace(/\b\w/g, (char) => char.toUpperCase()) : 'Unknown';
};

export const statusTone = (status) => {
  const value = (status || '').toString().toLowerCase();
  if (value === 'pending' || value === 'open') return 'pending';
  if (value === 'manual_review') return 'manualReview';
  if (value === 'needs_more_proof') return 'needsMoreProof';
  if (value === 'approved' || value === 'verified' || value === 'admin_approved') return 'approved';
  if (value === 'resolved' || value === 'solved') return 'resolved';
  if (value === 'rejected' || value === 'fake' || value === 'spam') return 'rejected';
  if (value === 'in_progress') return 'inProgress';
  return 'neutral';
};

export const statusBadgeStyle = (status) => {
  const tone = statusTone(status);
  const styles = {
    pending: { background: 'rgba(245, 158, 11, 0.16)', color: '#b45309', border: '1px solid rgba(245, 158, 11, 0.34)' },
    manualReview: { background: 'rgba(249, 115, 22, 0.16)', color: '#c2410c', border: '1px solid rgba(249, 115, 22, 0.34)' },
    approved: { background: 'rgba(14, 165, 233, 0.16)', color: '#0369a1', border: '1px solid rgba(14, 165, 233, 0.34)' },
    resolved: { background: 'rgba(16, 185, 129, 0.16)', color: '#047857', border: '1px solid rgba(16, 185, 129, 0.34)' },
    rejected: { background: 'rgba(239, 68, 68, 0.16)', color: '#dc2626', border: '1px solid rgba(239, 68, 68, 0.34)' },
    needsMoreProof: { background: 'rgba(168, 85, 247, 0.16)', color: '#7e22ce', border: '1px solid rgba(168, 85, 247, 0.34)' },
    inProgress: { background: 'rgba(59, 130, 246, 0.16)', color: '#1d4ed8', border: '1px solid rgba(59, 130, 246, 0.34)' },
    neutral: { background: 'rgba(100, 116, 139, 0.16)', color: 'var(--text-muted)', border: '1px solid var(--border-color)' },
  };
  return styles[tone];
};
