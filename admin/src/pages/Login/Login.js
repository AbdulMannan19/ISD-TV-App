import { useState } from 'react';
import { supabase } from '../../supabase';
import './Login.css';

const MosqueIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" className="mosque-svg">
    <path d="M12 3C12 3 8 6 8 10V20H16V10C16 6 12 3 12 3Z" />
    <path d="M4 20V14C4 12 5 11 6 10.5" />
    <path d="M20 20V14C20 12 19 11 18 10.5" />
    <path d="M2 20H22" />
    <circle cx="12" cy="10" r="1.5" />
  </svg>
);

const MailIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <rect width="20" height="16" x="2" y="4" rx="2" />
    <path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
  </svg>
);

const LockIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <rect width="18" height="11" x="3" y="11" rx="2" ry="2" />
    <path d="M7 11V7a5 5 0 0 1 10 0v4" />
  </svg>
);

const EyeIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <path d="M2.062 12.348a1 1 0 0 1 0-.696 10.75 10.75 0 0 1 19.876 0 1 1 0 0 1 0 .696 10.75 10.75 0 0 1-19.876 0" />
    <circle cx="12" cy="12" r="3" />
  </svg>
);

const EyeOffIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <path d="M10.733 5.076a10.744 10.744 0 0 1 11.205 6.575 1 1 0 0 1 0 .696 10.747 10.747 0 0 1-1.444 2.49" />
    <path d="M14.084 14.158a3 3 0 0 1-4.242-4.242" />
    <path d="M17.479 17.499a10.75 10.75 0 0 1-15.417-5.151 1 1 0 0 1 0-.696 10.75 10.75 0 0 1 4.446-5.143" />
    <path d="m2 2 20 20" />
  </svg>
);

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
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
        <img src="/images/mosque-pattern.jpg" alt="Islamic pattern" className="login-bg-img" />
        <div className="login-overlay" />
        <div className="login-quote">
          <p>"Indeed, the first House [of worship] established for mankind was that at Makkah – blessed and a guidance for the worlds."</p>
          <span className="login-quote-source">— Quran 3:96</span>
        </div>
      </div>

      <div className="login-right">
        <div className="login-form-wrapper">
          <div className="login-brand">
            <div className="login-brand-icon"><MosqueIcon /></div>
            <h1 className="login-brand-name">Islamic Society of Denton</h1>
            <p className="login-brand-sub">Sign in to manage your display</p>
          </div>

          <form className="login-form" onSubmit={handleLogin}>
            <div className="form-group">
              <label>Email</label>
              <div className="input-with-icon">
                <span className="input-icon"><MailIcon /></span>
                <input type="email" value={email} onChange={e => setEmail(e.target.value)} placeholder="your@email.com" required />
              </div>
            </div>

            <div className="form-group">
              <label>Password</label>
              <div className="input-with-icon">
                <span className="input-icon"><LockIcon /></span>
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={e => setPassword(e.target.value)}
                  placeholder="Enter your password"
                  required
                />
                <button type="button" className="toggle-password" onClick={() => setShowPassword(!showPassword)} aria-label={showPassword ? 'Hide password' : 'Show password'}>
                  {showPassword ? <EyeOffIcon /> : <EyeIcon />}
                </button>
              </div>
            </div>

            <button className="login-submit" type="submit" disabled={loading}>
              {loading ? (
                <span className="login-spinner-wrap">
                  <span className="login-spinner" />
                  Signing in...
                </span>
              ) : 'Sign In'}
            </button>
            {error && <div className="login-error">{error}</div>}
          </form>

          <p className="login-footer">Managed by Islamic Society of Denton</p>
        </div>
      </div>
    </div>
  );
}
