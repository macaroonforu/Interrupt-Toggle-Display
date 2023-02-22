//LAB FOUR PART ONE      
			  .equ      EDGE_TRIGGERED,    0x1
               .equ      LEVEL_SENSITIVE,   0x0
               .equ      CPU0,              0x01    // bit-mask; bit 0 represents cpu0
               .equ      ENABLE,            0x1

               .equ      KEY0,              0b0001
               .equ      KEY1,              0b0010
               .equ      KEY2,              0b0100
               .equ      KEY3,              0b1000

               .equ      IRQ_MODE,          0b10010
               .equ      SVC_MODE,          0b10011

               .equ      INT_ENABLE,        0b01000000
               .equ      INT_DISABLE,       0b11000000
/*********************************************************************************
 * Initialize the exception vector table
 ********************************************************************************/
                .section .vectors, "ax"

                B        _start             // reset vector
                .word    0                  // undefined instruction vector
                .word    0                  // software interrrupt vector
                .word    0                  // aborted prefetch vector
                .word    0                  // aborted data vector
                .word    0                  // unused vector
                B        IRQ_HANDLER        // IRQ interrupt vector
				                            //If an interrupt is detected, branch to 
											//IRQ_handler
                .word    0                  // FIQ interrupt vector

/*********************************************************************************
 * Main program
 ********************************************************************************/
//LAB FOUR PART ONE
                .text
                .global  _start
				
				
