.386
.model flat, stdcall  ;32 bit memory model
option casemap :none  ;case sensitive

include Notepad.inc

.code

start:

	invoke GetModuleHandle,NULL
	mov		hInstance,eax

    invoke InitCommonControls
	invoke DialogBoxParam,hInstance,IDD_DIALOG1,NULL,addr DlgProc,NULL
	invoke ExitProcess,0

;########################################################################

DlgProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	LOCAL tbab:TBADDBITMAP
	LOCAL tbb:TBBUTTON
	LOCAL buffer[256]:BYTE
	LOCAL lineNum:DWORD
	LOCAL colNum:DWORD
	LOCAL charIndex:DWORD
	LOCAL bytesRead:DWORD
	LOCAL bytesWritten:DWORD
	LOCAL fileSize:DWORD
	LOCAL hFile:DWORD
	LOCAL tvitem:TV_ITEM

	mov		eax,uMsg
	.if eax==WM_INITDIALOG
		;setting up the ico
		invoke LoadIcon, hInstance, IDI_ICON
		invoke SendMessage, hWin, WM_SETICON, ICON_BIG, eax

		
		; Get edit control handle
		invoke GetDlgItem,hWin,IDC_EDT1
		mov hEdit,eax
		
		; Initialize toolbar
		invoke GetDlgItem,hWin,IDC_TBR1
		mov hToolbar,eax
		
		; Set toolbar button size
		invoke SendMessage,hToolbar,TB_BUTTONSTRUCTSIZE,sizeof TBBUTTON,0
		
		; Add standard bitmap
		mov tbab.hInst,HINST_COMMCTRL
		mov tbab.nID,IDB_STD_SMALL_COLOR
		invoke SendMessage,hToolbar,TB_ADDBITMAP,15,addr tbab
		
		; Add buttons to toolbar
		; New button
		mov tbb.iBitmap,STD_FILENEW
		mov tbb.idCommand,IDC_TOOLBAR_NEW
		mov tbb.fsState,TBSTATE_ENABLED
		mov tbb.fsStyle,TBSTYLE_BUTTON
		mov tbb.dwData,0
		mov tbb.iString,0
		invoke SendMessage,hToolbar,TB_ADDBUTTONS,1,addr tbb
		
		; Open button
		mov tbb.iBitmap,STD_FILEOPEN
		mov tbb.idCommand,IDC_TOOLBAR_OPEN
		invoke SendMessage,hToolbar,TB_ADDBUTTONS,1,addr tbb
		
		; Save button
		mov tbb.iBitmap,STD_FILESAVE
		mov tbb.idCommand,IDC_TOOLBAR_SAVE
		invoke SendMessage,hToolbar,TB_ADDBUTTONS,1,addr tbb
		
		; Separator
		mov tbb.iBitmap,0
		mov tbb.idCommand,0
		mov tbb.fsStyle,TBSTYLE_SEP
		invoke SendMessage,hToolbar,TB_ADDBUTTONS,1,addr tbb
		
		; Undo button
		mov tbb.iBitmap,STD_UNDO
		mov tbb.idCommand,IDC_TOOLBAR_UNDO
		mov tbb.fsState,TBSTATE_ENABLED
		mov tbb.fsStyle,TBSTYLE_BUTTON
		invoke SendMessage,hToolbar,TB_ADDBUTTONS,1,addr tbb
		
		; Redo button
		mov tbb.iBitmap,STD_REDOW
		mov tbb.idCommand,IDC_TOOLBAR_REDO
		invoke SendMessage,hToolbar,TB_ADDBUTTONS,1,addr tbb

		; Separator
		mov tbb.iBitmap,0
		mov tbb.idCommand,0
		mov tbb.fsStyle,TBSTYLE_SEP
		invoke SendMessage,hToolbar,TB_ADDBUTTONS,1,addr tbb
		
		; Info button
		mov tbb.iBitmap,STD_HELP
		mov tbb.idCommand,IDC_TOOLBAR_INFO
		mov tbb.fsState,TBSTATE_ENABLED
		mov tbb.fsStyle,TBSTYLE_BUTTON
		invoke SendMessage,hToolbar,TB_ADDBUTTONS,1,addr tbb
		
		; Initialize status bar
		invoke GetDlgItem,hWin,IDC_SBR1
		mov hStatusBar,eax
		
		; Initialize TreeView
		invoke GetDlgItem,hWin,IDC_TRV1
		mov hTreeView,eax
		
		; Set initial status
		invoke SendMessage,hStatusBar,SB_SETTEXT,0,addr szTitle
		
		; Initialize file variables
		mov bFileModified,FALSE
		mov bHasFileName,FALSE
		mov szFileName,0
		
		; Explicitly enable edit control (remove readonly if set)
		invoke SendMessage,hEdit,EM_SETREADONLY,FALSE,0
		
		; Subclass Edit Control to track cursor
		invoke SetWindowLong,hEdit,GWL_WNDPROC,offset EditProc
		mov OldEditProc,eax
		
		; Set focus to edit control
		invoke SetFocus,hEdit
		
		mov eax,FALSE
		ret

	.elseif eax==WM_NOTIFY
		mov edi,lParam
		mov eax,[edi].NMHDR.hwndFrom
		.if eax==hTreeView
			mov eax,[edi].NMHDR.code
			.if eax==NM_DBLCLK
				; Get selected item
				invoke SendMessage,hTreeView,TVM_GETNEXTITEM,TVGN_CARET,0
				.if eax!=0
					mov tvitem.hItem,eax
					mov tvitem.imask,TVIF_TEXT
					mov tvitem.pszText,offset szBuffer
					mov tvitem.cchTextMax,MAXSIZE
					invoke SendMessage,hTreeView,TVM_GETITEM,0,addr tvitem
					
					; Check if ".."
					invoke lstrcmp,addr szBuffer,offset szParentDir
					.if eax!=0
						; Construct full path
						invoke lstrcpy,addr szFileName,addr szCurrentDir
						invoke lstrcat,addr szFileName,offset szBackSlash
						invoke lstrcat,addr szFileName,addr szBuffer
						
						; Open file
						invoke CreateFile,addr szFileName,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL
						.if eax!=INVALID_HANDLE_VALUE
						    mov hFile,eax
						    invoke GetFileSize,hFile,NULL
						    mov fileSize,eax
							invoke SendMessage,hEdit,EM_SETLIMITTEXT,0,0
						
						    ; --- CORRECCI�N 1: Manejar archivo vac�o expl�citamente ---
						    .if fileSize == 0
						        ; Si est� vac�o, simplemente limpiamos el editor y no hacemos nada de memoria
						        invoke SetWindowText,hEdit,NULL
						    .else
						        ; Si TIENE contenido, procedemos con la memoria
						        
						        ; --- CORRECCI�N 2: Reservar fileSize + 1 byte ---
						        ; Necesitamos espacio extra para el terminador nulo (el 0 del final)
						        ; para no escribir fuera de la memoria reservada.
						        mov eax, fileSize
						        inc eax         ; Sumamos 1 al tama�o
						        
						        invoke GlobalAlloc,GMEM_MOVEABLE or GMEM_ZEROINIT, eax ; Usamos el tama�o + 1
						        .if eax!=NULL
						            push eax
						            invoke GlobalLock,eax
						            mov edi,eax
						            
						            ; Leemos el archivo (usamos fileSize original, no el incrementado)
						            invoke ReadFile,hFile,edi,fileSize,addr bytesRead,NULL
						            
						            ; Ponemos el terminador nulo al final
						            mov eax,bytesRead
						            mov byte ptr [edi+eax],0
						            
						            invoke SetWindowText,hEdit,edi
						            
						            pop eax
						            invoke GlobalUnlock,eax
						            invoke GlobalFree,eax
						        .endif
						    .endif
						    ; --- FIN DE LA CORRECCI�N ---
						
						    invoke CloseHandle,hFile
						    
						    mov bHasFileName,TRUE
						    mov bFileModified,FALSE
						    
						    call PopulateTreeView
						    
						    invoke wsprintf,addr buffer,addr szFileNameFormat,addr szFileName
						    invoke SendMessage,hStatusBar,SB_SETTEXT,0,addr buffer
						.endif
					.endif
				.endif
			.endif
		.endif

	.elseif eax==WM_COMMAND
		mov eax,wParam
		and eax,0FFFFh
		
		; Handle toolbar buttons
		.if eax==IDC_TOOLBAR_NEW
			; Clear edit control
			invoke SetWindowText,hEdit,NULL
			mov bFileModified,FALSE
			mov bHasFileName,FALSE
			mov szFileName,0
			invoke SendMessage,hStatusBar,SB_SETTEXT,0,addr szTitle
		.elseif eax==IDM_FILE_NEW
			; Clear edit control
			invoke SetWindowText,hEdit,NULL
			mov bFileModified,FALSE
			mov bHasFileName,FALSE
			mov szFileName,0
			invoke SendMessage,hStatusBar,SB_SETTEXT,0,addr szTitle
			
		.elseif eax==IDC_TOOLBAR_OPEN
			; Open file dialog
			mov ofn.lStructSize,sizeof OPENFILENAME
			push hWin
			pop ofn.hwndOwner
			push hInstance
			pop ofn.hInstance
			mov ofn.lpstrFilter,offset szFilter
			mov ofn.lpstrFile,offset szFileName
			mov ofn.nMaxFile,MAXSIZE
			mov ofn.lpstrFileTitle,offset szFileTitle
			mov ofn.nMaxFileTitle,MAXSIZE
			mov ofn.Flags,OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_HIDEREADONLY
			
			invoke GetOpenFileName,addr ofn
			.if eax!=0
				; Open and read file
				invoke CreateFile,addr szFileName,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL
				.if eax!=INVALID_HANDLE_VALUE
					mov hFile,eax
					
					; Get file size
					invoke GetFileSize,hFile,NULL
					mov fileSize,eax
					inc fileSize
					invoke SendMessage,hEdit,EM_SETLIMITTEXT,0,0
					
					; Allocate memory for file content
					invoke GlobalAlloc,GMEM_MOVEABLE or GMEM_ZEROINIT,fileSize
					.if eax!=NULL
						push eax
						invoke GlobalLock,eax
						mov edi,eax
						
						; Read file into buffer
						invoke ReadFile,hFile,edi,fileSize,addr bytesRead,NULL
						
						; Add null terminator
						mov eax,bytesRead
						mov byte ptr [edi+eax],0
						
						; Set text to edit control
						invoke SetWindowText,hEdit,edi
						
						; Cleanup memory
						pop eax
						invoke GlobalUnlock,eax
						invoke GlobalFree,eax
					.endif
					
					; Close file handle
					invoke CloseHandle,hFile
					
					mov bHasFileName,TRUE
					mov bFileModified,FALSE
					
					; Update TreeView with current directory
					call PopulateTreeView
					
					; Update title
					invoke wsprintf,addr buffer,addr szTitle
					invoke SendMessage,hStatusBar,SB_SETTEXT,0,addr buffer
				.endif
			.endif
		.elseif eax==IDM_FILE_OPEN
		.elseif eax==IDM_FILE_OPEN
			; Open file dialog
			mov ofn.lStructSize,sizeof OPENFILENAME
			push hWin
			pop ofn.hwndOwner
			push hInstance
			pop ofn.hInstance
			mov ofn.lpstrFilter,offset szFilter
			mov ofn.lpstrFile,offset szFileName
			mov ofn.nMaxFile,MAXSIZE
			mov ofn.lpstrFileTitle,offset szFileTitle
			mov ofn.nMaxFileTitle,MAXSIZE
			mov ofn.Flags,OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_HIDEREADONLY
			
			invoke GetOpenFileName,addr ofn
			.if eax!=0
				; Open and read file
				invoke CreateFile,addr szFileName,GENERIC_READ,FILE_SHARE_READ,NULL,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL
				.if eax!=INVALID_HANDLE_VALUE
					mov hFile,eax
					
					; Get file size
					invoke GetFileSize,hFile,NULL
					mov fileSize,eax
					inc fileSize
					invoke SendMessage,hEdit,EM_SETLIMITTEXT,0,0
					
					; Allocate memory for file content
					invoke GlobalAlloc,GMEM_MOVEABLE or GMEM_ZEROINIT,fileSize
					.if eax!=NULL
						push eax
						invoke GlobalLock,eax
						mov edi,eax
						
						; Read file into buffer
						invoke ReadFile,hFile,edi,fileSize,addr bytesRead,NULL
						
						; Add null terminator
						mov eax,bytesRead
						mov byte ptr [edi+eax],0
						
						; Set text to edit control
						invoke SetWindowText,hEdit,edi
						
						; Cleanup memory
						pop eax
						invoke GlobalUnlock,eax
						invoke GlobalFree,eax
					.endif
					
					; Close file handle
					invoke CloseHandle,hFile
					
					mov bHasFileName,TRUE
					mov bFileModified,FALSE
					
					; Update title
					invoke wsprintf,addr buffer,addr szTitle
					invoke SendMessage,hStatusBar,SB_SETTEXT,0,addr buffer
				.endif
			.endif
			
		.elseif eax==IDC_TOOLBAR_SAVE
			; Check if we have a filename
			.if bHasFileName==FALSE
				; Show Save As dialog
				mov ofn.lStructSize,sizeof OPENFILENAME
				push hWin
				pop ofn.hwndOwner
				push hInstance
				pop ofn.hInstance
				mov ofn.lpstrFilter,offset szFilter
				mov ofn.lpstrFile,offset szFileName
				mov ofn.nMaxFile,MAXSIZE
				mov ofn.lpstrFileTitle,offset szFileTitle
				mov ofn.nMaxFileTitle,MAXSIZE
				mov ofn.Flags,OFN_OVERWRITEPROMPT or OFN_HIDEREADONLY
				
				invoke GetSaveFileName,addr ofn
				.if eax==0
					jmp @F
				.endif
				mov bHasFileName,TRUE
			.endif
			
			; Save file
			invoke CreateFile,addr szFileName,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
			.if eax!=INVALID_HANDLE_VALUE
				mov hFile,eax
				
				; Get text length
				invoke GetWindowTextLength,hEdit
				.if eax>0
					inc eax
					invoke GlobalAlloc,GMEM_MOVEABLE or GMEM_ZEROINIT,eax
					.if eax!=NULL
						push eax
						invoke GlobalLock,eax
						mov edi,eax
						pop eax
						push eax
						
						; Get text
						invoke GetWindowText,hEdit,edi,65535
						
						; Write to file
						invoke lstrlen,edi
						mov fileSize,eax
						invoke WriteFile,hFile,edi,fileSize,addr bytesWritten,NULL
						
						; Cleanup
						pop eax
						invoke GlobalUnlock,eax
						invoke GlobalFree,eax
						
						mov bFileModified,FALSE
					.endif
				.endif
				
				invoke CloseHandle,hFile
				
				; Update TreeView with current directory
				call PopulateTreeView
				
				; Update status bar with filename
				invoke wsprintf,addr buffer,addr szFileNameFormat,addr szFileName
				invoke SendMessage,hStatusBar,SB_SETTEXT,0,addr buffer
			.endif
			@@:
		.elseif eax==IDM_FILE_SAVE
			; Check if we have a filename
			.if bHasFileName==FALSE
				; Show Save As dialog
				mov ofn.lStructSize,sizeof OPENFILENAME
				push hWin
				pop ofn.hwndOwner
				push hInstance
				pop ofn.hInstance
				mov ofn.lpstrFilter,offset szFilter
				mov ofn.lpstrFile,offset szFileName
				mov ofn.nMaxFile,MAXSIZE
				mov ofn.lpstrFileTitle,offset szFileTitle
				mov ofn.nMaxFileTitle,MAXSIZE
				mov ofn.Flags,OFN_OVERWRITEPROMPT or OFN_HIDEREADONLY
				
				invoke GetSaveFileName,addr ofn
				.if eax==0
					jmp @F
				.endif
				mov bHasFileName,TRUE
			.endif
			
			; Save file
			invoke CreateFile,addr szFileName,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
			.if eax!=INVALID_HANDLE_VALUE
				mov hFile,eax
				
				; Get text length
				invoke GetWindowTextLength,hEdit
				.if eax>0
					inc eax
					invoke GlobalAlloc,GMEM_MOVEABLE or GMEM_ZEROINIT,eax
					.if eax!=NULL
						push eax
						invoke GlobalLock,eax
						mov edi,eax
						pop eax
						push eax
						
						; Get text
						invoke GetWindowText,hEdit,edi,65535
						
						; Write to file
						invoke lstrlen,edi
						mov fileSize,eax
						invoke WriteFile,hFile,edi,fileSize,addr bytesWritten,NULL
						
						; Cleanup
						pop eax
						invoke GlobalUnlock,eax
						invoke GlobalFree,eax
						
						mov bFileModified,FALSE
					.endif
				.endif
				
				invoke CloseHandle,hFile
				
				; Update TreeView with current directory
				call PopulateTreeView
				
				; Update status bar with filename
				invoke wsprintf,addr buffer,addr szFileNameFormat,addr szFileName
				invoke SendMessage,hStatusBar,SB_SETTEXT,0,addr buffer
			.endif
			@@:
		.elseif eax==IDC_BTN1
			invoke SendMessage,hWin,WM_COMMAND,IDC_TOOLBAR_SAVE,0
			
		.elseif eax==IDM_FILE_SAVEAS
			; Save As dialog
			mov ofn.lStructSize,sizeof OPENFILENAME
			push hWin
			pop ofn.hwndOwner
			push hInstance
			pop ofn.hInstance
			mov ofn.lpstrFilter,offset szFilter
			mov ofn.lpstrFile,offset szFileName
			mov ofn.nMaxFile,MAXSIZE
			mov ofn.lpstrFileTitle,offset szFileTitle
			mov ofn.nMaxFileTitle,MAXSIZE
			mov ofn.Flags,OFN_OVERWRITEPROMPT or OFN_HIDEREADONLY
			
			invoke GetSaveFileName,addr ofn
			.if eax!=0
				mov bHasFileName,TRUE
				; Use same save code as above
				invoke CreateFile,addr szFileName,GENERIC_WRITE,0,NULL,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,NULL
				.if eax!=INVALID_HANDLE_VALUE
					push eax
					invoke GetWindowTextLength,hEdit
					.if eax>0
						inc eax
						invoke GlobalAlloc,GMEM_MOVEABLE or GMEM_ZEROINIT,eax
						.if eax!=NULL
							push eax
							invoke GlobalLock,eax
							mov edi,eax
							pop eax
							push eax
							invoke GetWindowText,hEdit,edi,65535
							invoke lstrlen,edi
							mov fileSize,eax
							invoke WriteFile,hFile,edi,fileSize,addr bytesWritten,NULL
							pop eax
							invoke GlobalUnlock,eax
							invoke GlobalFree,eax
							mov bFileModified,FALSE
						.endif
					.endif
					pop eax
					invoke CloseHandle,eax
				.endif
			.endif
			
		.elseif eax==IDM_FILE_EXIT
			invoke SendMessage,hWin,WM_CLOSE,0,0
			
		.elseif eax==IDC_TOOLBAR_UNDO
			; Undo
			invoke SendMessage,hEdit,EM_UNDO,0,0
			
		.elseif eax==IDM_EDIT_UNDO
			; Undo
			invoke SendMessage,hEdit,EM_UNDO,0,0
			
		.elseif eax==IDC_TOOLBAR_REDO
			; Redo (not directly supported in standard edit control, but we try)
			invoke SendMessage,hEdit,EM_UNDO,0,0
			
		.elseif eax==IDM_EDIT_REDO
			; Redo (not directly supported in standard edit control, but we try)
			invoke SendMessage,hEdit,EM_UNDO,0,0
			
		.elseif eax==IDC_TOOLBAR_INFO
			invoke DialogBoxParam,hInstance,IDD_INFO,hWin,addr InfoProc,NULL

		.else
			; Check if edit control changed
			mov eax,wParam
			shr eax,16
			.if eax==EN_CHANGE
				; Update status bar with line and column
				call UpdateStatusBar
				
				mov bFileModified,TRUE
				
				; Show unsaved message if no filename
				.if bHasFileName==FALSE
					invoke SendMessage,hStatusBar,SB_SETTEXT,1,addr szUnsavedMsg
				.endif
			.endif
		.endif

	.elseif eax==WM_SIZE
		; Resize status bar
		invoke SendMessage,hStatusBar,WM_SIZE,0,0

	.elseif eax==WM_CLOSE
		invoke EndDialog,hWin,0
	.else
		mov		eax,FALSE
		ret
	.endif
	mov		eax,TRUE
	ret

