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

function AppContent() {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);
  const [collapsed, setCollapsed] = useState(false);
  const [needsPassword, setNeedsPassword] = useState(false);

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setSession(session);
      setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      setSession(session);
      setLoading(false);

      const hash = window.location.hash;
      if (hash.includes('type=invite') || hash.includes('type=recovery')) {
        setNeedsPassword(true);
      }
    });

    return () => subscription.unsubscribe();
  }, []);

  if (loading) return <div className="loading">Loading...</div>;

  // User just came from invite link, has session but needs to set password
  if (needsPassword && session) {
    return <SetPassword onDone={() => { setNeedsPassword(false); window.location.hash = ''; }} />;
  }

  // No session and hash has invite params = Supabase is still processing the redirect
  if (!session) {
    const hash = window.location.hash;
    if (hash.includes('access_token') && (hash.includes('type=invite') || hash.includes('type=recovery'))) {
      return <div className="loading">Processing invitation...</div>;
    }
    return <Login />;
  }

  const email = session.user?.email || '';

  return (
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
  );
}

export default function App() {
  return (
    <BrowserRouter>
      <AppContent />
    </BrowserRouter>
  );
}
