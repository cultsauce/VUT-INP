; Autor reseni: Tereza Kubincova xkubin27

; Projekt 2 - INP 2022
; Vernamova sifra na architekture MIPS64

; DATA SEGMENT
                .data
login:          .asciiz "xkubin27"  ; sem doplnte vas login
cipher:         .space  17  ; misto pro zapis sifrovaneho loginu

params_sys5:    .space  8   ; misto pro ulozeni adresy pocatku
                            ; retezce pro vypis pomoci syscall 5
                            ; (viz nize "funkce" print_string)

; CODE SEGMENT
                .text
                ;xkubin27-r1-r27-r30-r23-r0-r4
                ; ZDE NAHRADTE KOD VASIM RESENIM
main:           
                daddi   r30, r0, 11 ; login offset +
                daddi   r27, r0, 21 ;login offset -
cycle:  
                ; START OF +OFFSET PARSING

                daddi   r4, r23, login
                lb      r1, 0(r4)
                slti    r4, r1, 97 ; validate if the current character isnt a number
                bne     r4, r0, end 
                dadd    r1, r1, r30

                slti    r4, r1, 123
                bne     r4, r0, no_circle1 
                ; r1 is not within range
                daddi   r1, r1, -123
                daddi   r1, r1, 97

no_circle1:     ; r1 is within range
                daddi   r4, r23, cipher
                sb      r1, 0(r4)
            
                ; END OF +OFFSET PARSING
                ; START OF -OFFSET PARSING

                daddi   r4, r23, login
                lb      r1, 1(r4)
                slti    r4, r1, 97 ; validate if the current character isnt a number
                bne    r4, r0, end
                dsub    r1, r1, r27

                slti    r4, r1, 97
                bne    r4, r0, no_circle2

                ; r1 is within range
                b       continue

no_circle2:     ; r1 is not within range
                daddi   r1, r1, -96
                daddi   r1, r1, 122

continue:       daddi   r4, r23, cipher
                sb      r1, 1(r4)
                ; END OF +OFFSET PARSING

                daddi   r23, r23, 2   
                b       cycle
end:
                daddi   r4, r0, cipher
                jal     print_string    ; vypis pomoci print_string - viz nize
                syscall 0   ; halt

print_string:   ; adresa retezce se ocekava v r4
                sw      r4, params_sys5(r0)
                daddi   r14, r0, params_sys5    ; adr pro syscall 5 musi do r14
                syscall 5   ; systemova procedura - vypis retezce na terminal
                jr      r31 ; return - r31 je urcen na return address
