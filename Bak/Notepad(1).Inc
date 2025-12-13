
include windows.inc
include kernel32.inc
include user32.inc
include Comctl32.inc
include shell32.inc
include comdlg32.inc

includelib kernel32.lib
includelib user32.lib
includelib Comctl32.lib
includelib shell32.lib
includelib comdlg32.lib

DlgProc			PROTO	:HWND,:UINT,:WPARAM,:LPARAM

.const

IDD_DIALOG1			equ 101
IDC_EDT1			equ 1001
IDC_UDN1			equ 1002
IDC_TBR1			equ 1003
IDC_TRV1			equ 1004
IDC_SBR1			equ 1005
IDC_BTN1			equ 1006

; Menu IDs
IDM_FILE_NEW		equ 2001
IDM_FILE_OPEN		equ 2002
IDM_FILE_SAVE		equ 2003
IDM_FILE_SAVEAS		equ 2004
IDM_FILE_EXIT		equ 2005
IDM_EDIT_UNDO		equ 2006
IDM_EDIT_REDO		equ 2007

; Toolbar button IDs
IDC_TOOLBAR_NEW		equ 3001
IDC_TOOLBAR_OPEN	equ 3002
IDC_TOOLBAR_SAVE	equ 3003
IDC_TOOLBAR_SAVEAS	equ 3004
IDC_TOOLBAR_UNDO	equ 3005
IDC_TOOLBAR_REDO	equ 3006

; Icon image
IDI_ICON equ 100

MAXSIZE				equ 260

;#########################################################################

.data

szFilter		db 'Todos los archivos (*.*)',0,'*.*',0
				db 'Archivos de texto (*.txt)',0,'*.txt',0
				db 'Archivos ASM (*.asm)',0,'*.asm',0,0

szTitle			db 'Notepad - Sin titulo',0
szUntitled		db 'Sin titulo',0
szModified		db ' *',0
szStatusFormat	db 'Linea: %d  Columna: %d',0
szTestText		db 'Bienvenido a Notepad!',13,10
				db 'Puedes escribir texto aqui.',13,10
				db 'Usa los botones del toolbar para abrir y guardar archivos.',0
szAllFiles		db '\*.*',0
szFileNameFormat db 'Archivo: %s',0
szUnsavedMsg	db '* Sin guardar - Presione Guardar',0
szParentDir		db '..',0
szBackSlash		db '\',0

.data?

hInstance		dd ?
hEdit			dd ?
hToolbar		dd ?
hStatusBar		dd ?
hTreeView		dd ?
OldEditProc		dd ?

ofn				OPENFILENAME <>
szFileName		db MAXSIZE dup(?)
szFileTitle		db MAXSIZE dup(?)
szBuffer		db 65535 dup(?)
szCurrentDir	db MAXSIZE dup(?)

bFileModified	dd ?
bHasFileName	dd ?

;#########################################################################


;#########################################################################

EditProc PROTO :HWND,:UINT,:WPARAM,:LPARAM
UpdateStatusBar PROTO
PopulateTreeView PROTO
