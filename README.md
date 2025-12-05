# 🧠 BrainQ – AI-Powered Flashcard Learning System

BrainQ is an AI-enhanced flashcard learning platform that we developed to help users study more efficiently through personalized, interactive, and adaptive learning tools.

Our system allows users to **create, customize, share, and study flashcard decks** while leveraging AI for intelligent content generation, assistance, and learning optimization.

We built BrainQ as a full-stack application using a modern tech stack that integrates a mobile frontend, cloud backend, AI services, and real-time notifications.

---

## 🚀 Tech Stack

**Frontend**

* Flutter (cross-platform mobile app)

**Backend**

* Django + Django REST Framework
* Celery + Redis (background jobs & reminders)

**Database**

* MySQL (hosted on Amazon RDS)

**AI & Cloud Services**

* OpenAI API – flashcard generation & study assistant
* Firebase Cloud Messaging – push notifications
* Google Cloud Vision – optional OCR support

---

## 🧠 Main Features

* Create and edit flashcard decks (CRUD)
* AI-powered flashcard generation from prompts, notes, or PDFs
* AI study assistant (Q&A per deck/topic)
* Adaptive learning (difficulty adjusts to performance)
* Spaced repetition system
* Quiz modes: random, sequential, timed
* Flashcard shuffle
* Deck sharing & rating system
* Streak tracker & achievements
* Calendar & reminders
* Deck archive feature
* Topic search & filters
* Populate feature (auto-fills an initial deck from a topic)
* Role-based user management (User / Admin)

---

## 🔐 Important: Secrets & Private Files

For security reasons, the following files are **not** included in the repository and are added to `.gitignore`:

```
.env
service_account.json
firebase_options.dart
google-services.json
GoogleService-Info.plist
.venv/
db.sqlite3
__pycache__/
```

These files contain sensitive information such as database credentials, Firebase keys, and OpenAI API keys.

Instead, we provide **safe template files**:

```
.env.example
service_account.example.json
firebase_options.example.dart
```

You must copy and fill them with your own credentials.

---

## ✅ Required Setup (Before Running)

```bash
cp .env.example .env
cp service_account.example.json service_account.json
cp firebase_options.example.dart firebase_options.dart
```

Then edit the files and add your real credentials.

### `.env` File Structure

```env
SECRET_KEY=your_django_secret_key
DEBUG=True

DB_NAME=brainq
DB_USER=your_db_username
DB_PASSWORD=your_db_password
DB_HOST=your_rds_or_localhost
DB_PORT=3306

OPENAI_API_KEY=your_openai_api_key
GOOGLE_APPLICATION_CREDENTIALS=service_account.json
```

---

## ✅ Backend Setup (Django)

### 1. Clone the repository

```bash
git clone https://github.com/ngson927/BrainQ.git
cd BrainQ/backend
```

### 2. Create virtual environment

```bash
python -m venv .venv
source .venv/bin/activate       # macOS/Linux
.venv\Scripts\activate          # Windows
```

### 3. Install dependencies

```bash
pip install -r requirements.txt
```

### 4. Run migrations

```bash
python manage.py makemigrations
python manage.py migrate
```

### 5. Start the backend server

```bash
python manage.py runserver
```

Backend runs at:

```
http://127.0.0.1:8000/api/
```

---

## ✅ Celery & Redis (Background Jobs)

We use **Celery** and **Redis** for:

* Study reminders
* Scheduled tasks (spaced repetition)
* Notification jobs
* Background AI processing

Start Redis:

```bash
redis-server
```

Start Celery worker:

```bash
celery -A brainq worker -l info
```

Start Celery Beat:

```bash
celery -A brainq beat -l info
```

---

## ✅ Frontend Setup (Flutter)

```bash
cd frontend
flutter pub get
flutter run
```

Make sure you have replaced:

```
firebase_options.dart
```

with your real Firebase configuration.

---

## 🔔 Firebase Cloud Messaging (Notifications)

We use Firebase Cloud Messaging (FCM) for:

* Study reminders
* Streak alerts
* System notifications

Required steps:

✅ Create a Firebase project
✅ Enable Cloud Messaging
✅ Register Android / iOS apps
✅ Download Firebase config files
✅ Add credentials to:

```
firebase_options.dart
service_account.json
.env
```

---

## 🤖 OpenAI Integration

BrainQ uses OpenAI for:

* AI flashcard generation
* AI study assistant chat

Add your key to `.env`:

```
OPENAI_API_KEY=sk-xxxxxxxxxxxxxxxx
```

---

## 🔐 Security Summary

The following files must **NEVER** be committed:

```
.env
service_account.json
firebase_options.dart
google-services.json
GoogleService-Info.plist
```

These are intentionally excluded for security.

---

## 👨‍🏫 For Markers / TA (How to Test)

To test BrainQ:

1. Create your own Firebase project
2. Create `.env` from `.env.example`
3. Create `service_account.json` & `firebase_options.dart`
4. Setup MySQL (local or Amazon RDS)
5. Add your OpenAI key
6. Run:

```bash
python manage.py migrate
python manage.py runserver
cd frontend
flutter run
```

All features of the application should work after configuration.

---

## 🎯 Project Purpose

This project demonstrates our ability to:

* Build complete full-stack applications
* Design REST APIs with Django
* Develop cross-platform mobile apps with Flutter
* Integrate AI into real-world applications
* Use cloud platforms (AWS, Firebase, OpenAI)
* Implement secure authentication and notifications
* Design adaptive learning systems

BrainQ represents both our technical skills and our ability to deliver a complete production-ready system.

---

## ✨ Future Improvements

* Web version (React)
* User analytics dashboard
* AI image-based flashcards
* Multiplayer quiz mode
* Class/teacher dashboards

---

## 👨‍💻 Authors

Developed by the BrainQ Team:

* Aminata Diallo
* Benedict Cheong
* Farrel Amaladason
* Jahvarie Innerarity
* Roshan Savarimuthu
* Son Nguyen

Project: BrainQ – AI-Powered Learning Platform
