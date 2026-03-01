import { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { supabase } from './supabase';
import Topbar from './components/Topbar/Topbar';
import Sidebar from './components/Sidebar/Sidebar';
import Login from './pages/Login/Login';
import Slides from './pages/Slides/Slides';
import Hadiths from './pages/Hadiths/Hadiths';
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
  if (!session) return <Login />;

  const email = session.user?.email || '';

  return (
    <BrowserRouter>
      <div className="app">
        <Sidebar collapsed={collapsed} onToggle={() => setCollapsed(!collapsed)} />
        <Topbar collapsed={collapsed} email={email} />
        <main className={`main${collapsed ? ' collapsed' : ''}`}>
          <Routes>
            <Route path="/hadiths" element={<Hadiths />} />
            <Route path="/slides" element={<Slides />} />
            <Route path="/profile" element={<Profile />} />
            <Route path="*" element={<Navigate to="/hadiths" />} />
          </Routes>
        </main>
      </div>
    </BrowserRouter>
  );
}
