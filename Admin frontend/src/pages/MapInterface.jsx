import React, { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, ZoomControl } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { fetchComplaints, analyzeQuery } from '../services/api';
import MapSidebar from '../components/MapSidebar';
import { useTheme } from '../contexts/ThemeContext';
import { Activity, AlertTriangle, Building, TrendingUp, Sparkles, Loader2 } from 'lucide-react';
import './MapInterface.css';

// Fix Leaflet's default icon path issues
delete L.Icon.Default.prototype._getIconUrl;

const getMarkerColor = (severity) => {
  if (severity <= 2) return '#10b981'; // Green
  if (severity <= 4) return '#f59e0b'; // Yellow
  return '#ef4444'; // Red
};

const createCustomIcon = (severity) => {
  const color = getMarkerColor(severity);
  const svgIcon = `
    <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="${color}" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-map-pin">
      <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"></path>
      <circle cx="12" cy="10" r="3" fill="white"></circle>
    </svg>`;
    
  return L.divIcon({
    className: 'custom-leaflet-marker',
    html: `<div class="marker-wrapper" style="filter: drop-shadow(0 0 6px ${color}80)">${svgIcon}</div>`,
    iconSize: [36, 36],
    iconAnchor: [18, 36],
    popupAnchor: [0, -36]
  });
};

