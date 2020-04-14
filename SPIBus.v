module SPIBus(clk,DataIn,MOSI,SS,SCLK,MISO,DataOut);
input clk,SCLK,MOSI,SS; //declare inputs
input [7:0] DataIn;	   //Byte data input

output MISO;				//Signal from MBED
output [7:0] DataOut;	//Byte data output

reg [2:0] SCLKreg;		//shift register to sync FPGA clock with MBED clock
reg [2:0] SSreg;			//shift register to sync FPGA clock with Select line
reg [1:0] MOSIreg;		//shift register to sync FPGA clock with MOSI signal

reg [2:0] BitCount; //Bit in counter
reg GotByte;			//Goes high when a byte has been loaded
reg [7:0] InputBuffer;
reg [7:0] OutputBuffer;
reg [7:0] Count;
reg [7:0] DataOut;

wire SCLKRise = (SCLKreg[2:1]==2'b01); //Detects rising edge of the SCLK
													//Works by comparing previous value to a new value
wire SCLKFall = (SCLKreg[2:1]==2'b10);	//Falling edge detector, works same way

wire SSActive = ~SSreg[1]; //Select line is active when it goes low
wire SSStart = (SSreg[2:1]==2'b10); //Falling edge detector
wire SSEnd = (SSreg[2:1]==2'b01); //Rising edge detector

wire MOSIData=MOSIreg[1]; //Get MOSIData from the value of the MOSIreg


always @(posedge clk) begin //Always block to syn
   SCLKreg <={SCLKreg[1:0], SCLK}; //Load SCLKreg 
	SSreg <={SSreg[1:0],SS}; //Load SSreg
	MOSIreg <= {MOSIreg[0], MOSI}; //Load MOSIreg from MOSI line
end

always @(posedge clk) begin
	if (BitCount==0) begin	//Swap the buffer and register contents
		OutputBuffer<=DataIn;
		DataOut<=InputBuffer;
	end
	if(~SSActive)
		BitCount <= 3'b000; //Set counter to zero if SS is high
	else
	if(SCLKRise)
	begin	
		BitCount <= BitCount + 3'b001; //Count bits in
		InputBuffer <= {InputBuffer[6:0], MOSIData}; //Shift the MOSI data along the buffer
		OutputBuffer <= {OutputBuffer[6:0],1'b0}; //Shift the MISO data along the buffer
	end
end

always @(posedge clk) GotByte <=SSActive &&SCLKRise &&(BitCount==3'b111); //Set GotByte high once a byte has been got

assign MISO = OutputBuffer[7]; //Set MSB to MISO output

endmodule










		
		










