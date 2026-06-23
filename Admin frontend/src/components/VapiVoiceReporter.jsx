import React, { useState, useEffect } from 'react';
import Vapi from '@vapi-ai/web';
import { Mic, MicOff, Loader2, AlertCircle } from 'lucide-react';
import './VapiVoiceReporter.css'; // Optional simple CSS

const vapi = new Vapi(import.meta.env.VITE_VAPI_PUBLIC_KEY || '');

const VapiVoiceReporter = ({ onTranscriptUpdate }) => {
  const [callStatus, setCallStatus] = useState('idle');
  const [errorMsg, setErrorMsg] = useState('');
  const [geoLoc, setGeoLoc] = useState({ latitude: 0, longitude: 0 });

  // Check for env vars early
  const isSetup = import.meta.env.VITE_VAPI_PUBLIC_KEY && import.meta.env.VITE_VAPI_ASSISTANT_ID && 
                  import.meta.env.VITE_VAPI_PUBLIC_KEY !== 'your-vapi-public-key-here';

  useEffect(() => {
    // Attempt Geolocation
    if ('geolocation' in navigator) {
      navigator.geolocation.getCurrentPosition(
        (position) => {
          setGeoLoc({
            latitude: position.coords.latitude,
            longitude: position.coords.longitude
          });
        },
        (error) => {
          console.log("Geolocation permission denied or failed. Proceeding without location.", error);
        }
      );
    }

    // Setup Vapi Events
    vapi.on('call-start', () => setCallStatus('connecting'));
    vapi.on('call-end', () => setCallStatus('idle'));
    vapi.on('speech-start', () => setCallStatus('assistant speaking'));
    vapi.on('speech-end', () => setCallStatus('listening'));
    vapi.on('message', (message) => {
      if (message.type === 'transcript' && message.role === 'user') {
        onTranscriptUpdate(message.transcript);
      }
    });
    vapi.on('error', (e) => {
      console.error(e);
      setCallStatus('error');
      setErrorMsg(e.message || "An unknown Vapi error occurred.");
    });

    return () => {
      vapi.removeAllListeners();
    };
  }, [onTranscriptUpdate]);

  const toggleCall = async () => {
    if (callStatus === 'idle' || callStatus === 'error') {
      try {
        setCallStatus('connecting');
        setErrorMsg('');
        await vapi.start(import.meta.env.VITE_VAPI_ASSISTANT_ID, {
          variableValues: {
            user_lat: geoLoc.latitude.toString(),
            user_lng: geoLoc.longitude.toString()
          }
        });
        setCallStatus('listening');
      } catch (e) {
        console.error("Failed to start Vapi call", e);
        setCallStatus('error');
        setErrorMsg('Failed to connect to the Voice Assistant.');
      }
    } else {
      vapi.stop();
      setCallStatus('idle');
    }
  };

  if (!isSetup) {
    return (
      <div className="vapi-alert glass-card">
        <AlertCircle size={24} color="#f59e0b" />
        <div style={{marginLeft: '10px'}}>
          <h4>Voice Assistant Not Configured</h4>
          <p style={{fontSize: '0.9rem', color: '#888'}}>
            Please add VITE_VAPI_PUBLIC_KEY and VITE_VAPI_ASSISTANT_ID to your .env file to enable Voice Reporting.
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="vapi-reporter-container">
      <div className="status-banner">
        <span>Status: <strong style={{textTransform: 'capitalize'}}>{callStatus}</strong></span>
        {geoLoc.latitude !== 0 && (
          <span className="geo-badge">Location Acquired</span>
        )}
      </div>

      {errorMsg && (
        <div className="error-msg">{errorMsg}</div>
      )}

      <button 
        className={`vapi-mic-btn ${callStatus !== 'idle' && callStatus !== 'error' ? 'active' : ''}`}
        onClick={toggleCall}
      >
        {callStatus === 'connecting' ? (
          <Loader2 className="spinner" size={32} />
        ) : callStatus !== 'idle' && callStatus !== 'error' ? (
          <MicOff size={32} />
        ) : (
          <Mic size={32} />
        )}
      </button>

      <p className="helper-text">
        {callStatus !== 'idle' && callStatus !== 'error' 
          ? "Tap to end call" 
          : "Tap to report civic issue via voice"}
      </p>
    </div>
  );
};

export default VapiVoiceReporter;
