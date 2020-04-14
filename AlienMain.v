module AlienMain(clk, SCLK, SS, MOSI,SwitchInput, MISO,SigOut,DCOut1,DCOut2,BCD,State,LEDOut);

input SCLK, SS, MOSI; //SPI Inputs
input clk; //50MHz Clock input
input [6:0] SwitchInput; //7-bit switch input

output MISO, SigOut; //Servo PWM out
output [1:0] DCOut1,DCOut2; //Output to H-Bridge
output [7:0] LEDOut;//Output to LEDs
output [20:0] BCD; //Used to display data on BCD Screen

wire [7:0] SPIIn; //8-bit Register containing information received from the MBED
wire [3:0] SwitchOutput; //Tells the FPGA which Switch has been pressed 

reg Direction1,Direction2,Lit; //Motor directions and LED Value
reg [1:0] Speed1,Speed2; //Speed encoding, 4 settings: 0=Off,1=Low,2=Medium,3=High
reg [2:0] Motor; //Which of the 2 motors is being driven 
reg [4:0] State=0; //State register containing what state the machine is at
reg [7:0] LEDArray [14:0]; //Contains the sequence of LEDs to light up
reg [7:0] SPIOut,LEDCode,ServoPos,LEDCount; //Various Registers, SPI Output, LED Encoding, Servo Angle and Counter

SPIBus(clk,SPIOut,MOSI,SS,SCLK,MISO,SPIIn);//Instantiates the SPI module, this outputs the 8-bit command sent by the MBED on SPIIn
ServoControl(clk, ServoPos, SigOut);	//Instantiates the servo module, this is used to output the PWM signal for the specified position
LED(clk,Lit,LEDCode,LEDOut);	//LED Module			
bcd_decode_display(clk,SPIIn,BCD);	//Displays the Decimal of the SPI command on the BCD
SwitchPoll(clk,SwitchInput,SwitchOutput); //Switch Poller
DCControl(clk, Speed1, Direction1, DCOut1);	//DC Motor 1 controller
DCControl(clk, Speed2, Direction2, DCOut2);	//DC Motor 2 controller

initial begin 
	State = 0; //Set the state variable to 0
	ServoPos = 0; //Set the angle variable to 0
	SPIOut=20;
	LEDCode=16;
	LEDCount=0;
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
State=State+1;
end

if (State==2) begin
if (SwitchOutput[2:0]==LEDCode[2:0]) begin
	State=State+1;
	end
end

if (State==3) begin
 //Game counter variable
Lit=0;
LEDCount=LEDCount+1;
ServoPos=ServoPos +5;
if (LEDCount>14) begin
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

	reg [3:0] Swout;	//Returns the 
	reg [20:0] Divider=0;
	reg Divclk=0;
	reg [20:0] DivCount=1000; //Divide the clock down to 50KHz
	reg [7:0] SwitchArray [6:0]; // 8x7 Array of shift registers for edge detection
	reg i;
	always @(posedge clk) begin
		Divider=Divider+1;		//Clock divider for switch timings
		if (Divider==(DivCount/2)) Divclk=1-Divclk;	//Needed for debouncing
		if (Divider==DivCount) begin
			Divclk=1-Divclk;
			Divider=0;
		end
	end
	always @(posedge Divclk) begin
	for(i=0;i<7;i=i+1) begin
		if (SwitchArray[i]==8'b01111111)#1000 Swout=0; //Delay is there to ensure the rising edge is detected
		SwitchArray[i] <={SwitchArray[i][6:0], Switches[i]}; //Shift switch value into array
		if (SwitchArray[i]==8'b00111111) Swout=i; //Detect rising edge
		if (SwitchArray[i]==8'b11111100) Swout=i; //Detect falling edge
	end

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