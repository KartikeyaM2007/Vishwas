import React, { useState } from 'react';
import { motion } from 'framer-motion';
import { Send, Loader2, MapPin, AlertTriangle } from 'lucide-react';
import VapiVoiceReporter from '../components/VapiVoiceReporter';

const VoiceReport = () => {
  const [transcript, setTranscript] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [successMsg, setSuccessMsg] = useState('');
  const [errorMsg, setErrorMsg] = useState('');

  const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://127.0.0.1:8000';

  const handleSubmit = async (e) => {
    if (e) e.preventDefault();
    if (!transcript.trim()) return;

    setIsSubmitting(true);
    setSuccessMsg('');
    setErrorMsg('');

    try {
      // Best effort grab location if manually submitted
      let lat = 0;
      let lng = 0;
      
      if ('geolocation' in navigator) {
        try {
          const pos = await new Promise((resolve, reject) => {
            navigator.geolocation.getCurrentPosition(resolve, reject, { timeout: 3000 });
          });
          lat = pos.coords.latitude;
          lng = pos.coords.longitude;
        } catch (err) {
          console.log("Geo error on manual submit", err);
        }
      }

      const payload = {
        transcript: transcript,
        latitude: lat,
        longitude: lng,
        username: "voice_demo_user"
      };

      const res = await fetch(`${API_BASE_URL}/voice-report`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      const data = await res.json();
      
      if (res.ok && data.id) {
        setSuccessMsg(`Report submitted successfully! Categorized as: ${data.issue_type} with Urgency: ${data.urgency_label}`);
        setTranscript(''); // clear
      } else {
        setErrorMsg(`Failed: ${data.error || 'Unknown error'}`);
      }
    } catch (err) {
      setErrorMsg(`Network error: ${err.message}`);
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleTranscriptUpdate = (newTranscript) => {
    setTranscript(prev => prev ? prev + ' ' + newTranscript : newTranscript);
  };

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="page-container"
      style={{ padding: '2rem', maxWidth: '800px', margin: '0 auto' }}
    >
      <header style={{ marginBottom: '2rem' }}>
        <h1 style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
          <AlertTriangle color="#6366f1" /> 
          Voice Civic Reporter
        </h1>
        <p style={{ color: '#9ca3af' }}>
          Describe a civic issue verbally using Vapi.ai, and Gemini will automatically extract the details, severity, and location to route it to the right department.
        </p>
      </header>

      <VapiVoiceReporter onTranscriptUpdate={handleTranscriptUpdate} />

      <div className="glass-panel" style={{ padding: '2rem', borderRadius: '16px' }}>
        <h3 style={{ marginBottom: '1rem' }}>Transcript & Fallback Submit</h3>
        <p style={{ color: '#9ca3af', marginBottom: '1rem', fontSize: '0.9rem' }}>
          If Vapi is offline or you prefer to test manually, you can paste the voice transcript below and submit.
        </p>
        
        <form onSubmit={handleSubmit}>
          <textarea 
            value={transcript}
            onChange={(e) => setTranscript(e.target.value)}
            placeholder="E.g. There is a broken streetlight near my lane and it has been dark for three days. It feels unsafe at night."
            className="search-input"
            style={{ 
              width: '100%', 
              minHeight: '150px', 
              padding: '1rem', 
              borderRadius: '12px',
              marginBottom: '1rem',
              resize: 'vertical'
            }}
          />

          {errorMsg && (
            <div style={{ padding: '1rem', background: 'rgba(239, 68, 68, 0.1)', color: '#ef4444', borderRadius: '8px', marginBottom: '1rem' }}>
              {errorMsg}
            </div>
          )}

          {successMsg && (
            <div style={{ padding: '1rem', background: 'rgba(16, 185, 129, 0.1)', color: '#34d399', borderRadius: '8px', marginBottom: '1rem' }}>
              {successMsg}
            </div>
          )}

          <button 
            type="submit" 
            className="btn-primary" 
            disabled={isSubmitting || !transcript.trim()}
            style={{ width: '100%', display: 'flex', justifyContent: 'center', gap: '10px' }}
          >
            {isSubmitting ? <Loader2 className="spinner" size={20} /> : <Send size={20} />}
            Submit Voice Report
          </button>
        </form>
      </div>
    </motion.div>
  );
};

export default VoiceReport;
