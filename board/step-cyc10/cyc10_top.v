module wb_ram (
    input             clk,
    input             reset,
    input      [31:0] addr,
    input      [31:0] wdata,
    input      [ 3:0] sel,
    input             we,
    input             cyc,
    input             stb,
    output     [31:0] rdata,
    output reg        ack
);

  wire [31:0] q;
  assign rdata = {q[7:0], q[15:8], q[23:16], q[31:24]};
  assign data = {wdata[7:0], wdata[15:8], wdata[23:16], wdata[31:24]};
  ram mem (
`ifdef MODEL_TECH
      .address(addr[31:2]),
`else
      .address(addr),
`endif
      .byteena(sel),
      .clock(clk),
      .data(data),  // 换顺序？
      .rden(cyc & stb & ~we),
      .wren(cyc & stb & we),
      .q(q)
  );

  reg ack1;  // 拖一个周期
  always @(posedge clk) begin
    ack1 <= 1'b0;
    if (cyc & stb & ~ack & ~ack1) begin
      ack1 <= 1'b1;
    end
  end

  always @(posedge clk or posedge reset) begin
    if (reset) ack <= 1'b0;
    else ack <= ack1;
  end
endmodule
module synchronizer (
    input clk,
    input asyncrst_n,
    output reg rst_n
);

  reg rff1;
  always @(posedge clk or negedge asyncrst_n)
    if (!asyncrst_n) {rst_n, rff1} <= 2'b0;
    else {rst_n, rff1} <= {rff1, 1'b1};
endmodule
module cyc10_top (
    output reg rgb_led1_r,
    output reg rgb_led1_g,
    output reg rgb_led1_b,
    output reg rgb_led2_r,
    output reg rgb_led2_g,
    output reg rgb_led2_b,
    output [7:0] led,
    input clk_50m,
    input key_c_n,
    input uart_rx,
    output uart_tx
);

  wire clk;
  wire pll_locked;

  pll pll (
      .areset(~key_c_n),
      .inclk0(clk_50m),
      .c0(clk),  // 5MHz
      .locked(pll_locked)
  );

  wire rst_n;
  synchronizer synchronizer (
      .clk(clk),
      .asyncrst_n(pll_locked),
      .rst_n(rst_n)
  );

  wire [31:0] inst_addr;
  wire [31:0] inst_wdata;
  wire [ 3:0] inst_sel;
  wire        inst_we;
  wire        inst_cyc;
  wire        inst_stb;
  wire [31:0] inst_rdata;
  wire        inst_ack;

  wire [31:0] data_addr;
  wire [31:0] data_wdata;
  wire [ 3:0] data_sel;
  wire        data_we;
  wire        data_cyc;
  wire        data_stb;
  wire [31:0] data_rdata;
  wire        data_ack;

  wire [31:0] ram_addr;
  wire [31:0] ram_wdata;
  wire [ 3:0] ram_sel;
  wire        ram_we;
  wire        ram_cyc;
  wire        ram_stb;
  wire [31:0] ram_rdata;
  wire        ram_ack;

  wb_ram ram (
      .clk(clk),
      .reset(~rst_n),
      .addr(ram_addr),
      .wdata(ram_wdata),
      .sel(ram_sel),
      .we(ram_we),
      .cyc(ram_cyc),
      .stb(ram_stb),
      .rdata(ram_rdata),
      .ack(ram_ack)
  );

  wire [7:0] led_n;
  assign led = ~led_n;
  naive_soc soc (
      .clk(clk),
      .reset(~rst_n),
      .ram_addr(ram_addr),
      .ram_wdata(ram_wdata),
      .ram_sel(ram_sel),
      .ram_we(ram_we),
      .ram_cyc(ram_cyc),
      .ram_stb(ram_stb),
      .ram_rdata(ram_rdata),
      .ram_ack(ram_ack),
      .uart_rx(uart_rx),
      .uart_tx(uart_tx),
      .gpio_o(led_n)
  );

  // reset test
  always @(posedge clk) begin
    if (!rst_n)
      {rgb_led1_r, rgb_led1_g, rgb_led1_b, rgb_led2_r, rgb_led2_g, rgb_led2_b} <= 6'b000000;  // 时间太快，放开按键时微微一闪
    else {rgb_led1_r, rgb_led1_g, rgb_led1_b, rgb_led2_r, rgb_led2_g, rgb_led2_b} <= 6'b111111;
  end

endmodule
