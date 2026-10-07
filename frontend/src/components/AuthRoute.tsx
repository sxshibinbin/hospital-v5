import React from 'react';
import { Navigate, useLocation } from 'react-router-dom';

interface AuthRouteProps {
  children: React.ReactNode;
}

const AuthRoute: React.FC<AuthRouteProps> = ({ children }) => {
  const location = useLocation();
  const token = localStorage.getItem('token');
  const isFlutterEnv = typeof window.FlutterBridge !== 'undefined';

  // If we are in Flutter WebView, we don't intercept because Token will be injected
  // If we are in standard Web, we check for localStorage token
  if (!isFlutterEnv && !token) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <>{children}</>;
};

export default AuthRoute;
