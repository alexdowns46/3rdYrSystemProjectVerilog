module LED(clk,Lit, LEDCode,LEDOut);

// LED interpreter A Downs 2020

input clk,Lit;
input [7:0] LEDCode;
output [7:0] LEDOut;
//Designates the value of an LED
reg [7:0] LEDOut;

always @(posedge clk) begin


casex(LEDCode) //Lights the corresponding LED
	8'bxxxxx000: LEDOut=0; 
	8'bxxxxx001: LEDOut[0]= Lit;
	8'bxxxxx010: LEDOut[1]= Lit;
	8'bxxxxx011: LEDOut[2]= Lit; 
	8'bxxxxx100: LEDOut[3]= Lit;
	8'bxxxxx101: LEDOut[4]= Lit;
	8'bxxxxx110: LEDOut[5]= Lit;
	8'bxxxxx111: LEDOut[6]= Lit;
	default:LEDOut = 0;
endcase

end
endmodule

