`timescale 1ns/1ps

module pochoco_periph_tb;

  reg         clk_i;
  reg         rst_ni;
  reg         sel_i;
  reg         req_i;
  reg         we_i;
  reg  [7:0]  addr_i;
  reg  [31:0] wdata_i;
  wire [31:0] rdata_o;
  wire [3:0]  leds_o;
  reg  [3:0]  btn_i;
  wire [6:0]  seg1_o;
  wire [6:0]  seg2_o;

  integer errors;

  reg [31:0] cycle_1;
  reg [31:0] cycle_2;
  reg [31:0] led_stamp_1;
  reg [31:0] led_stamp_2;
  reg [31:0] button_value;


  // Device under test
  pochoco_periph dut (
    .clk_i   (clk_i),
    .rst_ni  (rst_ni),
    .sel_i   (sel_i),
    .req_i   (req_i),
    .we_i    (we_i),
    .addr_i  (addr_i),
    .wdata_i (wdata_i),
    .rdata_o (rdata_o),
    .leds_o  (leds_o),
    .btn_i   (btn_i),
    .seg1_o  (seg1_o),
    .seg2_o  (seg2_o)
  );


  // Clock
  always #5 clk_i = ~clk_i;


  // -----------------------------------------------
  // Write helper
  // -----------------------------------------------

  task write_reg;

    input [7:0] addr;
    input [31:0] data;

    begin

      @(negedge clk_i);

      sel_i   = 1'b1;
      req_i   = 1'b1;
      we_i    = 1'b1;
      addr_i  = addr;
      wdata_i = data;

      @(posedge clk_i);
      #1;

      @(negedge clk_i);

      sel_i   = 1'b0;
      req_i   = 1'b0;
      we_i    = 1'b0;

    end

  endtask


  // -----------------------------------------------
  // Read helper
  // -----------------------------------------------

  task read_reg;

    input [7:0] addr;
    output [31:0] data;

    begin

      @(negedge clk_i);

      sel_i  = 1'b1;
      req_i  = 1'b1;
      we_i   = 1'b0;
      addr_i = addr;

      @(posedge clk_i);
      #1;

      data = rdata_o;

      @(negedge clk_i);

      sel_i = 1'b0;
      req_i = 1'b0;

    end

  endtask


  // -----------------------------------------------
  // Tests
  // -----------------------------------------------

  initial begin

    $dumpfile("sim/pochoco_periph_tb.vcd");
    $dumpvars(0, pochoco_periph_tb);

    clk_i   = 1'b0;
    rst_ni  = 1'b0;
    sel_i   = 1'b0;
    req_i   = 1'b0;
    we_i    = 1'b0;
    addr_i  = 8'b0;
    wdata_i = 32'b0;
    btn_i   = 4'b0;

    errors = 0;


    // ---------------------------------------------
    // RESET
    // ---------------------------------------------

    repeat (3)
      @(posedge clk_i);

    @(negedge clk_i);
    rst_ni = 1'b1;

    repeat (2)
      @(posedge clk_i);


    // =============================================
    // TEST 1 - Cycle counter
    // =============================================

    $display("");
    $display("TEST 1 - Cycle counter");

    read_reg(8'h0C, cycle_1);

    repeat (5)
      @(posedge clk_i);

    read_reg(8'h0C, cycle_2);

    if (cycle_2 > cycle_1) begin

      $display("PASS: counter increased (%0d -> %0d)",
               cycle_1, cycle_2);

    end else begin

      $display("ERROR: cycle counter did not increase");
      errors = errors + 1;

    end


    // =============================================
    // TEST 2 - LED write
    // =============================================

    $display("");
    $display("TEST 2 - LED write");

    write_reg(8'h04, 32'h00000004);

    if (leds_o == 4'b0100) begin

      $display("PASS: LED value = 0100");

    end else begin

      $display("ERROR: LED value incorrect");
      errors = errors + 1;

    end


    // =============================================
    // TEST 3 - Exact LED timestamp
    // =============================================

    $display("");
    $display("TEST 3 - LED timestamp");

    // Immediately after the LED write, cycle_q has
    // advanced by one cycle while led_cycle_q contains
    // the cycle in which the write occurred.

    if (dut.led_cycle_q == (dut.cycle_q - 1)) begin

      $display("PASS: LED timestamp captured correctly");

    end else begin

      $display("ERROR: incorrect LED timestamp");
      $display("cycle_q     = %0d", dut.cycle_q);
      $display("led_cycle_q = %0d", dut.led_cycle_q);

      errors = errors + 1;

    end

    read_reg(8'h10, led_stamp_1);
    read_reg(8'h0C, cycle_1);

    if (cycle_1 > led_stamp_1) begin

      $display("PASS: current cycle is later than LED timestamp");

    end else begin

      $display("ERROR: timestamp relationship incorrect");
      errors = errors + 1;

    end


    // =============================================
    // TEST 4 - Buttons
    // =============================================

    $display("");
    $display("TEST 4 - Button input");

    btn_i = 4'b0010;

    read_reg(8'h08, button_value);

    if (button_value[3:0] == 4'b0010) begin

      $display("PASS: button value read correctly");

    end else begin

      $display("ERROR: button value incorrect");
      errors = errors + 1;

    end

    btn_i = 4'b0000;


    // =============================================
    // TEST 5 - Second LED timestamp
    // =============================================

    $display("");
    $display("TEST 5 - New LED timestamp");

    repeat (5)
      @(posedge clk_i);

    write_reg(8'h04, 32'h0000000F);

    read_reg(8'h10, led_stamp_2);

    if (led_stamp_2 > led_stamp_1) begin

      $display("PASS: timestamp updated after new LED write");

    end else begin

      $display("ERROR: timestamp was not updated");
      errors = errors + 1;

    end


    // =============================================
    // TEST 6 - Seven-segment display
    // =============================================

    $display("");
    $display("TEST 6 - Display");

    // Write hexadecimal 25
    write_reg(8'h00, 32'h00000025);

    if ((seg1_o == 7'b1011011) &&
        (seg2_o == 7'b1101101)) begin

      $display("PASS: display shows hexadecimal 25");

    end else begin

      $display("ERROR: display decoding incorrect");
      errors = errors + 1;

    end


    // =============================================
    // FINAL RESULT
    // =============================================

    $display("");
    $display("--------------------------------");

    if (errors == 0) begin

      $display("ALL TESTS PASSED");

    end else begin

      $display("TEST FAILED: %0d error(s)", errors);

    end

    $display("--------------------------------");
    $display("");

    $finish;

  end

endmodule
