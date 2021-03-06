module AlienMain(clk, SCLK, SS, MOSI,SwitchInput, MISO,SigOut,DCOut1,DCOut2,BCD,State,LEDOut);

// B39VS A Downs 2020

input SCLK, SS, MOSI; //SPI Inputs
input clk; //50MHz Clock input
input [6:0] SwitchInput;



output [20:0] BCD;
output MISO; //SPI Outputs
output SigOut; //Servo PWM out
output [7:0] LEDOut;
output [4:0] State; //State reg
output [1:0] DCOut1,DCOut2;
wire [7:0] SPIIn; //8-bit Register containing information received from the MBED
reg [7:0] SPIOut; //8-bit Register containing data to be sent to the MBED 
reg [4:0] State=0; //State register containing what state the machine is at
reg [7:0] LEDCode=16; //Tells the FPGA which LED to light 
wire [3:0] SwitchOutput; //Tells the FPGA which Switch has been pressed 
reg [7:0] ServoPos; //
reg DIVCLK;
reg [10:0] Divider; 
reg [7:0] DivCount= 50;
reg Gen=0;
reg [7:0] GCount=0;
wire Place;
reg Lit;
reg [7:0] LEDArray [14:0];
reg [7:0] LEDCount=0;


reg [1:0] Speed1,Speed2; //Speed encoding, 4 settings: 0=Off,1=Low,2=Medium,3=High
reg Direction1,Direction2; //1=Forwards, 0=Reverse
reg [2:0] Motor; //Which of the 2 motors is being driven 




//Instantiates the SPI module, this outputs the 8-bit command sent by the MBED on SPIIn
SPIBus(clk,SPIOut,MOSI,SS,SCLK,MISO,SPIIn);
ServoControl(clk, ServoPos, SigOut);	//Instantiates the servo module, this is used to output the PWM signal for the specified position
LED(clk,Lit,LEDCode,LEDOut);				
bcd_decode_display(clk,SPIIn,BCD);	//Displays the Decimal of the SPI command on the BCD
Rand(Gen, Place);
SwitchPoll(DIVCLK,SwitchInput,SwitchOutput);
DCControl(clk, Speed1, Direction1, DCOut1);	//DC Motor 1 controller
DCControl(clk, Speed2, Direction2, DCOut2);	//DC Motor 2 controller

initial begin 
	State = 0; //Set the state variable to 0
	ServoPos = 0; //Set the angle variable to 0
	SPIOut=20;
	LEDArray[0]=8'b00000001;
	LEDArray[1]=8'b00000011;
	LEDArray[2]=8'b00000010;
	LEDArray[3]=8'b00000101;
	LEDArray[4]=8'b00000110;
	LEDArray[5]=8'b00000111;
	LEDArray[6]=8'b00000101;
	LEDArray[7]=8'b00000010;
	LEDArray[8]=8'b00000001;
	LEDArray[9]=8'b00000011;
	LEDArray[10]=8'b00000111;
	LEDArray[11]=8'b00000110;
	LEDArray[12]=8'b00000101;
	LEDArray[13]=8'b00000100;
	LEDArray[14]=8'b00000001;
end

always @(posedge clk) begin
Divider=Divider+1;
if  (Divider==(DivCount/2)) begin
	DIVCLK=1-DIVCLK;
end
if (Divider==DivCount) begin
	DIVCLK=1-DIVCLK;
	Divider=0;
end
end




always @(posedge clk) begin			//Always block that contains the SPI Command interpreter

if (State ==0) begin
	casez (SPIIn)							//Casez block that any input on the SPI Lines
	8'b00000001: begin 
				 //This is the 'GO' command from the MBED
				 SPIOut=21;
				 State=1;
				 end
	8'b00000010: State = 10;			//Maintenance mode from MBED
	default: State=0;
endcase
State=SPIIn;
end

if (State==1) begin
#10 LEDCode = LEDArray[LEDCount];
#10 Lit=1;
SPIOut=LEDCode+32;
Gen=1; //Generate a new LED code
State=State+1;
end

if (State==2) begin
if (SwitchOutput[2:0]==LEDCode[2:0]) begin
	State=State+1;
	end
end

if (State==3) begin
Gen=0;
GCount=GCount+1; //Game counter variable
Lit=0;
LEDCount=LEDCount+1;
ServoPos=ServoPos +5;
if (GCount>14) begin
	GCount=0;
	LEDCount=0;
	SPIOut=20; //Send game complete command
	State=0;
end
State=1;
end



if (State==10) begin
casez(SPIIn) 
	//8'b00000100: State=0; //Exit maintenance mode command
	8'b001zzzzz: begin 				//If the command recevied is a LED
					LEDCode=SPIIn-32;
					Lit=LEDCode[4];
					SPIOut=20;
				 end
	8'b0001zzzz: begin 				//If the command recevied is a DC motor command
					if (SPIIn[0]==1) begin
						Speed1 = SPIIn[3:2]; //Set the speed
						Direction1 = SPIIn[1]; //Set the direction
						SPIOut=20;
					end
					if (SPIIn[0]==0) begin
						Speed2 = SPIIn[3:2]; //Set the speed
						Direction2 = SPIIn[1]; //Set the direction
						SPIOut=20;
					end
				 end

		default: begin 				//If the command recevied is a Servo angle
					if ((SPIIn>63)&&(SPIIn<154)) begin
						ServoPos=SPIIn-64;
						SPIOut=20;
					end
				 end
endcase
end
end
endmodule

