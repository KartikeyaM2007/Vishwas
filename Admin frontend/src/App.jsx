import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import MapInterface from './pages/MapInterface';
import FiltrationSystem from './pages/FiltrationSystem';
import NLQuery from './pages/NLQuery';
import VoiceReport from './pages/VoiceReport';
import CommunityFeed from './pages/CommunityFeed';
import Leaderboard from './pages/Leaderboard';
import ReviewQueue from './pages/ReviewQueue';
import ComplaintDetail from './pages/ComplaintDetail';

function App() {
  return (
    <Router>
      <Layout>
        <Routes>
          <Route path="/" element={<MapInterface />} />
          <Route path="/filter" element={<FiltrationSystem />} />
          <Route path="/analyze" element={<NLQuery />} />
          <Route path="/voice-report" element={<VoiceReport />} />
          <Route path="/community" element={<CommunityFeed />} />
          <Route path="/review-queue" element={<ReviewQueue />} />
          <Route path="/complaints/:id" element={<ComplaintDetail />} />
          <Route path="/leaderboard" element={<Leaderboard />} />
        </Routes>
      </Layout>
    </Router>
  );
}

export default App;
