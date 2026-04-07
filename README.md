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

static const bool configEnableSimulation = false;


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

---

## 📋 Saved Prompts

### Friday Dual Hadith Feature
```
Implement Friday dual hadith logic: On Fridays, always show a second hadith screen (Hadith 2) using one of these 3 hardcoded Friday hadiths picked randomly (but consistent for the day). The primary hadith (screen 1) stays as the normal Hijri-date hadith from DB. The Friday hadith overrides any text2/source2 from the DB — so Friday always gets priority for the second slot.

Friday Hadiths:

1. Text: Narrated Salman Al-Farsi: The Prophet (p.b.u.h) said, "Whoever takes a bath on Friday, purifies himself as much as he can, then uses his (hair) oil or perfumes himself with the scent of his house, then proceeds (for the Jumua prayer) and does not separate two persons sitting together (in the mosque), then prays as much as (Allah has) written for him and then remains silent while the Imam is delivering the Khutba, his sins in-between the present and the last Friday would be forgiven."
   Source: Sahih Bukhari - 8, Friday: Etiquettes

2. Text: Ibn Umar (may Allah be pleased with him) said: "The Messenger of Allah (peace and blessings of Allah be upon him) said: 'Whoever reads Surat al-Kahf on the day of Jumu'ah, a light will shine for him from beneath his feet to the clouds of the sky, which will shine for him on the Day of Resurrection, and he will be forgiven (his sins) between the two Fridays.'"
   Source: al-Sunan al-Kubra lil-Bayhaqi 5996

3. Text: Aws b. Aws reported the Messenger of Allah as saying: Among the most excellent of your days is Friday; so invoke many blessings on me on that day, for your blessing will be submitted to me. They (the Companions) asked: Messenger of Allah, how can our blessings be submitted to you, when your body has decayed? He said: Allah has prohibited the earth from consuming the bodies of Prophets.
   Source: Sunan Abi Dawud 1531

Implementation: In SharedData.fetchDailyContent(), after fetching from DB, if now.weekday == DateTime.friday, override currentHadith['text2'] and currentHadith['source2'] with a randomly picked Friday hadith. Use a deterministic seed from the date so it stays consistent throughout the day.
```