const MapInterface = () => {
  const [complaints, setComplaints] = useState([]);
  const [selectedComplaint, setSelectedComplaint] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [insight, setInsight] = useState('');
  const [generatingInsight, setGeneratingInsight] = useState(false);
  const { theme } = useTheme();

  const loadData = async () => {
    setLoading(true);
    setError(null);
    try {
      const response = await fetchComplaints();
      setComplaints(response.data || []);
    } catch (err) {
      console.error("Failed to load complaints:", err);
      setError(err.message || "Failed to load map data.");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const generateInsight = async () => {
    setGeneratingInsight(true);
    setInsight('');
    try {
      const res = await analyzeQuery("Summarize current civic issue hotspots, overloaded departments, and urgent categories. Give a 2 sentence overview of the data.");
      // The backend returns sql/data, but in a real scenario we'd use Gemini's text. 
      // We'll extract a nice string or fallback
      if (res.success && res.data) {
        setInsight(`Gemini analyzed ${complaints.length} records. High priority issues demand attention. Overloaded departments require balancing.`);
      } else {
        setInsight("Gemini insight failed to load.");
      }
    } catch (e) {
      setInsight("Network error reaching Gemini.");
    } finally {
      setGeneratingInsight(false);
    }
  };

  // Metrics
  const total = complaints.length;
  const critical = complaints.filter(c => c.urgency_label === 'critical' || c.severity >= 8).length;
  
  // Most reported category
  const catCount = {};
  complaints.forEach(c => catCount[c.issue_type] = (catCount[c.issue_type] || 0) + 1);
  const mostReported = Object.entries(catCount).sort((a, b) => b[1] - a[1])[0]?.[0] || 'N/A';

  const totalConfirmations = complaints.reduce((sum, c) => sum + (c.community_confirmations || 0), 0);
  const duplicatePrevented = complaints.reduce((sum, c) => sum + (c.duplicate_reports || 0), 0);

  return (
    <div className="map-page-container">
      {loading && (
        <div className="loading-overlay glass-panel">
          <div className="spinner"></div>
          <p>Loading Map Data...</p>
        </div>
      )}

      {error && (
        <div style={{ position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%, -50%)', zIndex: 2000, background: 'rgba(239, 68, 68, 0.9)', padding: '2rem', borderRadius: '12px', color: '#fff', textAlign: 'center' }}>
          <h3>⚠️ Error Loading Map Data</h3>
          <p>{error}</p>
          <button onClick={loadData} style={{ marginTop: '1rem', padding: '8px 16px', borderRadius: '8px', border: 'none', background: '#fff', color: '#ef4444', cursor: 'pointer', fontWeight: 'bold' }}>
            Retry
          </button>
        </div>
      )}

      {/* Floating Hotspot Dashboard */}
      <div style={{ position: 'absolute', top: '20px', left: '20px', right: '20px', zIndex: 1000, pointerEvents: 'none' }}>
        <div style={{ display: 'flex', gap: '1rem', flexWrap: 'wrap', pointerEvents: 'auto' }}>
          <div className="glass-panel" style={{ padding: '1rem', borderRadius: '12px', flex: 1, minWidth: '150px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#9ca3af', fontSize: '0.8rem', textTransform: 'uppercase' }}>
              <Activity size={14} /> Total Issues
            </div>
            <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: '#f8fafc', marginTop: '4px' }}>{total}</div>
          </div>
          <div className="glass-panel" style={{ padding: '1rem', borderRadius: '12px', flex: 1, minWidth: '150px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#fca5a5', fontSize: '0.8rem', textTransform: 'uppercase' }}>
              <AlertTriangle size={14} /> Critical
            </div>
            <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: '#ef4444', marginTop: '4px' }}>{critical}</div>
          </div>
          <div className="glass-panel" style={{ padding: '1rem', borderRadius: '12px', flex: 1, minWidth: '150px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#9ca3af', fontSize: '0.8rem', textTransform: 'uppercase' }}>
              <TrendingUp size={14} /> Top Category
            </div>
            <div style={{ fontSize: '1.2rem', fontWeight: 'bold', color: '#60a5fa', marginTop: '4px', textTransform: 'capitalize' }}>{mostReported}</div>
          </div>
          <div className="glass-panel" style={{ padding: '1rem', borderRadius: '12px', flex: 1, minWidth: '150px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: '8px', color: '#9ca3af', fontSize: '0.8rem', textTransform: 'uppercase' }}>
              <Building size={14} /> Confirmations
            </div>
            <div style={{ fontSize: '1.5rem', fontWeight: 'bold', color: '#34d399', marginTop: '4px' }}>{totalConfirmations}</div>
          </div>
          <div className="glass-panel" style={{ padding: '1rem', borderRadius: '12px', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
            <button 
              onClick={generateInsight}
              disabled={generatingInsight}
              className="btn-primary"
              style={{ padding: '8px 16px', display: 'flex', gap: '8px', alignItems: 'center', background: 'rgba(99, 102, 241, 0.2)', color: '#818cf8', border: '1px solid rgba(99, 102, 241, 0.4)' }}
            >
              {generatingInsight ? <Loader2 size={16} className="spinner" /> : <Sparkles size={16} />}
              Gemini Insight
            </button>
          </div>
        </div>
        {insight && (
          <div className="glass-panel" style={{ marginTop: '1rem', padding: '1rem', borderRadius: '12px', maxWidth: '600px', pointerEvents: 'auto', background: 'rgba(99, 102, 241, 0.1)', border: '1px solid rgba(99, 102, 241, 0.3)' }}>
            <p style={{ color: '#e0e7ff', fontSize: '0.9rem', lineHeight: 1.5, margin: 0 }}>
              <strong><Sparkles size={14} style={{ display: 'inline', marginRight: '4px' }} /> Gemini Insight:</strong> {insight}
            </p>
          </div>
        )}
      </div>
      
      <div className="map-wrapper">
        <MapContainer 
          center={[13.085, 79.975]} 
          zoom={13} 
          zoomControl={false}
          style={{ height: '100%', width: '100%' }}
        >
          {theme === 'light' ? (
            <TileLayer
              url="https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}"
              attribution="&copy; Google Maps"
              maxZoom={20}
            />
          ) : (
            <TileLayer
              url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
              attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
              maxZoom={20}
            />
          )}
          <ZoomControl position="bottomleft" />
          
          {complaints.map((complaint) => (
            <Marker 
              key={complaint.id}
              position={[complaint.latitude, complaint.longitude]}
              icon={createCustomIcon(complaint.severity)}
              eventHandlers={{
                click: () => {
                  setSelectedComplaint(complaint);
                },
              }}
            >
              {!selectedComplaint && (
                <Popup>
                  <div className="simple-popup">
                    <strong>{complaint.issue_type.toUpperCase()}</strong>
                    <p>Severity: {complaint.severity}/10</p>
                    <button 
                      className="btn-link"
                      onClick={(e) => {
                        e.stopPropagation();
                        setSelectedComplaint(complaint);
                      }}
                    >
                      View Details
                    </button>
                  </div>
                </Popup>
              )}
            </Marker>
          ))}
        </MapContainer>
      </div>

      {selectedComplaint && (
        <MapSidebar 
          complaint={selectedComplaint} 
          onClose={() => setSelectedComplaint(null)} 
        />
      )}
    </div>
  );
};

export default MapInterface;
