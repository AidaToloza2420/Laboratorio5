; Archivo: Prelab5.s
; Dispositivo: PIC16F887 
; Autor: Aida Toloza
; Copilador: pic-as (v2.30), MPLABX v5.40
;
; Programa: Displays Simultaneos
; Hardware: Contador binario de 8 bits que incremente en RB0 Y decremente en RB1
;
; Creado: 20 de febrero , 2022
; Última modificación: 26 febrero, 2022
    
PROCESSOR 16F887
#include <xc.inc>

; CONFIGURACIÓN 1
  CONFIG  FOSC = INTRC_NOCLKOUT // Oscilador interno sin salidas
  CONFIG  WDTE = OFF            // WDT disabled (reinicio repetitivo del pic)
  CONFIG  PWRTE = ON            // PWRT enabled (reinicio repetitivo del pic)
  CONFIG  MCLRE = OFF           // El pin de MCLR se utiliza como I/O
  CONFIG  CP = OFF              // Sin protección de código
  CONFIG  CPD = OFF             // Sin protección de datos
  CONFIG  BOREN = OFF           // Sin reinicio cuando el voltaje de alimentación baja de 4V
  CONFIG  IESO = OFF            // Reinicio sin cambio de reloj de interno a externo 
  CONFIG  FCMEN = OFF           // Cambio de reloj externo a interno en caso de fallo
  CONFIG  LVP = ON              // Programación en bajo voltaje permitida

; CONFIGURACIÓN 2
  CONFIG  BOR4V = BOR40V        // Reinicio abajo de 4V, (BOR21V=2.1V)
  CONFIG  WRT = OFF             // Protección de autoescritura por el programa desactivado
  
 
UP EQU 1
DOWN EQU 0
 
PSECT udata_bank0
    CONTA:              DS 1    ; Para hacer la division
    CENTENA:            DS 1
    DECENA:             DS 1
    UNIDADES:           DS 1
    banderas:		DS 1	; Indica que display hay que encender
    display:		DS 3	; Representación de cada nibble en el display de 7-seg

 
; -------------- MACROS --------------- 
  ; Macro para reiniciar el valor del TMR0
  ; **Recibe el valor a configurar en TMR_VAR**
  RESET_TMR0 MACRO
    BANKSEL TMR0	    ; cambiamos de banco
    MOVLW   217
    MOVWF   TMR0	    ; configuramos tiempo de retardo
    BCF	    T0IF	    ; limpiamos bandera de interrupción
    ENDM
  
; ------- VARIABLES EN MEMORIA --------
PSECT udata_shr		    ; Memoria compartida
    W_TEMP:		DS 1
    STATUS_TEMP:	DS 1
    
    
PSECT resVect, class=CODE, abs, delta=2
ORG 00h			    ; posición 0000h para el reset
;------------ VECTOR RESET --------------
resetVec:
    PAGESEL MAIN		; Cambio de pagina
    GOTO    MAIN
    
PSECT intVect, class=CODE, abs, delta=2
ORG 04h				; posición 0004h para interrupciones
;------- VECTOR INTERRUPCIONES ----------
PUSH:
    MOVWF   W_TEMP		; Guardamos W
    SWAPF   STATUS, W
    MOVWF   STATUS_TEMP		; Guardamos STATUS
    
ISR:
    BTFSC   RBIF		; Fue interrupción del PORTB? No=0 Si=1
    CALL    INT_PORTB		; Si -> Subrutina de interrupción de PORTB
    BANKSEL PORTA
    
    BTFSC   T0IF		; Fue interrupción del TMR0? No=0 Si=1
    CALL    INT_TMR0		; Si -> Subrutina de interrupción de TMR0
POP:
    SWAPF   STATUS_TEMP, W  
    MOVWF   STATUS		; Recuperamos el valor de reg STATUS
    SWAPF   W_TEMP, F	    
    SWAPF   W_TEMP, W		; Recuperamos valor de W
    RETFIE			; Regresamos a ciclo principal
    
    
PSECT code, delta=2, abs
ORG 100h			; posición 100h para el codigo
;------------- CONFIGURACION ------------
MAIN:
    CALL    CONFIG_IO		; Configuración de I/O
    CALL    CONFIG_RELOJ	; Configuración de Oscilador
    CALL    CONFIG_TMR0		; Configuración de TMR0
    CALL    CONFIG_INT		; Configuración de interrupciones
    CALL    config_iocrb        ;Configuraciones de la interrumpciones del puerto B
    BANKSEL PORTA		; Cambio a banco 00
    
