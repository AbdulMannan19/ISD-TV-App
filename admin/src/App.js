import { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { supabase } from './supabase';
import Topbar from './components/Topbar/Topbar';
import Sidebar from './components/Sidebar/Sidebar';
import Login from './pages/Login/Login';
import SetPassword from './pages/SetPassword/SetPassword';
import Slides from './pages/Slides/Slides';
import Profile from './pages/Profile/Profile';
import './App.css';

export default function App() {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);
  const [collapsed, setCollapsed] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setLoading(false);
    });
    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setSession(session);
    });
    return () => subscription.unsubscribe();
  }, []);

  if (loading) return <div className="loading">Loading...</div>;

  // Check if user is on password setup page
  const hashParams = new URLSearchParams(window.location.hash.substring(1));
  const type = hashParams.get('type');
  if (type === 'invite' || type === 'recovery') {
    return (
      <BrowserRouter>
        <Routes>
          <Route path="*" element={<SetPassword />} />
        </Routes>
      </BrowserRouter>
    );
  }

  if (!session) return <Login />;

  const email = session.user?.email || '';

  return (
    <BrowserRouter>
      <div className="app">
        <Sidebar collapsed={collapsed} onToggle={() => setCollapsed(!collapsed)} />
        <Topbar collapsed={collapsed} email={email} />
        <main className={`main${collapsed ? ' collapsed' : ''}`}>
          <Routes>
            <Route path="/slides" element={<Slides />} />
            <Route path="/profile" element={<Profile />} />
            <Route path="*" element={<Navigate to="/slides" />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  );
}
