module DT(input 			clk,
            input			reset,
            output	        done,
            output			sti_rd,
            output	reg 	[9:0]	sti_addr,
            input		[15:0]	sti_di,
            output			res_wr,
            output			res_rd,
            output	reg 	[13:0]	res_addr,
            output	reg 	[7:0]	res_do,
            input		[7:0]	res_di);


  /*----------PARAMETERS--------*/
  parameter  IDLE                = 'd0;
  parameter  FETCH_ROM_FORWARD   = 'd1;
  parameter  FETCH_REG_FORWARD   = 'd2;
  parameter  FORWARD             = 'd3;
  parameter  BACKWARD_PREPROCESS = 'd4;
  parameter  FETCH_ROM_BACKWARD  = 'd5;
  parameter  FETCH_REG_BACKWARD  = 'd6;
  parameter  BACKWARD            = 'd7;
  parameter  DONE                = 'd8;

  //Registers
  reg[3:0]  counter_reg;
  reg[9:0]  rom_addr_index_reg;
  reg[13:0] ram_addr_index_reg;
  reg[2:0]  fetch_ram_counter_reg;
  reg[15:0] sti_di_reg;
  reg[7:0]  for_back_reg[0:3];
  reg[7:0]  ref_and_temp_reg;
  reg backward_start;
  reg[7:0]  min_temp_wire_b3_reg;
  reg[3:0]  current_state,next_state;

  //flag
  wire  f_r_f_done,forward_done,f_r_f_start;
  wire  f_r_b_done,backward_done,f_r_b_start;
  wire  skip_f_flag = rom_addr_index_reg == 'd0;
  wire  skip_b_flag = rom_addr_index_reg == 'd1023;
  wire  not_object = sti_di_reg[rom_addr_index_reg] == 'd0 ;

  assign f_r_f_done = (fetch_ram_counter_reg == 'd3 | not_object);
  assign forward_done = (ram_addr_index_reg == 'd16383);
  assign f_r_f_start = (counter_reg == 'd0);

  assign f_r_b_done = (fetch_ram_counter_reg == 'd4 || sti_di_reg[rom_addr_index_reg] == 'd0);
  assign backward_done = (ram_addr_index_reg == 'd16383);
  assign f_r_b_start = (counter_reg == 'd15);

  //wire
  wire  [7:0] min_temp_wire_1,min_temp_wire_2,min_temp_wire_3;
  wire  [7:0] min_temp_wire_b1,min_temp_wire_b2,min_temp_wire_b3,min_temp_wire_b4;
  assign min_temp_wire_1 = FORWARD_state ? {(for_back_reg[0] > for_back_reg[1]) ? for_back_reg[1] : for_back_reg[0]} : 'd0;
  assign min_temp_wire_2 = FORWARD_state ? {(for_back_reg[2] > for_back_reg[3]) ? for_back_reg[3] : for_back_reg[2]} : 'd0;
  assign min_temp_wire_3 = FORWARD_state ? {(min_temp_wire_2 > min_temp_wire_1) ? min_temp_wire_1 : min_temp_wire_2} : 'd0;

  assign min_temp_wire_b1 = BACKWARD_state ? {(for_back_reg[0] > for_back_reg[1]) ? for_back_reg[1] : for_back_reg[0]} : 'd0;
  assign min_temp_wire_b2 = BACKWARD_state ? {(for_back_reg[2] > for_back_reg[3]) ? for_back_reg[3] : for_back_reg[2]} : 'd0;
  assign min_temp_wire_b3 = BACKWARD_state ? {(min_temp_wire_b2 > min_temp_wire_b1) ? min_temp_wire_b1 : min_temp_wire_b2} : 'd0;
  assign min_temp_wire_b4 = backward_start ? {(min_temp_wire_b3_reg > ref_and_temp_reg) ? ref_and_temp_reg : min_temp_wire_b3_reg} : 'd0;

  //state
  wire IDLE_state                 = current_state == IDLE;
  wire FETCH_ROM_FORWARD_state    = current_state == FETCH_ROM_FORWARD;
  wire FETCH_REG_FORWARD_state    = current_state == FETCH_REG_FORWARD;
  wire FORWARD_state              = current_state == FORWARD;
  wire BACKWARD_PREPROCESS_state  = current_state == BACKWARD_PREPROCESS;
  wire FETCH_ROM_BACKWARD_state   = current_state == FETCH_ROM_BACKWARD;
  wire FETCH_REG_BACKWARD_state   = current_state == FETCH_REG_BACKWARD;
  wire BACKWARD_state             = current_state == BACKWARD;
  wire DONE_state                 = current_state == DONE;

  //OUTPUT
  assign done = DONE_state;
  assign sti_rd = FETCH_ROM_FORWARD_state | FETCH_ROM_BACKWARD_state;
  assign res_wr = FORWARD_state | BACKWARD_state;
  assign res_rd = skip_f_flag ? 0 : (FETCH_REG_FORWARD_state | FETCH_REG_BACKWARD_state) ? 1 : 0;

  /*
          case (fetch_ram_counter_reg)
            'd0:res_addr = (col_index_reg - 'd1) + 'd128 * (row_index_reg - 'd1);
            'd1:res_addr = (col_index_reg) + 'd128 * (row_index_reg - 'd1);
            'd2:res_addr = (col_index_reg + 'd1) + 'd128 * (row_index_reg - 'd1);
            'd3:res_addr = ram_addr_index_reg - 'd1;
            default: res_addr = 'd0;
        endcase
  */

  //res_addr
  always @(*)
  begin
    if (FORWARD_state)
    begin
      case (fetch_ram_counter_reg)
        'd0:
          res_addr = ram_addr_index_reg - 'd129;
        'd1:
          res_addr = ram_addr_index_reg - 'd128;
        'd2:
          res_addr = ram_addr_index_reg - 'd127;
        'd3:
          res_addr = ram_addr_index_reg - 'd1;
        default:
          res_addr = 'd0;
      endcase
    end
    else if(BACKWARD_state)
    begin
      if(f_r_f_done)
      begin
        res_addr = ram_addr_index_reg;
      end
      else
      begin
        case (fetch_ram_counter_reg)
          'd0:
            res_addr = ram_addr_index_reg + 'd1;
          'd1:
            res_addr = ram_addr_index_reg + 'd127;
          'd2:
            res_addr = ram_addr_index_reg + 'd128;
          'd3:
            res_addr = ram_addr_index_reg + 'd129;
          default:
            res_addr = 'd0;
        endcase
      end
    end
  end

  //res_do
  always @(*)
  begin
    if (FORWARD_state)
    begin
      res_do = skip_f_flag ? sti_di_reg[0] : not_object ? 'd0 : min_temp_wire_3 + 'd1;
    end
    else if(backward_start)
    begin
      res_do = skip_b_flag ? sti_di_reg[15] : not_object ? 'd0 : min_temp_wire_b4;
    end
    else
    begin
      res_do = 'd0;
    end
  end

  /*------------CTR---------------*/
  always @(posedge clk or negedge reset)
  begin
    current_state <= !reset ? IDLE : next_state;
  end
  //next_state
  always @(*)
  begin
    case (current_state)
      IDLE:
      begin
        next_state = FETCH_ROM_FORWARD;
      end
      FETCH_ROM_FORWARD:
      begin
        next_state = skip_f_flag ? FORWARD : FETCH_REG_FORWARD;
      end
      FETCH_REG_FORWARD:
      begin
        next_state = f_r_f_done ? FORWARD : FETCH_REG_FORWARD;
      end
      FORWARD:
      begin
        next_state = f_r_f_done ? BACKWARD_PREPROCESS : f_r_f_start ? FETCH_ROM_FORWARD : FETCH_REG_FORWARD;
      end
      BACKWARD:
      begin
        next_state = FETCH_ROM_BACKWARD;
      end
      FETCH_ROM_BACKWARD:
      begin
        next_state = skip_b_flag ? BACKWARD : FETCH_REG_BACKWARD;
      end
      FETCH_REG_BACKWARD:
      begin
        next_state = f_r_b_done ? BACKWARD : FETCH_REG_BACKWARD;
      end
      BACKWARD:
      begin
        next_state = backward_start ? {backward_done ? DONE : f_r_b_start ? FETCH_ROM_BACKWARD : FETCH_REG_BACKWARD} : BACKWARD;
      end
      DONE:
      begin
        next_state = IDLE;
      end
      default:
      begin
        next_state = IDLE;
      end
    endcase
  end

  //backward_start
  always @(posedge clk or negedge reset)
  begin
    if(!reset)
    begin
      backward_start <= 0;
    end
    else
    begin
      backward_start <= BACKWARD_state ;
    end
  end

  //counter_reg
  always @(posedge clk or negedge reset)
  begin
    if(!reset)
    begin
      counter_reg <= 'd0;
    end
    else if(BACKWARD_state | FORWARD_state)
    begin
      counter_reg <= counter_reg + 'd1;
    end
    else
    begin
      counter_reg <= counter_reg;
    end
  end

  //fetch_ram_counter_reg
  always @(posedge clk or negedge reset)
  begin
    if(!reset)
    begin
      fetch_ram_counter_reg <= 'd0;
    end
    else if(FETCH_REG_FORWARD_state | FETCH_REG_BACKWARD_state)
    begin
      fetch_ram_counter_reg <= fetch_ram_counter_reg + 'd1;
    end
    else if(FORWARD_state | BACKWARD_state)
    begin
      fetch_ram_counter_reg <= 'd0;
    end
    else
    begin
      fetch_ram_counter_reg <= fetch_ram_counter_reg;
    end
  end

  //rom_addr_index_reg
  always @(posedge clk or negedge reset)
  begin
    if(!reset)
    begin
      rom_addr_index_reg <= 'd0;
    end
    else if(FETCH_ROM_BACKWARD_state)
    begin
      rom_addr_index_reg <= rom_addr_index_reg + 'd1;
    end
    else if(BACKWARD_PREPROCESS_state)
    begin
      rom_addr_index_reg <= 'd1023;
    end
    else if(BACKWARD_state)
    begin
      rom_addr_index_reg <= rom_addr_index_reg - 'd1;
    end
    else
    begin
      rom_addr_index_reg <= rom_addr_index_reg;
    end
  end

  //ram_addr_index_reg
  always @(posedge clk or negedge reset)
  begin
    if(!reset)
    begin
      ram_addr_index_reg <= 'd0;
    end
    else if(FORWARD_state)
    begin
      ram_addr_index_reg <= ram_addr_index_reg + 'd1;
    end
    else if(BACKWARD_PREPROCESS_state)
    begin
      ram_addr_index_reg <= 'd16383;
    end
    else if(BACKWARD_state)
    begin
      ram_addr_index_reg <= ram_addr_index_reg - 'd1;
    end
    else
    begin
      ram_addr_index_reg <= ram_addr_index_reg;
    end
  end

  //sti_di_reg
  always @(posedge clk or negedge reset)
  begin
    if(!reset)
    begin
      sti_di_reg <= 'd0;
    end
    else if(FETCH_ROM_BACKWARD_state | FETCH_ROM_FORWARD_state)
    begin
      sti_di_reg <= sti_di;
    end
    else
    begin
      sti_di_reg <= sti_di_reg;
    end
  end

  integer i;
  //for_back_reg
  always @(posedge clk or negedge reset)
  begin
    if(!reset)
    begin
      for(i=0;i<4;i=i+1)
      begin
        for_back_reg[i] <= 'd0;
      end
    end
    else if(FETCH_REG_FORWARD_state)
    begin
      for_back_reg[fetch_ram_counter_reg] <= skip_f_flag ? 'd127 : res_di;
    end
    else if(FETCH_REG_BACKWARD_state)
    begin
      for_back_reg[fetch_ram_counter_reg] <= skip_f_flag ? 'd127 : res_di + 'd1;
    end
    else if(FORWARD_state | BACKWARD_state)
    begin
      for(i=0;i<4;i=i+1)
      begin
        for_back_reg[i] <= 'd0;
      end
    end
    else
    begin
      for(i=0;i<4;i=i+1)
      begin
        for_back_reg[i] <= for_back_reg[i];
      end
    end
  end

  //ref_and_temp_reg
  always @(posedge clk or negedge reset)
  begin
    if(!reset)
    begin
      ref_and_temp_reg <= 'd0;
    end
    else if(FETCH_REG_BACKWARD_state & f_r_b_done)
    begin
      ref_and_temp_reg <= res_di;
    end
    else
    begin
      ref_and_temp_reg <= ref_and_temp_reg;
    end
  end

  //min_temp_wire_b3_reg
  always @(posedge clk or negedge reset)
  begin
    if(!reset)
    begin
      min_temp_wire_b3_reg <= 'd0;
    end
    else
    begin
      min_temp_wire_b3_reg <= min_temp_wire_b3;
    end
  end

endmodule