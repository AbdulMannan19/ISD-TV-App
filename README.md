git status
git add .
git commit -m "quick commit"
git push
clear

cd display
flutter run -d windows

cd admin
npm install
clear
npm start

cd admin
npm start


# ISD TV Display System

The **ISD (Islamic Society of Denton) TV Display System** is a comprehensive, dual-component application designed to effortlessly manage and beautifully display prayer times, announcements, and Islamic content on Masjid TV screens.

The project is split into two primary applications:
1. **Admin**: A secure, web-based administration dashboard.
2. **Display**: A Flutter client application that runs on Windows, rendering the content onto the TV screens.

---

## 🌟 Features

### Admin Dashboard (React + Supabase)
The admin panel provides a user-friendly interface for Masjid administrators to control what appears on the screens:
* **Authentication**: Secure login and profile management.
* **Prayer Times Management**: Update daily and Jumu'ah prayer times, along with Iqamah schedules.
* **Alerts & Announcements**: Broadcast important alerts instantly to the displays.
* **Islamic Content Library**: Manage and curate a rotation of **Hadiths, Duas, and Quranic Verses**.
* **Slides**: Upload and manage custom image/informational slides.
* **Embeddable Widgets**: Provides a dedicated route to embed prayer times onto other websites.

### TV Display Client (Flutter)
Designed for large screens, the Flutter client acts as a digital signage player:
* **Real-time Clock & Dates**: Displays current time alongside prominent Gregorian and Hijri dates.
* **Interactive Prayer Bar**: Shows Start and Iqamah times for all daily prayers (Fajr, Dhuhr, Asr, Maghrib, Isha) and Jumu'ah.
* **Countdown Timer**: A prominent live countdown to the next Iqamah.
* **Sun Tracking**: Displays Sunrise and Sunset times.
* **Dynamic Content Rotation**: Seamlessly cycles through admin-managed content (Hadiths, Duas, Quranic Verses, and Slides).
* **QR Code Integration**: Displays a scannable QR code for easy access to donations or links.

---

## 🚀 Getting Started

Below are the essential commands you need to set up, run, and manage the project locally.

### 1. Admin Dashboard

The admin panel is built with React and Node.js.

**First-time Setup & Run:**
Navigate to the admin folder, install the necessary dependencies, clear the terminal, and start the development server.
```bash
cd admin
npm install
clear
npm start
```

**Standard Run:**
If you have already installed the dependencies, you can simply start the admin panel.
```bash
cd admin
npm start
```

### 2. TV Display Client

The client is a Flutter application optimized for Windows desktop viewing.

**Run on Windows:**
Navigate to the display folder and launch the Flutter application tailored for Windows.
```bash
cd display
flutter run -d windows
```

---

## 🛠️ Version Control (Git)

Use the following sequence of commands to quickly stage, commit, and push your latest changes to the repository:
```bash
git status
git add .
git commit -m "quick commit"
git push
clear
```
