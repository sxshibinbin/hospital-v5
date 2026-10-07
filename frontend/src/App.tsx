import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import ChatPage from './pages/ChatPage';
import AdminPage from './pages/AdminPage';
import LoginPage from './pages/LoginPage';
import AuthRoute from './components/AuthRoute';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/chat" replace />} />
        <Route path="/login" element={<LoginPage />} />
        <Route 
          path="/chat" 
          element={
            <AuthRoute>
              <ChatPage />
            </AuthRoute>
          } 
        />
        <Route 
          path="/admin/*" 
          element={
            <AuthRoute>
              <AdminPage />
            </AuthRoute>
          } 
        />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
