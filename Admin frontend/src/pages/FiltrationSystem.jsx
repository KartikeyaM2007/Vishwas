import { Search, Filter as FilterIcon, ChevronUp, ChevronDown, CheckCircle, Clock, Download } from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import './FiltrationSystem.css';
import {useMemo, useState, useEffect} from 'react';
import {fetchComplaints} from '../services/api';

const FiltrationSystem = () => {
  const [complaints, setComplaints] = useState([]);
  const [loading, setLoading] = useState(true);

  // Filters State
  const [searchTerm, setSearchTerm] = useState('');
  const [filterType, setFilterType] = useState('all');
  const [filterStatus, setFilterStatus] = useState('all');
  const [filterSeverity, setFilterSeverity] = useState('all');
  
  // Sort State
  const [sortConfig, setSortConfig] = useState({ key: 'submitted_at', direction: 'desc' });

  useEffect(() => {
    const loadData = async () => {
      try {
        const response = await fetchComplaints();
        setComplaints(response.data);
        
      } catch (error) {
        console.error("Failed to load complaints:", error);
      } finally {
        setLoading(false);
      }
    };
    loadData();
  }, []);

  const handleSort = (key) => {
    let direction = 'asc';
    if (sortConfig.key === key && sortConfig.direction === 'asc') {
      direction = 'desc';
    }
    setSortConfig({ key, direction });
  };

  const filteredAndSortedData = useMemo(() => {
    let result = [...complaints];

    // Search text across multiple fields
    if (searchTerm) {
      const lowercasedSearch = searchTerm.toLowerCase();
      result = result.filter(item => 
        item.issue_type.toLowerCase().includes(lowercasedSearch) ||
        item.status.toLowerCase().includes(lowercasedSearch) ||
        item.id.toString().includes(lowercasedSearch) ||
        item.complaint_desc.toLowerCase().includes(lowercasedSearch) ||
        item.username.toLowerCase().includes(lowercasedSearch)
      );
    }

    // Exact matches
    if (filterType !== 'all') {
      result = result.filter(item => item.issue_type === filterType);
    }
    
    if (filterStatus !== 'all') {
      result = result.filter(item => item.status === filterStatus);
    }

    if (filterSeverity !== 'all') {
      if (filterSeverity === 'high') {
        result = result.filter(item => item.severity >= 7);
      } else if (filterSeverity === 'medium') {
        result = result.filter(item => item.severity >= 4 && item.severity < 7);
      } else {
        result = result.filter(item => item.severity < 4);
      }
    }

    // Sorting logic
    result.sort((a, b) => {
      if (a[sortConfig.key] < b[sortConfig.key]) {
        return sortConfig.direction === 'asc' ? -1 : 1;
      }
      if (a[sortConfig.key] > b[sortConfig.key]) {
        return sortConfig.direction === 'asc' ? 1 : -1;
      }
      return 0;
    });

    return result;
  }, [complaints, searchTerm, filterType, filterStatus, filterSeverity, sortConfig]);

  const handleExport = () => {
    // Define headers
    const headers = ["ID", "Type", "Reporter", "Latitude", "Longitude", "Department", "Severity", "Priority Score", "Confirmations", "Status", "Submitted At", "Description"];
    
    // Map data to rows
    const rows = filteredAndSortedData.map(item => [
      item.id,
      item.issue_type.replace('_', ' ').toUpperCase(),
      item.username,
      item.latitude,
      item.longitude,
      `"${item.department || ''}"`,
      item.severity,
      item.priority_score || item.severity,
      item.community_confirmations || 0,
      item.status.toUpperCase(),
      new Date(item.submitted_at).toLocaleString().replace(',', ''), // Remove comma to avoid CSV issues
      `"${item.complaint_desc.replace(/"/g, '""')}"` // Escape quotes and wrap in quotes
    ]);

    // Combine headers and rows
    const csvContent = [
      headers.join(','),
      ...rows.map(row => row.join(','))
    ].join('\n');

    // Create a blob and trigger download
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const link = document.createElement('a');
    const url = URL.createObjectURL(blob);
    
    link.setAttribute('href', url);
    link.setAttribute('download', `smart_city_complaints_${new Date().toISOString().split('T')[0]}.csv`);
    link.style.visibility = 'hidden';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  const SortIcon = ({ column }) => {
    if (sortConfig.key !== column) return <ChevronDown size={14} className="opacity-30" />;
    return sortConfig.direction === 'asc' ? <ChevronUp size={14} className="text-primary" /> : <ChevronDown size={14} className="text-primary" />;
  };

  return (
    <div className="filtration-container">
      <header className="page-header">
        <div>
          <h1>Complaint Database</h1>
          <p>Filter, sort, and manage all incoming smart city issues.</p>
        </div>
        <div className="header-actions">
          <div className="search-box">
            <Search size={18} className="search-icon" />
            <input 
              type="text" 
              placeholder="Search ID, Type, Description..." 
              value={searchTerm}
              onChange={(e) => setSearchTerm(e.target.value)}
              className="input-field"
            />
          </div>
        </div>
      </header>

      <div className="filters-row glass-card">
        <div className="filter-group">
          <label>Issue Type</label>
          <select className="select-field" value={filterType} onChange={(e) => setFilterType(e.target.value)}>
            <option value="all">All Types</option>
            <option value="garbage">Garbage</option>
            <option value="pothole">Pothole</option>
            <option value="streetlight">Streetlight</option>
            <option value="water_leak">Water Leak</option>
          </select>
        </div>
        
        <div className="filter-group">
          <label>Status</label>
          <select className="select-field" value={filterStatus} onChange={(e) => setFilterStatus(e.target.value)}>
            <option value="all">All Statuses</option>
            <option value="pending">Pending</option>
            <option value="resolved">Resolved</option>
          </select>
        </div>

        <div className="filter-group">
          <label>Severity Level</label>
          <select className="select-field" value={filterSeverity} onChange={(e) => setFilterSeverity(e.target.value)}>
            <option value="all">All Severities</option>
            <option value="high">High (7-10)</option>
            <option value="medium">Medium (4-6)</option>
            <option value="low">Low (1-3)</option>
          </select>
        </div>

        <button className="btn-reset" onClick={() => {
          setFilterType('all');
          setFilterStatus('all');
          setFilterSeverity('all');
          setSearchTerm('');
        }}>
          Reset Filters
        </button>
      </div>

      <div className="table-container glass-panel">
        {loading ? (
          <div className="table-loader">Loading Data...</div>
        ) : (
          <table className="data-table">
            <thead>
              <tr>
                <th onClick={() => handleSort('id')}>ID <SortIcon column="id" /></th>
                <th onClick={() => handleSort('issue_type')}>Type <SortIcon column="issue_type" /></th>
                <th>Reporter / Location</th>
                <th onClick={() => handleSort('department')}>Department <SortIcon column="department" /></th>
                <th onClick={() => handleSort('priority_score')}>Priority <SortIcon column="priority_score" /></th>
                <th onClick={() => handleSort('community_confirmations')}>Confirmations <SortIcon column="community_confirmations" /></th>
                <th onClick={() => handleSort('submitted_at')}>Submitted At <SortIcon column="submitted_at" /></th>
                <th onClick={() => handleSort('status')}>Status <SortIcon column="status" /></th>
              </tr>
            </thead>
            <tbody>
              <AnimatePresence>
                {filteredAndSortedData.map((row) => (
                  <motion.tr 
                    key={row.id}
                    initial={{ opacity: 0, y: 10 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.2 }}
                    className="table-row hover-glow"
                  >
                    <td>#{row.id}</td>
                    <td>
                      <span className="type-label">{row.issue_type.replace('_', ' ')}</span>
                    </td>
                    <td>
                      <div className="reporter-cell">
                        <strong>@{row.username}</strong>
                        <span className="location-coords">{row.latitude.toFixed(4)}, {row.longitude.toFixed(4)}</span>
                      </div>
                    </td>
                    <td>
                      <span className="type-label" style={{ backgroundColor: 'rgba(16, 185, 129, 0.1)' }}>
                        {row.department || 'General Civic Team'}
                      </span>
                    </td>
                    <td>
                      <div className="severity-bar-container">
                        <div 
                          className="severity-bar" 
                          style={{ 
                            width: `${Math.min((row.priority_score || row.severity) * 10, 100)}%`,
                            backgroundColor: (row.priority_score || row.severity) >= 15 ? '#ef4444' : (row.priority_score || row.severity) >= 8 ? '#f59e0b' : '#10b981'
                          }}
                        />
                        <span>{(row.priority_score || row.severity).toFixed(1)}/20</span>
                      </div>
                    </td>
                    <td>{row.community_confirmations || 0}</td>
                    <td>{new Date(row.submitted_at).toLocaleDateString()}</td>
                    <td>
                        {row.status}
                    </td>
                  </motion.tr>
                ))}
              </AnimatePresence>
              {filteredAndSortedData.length === 0 && (
                <tr>
                  <td colSpan="6" className="empty-state">
                    No complaints match your filters.
                  </td>
                </tr>
              )}
            </tbody>
          </table>
        )}
      </div>

      <motion.div 
        className="export-container"
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.5 }}
      >
        <button className="btn-primary btn-export hover-glow" onClick={handleExport}>
          <Download size={20} />
          Export to Excel (CSV)
        </button>
      </motion.div>
    </div>
  );
};

export default FiltrationSystem;
