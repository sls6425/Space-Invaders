// Lab9.c
// Runs on LM4F120 or TM4C123
// Student names: Nik Srinivas, Savannah Schmidt
// Last Modified: 4/23/2019

// Analog Input connected to PE2=ADC1
// displays on Sitronox ST7735
// PF3, PF2, PF1 are heartbeats
// This U0Rx PC4 (in) is connected to other LaunchPad PC5 (out)
// This U0Tx PC5 (out) is connected to other LaunchPad PC4 (in)
// This ground is connected to other LaunchPad ground
// * Start with where you left off in Lab8. 
// * Get Lab8 code working in this project.
// * Understand what parts of your main have to move into the UART1_Handler ISR
// * Rewrite the SysTickHandler
// * Implement the s/w Fifo on the receiver end 
//    (we suggest implementing and testing this first)

#include <stdint.h>

#include "ST7735.h"
#include "PLL.h"
#include "ADC.h"
#include "print.h"
#include "../inc/tm4c123gh6pm.h"
#include "Uart.h"
#include "FiFo.h"

//*****the first three main programs are for debugging *****
// main1 tests just the ADC and slide pot, use debugger to see data
// main2 adds the LCD to the ADC and slide pot, ADC data is on Nokia
// main3 adds your convert function, position data is no Nokia

void DisableInterrupts(void); // Disable interrupts
void EnableInterrupts(void);  // Enable interrupts
void UART1_Handler(void);


uint32_t Data;      // 12-bit ADC
uint32_t Position;  // 32-bit fixed-point 0.001 cm

uint8_t message[8];			// message array
uint8_t hold = 0;				// holds number to be put into array
uint32_t Cnt = 0;	// transmission counter
uint32_t State = 0;			// state of mailbox
uint32_t ADC = 0;				// holds data from ADC
uint8_t out[8];
char packet;						// data sent or received 



#define PF1       (*((volatile uint32_t *)0x40025008))
#define PF2       (*((volatile uint32_t *)0x40025010))
#define PF3       (*((volatile uint32_t *)0x40025020))



// Initialize Port F so PF1, PF2 and PF3 are heartbeats
void PortF_Init(void){
	
// Code to initialize PF1, PF2, PF3
	SYSCTL_RCGCGPIO_R &= ~0x20;		// enable port F clock
	SYSCTL_RCGCGPIO_R |= 0x20;
	__nop();	
	__nop();
	__nop();
	__nop();
	__nop();											// wait for clock to stabilize
	GPIO_PORTF_DIR_R &= ~0x0E;		// set PF1 - PF3 as output and input
	GPIO_PORTF_DIR_R |= 0x0E;
	GPIO_PORTF_AFSEL_R &= ~0x0E;	// disable alternate function for PF1 - PF3
	GPIO_PORTF_DEN_R &= ~0x0E;		// enable GPIO for PF1 - PF3
	GPIO_PORTF_DEN_R |= 0x0E;
}



void SysTick_Init(){
  

	NVIC_ST_CTRL_R = 0;							 // disable SysTick during setup
	NVIC_ST_CURRENT_R = 0;					 // any write to current clears it
	NVIC_SYS_PRI3_R = (NVIC_SYS_PRI3_R&0x00FFFFFF)|0x40000000;
																	 // set interrupt priority to 2
	NVIC_ST_RELOAD_R = 1333333; 		 // Load 60Hz value into SysTick reload value
	NVIC_ST_CURRENT_R = 0;					 // Set SysTick to zero to start note immediately
	
}



uint32_t Status[20];             // entries 0,7,12,19 should be false, others true
char GetData[10];  // entries 1 2 3 4 5 6 7 8 should be 1 2 3 4 5 6 7 8
int main1(void){ // Make this main to test FiFo
  Fifo_Init();   // Assuming a buffer of size 6
  for(;;){
    Status[0]  = Fifo_Get(&GetData[0]);  // should fail,    empty
    Status[1]  = Fifo_Put(1);            // should succeed, 1 
    Status[2]  = Fifo_Put(2);            // should succeed, 1 2
    Status[3]  = Fifo_Put(3);            // should succeed, 1 2 3
    Status[4]  = Fifo_Put(4);            // should succeed, 1 2 3 4
    Status[5]  = Fifo_Put(5);            // should succeed, 1 2 3 4 5
    Status[6]  = Fifo_Put(6);            // should succeed, 1 2 3 4 5 6
    Status[7]  = Fifo_Put(7);            // should fail,    1 2 3 4 5 6 
    Status[8]  = Fifo_Get(&GetData[1]);  // should succeed, 2 3 4 5 6
    Status[9]  = Fifo_Get(&GetData[2]);  // should succeed, 3 4 5 6
    Status[10] = Fifo_Put(7);            // should succeed, 3 4 5 6 7
    Status[11] = Fifo_Put(8);            // should succeed, 3 4 5 6 7 8
    Status[12] = Fifo_Put(9);            // should fail,    3 4 5 6 7 8 
    Status[13] = Fifo_Get(&GetData[3]);  // should succeed, 4 5 6 7 8
    Status[14] = Fifo_Get(&GetData[4]);  // should succeed, 5 6 7 8
    Status[15] = Fifo_Get(&GetData[5]);  // should succeed, 6 7 8
    Status[16] = Fifo_Get(&GetData[6]);  // should succeed, 7 8
    Status[17] = Fifo_Get(&GetData[7]);  // should succeed, 8
    Status[18] = Fifo_Get(&GetData[8]);  // should succeed, empty
    Status[19] = Fifo_Get(&GetData[9]);  // should fail,    empty
  }
}

