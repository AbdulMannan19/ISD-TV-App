import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../../supabase';
import './SetPassword.css';

export default function SetPassword() {
  const [password, setPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);
  const navigate = useNavigate();

  useEffect(() => {
    // Check if user came from invitation link
    const hashParams = new URLSearchParams(window.location.hash.substring(1));
    const type = hashParams.get('type');
    
    if (type !== 'invite' && type !== 'recovery') {
      navigate('/');
    }
  }, [navigate]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (password.length < 6) {
      setError('Password must be at least 6 characters');
      return;
    }

    if (password !== confirmPassword) {
      setError('Passwords do not match');
      return;
    }

    setLoading(true);

    const { error } = await supabase.auth.updateUser({ password });

    if (error) {
      setError(error.message);
      setLoading(false);
    } else {
      navigate('/slides');
    }
  };

  return (
    <div className="set-password-page">
      <div className="set-password-left">
        <div className="set-password-pattern"></div>
        <div className="set-password-quote">
          <p>"Indeed, the first House [of worship] established for mankind was that at Makkah – blessed and a guidance for the worlds."</p>
          <span>— Quran 3:96</span>
        </div>
      </div>

      <div className="set-password-right">
        <div className="set-password-card">
          <div className="set-password-icon">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
              <path d="M12 3C12 3 8 6 8 10V20H16V10C16 6 12 3 12 3Z" />
              <path d="M4 20V14C4 12 5 11 6 10.5" />
              <path d="M20 20V14C20 12 19 11 18 10.5" />
              <path d="M2 20H22" />
              <circle cx="12" cy="10" r="1.5" />
            </svg>
          </div>

          <h1>Islamic Society of Denton</h1>
          <p className="set-password-subtitle">Set your password to access the dashboard</p>

          <form onSubmit={handleSubmit}>
            <div className="form-group">
              <label>PASSWORD</label>
              <div className="password-input-wrapper">
                <input
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Enter your password"
                  required
                />
                <button
                  type="button"
                  className="toggle-password"
                  onClick={() => setShowPassword(!showPassword)}
                >
                  {showPassword ? '👁️' : '👁️‍🗨️'}
                </button>
              </div>
            </div>

            <div className="form-group">
              <label>CONFIRM PASSWORD</label>
              <input
                type={showPassword ? 'text' : 'password'}
                value={confirmPassword}
                onChange={(e) => setConfirmPassword(e.target.value)}
                placeholder="Confirm your password"
                required
              />
            </div>

            {error && <div className="error-message">{error}</div>}

            <button type="submit" className="btn-submit" disabled={loading}>
              {loading ? 'Setting Password...' : 'Set Password'}
            </button>
          </form>

          <p className="set-password-footer">Managed by Islamic Society of Denton</p>
        </div>
      </div>
    </div>
  );
}
