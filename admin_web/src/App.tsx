import React from 'react';
import { BrowserRouter, Routes, Route, Navigate, useLocation } from 'react-router-dom';
import Layout from '@/components/Layout';
import Questions from '@/pages/Questions';
import Login from '@/pages/Login';
import Dashboard from '@/pages/Dashboard';
import Users from '@/pages/Users';
import Logs from '@/pages/Logs';
import Settings from '@/pages/Settings';
import Agreements from '@/pages/Agreements';
import Feedback from '@/pages/Feedback';
import AiSafety from '@/pages/AiSafety';
import IntentRules from '@/pages/AiSafety/IntentRules';
import Words from '@/pages/AiSafety/Words';

const RequireAuth = ({ children }: { children: JSX.Element }) => {
  const token = localStorage.getItem('admin_token');
  const location = useLocation();

  if (!token) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return children;
};

function App() {
  return (
    <BrowserRouter basename={import.meta.env.BASE_URL}>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/" element={<RequireAuth><Layout /></RequireAuth>}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="users" element={<Users />} />
          <Route path="questions" element={<Questions />} />
          <Route path="feedback" element={<Feedback />} />
          <Route path="ai-safety" element={<AiSafety />} />
          <Route path="ai-safety/intent-rules" element={<IntentRules />} />
          <Route path="ai-safety/words" element={<Words />} />
          <Route path="agreements" element={<Agreements />} />
          <Route path="logs" element={<Logs />} />
          <Route path="audit" element={<Navigate to="/logs" replace />} />
          <Route path="settings" element={<Settings />} />
        </Route>
      </Routes>
    </BrowserRouter>
  );
}

export default App;
