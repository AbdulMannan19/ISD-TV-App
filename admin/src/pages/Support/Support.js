import './Support.css';

const MailIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="20" height="20">
    <rect width="20" height="16" x="2" y="4" rx="2" /><path d="m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7" />
  </svg>
);

const PhoneIcon = () => (
  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" width="20" height="20">
    <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
  </svg>
);

export default function Support() {
  return (
    <div>
      <div className="page-header">
        <div>
          <h1 className="page-title">Support</h1>
          <p className="page-subtitle">
            For feature requests or technical support and assistance, contact us using the details below.
          </p>
        </div>
      </div>

      <div className="support-grid">
        <section className="support-card">
          <h2 className="support-card-title">Contact</h2>
          <ul className="support-list">
            <li>
              <PhoneIcon />
              <a href="tel:+19132636353">+1 (913) 263-6353</a>
            </li>
            <li>
              <MailIcon />
              <a href="mailto:abdulmannan34695@gmail.com">abdulmannan34695@gmail.com</a>
            </li>
          </ul>
        </section>

        <section className="support-card">
          <h2 className="support-card-title">Contact</h2>
          <ul className="support-list">
            <li>
              <PhoneIcon />
              <a href="tel:+19407581066">+1 (940) 758-1066</a>
            </li>
            <li>
              <MailIcon />
              <a href="mailto:Abdullahmkh2004@gmail.com">Abdullahmkh2004@gmail.com</a>
            </li>
          </ul>
        </section>
      </div>
    </div>
  );
}