_start:        //Clear the hex display 
                MOV R0, #0
				LDR R1, =0xFF200020 //Address of Hex Display
				STR R0, [R1] 
                
				/* Set up stack pointers for IRQ and SVC processor modes */
                MOV      R1, #0b11010010    //I bit= 1: interrupts disabled, Mode=10010: IRQ
                MSR      CPSR_c, R1        //Modify the lower 8 bits of the CPSR to change into IRQ                   
                LDR      SP, =0x40000     //Initalize R13_IRQ sp to point far away from our program 
				
				MOV      R1, #0b11010011   //I bit =1: interrupts disabled, Mode=10011: SVC
                MSR      CPSR_c, R1       //Modify the lower 8 bits of the CPSR to change into SVC
                LDR      SP, =0x20000    //Initalize R13_SVC sp to point far away from our program 

                BL       CONFIG_GIC              // configure the ARM generic interrupt controller

                // Configure the KEY pushbutton port to generate interrupts
                LDR      R0, =0xFF200050      //Load pushbutton KEY base address into R0
                MOV      R1, #0xF            // R1<- 1111
                STR      R1, [R0, #0x8]     // Enable interrupts by storing ones into the 
				                           //Interrupt mask register 

                // enable IRQ interrupts in the processor
                MOV      R0, #0b01010011  //I bit =0: Interrupts enabled, Mode=10011: SVC
                MSR      CPSR_c, R0      //Modify lower 8 bits of the CPSR to change into SVC 
				                        //w/enabled interrupts
										
										
IDLE:           B        IDLE         // main program simply idles, until a key triggers an interrupt
				                     //then it branches to IRQ_handler 

IRQ_HANDLER:     PUSH     {R0-R7, LR}
                /* Read the ICCIAR in the CPU interface */
                LDR      R4, =0xFFFEC100     //0xFFFEC10C is the address of the ICCIAR.
				                            //It will contain the interrupt ID                            
                LDR      R5, [R4, #0x0C]    //Load the interrupt ID into R5 to check which device
				                           //caused the interrupt 
										   
CHECK_KEYS:     CMP      R5, #73          //Interrupt ID of the keys is #73


UNEXPECTED:     BNE      UNEXPECTED      //BNE would imply another device caused the interrupt, 
                                        //so stop 
                BL       KEY_ISR      //Execute this subroutine, then exit the interrupt by 
				                     //Entering the EXIT_IRQ subroutine 
									 
EXIT_IRQ:       /* Write to the End of Interrupt Register (ICCEOIR) */
                STR      R5, [R4, #0x10]    //0xFFFEC110 is the end of interrupt regiser. 
				                           //Store the interrupt ID into the ICCEOIR to tell the GIC
										  //That the processor has seen the interrupt from the keys,
										 //And to tell the GIC to turn off that interrupt 
    
                POP      {R0-R7, LR}
                SUBS     PC, LR, #4   //Subtract 4 from the LR so we point to the next instruction 
				                     //instead of the next next instruction 
/*****************************************************0xFF200050***********************************
 * Pushbutton - Interrupt Service Routine                                
 *                                                                          
 * This routine checks which KEY(s) have been pressed. It writes to HEX3-0
 ***************************************************************************************/
                .global  KEY_ISR
				
KEY_ISR:        PUSH {R4-R9, LR}
                LDR R6, =0xFF200020   //Address of Hex Display
				LDR R4, [R6] //Load into R4 what we are currently displaying on the keys
				LDR R8, =0xFF200050  //Address of the keys 
				LDR R9, [R8, #0xC]   //Load the ECR into R9 
				
CHECK_ZERO:    CMP R9, #1
			   BNE CHECK_ONE
			   STR R9, [R8, #0xC] //Reset the ECR
			   B ZERO_EXECUTE
			   
CHECK_ONE:     CMP R9, #2
               BNE CHECK_TWO
			   STR R9, [R8, #0xC] //Reset the ECR
			   B ONE_EXECUTE
			   
CHECK_TWO:    CMP R9, #4
              BNE THREE_EXECUTE
			  STR R9, [R8, #0xC] //Reset the ECR
			  B TWO_EXECUTE
			  
ZERO_EXECUTE: LDR R7, =0xFF
			  ANDS R5, R4, R7
			  LDR R7, =0x3F
			  CMP R5, R7
			  BEQ BLANK_ZERO
			  ORR R4, R7
			  B DISPLAY
			  
BLANK_ZERO: LDR R5, =0xFFFFFF00
            ANDS R4, R5
			B DISPLAY 

ONE_EXECUTE:  LDR R7, =0xFF00
              ANDS R5, R4, R7
			  LDR  R7, =0x600
			  CMP R5, R7
			  BEQ BLANK_ONE
			  ORR R4, R7
			  B DISPLAY
			  
BLANK_ONE:   LDR R5, =0xFFFF00FF
             AND R4, R5
			 B DISPLAY
			 
TWO_EXECUTE:  LDR R7, =0xFF0000
              ANDS R5, R4, R7
			  LDR R7, =0x5B0000
			  CMP R5, R7
			  BEQ BLANK_TWO
			  ORR R4, R7
			  B DISPLAY
			  
BLANK_TWO:   LDR R5, =0xFF00FFFF
             AND R4, R5
			 B DISPLAY
			 
THREE_EXECUTE: STR R9, [R8, #0xC] //Reset the ECR
               LDR R7, =0xFF000000
			   ANDS R5, R4, R7
			   LDR R7, =0x4F000000
			   CMP R5, R7
			   BEQ BLANK_THREE
			   ORR R4, R7
			   B DISPLAY
			   
BLANK_THREE:   LDR R5, =0x00FFFFFF
               AND R4, R5
			   B DISPLAY

DISPLAY:        STR R4, [R6]
				POP {R4-R9, LR}
				MOV PC, LR
/* 
 * Configure the Generic Interrupt Controller (GIC)
*/
                .global  CONFIG_GIC
CONFIG_GIC:
                PUSH     {LR}
                /* Enable the KEYs interrupts */
                MOV      R0, #73
                MOV      R1, #CPU0
                /* CONFIG_INTERRUPT (int_ID (R0), CPU_target (R1)); */
                BL       CONFIG_INTERRUPT

                /* configure the GIC CPU interface */
                LDR      R0, =0xFFFEC100        // base address of CPU interface
                /* Set Interrupt Priority Mask Register (ICCPMR) */
                LDR      R1, =0xFFFF            // enable interrupts of all priorities levels
                STR      R1, [R0, #0x04]
                /* Set the enable bit in the CPU Interface Control Register (ICCICR). This bit
                 * allows interrupts to be forwarded to the CPU(s) */
                MOV      R1, #1
                STR      R1, [R0]
    
                /* Set the enable bit in the Distributor Control Register (ICDDCR). This bit
                 * allows the distributor to forward interrupts to the CPU interface(s) */
                LDR      R0, =0xFFFED000
                STR      R1, [R0]    
    
                POP      {PC}
/* 
 * Configure registers in the GIC for an individual interrupt ID
 * We configure only the Interrupt Set Enable Registers (ICDISERn) and Interrupt 
 * Processor Target Registers (ICDIPTRn). The default (reset) values are used for 
 * other registers in the GIC
 * Arguments: R0 = interrupt ID, N
 *            R1 = CPU target
*/
CONFIG_INTERRUPT:
                PUSH     {R4-R5, LR}
    
                /* Configure Interrupt Set-Enable Registers (ICDISERn). 
                 * reg_offset = (integer_div(N / 32) * 4
                 * value = 1 << (N mod 32) */
                LSR      R4, R0, #3               // calculate reg_offset
                BIC      R4, R4, #3               // R4 = reg_offset
                LDR      R2, =0xFFFED100
                ADD      R4, R2, R4               // R4 = address of ICDISER
    
                AND      R2, R0, #0x1F            // N mod 32
                MOV      R5, #1                   // enable
                LSL      R2, R5, R2               // R2 = value

                /* now that we have the register address (R4) and value (R2), we need to set the
                 * correct bit in the GIC register */
                LDR      R3, [R4]                 // read current register value
                ORR      R3, R3, R2               // set the enable bit
                STR      R3, [R4]                 // store the new register value

                /* Configure Interrupt Processor Targets Register (ICDIPTRn)
                  * reg_offset = integer_div(N / 4) * 4
                  * index = N mod 4 */
                BIC      R4, R0, #3               // R4 = reg_offset
                LDR      R2, =0xFFFED800
                ADD      R4, R2, R4               // R4 = word address of ICDIPTR
                AND      R2, R0, #0x3             // N mod 4
                ADD      R4, R2, R4               // R4 = byte address in ICDIPTR

                /* now that we have the register address (R4) and value (R2), write to (only)
                 * the appropriate byte */
                STRB     R1, [R4]
                POP      {R4-R5, PC}
                .end   