DlgProc endp

;########################################################################
; PopulateTreeView - Populate TreeView with files from current directory
;########################################################################

PopulateTreeView proc
	LOCAL wfd:WIN32_FIND_DATA
	LOCAL hFind:DWORD
	LOCAL tvi:TV_INSERTSTRUCT
	LOCAL searchPath[MAXSIZE]:BYTE
	LOCAL pLastSlash:DWORD
	LOCAL currentFile[MAXSIZE]:BYTE
	LOCAL hItem:DWORD
	
	; Clear TreeView
	invoke SendMessage,hTreeView,TVM_DELETEITEM,0,TVI_ROOT
	
	; Extract directory from szFileName
	invoke lstrcpy,addr szCurrentDir,addr szFileName
	
	; Find last backslash
	mov esi,offset szCurrentDir
	mov pLastSlash,0
	@@:
	lodsb
	test al,al
	jz @F
	cmp al,'\'
	jne @B
	dec esi
	mov pLastSlash,esi
	inc esi
	jmp @B
	@@:
	
	; Extract filename (part after last slash)
	mov esi,pLastSlash
	.if esi!=0
		inc esi
		invoke lstrcpy,addr currentFile,esi
	.else
		invoke lstrcpy,addr currentFile,addr szFileName
	.endif

	; Terminate at last backslash to get directory
	mov esi,pLastSlash
	.if esi!=0
		mov byte ptr [esi],0
	.endif
	
	; Add ".." item
	mov tvi.hParent,TVI_ROOT
	mov tvi.hInsertAfter,TVI_LAST
	mov tvi.item.imask,TVIF_TEXT
	mov tvi.item.pszText,offset szParentDir
	invoke SendMessage,hTreeView,TVM_INSERTITEM,0,addr tvi
	
	; Create search pattern (directory\*.*)
	invoke lstrcpy,addr searchPath,addr szCurrentDir
	invoke lstrcat,addr searchPath,offset szAllFiles
	
	; Find first file
	invoke FindFirstFile,addr searchPath,addr wfd
	mov hFind,eax
	.if eax!=INVALID_HANDLE_VALUE
		@@:
		; Skip directories (. and ..)
		test wfd.dwFileAttributes,FILE_ATTRIBUTE_DIRECTORY
		jnz skipFile
		
		; Add file to TreeView
		mov tvi.hParent,TVI_ROOT
		mov tvi.hInsertAfter,TVI_LAST
		mov tvi.item.imask,TVIF_TEXT
		lea eax,wfd.cFileName
		mov tvi.item.pszText,eax
		invoke SendMessage,hTreeView,TVM_INSERTITEM,0,addr tvi
		mov hItem,eax
		
		; Check if it matches current file
		invoke lstrcmpi,addr wfd.cFileName,addr currentFile
		.if eax==0
			invoke SendMessage,hTreeView,TVM_SELECTITEM,TVGN_CARET,hItem
		.endif
		
		skipFile:
		; Find next file
		invoke FindNextFile,hFind,addr wfd
		test eax,eax
		jnz @B
		
		invoke FindClose,hFind
	.endif
	
	ret
