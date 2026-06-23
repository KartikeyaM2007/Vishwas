import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Layout from './components/Layout';
import MapInterface from './pages/MapInterface';
import FiltrationSystem from './pages/FiltrationSystem';
import NLQuery from './pages/NLQuery';

function App() {
  return (
    <Router>
      <Layout>
        <Routes>
          <Route path="/" element={<MapInterface />} />
          <Route path="/filter" element={<FiltrationSystem />} />
          <Route path="/analyze" element={<NLQuery />} />
        </Routes>
      </Layout>
    </Router>
  );
}

export default App;
