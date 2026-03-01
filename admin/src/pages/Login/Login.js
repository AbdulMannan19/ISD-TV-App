import { useState } from 'react';
import { supabase } from '../../supabase';
import './Login.css';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);
    const { error } = await supabase.auth.signInWithPassword({ email, password });
    setLoading(false);
    if (error) setError(error.message);
  };

  return (
    <div className="login-page">
      <div className="login-left">
        <div className="login-mosque">🕌</div>
        <div className="login-brand">Islamic Society of Denton</div>
        <div className="login-tagline">TV Display Management System</div>
      </div>
      <div className="login-right">
        <form className="login-form" onSubmit={handleLogin}>
          <h2>Welcome back</h2>
          <p className="subtitle">Sign in to manage your display</p>
          <div className="form-group">
            <label>Email</label>
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="admin@masjid.com" required />
          </div>
          <div className="form-group">
            <label>Password</label>
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="••••••••" required />
          </div>
          <button className="login-submit" type="submit" disabled={loading}>
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
          {error && <div className="login-error">{error}</div>}
        </form>
      </div>
    </div>
  );
}
