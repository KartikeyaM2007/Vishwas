import React, { useState, useEffect } from 'react';
import { MapContainer, TileLayer, Marker, Popup, ZoomControl } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { fetchComplaints } from '../services/api';
import MapSidebar from '../components/MapSidebar';
import { useTheme } from '../contexts/ThemeContext';
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
  const { theme } = useTheme();

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

  return (
    <div className="map-page-container">
      {loading && (
        <div className="loading-overlay glass-panel">
          <div className="spinner"></div>
          <p>Loading Map Data...</p>
        </div>
      )}
      
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
