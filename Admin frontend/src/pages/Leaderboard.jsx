import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { fetchComplaints } from '../services/api';
import { Trophy, Award, Star, Shield, TrendingUp } from 'lucide-react';

const Leaderboard = () => {
  const [issues, setIssues] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await fetchComplaints();
      setIssues(data.data || []);
    } catch (err) {
      console.error("Failed to load leaderboard data", err);
      setError(err.message || "Failed to load leaderboard data.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  if (loading) {
    return <div className="page-container" style={{ padding: '2rem', textAlign: 'center' }}>Loading Leaderboard...</div>;
  }

  if (error) {
    return (
      <div className="page-container" style={{ padding: '2rem', display: 'flex', justifyContent: 'center' }}>
        <div style={{ textAlign: 'center', backgroundColor: 'rgba(239, 68, 68, 0.1)', padding: '2rem', borderRadius: '12px', border: '1px solid rgba(239, 68, 68, 0.2)', color: '#ef4444' }}>
          <h3>⚠️ Error Loading Leaderboard</h3>
          <p>{error}</p>
          <button onClick={loadData} className="btn-primary" style={{ marginTop: '1rem', background: 'rgba(239, 68, 68, 0.2)', color: '#ef4444' }}>
            Retry
          </button>
        </div>
      </div>
    );
  }

  // Calculate Metrics
  const totalConfirmations = issues.reduce((sum, issue) => sum + (issue.community_confirmations || 0), 0);
  const totalResolved = issues.filter(issue => issue.status === 'solved').length;

  // Calculate User Stats
  const userStats = {};
  issues.forEach(issue => {
    const user = issue.username || 'Anonymous';
    if (!userStats[user]) {
      userStats[user] = {
        username: user,
        reportCount: 0,
        confirmationsReceived: 0,
        categories: new Set()
      };
    }
    userStats[user].reportCount += 1;
    userStats[user].confirmationsReceived += (issue.community_confirmations || 0);
    userStats[user].categories.add(issue.issue_type);
  });

  const sortedUsers = Object.values(userStats).sort((a, b) => b.reportCount - a.reportCount);

  // Badge Checkers
  const getBadges = (stats) => {
    const badges = [];
    if (stats.reportCount >= 5) badges.push({ name: 'Community Hero', icon: <Trophy size={16} color="#fbbf24" />, desc: '5+ Reports' });
    if (stats.categories.has('streetlight')) badges.push({ name: 'Streetlight Watcher', icon: <Star size={16} color="#fcd34d" />, desc: 'Reported Streetlight' });
    if (stats.categories.has('garbage')) badges.push({ name: 'Sanitation Hero', icon: <Shield size={16} color="#34d399" />, desc: 'Reported Garbage' });
    if (stats.categories.has('pothole')) badges.push({ name: 'Road Guardian', icon: <Award size={16} color="#60a5fa" />, desc: 'Reported Pothole' });
    if (stats.confirmationsReceived >= 5) badges.push({ name: 'Trusted Reporter', icon: <TrendingUp size={16} color="#a78bfa" />, desc: 'High Confirmations' });
    return badges;
  };

  return (
    <motion.div 
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      className="page-container"
      style={{ padding: '2rem', maxWidth: '900px', margin: '0 auto' }}
    >
      <header style={{ marginBottom: '2rem' }}>
        <h1 style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <Trophy color="#fbbf24" /> 
          Citizen Leaderboard
        </h1>
        <p style={{ color: '#9ca3af' }}>
          Recognizing the most active and trusted community members.
        </p>
      </header>

      {/* Top Metrics Cards */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
        <div className="glass-panel" style={{ padding: '1.5rem', borderRadius: '12px', textAlign: 'center' }}>
          <div style={{ fontSize: '2rem', fontWeight: 'bold', color: '#f8fafc' }}>{sortedUsers.length}</div>
          <div style={{ color: '#9ca3af', fontSize: '0.9rem' }}>Active Citizens</div>
        </div>
        <div className="glass-panel" style={{ padding: '1.5rem', borderRadius: '12px', textAlign: 'center' }}>
          <div style={{ fontSize: '2rem', fontWeight: 'bold', color: '#34d399' }}>{totalConfirmations}</div>
          <div style={{ color: '#9ca3af', fontSize: '0.9rem' }}>Community Confirmations</div>
        </div>
        <div className="glass-panel" style={{ padding: '1.5rem', borderRadius: '12px', textAlign: 'center' }}>
          <div style={{ fontSize: '2rem', fontWeight: 'bold', color: '#60a5fa' }}>{totalResolved}</div>
          <div style={{ color: '#9ca3af', fontSize: '0.9rem' }}>Issues Resolved</div>
        </div>
      </div>

      {/* Leaderboard Table */}
      <div className="glass-panel" style={{ borderRadius: '16px', overflow: 'hidden' }}>
        <table style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
          <thead>
            <tr style={{ background: 'rgba(255,255,255,0.05)', color: '#9ca3af', fontSize: '0.85rem', textTransform: 'uppercase' }}>
              <th style={{ padding: '1rem' }}>Rank</th>
              <th style={{ padding: '1rem' }}>Citizen</th>
              <th style={{ padding: '1rem' }}>Reports</th>
              <th style={{ padding: '1rem' }}>Confirmations</th>
              <th style={{ padding: '1rem' }}>Earned Badges</th>
            </tr>
          </thead>
          <tbody>
            {sortedUsers.map((user, index) => {
              const badges = getBadges(user);
              return (
                <tr key={user.username} style={{ borderTop: '1px solid rgba(255,255,255,0.05)' }}>
                  <td style={{ padding: '1rem', fontWeight: 'bold', color: index < 3 ? '#fbbf24' : '#f8fafc' }}>
                    #{index + 1}
                  </td>
                  <td style={{ padding: '1rem', color: '#f8fafc' }}>{user.username}</td>
                  <td style={{ padding: '1rem', color: '#60a5fa', fontWeight: 'bold' }}>{user.reportCount}</td>
                  <td style={{ padding: '1rem', color: '#34d399', fontWeight: 'bold' }}>{user.confirmationsReceived}</td>
                  <td style={{ padding: '1rem', display: 'flex', gap: '0.5rem', flexWrap: 'wrap' }}>
                    {badges.map(b => (
                      <div key={b.name} title={b.desc} style={{
                        display: 'flex', alignItems: 'center', gap: '4px', padding: '4px 8px',
                        background: 'rgba(255,255,255,0.1)', borderRadius: '12px', fontSize: '0.75rem', color: '#e2e8f0'
                      }}>
                        {b.icon} {b.name}
                      </div>
                    ))}
                    {badges.length === 0 && <span style={{ color: '#64748b', fontSize: '0.8rem' }}>None yet</span>}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </motion.div>
  );
};

export default Leaderboard;
