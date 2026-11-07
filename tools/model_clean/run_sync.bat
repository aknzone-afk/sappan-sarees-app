@echo off
rem Samppan: daily logo-free modelling photos (Task Scheduler "Samppan model photos", 07:10)
cd /d C:\Users\4001C\sappan-repo\tools\model_clean
"C:\Users\4001C\AppData\Local\Programs\Python\Python312\python.exe" sync.py --push >> sync.log 2>&1