PopulateTreeView endp

;########################################################################
; UpdateStatusBar - Updates line and column number in status bar
;########################################################################

UpdateStatusBar proc
	LOCAL lineNum:DWORD
	LOCAL colNum:DWORD
	LOCAL charIndex:DWORD
	LOCAL buffer[256]:BYTE

	invoke SendMessage,hEdit,EM_LINEINDEX,-1,0
	mov charIndex,eax
	
	invoke SendMessage,hEdit,EM_LINEFROMCHAR,-1,0
	inc eax
	mov lineNum,eax
	
	invoke SendMessage,hEdit,EM_GETSEL,0,0
	and eax,0FFFFh
	sub eax,charIndex
	inc eax
	mov colNum,eax
	
	invoke wsprintf,addr buffer,addr szStatusFormat,lineNum,colNum
	invoke SendMessage,hStatusBar,SB_SETTEXT,0,addr buffer
	ret
UpdateStatusBar endp

;########################################################################
; EditProc - Subclassed Edit Control Procedure
;########################################################################

EditProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	invoke CallWindowProc,OldEditProc,hWin,uMsg,wParam,lParam
	
	.if uMsg==WM_KEYUP || uMsg==WM_LBUTTONUP
		push eax
		call UpdateStatusBar
		pop eax
	.endif
	
	ret
EditProc endp

;########################################################################
; InfoProc - Info Dialog Procedure
;########################################################################

InfoProc proc hWin:HWND,uMsg:UINT,wParam:WPARAM,lParam:LPARAM
	mov eax,uMsg
	.if eax==WM_INITDIALOG
		; Set icon
		invoke LoadIcon,hInstance,IDI_ICON
		invoke SendMessage,hWin,WM_SETICON,ICON_BIG,eax
		invoke SendMessage,hWin,WM_SETICON,ICON_SMALL,eax
		mov eax,TRUE
		ret
	.elseif eax==WM_COMMAND
		mov eax,wParam
		.if eax==IDOK || eax==IDCANCEL
			invoke EndDialog,hWin,0
		.endif
	.elseif eax==WM_CLOSE
		invoke EndDialog,hWin,0
	.else
		mov eax,FALSE
		ret
	.endif
	mov eax,TRUE
	ret
InfoProc endp

end start

