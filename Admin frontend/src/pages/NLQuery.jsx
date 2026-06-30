import React, { useState } from 'react';
import { analyzeQuery } from '../services/api';
import { Search, Sparkles, Terminal, ArrowRight, Loader, Mic } from 'lucide-react';
// eslint-disable-next-line no-unused-vars
import { motion, AnimatePresence } from 'framer-motion';
import { useTheme } from '../contexts/ThemeContext';
import { 
  LineChart, Line, BarChart, Bar, XAxis, YAxis, 
  CartesianGrid, Tooltip as RechartsTooltip, ResponsiveContainer,
  AreaChart, Area
} from 'recharts';
import './NLQuery.css';

const CustomTooltip = ({ active, payload, label }) => {
  if (active && payload && payload.length) {
    return (
      <div className="custom-tooltip glass-card">
        <p className="tooltip-label">{label}</p>
        <p className="tooltip-value">
          <span className="tooltip-color-indicator" style={{ backgroundColor: payload[0].color }}></span>
          {payload[0].name}: {payload[0].value}
        </p>
      </div>
    );
  }
  return null;
};

const NLQuery = () => {
  const [query, setQuery] = useState('');
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [result, setResult] = useState(null);
  const [isListening, setIsListening] = useState(false);
  const { theme } = useTheme();

  const [error, setError] = useState(null);

  const axesColor = theme === 'dark' ? 'var(--text-muted)' : '#64748b';
  const gridColor = theme === 'dark' ? '#374151' : '#e2e8f0';

  const handleSearch = async (e) => {
    e.preventDefault();
    if (!query.trim()) return;

    setIsAnalyzing(true);
    setResult(null);
    setError(null);

    try {
      const response = await analyzeQuery(query);
      setResult(response);
    } catch (err) {
      console.error("Analysis failed:", err);
      setError(err.message || "Failed to analyze query. Is the backend running?");
    } finally {
      setIsAnalyzing(false);
    }
  };

  const translateToEnglish = async (text) => {
    try {
      const res = await fetch(`https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=en&dt=t&q=${encodeURIComponent(text)}`);
      const data = await res.json();
      if (data && data[0] && data[0][0] && data[0][0][0]) {
        return data[0][0][0];
      }
      return text;
    } catch (err) {
      console.error("Translation error", err);
      return text;
    }
  };

  const handleMicClick = () => {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition) {
      alert("Speech Recognition is not supported by your browser. Try using Chrome.");
      return;
    }

    if (isListening) return; // Prevent multiple instances

    const recognition = new SpeechRecognition();
    recognition.lang = ''; // Let browser auto-detect or use default language to capture whatever they say
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;

    recognition.onstart = () => {
      setIsListening(true);
    };

    recognition.onresult = async (event) => {
      const transcript = event.results[0][0].transcript;
      setIsListening(false);
      
      // We got the text in whatever language. Now translate to English.
      setQuery("Translating voice input...");
      const englishText = await translateToEnglish(transcript);
      setQuery(englishText);
    };

    recognition.onerror = (event) => {
      console.error("Speech recognition error", event.error);
      setIsListening(false);
      if (event.error === 'not-allowed') {
        alert("Please grant microphone permissions to use voice search.");
      }
    };

    recognition.onend = () => {
      setIsListening(false);
    };

    recognition.start();
  };

  const renderChart = () => {
    if (!result || !result.data) return null;

    const { chart, data: rawData } = result;
    
    // Convert to array if it is a single object from backend
    const dataArray = Array.isArray(rawData) ? rawData : (rawData ? [rawData] : []);
    
    if (dataArray.length === 0) return <div className="p-4 text-center">No results found for this query</div>;

    // Determine keys from data dynamically
    const xKey = Object.keys(dataArray[0])[0];
    const yKey = Object.keys(dataArray[0])[1];

    // Format dates for the X axis if it looks like a date string
    const formattedData = dataArray.map(item => {
      let xValue = item[xKey];
      if (typeof xValue === 'string' && xValue.includes('T')) {
        xValue = new Date(xValue).toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
      }
      return {
        ...item,
        [xKey]: xValue
      };
    });

    switch(chart) {
      case 'bar':
        return (
          <ResponsiveContainer width="100%" height={350}>
            <BarChart data={formattedData} margin={{ top: 20, right: 30, left: 0, bottom: 5 }}>
              <CartesianGrid strokeDasharray="3 3" stroke={gridColor} vertical={false} />
              <XAxis dataKey={xKey} stroke={axesColor} tick={{fill: axesColor}} axisLine={false} tickLine={false} />
              <YAxis stroke={axesColor} tick={{fill: axesColor}} axisLine={false} tickLine={false} />
              <RechartsTooltip content={<CustomTooltip />} />
              <Bar 
                dataKey={yKey} 
                name="Complaints"
                fill="url(#colorGradientBar)" 
                radius={[4, 4, 0, 0]} 
                animationDuration={1500}
              />
              <defs>
                <linearGradient id="colorGradientBar" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#818cf8" stopOpacity={1}/>
                  <stop offset="95%" stopColor="#6366f1" stopOpacity={0.8}/>
                </linearGradient>
              </defs>
            </BarChart>
          </ResponsiveContainer>
        );
      case 'line':
      default:
        return (
          <ResponsiveContainer width="100%" height={350}>
            <AreaChart data={formattedData} margin={{ top: 20, right: 30, left: 0, bottom: 5 }}>
              <defs>
                <linearGradient id="colorGradientLine" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#6366f1" stopOpacity={0.4}/>
                  <stop offset="95%" stopColor="#6366f1" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" stroke={gridColor} vertical={false} />
              <XAxis dataKey={xKey} stroke={axesColor} tick={{fill: axesColor}} axisLine={false} tickLine={false} />
              <YAxis stroke={axesColor} tick={{fill: axesColor}} axisLine={false} tickLine={false} />
              <RechartsTooltip content={<CustomTooltip />} />
              <Area 
                type="monotone" 
                dataKey={yKey} 
                name="Complaints"
                stroke="#818cf8" 
                strokeWidth={3}
                fillOpacity={1} 
                fill="url(#colorGradientLine)" 
                animationDuration={1500}
              />
            </AreaChart>
          </ResponsiveContainer>
        );
    }
  };

  return (
    <div className="nl-container">
      <div className="nl-header">
        <motion.div 
          initial={{ opacity: 0, y: -20 }}
          animate={{ opacity: 1, y: 0 }}
          className="ai-badge"
        >
          <Sparkles size={16} />
          <span>AI COMPLAINT ANALYST</span>
        </motion.div>
        <motion.h1 
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ delay: 0.1 }}
        >
          Ask Anything About Your City Data
        </motion.h1>
        <motion.p 
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          transition={{ delay: 0.2 }}
        >
          Use natural language to query complaints, find trends, and visualize patterns instantly.
        </motion.p>
      </div>

      <motion.form 
        className="search-prompt-wrapper"
        initial={{ scale: 0.95, opacity: 0 }}
        animate={{ scale: 1, opacity: 1 }}
        transition={{ delay: 0.2, type: 'spring' }}
        onSubmit={handleSearch}
      >
        <div className="search-input-container hover-glow">
          <Search className="search-icon-lg" size={24} />
          <input 
            type="text" 
            placeholder="e.g. Which issue type has most complaints? or Show complaints over time" 
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            autoFocus
          />
          <button 
            type="button" 
            className={`btn-mic ${isListening ? 'listening hover-glow' : ''}`} 
            onClick={handleMicClick}
            title="Search by Voice (Any Language)"
          >
             <Mic size={20} className={isListening ? 'text-danger animate-pulse' : 'text-muted'} />
          </button>
          <button type="submit" disabled={isAnalyzing || !query.trim() || isListening} className="btn-submit hover-glow">
             <ArrowRight size={20} />
          </button>
        </div>
        
        {/* Suggested Queries */}
        <div className="suggested-queries">
          <span>Try asking:</span>
          <button type="button" onClick={() => setQuery("Display complaints over time as a line chart")}>Trends over time</button>
          <button type="button" onClick={() => setQuery("Display complaints by issue type as a bar chart")}>Complaints by category</button>
        </div>
      </motion.form>

      <div className="results-container">
        <AnimatePresence mode="wait">
          {isAnalyzing && (
            <motion.div 
              key="loading"
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.9 }}
              className="analyzing-state glass-card"
            >
              <Loader className="spinner" size={48} color="var(--primary)" />
              <h2>Analyzing Data...</h2>
              <p>Translating query into SQL and generating visualization</p>
            </motion.div>
          )}

          {error && !isAnalyzing && (
            <motion.div 
              key="error"
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: 10 }}
              className="glass-card error-state text-danger p-4"
              style={{ textAlign: 'center', backgroundColor: 'rgba(239, 68, 68, 0.1)', border: '1px solid rgba(239, 68, 68, 0.2)' }}
            >
              <h3>⚠️ Analysis Error</h3>
              <p>{error}</p>
            </motion.div>
          )}

          {result && !isAnalyzing && (
            <motion.div 
              key="results"
              initial={{ opacity: 0, y: 40 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 0.1, type: 'spring', damping: 20 }}
              className="analysis-result-grid"
            >
              <div className="result-main-card glass-panel">
                <div className="card-header">
                  <h3>{result.query}</h3>
                  <div className="chart-badge">{result.chart.toUpperCase()} CHART</div>
                </div>
                
                <div className="chart-wrapper">
                  {renderChart()}
                </div>
              </div>

              <div className="sql-box glass-panel">
                <div className="sql-header">
                  <Terminal size={18} />
                  <span>GENERATED SQL</span>
                </div>
                <pre>
                  <code>{result.sql}</code>
                </pre>
              </div>
            </motion.div>
          )}
        </AnimatePresence>
      </div>
    </div>
  );
};

export default NLQuery;
