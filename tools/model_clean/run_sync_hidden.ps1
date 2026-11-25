Set-Location "C:\Users\4001C\sappan-repo\tools\model_clean"
# python.exe (not pythonw): PowerShell waits for a console program and its output
# reaches sync.log; conhost --headless in the task keeps the window hidden.
# (pythonw = no output and not waited on -> sync.log stayed empty 9..25-Nov)
$py = "C:\Users\4001C\AppData\Local\Programs\Python\Python312\python.exe"
"=== $(Get-Date -Format 'yyyy-MM-dd HH:mm') ===" | Out-File -Append -Encoding utf8 sync.log
& $py sync.py --push 2>&1 | Out-File -Append -Encoding utf8 sync.log