module SwitchPoll(clk,Switches,Swout);
	input clk;
	input [6:0] Switches;
	output [3:0] Swout;
	reg [7:0] SW1,SW2,SW3,SW4,SW5,SW6,SW7;
	reg [3:0] Swout;
	
	reg [20:0] Divider=0;
	reg DIVCLK=0;
	reg [20:0] DivCount=100000;
	
	reg [7:0] SwitchArray [6:0];
	
	
	
	always @(posedge clk) begin
		Divider=Divider+1;		//Clock divider for switch timines
		if (Divider==(DivCount/2)) DIVCLK=1-DIVCLK;	//Needed for debouncing
		if (Divider==DivCount) begin
			DIVCLK=1-DIVCLK;
			Divider=0;
		end
	end
	always @(posedge DIVCLK) begin
	for(i=0;i<7;i=i+1) begin
		if (SwitchArray[i]==8'b01111111)#1000 Swout=0;
		SwitchArray[i] <={SwitchArray[i][6:0], Switches[i]};
		if (SwitchArray[i]==8'b00111111) Swout=i;
		if (SwitchArray[i]==8'b11111100) Swout=i;
	end
	
	
	
	
	
	
		if (SW1==8'b01111111)#1000 Swout=0; //Delay required to give FPGA enough time to read a high
		if (SW2==8'b01111111)#1000 Swout=0;
		if (SW3==8'b01111111)#1000 Swout=0;
		if (SW4==8'b01111111)#1000 Swout=0;
		if (SW5==8'b01111111)#1000 Swout=0;
		if (SW6==8'b01111111)#1000 Swout=0;
		if (SW7==8'b01111111)#1000 Swout=0;
		if (SW1==8'b11111110)#1000 Swout=0;
		if (SW2==8'b11111110)#1000 Swout=0;
		if (SW3==8'b11111110)#1000 Swout=0;
		if (SW4==8'b11111110)#1000 Swout=0;
		if (SW5==8'b11111110)#1000 Swout=0;
		if (SW6==8'b11111110)#1000 Swout=0;
		if (SW7==8'b11111111)#1000 Swout=0;
		SW1 <={SW1[6:0], Switches[0]}; //Shift register to poll switch inputs
		SW2 <={SW2[6:0], Switches[1]}; //Shift register to poll switch inputs
		SW3 <={SW3[6:0], Switches[2]}; //Shift register to poll switch inputs
		SW4 <={SW4[6:0], Switches[3]}; //Shift register to poll switch inputs
		SW5 <={SW5[6:0], Switches[4]}; //Shift register to poll switch inputs
		SW6 <={SW6[6:0], Switches[5]}; //Shift register to poll switch inputs
		SW7 <={SW7[6:0], Switches[6]}; //Shift register to poll switch inputs
		//Poll for rising and falling edges below, also used to debounce
		if (SW1==8'b00111111) Swout=1;
		if (SW1==8'b11111100) Swout=1;

		if (SW2==8'b00111111) Swout=2;
		if (SW2==8'b11111100) Swout=2;

		if (SW3==8'b00111111) Swout=3;
		if (SW3==8'b11111100) Swout=3;

		if (SW4==8'b00111111) Swout=4;
		if (SW4==8'b11111100) Swout=4;

		if (SW5==8'b00111111) Swout=5;
		if (SW5==8'b11111100) Swout=5;

		if (SW6==8'b00111111) Swout=6;
		if (SW6==8'b11111100) Swout=6;

		if (SW7==8'b00111111) Swout=7;
		if (SW7==8'b11111100) Swout=7;

	end
endmodule


module Rand(Gen, Random); //Generates a random number between 0-7 to light up LED
	input Gen;
	output [4:0] Random; 
	reg[4:0]Random;
	always @(posedge Gen) begin
      integer    seed,i,j;
      for (i=0; i<6; i=i+1)
        begin
           Random=2; 
        end 
    end
endmodule

module bcd_decode_display(clk,number,disp_drive);
	// includes the display drivers
	input clk;
	input [9:0] number;
	output [20:0] disp_drive;//outputs to display segments
	reg [3:0] numb_bcd0,numb_bcd1,numb_bcd2;
	wire [3:0] n1,n2,n3;
	assign n1 = numb_bcd0; //Assign input driver values
	assign n2 = numb_bcd1;
	assign n3 = numb_bcd2;
	// instantiate each display driver
	//Send decoded data to each driver
	display_drv units(clk,n1,disp_drive[6:0]); // Least significant digit
	display_drv tenths(clk,n2,disp_drive[13:7]); 
	display_drv hundredths(clk,n3,disp_drive[20:14]); //Most signifigcant digit
	// bcd conversion units, tens and hundreds
	always @(posedge clk)
		begin	//Use the modulo function to split the output signals
		numb_bcd0 = (number%100)%10;//units
		numb_bcd1 = (number%100)/10;//tenths
		numb_bcd2 = number/100;//hundredths
	end
endmodule


module display_drv(clk,number,display);
	input clk;
	input [3:0] number;
	output [6:0] display;
	reg [6:0] d;
	assign display = d; // active high
	// on clock edge update display
	always @(posedge clk )
		begin
		if (number < 10)
			begin
				case (number)
				4'd0 : d <= 7'b1000000; // segments lit
				4'd1 : d <= 7'b1111001; //Sets the display segments depending on case
				4'd2 : d <= 7'b0100100;
				4'd3 : d <= 7'b0110000;
				4'd4 : d <= 7'b0011001;
				4'd5 : d <= 7'b0010010;
				4'd6 : d <= 7'b0000010;
				4'd7 : d <= 7'b1111000;
				4'd8 : d <= 7'b0000000;
				4'd9 : d <= 7'b0011000;
				default : d <= 7'b1111111; // off
				endcase
			end
		else d <= 7'b0001110; // 'F'
	end
endmodule