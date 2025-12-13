@echo off
echo Building Notepad...

REM Resource Compiler
echo Compiling resources...
C:\masm32\bin\rc.exe /v Notepad.rc
if errorlevel 1 goto error

REM Assembler
echo Assembling...
C:\masm32\bin\ml.exe /c /coff /Cp /nologo /I"C:\masm32\include" Notepad.asm
if errorlevel 1 goto error

REM Linker
echo Linking...
C:\masm32\bin\link.exe /SUBSYSTEM:WINDOWS /RELEASE /VERSION:4.0 /LIBPATH:"C:\masm32\lib" /OUT:"Notepad.exe" Notepad.obj Notepad.res
if errorlevel 1 goto error

echo.
echo Build successful!
echo.
goto end

:error
echo.
echo Build failed!
echo.
pause
goto end

:end
