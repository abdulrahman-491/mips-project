module instruction_mem (A, RD);
	input [9:0]A; //10-bit
	output [31:0]RD;

	reg [31:0] memory [0:1023];
	assign RD = memory [A];
endmodule


module alu (in_1, in_2, alu_control, zero, alu_result);

	input wire [31:0 ]in_1, in_2;
	input wire [2:0] alu_control;
	output reg [31:0] alu_result;
	output wire zero;

	assign zero = in_1 == in_2 ? 1'b1 : 1'b0;

	always @ (*)
	begin 
		case(alu_control)
			3'b000: alu_result = in_1 & in_2;
			3'b001: alu_result = in_1 | in_2;
			3'b010: alu_result = in_1 + in_2;
			3'b110: alu_result = in_1 - in_2;
			3'b111: alu_result = in_1 < in_2 ? 1'b1 : 1'b0;
		endcase 
	end 
endmodule 

module mux (in_1, in_2, sel, out);
	
	input wire sel;
	input wire [31:0] in_1, in_2;
	output reg [31:0]out;

	always @ (*)
	begin 
		case(sel)
			1'b0: out = in_1;
			1'b1: out = in_2;
		endcase 
	end

endmodule 

module register_file (RD1, RD2, WD, RA1, RA2, WA, WE, clk);

	input wire [4:0] RA1, RA2, WA;
	input wire WE, clk;
	input wire [31:0] WD;
	output wire [31:0] RD1, RD2;

	reg [31:0] RF [0:31];

	assign RD1 = RF[RA1];
	assign RD2 = RF[RA2];

	always @(posedge clk)
	begin
		 if (WE) RF[WA] <= WD;
	end 
endmodule

module sign_extend (immediate, signlmm);

	input wire [15:0]immediate;
	output wire [31:0]signlmm;
	
	assign immediate_MSB = immediate[15];
	assign signlmm = {{16{immediate_MSB}}, immediate};
	
endmodule

module control_unit (

	op, funct,
	mem_reg, mem_write, branch, alu_src, reg_dst, reg_write, jump,
	alu_control
);

	input wire [5:0] op, funct;
	output reg mem_reg, mem_write, branch, alu_src, reg_dst, reg_write, jump;
	output reg [2:0] alu_control;

	

	always @ (*)
   	begin
		case(op)
			6'b0000_00: // R-format
				begin
					case(funct)
						6'b1000_00: alu_control = 3'b010;
						6'b1000_10: alu_control = 3'b110;
						6'b1001_00: alu_control = 3'b000;
						6'b1001_01: alu_control = 3'b001;
						6'b1010_10: alu_control = 3'b111;
					endcase
					reg_write = 1'b1;
					reg_dst   = 1'b1;
					alu_src   = 1'b0;
					branch    = 1'b0;
					mem_write = 1'b0;
					mem_reg   = 1'b0;
					jump      = 1'b0;
				end

			6'b1000_11: // lw
				begin 
					alu_control = 3'b010;
					reg_write   = 1'b1;
					reg_dst     = 1'b0;
					alu_src     = 1'b1;
					branch      = 1'b0;
					mem_write   = 1'b0;
					mem_reg     = 1'b1;
					jump        = 1'b0;
				end

			6'b1010_11: // sw
				begin 
					alu_control = 3'b010;
					reg_write   = 1'b0;
					reg_dst     = 1'bx;
					alu_src     = 1'b1;
					branch      = 1'b0;
					mem_write   = 1'b1;
					mem_reg     = 1'bx;
					jump        = 1'b0;
				end

			6'b0001_00: // beq
				begin 
					alu_control = 3'b110;
					reg_write   = 1'b0;
					reg_dst     = 1'bx;
					alu_src     = 1'b0;
					branch      = 1'b1;
					mem_write   = 1'b0;
					mem_reg     = 1'bx;
					jump        = 1'b0;
				end

			6'b0010_00: // addi
				begin 
					alu_control = 3'b010;
					reg_write   = 1'b1;
					reg_dst     = 1'b0;
					alu_src     = 1'b1;
					branch      = 1'b0;
					mem_write   = 1'b0;
					mem_reg     = 1'b0;
					jump        = 1'b0;
				end

			6'b0000_10: // j
				begin 
					alu_control = 3'bxxx;
					reg_write   = 1'b0;
					reg_dst     = 1'bx;
					alu_src     = 1'bx;
					branch      = 1'bx;
					mem_write   = 1'b0;
					mem_reg     = 1'bx;
					jump        = 1'b1;
					
				end
		endcase
 	end
endmodule 

module data_memory(A, WD, WE, RD, clk);

	input wire [11:0] A; // 12-bit 
	input wire [31:0] WD;
	input wire WE, clk;
	output wire [31:0] RD;

	reg [31:0] memory [0:4095];
	
	assign RD = memory [A]; 

	always @ (posedge clk)
	begin 
        if (WE) begin
            memory[A] <= WD;
        end	 
	end 
endmodule 

module mips (clk, reset);

	input wire reset, clk;
	
	reg [31:0] PC;
	wire [31:0] instr;
	instruction_mem im (PC[11:2], instr); ///////updated/////////
	
	
	wire [31:0] srcA;
	wire [31:0] write_data;
	wire [31:0] result;
	wire [4:0] write_reg;
	wire reg_write;
	wire reg_dst;
	register_file reg_file1 (srcA, write_data, result, instr[25:21], instr[20:16], write_reg, reg_write, clk);
	mux m1 (instr[20:16], instr[15:11], reg_dst, write_reg);


	wire [31:0] srcB;
	wire alu_src;
	wire zero;
	wire [31:0] signlmm;
	//wire [31:0] RD2_wire;
	wire [2:0] alu_control;
	wire [31:0] alu_result;

	sign_extend s1 (instr[15:0], signlmm);
	mux m2 (write_data, signlmm, alu_src, srcB);
	alu alu_1(srcA, srcB, alu_control, zero, alu_result);


	wire mem_write;
	wire mem_to_reg;
	wire [31:0] read_data;

	data_memory data_mem1(alu_result, write_data, mem_write, read_data, clk); ////////updated/////////
	mux m3 (alu_result, read_data, mem_to_reg, result);
	
	
	wire [31:0] PC_plus_4, PC_branch;
	assign PC_plus_4 = PC + 4;
	assign PC_branch = (signlmm << 2) + PC_plus_4;

	
	wire branch, jump, PC_src;
	control_unit c1(instr[31:26], instr[5:0], mem_to_reg, mem_write, branch, alu_src, reg_dst, reg_write, jump, alu_control);
	assign PC_src = zero & branch;


	wire [31:0] PC_jump;
	assign PC_jump = {PC_plus_4[31:28], {instr[25:0], 2'b00}};


	wire [31:0] PC_next;
	assign PC_next = jump ? PC_jump : (PC_src ? PC_branch : PC_plus_4);


	always @(posedge clk, posedge reset)
	begin 
		if (reset) begin
			PC <= 0;
		end 
		else 
			PC <= PC_next;
	end 
endmodule 


module mips_tb;

	reg clk, reset;

	mips m1 (clk, reset);

	initial begin
		clk = 0;
		forever begin
			#5 clk = ~clk;
		end
	end
	
	initial begin
    	$readmemh("mem.txt",m1.im.memory);
    	$readmemh("mem_reg.txt",m1.reg_file1.RF);
    	reset=1;
    	@(negedge clk);
   		reset=0;
		@(negedge clk);
   	 	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	@(negedge clk);
    	$stop;
	end
endmodule
