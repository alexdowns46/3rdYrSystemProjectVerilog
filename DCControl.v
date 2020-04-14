module DCControl(clk, Speed, Direction, DCOut);
//Verilog DC Motor PWM Controller, A Downs 2020
input clk;
input [1:0] Speed;
input Direction;

output [1:0] DCOut;

reg [3:0] PWMCount; //Counts each 10% duty Cycle
reg [3:0] DutyCycle; //The duty cycle 1=10%, 5=50% etc
reg PWM; //The PWM signal thats routed to each switch
reg [1:0] DCOut;

always @(posedge clk)
begin
case(Speed)
	0: DutyCycle=0;
	1: DutyCycle=8;
	2: DutyCycle=9;
	3: DutyCycle=10;
	default: DutyCycle=0;
endcase	
if  (PWMCount<DutyCycle) begin
	PWM=1;
end

if (PWMCount>=DutyCycle) begin
	PWM=0;
end

if (PWMCount==10) begin
	PWMCount=0;
	PWM=1;
end

if (Direction==1) begin
	DCOut[0]=PWM;
	DCOut[1]=0;
end

if (Direction==0) begin
	DCOut[0]=0;
	DCOut[1]=PWM;
end
PWMCount=PWMCount+1;

end
endmodule