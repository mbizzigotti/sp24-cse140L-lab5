// ECE260C -- lab 5 alternative DUT
// applies done flag when cycle_ct = 255
module top_level_5b(
  input          clk, init, 
  output logic   done);

// memory interface
  logic          wr_en;
  logic    [7:0] raddr, 
                 waddr,
                 data_in,
                 data_out;             

// program counter
  logic[15:0] cycle_ct = 0;

// LFSR interface
  logic load_LFSR,
        LFSR_en;
  logic[5:0] start;                  // LFSR starting state
  logic[5:0] LFSR_state[6];
  logic[5:0] match;					 // got a match for LFSR (one hot)
  logic[2:0] foundit;                // binary index equiv. of match
  int i;

// instantiate submodules
// data memory -- fill in the connections
  dat_mem dm1(
    .clk,
    .write_en(wr_en),
    .raddr,
    .waddr,
    .data_in,
    .data_out
  );

const bit [5:0] tap_patterns[6] = '{
  6'h21,
  6'h2D,
  6'h30,
  6'h33,
  6'h36,
  6'h39
};

genvar k;
generate
  for (k=0; k < 6; k++)
  lfsr6b lfsr (
    .clk,
    .en(LFSR_en),
    .init(load_LFSR),
    .taps(tap_patterns[k]),
    .start(data_out[5:0] ^ 6'h1f),
    .state(LFSR_state[k])
  );
endgenerate


/* We need to advance the LFSR(s) once per clock cycle. 
Same with raddr, waddr, since we can physically do one memory read and/or write
per clock cycle. 
*/

// this block remaps a one-hot 6-bit code into a 3-bit binary count
// acts like a priority encoder from MSB to LSB 
  always_comb case(match)
    6'b10_0000: foundit = 'd5; // because bit [5] was set
    6'b01_0000: foundit = 'd4; // because bit [4] was set
    6'b00_1000: foundit = 'd3; // because bit [3] was set
    6'b00_0100: foundit = 'd2; // because bit [2] was set
    6'b00_0010: foundit = 'd1; // because bit [1] was set
	default:      foundit = 'd0; // covers bit[0] match and no match cases
  endcase

// program counter
// as in Lab 4, you can do the whole lab without any branches or jumps
  always @(posedge clk) begin  :clock_loop
    if(init) begin
      cycle_ct <= 'b0;
      match    <= 'b0;
    end
    else begin
      cycle_ct <= cycle_ct + 1;
	    if (cycle_ct == 8) begin // last symbol of preamble
	      for(i=0; i<6; i++) begin
	        match[i] <= (LFSR_state[i] == ('h1f ^ data_out[5:0])); // which LFSR state conforms to our test bench LFSR? 
		    end
      end
    end
  end  

  always_comb begin 
//defaults
    load_LFSR = 'b0; 
    LFSR_en   = 'b0;   
	  wr_en     = 'b0;
  case(cycle_ct)
	0: begin 
    raddr     = 'd64;   // starting address for encrypted data to be loaded into device
		waddr     = 'd64;   // starting address for storing decrypted results into data mem
	end		       // no op
	1: begin 
    load_LFSR = 1;	  // initialize the 6 LFSRs
    raddr     = 'd64;
		waddr     = 'd64;
	end		       // no op
	2  : begin				   
      LFSR_en   = 1;	   // advance the 6 LFSRs     
      raddr     = 'd64;
		  waddr     = 'd64;
    end
	3  : begin			       // training seq.	-- run LFSRs & advance raddr
	    LFSR_en = 1;
		  raddr = 'd65;			  // advance raddr
		  waddr = 'd64;
		end
	72  : begin
        done = 1;		// send acknowledge back to test bench to halt simulation
 		    raddr =	0;
 		    waddr = 'd64; 
	     end
	default: begin	         // covers cycle_ct 4-71
	  LFSR_en = 1;
	  waddr = cycle_ct - 9;
    //raddr++;
    if(cycle_ct>8) begin   // turn on write enable
			wr_en = 1;
      raddr = 62 + cycle_ct;
		end
		else begin
      raddr = 'd70;
			wr_en = 0;
		end
		data_in = data_out^{2'b00, LFSR_state[foundit]};
  end
  endcase
end

/*
    if(!init && initQ) begin :init_loop  // falling init
	  begin  :loop2			   
        for(int jl=0;jl<7;jl++)
	      LFSR[jl] =         dm1.core[64+jl][5:0]^6'h1f;
          lfsr_trial[0][0] = dm1.core[64][5:0]^6'h1f;
          lfsr_trial[1][0] = dm1.core[64][5:0]^6'h1f;
          lfsr_trial[2][0] = dm1.core[64][5:0]^6'h1f;
          lfsr_trial[3][0] = dm1.core[64][5:0]^6'h1f;
          lfsr_trial[4][0] = dm1.core[64][5:0]^6'h1f;
          lfsr_trial[5][0] = dm1.core[64][5:0]^6'h1f;
//          $display("trial 0 = %h",lfsr_trial[0][0]);
          for(int kl=0;kl<6;kl++) begin :trial_loop
            lfsr_trial[0][kl+1] = (lfsr_trial[0][kl]<<1)+(^(lfsr_trial[0][kl]&LFSR_ptrn[0]));   
            lfsr_trial[1][kl+1] = (lfsr_trial[1][kl]<<1)+(^(lfsr_trial[1][kl]&LFSR_ptrn[1]));   
            lfsr_trial[2][kl+1] = (lfsr_trial[2][kl]<<1)+(^(lfsr_trial[2][kl]&LFSR_ptrn[2]));   
            lfsr_trial[3][kl+1] = (lfsr_trial[3][kl]<<1)+(^(lfsr_trial[3][kl]&LFSR_ptrn[3]));   
            lfsr_trial[4][kl+1] = (lfsr_trial[4][kl]<<1)+(^(lfsr_trial[4][kl]&LFSR_ptrn[4]));   
            lfsr_trial[5][kl+1] = (lfsr_trial[5][kl]<<1)+(^(lfsr_trial[5][kl]&LFSR_ptrn[5]));   
            $display("trials %d %h %h %h %h %h %h    %h",  kl,
				 lfsr_trial[0][kl+1],
				 lfsr_trial[1][kl+1],
				 lfsr_trial[2][kl+1],
				 lfsr_trial[3][kl+1],
				 lfsr_trial[4][kl+1],
				 lfsr_trial[5][kl+1],
				 LFSR[kl+1]);			  
          end :trial_loop
		  for(int mm=0;mm<6;mm++) begin :ureka_loop
            $display("mm = %d  lfsr_trial[mm] = %h, LFSR[6] = %h",
			     mm, lfsr_trial[mm][6], LFSR[6]); 
		    if(lfsr_trial[mm][6] == LFSR[6]) begin
			  foundit = mm;
			  $display("foundit = %d LFSR[6] = %h",foundit,LFSR[6]);
            end
		  end :ureka_loop
		  $display("foundit fer sure = %d",foundit);								   
		  for(int jm=0;jm<63;jm++)
		    LFSR[jm+1] = (LFSR[jm]<<1)+(^(LFSR[jm]&LFSR_ptrn[foundit]));
          for(int mn=7;mn<64-7;mn++) begin  :first_core_write
		    dm1.core[mn-7] = dm1.core[64+mn-7]^{2'b0,LFSR[mn-7]};
			$display("%dth core = %h LFSR = %h",mn,dm1.core[64+mn-7],LFSR[mn-7]);
          end   :first_core_write
         #10ns;
         for(km=0; km<64; km++) begin
            if(dm1.core[km]==8'h5f) continue;
            else break;  
          end     
          $display("underscores to %d th",km);
          for(int kl=0; kl<64; kl++) begin
            dm1.core[kl] = dm1.core[kl+km];
		    $display("%dth core = %h",kl,dm1.core[kl]);
          end
	  end   :loop2
    end :init_loop
  end  :clock_loop

  always_comb
    done = &cycle_ct[6:0];   // holds for two clocks
*/
endmodule