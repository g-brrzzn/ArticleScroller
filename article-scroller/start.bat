@echo off
echo ===================================================
echo    🚀 Starting the Article Scroller Ecosystem...
echo ===================================================

echo.
echo [1/2] Starting Python Server (FastAPI)...

start "Backend Server - Article Scroller" cmd /k "cd backend && call venv\Scripts\activate && uvicorn app.main:app --reload"

echo.
echo [2/2] Starting Flutter App...

start "Flutter App - Article Scroller" cmd /k "cd frontend && flutter run -d windows"