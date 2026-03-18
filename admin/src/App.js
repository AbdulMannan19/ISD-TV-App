import { useState, useEffect } from 'react';
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { supabase } from './supabase';
import Topbar from './components/Topbar/Topbar';
import Sidebar from './components/Sidebar/Sidebar';
import Login from './pages/Login/Login';
import UpdatePassword from './pages/UpdatePassword/UpdatePassword';
import Slides from './pages/Slides/Slides';
import PrayerTimes from './pages/PrayerTimes/PrayerTimes';
import Profile from './pages/Profile/Profile';
import Alerts from './pages/Alerts/Alerts';
import './App.css';

function AppContent() {
  const [session, setSession] = useState(null);
  const [loading, setLoading] = useState(true);
  const [collapsed, setCollapsed] = useState(false);
  const [isPasswordRecovery, setIsPasswordRecovery] = useState(false);

  useEffect(() => {
    // onAuthStateChange fires BEFORE getSession resolves when there's a hash token.
    // We use it as the single source of truth and only stop loading after it fires.
    const { data: { subscription } } = supabase.auth.onAuthStateChange((event, session) => {
      console.log('[App] Auth event:', event, 'session:', !!session);
      setSession(session);

      if (event === 'PASSWORD_RECOVERY') {
        setIsPasswordRecovery(true);
      }

      // Stop loading on any auth event (SIGNED_IN, PASSWORD_RECOVERY, SIGNED_OUT, INITIAL_SESSION)
      setLoading(false);
    });

    return () => subscription.unsubscribe();
  }, []);

  if (loading) return <div className="loading">Loading...</div>;

  console.log('[App] Render - recovery:', isPasswordRecovery, 'session:', !!session);

  if (isPasswordRecovery && session) {
    return <UpdatePassword onComplete={() => setIsPasswordRecovery(false)} />;
  }

  if (!session) return <Login />;

  const email = session.user?.email || '';

  return (
    <div className="app">
      <Sidebar collapsed={collapsed} onToggle={() => setCollapsed(!collapsed)} />
      <Topbar collapsed={collapsed} email={email} />
      <main className={`main${collapsed ? ' collapsed' : ''}`}>
        <Routes>
          <Route path="/slides" element={<Slides />} />
          <Route path="/prayer-times" element={<PrayerTimes />} />
          <Route path="/alerts" element={<Alerts />} />
          <Route path="/profile" element={<Profile />} />
          <Route path="*" element={<Navigate to="/prayer-times" />} />
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