LOOP:
    ;MOVF   PORTA, W		; Valor del PORTA a W
    ;MOVWF   valor		; Movemos W a variable valor
    CALL    SET_DISPLAY		; Para llevar los valores decimales a los display
    CALL    OBTENER_DIVISION	; Rutina para obtener la division de centenas, decenas, unidades
    GOTO    LOOP	    
    
;------------- SUBRUTINAS ---------------
CONFIG_RELOJ:
    BANKSEL OSCCON		; cambiamos a banco 1
    BSF	    OSCCON, 0		; SCS -> 1, Usamos reloj interno
    BSF	    OSCCON, 6
    BSF	    OSCCON, 5
    BCF	    OSCCON, 4		; IRCF<2:0> -> 110 4MHz
    RETURN
    
; Configuramos el TMR0 para obtener un retardo de 50ms
CONFIG_TMR0:
    BANKSEL OPTION_REG		; cambiamos de banco
    BCF	    OPTION_REG, 5		; TMR0 como temporizador
    BCF	    OPTION_REG, 3			; prescaler a TMR0
    BSF	    OPTION_REG, 2
    BSF	    OPTION_REG, 1
    BSF	    OPTION_REG, 0			; PS<2:0> -> 111 prescaler 1 : 256
    RESET_TMR0   		; Reiniciamos TMR0 para 10ms
    RETURN 
    
 CONFIG_IO:
    BANKSEL ANSEL
    CLRF    ANSEL
    CLRF    ANSELH              ; I/O digitales
    
    BANKSEL TRISA
    BSF	    TRISB, UP	; RB0 como entrada / Botón modo
    BSF	    TRISB, DOWN	; RB1 como entrada / Botón acción
    
    CLRF    TRISA		; RBA como salida
    CLRF    TRISC
    CLRF    TRISD
    
    BCF     OPTION_REG, 7       ; Habilita resistencia pull-up
    BSF     WPUB, UP
    BSF     WPUB, DOWN
    
    BANKSEL PORTA
    CLRF    PORTA		; Apagamos PORTC
    CLRF    PORTB		; Apagamos PORTC
    CLRF    PORTC		; Apagamos PORTC
    CLRF    PORTD		; Apagamos PORTA
    CLRF    CENTENA		; Limpiamos VARIABLES
    CLRF    DECENA		; Limpiamos VARIABLES
    CLRF    UNIDADES		; Limpiamos VARIABLES
    CLRF    banderas		; Limpiamos VARIABLES
    
    RETURN
    
CONFIG_INT:
    BANKSEL INTCON
    BSF	    GIE			; Habilitamos interrupciones
    BSF     RBIE                ; Habilitamos interrupción puerto B
    BCF	    RBIF		; Limpiamos bandera de int. de PORTB

    BSF	    T0IE                ; Habilitamos interrupcion TMR0
    BCF	    T0IF		; Limpiamos bandera de int. de TMR0
    RETURN
    
config_iocrb:
    banksel TRISA
    bsf IOCB, UP
    bsf IOCB, DOWN
    
    banksel PORTA
    movf PORTB, W   ; al leer termina la condición mismatch
    bcf RBIF
    return
    
INT_PORTB:
    banksel PORTA
    btfss PORTB, UP  ;Se verifica que dato esta entrando
    incf PORTA ; Se incrementa el PORTB si esta en 1
    btfss PORTB, DOWN
    decf PORTA  ;Se decrementa el PORTB si esta en 0
    bcf RBIF  ; se reinicia la bandera
    return
    
INT_TMR0:
    RESET_TMR0		; Reiniciamos TMR0 para 10ms
    CALL    MOSTRAR_VALOR	; Mostramos valor en DECIMALES en los displays
   
    RETURN
    
SET_DISPLAY:
    MOVF    UNIDADES, W		; Movemos nibble bajo a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   display		; Guardamos en display
    
    MOVF    DECENA, W		; Movemos nibble bajo a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   display+1		; Guardamos en display
    
    MOVF    CENTENA, W	; Movemos nibble alto a W
    CALL    TABLA_7SEG		; Buscamos valor a cargar en PORTC
    MOVWF   display+2		; Guardamos en display+1
    RETURN
 
