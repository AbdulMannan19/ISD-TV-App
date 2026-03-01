import { useState, useEffect } from 'react';
import { supabase } from '../../supabase';
import './Profile.css';

const UserIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="28" height="28">
    <path d="M19 21v-2a4 4 0 0 0-4-4H9a4 4 0 0 0-4 4v2" /><circle cx="12" cy="7" r="4" />
  </svg>
);

const MailIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <rect width="20" height="16" x="2" y="4" rx="2" /><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
  </svg>
);

const LockIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <rect width="18" height="11" x="3" y="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" />
  </svg>
);

const ShieldIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="16" height="16">
    <path d="M20 13c0 5-3.5 7.5-7.66 8.95a1 1 0 0 1-.67-.01C7.5 20.5 4 18 4 13V6a1 1 0 0 1 1-1c2 0 4.5-1.2 6.24-2.72a1.17 1.17 0 0 1 1.52 0C14.51 3.81 17 5 19 5a1 1 0 0 1 1 1z" />
  </svg>
);

const PencilIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="12" height="12">
    <path d="M21.174 6.812a1 1 0 0 0-3.986-3.987L3.842 16.174a2 2 0 0 0-.5.83l-1.321 4.352a.5.5 0 0 0 .623.622l4.353-1.32a2 2 0 0 0 .83-.497z" />
  </svg>
);

const CheckIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <path d="M20 6 9 17l-5-5" />
  </svg>
);

const XIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="14" height="14">
    <path d="M18 6 6 18" /><path d="m6 6 12 12" />
  </svg>
);

export default function Profile() {
  const [email, setEmail] = useState('');
  const [editing, setEditing] = useState(false);
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [saving, setSaving] = useState(false);
  const [status, setStatus] = useState('');

  useEffect(() => {
    supabase.auth.getUser().then(({ data: { user } }) => {
      if (user) setEmail(user.email);
    });
  }, []);

  const handleSave = async () => {
    setStatus('');
    if (password.length < 6) { setStatus('Password must be at least 6 characters'); return; }
    if (password !== confirm) { setStatus('Passwords do not match'); return; }
    setSaving(true);
    const { error } = await supabase.auth.updateUser({ password });
    setSaving(false);
    if (error) { setStatus(error.message); } else {
      setStatus('Password updated');
      setEditing(false); setPassword(''); setConfirm('');
    }
  };

  const cancelEdit = () => { setEditing(false); setPassword(''); setConfirm(''); setStatus(''); };

  return (
    <div className="profile-page">
      <div className="page-header">
        <div>
          <h1 className="page-title">Profile</h1>
          <p className="page-subtitle">Manage your account settings and preferences</p>
        </div>
      </div>

      {/* Avatar card */}
      <div className="profile-card profile-avatar-card">
        <div className="profile-avatar-icon"><UserIcon /></div>
        <div>
          <div className="profile-avatar-name">{email || 'Admin User'}</div>
          <div className="profile-avatar-role">Masjid Display Manager</div>
        </div>
      </div>

      {/* Email card */}
      <div className="profile-section-card">
        <div className="profile-section-header">
          <span className="profile-section-label"><MailIcon /> Email Address</span>
        </div>
        <div className="profile-section-body">
          <p className="profile-section-value">{email || 'admin@example.com'}</p>
          <p className="profile-section-hint">Contact your administrator to change your email address</p>
        </div>
      </div>

      {/* Password card */}
      <div className="profile-section-card">
        <div className="profile-section-header">
          <span className="profile-section-label"><LockIcon /> Password</span>
          {!editing && (
            <button className="profile-change-btn" onClick={() => setEditing(true)}>
              <PencilIcon /> Change
            </button>
          )}
        </div>
        <div className="profile-section-body">
          {editing ? (
            <>
              <div className="form-group">
                <label>New Password</label>
                <input type="password" value={password} onChange={e => setPassword(e.target.value)} placeholder="Enter new password" />
              </div>
              <div className="form-group">
                <label>Confirm Password</label>
                <input type="password" value={confirm} onChange={e => setConfirm(e.target.value)} placeholder="Confirm new password" />
              </div>
              {status && <div className={`profile-status${status === 'Password updated' ? ' success' : ''}`}>{status}</div>}
              <div style={{ display: 'flex', gap: 8 }}>
                <button className="btn btn-green btn-sm" onClick={handleSave} disabled={saving}><CheckIcon /> {saving ? 'Saving...' : 'Update Password'}</button>
                <button className="btn btn-outline btn-sm" onClick={cancelEdit}><XIcon /> Cancel</button>
              </div>
            </>
          ) : (
            <span className="profile-password-dots">••••••••</span>
          )}
        </div>
      </div>

      {/* Security card */}
      <div className="profile-section-card">
        <div className="profile-section-header">
          <span className="profile-section-label"><ShieldIcon /> Security</span>
        </div>
        <div className="profile-section-body">
          <div className="profile-session">
            <span className="profile-session-dot" />
            <span>Session active</span>
          </div>
          <p className="profile-section-hint" style={{ marginLeft: 20 }}>Your session is secure and encrypted</p>
        </div>
      </div>
    </div>
  );
}
