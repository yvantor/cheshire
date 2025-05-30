
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License.  You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
// Simulation UART (not synthesizable). Leverages CVA6 Mock UART.

module chs_sim_uart #(
  parameter type reg_req_t,
  parameter type reg_rsp_t
)(
  input  logic clk_i,
  input  logic rst_ni,
  input  reg_req_t reg_req_i,
  output reg_rsp_t reg_rsp_o
);

  typedef struct packed {
    logic [31:0] paddr;
    logic [ 2:0] pprot;
    logic        psel;
    logic        penable;
    logic        pwrite;
    logic [31:0] pwdata;
    logic [3:0]  pstrb;
  } apb_req_t;

  typedef struct packed {
    logic pready;
    logic [31:0] prdata;
    logic pslverr;
  } apb_rsp_t;

  apb_req_t  apb_uart_req;
  apb_rsp_t apb_uart_rsp;

  reg_to_apb #(
    .reg_req_t (reg_req_t),
    .reg_rsp_t (reg_rsp_t),
    .apb_req_t (apb_req_t),
    .apb_rsp_t (apb_rsp_t)
  ) i_reg_to_apb (
    .clk_i,
    .rst_ni,
    .reg_req_i,
    .reg_rsp_o,
    .apb_req_o (apb_uart_req),
    .apb_rsp_i (apb_uart_rsp)
  );

  mock_uart i_mock_uart (
    .clk_i,
    .rst_ni,
    .penable_i ( apb_uart_req.penable ),
    .pwrite_i  ( apb_uart_req.pwrite  ),
    .paddr_i   ( apb_uart_req.paddr   ),
    .psel_i    ( apb_uart_req.psel    ),
    .pwdata_i  ( apb_uart_req.pwdata  ),
    .prdata_o  ( apb_uart_rsp.prdata  ),
    .pready_o  ( apb_uart_rsp.pready  ),
    .pslverr_o ( apb_uart_rsp.pslverr )
  );

endmodule : chs_sim_uart