MOSTRAR_VALOR:
    BCF	    PORTD, 0		; Apagamos display de nibble alto
    BCF	    PORTD, 1		; Apagamos display de nibble bajo
    BCF	    PORTD, 2		; Apagamos display de nibble bajo    
    BTFSC   banderas, 0		; Verificamos bandera
    GOTO    DISPLAY3		; 
    BTFSC   banderas, 1		; Verificamos bandera
    GOTO    DISPLAY2		; 
    BTFSC   banderas, 2		; Verificamos bandera
    GOTO    DISPLAY1		; 
    
DISPLAY1:			
    MOVF    display, W	; Movemos display a W
    MOVWF   PORTC		; Movemos Valor de tabla a PORTC
    BSF	    PORTD, 2	; Encendemos display de nibble bajo
    BCF	banderas, 2	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    BSF	banderas, 1	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN

DISPLAY2:
    MOVF    display +1, W	; Movemos display+1 a W
    MOVWF   PORTC		; Movemos Valor de tabla a PORTC
    BSF	    PORTD, 1	; Encendemos display de nibble alto
    BCF	banderas, 1	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    BSF	banderas, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    RETURN

DISPLAY3:
    MOVF    display +2, W	; Movemos display+1 a W
    MOVWF   PORTC		; Movemos Valor de tabla a PORTC
    BSF	    PORTD, 0	; Encendemos display de nibble alto
    BCF	banderas, 0	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    BSF	banderas, 2	; Cambiamos bandera para cambiar el otro display en la siguiente interrupción
    
    RETURN
    
    
OBTENER_DIVISION:	        ;    Ejemplo:
    CLRF    CENTENA		; Limpiamos la variable
    CLRF    DECENA		; Limpiamos la variable
    CLRF    UNIDADES            ; Limpiamos la variable
    ; Obtenemos CENTENAS
    MOVF    PORTA, W		;
    MOVWF   CONTA
    MOVLW   100                 ; Se agrega 100 a w
    SUBWF   CONTA, F		;
    INCF    CENTENA             ; Se incrementa 1 a la variable CENTENA
    BTFSC   STATUS,0            ; Se verifica la bandera BOROOW
    
    GOTO    $-4                 ; Si esta encendida la bandera se regresa a 4 instrucciones 
    DECF    CENTENA
    
    MOVLW   100		
    ADDWF   CONTA,F
    CALL    OBTENER_DECENAS    ; Se llama la rutina para obtener las decenas
    RETURN
    
OBTENER_DECENAS:	        ;    Ejemplo:
    ; Obtenemos DECENAS

    MOVLW   10                  ; Se agrega 10 a w
    SUBWF   CONTA, F		;
    INCF    DECENA             ; Se incrementa 1 a la variable CENTENA
    BTFSC   STATUS,0            ; Se verifica la bandera BOROOW
    
    GOTO    $-4                 ; Si esta encendida la bandera se regresa a 4 instrucciones 
    DECF    DECENA
    
    MOVLW   10	
    ADDWF   CONTA,F
    CALL    OBTENER_UNIDADES    ; Se llama la rutina para obtener las unidades
    RETURN
    
    
OBTENER_UNIDADES:	        ;    Ejemplo:
    ; Obtenemos UNIDADES
    MOVLW   1                   ; Se agrega 1 a w
    SUBWF   CONTA,F		;
    INCF    UNIDADES             ; Se incrementa 1 a la variable CENTENA
    BTFSC   STATUS,0            ; Se verifica la bandera BOROOW
    
    GOTO    $-4                 ; Si esta encendida la bandera se regresa a 4 instrucciones 
    DECF    UNIDADES
    
    MOVLW   1		
    ADDWF   CONTA,F
    RETURN
    
ORG 200h
TABLA_7SEG:
    CLRF    PCLATH		; Limpiamos registro PCLATH
    BSF	    PCLATH, 1		; Posicionamos el PC en dirección 02xxh
    ANDLW   0x0F		; no saltar más del tamaño de la tabla
    ADDWF   PCL
    RETLW   00111111B	;0
    RETLW   00000110B	;1
    RETLW   01011011B	;2
    RETLW   01001111B	;3
    RETLW   01100110B	;4
    RETLW   01101101B	;5
    RETLW   01111101B	;6
    RETLW   00000111B	;7
    RETLW   01111111B	;8
    RETLW   01101111B	;9
    RETLW   01110111B	;A
    RETLW   01111100B	;b
    RETLW   00111001B	;C
    RETLW   01011110B	;d
    RETLW   01111001B	;E
    RETLW   01110001B	;F
    
END
    
    