import React, { useEffect, useState } from 'react';
import { MessageCircle, Reply, Send, ThumbsDown, ThumbsUp, Trash2 } from 'lucide-react';
import { addComment, deleteComment, fetchComments, replyToComment, voteComment } from '../services/api';

const defaultUser = {
  user_id: localStorage.getItem('citypulse_user_id') || 'admin_dashboard_user',
  username: localStorage.getItem('citypulse_username') || 'Guest Citizen',
  user_role: 'citizen',
  is_verified_user: false,
};

const roleLabel = (comment) => {
  if (comment.user_role === 'admin') return 'Admin';
  if (comment.is_verified_user) return 'Verified Citizen';
  return 'Mobile Citizen';
};

const CommentNode = ({ complaintId, comment, currentUser, depth = 0, onChanged }) => {
  const [replying, setReplying] = useState(false);
  const [replyBody, setReplyBody] = useState('');

  const submitReply = async () => {
    if (!replyBody.trim()) return;
    await replyToComment(complaintId, comment.id, { ...currentUser, body: replyBody });
    setReplyBody('');
    setReplying(false);
    onChanged();
  };

  const vote = async (direction) => {
    await voteComment(comment.id, direction);
    onChanged();
  };

  const remove = async () => {
    if (!window.confirm('Delete this comment?')) return;
    await deleteComment(comment.id);
    onChanged();
  };

  return (
    <div style={{ marginLeft: depth ? '1rem' : 0, borderLeft: depth ? '2px solid var(--border-color)' : 'none', paddingLeft: depth ? '1rem' : 0 }}>
      <div style={{ padding: '0.85rem 0', borderBottom: '1px solid var(--border-color)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem' }}>
          <div>
            <strong>{comment.username || 'Guest Citizen'}</strong>
            <span className="badge pending" style={{ marginLeft: '0.5rem', fontSize: '0.65rem' }}>{roleLabel(comment)}</span>
          </div>
          <span style={{ color: 'var(--text-muted)', fontSize: '0.8rem' }}>
            {comment.created_at ? new Date(comment.created_at).toLocaleString() : ''}
          </span>
        </div>
        <p style={{ color: 'var(--text-main)', margin: '0.55rem 0', lineHeight: 1.5 }}>{comment.body}</p>
        <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
          <button className="btn-primary" onClick={() => vote('upvote')} style={{ padding: '0.45rem 0.7rem' }}>
            <ThumbsUp size={14} /> {comment.upvotes || 0}
          </button>
          <button className="btn-primary" onClick={() => vote('downvote')} style={{ padding: '0.45rem 0.7rem', background: 'rgba(239,68,68,0.16)', color: '#ef4444' }}>
            <ThumbsDown size={14} /> {comment.downvotes || 0}
          </button>
          {depth < 2 && (
            <button className="btn-primary" onClick={() => setReplying((value) => !value)} style={{ padding: '0.45rem 0.7rem' }}>
              <Reply size={14} /> Reply
            </button>
          )}
          <button className="btn-primary" onClick={remove} style={{ padding: '0.45rem 0.7rem', background: 'rgba(100,116,139,0.18)', color: 'var(--text-muted)' }}>
            <Trash2 size={14} /> Delete
          </button>
        </div>
        {replying && (
          <div style={{ display: 'flex', gap: '0.5rem', marginTop: '0.75rem' }}>
            <input
              className="input-field"
              value={replyBody}
              maxLength={1000}
              onChange={(event) => setReplyBody(event.target.value)}
              placeholder="Write a reply"
            />
            <button className="btn-primary" onClick={submitReply}><Send size={16} /></button>
          </div>
        )}
      </div>
      {(comment.replies || []).slice(0, depth < 2 ? undefined : 0).map((reply) => (
        <CommentNode key={reply.id} complaintId={complaintId} comment={reply} currentUser={currentUser} depth={depth + 1} onChanged={onChanged} />
      ))}
    </div>
  );
};

const ComplaintDiscussion = ({ complaintId, compact = false, currentUser = defaultUser }) => {
  const [comments, setComments] = useState([]);
  const [sort, setSort] = useState('newest');
  const [body, setBody] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const load = async () => {
    setLoading(true);
    setError('');
    try {
      const data = await fetchComments(complaintId, sort);
      setComments(data.data || []);
    } catch (err) {
      setError(err.message || 'Unable to load discussion.');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (complaintId) load();
  }, [complaintId, sort]);

  const submit = async () => {
    if (!body.trim()) return;
    try {
      await addComment(complaintId, { ...currentUser, body });
      setBody('');
      load();
    } catch (err) {
      setError(err.message || 'Unable to add comment.');
    }
  };

  return (
    <section style={{ display: 'flex', flexDirection: 'column', gap: '1rem' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap', alignItems: 'center' }}>
        <h3 style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
          <MessageCircle size={20} /> Discussion
        </h3>
        <select className="input-field" value={sort} onChange={(event) => setSort(event.target.value)} style={{ width: '180px' }}>
          <option value="newest">Newest</option>
          <option value="top">Top</option>
          <option value="verified">Verified first</option>
          <option value="oldest">Oldest</option>
        </select>
      </div>
      <div style={{ display: 'flex', gap: '0.5rem' }}>
        <input
          className="input-field"
          value={body}
          maxLength={1000}
          onChange={(event) => setBody(event.target.value)}
          placeholder="Add a community comment"
        />
        <button className="btn-primary" onClick={submit}><Send size={16} /> Comment</button>
      </div>
      {error && <p style={{ color: 'var(--danger)' }}>{error}</p>}
      {loading && <p style={{ color: 'var(--text-muted)' }}>Loading discussion...</p>}
      {!loading && comments.length === 0 && <p style={{ color: 'var(--text-muted)' }}>{compact ? 'No comments yet.' : 'No discussion yet.'}</p>}
      {comments.map((comment) => (
        <CommentNode key={comment.id} complaintId={complaintId} comment={comment} currentUser={currentUser} onChanged={load} />
      ))}
    </section>
  );
};

export default ComplaintDiscussion;
