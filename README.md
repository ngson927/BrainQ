# BrainQ Flashcard Learning System Backend


# Backend

# Requirements:

Python 3.11+

MySQL (or SQLite for testing)

pip (package manager)


# Setup

Clone the repository: git clone https://github.com/ngson927/BrainQ.git
                      cd BrainQ


Create a virtual environment: python -m venv .venv

Activate the virtual environment: Windows PowerShell: .venv/Scripts/Activate.ps1


macOS/Linux: .venv/bin/activate


Install dependencies: pip install -r requirements.txt


Configure environment variables: Create a .env file (or update settings.py) with your database credentials and email settings.

Run migrations: python manage.py makemigrations
                python manage.py migrate


# Running the Backend

Start the development server: python manage.py runserver

Access the API at http://127.0.0.1:8000/api/.

User Management Features

Register: POST /api/users/register/
New users register with username, email, and password. Roles are assigned by default.

Login: POST /api/users/login/
Returns an authentication token.

Logout: POST /api/users/logout/
Invalidates the user token.

Admin-only View: GET /api/users/admin-only/
View all users (requires admin authentication).

Password Reset Flow

Request reset: POST /api/users/password-reset/
Provide an email to receive a token (for testing, the token is also returned in the response).

Confirm reset: POST /api/users/password-reset-confirm/
Provide the token and new password to reset.

Security:

Tokens expire after 15 minutes.

Tokens are one-time use.

Passwords are hashed and stored securely.

# Git Workflow & Contributing

Clone the repository:

git clone https://github.com/ngson927/BrainQ.git
cd BrainQ


Create a branch

git checkout -b feature/<feature-name>


Make changes locally

Do not commit .venv/ or db.sqlite3.

Stage & commit changes

git add .
git commit -m "Short descriptive message"


Push your branch

git push origin feature/<feature-name>


Open a Pull Request on GitHub for review.

Update local master

git checkout master
git pull origin master

# Notes

Use consistent code style.

Run backend tests before opening a PR.

Always sync your branch with master before merging.