// Get fit from excel and code the convert routine with the constants
// from the curve-fit
uint32_t Convert(uint32_t input){
	if (input <= 20) //Just return 0 if at bottom of potentiometer
		return 0;
	input -= 20; //Adjust for value of ADC when slide is at zero
	input *= 36846; //0.00049128 cm per value (range of potentiometer is about 18 to 4089)
	input /= 100000; //Adjust to cm
	return input;

}


/* SysTick ISR
*/
void SysTick_Handler(void){ // every 20 ms
 //Sample ADC, convert to distance, create 8-byte message, send message out UART1
	uint32_t k = 0;							// starting index to output char from
	PF2 ^= 0xFF;								// toggle heartbeat
	ADC = ADC_In();							// read in data to mailbox
	State = 1;									// set state to 1
	PF2 ^= 0xFF;								// toggle heartbeat
	ADC = Convert(ADC);					// convert data
	
	message[0] = 0x02;					// packet start
	
	hold = ADC / 1000;
	ADC %= 1000;
	message[1] = hold + 0x30;		// ASCII char of first number
	
	message[2] = 0x2E;					// decimal point
	
	hold = ADC / 100;
	ADC %= 100;
	message[3] = hold + 0x30;		// ASCII char of second number
	
	hold = ADC / 10;
	ADC %= 10;
	message[4] = hold + 0x30;		// ASCII char of third number
	message[5] = ADC + 0x30;		// ASCII char of last number
	message[6] = 0x0D;					// ASCII char of carriage return
	message[7] = 0x03;					// packet end
	
	for(;k < 8; k++){
		Uart_OutChar(message[k]);	// output packet using UART
	}
	
	Cnt++; 								// increment transmit counter
	PF2 ^= 0xFF;								// toggle heartbeat


}
// final main program for bidirectional communication
// Sender sends using SysTick Interrupt
// Receiver receives using RX
uint32_t heartbeat = 0;
uint32_t ADCmail;
uint32_t ADCstatus = 1;


int main(void){ 
  
  PLL_Init(Bus80MHz);     			// Bus clock is 80 MHz 
  ST7735_InitR(INITR_REDTAB);
  ADC_Init();    								// initialize to sample ADC
  PortF_Init();
  Uart_Init();     							// initialize UART
	SysTick_Init();
	
  ST7735_SetCursor(0,0);
  LCD_OutFix(0);
  ST7735_OutString(" cm");
	
  EnableInterrupts();
	NVIC_ST_CTRL_R = 0x07; //Enable SysTick with interrupt privelege.

  while(1){
		int j = 1;
		int i = 1;
		int m = 0;
		while(State == 0){
		}													// wait until adc mailbox is full
		State = 0;								// clear state of mailbox
		
		ST7735_SetCursor(0,0);		// set cursor to left corner
		do{
			Fifo_Get(&packet);
			out[0] = packet; 				// waits until fifo isn't empty
		}while (out[0] == 0x00);
		
		for(; j < 8; j++){				// place fifo data into output array
			Fifo_Get(&packet);
			out[j] = packet;
		}
		
		if((out[0] == 0x02) && (out[7] == 0x03)){
			out[0] = 0;											// reset packet start char
			out[7] = 0;											// reset packet end char
			
			for(;i < 6; i++){
				char holder = 0;							// holding character for debugging purposes
				holder = out[i];
				ST7735_OutChar(holder);				// output character to lcd
				out[i] = 0;										// reset index in output array
			}
			
			ST7735_SetCursor(6,0);					// set cursor to end
			ST7735_OutString(" cm.");				// print " cm."
			
		}
		
		else{
			for(;m < 8; m++){								// reset indexes in output array
				out[m] = 0;
			}
		}
	}
}


