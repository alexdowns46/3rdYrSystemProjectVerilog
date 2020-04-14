module ServoControl(clk, PosIn, SigOut);
//Verilog Servo PWM Controller, A Downs 2020
input clk;
input [7:0] PosIn; //0 = 1ms, 1 = 1.5ms, 2 = 2ms
output SigOut;

reg SigOut;
reg [5:0] ClkCycles = 50; //number of actual clock cycles between each 1us pulse
reg [5:0] CycleCount = 0;	//Counts number of clock cycles
reg [15:0] MicroCount = 0;	//Counts numer of microseconds
reg [10:0] intv = 1000;
reg [7:0] Pos;
reg [3:0] i = 0;

initial begin
//CycleCount = 0;
//MicroCount = 0;
//PulseNum = 0;
end

always @(posedge clk)
begin
	intv = 1000+(((Pos*1000)/90)); //Sets PWM period according to angle
	if (CycleCount < ClkCycles) //Checks counter value
		CycleCount=CycleCount+1;//Increments cycle counter
	if (CycleCount >= ClkCycles) begin	//Checks how many uS have elapsed
			MicroCount=MicroCount+1;	//Increments uS counter
			CycleCount = 0;				//Resets cycle counter
		end
	if (MicroCount > intv)
		SigOut =0;					//If the time elapsed is greater than the microsecond counter set output to low
	else
		SigOut = 1;					//If else set it to high

	if (MicroCount > 20000) begin	//If the time elapsed is greater than the period
		MicroCount = 0;				//Resets the time elapsed to zero
	end
end
endmodule