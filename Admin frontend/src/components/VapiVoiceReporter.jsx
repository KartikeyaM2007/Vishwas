import React, { useState, useEffect, useRef } from 'react';
import { Mic, MicOff, Loader2, AlertCircle } from 'lucide-react';
import './VapiVoiceReporter.css'; // Optional simple CSS

const resolveVapiConstructor = (mod) => {
  const candidates = [
    mod?.default,
    mod?.Vapi,
    mod?.default?.default,
    mod?.default?.Vapi,
    mod
  ];
  return candidates.find((candidate) => typeof candidate === "function");
};

const VapiVoiceReporter = ({ onTranscriptUpdate }) => {
  const [callStatus, setCallStatus] = useState('idle');
  const [errorMsg, setErrorMsg] = useState('');
  const [geoLoc, setGeoLoc] = useState({ latitude: 0, longitude: 0 });
  const vapiRef = useRef(null);

  // Safely check for env vars
  const vapiPublicKey = import.meta.env.VITE_VAPI_PUBLIC_KEY;
  const assistantId = import.meta.env.VITE_VAPI_ASSISTANT_ID;
  const isSetup = vapiPublicKey && assistantId && vapiPublicKey !== 'your-vapi-public-key-here';

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

    return () => {
      // Cleanup Vapi if instantiated
      if (vapiRef.current) {
        try {
          vapiRef.current.removeAllListeners();
          vapiRef.current.stop();
        } catch (e) {
          console.error("Error during Vapi cleanup", e);
        }
      }
    };
  }, []);

  const initVapi = async () => {
    if (vapiRef.current) return true;

    try {
      const mod = await import("@vapi-ai/web");
      const VapiConstructor = resolveVapiConstructor(mod);

      if (!VapiConstructor) {
        console.warn("Vapi module shape:", Object.keys(mod || {}));
        setCallStatus("sdk_load_error");
        setErrorMsg("Vapi SDK is installed but could not initialize in this browser build. Manual transcript mode is still available.");
        return false;
      }

      const client = new VapiConstructor(vapiPublicKey);

      // Setup Vapi Events
      client.on('call-start', () => setCallStatus('connecting'));
      client.on('call-end', () => setCallStatus('idle'));
      client.on('speech-start', () => setCallStatus('assistant speaking'));
      client.on('speech-end', () => setCallStatus('listening'));
      client.on('message', (message) => {
        if (message.type === 'transcript' && message.role === 'user') {
          onTranscriptUpdate(message.transcript);
        }
      });
      client.on('error', (e) => {
        console.error(e);
        setCallStatus('error');
        setErrorMsg(e.message || "An unknown Vapi error occurred.");
      });

      vapiRef.current = client;
      return true;
    } catch (err) {
      console.error("Failed to initialize Vapi", err);
      setCallStatus('sdk_load_error');
      setErrorMsg("Failed to load Voice Assistant SDK.");
      return false;
    }
  };

  const toggleCall = async () => {
    if (!isSetup) return;

    if (callStatus === 'idle' || callStatus === 'error' || callStatus === 'sdk_load_error') {
      try {
        setCallStatus('connecting');
        setErrorMsg('');
        
        const initialized = await initVapi();
        if (!initialized) return;

        await vapiRef.current.start(assistantId, {
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
      try {
        if (vapiRef.current) {
          vapiRef.current.stop();
        }
      } catch (e) {
        console.error("Error stopping Vapi call", e);
      }
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
            Voice reporting supports manual transcript submission. Live Vapi calls are optional and require Vapi public key + assistant ID.
          </p>
        </div>
      </div>
    );
  }

  if (callStatus === 'sdk_load_error') {
    return (
      <div className="vapi-alert glass-card" style={{ background: 'rgba(245, 158, 11, 0.1)', border: '1px solid rgba(245, 158, 11, 0.3)' }}>
        <AlertCircle size={24} color="#f59e0b" />
        <div style={{marginLeft: '10px'}}>
          <h4>Live Vapi Calling Unavailable</h4>
          <p style={{fontSize: '0.9rem', color: '#888', marginBottom: '8px'}}>
            You can still submit a voice transcript manually.
          </p>
          <p style={{fontSize: '0.8rem', color: '#ef4444'}}>
            {errorMsg}
          </p>
        </div>
      </div>
    );
  }

  return (
    <div className="vapi-reporter-container">
      <div className="status-banner">
        <span>Status: <strong style={{textTransform: 'capitalize'}}>{callStatus.replace('_', ' ')}</strong></span>
        {geoLoc.latitude !== 0 && (
          <span className="geo-badge">Location Acquired</span>
        )}
      </div>

      {errorMsg && (
        <div className="error-msg">{errorMsg}</div>
      )}

      <button 
        className={`vapi-mic-btn ${callStatus !== 'idle' && callStatus !== 'error' && callStatus !== 'sdk_load_error' ? 'active' : ''}`}
        onClick={toggleCall}
      >
        {callStatus === 'connecting' ? (
          <Loader2 className="spinner" size={32} />
        ) : callStatus !== 'idle' && callStatus !== 'error' && callStatus !== 'sdk_load_error' ? (
          <MicOff size={32} />
        ) : (
          <Mic size={32} />
        )}
      </button>

      <p className="helper-text">
        {callStatus !== 'idle' && callStatus !== 'error' && callStatus !== 'sdk_load_error'
          ? "Tap to end call" 
          : "Tap to report civic issue via voice"}
      </p>
    </div>
  );
};

export default VapiVoiceReporter;
