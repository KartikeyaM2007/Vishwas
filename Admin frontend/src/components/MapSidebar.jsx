import React, { useState } from 'react';
import { X, MapPin, Calendar, AlertCircle, Upload, CheckCircle2, Loader2, Users, Activity, Tag } from 'lucide-react';
import NeumorphicAlert from './NeumorphicAlert';
import './MapSidebar.css';

const MapSidebar = ({ complaint, onClose }) => {
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [status, setStatus] = useState(complaint?.status || 'pending');
  const [selectedFile, setSelectedFile] = useState(null);
  const [previewUrl, setPreviewUrl] = useState(null);
  const [alertState, setAlertState] = useState({ isOpen: false, message: '', type: 'info' });

  const showAlert = (message, type = 'info') => {
    setAlertState({ isOpen: true, message, type });
  };

  if (!complaint) return null;

  const handleFileChange = (e) => {
    const file = e.target.files[0];
    if (file) {
      setSelectedFile(file);
      setPreviewUrl(URL.createObjectURL(file));
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!selectedFile) {
      showAlert("Please upload a resolved image.", "warning");
      return;
    }

    setIsSubmitting(true);

    try {
      // Import updateComplaintStatus from api.js or just use VITE_API_BASE_URL
      const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000';
      const formData = new FormData();
      formData.append('complaint_id', complaint.id);
      formData.append('status', status);
      formData.append('resolved_image', selectedFile);

      const response = await fetch(`${API_BASE_URL}/update-complaint`, {
        method: 'PUT',
        body: formData,
      });

      const data = await response.json();
      if (data.success || response.ok) {
        showAlert("Complaint updated successfully!", "success");
        setIsModalOpen(false);
        // Optionally trigger a refresh of the complaint data here
      } else {
        showAlert(`Error: ${data.error || 'Failed to update complaint'}`, "error");
      }
    } catch (error) {
      console.error("Error updating complaint:", error);
      showAlert("An error occurred while updating the complaint.", "error");
    } finally {
      setIsSubmitting(false);
    }
  };


  return (
    <>
      <AnimatePresence>
        {complaint && (
          <motion.div
            initial={{ x: '100%' }}
            animate={{ x: 0 }}
            exit={{ x: '100%' }}
            transition={{ type: 'spring', damping: 25, stiffness: 200 }}
            className="map-sidebar glass-panel"
          >
        <button onClick={onClose} className="close-btn hover-glow">
          <X size={20} />
        </button>

        <div className="sidebar-content">
          <div className="image-container">
            <img 
              src={complaint.image_url} 
              alt="Complaint Evidence" 
              className="complaint-image"
            />
            <div className={`status-badge ${complaint.status.toLowerCase()}`}>
              {complaint.status}
            </div>
          </div>

          <div className="details-section">
            <h2 className="complaint-title">
              {complaint.issue_type.replace('_', ' ').toUpperCase()}
            </h2>
            
            <div className="user-row">
              <span className="user-name">@{complaint.username}</span>
              <div className="severity-indicator">
                <AlertCircle size={16} />
                <span>Priority: {complaint.priority_score || complaint.severity}/10</span>
              </div>
            </div>

            <div className="meta-info">
              <div className="meta-item">
                <Tag size={16} />
                <span>{complaint.department || 'General Civic Team'}</span>
              </div>
              <div className="meta-item">
                <Activity size={16} />
                <span style={{ textTransform: 'capitalize' }}>Urgency: {complaint.urgency_label || 'medium'}</span>
              </div>
              <div className="meta-item">
                <Users size={16} />
                <span>Confirmations: {complaint.community_confirmations || 0}</span>
              </div>
              <div className="meta-item">
                <MapPin size={16} />
                <span>{complaint.latitude.toFixed(4)}, {complaint.longitude.toFixed(4)}</span>
              </div>
              <div className="meta-item">
                <Calendar size={16} />
                <span>{new Date(complaint.submitted_at).toLocaleString()}</span>
              </div>
            </div>

            <div className="description-box glass-card" style={{ marginBottom: '10px' }}>
              <h3>AI Summary</h3>
              <p>{complaint.complaint_desc}</p>
            </div>

            {complaint.admin_action_recommendation && (
              <div className="description-box glass-card admin-rec" style={{ background: 'rgba(255, 152, 0, 0.1)', borderLeft: '4px solid #ff9800' }}>
                <h3 style={{ color: '#ff9800' }}>Admin Recommendation</h3>
                <p>{complaint.admin_action_recommendation}</p>
              </div>
            )}
            
            <div className="action-buttons">
              <button 
                className="btn-primary" 
                style={{ width: '100%', justifyContent: 'center' }}
                onClick={() => setIsModalOpen(true)}
              >
                Update Status
              </button>
            </div>
          </div>
        </div>
      </motion.div>
    )}
  </AnimatePresence>

  {/* Update Status Modal */}
  <AnimatePresence>
    {isModalOpen && (
      <motion.div 
        className="modal-overlay"
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        exit={{ opacity: 0 }}
        onClick={() => setIsModalOpen(false)}
      >
        <motion.div 
          className="status-modal glass-panel"
          initial={{ scale: 0.9, opacity: 0, y: 20 }}
          animate={{ scale: 1, opacity: 1, y: 0 }}
          exit={{ scale: 0.9, opacity: 0, y: 20 }}
          style={{ position: 'relative', zIndex: 3001 }}
          onClick={(e) => e.stopPropagation()}
        >
          <div className="modal-header">
            <h3>Update Complaint Status</h3>
            <button onClick={() => setIsModalOpen(false)} className="close-modal-btn">
              <X size={18} />
            </button>
          </div>

          <form onSubmit={handleSubmit} className="status-form">
            <div className="form-group">
              <label>Resolution Status</label>
              <select 
                value={status} 
                onChange={(e) => setStatus(e.target.value)}
                className="status-select"
              >
                <option value="pending">Pending</option>
                <option value="onprogress">On Progress</option>
                <option value="solved">Resolved</option>
                <option value="rejected">Rejected</option>
              </select>
            </div>

            <div className="form-group">
              <label>Resolved Image</label>
              <div className="file-upload-container">
                <input 
                  type="file" 
                  id="resolved-image" 
                  accept="image/*" 
                  onChange={handleFileChange}
                  style={{ display: 'none' }}
                />
                <label htmlFor="resolved-image" className="file-upload-label">
                  {previewUrl ? (
                    <img src={previewUrl} alt="Preview" className="upload-preview" />
                  ) : (
                    <div className="upload-placeholder">
                      <Upload size={24} />
                      <span>Upload Resolution Image</span>
                    </div>
                  )}
                </label>
              </div>
            </div>

            <button 
              type="submit" 
              className="submit-btn" 
              disabled={isSubmitting}
            >
              {isSubmitting ? (
                <>
                  <Loader2 className="spinner" size={18} />
                  Updating...
                </>
              ) : (
                <>
                  <CheckCircle2 size={18} />
                  Submit Update
                </>
              )}
            </button>
          </form>
        </motion.div>
      </motion.div>
    )}
  </AnimatePresence>

  <NeumorphicAlert 
    isOpen={alertState.isOpen} 
    message={alertState.message} 
    type={alertState.type} 
    onClose={() => setAlertState(prev => ({ ...prev, isOpen: false }))} 
  />
</>
);
};

export default MapSidebar;
